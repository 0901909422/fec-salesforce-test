// Add Routing Assignment cho NOC của case S-2160 (team CC)
Case c = [SELECT Id, FEC_SubCode__c, FEC_SubCategory__c, FEC_Category__c, FEC_Product_Type__c FROM Case WHERE FEC_ID_Search__c = 'S-2160' LIMIT 1];

List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, Name FROM FEC_Nature_of_Case__c
    WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
      AND FEC_Category__c = :c.FEC_Category__c
      AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
      AND FEC_Sub_Code__c = :c.FEC_SubCode__c
      AND FEC_Active__c = true LIMIT 1
];
if (nocs.isEmpty()) { System.debug('NOC not found'); return; }
System.debug('NOC: ' + nocs[0].Name + ' | Id: ' + nocs[0].Id);

// Check queue CC
List<Group> ccQueues = [SELECT Id, Name FROM Group WHERE Name LIKE '%CS Customer Care%' AND Type = 'Queue' LIMIT 5];
System.debug('CC Queues: ' + ccQueues.size());
for (Group g : ccQueues) System.debug('  ' + g.Name + ' | ' + g.Id);

// Nếu có queue thì insert
if (!ccQueues.isEmpty()) {
    FEC_Routing_Assignment__c ra = new FEC_Routing_Assignment__c(
        FEC_Nature_of_Cases__c = nocs[0].Id,
        FEC_Team__c = 'CC',
        FEC_Queue__c = ccQueues[0].Name,
        FEC_Active__c = true
    );
    insert ra;
    System.debug('Inserted RA: ' + ra.Id);
} else {
    System.debug('No CC queue found - check queue name');
}
