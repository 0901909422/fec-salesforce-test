// tungnm37: simulate getByCase để check natureOfCase trả về
// Lấy Case S-1738
List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Product_Type__c, FEC_Category__c,
           FEC_SubCategory__c, FEC_SubCode__c, FEC_Customer_Type__c,
           FEC_Actual_Nature_of_Case__c
    FROM Case
    WHERE CaseNumber LIKE '%1738%'
    LIMIT 1
];
if (cases.isEmpty()) {
    System.debug('Case not found');
    return;
}
Case c = cases[0];
System.debug('Case: ' + c.CaseNumber
    + ' | ProductType: ' + c.FEC_Product_Type__c
    + ' | Category: ' + c.FEC_Category__c
    + ' | SubCategory: ' + c.FEC_SubCategory__c
    + ' | SubCode: ' + c.FEC_SubCode__c
    + ' | CustomerType: ' + c.FEC_Customer_Type__c
    + ' | ActualNOC: ' + c.FEC_Actual_Nature_of_Case__c);

// Query NOC match
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, Name, FEC_Business_Process__r.FEC_Code__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
      AND FEC_Category__c = :c.FEC_Category__c
      AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
      AND FEC_Sub_Code__c = :c.FEC_SubCode__c
      AND (FEC_Customer_Type__c = :c.FEC_Customer_Type__c OR FEC_Customer_Type__c = 'All')
      AND FEC_Active__c = true
    LIMIT 5
];
System.debug('=== Matching NOCs ===');
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug('NOC: ' + n.Id + ' | ' + n.Name + ' | BP: ' + n.FEC_Business_Process__r?.FEC_Code__c);
}
