// Test full luồng thủ công COF/GSR - kiểm tra Case Remarks
// S-2367: Stage 2 bị 5 bản ghi (3 Assignment + 2 Case Remark duplicate)

List<Case> cases = [SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c, FEC_Is_Submited__c, OwnerId, Owner.Name
    FROM Case WHERE FEC_ID_Search__c = 'S-2368' LIMIT 1];
if (cases.isEmpty()) { System.debug('Case S-2368 not found'); return; }
Case c = cases[0];
System.debug('=== CASE INFO ===');
System.debug('Id=' + c.Id + ' Stage=[' + c.FEC_Stage_Name__c + '] IsSubmited=' + c.FEC_Is_Submited__c + ' Owner=' + c.Owner?.Name);

// Check Assignments
List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Assignment_Routing_Action__c, FEC_Manual__c, FEC_OwnerID__c, FEC_Team__c, CreatedDate
    FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id ORDER BY CreatedDate ASC
];
System.debug('=== ASSIGNMENTS (' + assignments.size() + ') ===');
for (FEC_Assignment__c a : assignments) {
    System.debug('  Name=' + a.Name + ' Stage=[' + a.FEC_Assignment_Routing_Action__c + '] Manual=' + a.FEC_Manual__c + ' Team=' + a.FEC_Team__c + ' Queue=' + a.FEC_OwnerID__c + ' Date=' + a.CreatedDate);
}

// Check Case Remarks
List<FEC_Case_Remarks__c> remarks = [
    SELECT Id, FEC_Case_Remarks__c, FEC_Remark_Type__c, FEC_Stage_Name__c, FEC_User__c, FEC_Assignment__c, CreatedDate
    FROM FEC_Case_Remarks__c WHERE FEC_Case__c = :c.Id ORDER BY CreatedDate ASC
];
System.debug('=== CASE REMARKS (' + remarks.size() + ') ===');
for (FEC_Case_Remarks__c r : remarks) {
    System.debug('  Type=[' + r.FEC_Remark_Type__c + '] Content=[' + r.FEC_Case_Remarks__c + '] Stage=[' + r.FEC_Stage_Name__c + '] AssignmentId=' + r.FEC_Assignment__c + ' Date=' + r.CreatedDate);
}

// Check Routing Action History
List<FEC_Routing_Action_History__c> histories = [
    SELECT FEC_Routing_Action__c, FEC_Original_User_Queue__c, FEC_Updated_User_Queue__c, FEC_Stage_Name__c, FEC_User__c, CreatedDate
    FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c.Id ORDER BY CreatedDate ASC
];
System.debug('=== ROUTING HISTORY (' + histories.size() + ') ===');
for (FEC_Routing_Action_History__c h : histories) {
    System.debug('  Action=' + h.FEC_Routing_Action__c + ' Original=[' + h.FEC_Original_User_Queue__c + '] Updated=[' + h.FEC_Updated_User_Queue__c + '] Stage=[' + h.FEC_Stage_Name__c + '] Date=' + h.CreatedDate);
}

// Phân tích duplicate
System.debug('=== ANALYSIS ===');
Map<String, Integer> contentCount = new Map<String, Integer>();
for (FEC_Case_Remarks__c r : remarks) {
    if (r.FEC_Remark_Type__c == null || r.FEC_Remark_Type__c != 'Assignment') {
        String key = r.FEC_Case_Remarks__c + '|' + r.FEC_Stage_Name__c;
        contentCount.put(key, (contentCount.get(key) ?? 0) + 1);
    }
}
for (String key : contentCount.keySet()) {
    if (contentCount.get(key) > 1) {
        System.debug('DUPLICATE Case Remark: [' + key + '] count=' + contentCount.get(key));
    }
}
