List<FEC_Routing_Assignment__c> ras = [SELECT FEC_Team__c, FEC_Queue__c FROM FEC_Routing_Assignment__c WHERE FEC_Active__c = true LIMIT 3];
for (FEC_Routing_Assignment__c ra : ras) {
    System.debug('Team: ' + ra.FEC_Team__c + ' | Queue: ' + ra.FEC_Queue__c);
    List<Group> g1 = [SELECT Id FROM Group WHERE Name = :ra.FEC_Queue__c AND Type = 'Queue' LIMIT 1];
    List<Group> g2 = [SELECT Id FROM Group WHERE DeveloperName = :ra.FEC_Queue__c AND Type = 'Queue' LIMIT 1];
    System.debug('  Match by Name: ' + !g1.isEmpty() + ' | Match by DevName: ' + !g2.isEmpty());
}
