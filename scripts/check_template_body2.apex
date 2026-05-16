// Xem body của template đang dùng trong notification
FEC_Notification__c notif = [
    SELECT FEC_Notification_Template__c, FEC_Notification_Template__r.FEC_Body__c,
           FEC_Notification_Template__r.FEC_Subject_Line__c,
           FEC_Notification_Template__r.Name
    FROM FEC_Notification__c
    WHERE FEC_Notification_Status__c = true
      AND FEC_Assigned_to_Queue__c = 'FEC_DQ_CS_Support'
      AND FEC_Notification_Channel__r.Name = 'Email'
    LIMIT 1
];
System.debug('Template: ' + notif.FEC_Notification_Template__r.Name);
System.debug('Subject: ' + notif.FEC_Notification_Template__r.FEC_Subject_Line__c);
System.debug('Body: ' + notif.FEC_Notification_Template__r.FEC_Body__c);
