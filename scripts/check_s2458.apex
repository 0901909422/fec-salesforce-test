List<Case> cases = [
    SELECT Id, FEC_ID_Search__c,
           FEC_Current_Case_Stage__c,
           FEC_Current_Case_Stage__r.FEC_Code__c,
           FEC_Current_Case_Stage__r.Name,
           FEC_Stage_Name__c,
           FEC_Is_Submited__c
    FROM Case WHERE FEC_ID_Search__c = 'S-2458' LIMIT 1
];
if (cases.isEmpty()) { System.debug('not found'); return; }
Case c = cases[0];
System.debug('Case=' + c.FEC_ID_Search__c
    + ' CurrentStageId=' + c.FEC_Current_Case_Stage__c
    + ' StageCode=[' + c.FEC_Current_Case_Stage__r?.FEC_Code__c + ']'
    + ' StageName=[' + c.FEC_Stage_Name__c + ']'
    + ' IsSubmited=' + c.FEC_Is_Submited__c);
