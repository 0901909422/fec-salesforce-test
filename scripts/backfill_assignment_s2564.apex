// Backfill Assignment cho S-2564 (case đã submit trước khi có code mới)
String caseId = '500Az00000PvOSGIA3';

List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c,
           FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
    FROM Case WHERE Id = :caseId LIMIT 1
];
if (cases.isEmpty()) { System.debug('Not found'); return; }
Case c = cases[0];

// Get NOC
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
      AND FEC_Category__c = :c.FEC_Category__c
      AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
      AND FEC_Sub_Code__c = :c.FEC_SubCode__c
    LIMIT 1
];
if (nocs.isEmpty()) { System.debug('NOC not found'); return; }

Set<Id> nocIds = new Set<Id>{ nocs[0].Id };
User currentUser = [SELECT Email, UserRole.Name, Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

System.debug('Calling createAssignmentsOnRoute for ' + c.FEC_ID_Search__c);
FEC_CofGsrAssignmentService.createAssignmentsOnRoute(caseId, nocIds, currentUser, null, c.FEC_Stage_Name__c, null);

// Verify
List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Assignment_Type__c, FEC_OwnerID__c, FEC_Team__c
    FROM FEC_Assignment__c WHERE FEC_Case__c = :caseId ORDER BY CreatedDate DESC
];
System.debug('Assignments created: ' + assignments.size());
for (FEC_Assignment__c a : assignments) {
    System.debug('  ' + a.Name + ' | Team=' + a.FEC_Team__c + ' | OwnerID=' + a.FEC_OwnerID__c);
}
