// Check picklist values of FEC_Channel__c
Schema.DescribeFieldResult f = Case.FEC_Channel__c.getDescribe();
List<Schema.PicklistEntry> entries = f.getPicklistValues();
for (Schema.PicklistEntry e : entries) {
    System.debug('Value=[' + e.getValue() + '] Label=[' + e.getLabel() + '] Active=' + e.isActive());
}

// Also check the actual case
Case c = [SELECT Id, FEC_Channel__c FROM Case WHERE Id = '500Az00000Mr8ysIAB' LIMIT 1];
System.debug('Actual Channel=[' + c.FEC_Channel__c + ']');
