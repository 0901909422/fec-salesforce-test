// Check datatype NOC fields trên Case
Map<String, Schema.SObjectField> fields = Schema.SObjectType.Case.fields.getMap();
List<String> nocFields = new List<String>{'FEC_Product_Type__c','FEC_Category__c','FEC_SubCategory__c','FEC_SubCode__c'};
for (String f : nocFields) {
    if (fields.containsKey(f.toLowerCase())) {
        Schema.DescribeFieldResult d = fields.get(f.toLowerCase()).getDescribe();
        System.debug('Case.' + d.getName() + ' | ' + d.getType() + ' | referenceTo=' + d.getReferenceTo());
    }
}
