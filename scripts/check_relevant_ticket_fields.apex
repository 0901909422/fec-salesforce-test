Map<String, Schema.SObjectField> fields = Schema.SObjectType.FEC_Relevant_Ticket__c.fields.getMap();
for (String f : fields.keySet()) {
    Schema.DescribeFieldResult d = fields.get(f).getDescribe();
    if (d.getType() == Schema.DisplayType.REFERENCE) {
        System.debug(f + ' (' + d.getType() + ') → ' + d.getReferenceTo());
    }
}
