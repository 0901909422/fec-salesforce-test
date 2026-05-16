List<Case> cases = [SELECT Id, FEC_ID_Search__c, FEC_Assignment_Users__c, OwnerId, Owner.Name, Owner.Type,
    FEC_Service_Case_Owner__c, FEC_Is_Submited__c,
    FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c
    FROM Case WHERE FEC_ID_Search__c = 'S-2401' LIMIT 1];
if (cases.isEmpty()) { System.debug('Not found'); return; }
Case c = cases[0];
System.debug('Owner=' + c.Owner?.Name + ' OwnerType=' + c.Owner?.Type);
System.debug('AssignmentUsers=[' + c.FEC_Assignment_Users__c + ']');
System.debug('ServiceCaseOwner=[' + c.FEC_Service_Case_Owner__c + ']');
System.debug('IsSubmited=' + c.FEC_Is_Submited__c);
System.debug('BPCode=' + c.FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c);

List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Manual__c, FEC_OwnerID__c, FEC_Assignment_Routing_Action__c
    FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('Assignments: ' + assignments.size());
for (FEC_Assignment__c a : assignments) {
    System.debug('  ' + a.Name + ' Manual=' + a.FEC_Manual__c + ' Owner=' + a.FEC_OwnerID__c);
}
