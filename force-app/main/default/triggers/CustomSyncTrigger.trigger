trigger CustomSyncTrigger on CustomSync__c (before insert, before update) {
    List<CustomSync__c> toValidate = new List<CustomSync__c>();
    for (CustomSync__c rec : Trigger.new) {
        if (Trigger.isUpdate) {
            Boolean wasActive = Trigger.oldMap.get(rec.Id).Active__c;
            // Block edits while Active = true (except toggling Active to false)
            if (wasActive && rec.Active__c == true) {
                rec.addError('Cannot edit while Active is true. Please deactivate first.');
                continue;
            }
            // Validate when activating (false → true)
            if (!wasActive && rec.Active__c == true) {
                toValidate.add(rec);
            }
        }
        if (Trigger.isInsert && rec.Active__c == true) {
            toValidate.add(rec);
        }
    }
    if (!toValidate.isEmpty()) {
        FEC_CustomSyncValidator.validate(toValidate);
    }
}
