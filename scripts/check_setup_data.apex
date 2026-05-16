// 1. List tất cả EnhancedLetterhead
List<EnhancedLetterhead> lhs = [SELECT Id, Name, LetterheadHeader, LetterheadFooter FROM EnhancedLetterhead LIMIT 10];
System.debug('=== EnhancedLetterheads: ' + lhs.size());
for (EnhancedLetterhead lh : lhs) {
    System.debug('LH: ' + lh.Id + ' | ' + lh.Name + ' | Header len: ' + (lh.LetterheadHeader != null ? lh.LetterheadHeader.length() : 0) + ' | Footer len: ' + (lh.LetterheadFooter != null ? lh.LetterheadFooter.length() : 0));
}

// 2. Template đang dùng cho Notification
List<FEC_Notification__c> notifs = [
    SELECT Id, Name, FEC_Assigned_to_Queue__c,
           FEC_Notification_Template__c,
           FEC_Notification_Template__r.Name,
           FEC_Notification_Template__r.FEC_Enhanced_Letterhead__c
    FROM FEC_Notification__c
    WHERE FEC_Notification_Status__c = true
      AND FEC_Notification_Channel__r.Name = 'Email'
      AND FEC_Assigned_to_Queue__c != null
];
System.debug('=== Active Email Notifications: ' + notifs.size());
for (FEC_Notification__c n : notifs) {
    System.debug('Notif: ' + n.Name + ' | Queue: ' + n.FEC_Assigned_to_Queue__c + ' | Template: ' + n.FEC_Notification_Template__r?.Name + ' | Letterhead: ' + n.FEC_Notification_Template__r?.FEC_Enhanced_Letterhead__c);
}

// 3. Files đính kèm vào template
Set<Id> tIds = new Set<Id>();
for (FEC_Notification__c n : notifs) if (n.FEC_Notification_Template__c != null) tIds.add(n.FEC_Notification_Template__c);
if (!tIds.isEmpty()) {
    List<ContentDocumentLink> cdls = [SELECT LinkedEntityId, ContentDocument.Title, ContentDocument.FileType FROM ContentDocumentLink WHERE LinkedEntityId IN :tIds];
    System.debug('=== Files linked to templates: ' + cdls.size());
    for (ContentDocumentLink cdl : cdls) {
        System.debug('File: ' + cdl.ContentDocument.Title + ' | Type: ' + cdl.ContentDocument.FileType + ' | Template: ' + cdl.LinkedEntityId);
    }
}
