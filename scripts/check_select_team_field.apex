// Check FEC_Select_Team__c field info on org
Map<String, Schema.SObjectField> fields = Schema.SObjectType.FEC_Team_Queue__c.fields.getMap();
Schema.SObjectField f = fields.get('FEC_Select_Team__c');
if (f != null) {
    Schema.DescribeFieldResult dfr = f.getDescribe();
    System.debug('Field: ' + dfr.getName());
    System.debug('Type: ' + dfr.getType());
    List<Schema.sObjectType> refs = dfr.getReferenceTo();
    for (Schema.sObjectType ref : refs) {
        System.debug('ReferenceTo: ' + ref.getDescribe().getName());
    }
} else {
    System.debug('Field FEC_Select_Team__c not found');
}

// Also check if FEC_Team__c object exists
try {
    Schema.DescribeSObjectResult d = Schema.SObjectType.FEC_Team__c;
    System.debug('FEC_Team__c exists: ' + d.getName());
} catch (Exception e) {
    System.debug('FEC_Team__c does NOT exist: ' + e.getMessage());
}
