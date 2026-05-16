List<Case> cases = [
    SELECT Id, FEC_ID_Search__c,
           FEC_Actual_Nature_of_Case__c,
           FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c,
           FEC_Actual_Nature_of_Case__r.Name
    FROM Case WHERE FEC_ID_Search__c = 'S-2429' LIMIT 1
];
if (cases.isEmpty()) { System.debug('not found'); return; }
Case c = cases[0];
System.debug('ActualNOC=' + c.FEC_Actual_Nature_of_Case__c);
System.debug('ActualNOCName=' + c.FEC_Actual_Nature_of_Case__r?.Name);
System.debug('BPCodeViaActualNOC=' + c.FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c);
