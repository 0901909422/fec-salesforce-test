// Check FEC_Stage_Name__c của Case đang ở Stage 1
List<Case> cases = [
    SELECT Id, FEC_Stage_Name__c, FEC_Current_Case_Stage__c, FEC_Is_Submited__c
    FROM Case
    WHERE FEC_Stage_Name__c LIKE '%Stage%'
    LIMIT 5
];
for (Case c : cases) {
    System.debug('CaseId=' + c.Id + ' StageName=[' + c.FEC_Stage_Name__c + '] IsSubmited=' + c.FEC_Is_Submited__c);
}
// Check pattern match
String testStageName = 'COF - General Flow - CC01.01-Nhân viên yêu cầu tiền phí - Stage 1';
Boolean matches = Pattern.matches('(?i).*stage\\s*1.*', testStageName);
System.debug('Pattern matches: ' + matches);
