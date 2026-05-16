// Debug case đang ở Stage 2 COF
// Tìm case COF đã submit Stage 1 (isSubmited=true) và có Stage 2
List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Is_Submited__c, FEC_Current_Case_Stage__c,
           FEC_Current_Case_Stage__r.Name, FEC_Stage_Name__c,
           FEC_Actual_Nature_of_Case__c
    FROM Case
    WHERE FEC_Is_Submited__c = true
      AND FEC_Actual_Nature_of_Case__c != null
    ORDER BY LastModifiedDate DESC LIMIT 5
];
for (Case c : cases) {
    System.debug('Case=' + c.CaseNumber + ' Stage=' + c.FEC_Current_Case_Stage__r?.Name + ' StageName=' + c.FEC_Stage_Name__c);
}

// Check FEC_Log__c errors gần đây
List<FEC_Log__c> logs = [
    SELECT FEC_Function_Name__c, FEC_Error_Message__c, CreatedDate
    FROM FEC_Log__c ORDER BY CreatedDate DESC LIMIT 5
];
for (FEC_Log__c l : logs) {
    System.debug('Log fn=' + l.FEC_Function_Name__c + ' err=' + l.FEC_Error_Message__c);
}
