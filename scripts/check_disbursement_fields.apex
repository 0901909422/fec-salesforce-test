Map<String, Schema.SObjectField> fields = Schema.SObjectType.Case.fields.getMap();
for (String f : new List<String>{'FEC_Disbursement_Status__c', 'FEC_Disbursement_Date__c', 'FEC_Remarks__c'}) {
    System.debug(f + ' exists=' + fields.containsKey(f.toLowerCase()));
}
