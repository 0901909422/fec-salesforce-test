Schema.DescribeFieldResult f = FEC_Assignment__c.FEC_Assignment_Name__c.getDescribe();
System.debug('type=' + f.getType());
for (Schema.PicklistEntry e : f.getPicklistValues()) {
    System.debug('value=' + e.getValue() + ' label=' + e.getLabel() + ' active=' + e.isActive());
}
