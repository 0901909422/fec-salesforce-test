List<Case> cases = [SELECT Id, FEC_ID_Search__c FROM Case ORDER BY CreatedDate DESC LIMIT 3];
for (Case c : cases) {
    System.debug('Case=' + c.FEC_ID_Search__c + ' Id=' + c.Id);
    List<FEC_Case_Remarks__c> remarks = [
        SELECT FEC_Case_Remarks__c, FEC_Remark_Type__c, FEC_Stage_Name__c, CreatedDate
        FROM FEC_Case_Remarks__c WHERE FEC_Case__c = :c.Id ORDER BY CreatedDate ASC
    ];
    for (FEC_Case_Remarks__c r : remarks) {
        System.debug('  Type=[' + r.FEC_Remark_Type__c + '] Content=[' + r.FEC_Case_Remarks__c + '] Stage=[' + r.FEC_Stage_Name__c + '] Date=' + r.CreatedDate);
    }
}
