// Check FEC_Enhanced_Letterhead__c field reference
Schema.DescribeFieldResult f = FEC_Template__c.FEC_Enhanced_Letterhead__c.getDescribe();
System.debug('ReferenceTo: ' + f.getReferenceTo());
System.debug('Type: ' + f.getType());

// List records của object đó
String refObj = String.valueOf(f.getReferenceTo()[0]);
System.debug('Referenced object: ' + refObj);

// Query records
List<SObject> records = Database.query('SELECT Id, Name FROM ' + refObj + ' LIMIT 5');
for (SObject r : records) {
    System.debug('Record: ' + r.get('Id') + ' | ' + r.get('Name'));
}
