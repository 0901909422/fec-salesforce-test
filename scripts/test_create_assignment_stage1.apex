// Test tạo Assignment trên Case Stage 1 và check Stage Name được lưu không
// Case S-2539 đang ở Stage 1
String caseId = ''; // sẽ query bên dưới

List<Case> stage1Cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c,
           FEC_Current_Case_Stage__c,
           FEC_Current_Case_Stage__r.Name,
           FEC_Current_Case_Stage__r.FEC_Default_Stage__c
    FROM Case
    WHERE FEC_ID_Search__c = 'S-2539'
    LIMIT 1
];

if (stage1Cases.isEmpty()) {
    System.debug('ERROR: Case S-2539 not found');
    return;
}

Case c = stage1Cases[0];
caseId = c.Id;

System.debug('=== CASE INFO ===');
System.debug('Case: ' + c.FEC_ID_Search__c);
System.debug('FEC_Stage_Name__c: ' + c.FEC_Stage_Name__c);
System.debug('Current Stage: ' + c.FEC_Current_Case_Stage__r?.Name);
System.debug('Is Default Stage (Stage 1): ' + c.FEC_Current_Case_Stage__r?.FEC_Default_Stage__c);

// Simulate createAssignment logic
Boolean isStage1 = c.FEC_Current_Case_Stage__r != null
    && c.FEC_Current_Case_Stage__r.FEC_Default_Stage__c == true;

System.debug('isStage1 = ' + isStage1);

if (isStage1) {
    String stageName = String.isNotBlank(c.FEC_Stage_Name__c)
        ? c.FEC_Stage_Name__c
        : (c.FEC_Current_Case_Stage__r?.Name != null ? c.FEC_Current_Case_Stage__r.Name : null);
    System.debug('Stage Name to save: ' + stageName);

    // Tạo Assignment test
    FEC_Assignment__c assignment = new FEC_Assignment__c(
        FEC_Case__c = caseId,
        FEC_Assignment_Type__c = 'General',
        FEC_Assignment_Status__c = 'Open',
        FEC_Assignment_Name__c = 'Soạn thảo văn bản'
    );
    insert assignment;
    System.debug('Created Assignment: ' + assignment.Id + ' | Name: ' + assignment.Name);

    // Tạo Remark với Stage Name
    if (String.isNotBlank(stageName)) {
        FEC_Case_Remarks__c remark = new FEC_Case_Remarks__c(
            FEC_Case__c = caseId,
            FEC_Assignment__c = assignment.Id,
            FEC_Stage_Name__c = stageName,
            FEC_Remark_Type__c = 'Assignment'
        );
        insert remark;
        System.debug('Created Remark with StageName: ' + stageName);
    }

    // Verify
    List<FEC_Case_Remarks__c> verify = [
        SELECT Id, FEC_Stage_Name__c, FEC_Remark_Type__c
        FROM FEC_Case_Remarks__c
        WHERE FEC_Assignment__c = :assignment.Id
    ];
    System.debug('=== VERIFY ===');
    System.debug('Remarks count: ' + verify.size());
    for (FEC_Case_Remarks__c r : verify) {
        System.debug('StageName=' + r.FEC_Stage_Name__c + ' | Type=' + r.FEC_Remark_Type__c);
    }
} else {
    System.debug('Case is NOT at Stage 1 - Stage Name will not be saved');
}
