// Check Hold Case Config cho bộ CC05.02
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id FROM FEC_Nature_of_Case__c
    WHERE FEC_Sub_Code__r.FEC_Code__c = 'CC05.02'
    LIMIT 3
];
System.debug('NOCs CC05.02: ' + nocs.size());
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug('  NOC: ' + n.Id);
    List<FEC_Hold_Case_Config__c> cfgs = [
        SELECT Id, Name, Hold_Case_Type__c, FEC_Active__c
        FROM FEC_Hold_Case_Config__c
        WHERE FEC_Nature_of_Cases__c = :n.Id
    ];
    System.debug('  Configs: ' + cfgs.size());
    for (FEC_Hold_Case_Config__c c : cfgs) {
        System.debug('    ' + c.Name + ' | Type=' + c.Hold_Case_Type__c + ' | Active=' + c.FEC_Active__c);
    }
}
