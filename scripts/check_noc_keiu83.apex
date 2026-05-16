// tungnm37: check NOC a06Az00000KeIu83EIA
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, Name, FEC_Business_Process__r.Name, FEC_Business_Process__r.FEC_Code__c,
           FEC_Category__r.Name, FEC_Sub_Category__r.Name, FEC_Sub_Code__r.Name,
           FEC_Customer_Type__c, FEC_Product_Type__r.Name
    FROM FEC_Nature_of_Case__c
    WHERE Id = 'a06Az00000KeIu83EIA'
    LIMIT 1
];
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug('NOC: ' + n.Name
        + ' | BP: ' + n.FEC_Business_Process__r?.Name
        + ' | BP_Code: ' + n.FEC_Business_Process__r?.FEC_Code__c
        + ' | Product: ' + n.FEC_Product_Type__r?.Name
        + ' | Cat: ' + n.FEC_Category__r?.Name
        + ' | SubCat: ' + n.FEC_Sub_Category__r?.Name
        + ' | SubCode: ' + n.FEC_Sub_Code__r?.Name
        + ' | CustomerType: ' + n.FEC_Customer_Type__c);
}
