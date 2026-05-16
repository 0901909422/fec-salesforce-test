// Lấy notification có template
List<FEC_Notification__c> notifs = [
    SELECT FEC_Notification_Template__c,
           FEC_Notification_Template__r.FEC_Body__c,
           FEC_Notification_Template__r.FEC_Subject_Line__c,
           FEC_Notification_Template__r.FEC_Enhanced_Letterhead__c,
           FEC_Notification_Template__r.FEC_Folder__c
    FROM FEC_Notification__c
    WHERE FEC_Notification_Template__c != null
      AND FEC_Notification_Status__c = true
    LIMIT 3
];
System.debug('Found: ' + notifs.size());
for (FEC_Notification__c n : notifs) {
    System.debug('Template Id: ' + n.FEC_Notification_Template__c);
    System.debug('Subject: ' + n.FEC_Notification_Template__r?.FEC_Subject_Line__c);
    System.debug('Body length: ' + (n.FEC_Notification_Template__r?.FEC_Body__c != null ? n.FEC_Notification_Template__r.FEC_Body__c.length() : 0));
    System.debug('Letterhead: ' + n.FEC_Notification_Template__r?.FEC_Enhanced_Letterhead__c);
    
    // Check ContentDocumentLink
    List<ContentDocumentLink> links = [
        SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :n.FEC_Notification_Template__c
    ];
    System.debug('Files attached: ' + links.size());
    for (ContentDocumentLink l : links) {
        System.debug('  File: ' + l.ContentDocument.Title + ' | ' + l.ContentDocument.FileType);
    }
}
