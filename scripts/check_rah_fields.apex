Map<String, Schema.SObjectField> fields = Schema.SObjectType.FEC_Routing_Action_History__c.fields.getMap();
List<String> missing = new List<String>();
for (String fn : new List<String>{'fec_assigned_on__c','fec_tat_by_assignment__c','fec_submitted_on__c','fec_manual__c'}) {
    if (!fields.containsKey(fn)) missing.add(fn);
    else System.debug('EXISTS: ' + fn);
}
if (!missing.isEmpty()) System.debug('MISSING fields: ' + missing);
else System.debug('All fields exist');
