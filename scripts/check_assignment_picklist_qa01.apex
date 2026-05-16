// Check picklist values của FEC_Assignment_Type__c và FEC_Assignment_Name__c trên qa01
Schema.DescribeFieldResult typeField = FEC_Assignment__c.FEC_Assignment_Type__c.getDescribe();
List<Schema.PicklistEntry> typeValues = typeField.getPicklistValues();
System.debug('=== FEC_Assignment_Type__c values ===');
for (Schema.PicklistEntry pe : typeValues) {
    System.debug('  ' + pe.getValue() + ' | Active: ' + pe.isActive());
}

Schema.DescribeFieldResult nameField = FEC_Assignment__c.FEC_Assignment_Name__c.getDescribe();
List<Schema.PicklistEntry> nameValues = nameField.getPicklistValues();
System.debug('=== FEC_Assignment_Name__c values ===');
for (Schema.PicklistEntry pe : nameValues) {
    System.debug('  ' + pe.getValue() + ' | Active: ' + pe.isActive());
}
