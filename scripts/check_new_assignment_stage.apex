// Script check Stage Name cho Assignment mới tạo
// Thay CASE_ID bằng Id của Case S-2542
String caseId = '500Az00000Pv8IbIAJ';

// 1. Check Case hiện tại: Stage Name, Current Case Stage, Default Stage
List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Stage_Name__c,
           FEC_Current_Case_Stage__c,
           FEC_Current_Case_Stage__r.Name,
           FEC_Current_Case_Stage__r.FEC_Default_Stage__c
    FROM Case
    WHERE Id = :caseId
    LIMIT 1
];
if (!cases.isEmpty()) {
    Case c = cases[0];
    System.debug('=== CASE INFO ===');
    System.debug('Case Number: ' + c.CaseNumber);
    System.debug('FEC_Stage_Name__c: ' + c.FEC_Stage_Name__c);
    System.debug('Current Stage Id: ' + c.FEC_Current_Case_Stage__c);
    System.debug('Current Stage Name: ' + c.FEC_Current_Case_Stage__r?.Name);
    System.debug('Is Default Stage (Stage 1): ' + c.FEC_Current_Case_Stage__r?.FEC_Default_Stage__c);
}

// 2. Check Assignments mới nhất của Case
List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Assignment_Type__c, FEC_Assignment_Name__c, FEC_Assignment_Status__c, CreatedDate
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :caseId
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('=== ASSIGNMENTS ===');
for (FEC_Assignment__c a : assignments) {
    System.debug('Assignment: ' + a.Name + ' | Type: ' + a.FEC_Assignment_Type__c + ' | Name: ' + a.FEC_Assignment_Name__c + ' | Created: ' + a.CreatedDate);
}

// 3. Check FEC_Case_Remarks__c có Stage Name không
if (!assignments.isEmpty()) {
    Set<Id> aIds = new Map<Id, FEC_Assignment__c>(assignments).keySet();
    List<FEC_Case_Remarks__c> remarks = [
        SELECT Id, FEC_Assignment__c, FEC_Stage_Name__c, FEC_Remark_Type__c, CreatedDate
        FROM FEC_Case_Remarks__c
        WHERE FEC_Assignment__c IN :aIds
        ORDER BY CreatedDate DESC
    ];
    System.debug('=== CASE REMARKS (linked to assignments) ===');
    if (remarks.isEmpty()) {
        System.debug('NO REMARKS FOUND - Stage Name will be blank');
    }
    for (FEC_Case_Remarks__c r : remarks) {
        System.debug('Remark: AssignmentId=' + r.FEC_Assignment__c + ' | StageName=' + r.FEC_Stage_Name__c + ' | Type=' + r.FEC_Remark_Type__c);
    }
}
