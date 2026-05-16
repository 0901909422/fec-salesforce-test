// tungnm37: check NOC của Case đang mở - thay CaseNumber cho đúng
List<Case> cases = [
    SELECT Id, CaseNumber,
           FEC_Category__c, FEC_Category__r.Name,
           FEC_SubCategory__c, FEC_SubCategory__r.Name,
           FEC_SubCode__c, FEC_SubCode__r.Name,
           FEC_Product_Type__c, FEC_Product_Type__r.Name,
           FEC_Customer_Type__c,
           FEC_Actual_Nature_of_Case__c,
           FEC_Actual_Nature_of_Case__r.Name,
           FEC_Business_Process__c,
           FEC_Business_Process__r.FEC_Code__c,
           FEC_Business_Process__r.Name
    FROM Case
    WHERE CaseNumber LIKE '%1732%'
    LIMIT 1
];
for (Case c : cases) {
    System.debug('Case: ' + c.CaseNumber);
    System.debug('Category: ' + c.FEC_Category__r?.Name);
    System.debug('SubCategory: ' + c.FEC_SubCategory__r?.Name);
    System.debug('SubCode: ' + c.FEC_SubCode__r?.Name);
    System.debug('ProductType: ' + c.FEC_Product_Type__r?.Name);
    System.debug('CustomerType: ' + c.FEC_Customer_Type__c);
    System.debug('Actual NOC: ' + c.FEC_Actual_Nature_of_Case__c + ' | ' + c.FEC_Actual_Nature_of_Case__r?.Name);
    System.debug('BP: ' + c.FEC_Business_Process__r?.Name + ' | Code: ' + c.FEC_Business_Process__r?.FEC_Code__c);
}
