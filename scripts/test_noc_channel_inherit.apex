// Test kế thừa FEC_Channel__c từ NOC cha xuống con
// Tìm NOC có BP nhưng không có Category (level 1 - cha)
List<FEC_Nature_of_Case__c> parents = [
    SELECT Id, FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c, FEC_Channel__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Business_Process__c != null AND FEC_Category__c = null
    LIMIT 3
];
System.debug('Parent NOCs (level 1): ' + parents.size());

// Tìm NOC có BP + Category (level 2 - con của level 1)
if (!parents.isEmpty()) {
    Id bpId = parents[0].FEC_Business_Process__c;
    List<FEC_Nature_of_Case__c> children = [
        SELECT Id, FEC_Business_Process__c, FEC_Category__c, FEC_Channel__c
        FROM FEC_Nature_of_Case__c
        WHERE FEC_Business_Process__c = :bpId AND FEC_Category__c != null
        LIMIT 3
    ];
    System.debug('Children NOCs: ' + children.size());
    for (FEC_Nature_of_Case__c c : children) {
        System.debug('  Child: ' + c.Id + ' | Channel: ' + c.FEC_Channel__c);
    }
}

// Tìm Channel để test
List<FEC_Channel__c> channels = [SELECT Id, Name FROM FEC_Channel__c WHERE FEC_Channel_Status__c = true LIMIT 1];
System.debug('Test Channel: ' + (channels.isEmpty() ? 'none' : channels[0].Name));
