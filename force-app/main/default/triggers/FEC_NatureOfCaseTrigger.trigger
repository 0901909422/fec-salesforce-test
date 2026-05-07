// Trigger kế thừa các cấu hình NOC từ level cha xuống level con
trigger FEC_NatureOfCaseTrigger on FEC_Nature_of_Case__c (after insert, after update) {
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        // Re-query để lấy đủ các field hierarchy
        Set<Id> ids = Trigger.newMap.keySet();
        List<FEC_Nature_of_Case__c> fullRecords = [
            SELECT Id, FEC_Channel__c, FEC_Remove_Phone__c, FEC_Do_Not_Bother__c, FEC_Transfer_Call_to_Collection__c,
                   FEC_Active__c, FEC_Business_Process__c,
                   FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
            FROM FEC_Nature_of_Case__c WHERE Id IN :ids
        ];
        // Dùng Trigger.oldMap để so sánh giá trị cũ.
        Map<Id, FEC_Nature_of_Case__c> oldMap = Trigger.isUpdate ? Trigger.oldMap : null;
        FEC_NocChannelInheritanceHandler.handleAfterInsertUpdate(fullRecords, oldMap);
        FEC_NocRemovePhoneInheritanceHandler.handleAfterInsertUpdate(fullRecords, oldMap);
    }
}
