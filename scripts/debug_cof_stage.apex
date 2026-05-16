// Check case COF mới nhất
List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Is_Submited__c, FEC_Current_Case_Stage__c,
           FEC_Current_Case_Stage__r.Name, FEC_Stage_Name__c,
           FEC_Actual_Nature_of_Case__c, FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c,
           OwnerId, Owner.Name
    FROM Case
    WHERE FEC_Actual_Nature_of_Case__c != null
    ORDER BY LastModifiedDate DESC LIMIT 10
];
for (Case c : cases) {
    String bp = c.FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c;
    if (bp != null && (bp.startsWith('COF') || bp.startsWith('GSR'))) {
        System.debug('COF/GSR Case=' + c.CaseNumber + ' Submitted=' + c.FEC_Is_Submited__c + ' Stage=' + c.FEC_Current_Case_Stage__r?.Name + ' StageName=' + c.FEC_Stage_Name__c + ' Owner=' + c.Owner?.Name);
    }
}
