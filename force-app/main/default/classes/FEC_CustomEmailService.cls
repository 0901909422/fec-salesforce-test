/**
 * Custom email service cho FEC - thay thế FEC_InteractionEmailController
 * Bao gồm: validation, attachment, logging (Task), update case fields
 * @created: 2026/03/20
 */
public without sharing class FEC_CustomEmailService {

    @AuraEnabled
    public static Map<String, String> getInteractionEmail(String caseId) {
        Map<String, String> result = new Map<String, String>();
        Case c = [SELECT FEC_Send_To__c, FEC_Interaction_Email__c, RecordType.DeveloperName, FEC_Interaction__c, OwnerId, Owner.Type FROM Case WHERE Id = :caseId LIMIT 1];
        
        String sendTo = c.FEC_Send_To__c;
        String interactionEmail = c.FEC_Interaction_Email__c;
        
        // Nếu là Customer Case thì lấy từ Interaction parent
        if (String.isBlank(sendTo) && c.FEC_Interaction__c != null) {
            List<Case> parent = [SELECT FEC_Send_To__c, FEC_Interaction_Email__c FROM Case WHERE Id = :c.FEC_Interaction__c LIMIT 1];
            if (!parent.isEmpty()) {
                if (String.isBlank(sendTo)) sendTo = parent[0].FEC_Send_To__c;
                if (String.isBlank(interactionEmail)) interactionEmail = parent[0].FEC_Interaction_Email__c;
            }
        }

        // Fallback: nếu vẫn null thì lấy Queue email của case owner
        if (String.isBlank(sendTo) && c.Owner.Type == FEC_ConstantCommon.GROUP_TYPE_QUEUE) {
            try {
                Group q = [SELECT Email FROM Group WHERE Id = :c.OwnerId LIMIT 1];
                if (String.isNotBlank(q.Email)) sendTo = q.Email;
            } catch (Exception e) {
                System.debug('Queue email lookup failed: ' + e.getMessage());
            }
        }

        // Fallback: lấy từ EmailMessage incoming gần nhất
        if (String.isBlank(interactionEmail) || String.isBlank(sendTo)) {
            List<EmailMessage> incomingMsgs = [
                SELECT FromAddress, ToAddress FROM EmailMessage
                WHERE ParentId = :caseId AND Incoming = true
                ORDER BY MessageDate DESC LIMIT 1
            ];
            if (!incomingMsgs.isEmpty()) {
                if (String.isBlank(interactionEmail)) interactionEmail = incomingMsgs[0].FromAddress;
                if (String.isBlank(sendTo)) sendTo = incomingMsgs[0].ToAddress;
            }
        }

        // Fallback: tìm Customer Case có FEC_Interaction__c = caseId
        if (String.isBlank(sendTo) || String.isBlank(interactionEmail)) {
            List<Case> childCases = [
                SELECT FEC_Send_To__c, FEC_Interaction_Email__c
                FROM Case
                WHERE FEC_Interaction__c = :caseId
                AND (FEC_Send_To__c != null OR FEC_Interaction_Email__c != null)
                ORDER BY CreatedDate DESC LIMIT 1
            ];
            if (!childCases.isEmpty()) {
                if (String.isBlank(sendTo)) sendTo = childCases[0].FEC_Send_To__c;
                if (String.isBlank(interactionEmail)) interactionEmail = childCases[0].FEC_Interaction_Email__c;
            }
        }
        
        // Lấy tên của email routing address để format "Name <email>"
        String fromDisplay = sendTo != null ? sendTo : '';
        if (String.isNotBlank(sendTo)) {
            List<OrgWideEmailAddress> owas = [SELECT Address, DisplayName FROM OrgWideEmailAddress];
            for (OrgWideEmailAddress owa : owas) {
                if (owa.Address != null && owa.Address.equalsIgnoreCase(sendTo) && String.isNotBlank(owa.DisplayName)) {
                    fromDisplay = owa.DisplayName + ' <' + sendTo + '>';
                    break;
                }
            }
        }
        
        result.put('fromEmail', sendTo != null ? sendTo : '');
        result.put('fromDisplay', fromDisplay);
        result.put('toEmail', interactionEmail != null ? interactionEmail : '');
        return result;
    }

    @AuraEnabled
    public static String getCaseSubject(String caseId) {
        Case c = [SELECT Subject FROM Case WHERE Id = :caseId LIMIT 1];
        return c.Subject;
    }

    @AuraEnabled
    public static List<EmailMessage> getEmailMessages(String caseId) {
        return [
            SELECT Id, FromName, FromAddress, ToAddress, CcAddress,
                   Subject, TextBody, MessageDate, Incoming
            FROM EmailMessage
            WHERE ParentId = :caseId
            ORDER BY MessageDate DESC
            LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<SObject> getEmailTemplates() {
        return [
            SELECT Id, Name, FEC_Template_Name__c, FEC_Subject_Line__c, FEC_Body__c
            FROM FEC_Template__c
            WHERE FEC_Active__c = true
            ORDER BY FEC_Template_Name__c ASC
            LIMIT 100
        ];
    }

    @AuraEnabled
    public static String fetchImageAsBase64(String imageUrl) {
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(imageUrl);
            req.setMethod('GET');
            req.setTimeout(10000);
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                String contentType = res.getHeader('Content-Type');
                if (String.isBlank(contentType)) contentType = 'image/jpeg';
                if (contentType.contains(';')) contentType = contentType.substringBefore(';').trim();
                return 'data:' + contentType + ';base64,' + EncodingUtil.base64Encode(res.getBodyAsBlob());
            }
            return null;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
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
    public static String sendEmailV2(
        String caseId,
        String fromEmail,
        String toEmail,
        String ccEmail,
        String subject,
        String body,
        List<AttachmentWrapper> attachments,
        String titleReply
    ) {
        System.debug('### sendEmailV2 called: caseId=' + caseId + ' from=' + fromEmail + ' to=' + toEmail + ' subject=' + subject);
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
            mail.setHtmlBody(body != null ? body.replace('\n', '<br/>') : '');
            mail.setSaveAsActivity(false);

            // 4. Set OrgWideEmailAddress (From)
            System.debug('### Step 4: setFromAddress from=' + fromEmail);
            setFromAddress(mail, fromEmail);
            System.debug('### Step 5: attachments');

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
            System.debug('### About to sendEmail: from=' + fromEmail + ' to=' + toEmail);
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(
                new List<Messaging.SingleEmailMessage>{ mail }, false
            );
            if (!results.isEmpty() && !results[0].isSuccess()) {
                List<String> errs = new List<String>();
                for (Messaging.SendEmailError e : results[0].getErrors()) {
                    errs.add(e.getStatusCode() + ': ' + e.getMessage());
                }
                throw new AuraHandledException('Send failed: ' + String.join(errs, '; '));
            }

            // 7. Tạo EmailMessage outgoing để lưu lịch sử trong feed
            try {
                EmailMessage em = new EmailMessage();
                em.ParentId = caseId;
                em.FromAddress = fromEmail;
                em.ToAddress = toEmail;
                if (String.isNotBlank(ccEmail)) em.CcAddress = ccEmail;
                em.Subject = subject;
                em.HtmlBody = body;
                em.TextBody = body.replaceAll('<[^>]+>', '');
                em.Incoming = false;
                em.Status = '3';
                em.MessageDate = Datetime.now();
                insert em;
            } catch (Exception emEx) {
                System.debug('EmailMessage insert skipped: ' + emEx.getMessage());
            }

            // 8. Post-send: update case fields + create Task log
            updateCaseAfterSend(caseId, fromEmail, toEmail, ccEmail, subject, titleReply);
            System.debug('### sendEmail completed successfully');
            return 'OK';

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

        // Không có OrgWide → dùng EmailRoutingAddress (Email-to-Case)
        // Salesforce tự route qua routing address khi setWhatId = caseId
        // Chỉ set ReplyTo để khách hàng reply về đúng địa chỉ
        mail.setReplyTo(fromEmail);
    }

    private static void updateCaseAfterSend(
        String caseId, String fromEmail, String toEmail, String ccEmail, String subject, String titleReply
    ) {
        // Update case fields
        Case cUpdate = new Case(Id = caseId);
        if (String.isNotBlank(fromEmail))   cUpdate.FEC_Email_From__c  = fromEmail;
        if (String.isNotBlank(toEmail))     cUpdate.FEC_Send_To__c     = toEmail;
        if (String.isNotBlank(ccEmail))     cUpdate.FEC_Email_CC__c    = ccEmail;
        // FEC_Title_Reply__c is restricted picklist - skip update to avoid invalid value error
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
