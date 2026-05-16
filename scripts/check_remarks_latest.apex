// Tìm case COF/GSR mới nhất và đếm remarks
List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Is_Submited__c,
           FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c
    FROM Case
    WHERE FEC_Actual_Nature_of_Case__c != null
      AND LastModifiedDate = LAST_N_DAYS:1
    ORDER BY LastModifiedDate DESC
    LIMIT 20
];

for (Case c : cases) {
    String code = c.FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c;
    if (code == null || (!code.startsWith('COF') && !code.startsWith('GSR'))) continue;

    List<FEC_Case_Remarks__c> remarks = [
        SELECT Id, FEC_Case_Remarks__c, FEC_Remark_Type__c, FEC_Stage_Name__c, CreatedDate
        FROM FEC_Case_Remarks__c
        WHERE FEC_Case__c = :c.Id
        ORDER BY CreatedDate ASC
    ];
    if (remarks.isEmpty()) continue;

    System.debug('=== Case ' + c.CaseNumber + ' | Submitted=' + c.FEC_Is_Submited__c + ' | ' + remarks.size() + ' remarks ===');
    for (FEC_Case_Remarks__c r : remarks) {
        System.debug('  [' + (r.FEC_Remark_Type__c == null ? 'Case' : r.FEC_Remark_Type__c) + '] "' + r.FEC_Case_Remarks__c + '" | ' + r.CreatedDate);
    }
}
