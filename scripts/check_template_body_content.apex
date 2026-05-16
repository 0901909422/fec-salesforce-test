// Check body content của template đang dùng
FEC_Notification__c n = [
    SELECT FEC_Notification_Template__r.FEC_Body__c,
           FEC_Notification_Template__r.FEC_Subject_Line__c,
           FEC_Notification_Template__r.FEC_Enhanced_Letterhead__c
    FROM FEC_Notification__c
    WHERE FEC_Assigned_to_Queue__c = 'FEC_Ubank_Email'
      AND FEC_Notification_Status__c = true
    LIMIT 1
];
System.debug('Subject: ' + n.FEC_Notification_Template__r?.FEC_Subject_Line__c);
System.debug('Body: ' + n.FEC_Notification_Template__r?.FEC_Body__c);
System.debug('Letterhead Id: ' + n.FEC_Notification_Template__r?.FEC_Enhanced_Letterhead__c);

// Check letterhead content
if (n.FEC_Notification_Template__r?.FEC_Enhanced_Letterhead__c != null) {
    EnhancedLetterhead lh = [SELECT Id, Name, LetterheadHeader, LetterheadFooter FROM EnhancedLetterhead WHERE Id = :n.FEC_Notification_Template__r.FEC_Enhanced_Letterhead__c LIMIT 1];
    System.debug('Letterhead name: ' + lh.Name);
    System.debug('Header: ' + lh.LetterheadHeader);
    System.debug('Footer: ' + lh.LetterheadFooter);
}
