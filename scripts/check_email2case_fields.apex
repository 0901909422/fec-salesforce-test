// Describe EmailRoutingAddress fields
Map<String, Schema.SObjectField> fields = Schema.SObjectType.EmailRoutingAddress.fields.getMap();
System.debug('EmailRoutingAddress fields:');
List<String> fieldNames = new List<String>(fields.keySet());
fieldNames.sort();
for (String f : fieldNames) {
    System.debug('  ' + f + ' (' + fields.get(f).getDescribe().getType() + ')');
}
