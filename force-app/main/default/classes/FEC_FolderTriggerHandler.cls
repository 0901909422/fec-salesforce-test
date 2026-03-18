public without sharing class FEC_FolderTriggerHandler {
    public static void run() {
        FEC_FolderTriggerHandler handler = new FEC_FolderTriggerHandler();
        
        if (Trigger.isBefore && Trigger.isInsert) {
            List<FEC_Folder__c> folders = (List<FEC_Folder__c>) Trigger.new;
            handler.onBeforeInsert(folders);
        }
        
        if (Trigger.isBefore && Trigger.isUpdate) {
            List<FEC_Folder__c> folders = (List<FEC_Folder__c>) Trigger.new;
            Map<Id, FEC_Folder__c> oldMap = (Map<Id, FEC_Folder__c>) Trigger.oldMap;
            handler.onBeforeUpdate(folders, oldMap);
        }
        
    }

    private void onBeforeInsert(List<FEC_Folder__c> folders) {
        validateFolderUniqueName(folders);
    }

    private void onBeforeUpdate(List<FEC_Folder__c> folders, Map<Id, FEC_Folder__c> oldMap) {
       validateFolderUniqueName(folders);
    }

    private void validateFolderUniqueName(List<FEC_Folder__c> folders) {
        Set<String> newNames = new Set<String>();

        // 1. Collect names from incoming records
        for (FEC_Folder__c folder : folders) {
            if (folder.FEC_Folder_Unique_Name__c != null) {
                newNames.add(folder.FEC_Folder_Unique_Name__c);
            }
        }

        if (!newNames.isEmpty()) {
            // 2. Query existing records with the same names
            Map<String, FEC_Folder__c> existingFoldersMap = new Map<String, FEC_Folder__c>();
            for (FEC_Folder__c existing : [SELECT Id, FEC_Folder_Unique_Name__c 
                                        FROM FEC_Folder__c 
                                        WHERE FEC_Folder_Unique_Name__c IN :newNames]) {
                existingFoldersMap.put(existing.FEC_Folder_Unique_Name__c.toLowerCase(), existing);
            }

            // 3. Compare and add error
            String errorMsgLabel = System.Label.FEC_Folder_Duplicate_Error;
            for (FEC_Folder__c folder : folders) {
                if (existingFoldersMap.containsKey(folder.FEC_Folder_Unique_Name__c.toLowerCase())) {
                    // Ensure we aren't flagging the record against itself during an update
                    if (Trigger.isInsert || (Trigger.isUpdate && folder.Id != existingFoldersMap.get(folder.FEC_Folder_Unique_Name__c.toLowerCase()).Id)) {
                        // Format the message with the dynamic name
                        String dynamicError = String.format(errorMsgLabel, new List<Object>{folder.FEC_Folder_Unique_Name__c});
                        folder.FEC_Folder_Unique_Name__c.addError(dynamicError);
                    }
                }
            }
        }
    }
}