// Check NOC hierarchy - tìm cha của NOC-1003
FEC_Nature_of_Case__c noc1003 = [
    SELECT Id, Name, FEC_Business_Process__c, FEC_Category__c,
           FEC_Sub_Category__c, FEC_Sub_Code__c, FEC_Channel__c
    FROM FEC_Nature_of_Case__c WHERE Name = 'NOC-1003' LIMIT 1
];
System.debug('NOC-1003: BP=' + noc1003.FEC_Business_Process__c
    + ' Cat=' + noc1003.FEC_Category__c
    + ' SubCat=' + noc1003.FEC_Sub_Category__c
    + ' SubCode=' + noc1003.FEC_Sub_Code__c);

// Tìm NOC cùng BP+Cat+SubCat nhưng không có SubCode (cha level 3)
List<FEC_Nature_of_Case__c> level3Parents = [
    SELECT Id, Name, FEC_Channel__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Business_Process__c = :noc1003.FEC_Business_Process__c
      AND FEC_Category__c = :noc1003.FEC_Category__c
      AND FEC_Sub_Category__c = :noc1003.FEC_Sub_Category__c
      AND FEC_Sub_Code__c = null
];
System.debug('Level 3 parents (cùng BP+Cat+SubCat, ko SubCode): ' + level3Parents.size());
for (FEC_Nature_of_Case__c n : level3Parents) {
    System.debug('  ' + n.Name + ' | Channel: ' + n.FEC_Channel__c);
}

// Tìm tất cả NOC cùng BP+Cat+SubCat (siblings + cha)
List<FEC_Nature_of_Case__c> siblings = [
    SELECT Id, Name, FEC_Sub_Code__c, FEC_Channel__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Business_Process__c = :noc1003.FEC_Business_Process__c
      AND FEC_Category__c = :noc1003.FEC_Category__c
      AND FEC_Sub_Category__c = :noc1003.FEC_Sub_Category__c
      AND Id != :noc1003.Id
    ORDER BY Name
];
System.debug('Siblings (cùng BP+Cat+SubCat): ' + siblings.size());
for (FEC_Nature_of_Case__c n : siblings) {
    System.debug('  ' + n.Name + ' | SubCode: ' + n.FEC_Sub_Code__c + ' | Channel: ' + n.FEC_Channel__c);
}
