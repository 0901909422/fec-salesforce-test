/**
 * Service Layer: Business logic for FEC_Template__History.
 * Read-only service – records are created by triggers/handlers when template fields change.
 * @created  : 2026/03/19
 */
public with sharing class FEC_TemplateHistoryService {

    /**
     * Get template-history records for a template.
     * @param templateId  Parent template Id
     * @return List of FEC_Template__History ordered by date DESC
     */
    public static List<FEC_Template__History> getHistoryByTemplate(Id templateId) {
        return FEC_TemplateHistorySelector.selectByTemplateId(templateId);
    }

    /**
     * Get a single template-history record by Id.
     * @param recordId  The history record Id
     * @return FEC_Template__History or null
     */
    public static FEC_Template__History getHistoryRecord(Id recordId) {
        return FEC_TemplateHistorySelector.selectById(recordId);
    }
}