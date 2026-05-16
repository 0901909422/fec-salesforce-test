// Check chi tiết S-2542 để hiểu tại sao Stage Name blank
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c,
           FEC_Current_Case_Stage__c,
           FEC_Current_Case_Stage__r.Name,
           FEC_Current_Case_Stage__r.FEC_Default_Stage__c
    FROM Case
    WHERE FEC_ID_Search__c = 'S-2542'
    LIMIT 1
];
if (cases.isEmpty()) { System.debug('Not found'); return; }
Case c = cases[0];
System.debug('Case: ' + c.FEC_ID_Search__c);
System.debug('FEC_Stage_Name__c: ' + c.FEC_Stage_Name__c);
System.debug('Current Stage: ' + c.FEC_Current_Case_Stage__r?.Name);
System.debug('Is Stage 1 (Default): ' + c.FEC_Current_Case_Stage__r?.FEC_Default_Stage__c);

// Check assignments A-000268, A-000267 - khi nào được tạo so với deploy
List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Assignment_Type__c, FEC_Assignment_Name__c, CreatedDate
    FROM FEC_Assignment__c
    WHERE FEC_Case__c = :c.Id
    ORDER BY CreatedDate DESC
];
System.debug('=== ASSIGNMENTS ===');
for (FEC_Assignment__c a : assignments) {
    System.debug(a.Name + ' | Created: ' + a.CreatedDate + ' | Type: ' + a.FEC_Assignment_Type__c);
}

// Check remarks
Set<Id> aIds = new Map<Id, FEC_Assignment__c>(assignments).keySet();
List<FEC_Case_Remarks__c> remarks = [
    SELECT Id, FEC_Assignment__c, FEC_Stage_Name__c, FEC_Remark_Type__c
    FROM FEC_Case_Remarks__c
    WHERE FEC_Assignment__c IN :aIds
];
System.debug('Remarks count: ' + remarks.size());
for (FEC_Case_Remarks__c r : remarks) {
    System.debug('  StageName=' + r.FEC_Stage_Name__c + ' | AssignId=' + r.FEC_Assignment__c);
}
