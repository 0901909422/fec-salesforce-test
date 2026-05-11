// tungnm37: Trigger kế thừa FEC_Channel__c từ NOC cha xuống NOC con
trigger FEC_NatureOfCaseTrigger on FEC_Nature_of_Case__c (after insert, after update) {
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        // tungnm37: dùng Trigger.new trực tiếp, oldMap chỉ dùng để detect channel thay đổi khi update
        Map<Id, FEC_Nature_of_Case__c> oldMap = Trigger.isUpdate ? Trigger.oldMap : null;
        FEC_NatureOfCaseTriggerHandler.handleAfterInsertUpdate(Trigger.new, oldMap);
    }
}
