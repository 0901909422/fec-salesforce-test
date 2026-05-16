Case c = [
    SELECT Id, CaseNumber, FEC_Is_Submited__c, FEC_Current_Case_Stage__r.Name,
           FEC_Actual_Nature_of_Case__c, FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c,
           OwnerId, Owner.Name, FEC_Stage_Name__c
    FROM Case WHERE Id = '500Az00000OJ1XFIA1' LIMIT 1
];
System.debug('Case=' + c.CaseNumber + ' Submitted=' + c.FEC_Is_Submited__c);
System.debug('Stage=' + c.FEC_Current_Case_Stage__r?.Name);
System.debug('ActualNOC=' + c.FEC_Actual_Nature_of_Case__c);
System.debug('BP=' + c.FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c);
System.debug('Owner=' + c.Owner?.Name);
