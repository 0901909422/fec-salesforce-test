// Check PS nào có field permissions cho FEC_Channel__c
List<FieldPermissions> existing = [
    SELECT Parent.Name, Field
    FROM FieldPermissions
    WHERE SobjectType = 'FEC_Channel__c'
    ORDER BY Parent.Name
    LIMIT 200
];
Set<String> psNames = new Set<String>();
for (FieldPermissions fp : existing) psNames.add(fp.Parent.Name);
System.debug('PS count: ' + psNames.size());
for (String ps : psNames) System.debug(ps);

// Check 4 field mới
for (String field : new List<String>{
    'FEC_Channel__c.FEC_Cancel_Case__c',
    'FEC_Channel__c.FEC_Get_Nature_Of_Case__c',
    'FEC_Channel__c.FEC_Update_Case_Status__c',
    'FEC_Nature_of_Case__c.FEC_Channel__c'
}) {
    Integer cnt = [SELECT COUNT() FROM FieldPermissions WHERE Field = :field];
    System.debug(field + ': ' + cnt + ' PS');
}
