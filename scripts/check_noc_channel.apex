Map<String, Schema.SObjectField> fields = Schema.SObjectType.FEC_Nature_of_Case__c.fields.getMap();
for (String fn : fields.keySet()) {
    if (fn.containsIgnoreCase('channel')) System.debug('NOC field: ' + fn);
}
System.debug('Total NOC fields: ' + fields.size());
