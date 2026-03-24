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
     * Lấy From picklist: full list EmailRoutingAddress + OrgWide.
     * Nếu Case owner là Queue và email match → lên đầu + selected.
     */
    @AuraEnabled
    public static Map<String, Object> getFromAddresses(String caseId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        String defaultFrom = null;

        // Lấy toàn bộ EmailRoutingAddress
        Map<String, String> routingLabelMap = new Map<String, String>();
        Map<String, String> routingAddrMap  = new Map<String, String>();
        List<String> routingOrder = new List<String>();
        try {
            List<SObject> routingAddrs = Database.query(
                'SELECT Id, Address, PersonalName FROM EmailRoutingAddress ORDER BY PersonalName ASC LIMIT 50'
            );
            for (SObject r : routingAddrs) {
                String addr = (String) r.get('Address');
                String name = (String) r.get('PersonalName');
                if (String.isNotBlank(addr)) {
                    String lower = addr.toLowerCase();
                    String lbl = (String.isNotBlank(name) ? name + ' <' + addr + '>' : addr);
                    routingLabelMap.put(lower, lbl);
                    routingAddrMap.put(lower, addr);
                    routingOrder.add(lower);
                }
            }
        } catch (Exception e) {
            System.debug('EmailRoutingAddress query failed: ' + e.getMessage());
        }

        // Xác định Queue email của Case
        String queueEmail = null;
        if (String.isNotBlank(caseId)) {
            try {
                Case c = [SELECT OwnerId, Owner.Type FROM Case WHERE Id = :caseId LIMIT 1];
                if (c.Owner.Type == FEC_ConstantCommon.GROUP_TYPE_QUEUE) {
                    Group q = [SELECT Id, Name, Email FROM Group WHERE Id = :c.OwnerId LIMIT 1];
                    if (String.isNotBlank(q.Email)) queueEmail = q.Email;
                }
            } catch (Exception e) {
                System.debug('Queue lookup failed: ' + e.getMessage());
            }
        }

        // Queue match → lên đầu + selected
        String qLower = queueEmail != null ? queueEmail.toLowerCase() : null;
        if (qLower != null && routingAddrMap.containsKey(qLower)) {
            String addr = routingAddrMap.get(qLower);
            options.add(new Map<String, String>{ 'label' => routingLabelMap.get(qLower), 'value' => addr });
            defaultFrom = addr;
            routingOrder.remove(routingOrder.indexOf(qLower));
        }

        // Thêm phần còn lại routing
        for (String lower : routingOrder) {
            options.add(new Map<String, String>{
                'label' => routingLabelMap.get(lower),
                'value' => routingAddrMap.get(lower)
            });
        }

        // Thêm OrgWide (tránh trùng)
        for (OrgWideEmailAddress owa : [
            SELECT Id, Address, DisplayName FROM OrgWideEmailAddress ORDER BY DisplayName ASC
        ]) {
            String owaLower = owa.Address.toLowerCase();
            if (!routingAddrMap.containsKey(owaLower)) {
                options.add(new Map<String, String>{
                    'label' => owa.DisplayName + ' <' + owa.Address + '>',
                    'value' => owa.Address
                });
            }
        }

        if (defaultFrom == null && !options.isEmpty()) {
            defaultFrom = options[0].get('value');
        }

        return new Map<String, Object>{
            'options'     => options,
            'defaultFrom' => defaultFrom
        };
    }

    private static final List<String> READONLY_FROM_LIST = new List<String>{
        FEC_ConstantCommon.EMAIL_READONLY_FROM_FECREDIT,
        FEC_ConstantCommon.EMAIL_READONLY_FROM_UBANK
    };

    // Các status không cho phép gửi email
    private static final Set<String> BLOCKED_STATUSES = new Set<String>{
        FEC_ConstantCommon.CASE_STATUS_CLOSED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED,
        FEC_ConstantCommon.CASE_STATUS_CANCELLED
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
        List<AttachmentWrapper> attachments,
        String titleReply
    ) {
        try {
            // 1. Validate case status
            Case c = [
                SELECT Id, Status, FEC_Interaction_Status__c, OwnerId, Subject
                FROM Case WHERE Id = :caseId LIMIT 1
            ];

            if (BLOCKED_STATUSES.contains(c.Status)) {
                throw new AuraHandledException(
                    Label.FEC_Email_Error_Blocked_Status + c.Status + '".'
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
            updateCaseAfterSend(caseId, fromEmail, toEmail, ccEmail, subject, titleReply);

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(Label.FEC_Email_Error_Send + e.getMessage());
        }
    }

    // ─── Private helpers ────────────────────────────────────────────────────

    private static void validateEmail(String email, String fieldLabel) {
        if (String.isBlank(email)) {
            throw new AuraHandledException(fieldLabel + Label.FEC_Email_Error_Empty);
        }
        // Basic email format check
        Pattern p = Pattern.compile(FEC_ConstantCommon.PATTERN_EMAIL);
        for (String addr : email.split(',')) {
            addr = addr.trim();
            if (String.isBlank(addr)) continue;
            if (!p.matcher(addr).matches()) {
                throw new AuraHandledException(
                    fieldLabel + Label.FEC_Email_Error_Invalid + addr + '"'
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
            Label.FEC_Email_Error_OrgWide_Not_Configured + fromEmail + Label.FEC_Email_Error_OrgWide_Not_Configured_Suffix
        );
    }

    private static void updateCaseAfterSend(
        String caseId, String fromEmail, String toEmail, String ccEmail, String subject, String titleReply
    ) {
        // Update case fields
        Case cUpdate = new Case(Id = caseId);
        if (String.isNotBlank(fromEmail))   cUpdate.FEC_Email_From__c  = fromEmail;
        if (String.isNotBlank(toEmail))     cUpdate.FEC_Send_To__c     = toEmail;
        if (String.isNotBlank(ccEmail))     cUpdate.FEC_Email_C__c     = ccEmail;
        if (String.isNotBlank(titleReply))  cUpdate.FEC_Title_Reply__c = titleReply;
        update cUpdate;

        // Create Task as audit log
        Task t = new Task();
        t.WhatId       = caseId;
        t.Subject      = 'Email Sent: ' + subject;
        t.Description  = 'From: ' + fromEmail + '\nTo: ' + toEmail
                       + (String.isNotBlank(ccEmail) ? '\nCC: ' + ccEmail : '');
        t.Status       = 'Completed';
        t.Priority     = 'Normal';
        t.ActivityDate = Date.today();
        insert t;
    }
}
