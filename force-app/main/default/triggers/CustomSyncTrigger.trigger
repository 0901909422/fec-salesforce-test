trigger CustomSyncTrigger on CustomSync__c (before insert, before update) {
    List<CustomSync__c> toValidate = new List<CustomSync__c>();
    for (CustomSync__c rec : Trigger.new) {
        if (Trigger.isInsert && rec.Active__c == true) {
            toValidate.add(rec);
        }
        if (Trigger.isUpdate) {
            Boolean wasActive = Trigger.oldMap.get(rec.Id).Active__c;
            if (!wasActive && rec.Active__c == true) {
                toValidate.add(rec);
            }
        }
    }
    if (!toValidate.isEmpty()) {
        FEC_CustomSyncValidator.validate(toValidate);
    }
}