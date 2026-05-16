// eid = a0xAz000000jS4z (letterhead record)
// feoid = 00NAz000006JLmt (field Id)
// refid = 0EMAz000000uTAb (?)

// Thử query ContentDocumentLink linked to letterhead record
String lhId = 'a0xAz000000jS4zIAE';
List<ContentDocumentLink> links = [
    SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
    FROM ContentDocumentLink
    WHERE LinkedEntityId = :lhId
];
System.debug('ContentDocumentLinks for letterhead: ' + links.size());
for (ContentDocumentLink l : links) {
    System.debug('DocId=' + l.ContentDocumentId + ' Title=' + l.ContentDocument.Title + ' VersionId=' + l.ContentDocument.LatestPublishedVersionId);
}

// Thử xem refid 0EMAz000000uTAb là gì
// 0EM = ContentVersion prefix? Không. Thử describe
System.debug('refid prefix 0EM - checking...');
List<ContentVersion> cvByRefid = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id = '0EMAz000000uTAb' LIMIT 1];
System.debug('ContentVersion by refid as Id: ' + cvByRefid);
