List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Is_Submited__c,
           FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c
    FROM Case
    WHERE FEC_Actual_Nature_of_Case__c != null
    ORDER BY LastModifiedDate DESC
    LIMIT 30
];
for (Case c : cases) {
    String code = c.FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c;
    if (code != null && (code.startsWith('COF') || code.startsWith('GSR'))) {
        System.debug('CASE: ' + c.CaseNumber + ' | Id=' + c.Id + ' | Submitted=' + c.FEC_Is_Submited__c + ' | code=' + code);
    }
}

// Đếm remarks của case S-2293 (case đang test)
List<FEC_Case_Remarks__c> remarks = [
    SELECT Id, FEC_Case_Remarks__c, FEC_Remark_Type__c, FEC_Stage_Name__c, CreatedDate
    FROM FEC_Case_Remarks__c
    WHERE FEC_Case__r.CaseNumber = 'S-2293'
    ORDER BY CreatedDate ASC
];
System.debug('\n=== REMARKS của S-2293: ' + remarks.size() + ' bản ghi ===');
for (FEC_Case_Remarks__c r : remarks) {
    System.debug('  Type=[' + r.FEC_Remark_Type__c + '] Content="' + r.FEC_Case_Remarks__c + '" Stage=' + r.FEC_Stage_Name__c + ' Time=' + r.CreatedDate);
}
