List<FEC_Notification__c> notifs = [
    SELECT Id, Name, FEC_Target_Group__c, FEC_Notification_Status__c,
           FEC_Notification_Channel__r.Name, FEC_Assigned_to_Queue__c, FEC_Receivers__c
    FROM FEC_Notification__c
    WHERE Name IN ('TEST_EMAIL_NOTIF', 'TEST_SFAPP_NOTIF')
];
System.debug('Count: ' + notifs.size());
for (FEC_Notification__c n : notifs) {
    System.debug(n.Name + ' | Channel: ' + n.FEC_Notification_Channel__r?.Name
        + ' | Queue: ' + n.FEC_Assigned_to_Queue__c
        + ' | Receivers: ' + n.FEC_Receivers__c
        + ' | Active: ' + n.FEC_Notification_Status__c);
}

// Check queue hiện tại của case
Case c = [SELECT Id, OwnerId, Owner.Name FROM Case WHERE Id = '500Az00000M8FmqIAF'];
System.debug('Case owner: ' + c.Owner.Name + ' (' + c.OwnerId + ')');
