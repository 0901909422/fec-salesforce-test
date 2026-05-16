// Check hierarchy của NOC-1003 và NOC-1004
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, Name, FEC_Channel__c,
           FEC_Business_Process__c, FEC_Business_Process__r.Name,
           FEC_Category__c, FEC_Category__r.Name,
           FEC_Sub_Category__c, FEC_Sub_Category__r.Name,
           FEC_Sub_Code__c, FEC_Sub_Code__r.Name
    FROM FEC_Nature_of_Case__c
    WHERE Name IN ('NOC-1003', 'NOC-1004')
];
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug(n.Name + ' | Channel: ' + n.FEC_Channel__c
        + ' | BP: ' + n.FEC_Business_Process__r?.Name
        + ' | Cat: ' + n.FEC_Category__r?.Name
        + ' | SubCat: ' + n.FEC_Sub_Category__r?.Name
        + ' | SubCode: ' + n.FEC_Sub_Code__r?.Name);
}
