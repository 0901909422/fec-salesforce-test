// Tìm NOC COF có Stage
List<FEC_Nature_of_Case__c> cofNocs = [
    SELECT Id, Name, FEC_Business_Process__r.FEC_Code__c, FEC_User_Group__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Business_Process__r.FEC_Code__c LIKE 'COF%'
      AND FEC_Active__c = TRUE
    LIMIT 20
];
for (FEC_Nature_of_Case__c n : cofNocs) {
    List<FEC_Case_Stage__c> stages = [
        SELECT Id, Name FROM FEC_Case_Stage__c WHERE FEC_Nature_of_Cases__c = :n.Id LIMIT 1
    ];
    if (!stages.isEmpty()) {
        System.debug('NOC=' + n.Name + ' Id=' + n.Id + ' UserGroup=' + n.FEC_User_Group__c + ' HasStages=true Stage1=' + stages[0].Name);
    }
}

// Check case COF đang ở Stage 2 (nếu có)
List<Case> cofStage2 = [
    SELECT Id, CaseNumber, FEC_Current_Case_Stage__r.Name, FEC_Stage_Name__c,
           FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c
    FROM Case
    WHERE FEC_Stage_Name__c LIKE '%Stage 2%'
      AND FEC_Actual_Nature_of_Case__c != null
    ORDER BY LastModifiedDate DESC LIMIT 5
];
System.debug('COF/GSR Stage 2 cases = ' + cofStage2.size());
for (Case c : cofStage2) {
    String bp = c.FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c;
    if (bp != null && (bp.startsWith('COF') || bp.startsWith('GSR'))) {
        System.debug('  Case=' + c.CaseNumber + ' Stage=' + c.FEC_Stage_Name__c);
    }
}
