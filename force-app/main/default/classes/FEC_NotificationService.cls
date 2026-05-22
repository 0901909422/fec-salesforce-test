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
                   Name,
                   FEC_Assigned_to_Queue__c,
                   FEC_Receivers__c,
                   FEC_Product_Type__c,
                   FEC_Category__c,
                   FEC_SubCategory__c,
                   FEC_SubCode__c,
                   FEC_Customer_Type__c,
                   FEC_Schedule_Start_Time__c,
                   FEC_Schedule_End_Time__c
            FROM FEC_Notification__c
            WHERE FEC_Target_Group__c = :targetInternal
              AND FEC_Notification_Status__c = true
              AND FEC_Assigned_to_Queue__c != null
        ];
        Map<Id, List<FEC_Notification_Template_Channel__c>> templateChannelsByNotificationId = loadTemplateChannels(notifications);
        Map<Id, FEC_Notification_Channel__c> channelById = loadNotificationChannels(templateChannelsByNotificationId);
        Map<Id, FEC_Template__c> templateById = loadTemplates(templateChannelsByNotificationId);
        System.debug('--- [sendEmailNotifications] notifications queried=' + notifications.size());

        if (notifications.isEmpty()) return;

        Map<Id, List<FEC_Notification__c>> queueIdToNotifs = new Map<Id, List<FEC_Notification__c>>();
        for (FEC_Notification__c n : notifications) {
            if (String.isBlank(n.FEC_Receivers__c)) { System.debug('--- SKIP no receivers: ' + n.Id); continue; }
            List<FEC_Notification_Template_Channel__c> templateChannels = templateChannelsByNotificationId.get(n.Id);
            if (!hasChannelName(templateChannels, channelById, channelEmail)) continue;
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

        Set<Id> routedCaseIds = new Set<Id>();
        for (Case rc : routedCases) {
            routedCaseIds.add(rc.Id);
        }
        Map<Id, Case> caseStageById = routedCaseIds.isEmpty()
            ? new Map<Id, Case>()
            : new Map<Id, Case>([
                  SELECT Id,
                         FEC_Stage_Name__c,
                         FEC_Customer_Type__c,
                         FEC_Product_Type__c,
                         FEC_Category__c,
                         FEC_SubCategory__c,
                         FEC_SubCode__c
                  FROM Case
                  WHERE Id IN :routedCaseIds
              ]);

        Time nowTime = FEC_CommonUltils.getCurrentLocalTime();
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        List<AutoEmailHistoryMeta> emailHistoryMetas = new List<AutoEmailHistoryMeta>();

        // Lấy OrgWide sender 1 lần cho toàn bộ emails
        Id orgWideId = FEC_CommonUltils.getOrgWideEmailIdForNotification();

        // Cache letterhead đã xử lý để tránh query nhiều lần
        Map<Id, FEC_Enhanced_Letterhead__c> letterheadCache = new Map<Id, FEC_Enhanced_Letterhead__c>();

        // Bulk query ContentDocumentLink cho tất cả template
        Set<Id> templateIds = new Set<Id>(templateById.keySet());
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
                Case cNature = caseStageById.get(c.Id);
                Boolean natureOk = matchesNatureOfCase(cNature != null ? cNature : c, n);
                Boolean scheduleOk = FEC_CommonUltils.isWithinSchedule(nowTime, n.FEC_Schedule_Start_Time__c, n.FEC_Schedule_End_Time__c);
                System.debug('--- notif=' + n.Id + ' natureOk=' + natureOk + ' scheduleOk=' + scheduleOk);
                if (!natureOk) continue;
                if (!scheduleOk) continue;

                List<String> toAddresses = FEC_CommonUltils.parseReceivers(n.FEC_Receivers__c);
                FEC_Template__c templateRow = getTemplateForChannel(templateChannelsByNotificationId.get(n.Id), channelById, templateById, channelEmail);
                Boolean templateActive = templateRow != null && templateRow.FEC_Active__c == true;
                Boolean hasSubject = templateRow != null && String.isNotBlank(templateRow.FEC_Subject_Line__c);
                System.debug('--- toAddresses=' + toAddresses);
                if (toAddresses.isEmpty()) continue;
                if (!hasSubject) continue;
                if (!templateActive) continue;

                String subject = resolveTemplate(templateRow.FEC_Subject_Line__c, c);
                String bodyContent = String.isNotBlank(templateRow.FEC_Body__c)
                    ? resolveTemplate(templateRow.FEC_Body__c, c) : '';

                // Wrap body với letterhead header/footer nếu có
                Id lhId = templateRow.FEC_Enhanced_Letterhead__c;
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
                Id templateId = templateRow != null ? templateRow.Id : null;
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
                Case cStageRow = caseStageById.get(c.Id);
                String stageNm = cStageRow != null ? cStageRow.FEC_Stage_Name__c : null;
                String tmplNm = templateRow != null ? templateRow.Name : null;
                String chNm = getChannelName(templateChannelsByNotificationId.get(n.Id), channelById, channelEmail);
                AutoEmailHistoryMeta histMeta = new AutoEmailHistoryMeta();
                histMeta.caseId = c.Id;
                histMeta.notificationRuleId = n.Id;
                histMeta.stageName = stageNm;
                histMeta.templateName = tmplNm;
                histMeta.notificationRuleName = n.Name;
                histMeta.channelName = chNm;
                histMeta.targetGroup = targetInternal;
                emailHistoryMetas.add(histMeta);
                System.debug('--- email queued to=' + toAddresses + ' subject=' + subject);
            }
        }

        System.debug('--- [sendEmailNotifications] sending ' + emailsToSend.size() + ' emails');
        List<Messaging.SendEmailResult> emailResults = new List<Messaging.SendEmailResult>();
        if (emailsToSend != null && !emailsToSend.isEmpty()) {
            try {
                emailResults = Messaging.sendEmail(emailsToSend, false);
            } catch (Exception e) {
                System.debug('FEC_NotificationService.sendEmailNotifications: ' + e.getMessage());
            }
        }
        persistAutoEmailNotificationHistory(emailResults, emailHistoryMetas);
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
                   Name,
                   FEC_Assigned_to_Queue__c,
                   FEC_Receivers__c,
                   FEC_Product_Type__c,
                   FEC_Category__c,
                   FEC_SubCategory__c,
                   FEC_SubCode__c,
                   FEC_Customer_Type__c,
                   FEC_Schedule_Start_Time__c,
                   FEC_Schedule_End_Time__c
            FROM FEC_Notification__c
            WHERE FEC_Target_Group__c = :targetInternal
              AND FEC_Notification_Status__c = true
              AND FEC_Assigned_to_Queue__c != null
        ];
        Map<Id, List<FEC_Notification_Template_Channel__c>> templateChannelsByNotificationId = loadTemplateChannels(notifications);
        Map<Id, FEC_Notification_Channel__c> channelById = loadNotificationChannels(templateChannelsByNotificationId);
        Map<Id, FEC_Template__c> templateById = loadTemplates(templateChannelsByNotificationId);

        if (notifications.isEmpty()) return;

        Map<Id, List<FEC_Notification__c>> queueIdToNotifs = new Map<Id, List<FEC_Notification__c>>();
        for (FEC_Notification__c n : notifications) {
            if (String.isBlank(n.FEC_Receivers__c)) continue;
            List<FEC_Notification_Template_Channel__c> templateChannels = templateChannelsByNotificationId.get(n.Id);
            if (!hasChannelName(templateChannels, channelById, channelSfApp)) continue;
            String assignedVal = n.FEC_Assigned_to_Queue__c.trim();
            Id matchedQueueId = queueLookup.get(assignedVal);
            if (matchedQueueId == null) continue;
            if (!queueIdToNotifs.containsKey(matchedQueueId)) {
                queueIdToNotifs.put(matchedQueueId, new List<FEC_Notification__c>());
            }
            queueIdToNotifs.get(matchedQueueId).add(n);
        }

        if (queueIdToNotifs.isEmpty()) return;

        Set<Id> routedCaseIdsSf = new Set<Id>();
        for (Case rc2 : routedCases) {
            routedCaseIdsSf.add(rc2.Id);
        }
        Map<Id, Case> caseStageByIdSf = routedCaseIdsSf.isEmpty()
            ? new Map<Id, Case>()
            : new Map<Id, Case>([
                  SELECT Id,
                         FEC_Stage_Name__c,
                         FEC_Customer_Type__c,
                         FEC_Product_Type__c,
                         FEC_Category__c,
                         FEC_SubCategory__c,
                         FEC_SubCode__c
                  FROM Case
                  WHERE Id IN :routedCaseIdsSf
              ]);

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
        List<FEC_Notification_History__c> sfAppHistoryRows = new List<FEC_Notification_History__c>();

        for (Case c : routedCases) {
            List<FEC_Notification__c> candidates = queueIdToNotifs.get(c.OwnerId);
            if (candidates == null || candidates.isEmpty()) continue;

            for (FEC_Notification__c n : candidates) {
                Case cNatureSf = caseStageByIdSf.get(c.Id);
                if (!matchesNatureOfCase(cNatureSf != null ? cNatureSf : c, n)) continue;
                if (!FEC_CommonUltils.isWithinSchedule(nowTime, n.FEC_Schedule_Start_Time__c, n.FEC_Schedule_End_Time__c)) continue;

                List<String> receiverEmails = FEC_CommonUltils.parseReceivers(n.FEC_Receivers__c);
                Set<String> recipientIds = new Set<String>();
                for (String email : receiverEmails) {
                    Id uid = emailToUserId.get(email.toLowerCase());
                    if (uid != null) recipientIds.add(String.valueOf(uid));
                }
                if (recipientIds.isEmpty()) continue;

                FEC_Template__c templateRow = getTemplateForChannel(templateChannelsByNotificationId.get(n.Id), channelById, templateById, channelSfApp);
                if (templateRow == null || String.isBlank(templateRow.FEC_Subject_Line__c)) continue;
                if (templateRow.FEC_Active__c != true) continue;
                String title = resolveTemplate(templateRow.FEC_Subject_Line__c, c);
                String body = String.isNotBlank(templateRow.FEC_Body__c)
                    ? resolveTemplate(templateRow.FEC_Body__c, c)
                    : '';

                Boolean sentOk = sendCustomAppNotification(recipientIds, c.Id, title, body, notifType);
                Case cSfSt = caseStageByIdSf.get(c.Id);
                String stNameSf = cSfSt != null ? cSfSt.FEC_Stage_Name__c : null;
                String tmplNmSf = templateRow != null ? templateRow.Name : null;
                String chNmSf = getChannelName(templateChannelsByNotificationId.get(n.Id), channelById, channelSfApp);
                sfAppHistoryRows.add(
                    FEC_NotificationHistoryService.buildRow(
                        c.Id,
                        n.Id,
                        stNameSf,
                        tmplNmSf,
                        n.Name,
                        chNmSf,
                        targetInternal,
                        FEC_NotificationHistoryService.SEND_TYPE_AUTO,
                        sentOk ? FEC_NotificationHistoryService.SEND_STATUS_SUCCESS : FEC_NotificationHistoryService.SEND_STATUS_FAILURE,
                        sentOk ? null : 'Salesforce App notification send failed',
                        FEC_NotificationHistoryService.SEND_USER_SYSTEM,
                        null,
                        System.now()
                    )
                );
            }
        }
        FEC_NotificationHistoryService.insertRows(sfAppHistoryRows);
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

    private static Map<Id, List<FEC_Notification_Template_Channel__c>> loadTemplateChannels(List<FEC_Notification__c> notifications) {
        Set<Id> notificationIds = new Set<Id>();
        for (FEC_Notification__c n : notifications) {
            if (n.Id != null) notificationIds.add(n.Id);
        }
        Map<Id, List<FEC_Notification_Template_Channel__c>> result = new Map<Id, List<FEC_Notification_Template_Channel__c>>();
        if (notificationIds.isEmpty()) return result;

        for (FEC_Notification_Template_Channel__c row : [
            SELECT Id, FEC_Notification__c, FEC_Notification_Channel__c, FEC_Notification_Template__c
            FROM FEC_Notification_Template_Channel__c
            WHERE FEC_Notification__c IN :notificationIds
        ]) {
            if (!result.containsKey(row.FEC_Notification__c)) {
                result.put(row.FEC_Notification__c, new List<FEC_Notification_Template_Channel__c>());
            }
            result.get(row.FEC_Notification__c).add(row);
        }
        return result;
    }

    private static Map<Id, FEC_Notification_Channel__c> loadNotificationChannels(Map<Id, List<FEC_Notification_Template_Channel__c>> templateChannelsByNotificationId) {
        Set<Id> channelIds = new Set<Id>();
        for (List<FEC_Notification_Template_Channel__c> rows : templateChannelsByNotificationId.values()) {
            for (FEC_Notification_Template_Channel__c row : rows) {
                if (row.FEC_Notification_Channel__c != null) channelIds.add(row.FEC_Notification_Channel__c);
            }
        }
        return channelIds.isEmpty()
            ? new Map<Id, FEC_Notification_Channel__c>()
            : new Map<Id, FEC_Notification_Channel__c>([
                SELECT Id, Name
                FROM FEC_Notification_Channel__c
                WHERE Id IN :channelIds
            ]);
    }

    private static Map<Id, FEC_Template__c> loadTemplates(Map<Id, List<FEC_Notification_Template_Channel__c>> templateChannelsByNotificationId) {
        Set<Id> templateIds = new Set<Id>();
        for (List<FEC_Notification_Template_Channel__c> rows : templateChannelsByNotificationId.values()) {
            for (FEC_Notification_Template_Channel__c row : rows) {
                if (row.FEC_Notification_Template__c != null) templateIds.add(row.FEC_Notification_Template__c);
            }
        }
        return templateIds.isEmpty()
            ? new Map<Id, FEC_Template__c>()
            : new Map<Id, FEC_Template__c>([
                SELECT Id, Name, FEC_Subject_Line__c, FEC_Body__c, FEC_Active__c, FEC_Enhanced_Letterhead__c
                FROM FEC_Template__c
                WHERE Id IN :templateIds
            ]);
    }

    private static Boolean hasChannelName(
        List<FEC_Notification_Template_Channel__c> templateChannels,
        Map<Id, FEC_Notification_Channel__c> channelById,
        String expectedChannelName
    ) {
        if (templateChannels == null || templateChannels.isEmpty()) return false;
        for (FEC_Notification_Template_Channel__c row : templateChannels) {
            FEC_Notification_Channel__c channelRow = channelById.get(row.FEC_Notification_Channel__c);
            if (channelRow != null && channelRow.Name == expectedChannelName) return true;
        }
        return false;
    }

    private static FEC_Template__c getTemplateForChannel(
        List<FEC_Notification_Template_Channel__c> templateChannels,
        Map<Id, FEC_Notification_Channel__c> channelById,
        Map<Id, FEC_Template__c> templateById,
        String expectedChannelName
    ) {
        if (templateChannels == null || templateChannels.isEmpty()) return null;
        for (FEC_Notification_Template_Channel__c row : templateChannels) {
            FEC_Notification_Channel__c channelRow = channelById.get(row.FEC_Notification_Channel__c);
            if (channelRow != null && channelRow.Name == expectedChannelName) {
                return templateById.get(row.FEC_Notification_Template__c);
            }
        }
        return null;
    }

    private static String getChannelName(
        List<FEC_Notification_Template_Channel__c> templateChannels,
        Map<Id, FEC_Notification_Channel__c> channelById,
        String fallbackChannelName
    ) {
        if (templateChannels != null) {
            for (FEC_Notification_Template_Channel__c row : templateChannels) {
                FEC_Notification_Channel__c channelRow = channelById.get(row.FEC_Notification_Channel__c);
                if (channelRow != null && String.isNotBlank(channelRow.Name)) return channelRow.Name;
            }
        }
        return fallbackChannelName;
    }

    /**
     * Kiểm tra Nature of Case của Case có khớp với Notification record không.
     * Nếu Notification không set field nào → match all (wildcard).
     */
    private static Boolean matchesNatureOfCase(Case c, FEC_Notification__c n) {
        if (String.isNotBlank(n.FEC_Customer_Type__c) && !FEC_CommonUltils.notificationCustomerTypeMatchesCase(n.FEC_Customer_Type__c, c.FEC_Customer_Type__c)) {
            return false;
        }
        if (n.FEC_Product_Type__c != null && n.FEC_Product_Type__c != c.FEC_Product_Type__c) return false;
        if (n.FEC_Category__c != null && n.FEC_Category__c != c.FEC_Category__c) return false;

        String caseSubCategory = String.valueOf(c.get('FEC_SubCategory__c'));
        String caseSubCode = String.valueOf(c.get('FEC_SubCode__c'));

        if (String.isNotBlank(n.FEC_SubCategory__c) && !containsConfiguredValue(n.FEC_SubCategory__c, caseSubCategory)) {
            return false;
        }
        if (String.isNotBlank(n.FEC_SubCode__c) && !containsConfiguredValue(n.FEC_SubCode__c, caseSubCode)) {
            return false;
        }
        return true;
    }

    private static Boolean containsConfiguredValue(String configuredValues, String caseValue) {
        if (String.isBlank(configuredValues)) return true;
        if (String.isBlank(caseValue)) return false;

        String normalizedCaseValue = caseValue.trim().toLowerCase();
        for (String token : configuredValues.split('[;,\\n\\r]+')) {
            if (String.isBlank(token)) continue;
            if (token.trim().toLowerCase() == normalizedCaseValue) {
                return true;
            }
        }
        return false;
    }

    /**
     * Convert rtaImage URLs trong HTML sang base64 inline để email client hiển thị được.
     * Tự detect org domain nên không cần hardcode URL.
     */
    public static String inlineImages(String html) {
        if (String.isBlank(html)) return html;
        // Tìm tất cả src="...rtaImage..." và replace bằng base64
        Pattern p = Pattern.compile('src="(https?://[^"]*rtaImage[^"]*)"');
        Matcher m = p.matcher(html);
        String result = html;
        while (m.find()) {
            String rawUrl = m.group(1);
            // Decode HTML entities trong URL (&amp; → &)
            String url = rawUrl.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>');
            System.debug('--- [inlineImages] Processing URL: ' + url);
            try {
                PageReference pr = new PageReference(url);
                Blob imageBlob = Test.isRunningTest() ? Blob.valueOf('Mock Image') : pr.getContent();
                if (imageBlob != null && imageBlob.size() > 0) {
                    String contentType = 'image/png';
                    String b64 = EncodingUtil.base64Encode(imageBlob);
                    String dataUri = 'data:' + contentType + ';base64,' + b64;
                    result = result.replace(rawUrl, dataUri);
                    System.debug('--- [inlineImages] SUCCESS: Inlined URL using PageReference: ' + url);
                } else {
                    // Không inline được ảnh, giữ nguyên URL gốc trong HTML
                    System.debug('inlineImages: skip inline for url=' + url + ' | empty blob');
                }
            } catch (Exception e) {
                System.debug('inlineImages failed for url: ' + url + ' | ' + e.getMessage());
            }
        }
        System.debug('--- [inlineImages] Final Result (first 200 chars): ' + result);
        return result;
    }

    /**
     * Thay thế placeholder {{FieldName}} trong template bằng giá trị từ Case
     */
    private static String resolveTemplate(String template, Case c) {
        if (String.isBlank(template)) return template;
        try {
            // Normalize: convert {{{...}}} → {{...}}
            template = template.replaceAll(FEC_ConstantCommon.PATTERN_TRIPLE_BRACE, '{{$1}}');
            System.debug('resolveTemplate after triple convert: ' + template.left(100));
            // Resolve User.* fields từ current user
            Pattern userPat = Pattern.compile(FEC_ConstantCommon.PATTERN_USER_MERGE_FIELD);
            Matcher userMat = userPat.matcher(template);
            if (userMat.find()) {
                // Collect all User field names needed
                Set<String> userFieldNames = new Set<String>{'Id'};
                Matcher userMatCollect = userPat.matcher(template);
                while (userMatCollect.find()) { userFieldNames.add(userMatCollect.group(1)); }
                // Dynamic query to get all needed fields
                String userSoql = 'SELECT ' + String.join(new List<String>(userFieldNames), ', ') + ' FROM User WHERE Id = :userId LIMIT 1';
                Id userId = UserInfo.getUserId();
                List<User> users = new List<User>();
                try { users = Database.query(userSoql); } catch(Exception qEx) {
                    // Fallback: query standard fields only
                    users = [SELECT Id, Name, FirstName, LastName, Email, Phone, Title, Department, AboutMe, MobilePhone FROM User WHERE Id = :userId LIMIT 1];
                }
                if (!users.isEmpty()) {
                    User u = users[0];
                    Matcher userMat2 = userPat.matcher(template);
                    while (userMat2.find()) {
                        String fieldName = userMat2.group(1);
                        String val = '';
                        try { Object fv = u.get(fieldName); val = fv != null ? String.valueOf(fv) : ''; } catch(Exception ex) {}
                        template = template.replace('{{User.' + fieldName + '}}', val);
                    }
                }
                System.debug('resolveTemplate after user resolve: ' + template.left(100));
            }
            // Re-query Case với dynamic fields từ template
            if (c != null && c.Id != null && template.contains('{{')) {
                try {
                    // Extract tất cả Case.* fields từ template
                    Pattern casePat = Pattern.compile(FEC_ConstantCommon.PATTERN_CASE_MERGE_FIELD);
                    Matcher caseMat = casePat.matcher(template);
                    Set<String> caseFields = new Set<String>{'Id'};
                    while (caseMat.find()) { caseFields.add(caseMat.group(1)); }

                    // Build dynamic SOQL
                    String caseSoql = 'SELECT ' + String.join(new List<String>(caseFields), ', ') + ' FROM Case WHERE Id = :cId LIMIT 1';
                    Id cId = c.Id;
                    List<Case> caseList = new List<Case>();
                    try {
                        caseList = Database.query(caseSoql);
                    } catch(Exception qEx) {
                        // Fallback nếu có field không hợp lệ: query từng field, bỏ qua field lỗi
                        Set<String> validFields = new Set<String>{'Id'};
                        for (String f : caseFields) {
                            if (f == 'Id') continue;
                            try {
                                Database.query('SELECT ' + f + ' FROM Case WHERE Id = :cId LIMIT 1');
                                validFields.add(f);
                            } catch(Exception fe) {}
                        }
                        caseList = Database.query('SELECT ' + String.join(new List<String>(validFields), ', ') + ' FROM Case WHERE Id = :cId LIMIT 1');
                    }

                    if (!caseList.isEmpty()) {
                        Case fullCase = caseList[0];
                        // Replace {{Case.FieldName}} với giá trị thực
                        Matcher caseMat2 = casePat.matcher(template);
                        while (caseMat2.find()) {
                            String fieldName = caseMat2.group(1);
                            String val = '';
                            try { Object fv = fullCase.get(fieldName); val = fv != null ? String.valueOf(fv) : ''; } catch(Exception ex) {}
                            template = template.replace('{{Case.' + fieldName + '}}', val);
                        }
                        // Tiếp tục resolve các object khác (FEC_Additional_Info__c, FEC_Customer_History__c...)
                        template = FEC_CommonUltils.resolveTemplate(template, fullCase);
                    }
                    System.debug('resolveTemplate final: ' + template.left(100));
                    return template;
                } catch (Exception ex) { System.debug('fullCase query error: ' + ex.getMessage()); }
            }
            if (c != null) {
                return FEC_CommonUltils.resolveTemplate(template, c);
            }
            return template;
        } catch (Exception e) {
            System.debug('resolveTemplate exception: ' + e.getMessage());
            return template;
        }
    }

    private class AutoEmailHistoryMeta {
        public Id caseId;
        public Id notificationRuleId;
        public String stageName;
        public String templateName;
        public String notificationRuleName;
        public String channelName;
        public String targetGroup;
    }

    /**
     * Gửi Custom Notification (Salesforce App) và trả về true nếu send thành công.
     */
    private static Boolean sendCustomAppNotification(
        Set<String> recipientIds,
        Id targetRecordId,
        String title,
        String body,
        CustomNotificationType notificationType
    ) {
        if (notificationType == null || recipientIds == null || recipientIds.isEmpty()) {
            return false;
        }
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setTitle(title);
        notification.setBody(body);
        notification.setNotificationTypeId(notificationType.Id);
        if (targetRecordId != null) {
            notification.setTargetId(targetRecordId);
        }
        try {
            notification.send(recipientIds);
            return true;
        } catch (Exception e) {
            System.debug('FEC_NotificationService.sendCustomAppNotification: ' + e.getMessage());
            return false;
        }
    }

    private static void persistAutoEmailNotificationHistory(
        List<Messaging.SendEmailResult> results,
        List<AutoEmailHistoryMeta> metas
    ) {
        if (metas == null || metas.isEmpty()) {
            return;
        }
        List<FEC_Notification_History__c> rows = new List<FEC_Notification_History__c>();
        Integer n = metas.size();
        for (Integer i = 0; i < n; i++) {
            AutoEmailHistoryMeta m = metas[i];
            Boolean ok = (results != null && i < results.size()) && results[i].isSuccess();
            String failMsg = '';
            if (!ok) {
                if (results != null && i < results.size()) {
                    failMsg = FEC_NotificationHistoryService.joinSendEmailErrors(results[i]);
                } else {
                    failMsg = 'Messaging.sendEmail returned no result or threw exception';
                }
                if (String.isBlank(failMsg)) {
                    failMsg = 'Email send failed';
                }
            }
            rows.add(
                FEC_NotificationHistoryService.buildRow(
                    m.caseId,
                    m.notificationRuleId,
                    m.stageName,
                    m.templateName,
                    m.notificationRuleName,
                    m.channelName,
                    m.targetGroup,
                    FEC_NotificationHistoryService.SEND_TYPE_AUTO,
                    ok ? FEC_NotificationHistoryService.SEND_STATUS_SUCCESS : FEC_NotificationHistoryService.SEND_STATUS_FAILURE,
                    ok ? null : failMsg,
                    FEC_NotificationHistoryService.SEND_USER_SYSTEM,
                    null,
                    System.now()
                )
            );
        }
        FEC_NotificationHistoryService.insertRows(rows);
    }
}
