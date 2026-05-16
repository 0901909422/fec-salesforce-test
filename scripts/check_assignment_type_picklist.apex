Schema.DescribeFieldResult f = FEC_Assignment__c.FEC_Assignment_Type__c.getDescribe();
System.debug('type=' + f.getType());
for (Schema.PicklistEntry e : f.getPicklistValues()) {
    System.debug('value=' + e.getValue() + ' active=' + e.isActive());
}
