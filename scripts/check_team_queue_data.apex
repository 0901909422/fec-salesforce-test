List<FEC_Team_Queue__c> tqs = [
    SELECT Id, FEC_Select_Team__r.Name, FEC_Queue_Name__c
    FROM FEC_Team_Queue__c LIMIT 10
];
System.debug('FEC_Team_Queue__c records: ' + tqs.size());
for (FEC_Team_Queue__c tq : tqs) {
    System.debug('  Team: ' + tq.FEC_Select_Team__r?.Name + ' | Queue: ' + tq.FEC_Queue_Name__c);
}
