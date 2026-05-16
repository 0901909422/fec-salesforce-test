// tungnm37: tìm tất cả NOC thuộc Card/Inquiry/IC01.01 để biết có bao nhiêu CustomerType
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, Name, FEC_Customer_Type__c, FEC_Product_Type__r.Name,
           FEC_Category__r.Name, FEC_Sub_Category__r.Name, FEC_Sub_Code__r.Name,
           FEC_Business_Process__r.FEC_Code__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Business_Process__r.FEC_Code__c = 'GSR - General Flow'
      AND FEC_Sub_Code__r.Name LIKE '%IC01.01%'
      AND FEC_Active__c = true
    LIMIT 10
];
System.debug('Total NOCs for IC01.01: ' + nocs.size());
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug('ID: ' + n.Id + ' | Name: ' + n.Name
        + ' | CustomerType: ' + n.FEC_Customer_Type__c
        + ' | Product: ' + n.FEC_Product_Type__r?.Name);
}
