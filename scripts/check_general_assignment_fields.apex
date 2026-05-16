Map<String, Schema.SObjectField> fields = Schema.SObjectType.FEC_General_Assignment__c.fields.getMap();
for (String fn : fields.keySet()) {
    if (fn.containsIgnoreCase('stage') || fn.containsIgnoreCase('noc') || fn.containsIgnoreCase('nature')) {
        System.debug(fn + ' | ' + fields.get(fn).getDescribe().getType());
    }
}
System.debug('All custom fields:');
for (String fn : fields.keySet()) {
    if (fn.startsWith('fec_')) System.debug('  ' + fn);
}
