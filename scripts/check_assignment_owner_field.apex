Schema.DescribeFieldResult ownerField = Schema.SObjectType.FEC_Assignment__c.fields.getMap().get('OwnerId').getDescribe();
System.debug('Standard OwnerId type: ' + ownerField.getType());

List<FEC_Assignment__c> assignments = [
    SELECT Id, OwnerId, Owner.Name, FEC_OwnerID__c
    FROM FEC_Assignment__c
    WHERE FEC_Assignment_Type__c = 'Routing'
    ORDER BY CreatedDate DESC LIMIT 3
];
for (FEC_Assignment__c a : assignments) {
    System.debug('OwnerId: ' + a.OwnerId + ' | Owner.Name: ' + a.Owner?.Name + ' | FEC_OwnerID__c: ' + a.FEC_OwnerID__c);
}
