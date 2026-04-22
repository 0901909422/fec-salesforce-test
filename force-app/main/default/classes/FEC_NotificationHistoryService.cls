/**
 * Ghi nhận FEC_Notification_History__c sau khi gửi thông báo (Manual / Auto).
 */
public without sharing class FEC_NotificationHistoryService {

    public static final String SEND_TYPE_AUTO = 'Auto';
    public static final String SEND_TYPE_MANUAL = 'Manual';
    public static final String SEND_STATUS_SUCCESS = 'Success';
    public static final String SEND_STATUS_FAILURE = 'Failure';
    public static final String SEND_USER_SYSTEM = 'System';

    /** API lookup từ FEC_Notification_History__c → FEC_Notification__c (cấu hình rule). */
    private static final String LOOKUP_FEC_NOTIFICATION = 'FEC_Notification__c';
    private static final String LOOKUP_SEND_USER = 'FEC_Send_User__c';
    private static final Map<String, Id> SEND_USER_LOCAL_CACHE = new Map<String, Id>();
    private static final Map<Id, String> USER_LOCAL_BY_ID_CACHE = new Map<Id, String>();

    public static FEC_Notification_History__c buildRow(
        Id caseId,
        Id fecNotificationId,
        String stageName,
        String notificationTemplateName,
        String notificationRuleName,
        String notificationChannel,
        String targetGroup,
        String sentType,
        String sentStatus,
        String failureReason,
        String sendUserField,
        String userRoleName,
        Datetime sentAt
    ) {
        FEC_Notification_History__c row = new FEC_Notification_History__c();
        row.FEC_Case__c = caseId;
        putNotificationLookup(row, fecNotificationId);
        row.FEC_Stage_Name__c = trunc(stageName, 255);
        row.FEC_Notification_Template__c = trunc(notificationTemplateName, 255);
        row.FEC_Notification_Content__c = trunc(notificationRuleName, 255);
        row.FEC_Notification_Type__c = trunc(notificationRuleName, 255);
        row.FEC_Notification_Channel__c = trunc(notificationChannel, 255);
        row.FEC_Target_Group__c = trunc(targetGroup, 255);
        row.FEC_Send_Type__c = trunc(sentType, 255);
        row.FEC_Send_Status__c = trunc(sentStatus, 255);
        row.FEC_Failure_Reason__c = trunc(failureReason, 255);
        Object sendUserLookupValue = resolveSendUserLookupValue(sentType, sendUserField);
        row.put(LOOKUP_SEND_USER, sendUserLookupValue);
        row.FEC_User__c = trunc(resolveSendUserText(sentType, sendUserField, sendUserLookupValue), 255);
        row.FEC_User_Role__c = trunc(userRoleName, 255);
        row.FEC_Send_Date_Time__c = sentAt != null ? sentAt : System.now();
        return row;
    }

    private static void putNotificationLookup(FEC_Notification_History__c row, Id fecNotificationId) {
        if (fecNotificationId == null) {
            return;
        }
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.FEC_Notification_History__c.fields.getMap();
        if (!fm.containsKey(LOOKUP_FEC_NOTIFICATION)) {
            return;
        }
        Schema.DescribeFieldResult dfr = fm.get(LOOKUP_FEC_NOTIFICATION).getDescribe();
        if (!dfr.isCreateable() || dfr.getType() != Schema.DisplayType.REFERENCE) {
            return;
        }
        for (Schema.SObjectType refTo : dfr.getReferenceTo()) {
            if (refTo == FEC_Notification__c.SObjectType) {
                row.put(LOOKUP_FEC_NOTIFICATION, fecNotificationId);
                return;
            }
        }
    }

    /**
     * FEC_Send_User__c trên org có thể là Text (local email) hoặc Lookup(User).
     * Lookup(User):
     * - Auto/System: null
     * - Manual: ưu tiên Id hợp lệ, sau đó tìm User theo local-part email, fallback user hiện tại.
     */
    private static Object resolveSendUserLookupValue(String sentType, String sendUserField) {
        Schema.SObjectField fld = Schema.SObjectType.FEC_Notification_History__c.fields.getMap().get(LOOKUP_SEND_USER);
        String manualLocalUser = emailLocalPart(UserInfo.getUserEmail());
        if (fld == null) {
            return null;
        }
        Schema.DescribeFieldResult fd = fld.getDescribe();
        if (fd.getType() == Schema.DisplayType.REFERENCE) {
            if (
                String.isBlank(sendUserField) ||
                SEND_USER_SYSTEM.equalsIgnoreCase(sendUserField) ||
                SEND_TYPE_AUTO.equalsIgnoreCase(sentType)
            ) {
                return null;
            }
            Id parsedUserId = tryParseSalesforceId(sendUserField);
            if (parsedUserId != null) {
                return parsedUserId;
            }
            if (SEND_TYPE_MANUAL.equalsIgnoreCase(sentType)) {
                Id byLocalEmail = findUserIdByEmailLocalPart(manualLocalUser);
                if (byLocalEmail != null) {
                    return byLocalEmail;
                }
            }
            return UserInfo.getUserId();
        }
        if (SEND_TYPE_MANUAL.equalsIgnoreCase(sentType)) {
            return trunc(manualLocalUser, 255);
        }
        return trunc(sendUserField, 255);
    }

    private static String resolveSendUserText(String sentType, String sendUserField, Object sendUserLookupValue) {
        if (SEND_TYPE_AUTO.equalsIgnoreCase(sentType)) {
            return SEND_USER_SYSTEM;
        }
        if (sendUserLookupValue instanceof Id) {
            String localFromLookup = getUserLocalById((Id) sendUserLookupValue);
            if (String.isNotBlank(localFromLookup)) {
                return localFromLookup;
            }
        }
        Id parsedUserId = tryParseSalesforceId(sendUserField);
        if (parsedUserId != null) {
            String localFromInputId = getUserLocalById(parsedUserId);
            if (String.isNotBlank(localFromInputId)) {
                return localFromInputId;
            }
        }
        if (String.isNotBlank(sendUserField) && !SEND_USER_SYSTEM.equalsIgnoreCase(sendUserField)) {
            String localFromInput = emailLocalPart(sendUserField);
            if (String.isNotBlank(localFromInput)) {
                return localFromInput;
            }
        }
        return emailLocalPart(UserInfo.getUserEmail());
    }

    private static String getUserLocalById(Id userId) {
        if (userId == null) {
            return '';
        }
        if (USER_LOCAL_BY_ID_CACHE.containsKey(userId)) {
            return USER_LOCAL_BY_ID_CACHE.get(userId);
        }
        List<User> users = [SELECT Email FROM User WHERE Id = :userId LIMIT 1];
        String local = users.isEmpty() ? '' : emailLocalPart(users[0].Email);
        USER_LOCAL_BY_ID_CACHE.put(userId, local);
        return local;
    }

    private static Id findUserIdByEmailLocalPart(String sendUserField) {
        String local = emailLocalPart(sendUserField);
        if (String.isBlank(local)) {
            return null;
        }
        String cacheKey = local.toLowerCase();
        if (SEND_USER_LOCAL_CACHE.containsKey(cacheKey)) {
            return SEND_USER_LOCAL_CACHE.get(cacheKey);
        }
        String likePattern = local + '@%';
        List<User> users = [
            SELECT Id, Email
            FROM User
            WHERE IsActive = true
              AND Email LIKE :likePattern
            ORDER BY LastModifiedDate DESC
            LIMIT 20
        ];
        for (User u : users) {
            if (String.isNotBlank(u.Email) && emailLocalPart(u.Email).equalsIgnoreCase(local)) {
                SEND_USER_LOCAL_CACHE.put(cacheKey, u.Id);
                return u.Id;
            }
        }
        SEND_USER_LOCAL_CACHE.put(cacheKey, null);
        return null;
    }

    private static Id tryParseSalesforceId(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Id.valueOf(value);
        } catch (Exception e) {
            return null;
        }
    }

    private static String trunc(String s, Integer maxLen) {
        if (String.isBlank(s)) {
            return s;
        }
        return s.length() > maxLen ? s.substring(0, maxLen) : s;
    }

    public static String emailLocalPart(String email) {
        if (String.isBlank(email)) {
            return '';
        }
        String t = email.trim();
        Integer at = t.indexOf('@');
        return at > 0 ? t.substring(0, at) : t;
    }

    public static void insertRows(List<FEC_Notification_History__c> rows) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        if (!Schema.sObjectType.FEC_Notification_History__c.isCreateable()) {
            return;
        }
        try {
            insert rows;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'FEC_NotificationHistoryService.insertRows: ' + e.getMessage());
        }
    }

    public static void insertRow(FEC_Notification_History__c row) {
        if (row == null) {
            return;
        }
        insertRows(new List<FEC_Notification_History__c>{ row });
    }

    public static String joinSendEmailErrors(Messaging.SendEmailResult res) {
        if (res == null || res.isSuccess()) {
            return '';
        }
        List<String> parts = new List<String>();
        for (Messaging.SendEmailError err : res.getErrors()) {
            if (err != null && String.isNotBlank(err.getMessage())) {
                parts.add(err.getMessage());
            }
        }
        return String.join(parts, '; ');
    }
}
