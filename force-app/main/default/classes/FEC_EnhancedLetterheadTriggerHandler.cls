public without sharing class FEC_EnhancedLetterheadTriggerHandler {
    
    public static void run() {
        FEC_EnhancedLetterheadTriggerHandler handler = new FEC_EnhancedLetterheadTriggerHandler();
        
        if (Trigger.isBefore) {
            if (Trigger.isDelete) {
                // New logic for delete validation
                handler.validateFolderDeletion((List<FEC_Enhanced_Letterhead__c>) Trigger.old);
            }
        }
    }

    /**
     * Prevents deletion if the folder contains any active templates.
     */
    private void validateFolderDeletion(List<FEC_Enhanced_Letterhead__c> letters) {
        Set<Id> letterheadIds = new Map<Id, FEC_Enhanced_Letterhead__c>(letters).keySet();
        Set<Id> letterheadWithActiveTemplates = new Set<Id>();

        // 1. Query for any active templates linked to these folders
        for (FEC_Template__c template : [SELECT FEC_Enhanced_Letterhead__c 
                                         FROM FEC_Template__c 
                                         WHERE FEC_Enhanced_Letterhead__c IN :letterheadIds 
                                         AND FEC_Active__c = true]) {
            letterheadWithActiveTemplates.add(template.FEC_Enhanced_Letterhead__c);
        }

        
        for (FEC_Enhanced_Letterhead__c item : letters) {
            if (letterheadWithActiveTemplates.contains(item.Id)) {
                item.addError(System.Label.FEC_Cannot_Delete_Enhanced_Letterhead);
            }
        }
    }
}