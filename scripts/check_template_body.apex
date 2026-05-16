FEC_Notification__c n = [
    SELECT FEC_Notification_Template__r.FEC_Subject_Line__c,
           FEC_Notification_Template__r.FEC_Body__c
    FROM FEC_Notification__c
    WHERE FEC_Assigned_to_Queue__c = 'FEC_DQ_CS_Support'
    LIMIT 1
];
System.debug('Subject: ' + n.FEC_Notification_Template__r?.FEC_Subject_Line__c);
System.debug('Body: ' + n.FEC_Notification_Template__r?.FEC_Body__c);
