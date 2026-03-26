public without sharing class FEC_FolderTriggerHandler {
    
    // Assumed field name for Parent lookup: FEC_Parent_Folder__c
    // Replace with your actual API name if different.
    
    public static void run() {
        FEC_FolderTriggerHandler handler = new FEC_FolderTriggerHandler();
        
        if (Trigger.isBefore) {
            if (Trigger.isInsert) {
                handler.validateFolderUniqueName((List<FEC_Folder__c>) Trigger.new, null);
            } else if (Trigger.isUpdate) {
                handler.validateFolderUniqueName((List<FEC_Folder__c>) Trigger.new, (Map<Id, FEC_Folder__c>) Trigger.oldMap);
            }
        }
    }

    private void validateFolderUniqueName(List<FEC_Folder__c> folders, Map<Id, FEC_Folder__c> oldMap) {
        Set<String> names = new Set<String>();
        Set<Id> parentIds = new Set<Id>();
        List<FEC_Folder__c> recordsToValidate = new List<FEC_Folder__c>();

        // 1. Collect names and parent IDs, filtering for records where name or parent changed
        for (FEC_Folder__c folder : folders) {
            Boolean isChanged = (oldMap == null || 
                                folder.FEC_Folder_Unique_Name__c != oldMap.get(folder.Id).FEC_Folder_Unique_Name__c ||
                                folder.FEC_Parent_Folder__c != oldMap.get(folder.Id).FEC_Parent_Folder__c);

            if (folder.FEC_Folder_Unique_Name__c != null && isChanged) {
                names.add(folder.FEC_Folder_Unique_Name__c);
                parentIds.add(folder.FEC_Parent_Folder__c); // Can be null for root folders
                recordsToValidate.add(folder);
            }
        }

        if (recordsToValidate.isEmpty()) return;

        // 2. Query existing records that share those names AND those parents
        // Using a Map with a composite key: "ParentId-Name"
        Map<String, Id> existingKeysMap = new Map<String, Id>();
        for (FEC_Folder__c existing : [SELECT Id, FEC_Folder_Unique_Name__c, FEC_Parent_Folder__c 
                                       FROM FEC_Folder__c 
                                       WHERE FEC_Folder_Unique_Name__c IN :names 
                                       AND FEC_Parent_Folder__c IN :parentIds]) {
            String key = generateKey(existing.FEC_Parent_Folder__c, existing.FEC_Folder_Unique_Name__c);
            existingKeysMap.put(key, existing.Id);
        }

        // 3. Validate against DB and handle intra-batch duplicates
        Set<String> keysInBatch = new Set<String>();
        String errorMsgLabel = System.Label.FEC_Folder_Duplicate_Error;
           System.debug('>>existingKeysMap: ' +Json.serializePretty(existingKeysMap));

        for (FEC_Folder__c folder : recordsToValidate) {
            String currentKey = generateKey(folder.FEC_Parent_Folder__c, folder.FEC_Folder_Unique_Name__c);
            System.debug('>>currentKey: ' +currentKey);

            // Check against Database
            Boolean existsInDb = existingKeysMap.containsKey(currentKey) && existingKeysMap.get(currentKey) != folder.Id;
             System.debug('>>existsInDb: ' +existsInDb);
            
            // Check against other records in the same transaction (Batch)
            Boolean existsInBatch = keysInBatch.contains(currentKey);
              System.debug('>>existsInBatch: ' +existsInBatch);

            if (existsInDb || existsInBatch) {
                String dynamicError = String.format(errorMsgLabel, new List<Object>{folder.FEC_Folder_Unique_Name__c});
                folder.FEC_Folder_Unique_Name__c.addError(dynamicError);
            } else {
                keysInBatch.add(currentKey);
            }
        }
    }

    /**
     * Creates a unique identifier for a folder name within a specific parent scope.
     * Handles null parentIds for root-level folders.
     */
    private String generateKey(Id parentId, String name) {
        return (parentId == null ? 'ROOT' : (String)parentId) + '-' + name.toLowerCase().trim();
    }
}