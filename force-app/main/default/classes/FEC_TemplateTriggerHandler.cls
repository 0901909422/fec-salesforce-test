/**
 * Class Description: Handler class for FEC_Template__c Trigger business logic.
 *                    ① Auto-generate FEC_API_Name__c from Name
 *                    ② Check duplicate FEC_API_Name__c within the same FEC_Folder__c
 * @created  : 2026/03/12
 */
public without sharing class FEC_TemplateTriggerHandler {

    // Trigger guard to prevent recursive execution
    private static Boolean isExecuting = false;

    /**
     * Method Description: Main entry point called from the trigger
     * @return void
     */
    public static void run() {
        FEC_TemplateTriggerHandler handler = new FEC_TemplateTriggerHandler();

        if (Trigger.isBefore && Trigger.isInsert) {
            List<FEC_Template__c> newTemplates = (List<FEC_Template__c>) Trigger.new;
            handler.onBeforeInsert(newTemplates);
        }

        if (Trigger.isBefore && Trigger.isUpdate) {
            List<FEC_Template__c> newTemplates = (List<FEC_Template__c>) Trigger.new;
            Map<Id, FEC_Template__c> oldMap = (Map<Id, FEC_Template__c>) Trigger.oldMap;
            handler.onBeforeUpdate(newTemplates, oldMap);
        }
    }

    /**
     * Method Description: Handle logic before inserting Templates
     * @param newTemplates List of new Templates to be inserted
     */
    private void onBeforeInsert(List<FEC_Template__c> newTemplates) {
        generateApiName(newTemplates);
        checkDuplicateApiName(newTemplates);
    }

    /**
     * Method Description: Handle logic before updating Templates
     * @param newTemplates List of Templates with new values after update
     * @param oldMap Map containing old Template values before update
     */
    private void onBeforeUpdate(List<FEC_Template__c> newTemplates, Map<Id, FEC_Template__c> oldMap) {
        // Only re-generate API Name if Template Name has changed
        List<FEC_Template__c> nameChanged = new List<FEC_Template__c>();
        for (FEC_Template__c tmpl : newTemplates) {
            FEC_Template__c oldTmpl = oldMap.get(tmpl.Id);
            if (tmpl.Name != oldTmpl.Name) {
                nameChanged.add(tmpl);
            }
        }
        if (!nameChanged.isEmpty()) {
            generateApiName(nameChanged);
        }

        // Check duplicate on all records where Name or Folder has changed
        List<FEC_Template__c> needDupCheck = new List<FEC_Template__c>();
        for (FEC_Template__c tmpl : newTemplates) {
            FEC_Template__c oldTmpl = oldMap.get(tmpl.Id);
            if (tmpl.Name != oldTmpl.Name
                || tmpl.FEC_Folder__c != oldTmpl.FEC_Folder__c) {
                needDupCheck.add(tmpl);
            }
        }
        if (!needDupCheck.isEmpty()) {
            checkDuplicateApiName(needDupCheck);
        }
    }

    /**
     * Method Description: Auto-generate FEC_API_Name__c from Name.
     *                    Rule: non-alphanumeric → underscore, collapse consecutive, trim.
     * @param templates List of Templates that need API Name generation
     */
    private void generateApiName(List<FEC_Template__c> templates) {
        for (FEC_Template__c tmpl : templates) {
            String templateName = tmpl.Name;
            if (String.isNotBlank(templateName)) {
                String apiName = templateName.trim();
                apiName = apiName.replaceAll('[^a-zA-Z0-9_]', '_');
                apiName = apiName.replaceAll('_+', '_');
                apiName = apiName.replaceAll('^_|_$', '');
                tmpl.FEC_API_Name__c = apiName;
            }
        }
    }

    /**
     * Method Description: Check duplicate FEC_API_Name__c within the same FEC_Folder__c.
     *                    Bulkified: collect folderIds → query existing → Map compare.
     * @param templates List of Templates that need duplicate check
     */
    private void checkDuplicateApiName(List<FEC_Template__c> templates) {
        // Collect all folder IDs that need to be queried
        Set<Id> folderIds = new Set<Id>();
        for (FEC_Template__c tmpl : templates) {
            if (tmpl.FEC_Folder__c != null) {
                folderIds.add(tmpl.FEC_Folder__c);
            }
        }

        // Query all existing templates in the related folders
        // Key: FolderId + '_' + API Name (lowercase) → Template Id
        Map<String, Id> existingMap = new Map<String, Id>();

        if (!folderIds.isEmpty()) {
            for (FEC_Template__c existing : [
                SELECT Id, FEC_API_Name__c, FEC_Folder__c
                FROM FEC_Template__c
                WHERE FEC_Folder__c IN :folderIds
            ]) {
                if (String.isNotBlank(existing.FEC_API_Name__c)) {
                    String key = existing.FEC_Folder__c + '_' + existing.FEC_API_Name__c.toLowerCase();
                    existingMap.put(key, existing.Id);
                }
            }
        }

        // Also need to handle templates with Folder = null (not in any folder)
        Set<String> nullFolderApiNames = new Set<String>();
        Boolean hasNullFolder = false;
        for (FEC_Template__c tmpl : templates) {
            if (tmpl.FEC_Folder__c == null) {
                hasNullFolder = true;
                break;
            }
        }
        if (hasNullFolder) {
            for (FEC_Template__c existing : [
                SELECT Id, FEC_API_Name__c
                FROM FEC_Template__c
                WHERE FEC_Folder__c = NULL
            ]) {
                if (String.isNotBlank(existing.FEC_API_Name__c)) {
                    String key = 'null_' + existing.FEC_API_Name__c.toLowerCase();
                    existingMap.put(key, existing.Id);
                }
            }
        }

        // Check each record in the current batch
        // Also detect duplicates within the same batch (batch-internal check)
        Map<String, FEC_Template__c> batchMap = new Map<String, FEC_Template__c>();

        for (FEC_Template__c tmpl : templates) {
            if (String.isBlank(tmpl.FEC_API_Name__c)) {
                continue;
            }

            String folderKey = tmpl.FEC_Folder__c != null
                ? String.valueOf(tmpl.FEC_Folder__c)
                : 'null';
            String compositeKey = folderKey + '_' + tmpl.FEC_API_Name__c.toLowerCase();

            // Check against existing records in DB
            if (existingMap.containsKey(compositeKey)) {
                Id existingId = existingMap.get(compositeKey);
                // If update: allow the record to match itself
                if (tmpl.Id == null || tmpl.Id != existingId) {
                    tmpl.Name.addError(
                        'A template with API Name "' + tmpl.FEC_API_Name__c
                        + '" already exists in the same folder. Please use a different name.'
                    );
                }
            }

            // Check within current batch (batch-internal duplicate)
            if (batchMap.containsKey(compositeKey)) {
                tmpl.Name.addError(
                    'Duplicate template name detected in this batch. A template with API Name "'
                    + tmpl.FEC_API_Name__c + '" already exists in the same folder.'
                );
            } else {
                batchMap.put(compositeKey, tmpl);
            }
        }
    }
}