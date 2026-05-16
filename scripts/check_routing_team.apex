// Check getRoutingAssignments cho case S-2160
Case c = [SELECT Id, FEC_SubCode__c, FEC_SubCategory__c, FEC_Category__c, FEC_Product_Type__c FROM Case WHERE FEC_ID_Search__c = 'S-2160' LIMIT 1];

// Simulate getRoutingAssignments
List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
      AND FEC_Category__c = :c.FEC_Category__c
      AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
      AND FEC_Sub_Code__c = :c.FEC_SubCode__c
      AND FEC_Active__c = true LIMIT 5
];
System.debug('NOCs: ' + nocs.size());

if (!nocs.isEmpty()) {
    Set<Id> nocIds = new Map<Id, FEC_Nature_of_Case__c>(nocs).keySet();
    List<FEC_Routing_Assignment__c> ras = [
        SELECT FEC_Team__c, FEC_Queue__c, FEC_Active__c
        FROM FEC_Routing_Assignment__c
        WHERE FEC_Nature_of_Cases__c IN :nocIds
    ];
    System.debug('Routing Assignments (all): ' + ras.size());
    for (FEC_Routing_Assignment__c ra : ras) {
        System.debug('  Team: ' + ra.FEC_Team__c + ' | Queue: ' + ra.FEC_Queue__c + ' | Active: ' + ra.FEC_Active__c);
    }
}

// Check FEC_SubCode__c object type
Id subCodeId = c.FEC_SubCode__c;
System.debug('SubCode object type: ' + subCodeId?.getSObjectType()?.getDescribe()?.getName());
