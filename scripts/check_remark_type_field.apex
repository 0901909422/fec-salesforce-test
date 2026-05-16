Schema.DescribeFieldResult f = FEC_Case_Remarks__c.Remark_Type__c.getDescribe();
System.debug('Remark_Type__c: type=' + f.getType() + ' label=' + f.getLabel());
List<Schema.PicklistEntry> vals = f.getPicklistValues();
for (Schema.PicklistEntry v : vals) {
    System.debug('picklist value=' + v.getValue() + ' label=' + v.getLabel());
}
