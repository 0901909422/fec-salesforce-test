// Tìm Case đang ở Stage 1 (Default Stage) để test
List<Case> stage1Cases = [
    SELECT Id, CaseNumber, FEC_ID_Search__c, FEC_Stage_Name__c,
           FEC_Current_Case_Stage__r.Name,
           FEC_Current_Case_Stage__r.FEC_Default_Stage__c
    FROM Case
    WHERE FEC_Current_Case_Stage__r.FEC_Default_Stage__c = true
    ORDER BY CreatedDate DESC
    LIMIT 5
];

System.debug('=== CASES AT STAGE 1 ===');
if (stage1Cases.isEmpty()) {
    System.debug('No cases at Stage 1 found');
} else {
    for (Case c : stage1Cases) {
        System.debug('Case: ' + c.FEC_ID_Search__c + ' | Stage: ' + c.FEC_Current_Case_Stage__r?.Name + ' | FEC_Stage_Name__c: ' + c.FEC_Stage_Name__c);
    }
}

// Check Assignment A-000268 remark cụ thể
List<FEC_Assignment__c> a268 = [SELECT Id FROM FEC_Assignment__c WHERE Name = 'A-000268' LIMIT 1];
if (!a268.isEmpty()) {
    List<FEC_Case_Remarks__c> r = [
        SELECT Id, FEC_Stage_Name__c, FEC_Remark_Type__c, CreatedDate
        FROM FEC_Case_Remarks__c
        WHERE FEC_Assignment__c = :a268[0].Id
    ];
    System.debug('=== REMARKS FOR A-000268 ===');
    System.debug('Count: ' + r.size());
    for (FEC_Case_Remarks__c rm : r) {
        System.debug('StageName=' + rm.FEC_Stage_Name__c + ' | Type=' + rm.FEC_Remark_Type__c);
    }
}
