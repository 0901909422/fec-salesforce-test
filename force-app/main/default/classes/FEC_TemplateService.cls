/**
 * Service Layer: Business logic for FEC_Template__c.
 * Orchestrates Selector queries, DML, content-history tracking,
 * and attachment management (ContentDocumentLink).
 * Called by controllers; never directly by LWC.
 * @created  : 2026/03/12
 */
public with sharing class FEC_TemplateService {

    /**
     * Get a single template with all related data for the detail page.
     * @param templateId  Record Id
     * @return FEC_Template__c (null if not found)
     */
    public static FEC_Template__c getTemplate(Id templateId) {
        return FEC_TemplateSelector.selectById(templateId);
    }

    /**
     * Get a filtered list of templates for the list view.
     * @param folderId      Filter by folder (null = all)
     * @param searchText    LIKE search (blank = all)
     * @param activeOnly    true = only active templates
     * @return List of FEC_Template__c
     */
    public static List<FEC_Template__c> getTemplates(
        Id folderId,
        String searchText,
        Boolean activeOnly
    ) {
        return FEC_TemplateSelector.selectByFilter(folderId, searchText, activeOnly);
    }

    /**
     * Create or update a template record.
     * Tracks Body changes in FEC_Content_History_Tracking__c.
     * @param tmpl          The template record to upsert
     * @param oldBody       Previous body value (null for insert) – used for content history
     * @return Id of the saved record
     */
    public static Id saveTemplate(FEC_Template__c tmpl, String oldBody, List<Id> deletedAttachmentIds) {
        // CRUD check
        if (tmpl.Id == null) {
            if (!Schema.sObjectType.FEC_Template__c.isCreateable()) {
                throw new FEC_APIServiceException('Insufficient privileges to create templates.');
            }
        } else {
            if (!Schema.sObjectType.FEC_Template__c.isUpdateable()) {
                throw new FEC_APIServiceException('Insufficient privileges to update templates.');
            }
        }

        Boolean isInsert = tmpl.Id == null;
        String newBody = tmpl.FEC_Body__c;

        upsert tmpl;

        if (deletedAttachmentIds != null && !deletedAttachmentIds.isEmpty()) {
            delete [SELECT Id FROM ContentDocument WHERE Id IN :deletedAttachmentIds];
        }

        // Track body change → FEC_Content_History_Tracking__c
        // Skip when oldBody is null (initial save / draft→real conversion)
        if (!isInsert && oldBody != null && newBody != oldBody
            && (String.isNotBlank(newBody) || String.isNotBlank(oldBody))) {
            createContentHistory(tmpl.Id, oldBody, newBody);
        }

        return tmpl.Id;
    }

    /**
     * Delete a template by Id.
     * @param templateId  Record Id
     */
    public static void deleteTemplate(Id templateId) {
        if (!Schema.sObjectType.FEC_Template__c.isDeletable()) {
            throw new FEC_APIServiceException('Insufficient privileges to delete templates.');
        }
        FEC_Template__c toDelete = new FEC_Template__c(Id = templateId);
        delete toDelete;
    }

    /**
     * Create a lightweight draft template so that file uploads have a valid
     * LinkedEntityId before the user fills in the form.
     * The record is intentionally minimal — the real field values are applied
     * when the user clicks Save (via saveTemplate / upsert).
     * @return Id of the newly created draft record
     */
    public static Id createDraftTemplate() {
        if (!Schema.sObjectType.FEC_Template__c.isCreateable()) {
            throw new FEC_APIServiceException('Insufficient privileges to create templates.');
        }
        FEC_Template__c draft = new FEC_Template__c(
            Name = 'Draft-' + Datetime.now().getTime()
        );
        insert draft;
        return draft.Id;
    }

    /**
     * Delete a draft template together with every file that was uploaded to it.
     * Called when the user cancels or navigates away from the New Template form.
     *
     * Deletion order:
     *   1. ContentDocument (cascade-deletes ContentDocumentLink + ContentVersion)
     *   2. FEC_Template__c draft record
     *
     * @param draftId  The Id of the draft template to remove
     */
    public static void deleteDraftTemplate(Id draftId) {
        if (draftId == null) return;

        // Delete attached files first (ContentDocument cascade-deletes links & versions)
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :draftId
        ];
        if (!links.isEmpty()) {
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink cdl : links) {
                docIds.add(cdl.ContentDocumentId);
            }
            delete [SELECT Id FROM ContentDocument WHERE Id IN :docIds];
        }

        // Delete the draft template record
        if (Schema.sObjectType.FEC_Template__c.isDeletable()) {
            delete new FEC_Template__c(Id = draftId);
        }
    }

    /**
     * Get file attachments (ContentDocumentLinks) for a template.
     * @param templateId  The parent entity Id
     * @return List of ContentDocumentLink with ContentDocument details
     */
    public static List<ContentDocumentLink> getAttachments(Id templateId) {
        return [
            SELECT Id, ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.FileExtension,
                   ContentDocument.ContentSize,
                   ContentDocument.FileType,
                   ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :templateId
            ORDER BY ContentDocument.CreatedDate DESC
        ];
    }

    /* ─── Private helpers ─── */

    /**
     * Create a content-history record when the Body field changes.
     * Extracts merge-field references from the new body for tracking.
     */
    private static void createContentHistory(Id templateId, String oldBody, String newBody) {
        if (!Schema.sObjectType.FEC_Content_History_Tracking__c.isCreateable()) {
            return; // Silently skip if user lacks create permission on history object
        }

        FEC_Content_History_Tracking__c history = new FEC_Content_History_Tracking__c();
        history.FEC_Template__c = templateId;
        history.FEC_Date__c = Datetime.now();
        history.FEC_User__c = UserInfo.getUserId();
        history.FEC_Original_Value__c = oldBody;
        history.FEC_New_Value__c = newBody;
        history.FEC_Merge_Fields_Used__c = extractMergeFields(newBody);

        insert history;
    }

    /**
     * Extract merge field references like {{{Contact.FirstName}}} from the body.
     * Returns a comma-separated string of all unique merge fields found.
     */
    @TestVisible
    private static String extractMergeFields(String body) {
        if (String.isBlank(body)) return '';

        Set<String> mergeFields = new Set<String>();
        Pattern p = Pattern.compile('\\{\\{\\{([^}]+)\\}\\}\\}');
        Matcher m = p.matcher(body);
        while (m.find()) {
            mergeFields.add('{{{' + m.group(1) + '}}}');
        }

        if (mergeFields.isEmpty()) return '';

        return String.join(new List<String>(mergeFields), ', ');
    }
}