// Check Case có field Business Process không
List<Case> cases = [SELECT Id, FEC_Business_Process__c FROM Case LIMIT 1];
System.debug('Case has FEC_Business_Process__c: ' + (cases.isEmpty() ? 'no data' : cases[0].FEC_Business_Process__c));

// Check qua NOC
List<Case> cases2 = [
    SELECT Id, FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c
    FROM Case 
    WHERE FEC_Actual_Nature_of_Case__c != null
    LIMIT 1
];
System.debug('Via NOC: ' + (cases2.isEmpty() ? 'no data' : cases2[0].FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c));
