trigger FEC_FolderTrigger on FEC_Folder__c (before insert, before update) {
    FEC_FolderTriggerHandler.run();
}