List<Case> cases = [
    SELECT Id, CaseNumber, FEC_SubCode__c, FEC_SubCategory__c,
           FEC_Category__c, FEC_Product_Type__c, FEC_Assignment_Users__c
    FROM Case WHERE FEC_ID_Search__c = 'S-1426' LIMIT 1
];
if (cases.isEmpty()) { System.debug('Not found'); return; }
Case c = cases[0];
System.debug('=== CASE === ' + c.Id + ' / ' + c.CaseNumber);
System.debug('BEFORE Case.FEC_Assignment_Users__c = ' + c.FEC_Assignment_Users__c);

List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
      AND FEC_Category__c = :c.FEC_Category__c
      AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
      AND FEC_Sub_Code__c = :c.FEC_SubCode__c
      AND FEC_Active__c = true
    LIMIT 5
];
System.debug('Matching NOCs: ' + nocs.size());
if (nocs.isEmpty()) { System.debug('No matching NOC'); return; }

Set<Id> nocIds = new Map<Id, FEC_Nature_of_Case__c>(nocs).keySet();
List<FEC_Routing_Assignment__c> ras = [
    SELECT FEC_Team__c, FEC_Queue__c
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Nature_of_Cases__c IN :nocIds
      AND FEC_Active__c = true AND FEC_Team__c != null AND FEC_Queue__c != null
];
System.debug('Routing Assignments: ' + ras.size());
if (ras.isEmpty()) { System.debug('No routing assignment'); return; }

User u = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
FEC_CofGsrAssignmentService.createAssignmentsOnRoute(c.Id, nocIds, u, null, 'Test Stage', 'Test remark');

List<FEC_Assignment__c> assignments = [
    SELECT Id, FEC_Team__c, FEC_Assignment_Owner__c, FEC_Assignment_Owner__r.Name, FEC_OwnerID__c, FEC_Assignment_Status__c
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :c.Id AND FEC_Assignment_Type__c = 'Routing'
    ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('=== Assignments created: ' + assignments.size());
for (FEC_Assignment__c a : assignments) {
    System.debug('Assignment ' + a.Id + ' | Team: ' + a.FEC_Team__c + ' | OwnerUserId: ' + a.FEC_Assignment_Owner__c + ' | OwnerName: ' + a.FEC_Assignment_Owner__r?.Name + ' | OwnerID: ' + a.FEC_OwnerID__c);
}
if (assignments.isEmpty()) { System.debug('No assignment created'); return; }

Id targetUserId = '005Az00000FTHoNIAX';
FEC_Assignment__c assignmentToUpdate = assignments[0];
assignmentToUpdate.FEC_Assignment_Owner__c = targetUserId;
update assignmentToUpdate;
System.debug('Updated assignment ' + assignmentToUpdate.Id + ' to user ' + targetUserId);

Case caseAfter = [
    SELECT Id, FEC_Assignment_Users__c
    FROM Case
    WHERE Id = :c.Id
    LIMIT 1
];
System.debug('AFTER Case.FEC_Assignment_Users__c = ' + caseAfter.FEC_Assignment_Users__c);
System.debug('EXPECTED = ' + targetUserId);
System.debug('MATCH = ' + (caseAfter.FEC_Assignment_Users__c == String.valueOf(targetUserId)));
