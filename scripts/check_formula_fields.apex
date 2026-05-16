// Check tất cả formula fields trên FEC_Assignment__c
Schema.DescribeSObjectResult d = FEC_Assignment__c.getSObjectType().getDescribe();
for (Schema.SObjectField f : d.fields.getMap().values()) {
    Schema.DescribeFieldResult fd = f.getDescribe();
    if (fd.isCalculated()) {
        System.debug('Formula: name=' + fd.getName() + ' type=' + fd.getType() + ' label=' + fd.getLabel());
    }
}
// Check FEC_Assignment_Owner__c cụ thể
Schema.DescribeFieldResult ownerField = FEC_Assignment__c.FEC_Assignment_Owner__c.getDescribe();
System.debug('FEC_Assignment_Owner__c: type=' + ownerField.getType() + ' calculated=' + ownerField.isCalculated() + ' referenceTo=' + ownerField.getReferenceTo());
