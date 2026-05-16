// Check fields của FEC_Enhanced_Letterhead__c
Map<String, Schema.SObjectField> fields = Schema.SObjectType.FEC_Enhanced_Letterhead__c.fields.getMap();
for (String f : fields.keySet()) {
    Schema.DescribeFieldResult d = fields.get(f).getDescribe();
    System.debug(d.getName() + ' | ' + d.getType() + ' | ' + d.getLabel());
}

// Lấy record "FEC Letterhead" đang được dùng
FEC_Enhanced_Letterhead__c lh = [SELECT Id, Name FROM FEC_Enhanced_Letterhead__c WHERE Id = 'a0xAz000000jS4zIAE' LIMIT 1];
System.debug('FEC Letterhead: ' + lh.Id + ' | ' + lh.Name);

// Query tất cả fields
List<FEC_Enhanced_Letterhead__c> all = Database.query('SELECT ' + String.join(new List<String>(fields.keySet()), ',') + ' FROM FEC_Enhanced_Letterhead__c WHERE Id = \'a0xAz000000jS4zIAE\' LIMIT 1');
if (!all.isEmpty()) {
    for (String f : fields.keySet()) {
        Object val = all[0].get(f);
        if (val != null) System.debug(f + ' = ' + String.valueOf(val).substring(0, Math.min(100, String.valueOf(val).length())));
    }
}
