List<FEC_Routing_Assignment__c> records = [
    SELECT Id, Name, FEC_Queue__c, FEC_Team__c, FEC_Nature_of_Cases__c
    FROM FEC_Routing_Assignment__c
    WHERE FEC_Queue__c LIKE '%Credit%'
    LIMIT 10
];
for (FEC_Routing_Assignment__c r : records) {
    System.debug('Id=' + r.Id + ' Name=' + r.Name + ' Queue=[' + r.FEC_Queue__c + '] Team=' + r.FEC_Team__c + ' NOC=' + r.FEC_Nature_of_Cases__c);
}
System.debug('Total: ' + records.size());
