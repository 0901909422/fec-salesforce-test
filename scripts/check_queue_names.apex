// Check Group names cho các queue liên quan
List<Group> queues = [
    SELECT Id, Name, DeveloperName
    FROM Group
    WHERE Type = 'Queue'
      AND (Name LIKE '%Card%' OR Name LIKE '%CO%' OR Name LIKE '%CA%')
    LIMIT 10
];
for (Group g : queues) {
    System.debug('Id: ' + g.Id + ' | Name: ' + g.Name + ' | DevName: ' + g.DeveloperName);
}

// Check FEC_Team_Queue__c queue names vs Group names
List<FEC_Team_Queue__c> tqs = [
    SELECT FEC_Queue_Name__c FROM FEC_Team_Queue__c
    WHERE FEC_Queue_Name__c != null LIMIT 5
];
for (FEC_Team_Queue__c tq : tqs) {
    List<Group> g = [SELECT Id, Name FROM Group WHERE Name = :tq.FEC_Queue_Name__c AND Type = 'Queue' LIMIT 1];
    System.debug('TQ Queue: ' + tq.FEC_Queue_Name__c + ' | Found: ' + !g.isEmpty());
}
