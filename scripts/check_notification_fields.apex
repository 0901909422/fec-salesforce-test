// Check datatype các field của FEC_Notification__c trên org
Map<String, Schema.SObjectField> fields = Schema.SObjectType.FEC_Notification__c.fields.getMap();
for (String f : fields.keySet()) {
    Schema.DescribeFieldResult d = fields.get(f).getDescribe();
    if (d.getName().startsWith('FEC_')) {
        System.debug(d.getName() + ' | ' + d.getType() + ' | ' + d.getLabel() + ' | referenceTo=' + d.getReferenceTo());
    }
}
