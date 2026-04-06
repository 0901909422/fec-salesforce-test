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
        List<Case> routedCases = filterCasesRoutedToQueue(newCases, oldMap);
        if (routedCases.isEmpty()) return;

        // Lấy DeveloperName của Queue mới
        Set<Id> queueIds = new Set<Id>();
        for (Case c : routedCases) queueIds.add(c.OwnerId);

        // Build lookup map: DeveloperName/Id → Queue Id
        Map<String, Id> queueLookup = buildQueueLookupMap(queueIds);

        String channelEmail = FEC_ConstantCommon.NOTIFICATION_CHANNEL_EMAIL;
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
              AND FEC_Notification_Channel__r.Name = :channelEmail
              AND FEC_Assigned_to_Queue__c != null
        ];

        if (notifications.isEmpty()) return;

        // Build map: Queue Id → matching notifications
        // FEC_Assigned_to_Queue__c có thể lưu DeveloperName hoặc Queue Id
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

        Time nowTime = FEC_CommonUltils.getCurrentLocalTime();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Case c : routedCases) {
            List<FEC_Notification__c> candidates = queueIdToNotifs.get(c.OwnerId);
            if (candidates == null || candidates.isEmpty()) continue;

            for (FEC_Notification__c n : candidates) {
                if (!matchesNatureOfCase(c, n)) continue;
                if (!FEC_CommonUltils.isWithinSchedule(nowTime, n.FEC_Schedule_Start_Time__c, n.FEC_Schedule_End_Time__c)) continue;

                List<String> toAddresses = parseReceivers(n.FEC_Receivers__c);
                if (toAddresses.isEmpty()) continue;

                if (String.isBlank(n.FEC_Notification_Template__r?.FEC_Subject_Line__c)) continue;
                if (n.FEC_Notification_Template__r?.FEC_Active__c != true) continue;
                String subject = resolveTemplate(n.FEC_Notification_Template__r.FEC_Subject_Line__c, c);
                String body = String.isNotBlank(n.FEC_Notification_Template__r?.FEC_Body__c)
                    ? resolveTemplate(n.FEC_Notification_Template__r.FEC_Body__c, c)
                    : '';

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(toAddresses);
                mail.setSubject(subject);
                mail.setHtmlBody(body);
                mail.setSaveAsActivity(false);
                emails.add(mail);
            }
        }

        if (!emails.isEmpty()) {
            sendEmails(emails);
        }
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
            for (String email : parseReceivers(n.FEC_Receivers__c)) {
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

                List<String> receiverEmails = parseReceivers(n.FEC_Receivers__c);
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
     * Common method gửi email - dùng lại cho sendEmailNotifications
     */
    private static void sendEmails(List<Messaging.SingleEmailMessage> emails) {
        if (emails == null || emails.isEmpty()) return;
        try {
            Messaging.sendEmail(emails, false);
        } catch (Exception e) {
            System.debug('FEC_NotificationService.sendEmails failed: ' + e.getMessage());
        }
    }

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
     * Parse danh sách email từ LongTextArea (phân cách bằng dấu phẩy hoặc xuống dòng)
     */
    private static List<String> parseReceivers(String receivers) {
        List<String> result = new List<String>();
        if (String.isBlank(receivers)) return result;
        // Normalize: replace newlines with comma
        String normalized = receivers.replace('\n', ',').replace('\r', ',');
        for (String email : normalized.split(',')) {
            String trimmed = email.trim();
            if (String.isNotBlank(trimmed)) result.add(trimmed);
        }
        return result;
    }

    /**
     * Thay thế placeholder {{FieldName}} trong template bằng giá trị từ Case
     */
    private static String resolveTemplate(String template, Case c) {
        if (String.isBlank(template)) return template;
        // Dùng FEC_CommonUltils.resolveTemplate nếu có, hoặc basic replace
        try {
            return FEC_CommonUltils.resolveTemplate(template, c);
        } catch (Exception e) {
            return template;
        }
    }
}
