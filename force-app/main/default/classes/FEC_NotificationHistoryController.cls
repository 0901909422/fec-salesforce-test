/****************************************************************************************
 * FEC_NotificationHistoryController — LWC fe_Notification_History (Email / ZNS / Mobile App).
 * Query FEC_Notification_History__c WHERE FEC_Case__c = Case Id AND FEC_Send_Type__c matches channel.
 *
 * channel (LWC): FEC_ConstantCommon.NOTIFICATION_HISTORY_CHANNEL_* — map tới các giá trị phổ biến trên FEC_Send_Type__c;
 *   chỉnh list trong sendTypesForChannel() nếu dữ liệu org khác.
 *
 * Cột UI ↔ field (giống Email):
 *   sentDateTime → FEC_Send_Date_Time__c, sentType → FEC_Send_Type__c, …
 ****************************************************************************************/
public with sharing class FEC_NotificationHistoryController {

    public class NotificationHistoryRow {
        @AuraEnabled public String id { get; set; }
        /** Formatted send time (cannot use "dateTime" — reserved in Apex). */
        @AuraEnabled public String sentDateTime { get; set; }
        @AuraEnabled public String sentType { get; set; }
        @AuraEnabled public String notificationType { get; set; }
        @AuraEnabled public String notificationContent { get; set; }
        @AuraEnabled public String sentSystem { get; set; }
        @AuraEnabled public String user { get; set; }
        @AuraEnabled public String sentStatus { get; set; }
        @AuraEnabled public String failureReason { get; set; }
        @AuraEnabled public String caseId { get; set; }
    }

    /**
     * @param channel NOTIFICATION_HISTORY_CHANNEL_* (case-insensitive)
     */
    @AuraEnabled(cacheable = true)
    public static List<NotificationHistoryRow> getNotificationHistoryForCase(Id caseId, String channel) {
        List<NotificationHistoryRow> out = new List<NotificationHistoryRow>();
        if (caseId == null) {
            return out;
        }

        List<String> channelValues = getChannelValues(channel);
        if (channelValues.isEmpty()) {
            return out;
        }

        // 1. Fetch National ID from current Case to allow cross-case history search
        List<Case> currentCases = [
            SELECT FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        
        String nationalId = (currentCases.isEmpty()) ? null : currentCases[0].FEC_Account_or_Contract__r?.FEC_National_ID_Passport_ID__c;

        // 2. Build Query - Search by National ID if available, else fallback to current caseId
        List<FEC_Notification_History__c> rows;
        if (String.isNotBlank(nationalId)) {
            rows = [
                SELECT
                    Id,
                    FEC_Send_Date_Time__c,
                    FEC_Send_Type__c,
                    FEC_Notification_Channel__c,
                    FEC_Notification_Template__c,
                    FEC_Notification_Content__c,
                    FEC_Send_System__c,
                    FEC_Send_User__r.Name,
                    FEC_Send_Status__c,
                    FEC_Failure_Reason__c,
                    FEC_Case__c
                FROM FEC_Notification_History__c
                WHERE FEC_Notification_Channel__c IN :channelValues
                  AND FEC_Case__r.FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c = :nationalId
                ORDER BY FEC_Send_Date_Time__c DESC NULLS LAST
            ];
        } else {
            rows = [
                SELECT
                    Id,
                    FEC_Send_Date_Time__c,
                    FEC_Send_Type__c,
                    FEC_Notification_Channel__c,
                    FEC_Notification_Template__c,
                    FEC_Notification_Content__c,
                    FEC_Send_System__c,
                    FEC_Send_User__r.Name,
                    FEC_Send_Status__c,
                    FEC_Failure_Reason__c,
                    FEC_Case__c
                FROM FEC_Notification_History__c
                WHERE FEC_Case__c = :caseId AND FEC_Notification_Channel__c IN :channelValues
                ORDER BY FEC_Send_Date_Time__c DESC NULLS LAST
            ];
        }

        String tz = UserInfo.getTimeZone().getID();
        for (FEC_Notification_History__c r : rows) {
            NotificationHistoryRow row = new NotificationHistoryRow();
            row.id = String.valueOf(r.Id);
            row.sentDateTime = r.FEC_Send_Date_Time__c != null
                ? r.FEC_Send_Date_Time__c.format(FEC_ConstantCommon.DATETIME_FORMAT_OUTPUT, tz)
                : FEC_ConstantCommon.STR_EMPTY;
            // Displays Manual/Auto as intended
            row.sentType = FEC_CommonUltils.defaultToEmpty(r.FEC_Send_Type__c);
            row.notificationType = FEC_CommonUltils.defaultToEmpty(r.FEC_Notification_Template__c);
            row.notificationContent = FEC_CommonUltils.defaultToEmpty(r.FEC_Notification_Content__c);
            row.sentSystem = FEC_CommonUltils.defaultToEmpty(r.FEC_Send_System__c);
            row.user = r.FEC_Send_User__r != null ? FEC_CommonUltils.defaultToEmpty(r.FEC_Send_User__r.Name) : FEC_ConstantCommon.STR_EMPTY;
            row.sentStatus = FEC_CommonUltils.defaultToEmpty(r.FEC_Send_Status__c);
            row.failureReason = FEC_CommonUltils.defaultToEmpty(r.FEC_Failure_Reason__c);
            row.caseId = r.FEC_Case__c != null ? String.valueOf(r.FEC_Case__c) : FEC_ConstantCommon.STR_EMPTY;
            out.add(row);
        }
        return out;
    }

    /** Giữ tương thích nếu chỗ khác vẫn gọi tên method cũ. */
    @AuraEnabled(cacheable = true)
    public static List<NotificationHistoryRow> getEmailNotificationHistoryForCase(Id caseId) {
        return getNotificationHistoryForCase(caseId, FEC_ConstantCommon.NOTIFICATION_HISTORY_CHANNEL_EMAIL);
    }

    private static List<String> getChannelValues(String tabChannel) {
        if (String.isBlank(tabChannel)) {
            return new List<String>();
        }
        String c = tabChannel.trim().toUpperCase();
        if (c == FEC_ConstantCommon.NOTIFICATION_HISTORY_CHANNEL_EMAIL) {
            return new List<String>{
                FEC_ConstantCommon.NOTIFICATION_CHANNEL_EMAIL,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_CHANNEL_EMAIL,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_SEND_TYPE_EMAIL_LOWER
            };
        }
        if (c == FEC_ConstantCommon.NOTIFICATION_HISTORY_CHANNEL_ZNS) {
            return new List<String>{
                FEC_ConstantCommon.NOTIFICATION_HISTORY_CHANNEL_ZNS,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_SEND_TYPE_ZALO,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_SEND_TYPE_ZALO_ZNS,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_SEND_TYPE_ZNS_TITLE,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_SEND_TYPE_ZNS_LOWER,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_SEND_TYPE_ZALO_ZNS_COMPACT
            };
        }
        if (c == FEC_ConstantCommon.NOTIFICATION_HISTORY_CHANNEL_MOBILE_APP) {
            return new List<String>{
                FEC_ConstantCommon.NOTIFICATION_HISTORY_SEND_TYPE_MOBILE_APP,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_SEND_TYPE_MOBILE_APP_COMPACT,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_SEND_TYPE_MOBILE_APP_LOWER,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_SEND_TYPE_APP,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_SEND_TYPE_PUSH,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_SEND_TYPE_PUSH_NOTIFICATION,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_SEND_TYPE_MOBILE_APPLICATION
            };
        }
        return new List<String>();
    }
}