// Check template body của notification đang dùng
FEC_Notification__c notif = [
    SELECT FEC_Notification_Template__c, FEC_Notification_Template__r.FEC_Body__c,
           FEC_Notification_Template__r.FEC_Subject_Line__c
    FROM FEC_Notification__c
    WHERE FEC_Notification_Status__c = true
      AND FEC_Assigned_to_Queue__c = 'FEC_DQ_CS_Support'
      AND FEC_Notification_Channel__r.Name = 'Email'
    LIMIT 1
];
String body = notif.FEC_Notification_Template__r?.FEC_Body__c;
System.debug('Body length: ' + (body != null ? body.length() : 0));
System.debug('Body snippet: ' + (body != null ? body.left(300) : 'null'));
System.debug('Contains {{: ' + (body != null ? body.contains('{{') : false));
System.debug('Contains {{{: ' + (body != null ? body.contains('{{{') : false));
