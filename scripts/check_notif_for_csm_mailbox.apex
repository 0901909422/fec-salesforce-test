// Tìm notification rule cho CSM Mailbox queue
Group q = [SELECT Id, DeveloperName FROM Group WHERE Name = 'CSM Mailbox' AND Type = 'Queue' LIMIT 1];
System.debug('Queue: ' + q.Id + ' DeveloperName=' + q.DeveloperName);

List<FEC_Notification__c> notifs = [
    SELECT Id, Name, FEC_Assigned_to_Queue__c, FEC_Notification_Template__c, FEC_Notification_Template__r.Name,
           FEC_Notification_Channel__r.Name
    FROM FEC_Notification__c
    WHERE FEC_Notification_Status__c = true
    AND FEC_Notification_Template__c != null
];
for (FEC_Notification__c n : notifs) {
    if (n.FEC_Assigned_to_Queue__c == q.DeveloperName || n.FEC_Assigned_to_Queue__c == String.valueOf(q.Id)) {
        System.debug('MATCH: notif=' + n.Name + ' channel=' + n.FEC_Notification_Channel__r?.Name
            + ' templateId=' + n.FEC_Notification_Template__c + ' templateName=' + n.FEC_Notification_Template__r?.Name);
    }
}
