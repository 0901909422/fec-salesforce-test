// Check case mới nhất submit có FEC_Business_Process
List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c,
           FEC_Actual_Nature_of_Case__c
    FROM Case WHERE FEC_Is_Submited__c = true ORDER BY LastModifiedDate DESC LIMIT 3
];
for (Case c : cases) {
    System.debug('Case=' + c.CaseNumber + ' BP=' + c.FEC_Business_Process__c + ' BPCode=' + c.FEC_Business_Process__r?.FEC_Code__c + ' ActualNOC=' + c.FEC_Actual_Nature_of_Case__c);
}

// Check remarks của case mới nhất
if (!cases.isEmpty()) {
    List<FEC_Case_Remarks__c> remarks = [
        SELECT Id, Remark_Type__c, FEC_User__c, FEC_Case_Remarks__c
        FROM FEC_Case_Remarks__c WHERE FEC_Case__c = :cases[0].Id ORDER BY CreatedDate DESC
    ];
    System.debug('Remarks count=' + remarks.size());
    for (FEC_Case_Remarks__c r : remarks) {
        System.debug('  Type=' + r.Remark_Type__c + ' User=' + r.FEC_User__c + ' Content=' + r.FEC_Case_Remarks__c);
    }
}
