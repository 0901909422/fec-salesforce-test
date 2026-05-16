// Full flow check cho Case S-2539
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c,
           FEC_Current_Case_Stage__r.Name,
           FEC_Current_Case_Stage__r.FEC_Default_Stage__c
    FROM Case
    WHERE FEC_ID_Search__c = 'S-2539'
    LIMIT 1
];
if (cases.isEmpty()) { System.debug('Case not found'); return; }

Case c = cases[0];
String caseId = c.Id;
System.debug('Case: ' + c.FEC_ID_Search__c + ' | Stage: ' + c.FEC_Current_Case_Stage__r?.Name + ' | IsStage1: ' + c.FEC_Current_Case_Stage__r?.FEC_Default_Stage__c);

// 1. Tất cả Assignments của Case
List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Assignment_Type__c, FEC_Assignment_Name__c, FEC_Assignment_Status__c, CreatedDate
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :caseId
    ORDER BY CreatedDate DESC
    LIMIT 10
];
System.debug('=== ASSIGNMENTS (' + assignments.size() + ') ===');
for (FEC_Assignment__c a : assignments) {
    System.debug('  ' + a.Name + ' | Type=' + a.FEC_Assignment_Type__c + ' | AssignName=' + a.FEC_Assignment_Name__c + ' | Status=' + a.FEC_Assignment_Status__c);
}

// 2. Remarks linked to assignments - đây là nguồn Stage Name
if (!assignments.isEmpty()) {
    Set<Id> aIds = new Map<Id, FEC_Assignment__c>(assignments).keySet();
    List<FEC_Case_Remarks__c> remarks = [
        SELECT Id, FEC_Assignment__c, FEC_Stage_Name__c, FEC_Remark_Type__c, CreatedDate
        FROM FEC_Case_Remarks__c
        WHERE FEC_Assignment__c IN :aIds
        ORDER BY CreatedDate DESC
    ];
    System.debug('=== REMARKS linked to assignments (' + remarks.size() + ') ===');
    if (remarks.isEmpty()) {
        System.debug('  NO REMARKS - Stage Name column will be blank');
    }
    for (FEC_Case_Remarks__c r : remarks) {
        System.debug('  AssignmentId=' + r.FEC_Assignment__c + ' | StageName=' + r.FEC_Stage_Name__c + ' | Type=' + r.FEC_Remark_Type__c);
    }

    // 3. Simulate AssignmentListHandler logic: lấy latest remark per assignment
    System.debug('=== SIMULATED DISPLAY (latest remark per assignment) ===');
    Map<Id, FEC_Case_Remarks__c> latestRemarkMap = new Map<Id, FEC_Case_Remarks__c>();
    for (FEC_Case_Remarks__c r : remarks) {
        if (!latestRemarkMap.containsKey(r.FEC_Assignment__c)) {
            latestRemarkMap.put(r.FEC_Assignment__c, r);
        }
    }
    for (FEC_Assignment__c a : assignments) {
        String stageName = latestRemarkMap.containsKey(a.Id)
            ? latestRemarkMap.get(a.Id).FEC_Stage_Name__c
            : '(blank)';
        System.debug('  ' + a.Name + ' → Stage Name displayed: ' + stageName);
    }
}
