// List tất cả Queue trong org để biết DeveloperName đúng
List<Group> queues = [SELECT Id, Name, DeveloperName FROM Group WHERE Type = 'Queue' ORDER BY Name];
System.debug('Total queues: ' + queues.size());
for (Group g : queues) {
    System.debug('Name: [' + g.Name + '] | DeveloperName: [' + g.DeveloperName + '] | Id: [' + g.Id + ']');
}

// Xem tất cả Notification records hiện tại
List<FEC_Notification__c> notifs = [
    SELECT Id, Name, FEC_Assigned_to_Queue__c, FEC_Target_Group__c, 
           FEC_Notification_Status__c, FEC_Notification_Channel__r.Name
    FROM FEC_Notification__c
    ORDER BY Name
];
System.debug('=== ALL NOTIFICATION RECORDS ===');
for (FEC_Notification__c n : notifs) {
    System.debug('Notif: [' + n.Name + '] | Queue: [' + n.FEC_Assigned_to_Queue__c + '] | Channel: [' + n.FEC_Notification_Channel__r?.Name + '] | Active: ' + n.FEC_Notification_Status__c);
}
