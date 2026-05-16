// Check xem Notification template nào có file attach
List<FEC_Notification__c> notifs = [
    SELECT Id, Name, FEC_Notification_Template__c, FEC_Notification_Template__r.Name
    FROM FEC_Notification__c
    WHERE FEC_Notification_Template__c != null
    AND FEC_Notification_Status__c = true
    LIMIT 20
];

Set<Id> templateIds = new Set<Id>();
for (FEC_Notification__c n : notifs) {
    templateIds.add(n.FEC_Notification_Template__c);
}
System.debug('Template IDs: ' + templateIds);

List<ContentDocumentLink> links = [
    SELECT ContentDocumentId, LinkedEntityId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
    FROM ContentDocumentLink
    WHERE LinkedEntityId IN :templateIds
];
System.debug('Total attachments found: ' + links.size());
for (ContentDocumentLink l : links) {
    System.debug('Template=' + l.LinkedEntityId + ' File=' + l.ContentDocument.Title + ' VersionId=' + l.ContentDocument.LatestPublishedVersionId);
}
