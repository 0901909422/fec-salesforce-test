Map<String, Schema.SObjectField> fields = Schema.SObjectType.FEC_Assignment__c.fields.getMap();
for (String fn : new List<String>{'fec_manual__c','fec_submitted_on__c'}) {
    System.debug(fn + ': ' + (fields.containsKey(fn) ? 'EXISTS' : 'MISSING'));
}
// Check FEC_Case_Created_On__c on Case
Map<String, Schema.SObjectField> caseFields = Schema.SObjectType.Case.fields.getMap();
System.debug('Case.FEC_Case_Created_On__c: ' + (caseFields.containsKey('fec_case_created_on__c') ? 'EXISTS' : 'MISSING'));
// Check FEC_Assigned_On__c on RAH
Map<String, Schema.SObjectField> rahFields = Schema.SObjectType.FEC_Routing_Action_History__c.fields.getMap();
System.debug('RAH.FEC_Assigned_On__c: ' + (rahFields.containsKey('fec_assigned_on__c') ? 'EXISTS' : 'MISSING'));
System.debug('RAH.FEC_TAT_by_Assignment__c: ' + (rahFields.containsKey('fec_tat_by_assignment__c') ? 'EXISTS' : 'MISSING'));
