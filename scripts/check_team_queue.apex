List<FEC_Team_Queue__c> records = [
    SELECT Id, FEC_Select_Team__r.Name, FEC_Queue_Name__c
    FROM FEC_Team_Queue__c
    WHERE FEC_Select_Team__c != null
    ORDER BY FEC_Select_Team__r.Name
    LIMIT 50
];
for (FEC_Team_Queue__c r : records) {
    System.debug('Team=[' + r.FEC_Select_Team__r?.Name + '] Queue=[' + r.FEC_Queue_Name__c + ']');
}
System.debug('Total: ' + records.size());
