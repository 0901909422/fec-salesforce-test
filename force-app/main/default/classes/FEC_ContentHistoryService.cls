/**
 * Service Layer: Business logic for FEC_Content_History_Tracking__c.
 * Read-only service – records are created by FEC_TemplateService when Body changes.
 * @created  : 2026/03/12
 */
public with sharing class FEC_ContentHistoryService {

    /**
     * Get content-history records for a template.
     * @param templateId  Parent template Id
     * @return List of FEC_Content_History_Tracking__c ordered by date DESC
     */
    public static List<FEC_Content_History_Tracking__c> getHistoryByTemplate(Id templateId) {
        return FEC_ContentHistorySelector.selectByTemplateId(templateId);
    }

    /**
     * Get a single content-history record by Id (for "View Diff" feature).
     * @param recordId  The history record Id
     * @return FEC_Content_History_Tracking__c or null
     */
    public static FEC_Content_History_Tracking__c getHistoryRecord(Id recordId) {
        return FEC_ContentHistorySelector.selectById(recordId);
    }
}