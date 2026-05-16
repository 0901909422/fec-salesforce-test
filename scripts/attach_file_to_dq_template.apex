// Tìm template đang dùng cho FEC_DQ_CS_Support notification
FEC_Notification__c notif = [
    SELECT FEC_Notification_Template__c, FEC_Notification_Template__r.Name
    FROM FEC_Notification__c
    WHERE FEC_Notification_Status__c = true
      AND FEC_Assigned_to_Queue__c = 'FEC_DQ_CS_Support'
      AND FEC_Notification_Channel__r.Name = 'Email'
    LIMIT 1
];
System.debug('Template: ' + notif.FEC_Notification_Template__r.Name + ' Id=' + notif.FEC_Notification_Template__c);

// Check xem đã có attachment chưa
List<ContentDocumentLink> existing = [
    SELECT ContentDocumentId, ContentDocument.Title
    FROM ContentDocumentLink WHERE LinkedEntityId = :notif.FEC_Notification_Template__c
];
System.debug('Existing attachments: ' + existing.size());
for (ContentDocumentLink l : existing) System.debug('  - ' + l.ContentDocument.Title);

// Attach file test nếu chưa có
if (existing.isEmpty()) {
    ContentVersion cv = new ContentVersion();
    cv.Title = 'TestAttachment_DQ';
    cv.PathOnClient = 'TestAttachment_DQ.txt';
    cv.VersionData = Blob.valueOf('Test attachment for DQ CS Support notification.');
    cv.IsMajorVersion = true;
    insert cv;
    cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
    ContentDocumentLink link = new ContentDocumentLink();
    link.ContentDocumentId = cv.ContentDocumentId;
    link.LinkedEntityId = notif.FEC_Notification_Template__c;
    link.ShareType = 'V';
    link.Visibility = 'AllUsers';
    insert link;
    System.debug('Attached new file to template!');
}
