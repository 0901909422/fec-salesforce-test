/**
 * Custom email service cho FEC - thay thế FEC_InteractionEmailController
 * Bao gồm: validation, attachment, logging (Task), update case fields
 * @created: 2026/03/20
 */
public without sharing class FEC_CustomEmailService {

    // ─── Proxy methods từ FEC_InteractionEmailController (giữ nguyên để helper JS dùng) ───

    @AuraEnabled
    public static Map<String, String> getInteractionEmail(String caseId) {
        return FEC_InteractionEmailController.getInteractionEmail(caseId);
    }

    @AuraEnabled
    public static String getCaseSubject(String caseId) {
        return FEC_InteractionEmailController.getCaseSubject(caseId);
    }

    @AuraEnabled
    public static List<EmailMessage> getEmailMessages(String caseId) {
        return FEC_InteractionEmailController.getEmailMessages(caseId);
    }

    @AuraEnabled(cacheable=true)
    public static List<EmailTemplate> getEmailTemplates() {
        return FEC_InteractionEmailController.getEmailTemplates();
    }

    @AuraEnabled
    public static String fetchImageAsBase64(String imageUrl) {
        return FEC_InteractionEmailController.fetchImageAsBase64(imageUrl);
    }

    /**
     * Lấy danh sách From: Email-to-Case routing addresses + OrgWideEmailAddress + current user
     * Ưu tiên Email-to-Case lên đầu (giống Chatter)
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getFromAddresses() {
        List<Map<String, String>> result = new List<Map<String, String>>();

        // 1. Email-to-Case routing addresses (EmailRoutingAddress)
        // Fields: address (EMAIL), personalname (STRING)
        try {
            List<SObject> routingAddrs = Database.query(
                'SELECT Id, Address, PersonalName FROM EmailRoutingAddress ORDER BY PersonalName ASC LIMIT 50'
            );
            for (SObject r : routingAddrs) {
                String addr = (String) r.get('Address');
                String name = (String) r.get('PersonalName');
                if (String.isNotBlank(addr)) {
                    result.add(new Map<String, String>{
                        'label' => (String.isNotBlank(name) ? name + ' <' + addr + '>' : addr),
                        'value' => addr
                    });
                }
            }
        } catch (Exception e) {
            // EmailRoutingAddress không available → bỏ qua
            System.debug('EmailRoutingAddress query failed: ' + e.getMessage());
        }

        // 2. OrgWideEmailAddress
        for (OrgWideEmailAddress owa : [
            SELECT Id, Address, DisplayName FROM OrgWideEmailAddress ORDER BY DisplayName ASC
        ]) {
            // Tránh trùng với routing address đã thêm
            Boolean alreadyAdded = false;
            for (Map<String, String> existing : result) {
                if (existing.get('value') == owa.Address) { alreadyAdded = true; break; }
            }
            if (!alreadyAdded) {
                result.add(new Map<String, String>{
                    'label' => owa.DisplayName + ' <' + owa.Address + '>',
                    'value' => owa.Address
                });
            }
        }

        // 3. Current user (fallback nếu chưa có gì)
        if (result.isEmpty()) {
            User me = [SELECT Id, Name, Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            if (String.isNotBlank(me.Email)) {
                result.add(new Map<String, String>{
                    'label' => me.Name + ' <' + me.Email + '>',
                    'value' => me.Email
                });
            }
        }

        return result;
    }


    private static final List<String> READONLY_FROM_LIST = new List<String>{
        'dichvukhachhang@fecredit.com.vn',
        'dichvukhachhang@ubank.com.vn'
    };

    // Các status không cho phép gửi email
    private static final Set<String> BLOCKED_STATUSES = new Set<String>{
        'Closed', 'Resolved', 'Cancelled'
    };

    // Wrapper cho attachment từ client
    public class AttachmentWrapper {
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String base64Data { get; set; }
        @AuraEnabled public String mimeType { get; set; }
    }

    /**
     * Gửi email custom với đầy đủ validation, attachment, logging
     */
    @AuraEnabled
    public static void sendEmail(
        String caseId,
        String fromEmail,
        String toEmail,
        String ccEmail,
        String subject,
        String body,
        List<AttachmentWrapper> attachments
    ) {
        try {
            // 1. Validate case status
            Case c = [
                SELECT Id, Status, FEC_Interaction_Status__c, OwnerId, Subject
                FROM Case WHERE Id = :caseId LIMIT 1
            ];

            if (BLOCKED_STATUSES.contains(c.Status)) {
                throw new AuraHandledException(
                    'Không thể gửi email: Case đang ở trạng thái "' + c.Status + '".'
                );
            }

            // 2. Validate email addresses
            validateEmail(toEmail, 'To');
            if (String.isNotBlank(ccEmail)) {
                for (String cc : ccEmail.split(',')) {
                    validateEmail(cc.trim(), 'CC');
                }
            }

            // 3. Build email message
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(toEmail.split(','));

            if (String.isNotBlank(ccEmail)) {
                List<String> ccList = new List<String>();
                for (String cc : ccEmail.split(',')) {
                    if (String.isNotBlank(cc.trim())) ccList.add(cc.trim());
                }
                if (!ccList.isEmpty()) mail.setCcAddresses(ccList);
            }

            mail.setSubject(subject);
            mail.setHtmlBody(body.replace('\n', '<br/>'));
            mail.setWhatId(caseId);
            mail.setSaveAsActivity(true);

            // 4. Set OrgWideEmailAddress (From)
            setFromAddress(mail, fromEmail);

            // 5. Handle attachments
            if (attachments != null && !attachments.isEmpty()) {
                List<Messaging.EmailFileAttachment> emailAttachments = new List<Messaging.EmailFileAttachment>();
                for (AttachmentWrapper att : attachments) {
                    if (String.isBlank(att.base64Data) || String.isBlank(att.fileName)) continue;
                    Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                    efa.setFileName(att.fileName);
                    efa.setBody(EncodingUtil.base64Decode(att.base64Data));
                    if (String.isNotBlank(att.mimeType)) {
                        efa.setContentType(att.mimeType);
                    }
                    emailAttachments.add(efa);
                }
                if (!emailAttachments.isEmpty()) {
                    mail.setFileAttachments(emailAttachments);
                }
            }

            // 6. Send
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });

            // 7. Post-send: update case fields + create Task log
            updateCaseAfterSend(caseId, fromEmail, toEmail, ccEmail, subject);

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Lỗi gửi email: ' + e.getMessage());
        }
    }

    // ─── Private helpers ────────────────────────────────────────────────────

    private static void validateEmail(String email, String fieldLabel) {
        if (String.isBlank(email)) {
            throw new AuraHandledException(fieldLabel + ' email không được để trống.');
        }
        // Basic email format check
        String emailRegex = '^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$';
        Pattern p = Pattern.compile(emailRegex);
        for (String addr : email.split(',')) {
            addr = addr.trim();
            if (String.isBlank(addr)) continue;
            if (!p.matcher(addr).matches()) {
                throw new AuraHandledException(
                    fieldLabel + ' email không hợp lệ: "' + addr + '"'
                );
            }
        }
    }

    private static void setFromAddress(Messaging.SingleEmailMessage mail, String fromEmail) {
        if (String.isBlank(fromEmail)) return;

        // Tìm OrgWideEmailAddress khớp trực tiếp
        List<OrgWideEmailAddress> orgEmails = [
            SELECT Id, Address FROM OrgWideEmailAddress
            WHERE Address = :fromEmail LIMIT 1
        ];
        if (!orgEmails.isEmpty()) {
            mail.setOrgWideEmailAddressId(orgEmails[0].Id);
            return;
        }

        // Tìm OrgWide cùng domain (cho Email-to-Case routing addresses)
        String fromDomain = fromEmail.contains('@') ? fromEmail.substringAfter('@') : '';
        if (String.isNotBlank(fromDomain)) {
            List<OrgWideEmailAddress> domainMatch = [
                SELECT Id, Address FROM OrgWideEmailAddress
                WHERE Address LIKE :('%@' + fromDomain) LIMIT 1
            ];
            if (!domainMatch.isEmpty()) {
                mail.setOrgWideEmailAddressId(domainMatch[0].Id);
                return;
            }
        }

        // Không tìm thấy OrgWide phù hợp → throw lỗi rõ ràng
        throw new AuraHandledException(
            'Không thể gửi email: địa chỉ "' + fromEmail + '" chưa được cấu hình làm Organization-Wide Email Address. Vui lòng liên hệ Admin để verify địa chỉ này trong Setup.'
        );
    }

    private static void updateCaseAfterSend(
        String caseId, String fromEmail, String toEmail, String ccEmail, String subject
    ) {
        // Update case fields
        Case cUpdate = new Case(Id = caseId);
        if (String.isNotBlank(fromEmail)) cUpdate.FEC_Email_From__c = fromEmail;
        if (String.isNotBlank(toEmail))   cUpdate.FEC_Send_To__c    = toEmail;
        if (String.isNotBlank(ccEmail))   cUpdate.FEC_Email_CC__c   = ccEmail;
        update cUpdate;

        // Create Task as audit log
        Task t = new Task();
        t.WhatId      = caseId;
        t.Subject     = 'Email Sent: ' + subject;
        t.Description = 'From: ' + fromEmail + '\nTo: ' + toEmail
                      + (String.isNotBlank(ccEmail) ? '\nCC: ' + ccEmail : '');
        t.Status      = 'Completed';
        t.Priority    = 'Normal';
        t.ActivityDate = Date.today();
        insert t;
    }
}
