// Check FEC_Final_Status__c field and Case Status picklist values
Schema.DescribeFieldResult finalStatus = Case.FEC_Final_Status__c.getDescribe();
System.debug('FEC_Final_Status__c type=' + finalStatus.getType());

Schema.DescribeFieldResult status = Case.Status.getDescribe();
for (Schema.PicklistEntry e : status.getPicklistValues()) {
    if (e.getValue().containsIgnoreCase('Resolved') || e.getValue().containsIgnoreCase('Cancel')) {
        System.debug('Status value=' + e.getValue());
    }
}
