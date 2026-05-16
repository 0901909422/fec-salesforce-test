// Check FEC_Queue_Name__c field: API name or Label?

List<FEC_Team_Queue__c> teamQueues = [
    SELECT Id, Name, FEC_Queue_Name__c, FEC_Select_Team__r.Name
    FROM FEC_Team_Queue__c
    LIMIT 10
];

System.debug('=== FEC_Team_Queue__c Records ===');
System.debug('Total: ' + teamQueues.size());
for (FEC_Team_Queue__c tq : teamQueues) {
    System.debug('Record: ' + tq.Name + ' | Team: ' + tq.FEC_Select_Team__r?.Name + ' | FEC_Queue_Name__c: ' + tq.FEC_Queue_Name__c);
}

// Check if FEC_Queue_Name__c matches Queue API Name or Label
if (!teamQueues.isEmpty() && String.isNotBlank(teamQueues[0].FEC_Queue_Name__c)) {
    String queueNameValue = teamQueues[0].FEC_Queue_Name__c;
    
    // Try to find queue by Name (Label)
    List<Group> queuesByName = [
        SELECT Id, Name, DeveloperName, QueueRoutingConfigId
        FROM Group
        WHERE Type = 'Queue' AND Name = :queueNameValue
        LIMIT 1
    ];
    
    // Try to find queue by DeveloperName (API Name)
    List<Group> queuesByDevName = [
        SELECT Id, Name, DeveloperName, QueueRoutingConfigId
        FROM Group
        WHERE Type = 'Queue' AND DeveloperName = :queueNameValue
        LIMIT 1
    ];
    
    System.debug('=== ANALYSIS ===');
    System.debug('FEC_Queue_Name__c value: ' + queueNameValue);
    System.debug('Match by Name (Label): ' + (!queuesByName.isEmpty()));
    if (!queuesByName.isEmpty()) {
        System.debug('  Queue Name: ' + queuesByName[0].Name + ' | DeveloperName: ' + queuesByName[0].DeveloperName);
    }
    System.debug('Match by DeveloperName (API): ' + (!queuesByDevName.isEmpty()));
    if (!queuesByDevName.isEmpty()) {
        System.debug('  Queue Name: ' + queuesByDevName[0].Name + ' | DeveloperName: ' + queuesByDevName[0].DeveloperName);
    }
    
    if (!queuesByName.isEmpty()) {
        System.debug('==> FEC_Queue_Name__c is storing LABEL (Name)');
    } else if (!queuesByDevName.isEmpty()) {
        System.debug('==> FEC_Queue_Name__c is storing API NAME (DeveloperName)');
    } else {
        System.debug('==> FEC_Queue_Name__c value does not match any queue');
    }
}
