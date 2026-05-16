List<Case> cases = [SELECT Id, FEC_ID_Search__c FROM Case WHERE FEC_ID_Search__c = 'S-2362' LIMIT 1];
if (cases.isEmpty()) { System.debug('Not found'); return; }
Id caseId = cases[0].Id;

List<FEC_Case_Remarks__c> remarks = [
    SELECT Id, FEC_Case_Remarks__c, FEC_Remark_Type__c, FEC_Stage_Name__c, FEC_User__c, CreatedDate
    FROM FEC_Case_Remarks__c WHERE FEC_Case__c = :caseId ORDER BY CreatedDate ASC
];
System.debug('Total remarks: ' + remarks.size());
for (FEC_Case_Remarks__c r : remarks) {
    System.debug('Type=[' + r.FEC_Remark_Type__c + '] Content=[' + r.FEC_Case_Remarks__c + '] Stage=[' + r.FEC_Stage_Name__c + '] Date=' + r.CreatedDate);
}
