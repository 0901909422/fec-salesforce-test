String refid = '0EMAz000000uTAb';
System.debug('refid prefix: ' + refid.left(3));

// Thử query ContentDocument
List<ContentDocument> docs = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument WHERE Id = :refid LIMIT 1];
System.debug('ContentDocument: ' + docs);

// Thử query ContentVersion by ContentDocumentId
List<ContentVersion> cvs = [SELECT Id, Title, FileType FROM ContentVersion WHERE ContentDocumentId = :refid AND IsLatest = true LIMIT 1];
System.debug('ContentVersion by DocId: ' + cvs);

// Thử query ContentVersion trực tiếp
List<ContentVersion> cvs2 = [SELECT Id, Title, FileType FROM ContentVersion WHERE Id = :refid LIMIT 1];
System.debug('ContentVersion by Id: ' + cvs2);
