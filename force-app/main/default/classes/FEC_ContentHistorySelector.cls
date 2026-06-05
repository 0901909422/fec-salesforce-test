/**
 * Selector Layer: Centralised SOQL for FEC_Content_History_Tracking__c.
 * Queries content (Body) change history for a specific template.
 * @created  : 2026/03/12
 */
public with sharing class FEC_ContentHistorySelector {

    /* ─── Standard field list ─── */
    private static final List<String> BASE_FIELDS = new List<String>{
        'Id',
        'Name',
        'FEC_Date__c',
        'FEC_User__c',
        'FEC_User__r.Name',
        'FEC_Original_Value__c',
        'FEC_New_Value__c',
        'FEC_Merge_Fields_Used__c',
        'FEC_Template__c',
        'CreatedDate'
    };

    /**
     * Get content history records for a specific template.
     * Ordered by date descending (most recent first).
     * @param templateId  The parent template Id
     * @return List of FEC_Content_History_Tracking__c
     */
    public static List<FEC_Content_History_Tracking__c> selectByTemplateId(Id templateId) {
        return Database.query(
            buildBaseQuery() +
            ' WHERE FEC_Template__c = :templateId' +
            ' ORDER BY FEC_Date__c DESC' +
            ' LIMIT 200'
        );
    }

    /**
     * Get a single content history record by Id.
     * @param recordId  The record Id
     * @return FEC_Content_History_Tracking__c or null
     */
    public static FEC_Content_History_Tracking__c selectById(Id recordId) {
        List<FEC_Content_History_Tracking__c> results = Database.query(
            buildBaseQuery() +
            ' WHERE Id = :recordId' +
            ' LIMIT 1'
        );
        return results.isEmpty() ? null : results[0];
    }

    /* ─── Private helpers ─── */

    private static String buildBaseQuery() {
        return 'SELECT ' + String.join(BASE_FIELDS, ', ') + ' FROM FEC_Content_History_Tracking__c';
    }
}