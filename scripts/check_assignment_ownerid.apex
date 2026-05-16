// Check các assignment Routing gần nhất xem FEC_OwnerID__c có giá trị không
List<FEC_Assignment__c> assignments = [
    SELECT Id, FEC_Case__r.CaseNumber, FEC_Team__c, FEC_OwnerID__c,
           FEC_Assignment_Owner__c, FEC_Assignment_Owner__r.Name,
           FEC_Assignment_Owner_Text__c, FEC_Manual__c, CreatedDate
    FROM FEC_Assignment__c
    WHERE FEC_Assignment_Type__c = 'Routing'
    ORDER BY CreatedDate DESC LIMIT 10
];
System.debug('Total: ' + assignments.size());
for (FEC_Assignment__c a : assignments) {
    System.debug('Case: ' + a.FEC_Case__r?.CaseNumber
        + ' | Team: ' + a.FEC_Team__c
        + ' | OwnerID: ' + a.FEC_OwnerID__c
        + ' | Owner: ' + a.FEC_Assignment_Owner__r?.Name
        + ' | OwnerText: ' + a.FEC_Assignment_Owner_Text__c
        + ' | Manual: ' + a.FEC_Manual__c);
}
