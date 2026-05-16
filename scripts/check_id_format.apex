// Check FEC_OwnerID__c format (15 hay 18 char)
List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_OwnerID__c FROM FEC_Assignment__c
    WHERE FEC_Assignment_Type__c = 'Routing' AND FEC_OwnerID__c != null
    ORDER BY CreatedDate DESC LIMIT 3
];
for (FEC_Assignment__c a : assignments) {
    System.debug('Name: ' + a.Name + ' | OwnerID: ' + a.FEC_OwnerID__c + ' | Length: ' + a.FEC_OwnerID__c.length());
}
