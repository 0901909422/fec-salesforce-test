/**
 * Controller: @AuraEnabled endpoints for FEC_Template__c.
 * Thin layer – delegates to FEC_TemplateService + FEC_ContentHistoryService.
 * Called by LWC components via @wire or imperative Apex.
 * @created  : 2026/03/12
 */
public with sharing class FEC_TemplateController {

    /**
     * Get a single template record with all fields.
     * Used by fec_templateEditor (edit mode) and fec_templateDetailPage.
     * @param templateId  Record Id
     * @return FEC_Template__c
     */
    @AuraEnabled
    public static FEC_Template__c getTemplate(Id templateId) {
        try {
            return FEC_TemplateService.getTemplate(templateId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Get a filtered list of templates for the list view.
     * @param folderId      Filter by folder (null = all)
     * @param searchText    LIKE search on name/description
     * @param activeOnly    true = only active templates
     * @return List of FEC_Template__c
     */
    @AuraEnabled
    public static List<FEC_Template__c> getTemplates(
        Id folderId,
        String searchText,
        Boolean activeOnly
    ) {
        try {
            return FEC_TemplateService.getTemplates(folderId, searchText, activeOnly);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Save (insert or update) a template.
     * @param templateJson  JSON-serialised FEC_Template__c record
     * @param oldBody       Previous body value (for content-history tracking)
     * @return Id of the saved record
     */
    @AuraEnabled
    public static Id saveTemplate(String templateJson, String oldBody) {
        try {
            FEC_Template__c tmpl = (FEC_Template__c) JSON.deserialize(
                templateJson, FEC_Template__c.class
            );
            return FEC_TemplateService.saveTemplate(tmpl, oldBody);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Delete a template.
     * @param templateId  Record Id
     */
    @AuraEnabled
    public static void deleteTemplate(Id templateId) {
        try {
            FEC_TemplateService.deleteTemplate(templateId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Get file attachments (ContentDocumentLinks) for a template.
     * @param templateId  The template record Id
     * @return List of ContentDocumentLink with ContentDocument details
     */
    @AuraEnabled
    public static List<ContentDocumentLink> getAttachments(Id templateId) {
        try {
            return FEC_TemplateService.getAttachments(templateId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Get content (Body) change history for a template.
     * Used by fec_templateDetailPage → Content History tab.
     * @param templateId  Record Id
     * @return List of FEC_Content_History_Tracking__c
     */
    @AuraEnabled
    public static List<FEC_Content_History_Tracking__c> getContentHistory(Id templateId) {
        try {
            return FEC_ContentHistoryService.getHistoryByTemplate(templateId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Get template field-level change history for a template.
     * Used by fec_templateDetailPage → Template History tab.
     * @param templateId  Record Id
     * @return List of FEC_Template__History
     */
    @AuraEnabled
    public static List<FEC_Template__History> getTemplateHistory(Id templateId) {
        try {
            return FEC_TemplateHistoryService.getHistoryByTemplate(templateId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Get all Enhanced Letterhead records for the dropdown picker.
     * @return List of FEC_Enhanced_Letterhead__c with Id and Name
     */
    @AuraEnabled
    public static List<FEC_Enhanced_Letterhead__c> getAllLetterheads() {
        try {
            return [
                SELECT Id, Name, FEC_Header__c, FEC_Footer__c
                FROM FEC_Enhanced_Letterhead__c
                ORDER BY Name ASC
                LIMIT 1000
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}