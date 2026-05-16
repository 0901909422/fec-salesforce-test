// Check template đang dùng cho notification
FEC_Notification__c n = [
    SELECT FEC_Notification_Template__c,
           FEC_Notification_Template__r.FEC_Body__c,
           FEC_Notification_Template__r.FEC_Subject_Line__c,
           FEC_Notification_Template__r.FEC_Enhanced_Letterhead__c,
           FEC_Notification_Template__r.FEC_Folder__c
    FROM FEC_Notification__c
    WHERE FEC_Assigned_to_Queue__c = 'FEC_DQ_CS_Support'
    LIMIT 1
];
System.debug('Template Id: ' + n.FEC_Notification_Template__c);
System.debug('Subject: ' + n.FEC_Notification_Template__r?.FEC_Subject_Line__c);
System.debug('Body: ' + n.FEC_Notification_Template__r?.FEC_Body__c);
System.debug('Letterhead: ' + n.FEC_Notification_Template__r?.FEC_Enhanced_Letterhead__c);
System.debug('Folder: ' + n.FEC_Notification_Template__r?.FEC_Folder__c);

// Check letterhead content
Id lhId = n.FEC_Notification_Template__r?.FEC_Enhanced_Letterhead__c;
if (lhId != null) {
    EnhancedLetterhead lh = [SELECT Id, Name, LetterheadHeader, LetterheadFooter FROM EnhancedLetterhead WHERE Id = :lhId LIMIT 1];
    System.debug('Letterhead name: ' + lh.Name);
    System.debug('Header: ' + lh.LetterheadHeader?.substring(0, Math.min(200, lh.LetterheadHeader?.length() ?? 0)));
    System.debug('Footer: ' + lh.LetterheadFooter?.substring(0, Math.min(200, lh.LetterheadFooter?.length() ?? 0)));
}

// Check ContentDocumentLink (file đính kèm) của template
List<ContentDocumentLink> links = [
    SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType
    FROM ContentDocumentLink
    WHERE LinkedEntityId = :n.FEC_Notification_Template__c
];
System.debug('Attachments count: ' + links.size());
for (ContentDocumentLink l : links) {
    System.debug('File: ' + l.ContentDocument.Title + ' | Type: ' + l.ContentDocument.FileType);
}
