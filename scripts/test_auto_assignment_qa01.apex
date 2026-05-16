// tungnm37: Test auto assignment (non CC/SP team) trên qa01
// Dùng NOC Loan GSR có team CP -> createAssignmentsOnRoute

// 1. Lấy RA Loan GSR team CP (không phải CC/SP -> chạy auto assignment)
FEC_Routing_Assignment__c ra = [
    SELECT FEC_Nature_of_Cases__c, FEC_Team__c, FEC_Queue__c,
           FEC_Nature_of_Cases__r.FEC_Business_Process__r.FEC_Code__c,
           FEC_Nature_of_Cases__r.FEC_Product_Type__r.Name
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Nature_of_Cases__r.FEC_Product_Type__r.Name = 'Loan'
      AND FEC_Team__c NOT IN ('CC', 'SP')
      AND FEC_Team__c != null AND FEC_Queue__c != null
    LIMIT 1
];
System.debug('Using RA: NOC=' + ra.FEC_Nature_of_Cases__c
    + ' | PT=' + ra.FEC_Nature_of_Cases__r?.FEC_Product_Type__r?.Name
    + ' | BP=' + ra.FEC_Nature_of_Cases__r?.FEC_Business_Process__r?.FEC_Code__c
    + ' | Team=' + ra.FEC_Team__c + ' | Queue=' + ra.FEC_Queue__c);

// 2. Lấy Case Loan chưa đóng
Case c = [SELECT Id, CaseNumber, OwnerId, Owner.Name FROM Case
          WHERE FEC_Product_Type__r.Name = 'Loan' AND IsClosed = false
          LIMIT 1];
System.debug('Case: ' + c.CaseNumber + ' | ' + c.Id + ' | Owner=' + c.Owner?.Name);

// 3. Đếm trước
Integer before = [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id];
System.debug('Assignments BEFORE: ' + before);

// 4. Resolve NOC IDs
Set<Id> nocIds = FEC_CofGsrAssignmentService.resolveToNocIds(ra.FEC_Nature_of_Cases__c);
System.debug('Resolved NOC IDs: ' + nocIds.size());

// 5. Gọi createAssignmentsOnRoute trực tiếp
User currentUser = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
FEC_CofGsrAssignmentService.createAssignmentsOnRoute(c.Id, nocIds, currentUser, null, 'Stage 1', 'Test auto assignment qa01');

// 6. Verify
Integer after = [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id];
System.debug('Assignments AFTER: ' + after + ' | Created: ' + (after - before));

List<FEC_Assignment__c> created = [
    SELECT Id, FEC_Assignment_Name__c, FEC_Team__c, FEC_OwnerID__c,
           FEC_Assignment_Status__c, FEC_Assignment_Remark__c
    FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id
    ORDER BY CreatedDate DESC LIMIT 5
];
for (FEC_Assignment__c a : created) {
    System.debug('=> Assignment: ' + a.Id
        + ' | Name=' + a.FEC_Assignment_Name__c
        + ' | Team=' + a.FEC_Team__c
        + ' | Status=' + a.FEC_Assignment_Status__c
        + ' | OwnerId=' + a.FEC_OwnerID__c);
}

// 7. Verify Routing History
List<FEC_Routing_Action_History__c> histories = [
    SELECT Id, FEC_Routing_Action__c, FEC_Updated_User_Queue__c, FEC_Stage_Name__c
    FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c.Id
    ORDER BY CreatedDate DESC LIMIT 3
];
System.debug('Routing Histories created: ' + histories.size());
for (FEC_Routing_Action_History__c h : histories) {
    System.debug('=> History: Action=' + h.FEC_Routing_Action__c
        + ' | Queue=' + h.FEC_Updated_User_Queue__c
        + ' | Stage=' + h.FEC_Stage_Name__c);
}
