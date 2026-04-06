/**
 * Email service riêng cho Customer Case / Internal Case
 * Luồng: gửi email đơn thuần, lưu lịch sử, nhận reply qua Email-to-Case
 */
public without sharing class FEC_ServiceCaseEmailService {

    private static final Set<String> BLOCKED_STATUSES = new Set<String>{
        FEC_ConstantCommon.CASE_STATUS_CLOSED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED,
        FEC_ConstantCommon.CASE_STATUS_CANCELLED
    };

    public class AttachmentWrapper {
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String base64Data { get; set; }
        @AuraEnabled public String mimeType { get; set; }
    }

    @AuraEnabled
    public static String sendEmail(
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
            Case c = [SELECT Id, Status FROM Case WHERE Id = :caseId LIMIT 1];
            if (BLOCKED_STATUSES.contains(c.Status)) {
                throw new AuraHandledException(
                    Label.FEC_Email_Error_Blocked_Status + c.Status + '".'
                );
            }

            // 2. Validate
            if (String.isBlank(toEmail)) throw new AuraHandledException(Label.FEC_Email_Error_To_Required);
            Pattern emailPattern = Pattern.compile(FEC_ConstantCommon.PATTERN_EMAIL);
            for (String addr : toEmail.split(',')) {
                if (!emailPattern.matcher(addr.trim()).matches()) {
                    throw new AuraHandledException('To ' + Label.FEC_Email_Error_Invalid + addr.trim() + '"');
                }
            }

            // 3. Append thread token để khách reply về đúng case
            String orgId = UserInfo.getOrganizationId();
            String threadToken = '[ ref:' + orgId.substring(0, 15) + '.' + caseId.substring(0, 15) + ':ref ]';
            String subjectWithThread = subject.contains('[ ref:') ? subject : subject + ' ' + threadToken;

            // 4. Build email
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(toEmail.split(','));
            if (String.isNotBlank(ccEmail)) {
                List<String> ccList = new List<String>();
                for (String cc : ccEmail.split(',')) { if (String.isNotBlank(cc.trim())) ccList.add(cc.trim()); }
                if (!ccList.isEmpty()) mail.setCcAddresses(ccList);
            }
            mail.setSubject(subjectWithThread);
            mail.setHtmlBody(body != null ? body : '');
            mail.setSaveAsActivity(false);
            // Không setWhatId để tránh Salesforce tự tạo EmailMessage thêm lần nữa

            // 5. Set From + ReplyTo = Email Service Address để khách reply về Salesforce
            setFromAndReplyTo(mail, fromEmail);

            // 6. Attachments
            if (attachments != null && !attachments.isEmpty()) {
                List<Messaging.EmailFileAttachment> efas = new List<Messaging.EmailFileAttachment>();
                for (AttachmentWrapper att : attachments) {
                    if (String.isBlank(att.base64Data) || String.isBlank(att.fileName)) continue;
                    Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                    efa.setFileName(att.fileName);
                    efa.setBody(EncodingUtil.base64Decode(att.base64Data));
                    if (String.isNotBlank(att.mimeType)) efa.setContentType(att.mimeType);
                    efas.add(efa);
                }
                if (!efas.isEmpty()) mail.setFileAttachments(efas);
            }

            // 7. Send
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(
                new List<Messaging.SingleEmailMessage>{ mail }, false
            );
            if (!results.isEmpty() && !results[0].isSuccess()) {
                List<String> errs = new List<String>();
                for (Messaging.SendEmailError e : results[0].getErrors()) errs.add(e.getMessage());
                throw new AuraHandledException('Send failed: ' + String.join(errs, '; '));
            }

            // 8. Lưu lịch sử EmailMessage outgoing
            try {
                EmailMessage em = new EmailMessage();
                em.ParentId    = caseId;
                em.FromAddress = fromEmail;
                em.ToAddress   = toEmail;
                if (String.isNotBlank(ccEmail)) em.CcAddress = ccEmail;
                em.Subject     = subjectWithThread;
                em.HtmlBody    = body;
                em.TextBody    = body != null ? body.replaceAll('<[^>]+>', '') : '';
                em.Incoming    = false;
                em.Status      = '3';
                em.MessageDate = Datetime.now();
                insert em;
            } catch (Exception emEx) {
                System.debug('EmailMessage insert skipped: ' + emEx.getMessage());
            }

            return 'OK';

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(Label.FEC_Email_Error_Send + e.getMessage());
        }
    }

    private static void setFromAndReplyTo(Messaging.SingleEmailMessage mail, String fromEmail) {
        if (String.isBlank(fromEmail)) return;
        // OrgWide
        List<OrgWideEmailAddress> owas = [SELECT Id FROM OrgWideEmailAddress WHERE Address = :fromEmail LIMIT 1];
        if (!owas.isEmpty()) mail.setOrgWideEmailAddressId(owas[0].Id);
        // Email Service Address để khách reply về Salesforce
        try {
            List<SObject> routings = Database.query(
                'SELECT EmailServiceAddress FROM EmailRoutingAddress WHERE Address = :fromEmail LIMIT 1'
            );
            if (!routings.isEmpty()) {
                String svcAddr = (String) routings[0].get('EmailServiceAddress');
                if (String.isNotBlank(svcAddr)) mail.setReplyTo(svcAddr);
            }
        } catch (Exception e) {
            System.debug('EmailServiceAddress lookup failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> getFromAddresses(String caseId) {
        return FEC_CustomEmailService.getFromAddresses(caseId);
    }
}
