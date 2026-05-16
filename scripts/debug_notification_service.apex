Id queueId = [SELECT Id FROM Group WHERE Name = 'CSM Mailbox' AND Type = 'Queue' LIMIT 1].Id;
Id myUserId = UserInfo.getUserId();

// Step 1: Check buildQueueLookupMap
Map<String, Id> lookup = new Map<String, Id>();
for (Group g : [SELECT Id, DeveloperName FROM Group WHERE Id = :queueId AND Type = 'Queue']) {
    lookup.put(g.DeveloperName, g.Id);
    lookup.put(String.valueOf(g.Id).substring(0, 15), g.Id);
    lookup.put(String.valueOf(g.Id), g.Id);
}
System.debug('Lookup map: ' + lookup);

// Step 2: Check notification records
String channelEmail = 'Email';
String targetInternal = 'Internal User';
List<FEC_Notification__c> notifs = [
    SELECT Id, FEC_Assigned_to_Queue__c, FEC_Receivers__c,
           FEC_Notification_Channel__r.Name, FEC_Target_Group__c
    FROM FEC_Notification__c
    WHERE FEC_Target_Group__c = :targetInternal
      AND FEC_Notification_Status__c = true
      AND FEC_Notification_Channel__r.Name = :channelEmail
      AND FEC_Assigned_to_Queue__c != null
];
System.debug('Notifications found: ' + notifs.size());
for (FEC_Notification__c n : notifs) {
    String assignedVal = n.FEC_Assigned_to_Queue__c.trim();
    Id matched = lookup.get(assignedVal);
    System.debug('Notif: ' + n.Id + ' | Assigned: ' + assignedVal + ' | Match: ' + matched + ' | Receivers: ' + n.FEC_Receivers__c);
}
