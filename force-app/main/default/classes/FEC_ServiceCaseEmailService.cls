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
        @AuraEnabled public String contentDocumentId { get; set; }
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
                ccEmail = ccEmail.replace(';', ',');
                List<String> ccList = new List<String>();
                for (String cc : ccEmail.split(',')) { if (String.isNotBlank(cc.trim())) ccList.add(cc.trim()); }
                if (!ccList.isEmpty()) mail.setCcAddresses(ccList);
            }
            mail.setSubject(subjectWithThread);
            // tungnm37 fix: Convert internal Salesforce image URLs (header/footer) sang public ContentDistribution URL
            // de Gmail/Outlook khong bi chan anh khi hien thi email
            String publicizedBody = FEC_CustomEmailService.publicizeImagesForEmail(body != null ? body : '');
            publicizedBody = FEC_CustomEmailService.wrapEmailBodyForConsistentWidth(publicizedBody);
            mail.setHtmlBody(publicizedBody);
            mail.setSaveAsActivity(false);
            // Không setWhatId để tránh Salesforce tự tạo EmailMessage thêm lần nữa

            // 5. Set From + ReplyTo = Email Service Address để khách reply về Salesforce
            setFromAndReplyTo(mail, fromEmail);

            // Validate attachment sizes: per-file 5MB, total 25MB (Salesforce email limits)
            if (attachments != null && !attachments.isEmpty()) {
                Integer totalSize = 0;
                for (AttachmentWrapper att : attachments) {
                    if (String.isNotBlank(att.base64Data)) {
                        // Base64 size ~ 4/3 of raw; 5MB raw ~ 6.67MB base64
                        if (att.base64Data.length() > 7000000) {
                            throw new AuraHandledException('File exceeds 5MB limit: ' + att.fileName);
                        }
                        totalSize += att.base64Data.length();
                    }
                }
                // Base64 size ~ 4/3 of raw; 25MB raw ~ 33.3MB base64
                if (totalSize > 33000000) {
                    throw new AuraHandledException('Total attachment size exceeds 25MB limit. Please reduce file size.');
                }
            }

            // 6. Attachments
            List<String> downloadLinkHtml = new List<String>();
            if (attachments != null && !attachments.isEmpty()) {
                // base64 (template/local) use EmailFileAttachment; ContentDocumentId split by size: <=2MB attach, >2MB use link.
                List<Messaging.EmailFileAttachment> efas = new List<Messaging.EmailFileAttachment>();
                Set<Id> docIdsToFetch = new Set<Id>();
                Map<Id, String> docIdToFileName = new Map<Id, String>();
                for (AttachmentWrapper att : attachments) {
                    if (String.isBlank(att.fileName)) continue;
                    if (String.isNotBlank(att.base64Data)) {
                        if (att.base64Data.length() > 7000000) {
                            throw new AuraHandledException('File exceeds 5MB limit: ' + att.fileName);
                        }
                        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                        efa.setFileName(att.fileName);
                        efa.setBody(EncodingUtil.base64Decode(att.base64Data));
                        efas.add(efa);
                    } else if (String.isNotBlank(att.contentDocumentId)) {
                        try {
                            Id docId = (Id) att.contentDocumentId;
                            docIdsToFetch.add(docId);
                            docIdToFileName.put(docId, att.fileName);
                        } catch (Exception idEx) {}
                    }
                }
                // Query ContentVersion to get ContentSize and Id for splitting
                Map<Id, Long> docIdToSize = new Map<Id, Long>();
                Map<Id, Id> docIdToCvId = new Map<Id, Id>();
                Map<Id, Id> cvIdToDocId = new Map<Id, Id>();
                if (!docIdsToFetch.isEmpty()) {
                    for (ContentVersion cv : [
                        SELECT Id, ContentDocumentId, ContentSize
                        FROM ContentVersion
                        WHERE ContentDocumentId IN :docIdsToFetch AND IsLatest = true
                    ]) {
                        docIdToSize.put(cv.ContentDocumentId, cv.ContentSize);
                        docIdToCvId.put(cv.ContentDocumentId, cv.Id);
                        cvIdToDocId.put(cv.Id, cv.ContentDocumentId);
                    }
                }
                // Split attachments: <=2MB attach directly; >2MB create public link
                Set<Id> entityAttachmentIds = new Set<Id>();
                if (!docIdsToFetch.isEmpty()) {
                    List<ContentDistribution> distsToInsert = new List<ContentDistribution>();
                    for (Id docId : docIdsToFetch) {
                        Long size = docIdToSize.get(docId);
                        if (size != null && size <= 2 * 1024 * 1024) {
                            // Small file: attach via setEntityAttachments
                            Id cvId = docIdToCvId.get(docId);
                            if (cvId != null) entityAttachmentIds.add(cvId);
                        } else {
                            // Large file: create ContentDistribution link
                            Id cvId = docIdToCvId.get(docId);
                            if (cvId != null) {
                                ContentDistribution cd = new ContentDistribution();
                                cd.ContentVersionId = cvId;
                                cd.Name = docIdToFileName.get(docId);
                                cd.PreferencesAllowOriginalDownload = true;
                                cd.PreferencesLinkLatestVersion = true;
                                cd.PreferencesNotifyOnVisit = false;
                                distsToInsert.add(cd);
                            }
                        }
                    }
                    if (!distsToInsert.isEmpty()) {
                        insert distsToInsert;
                        for (ContentDistribution cd : [SELECT Id, ContentVersionId, DistributionPublicUrl FROM ContentDistribution WHERE Id IN :distsToInsert]) {
                            String fName = docIdToFileName.get(cvIdToDocId.get(cd.ContentVersionId));
                            downloadLinkHtml.add('<a href="' + cd.DistributionPublicUrl + '">' + fName + '</a>');
                        }
                    }
                }
                if (!efas.isEmpty()) mail.setFileAttachments(efas);
                if (!entityAttachmentIds.isEmpty()) mail.setEntityAttachments(new List<Id>(entityAttachmentIds));
                if (!downloadLinkHtml.isEmpty()) {
                    String linkSection = '<p><strong>Attachments:</strong><br>' + String.join(downloadLinkHtml, '<br>') + '</p>';
                    mail.setHtmlBody(mail.getHtmlBody() + linkSection);
                }
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
                em.HtmlBody    = publicizedBody;
                em.TextBody    = body != null ? body.replaceAll('<[^>]+>', '') : '';
                em.Incoming    = false;
                em.Status      = '3';
                em.MessageDate = Datetime.now();
                insert em;

                // Store outgoing email attachments on the EmailMessage history record
                if (attachments != null && !attachments.isEmpty()) {
                    List<ContentVersion> cvs = new List<ContentVersion>();
                    List<ContentDocumentLink> links = new List<ContentDocumentLink>();
                    Set<Id> linkedDocIds = new Set<Id>();
                    for (AttachmentWrapper att : attachments) {
                        if (String.isBlank(att.fileName)) continue;
                        if (String.isNotBlank(att.contentDocumentId)) {
                            try {
                                Id docId = (Id) att.contentDocumentId;
                                if (!linkedDocIds.contains(docId)) {
                                    links.add(new ContentDocumentLink(
                                        ContentDocumentId = docId,
                                        LinkedEntityId = em.Id,
                                        ShareType = 'V',
                                        Visibility = 'AllUsers'
                                    ));
                                    linkedDocIds.add(docId);
                                }
                            } catch (Exception idEx) {}
                            continue;
                        }
                        if (String.isBlank(att.base64Data)) continue;
                        ContentVersion cv = new ContentVersion();
                        cv.Title = att.fileName.contains('.') ? att.fileName.substringBeforeLast('.') : att.fileName;
                        cv.PathOnClient = att.fileName;
                        cv.VersionData = EncodingUtil.base64Decode(att.base64Data);
                        cvs.add(cv);
                    }
                    if (!cvs.isEmpty()) {
                        insert cvs;
                        List<ContentVersion> insertedCvs = [
                            SELECT Id, ContentDocumentId
                            FROM ContentVersion
                            WHERE Id IN :cvs
                        ];
                        for (ContentVersion cv : insertedCvs) {
                            if (cv.ContentDocumentId == null || linkedDocIds.contains(cv.ContentDocumentId)) continue;
                            links.add(new ContentDocumentLink(
                                ContentDocumentId = cv.ContentDocumentId,
                                LinkedEntityId = em.Id,
                                ShareType = 'V',
                                Visibility = 'AllUsers'
                            ));
                        }
                    }
                    if (!links.isEmpty()) insert links;
                }
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