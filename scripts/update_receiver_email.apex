// Update receiver email cho FEC_DQ_CS_Support notification
FEC_Notification__c notif = [
    SELECT Id, FEC_Receivers__c
    FROM FEC_Notification__c
    WHERE FEC_Notification_Status__c = true
      AND FEC_Assigned_to_Queue__c = 'FEC_DQ_CS_Support'
      AND FEC_Notification_Channel__r.Name = 'Email'
    LIMIT 1
];
System.debug('Before: ' + notif.FEC_Receivers__c);
notif.FEC_Receivers__c = 'tungnm37@fpt.com';
update notif;
System.debug('After: ' + notif.FEC_Receivers__c);
