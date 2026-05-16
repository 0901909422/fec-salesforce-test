// Tìm NOC không có SubCode (level 3 - cha) và con của nó
List<FEC_Nature_of_Case__c> level3 = [
    SELECT Id, Name, FEC_Business_Process__c, FEC_Business_Process__r.Name,
           FEC_Category__c, FEC_Category__r.Name,
           FEC_Sub_Category__c, FEC_Sub_Category__r.Name,
           FEC_Sub_Code__c, FEC_Channel__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Sub_Code__c = null AND FEC_Sub_Category__c != null
    LIMIT 3
];
System.debug('Level 3 NOCs (no SubCode): ' + level3.size());
for (FEC_Nature_of_Case__c n : level3) {
    System.debug('  ' + n.Name + ' | BP: ' + n.FEC_Business_Process__r?.Name
        + ' | Cat: ' + n.FEC_Category__r?.Name
        + ' | SubCat: ' + n.FEC_Sub_Category__r?.Name
        + ' | Channel: ' + n.FEC_Channel__c);

    // Tìm con (cùng BP+Cat+SubCat nhưng có SubCode)
    List<FEC_Nature_of_Case__c> children = [
        SELECT Id, Name, FEC_Sub_Code__r.Name, FEC_Channel__c
        FROM FEC_Nature_of_Case__c
        WHERE FEC_Business_Process__c = :n.FEC_Business_Process__c
          AND FEC_Category__c = :n.FEC_Category__c
          AND FEC_Sub_Category__c = :n.FEC_Sub_Category__c
          AND FEC_Sub_Code__c != null
        LIMIT 3
    ];
    System.debug('  Children: ' + children.size());
    for (FEC_Nature_of_Case__c c : children) {
        System.debug('    ' + c.Name + ' | SubCode: ' + c.FEC_Sub_Code__r?.Name + ' | Channel: ' + c.FEC_Channel__c);
    }
}
