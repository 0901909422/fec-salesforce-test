String caseId = '5008500000HwJ6vAAF';

List<Case> cases = [
    SELECT Id, FEC_ID_Search__c,
           FEC_Assignment_Count__c,
           FEC_Business_Process__c,
           FEC_Business_Process__r.FEC_Code__c,
           FEC_Service_Case_Owner__c,
           OwnerId, Owner.Name
    FROM Case WHERE Id = :caseId LIMIT 1
];
if (cases.isEmpty()) { System.debug('Not found'); return; }
Case c = cases[0];
System.debug('Case: ' + c.FEC_ID_Search__c);
System.debug('FEC_Assignment_Count__c: ' + c.FEC_Assignment_Count__c);
System.debug('FEC_Business_Process__c: ' + c.FEC_Business_Process__c);
System.debug('FEC_Business_Process__r.FEC_Code__c: ' + c.FEC_Business_Process__r?.FEC_Code__c);
System.debug('FEC_Service_Case_Owner__c: ' + c.FEC_Service_Case_Owner__c);
System.debug('Owner: ' + c.Owner?.Name);

// Check assignments
List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Assignment_Type__c, FEC_OwnerID__c
    FROM FEC_Assignment__c WHERE FEC_Case__c = :caseId
    ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('Assignments: ' + assignments.size());
for (FEC_Assignment__c a : assignments) {
    System.debug('  ' + a.Name + ' | Type=' + a.FEC_Assignment_Type__c + ' | OwnerID=' + a.FEC_OwnerID__c);
}
