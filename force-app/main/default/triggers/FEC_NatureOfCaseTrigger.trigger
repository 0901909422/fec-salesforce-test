// tungnm37: kế thừa FEC_Channel__c từ NOC cha; kế thừa cờ Remove Phone / DNB / Transfer Call theo hierarchy
trigger FEC_NatureOfCaseTrigger on FEC_Nature_of_Case__c (after insert, after update) {
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        Map<Id, FEC_Nature_of_Case__c> oldMap = Trigger.isUpdate ? Trigger.oldMap : null;
        FEC_NatureOfCaseTriggerHandler.handleAfterInsertUpdate(Trigger.new, oldMap);
        FEC_NocRemovePhoneInheritanceHandler.handleAfterInsertUpdate(Trigger.new, oldMap);
    }
}
