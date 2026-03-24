Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Case.fields.getMap();
Schema.SObjectField f = fieldMap.get('FEC_Interaction_Subchannel__c');
if (f == null) {
    System.debug('Field NOT FOUND on Case');
} else {
    for (Schema.PicklistEntry e : f.getDescribe().getPicklistValues()) {
        System.debug('Value: [' + e.getValue() + '] active: ' + e.isActive());
    }
}
