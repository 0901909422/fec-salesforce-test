// tungnm37: tìm tất cả NOC thuộc IC01.01 không filter active
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, Name, FEC_Customer_Type__c, FEC_Product_Type__r.Name,
           FEC_Category__r.Name, FEC_Sub_Category__r.Name, FEC_Sub_Code__r.Name,
           FEC_Business_Process__r.FEC_Code__c, FEC_Active__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Business_Process__r.FEC_Code__c = 'GSR - General Flow'
      AND FEC_Sub_Code__r.Name LIKE '%IC01.01%'
    LIMIT 20
];
System.debug('Total: ' + nocs.size());
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug('ID: ' + n.Id + ' | CustomerType: ' + n.FEC_Customer_Type__c
        + ' | Active: ' + n.FEC_Active__c + ' | Product: ' + n.FEC_Product_Type__r?.Name);
}

// Cũng check NOC-2067 xem có CustomerType gì
List<FEC_Nature_of_Case__c> noc2067 = [
    SELECT Id, Name, FEC_Customer_Type__c, FEC_Product_Type__r.Name
    FROM FEC_Nature_of_Case__c
    WHERE Name = 'NOC-2067'
    LIMIT 1
];
for (FEC_Nature_of_Case__c n : noc2067) {
    System.debug('NOC-2067: ID=' + n.Id + ' | CustomerType: ' + n.FEC_Customer_Type__c + ' | Product: ' + n.FEC_Product_Type__r?.Name);
}
