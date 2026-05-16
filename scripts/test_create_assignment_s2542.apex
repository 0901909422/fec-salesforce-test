// Test createAssignment logic mới trên S-2542 (Stage 2)
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c,
           FEC_Current_Case_Stage__r.Name,
           FEC_Current_Case_Stage__r.FEC_Default_Stage__c
    FROM Case
    WHERE FEC_ID_Search__c = 'S-2542'
    LIMIT 1
];
if (cases.isEmpty()) { System.debug('Not found'); return; }

Case c = cases[0];
System.debug('Case: ' + c.FEC_ID_Search__c + ' | Stage: ' + c.FEC_Current_Case_Stage__r?.Name);

// Gọi trực tiếp FEC_NewAssignmentController.createAssignment
Id assignmentId = FEC_NewAssignmentController.createAssignment(
    c.Id, 'General', 'Open', 'Soạn thảo văn bản'
);
System.debug('Created Assignment Id: ' + assignmentId);

// Verify remark được tạo
List<FEC_Case_Remarks__c> remarks = [
    SELECT Id, FEC_Stage_Name__c, FEC_Remark_Type__c
    FROM FEC_Case_Remarks__c
    WHERE FEC_Assignment__c = :assignmentId
];
System.debug('Remarks count: ' + remarks.size());
for (FEC_Case_Remarks__c r : remarks) {
    System.debug('StageName=' + r.FEC_Stage_Name__c + ' | Type=' + r.FEC_Remark_Type__c);
}

// Verify qua AssignmentListHandler simulate
List<FEC_Assignment__c> allAssignments = [
    SELECT Id, Name, FEC_Assignment_Type__c, FEC_Assignment_Name__c
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :c.Id
    ORDER BY CreatedDate DESC
    LIMIT 5
];
Set<Id> aIds = new Map<Id, FEC_Assignment__c>(allAssignments).keySet();
List<FEC_Case_Remarks__c> allRemarks = [
    SELECT Id, FEC_Assignment__c, FEC_Stage_Name__c
    FROM FEC_Case_Remarks__c
    WHERE FEC_Assignment__c IN :aIds
    ORDER BY CreatedDate DESC
];
Map<Id, String> stageNameMap = new Map<Id, String>();
for (FEC_Case_Remarks__c r : allRemarks) {
    if (!stageNameMap.containsKey(r.FEC_Assignment__c)) {
        stageNameMap.put(r.FEC_Assignment__c, r.FEC_Stage_Name__c);
    }
}
System.debug('=== DISPLAY RESULT ===');
for (FEC_Assignment__c a : allAssignments) {
    System.debug(a.Name + ' → StageName: ' + (stageNameMap.containsKey(a.Id) ? stageNameMap.get(a.Id) : '(blank)'));
}
