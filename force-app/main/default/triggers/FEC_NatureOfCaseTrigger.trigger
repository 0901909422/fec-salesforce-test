// tungnm37: Trigger kế thừa FEC_Channel__c từ NOC cha xuống NOC con
trigger FEC_NatureOfCaseTrigger on FEC_Nature_of_Case__c (after insert, after update) {
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        // Re-query để lấy đủ các field hierarchy
        Set<Id> ids = Trigger.newMap.keySet();
        List<FEC_Nature_of_Case__c> fullRecords = [
            SELECT Id, FEC_Channel__c, FEC_Business_Process__c,
                   FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
            FROM FEC_Nature_of_Case__c WHERE Id IN :ids
        ];
        // tungnm37: dùng Trigger.new để lấy channel cũ từ oldMap (không dùng re-query cho old)
        Map<Id, FEC_Nature_of_Case__c> oldMap = Trigger.isUpdate ? Trigger.oldMap : null;
        FEC_NocChannelInheritanceHandler.handleAfterInsertUpdate(fullRecords, oldMap);
    }
}
