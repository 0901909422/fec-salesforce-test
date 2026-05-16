// Upload 1 file test vào template a10Az00000GW96zIAD
Id templateId = 'a10Az00000GW96zIAD';

// Tạo ContentVersion (file test)
ContentVersion cv = new ContentVersion();
cv.Title = 'TestAttachment';
cv.PathOnClient = 'TestAttachment.txt';
cv.VersionData = Blob.valueOf('This is a test attachment from notification template.');
cv.IsMajorVersion = true;
insert cv;

// Lấy ContentDocumentId
cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

// Link vào template
ContentDocumentLink link = new ContentDocumentLink();
link.ContentDocumentId = cv.ContentDocumentId;
link.LinkedEntityId = templateId;
link.ShareType = 'V';
link.Visibility = 'AllUsers';
insert link;

System.debug('File attached! ContentDocumentId=' + cv.ContentDocumentId + ' linked to template=' + templateId);
