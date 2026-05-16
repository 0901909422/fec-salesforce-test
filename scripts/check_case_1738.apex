// tungnm37: check Case S-1738
List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Actual_Nature_of_Case__c,
           FEC_Customer_Type__c, Status, FEC_Is_Submited__c,
           FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c,
           FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c,
           FEC_Product_Type__c
    FROM Case
    WHERE CaseNumber LIKE '%1738%'
    LIMIT 1
];
for (Case c : cases) {
    System.debug('Case: ' + c.CaseNumber
        + ' | Status: ' + c.Status
        + ' | IsSubmited: ' + c.FEC_Is_Submited__c
        + ' | FEC_Actual_NOC: ' + c.FEC_Actual_Nature_of_Case__c
        + ' | BP_Code: ' + c.FEC_Business_Process__r?.FEC_Code__c
        + ' | CustomerType: ' + c.FEC_Customer_Type__c
        + ' | ProductType: ' + c.FEC_Product_Type__c
        + ' | Category: ' + c.FEC_Category__c
        + ' | SubCode: ' + c.FEC_SubCode__c);
}

// Check NOC match với Card/Inquiry/KC01
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, Name, FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c,
           FEC_Business_Process__r.Name
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Business_Process__r.FEC_Code__c LIKE 'GSR%'
    LIMIT 5
];
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug('NOC: ' + n.Name + ' | BP: ' + n.FEC_Business_Process__r?.Name + ' | Code: ' + n.FEC_Business_Process__r?.FEC_Code__c);
}
