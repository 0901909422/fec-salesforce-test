trigger CustomSyncTrigger on CustomSync__c (before insert, before update) {
    List<CustomSync__c> toValidate = new List<CustomSync__c>();
    Set<String> validatedFields = new Set<String>{
        'CaseBusinessCode__c', 'TargetObject__c', 'ProcessingQuantity__c',
        'RequestBodyMapping__c', 'MappingDataType__c'
    };

    for (CustomSync__c rec : Trigger.new) {
        if (Trigger.isInsert && rec.Active__c == true) {
            toValidate.add(rec);
        }
        if (Trigger.isUpdate) {
            CustomSync__c oldRec = Trigger.oldMap.get(rec.Id);
            // Case 1: Active chuyển từ false -> true
            if (!oldRec.Active__c && rec.Active__c == true) {
                toValidate.add(rec);
            }
            // Case 2: Đang Active = true và chỉnh sửa các field quan trọng
            else if (oldRec.Active__c && rec.Active__c == true) {
                Boolean fieldChanged = false;
                for (String fieldName : validatedFields) {
                    if (rec.get(fieldName) != oldRec.get(fieldName)) {
                        fieldChanged = true;
                        break;
                    }
                }
                if (fieldChanged) {
                    toValidate.add(rec);
                }
            }
        }
    }
    if (!toValidate.isEmpty()) {
        FEC_CustomSyncValidator.validate(toValidate);
    }
}