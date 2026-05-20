// tungnm37: kế thừa Channel + Sub Process: cùng FEC_Product_Type__c, cha = nhiều null hơn (không Sub Code)
trigger FEC_NatureOfCaseTrigger on FEC_Nature_of_Case__c (after insert, after update) {
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        Map<Id, FEC_Nature_of_Case__c> oldMap = Trigger.isUpdate ? Trigger.oldMap : null;
        FEC_NatureOfCaseTriggerHandler.handleAfterInsertUpdate(Trigger.new, oldMap);
        FEC_NocRemovePhoneInheritanceHandler.handleAfterInsertUpdate(Trigger.new, oldMap);
    }
}