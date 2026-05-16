// tungnm37: tìm Case có NOC thuộc COF/GSR để test
List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Actual_Nature_of_Case__c,
           FEC_Customer_Type__c, Status,
           FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c
    FROM Case
    WHERE FEC_Business_Process__r.FEC_Code__c LIKE 'COF%'
       OR FEC_Business_Process__r.FEC_Code__c LIKE 'GSR%'
    ORDER BY LastModifiedDate DESC
    LIMIT 5
];
System.debug('=== Cases with COF/GSR BP ===');
for (Case c : cases) {
    System.debug('Case: ' + c.CaseNumber + ' | Status: ' + c.Status
        + ' | BP_Code: ' + c.FEC_Business_Process__r?.FEC_Code__c
        + ' | CustomerType: ' + c.FEC_Customer_Type__c
        + ' | NOC: ' + c.FEC_Actual_Nature_of_Case__c);
}

// Check NOC-2067 thuộc BP nào
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, Name, FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c
    FROM FEC_Nature_of_Case__c
    WHERE Id = 'a06Az00000LE7bqIAD'
    LIMIT 1
];
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug('NOC: ' + n.Name + ' | BP_Code: ' + n.FEC_Business_Process__r?.FEC_Code__c);
}
