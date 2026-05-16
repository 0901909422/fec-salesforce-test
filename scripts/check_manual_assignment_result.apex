// tungnm37: check kết quả sau khi submit assignment thủ công nhiều team
// Thay caseId bằng case vừa test
String caseId = 'YOUR_CASE_ID'; // TODO: thay

// 1. Case info
List<Case> cases = [
    SELECT Id, CaseNumber, Status, OwnerId, Owner.Name, Owner.Type,
           FEC_Assignment_Users__c, FEC_Assignment_Count__c,
           FEC_Can_Execute_Assignment__c, FEC_Is_Submited__c,
           FEC_Stage_Name__c
    FROM Case WHERE Id = :caseId LIMIT 1
];
if (!cases.isEmpty()) {
    Case c = cases[0];
    System.debug('=== CASE INFO ===');
    System.debug('CaseNumber: ' + c.CaseNumber);
    System.debug('Status: ' + c.Status);
    System.debug('Owner: ' + c.Owner?.Name + ' (' + c.Owner?.Type + ')');
    System.debug('FEC_Assignment_Users__c: ' + c.FEC_Assignment_Users__c);
    System.debug('FEC_Assignment_Count__c: ' + c.FEC_Assignment_Count__c);
    System.debug('FEC_Can_Execute_Assignment__c: ' + c.FEC_Can_Execute_Assignment__c);
    System.debug('FEC_Is_Submited__c: ' + c.FEC_Is_Submited__c);
    System.debug('Stage: ' + c.FEC_Stage_Name__c);
}

// 2. Assignments
List<FEC_Assignment__c> assignments = [
    SELECT Id, FEC_Team__c, FEC_OwnerID__c, FEC_Assignment_Owner__c,
           FEC_Assignment_Status__c, FEC_Assignment_Type__c,
           FEC_Manual__c, FEC_Submitted_On__c, FEC_User_Role__c,
           FEC_Assignment_Routing_Action__c
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :caseId
    ORDER BY CreatedDate DESC
    LIMIT 50
];
System.debug('=== ASSIGNMENTS (' + assignments.size() + ') ===');
for (FEC_Assignment__c a : assignments) {
    System.debug('Team: ' + a.FEC_Team__c
        + ' | Queue: ' + a.FEC_OwnerID__c
        + ' | Owner: ' + a.FEC_Assignment_Owner__c
        + ' | Status: ' + a.FEC_Assignment_Status__c
        + ' | Manual: ' + a.FEC_Manual__c
        + ' | SubmittedOn: ' + a.FEC_Submitted_On__c);
}

// 3. Case Remarks (assignment type)
List<FEC_Case_Remarks__c> remarks = [
    SELECT Id, FEC_Case_Remarks__c, FEC_Remark_Type__c, FEC_Stage_Name__c,
           FEC_User__c, CreatedDate
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__c = :caseId
      AND FEC_Remark_Type__c = 'Assignment'
    ORDER BY CreatedDate DESC
    LIMIT 20
];
System.debug('=== ASSIGNMENT REMARKS (' + remarks.size() + ') ===');
for (FEC_Case_Remarks__c r : remarks) {
    System.debug('Remark: ' + r.FEC_Case_Remarks__c + ' | Stage: ' + r.FEC_Stage_Name__c + ' | User: ' + r.FEC_User__c);
}

// 4. Routing Action History
List<FEC_Routing_Action_History__c> histories = [
    SELECT Id, FEC_Routing_Action__c, FEC_Stage_Name__c,
           FEC_Updated_User_Queue__c, FEC_User_Role__c,
           FEC_Submitted_On__c, CreatedDate
    FROM FEC_Routing_Action_History__c
    WHERE FEC_Case__c = :caseId
    ORDER BY CreatedDate DESC
    LIMIT 20
];
System.debug('=== ROUTING HISTORY (' + histories.size() + ') ===');
for (FEC_Routing_Action_History__c h : histories) {
    System.debug('Action: ' + h.FEC_Routing_Action__c
        + ' | Stage: ' + h.FEC_Stage_Name__c
        + ' | Queue: ' + h.FEC_Updated_User_Queue__c
        + ' | Role: ' + h.FEC_User_Role__c);
}
