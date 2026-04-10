/**
 * Class Description: Service xử lý Auto Notification cho Internal User
 *   - Loại 3 (Email): Khi Case route đến Queue → gửi email đến FEC_Receivers__c
 *   - Loại 4 (SF App): Khi Case route đến Queue → gửi SF bell notification đến FEC_Receivers__c
 * Trigger: OwnerId thay đổi sang Queue
 * @created: 2026/04/06
 */
public without sharing class FEC_NotificationService {

    /**
     * Method Description: Gửi Email notification khi Case được route đến Queue
     * Điều kiện lọc Notification record:
     *   - FEC_Target_Group__c = 'Internal User'
     *   - FEC_Notification_Status__c = true (Active)
     *   - FEC_Notification_Channel__c.Name = 'Email'
     *   - FEC_Assigned_to_Queue__c khớp DeveloperName của Queue mới
     *   - Nature of Case (Product Type, Category, Sub Category, Sub Code) khớp
     *   - Trong khung giờ Schedule Start Time → Schedule End Time
     * @param newCases Danh sách Case sau update
     * @param oldMap Map chứa giá trị cũ
     * @return void
     * @created: 2026/04/06
     */
    public static void sendEmailNotifications(List<Case> newCases, Map<Id, Case> oldMap) {
        System.debug('--- [sendEmailNotifications] START cases=' + newCases.size());
        List<Case> routedCases = filterCasesRoutedToQueue(newCases, oldMap);
        System.debug('--- [sendEmailNotifications] routedCases=' + routedCases.size());
        if (routedCases.isEmpty()) return;

        Set<Id> queueIds = new Set<Id>();
        for (Case c : routedCases) queueIds.add(c.OwnerId);

        Map<String, Id> queueLookup = buildQueueLookupMap(queueIds);
        System.debug('--- [sendEmailNotifications] queueLookup=' + queueLookup);

        String channelEmail = FEC_ConstantCommon.NOTIFICATION_CHANNEL_EMAIL;
        String targetInternal = FEC_ConstantCommon.NOTIFICATION_TARGET_GROUP_INTERNAL;

        List<FEC_Notification__c> notifications = [
            SELECT Id,
                   FEC_Assigned_to_Queue__c,
                   FEC_Receivers__c,
                   FEC_Notification_Template__r.FEC_Subject_Line__c,
                   FEC_Notification_Template__r.FEC_Body__c,
                   FEC_Notification_Template__r.FEC_Active__c,
                   FEC_Notification_Template__r.FEC_Enhanced_Letterhead__c,
                   FEC_Product_Type__c,
                   FEC_Category__c,
                   FEC_SubCategory__c,
                   FEC_SubCode__c,
                   FEC_Schedule_Start_Time__c,
                   FEC_Schedule_End_Time__c
            FROM FEC_Notification__c
            WHERE FEC_Target_Group__c = :targetInternal
              AND FEC_Notification_Status__c = true
              AND FEC_Notification_Channel__r.Name = :channelEmail
              AND FEC_Assigned_to_Queue__c != null
        ];
        System.debug('--- [sendEmailNotifications] notifications queried=' + notifications.size());

        if (notifications.isEmpty()) return;

        Map<Id, List<FEC_Notification__c>> queueIdToNotifs = new Map<Id, List<FEC_Notification__c>>();
        for (FEC_Notification__c n : notifications) {
            if (String.isBlank(n.FEC_Receivers__c)) { System.debug('--- SKIP no receivers: ' + n.Id); continue; }
            String assignedVal = n.FEC_Assigned_to_Queue__c.trim();
            Id matchedQueueId = queueLookup.get(assignedVal);
            System.debug('--- notif assignedVal=[' + assignedVal + '] matchedQueueId=' + matchedQueueId);
            if (matchedQueueId == null) continue;
            if (!queueIdToNotifs.containsKey(matchedQueueId)) {
                queueIdToNotifs.put(matchedQueueId, new List<FEC_Notification__c>());
            }
            queueIdToNotifs.get(matchedQueueId).add(n);
        }
        System.debug('--- [sendEmailNotifications] queueIdToNotifs size=' + queueIdToNotifs.size());

        if (queueIdToNotifs.isEmpty()) return;

        Time nowTime = FEC_CommonUltils.getCurrentLocalTime();
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        // Lấy OrgWide sender 1 lần cho toàn bộ emails
        Id orgWideId = FEC_CommonUltils.getOrgWideEmailIdForNotification();

        // Cache letterhead đã xử lý để tránh query nhiều lần
        Map<Id, FEC_Enhanced_Letterhead__c> letterheadCache = new Map<Id, FEC_Enhanced_Letterhead__c>();

        // Bulk query ContentDocumentLink cho tất cả template
        Set<Id> templateIds = new Set<Id>();
        for (FEC_Notification__c n : notifications) {
            if (n.FEC_Notification_Template__c != null) templateIds.add(n.FEC_Notification_Template__c);
        }
        Map<Id, List<ContentVersion>> templateAttachments = new Map<Id, List<ContentVersion>>();
        if (!templateIds.isEmpty()) {
            Map<Id, Id> docToTemplate = new Map<Id, Id>();
            for (ContentDocumentLink link : [
                SELECT ContentDocumentId, LinkedEntityId, ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink WHERE LinkedEntityId IN :templateIds
            ]) {
                docToTemplate.put(link.ContentDocument.LatestPublishedVersionId, link.LinkedEntityId);
            }
            if (!docToTemplate.isEmpty()) {
                for (ContentVersion cv : [
                    SELECT Id, Title, FileExtension, VersionData
                    FROM ContentVersion WHERE Id IN :docToTemplate.keySet()
                ]) {
                    Id tId = docToTemplate.get(cv.Id);
                    if (!templateAttachments.containsKey(tId)) templateAttachments.put(tId, new List<ContentVersion>());
                    templateAttachments.get(tId).add(cv);
                }
            }
        }

        for (Case c : routedCases) {
            List<FEC_Notification__c> candidates = queueIdToNotifs.get(c.OwnerId);
            System.debug('--- case=' + c.Id + ' OwnerId=' + c.OwnerId + ' candidates=' + (candidates == null ? 0 : candidates.size()));
            if (candidates == null || candidates.isEmpty()) continue;

            for (FEC_Notification__c n : candidates) {
                Boolean natureOk = matchesNatureOfCase(c, n);
                Boolean scheduleOk = FEC_CommonUltils.isWithinSchedule(nowTime, n.FEC_Schedule_Start_Time__c, n.FEC_Schedule_End_Time__c);
                System.debug('--- notif=' + n.Id + ' natureOk=' + natureOk + ' scheduleOk=' + scheduleOk);
                if (!natureOk) continue;
                if (!scheduleOk) continue;

                List<String> toAddresses = FEC_CommonUltils.parseReceivers(n.FEC_Receivers__c);
                Boolean templateActive = n.FEC_Notification_Template__r?.FEC_Active__c == true;
                Boolean hasSubject = String.isNotBlank(n.FEC_Notification_Template__r?.FEC_Subject_Line__c);
                System.debug('--- toAddresses=' + toAddresses + ' templateActive=' + templateActive + ' hasSubject=' + hasSubject);
                if (toAddresses.isEmpty()) continue;
                if (!hasSubject) continue;
                if (!templateActive) continue;

                String subject = resolveTemplate(n.FEC_Notification_Template__r.FEC_Subject_Line__c, c);
                String bodyContent = String.isNotBlank(n.FEC_Notification_Template__r?.FEC_Body__c)
                    ? resolveTemplate(n.FEC_Notification_Template__r.FEC_Body__c, c) : '';

                // Wrap body với letterhead header/footer nếu có
                Id lhId = n.FEC_Notification_Template__r?.FEC_Enhanced_Letterhead__c;
                if (lhId != null) {
                    if (!letterheadCache.containsKey(lhId)) {
                        try {
                            FEC_Enhanced_Letterhead__c lh = [SELECT Id, FEC_Header__c, FEC_Footer__c FROM FEC_Enhanced_Letterhead__c WHERE Id = :lhId LIMIT 1];
                            letterheadCache.put(lhId, lh);
                        } catch (Exception e) {
                            System.debug('FEC Letterhead query failed: ' + e.getMessage());
                            letterheadCache.put(lhId, null);
                        }
                    }
                    FEC_Enhanced_Letterhead__c lh = letterheadCache.get(lhId);
                    if (lh != null) {
                        String header = String.isNotBlank(lh.FEC_Header__c) ? inlineImages(lh.FEC_Header__c) : '';
                        String footer = String.isNotBlank(lh.FEC_Footer__c) ? inlineImages(lh.FEC_Footer__c) : '';
                        bodyContent = header + bodyContent + footer;
                    }
                }

                Messaging.SingleEmailMessage mail = FEC_CommonUltils.buildEmailWithSender(toAddresses, subject, bodyContent, orgWideId);

                // Attach files từ ContentDocumentLink của template (đã bulk query)
                Id templateId = n.FEC_Notification_Template__c;
                if (templateId != null && templateAttachments.containsKey(templateId)) {
                    List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
                    for (ContentVersion cv : templateAttachments.get(templateId)) {
                        Messaging.EmailFileAttachment att = new Messaging.EmailFileAttachment();
                        att.setFileName(cv.Title + (String.isNotBlank(cv.FileExtension) ? '.' + cv.FileExtension : ''));
                        att.setBody(cv.VersionData);
                        attachments.add(att);
                    }
                    if (!attachments.isEmpty()) mail.setFileAttachments(attachments);
                }

                emailsToSend.add(mail);
                System.debug('--- email queued to=' + toAddresses + ' subject=' + subject);
            }
        }

        System.debug('--- [sendEmailNotifications] sending ' + emailsToSend.size() + ' emails');
        FEC_CommonUltils.sendEmails(emailsToSend);
    }

    /**
     * Method Description: Gửi SF App (bell) notification khi Case được route đến Queue khác
     * Điều kiện lọc tương tự nhưng FEC_Notification_Channel__c.Name = 'Salesforce App'
     * FEC_Receivers__c chứa email của User → query UserId để gửi notification
     * Click vào notification → navigate đến Case
     * @param newCases Danh sách Case sau update
     * @param oldMap Map chứa giá trị cũ
     * @return void
     * @created: 2026/04/06
     */
    public static void sendSFAppNotifications(List<Case> newCases, Map<Id, Case> oldMap) {
        List<Case> routedCases = filterCasesRoutedToQueue(newCases, oldMap);
        if (routedCases.isEmpty()) return;

        Set<Id> queueIds = new Set<Id>();
        for (Case c : routedCases) queueIds.add(c.OwnerId);

        Map<String, Id> queueLookup = buildQueueLookupMap(queueIds);

        String channelSfApp = FEC_ConstantCommon.NOTIFICATION_CHANNEL_SF_APP;
        String targetInternal = FEC_ConstantCommon.NOTIFICATION_TARGET_GROUP_INTERNAL;

        List<FEC_Notification__c> notifications = [
            SELECT Id,
                   FEC_Assigned_to_Queue__c,
                   FEC_Receivers__c,
                   FEC_Notification_Template__r.FEC_Subject_Line__c,
                   FEC_Notification_Template__r.FEC_Body__c,
                   FEC_Notification_Template__r.FEC_Active__c,
                   FEC_Product_Type__c,
                   FEC_Category__c,
                   FEC_SubCategory__c,
                   FEC_SubCode__c,
                   FEC_Schedule_Start_Time__c,
                   FEC_Schedule_End_Time__c
            FROM FEC_Notification__c
            WHERE FEC_Target_Group__c = :targetInternal
              AND FEC_Notification_Status__c = true
              AND FEC_Notification_Channel__r.Name = :channelSfApp
              AND FEC_Assigned_to_Queue__c != null
        ];

        if (notifications.isEmpty()) return;

        Map<Id, List<FEC_Notification__c>> queueIdToNotifs = new Map<Id, List<FEC_Notification__c>>();
        for (FEC_Notification__c n : notifications) {
            if (String.isBlank(n.FEC_Receivers__c)) continue;
            String assignedVal = n.FEC_Assigned_to_Queue__c.trim();
            Id matchedQueueId = queueLookup.get(assignedVal);
            if (matchedQueueId == null) continue;
            if (!queueIdToNotifs.containsKey(matchedQueueId)) {
                queueIdToNotifs.put(matchedQueueId, new List<FEC_Notification__c>());
            }
            queueIdToNotifs.get(matchedQueueId).add(n);
        }

        if (queueIdToNotifs.isEmpty()) return;

        // Collect all receiver emails to bulk-query User IDs
        Set<String> allEmails = new Set<String>();
        for (FEC_Notification__c n : notifications) {
            if (String.isBlank(n.FEC_Receivers__c)) continue;
            for (String email : FEC_CommonUltils.parseReceivers(n.FEC_Receivers__c)) {
                allEmails.add(email.toLowerCase());
            }
        }

        Map<String, Id> emailToUserId = new Map<String, Id>();
        if (!allEmails.isEmpty()) {
            for (User u : [SELECT Id, Email FROM User WHERE IsActive = true AND Email IN :allEmails]) {
                emailToUserId.put(u.Email.toLowerCase(), u.Id);
            }
        }

        // Load CustomNotificationType once
        CustomNotificationType notifType = null;
        try {
            notifType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Custom_Notification' LIMIT 1];
        } catch (Exception e) {
            System.debug('CustomNotificationType not found: ' + e.getMessage());
            return;
        }

        Time nowTime = FEC_CommonUltils.getCurrentLocalTime();

        for (Case c : routedCases) {
            List<FEC_Notification__c> candidates = queueIdToNotifs.get(c.OwnerId);
            if (candidates == null || candidates.isEmpty()) continue;

            for (FEC_Notification__c n : candidates) {
                if (!matchesNatureOfCase(c, n)) continue;
                if (!FEC_CommonUltils.isWithinSchedule(nowTime, n.FEC_Schedule_Start_Time__c, n.FEC_Schedule_End_Time__c)) continue;

                List<String> receiverEmails = FEC_CommonUltils.parseReceivers(n.FEC_Receivers__c);
                Set<String> recipientIds = new Set<String>();
                for (String email : receiverEmails) {
                    Id uid = emailToUserId.get(email.toLowerCase());
                    if (uid != null) recipientIds.add(String.valueOf(uid));
                }
                if (recipientIds.isEmpty()) continue;

                if (String.isBlank(n.FEC_Notification_Template__r?.FEC_Subject_Line__c)) continue;
                if (n.FEC_Notification_Template__r?.FEC_Active__c != true) continue;
                String title = resolveTemplate(n.FEC_Notification_Template__r.FEC_Subject_Line__c, c);
                String body = String.isNotBlank(n.FEC_Notification_Template__r?.FEC_Body__c)
                    ? resolveTemplate(n.FEC_Notification_Template__r.FEC_Body__c, c)
                    : '';

                FEC_CommonUltils.notifyUsers(recipientIds, c.Id, null, title, body, notifType);
            }
        }
    }

    // ─── Private helpers ────────────────────────────────────────────────────

    /**
     * Lọc các Case có OwnerId thay đổi sang Queue (khác Queue cũ)
     */
    private static List<Case> filterCasesRoutedToQueue(List<Case> newCases, Map<Id, Case> oldMap) {
        List<Case> result = new List<Case>();
        for (Case c : newCases) {
            if (c.OwnerId == null) continue;
            // Chỉ xử lý khi Owner mới là Queue
            if (c.OwnerId.getSObjectType() != Group.SObjectType) continue;
            Case old = oldMap.get(c.Id);
            // OwnerId phải thay đổi
            if (old != null && c.OwnerId == old.OwnerId) continue;
            result.add(c);
        }
        return result;
    }

    /**
     * Lấy DeveloperName của Queue từ danh sách Queue IDs
     * Trả về map Id → DeveloperName VÀ Id → Id (để match cả 2 format trong FEC_Assigned_to_Queue__c)
     */
    private static Map<Id, String> getQueueDeveloperNames(Set<Id> queueIds) {
        Map<Id, String> result = new Map<Id, String>();
        if (queueIds.isEmpty()) return result;
        for (Group g : [SELECT Id, DeveloperName FROM Group WHERE Id IN :queueIds AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE]) {
            result.put(g.Id, g.DeveloperName);
        }
        return result;
    }

    /**
     * Build lookup map: cả Queue ID (15/18 char) và DeveloperName → Queue Id
     * Để match FEC_Assigned_to_Queue__c dù lưu dạng nào
     */
    private static Map<String, Id> buildQueueLookupMap(Set<Id> queueIds) {
        Map<String, Id> result = new Map<String, Id>();
        if (queueIds.isEmpty()) return result;
        for (Group g : [SELECT Id, DeveloperName FROM Group WHERE Id IN :queueIds AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE]) {
            // Match by DeveloperName
            result.put(g.DeveloperName, g.Id);
            // Match by Id (15 char)
            result.put(String.valueOf(g.Id).substring(0, 15), g.Id);
            // Match by Id (18 char)
            result.put(String.valueOf(g.Id), g.Id);
        }
        return result;
    }

    /**
     * Kiểm tra Nature of Case của Case có khớp với Notification record không.
     * Nếu Notification không set field nào → match all (wildcard).
     */
    private static Boolean matchesNatureOfCase(Case c, FEC_Notification__c n) {
        if (n.FEC_Product_Type__c != null && n.FEC_Product_Type__c != c.FEC_Product_Type__c) return false;
        if (n.FEC_Category__c != null && n.FEC_Category__c != c.FEC_Category__c) return false;
        if (n.FEC_SubCategory__c != null && n.FEC_SubCategory__c != c.FEC_SubCategory__c) return false;
        if (n.FEC_SubCode__c != null && n.FEC_SubCode__c != c.FEC_SubCode__c) return false;
        return true;
    }

    /**
     * Convert rtaImage URLs trong HTML sang base64 inline để email client hiển thị được.
     * Tự detect org domain nên không cần hardcode URL.
     */
    private static String inlineImages(String html) {
        if (String.isBlank(html)) return html;
        // Tìm tất cả src="...rtaImage..." và replace bằng base64
        Pattern p = Pattern.compile('src="(https?://[^"]*rtaImage[^"]*)"');
        Matcher m = p.matcher(html);
        String result = html;
        while (m.find()) {
            String rawUrl = m.group(1);
            // Decode HTML entities trong URL (&amp; → &)
            String url = rawUrl.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>');
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(url);
                req.setMethod('GET');
                req.setTimeout(10000);
                req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
                Http http = new Http();
                HttpResponse res = http.send(req);
                Integer statusCode = res.getStatusCode();
                // Follow redirect nếu 302/301, statusCode == 200 bên dưới khác với statusCode ban đầu
                if (statusCode == 302 || statusCode == 301) {
                    String location = res.getHeader('Location');
                    if (String.isNotBlank(location)) {
                        HttpRequest req2 = new HttpRequest();
                        req2.setEndpoint(location);
                        req2.setMethod('GET');
                        req2.setTimeout(10000);
                        req2.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
                        res = http.send(req2);
                        statusCode = res.getStatusCode();
                    }
                }
                if (statusCode == 200 && res.getBodyAsBlob() != null && res.getBodyAsBlob().size() > 0) {
                    String contentType = res.getHeader('Content-Type') != null ? res.getHeader('Content-Type') : 'image/png';
                    if (contentType.contains(';')) contentType = contentType.substringBefore(';').trim();
                    String b64 = EncodingUtil.base64Encode(res.getBodyAsBlob());
                    String dataUri = 'data:' + contentType + ';base64,' + b64;
                    result = result.replace(rawUrl, dataUri);
                } else {
                    // Không inline được ảnh, giữ nguyên URL gốc trong HTML
                    System.debug('inlineImages: skip inline for url=' + url + ' | status=' + statusCode
                        + ' | bodySize=' + (res.getBodyAsBlob() != null ? res.getBodyAsBlob().size() : 0));
                }
            } catch (Exception e) {
                System.debug('inlineImages failed for url: ' + url + ' | ' + e.getMessage());
            }
        }
        return result;
    }

    /**
     * Thay thế placeholder {{FieldName}} trong template bằng giá trị từ Case
     */
    private static String resolveTemplate(String template, Case c) {
        if (String.isBlank(template)) return template;
        try {
            // Xử lý {{{Object.Field}}} (triple-brace) — convert sang {{Object.Field}}
            template = template.replaceAll('\\{\\{\\{([^}]+)\\}\\}\\}', '{{$1}}');
            // Resolve User.* fields từ current user
            Pattern userPat = Pattern.compile('\\{\\{User\\.([^}]+)\\}\\}');
            Matcher userMat = userPat.matcher(template);
            if (userMat.find()) {
                // Query User với tất cả fields cần thiết
                User u = [SELECT Id, Name, FirstName, LastName, Email, Phone, Title, Department, AboutMe, MobilePhone FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
                Matcher userMat2 = userPat.matcher(template);
                while (userMat2.find()) {
                    String fieldName = userMat2.group(1);
                    String val = '';
                    try { val = String.valueOf(u.get(fieldName)); } catch(Exception ex) {}
                    if (val == 'null') val = '';
                    template = template.replace('{{User.' + fieldName + '}}', val);
                }
            }
            return FEC_CommonUltils.resolveTemplate(template, c);
        } catch (Exception e) {
            return template;
        }
    }
}
