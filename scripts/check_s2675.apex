// tungnm37: check S-2675 assignment result
List<Case> cases = [
    SELECT Id, CaseNumber, Status, OwnerId, Owner.Name, Owner.Type,
           FEC_Assignment_Users__c, FEC_Assignment_Count__c,
           FEC_Can_Execute_Assignment__c, FEC_Is_Submited__c,
           FEC_Stage_Name__c
    FROM Case WHERE CaseNumber = '00002675' LIMIT 1
];
if (cases.isEmpty()) { System.debug('Case S-2675 not found'); return; }

Case c = cases[0];
System.debug('=== CASE INFO ===');
System.debug('Id: ' + c.Id);
System.debug('Status: ' + c.Status);
System.debug('Owner: ' + c.Owner?.Name + ' (' + c.Owner?.Type + ')');
System.debug('FEC_Assignment_Users__c: ' + c.FEC_Assignment_Users__c);
System.debug('FEC_Assignment_Count__c: ' + c.FEC_Assignment_Count__c);
System.debug('FEC_Can_Execute_Assignment__c: ' + c.FEC_Can_Execute_Assignment__c);
System.debug('FEC_Is_Submited__c: ' + c.FEC_Is_Submited__c);
System.debug('Stage: ' + c.FEC_Stage_Name__c);

List<FEC_Assignment__c> assignments = [
    SELECT Id, FEC_Team__c, FEC_OwnerID__c, FEC_Assignment_Owner__c,
           FEC_Assignment_Status__c, FEC_Assignment_Type__c,
           FEC_Manual__c, FEC_User_Role__c
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :c.Id
    ORDER BY CreatedDate DESC LIMIT 50
];
System.debug('=== ASSIGNMENTS (' + assignments.size() + ') ===');
for (FEC_Assignment__c a : assignments) {
    System.debug('Team: ' + a.FEC_Team__c
        + ' | Queue: ' + a.FEC_OwnerID__c
        + ' | Owner: ' + a.FEC_Assignment_Owner__c
        + ' | Status: ' + a.FEC_Assignment_Status__c
        + ' | Manual: ' + a.FEC_Manual__c);
}

List<FEC_Case_Remarks__c> remarks = [
    SELECT FEC_Case_Remarks__c, FEC_Remark_Type__c, FEC_Stage_Name__c, FEC_User__c, CreatedDate
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__c = :c.Id AND FEC_Remark_Type__c = 'Assignment'
    ORDER BY CreatedDate DESC LIMIT 10
];
System.debug('=== ASSIGNMENT REMARKS (' + remarks.size() + ') ===');
for (FEC_Case_Remarks__c r : remarks) {
    System.debug('Remark: ' + r.FEC_Case_Remarks__c + ' | Stage: ' + r.FEC_Stage_Name__c + ' | User: ' + r.FEC_User__c);
}

List<FEC_Routing_Action_History__c> histories = [
    SELECT FEC_Routing_Action__c, FEC_Stage_Name__c, FEC_Updated_User_Queue__c,
           FEC_User_Role__c, FEC_Submitted_On__c, CreatedDate
    FROM FEC_Routing_Action_History__c
    WHERE FEC_Case__c = :c.Id
    ORDER BY CreatedDate DESC LIMIT 10
];
System.debug('=== ROUTING HISTORY (' + histories.size() + ') ===');
for (FEC_Routing_Action_History__c h : histories) {
    System.debug('Action: ' + h.FEC_Routing_Action__c
        + ' | Stage: ' + h.FEC_Stage_Name__c
        + ' | Queue: ' + h.FEC_Updated_User_Queue__c
        + ' | Role: ' + h.FEC_User_Role__c);
}
