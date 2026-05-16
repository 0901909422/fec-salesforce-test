// Check case mới nhất submit - xem timeline remark
List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Is_Submited__c, FEC_Actual_Nature_of_Case__c
    FROM Case WHERE FEC_Is_Submited__c = true
    ORDER BY LastModifiedDate DESC LIMIT 3
];
for (Case c : cases) {
    System.debug('Case=' + c.CaseNumber + ' Id=' + c.Id);
    List<FEC_Case_Remarks__c> remarks = [
        SELECT Id, Remark_Type__c, FEC_User__c, FEC_Assignment__c, FEC_Case_Remarks__c, CreatedDate
        FROM FEC_Case_Remarks__c WHERE FEC_Case__c = :c.Id ORDER BY CreatedDate ASC
    ];
    System.debug('  Remarks count=' + remarks.size());
    for (FEC_Case_Remarks__c r : remarks) {
        System.debug('  Remark Type=' + r.Remark_Type__c + ' User=' + r.FEC_User__c + ' Assignment=' + r.FEC_Assignment__c + ' Created=' + r.CreatedDate);
    }
}
