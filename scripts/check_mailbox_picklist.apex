// Check picklist values of FEC_Applicable_for_Mailbox__c
Schema.DescribeFieldResult fieldResult = FEC_Template__c.FEC_Applicable_for_Mailbox__c.getDescribe();
List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();
System.debug('Total picklist values: ' + entries.size());
for (Schema.PicklistEntry e : entries) {
    System.debug('Value: ' + e.getValue() + ' | Label: ' + e.getLabel() + ' | Active: ' + e.isActive());
}
