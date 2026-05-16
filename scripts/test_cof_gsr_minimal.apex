// tungnm37: Test minimal - gọi createAssignmentsOnRoute trực tiếp

// 1. Lấy NOC Loan có RA
FEC_Routing_Assignment__c loanRA = [
    SELECT FEC_Nature_of_Cases__c, FEC_Team__c, FEC_Queue__c
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Nature_of_Cases__r.FEC_Product_Type__r.Name = 'Loan'
      AND FEC_Team__c != null AND FEC_Queue__c != null
    LIMIT 1
];
System.debug('Loan RA NOC: ' + loanRA.FEC_Nature_of_Cases__c + ' Team: ' + loanRA.FEC_Team__c);

// 2. Tìm Case Loan
Case c = [SELECT Id, OwnerId FROM Case WHERE FEC_Product_Type__r.Name = 'Loan' AND IsClosed = false LIMIT 1];
System.debug('Case: ' + c.Id);

// 3. Đếm trước
Integer before = [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id];
System.debug('Assignments BEFORE: ' + before);

// 4. Resolve NOC IDs
Set<Id> nocIds = FEC_CofGsrAssignmentService.resolveToNocIds(loanRA.FEC_Nature_of_Cases__c);
System.debug('Resolved NOC IDs: ' + nocIds.size() + ' -> ' + nocIds);

// 5. Gọi createAssignmentsOnRoute
User currentUser = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
FEC_CofGsrAssignmentService.createAssignmentsOnRoute(c.Id, nocIds, currentUser, null, 'Stage 1', 'Test Loan remark');

// 6. Verify
Integer after = [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id];
System.debug('Assignments AFTER: ' + after + ' | Created: ' + (after - before));

List<FEC_Assignment__c> created = [
    SELECT Id, FEC_Assignment_Name__c, FEC_Team__c, FEC_OwnerID__c, FEC_Assignment_Status__c
    FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id ORDER BY CreatedDate DESC LIMIT 5
];
for (FEC_Assignment__c a : created) {
    System.debug('=> Assignment: ' + a.Id + ' | Name=' + a.FEC_Assignment_Name__c + ' | Team=' + a.FEC_Team__c + ' | Status=' + a.FEC_Assignment_Status__c + ' | OwnerId=' + a.FEC_OwnerID__c);
}
