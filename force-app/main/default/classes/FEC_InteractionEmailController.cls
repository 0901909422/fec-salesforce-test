/**
 * Controller gửi email từ Interaction Case đến KH
 * @created: 2026/03/18 tungnm37
 * @updated: 2026/03/18 tungnm37 — thêm CC, From, getEmailTemplates
 */
public without sharing class FEC_InteractionEmailController {

    private static final List<String> READONLY_FROM_LIST = new List<String>{
        'dichvukhachhang@fecredit.com.vn',
        'dichvukhachhang@ubank.com.vn'
    };

    @AuraEnabled
    public static Map<String, String> getInteractionEmail(String caseId) {
        Map<String, String> result = new Map<String, String>();

        // Lấy incoming EmailMessage đầu tiên của Case
        List<EmailMessage> msgs = [
            SELECT FromAddress, ToAddress FROM EmailMessage
            WHERE ParentId = :caseId AND Incoming = true
            ORDER BY MessageDate ASC LIMIT 1
        ];

        if (!msgs.isEmpty()) {
            // To = email khách hàng gửi đến (FromAddress của incoming message)
            result.put('toEmail', msgs[0].FromAddress);
            // From = mailbox nhận email (ToAddress của incoming message)
            result.put('fromEmail', msgs[0].ToAddress);
        } else {
            // Không có incoming email → để trống
            result.put('toEmail', '');
            result.put('fromEmail', '');
        }
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
    public static List<EmailTemplate> getEmailTemplates() {
        return [
            SELECT Id, Name, HtmlValue, Body
            FROM EmailTemplate
            WHERE IsActive = true
            ORDER BY Name ASC
            LIMIT 100
        ];
    }

    @AuraEnabled
    public static void sendEmailToCustomer(
        String caseId,
        String fromEmail,
        String toEmail,
        String ccEmail,
        String subject,
        String body
    ) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ toEmail });

            if (String.isNotBlank(ccEmail)) {
                mail.setCcAddresses(new List<String>{ ccEmail });
            }

            mail.setSubject(subject);
            mail.setHtmlBody(body.replace('\n', '<br/>'));
            mail.setWhatId(caseId);
            mail.setSaveAsActivity(true);

            // Nếu From là readonly address → dùng OrgWideEmailAddress
            String fromLower = String.isNotBlank(fromEmail) ? fromEmail.toLowerCase() : '';
            Boolean useOrgWide = READONLY_FROM_LIST.contains(fromLower);

            if (useOrgWide) {
                List<OrgWideEmailAddress> orgEmails = [
                    SELECT Id, Address FROM OrgWideEmailAddress
                    WHERE Address = :fromEmail
                    LIMIT 1
                ];
                if (!orgEmails.isEmpty()) {
                    mail.setOrgWideEmailAddressId(orgEmails[0].Id);
                } else {
                    // Fallback: tìm theo label
                    List<OrgWideEmailAddress> fallback = [
                        SELECT Id FROM OrgWideEmailAddress
                        WHERE Address = :System.Label.UBankCustomberServiceEmail
                        LIMIT 1
                    ];
                    if (!fallback.isEmpty()) {
                        mail.setOrgWideEmailAddressId(fallback[0].Id);
                    }
                }
            } else if (String.isNotBlank(fromEmail)) {
                // Mailbox nội bộ — tìm OrgWideEmailAddress tương ứng
                List<OrgWideEmailAddress> orgEmails = [
                    SELECT Id FROM OrgWideEmailAddress
                    WHERE Address = :fromEmail
                    LIMIT 1
                ];
                if (!orgEmails.isEmpty()) {
                    mail.setOrgWideEmailAddressId(orgEmails[0].Id);
                }
            }

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
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
                // Strip charset if present
                if (contentType.contains(';')) contentType = contentType.substringBefore(';').trim();
                String b64 = EncodingUtil.base64Encode(res.getBodyAsBlob());
                return 'data:' + contentType + ';base64,' + b64;
            }
            return null;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
