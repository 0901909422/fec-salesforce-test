@IsTest
private class FEC_CustomEmailService_Test {

    @TestSetup
    static void setupData() {
        // Tạo Case
        Case c = new Case(Subject = 'Test Email Case', Status = 'Open');
        insert c;

        // Tạo OrgWideEmailAddress (cần thiết để gửi email thành công)
        // Lưu ý: OrgWideEmailAddress không thể insert trong Test. 
        // Nếu không có, hàm setFromAddress sẽ không tìm thấy Record và không set OrgWideEmailAddressId.
    }

    @IsTest
    static void testGetInteractionEmail() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        c.FEC_Send_To__c = 'support@fecredit.com.vn';
        c.FEC_Interaction_Email__c = 'customer@test.com';
        update c;

        Test.startTest();
        Map<String, String> result = FEC_CustomEmailService.getInteractionEmail(c.Id);
        Test.stopTest();

        System.assertEquals('support@fecredit.com.vn', result.get('fromEmail'));
        System.assertEquals('customer@test.com', result.get('toEmail'));
    }

    @IsTest
    static void testSendEmailV2_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        // Chuẩn bị Attachment
        List<FEC_CustomEmailService.AttachmentWrapper> attachments = new List<FEC_CustomEmailService.AttachmentWrapper>();
        FEC_CustomEmailService.AttachmentWrapper att = new FEC_CustomEmailService.AttachmentWrapper();
        att.fileName = 'test.txt';
        att.base64Data = EncodingUtil.base64Encode(Blob.valueOf('Hello'));
        att.mimeType = 'text/plain';
        attachments.add(att);

        Test.startTest();
        String result = FEC_CustomEmailService.sendEmailV2(
            c.Id, 
            'support@fecredit.com.vn', 
            'customer@test.com', 
            '', 
            'Subject', 
            'Body', 
            attachments, 
            ''
        );
        Test.stopTest();

        System.assertEquals('OK', result);
        // Xác minh Email đã được tạo trong hệ thống
        List<EmailMessage> msgs = [SELECT Id FROM EmailMessage WHERE ParentId = :c.Id];
        System.assertEquals(1, msgs.size(), 'Phải có 1 EmailMessage được tạo.');
    }

    @IsTest
    static void testValidation_InvalidEmail() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        try {
            FEC_CustomEmailService.sendEmailV2(
                c.Id, 'support@fecredit.com.vn', 'invalid-email', '', 'Sub', 'Body', null, ''
            );
            System.assert(false, 'Phải báo lỗi email sai định dạng.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetEmailTemplates() {
        // Cần đảm bảo có dữ liệu trong FEC_Outbound_Email_Config__c và FEC_Template__c
        Test.startTest();
        List<SObject> templates = FEC_CustomEmailService.getEmailTemplates();
        Test.stopTest();
        
        System.assertNotEquals(null, templates);
    }

    @IsTest
    static void testGetCaseSubjectAndRecordType() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        String subject = FEC_CustomEmailService.getCaseSubject(c.Id);
        String rtName = FEC_CustomEmailService.getCaseRecordTypeName(c.Id);
        Test.stopTest();

        System.assertEquals('Test Email Case', subject);
    }

    @IsTest
    static void testGetEmailMessages() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<EmailMessage> msgs = FEC_CustomEmailService.getEmailMessages(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, msgs);
    }

    @IsTest
    static void testGetFromAddresses() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        Map<String, Object> fromData = FEC_CustomEmailService.getFromAddresses(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, fromData);
        System.assert(fromData.containsKey('options'));
    }

    @IsTest
    static void testGetEmailTemplatesByMailbox() {
        Test.startTest();
        List<SObject> byMailbox = FEC_CustomEmailService.getEmailTemplatesByMailbox('support@fecredit.com.vn');
        List<SObject> fallback = FEC_CustomEmailService.getEmailTemplatesByMailbox('');
        Test.stopTest();

        System.assertNotEquals(null, byMailbox);
        System.assertNotEquals(null, fallback);
    }

    @IsTest
    static void testGetTemplateAttachmentsBulk() {
        FEC_Template__c template = new FEC_Template__c(
            Name = 'Email Template Test',
            FEC_Active__c = true
        );
        insert template;

        ContentVersion cv = new ContentVersion(
            Title = 'TemplateAttachment',
            PathOnClient = 'TemplateAttachment.pdf',
            VersionData = Blob.valueOf('Attachment')
        );
        insert cv;
        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        insert new ContentDocumentLink(
            LinkedEntityId = template.Id,
            ContentDocumentId = insertedCv.ContentDocumentId,
            ShareType = 'V'
        );

        Test.startTest();
        Object attachmentMap = FEC_CustomEmailService.getTemplateAttachmentsBulk(
            new List<String>{ String.valueOf(template.Id) }
        );
        Object emptyMap = FEC_CustomEmailService.getTemplateAttachmentsBulk(new List<String>());
        Test.stopTest();

        System.assertNotEquals(null, attachmentMap);
        System.assertNotEquals(null, emptyMap);
    }

    @IsTest
    static void testFetchImageAsBase64() {
        Test.setMock(HttpCalloutMock.class, new MockImageHttpResponse());

        Test.startTest();
        String dataUri = FEC_CustomEmailService.fetchImageAsBase64('https://example.com/image.jpg');
        Test.stopTest();

        System.assert(dataUri != null && dataUri.startsWith('data:'), 'Should return data URI on HTTP 200.');
    }

    @IsTest
    static void testSendEmailV2_BlockedStatus() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        c.Status = FEC_ConstantCommon.CASE_STATUS_CLOSED;
        update c;

        Test.startTest();
        try {
            FEC_CustomEmailService.sendEmailV2(
                c.Id,
                'support@fecredit.com.vn',
                'customer@test.com',
                '',
                'Blocked',
                'Body',
                null,
                ''
            );
            System.assert(false, 'Closed case should block email send.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetInteractionEmail_ParentFallback() {
        Id interactionRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            ? Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
                .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
                .getRecordTypeId()
            : null;

        Case parent = new Case(
            Subject = 'Email Parent',
            Status = 'Open',
            FEC_Send_To__c = 'queue@fecredit.com.vn',
            FEC_Interaction_Email__c = 'parent@test.com'
        );
        if (interactionRtId != null) {
            parent.RecordTypeId = interactionRtId;
        }
        insert parent;

        Case child = new Case(
            Subject = 'Email Child',
            Status = 'Open',
            FEC_Interaction__c = parent.Id
        );
        insert child;

        Test.startTest();
        Map<String, String> childResult = FEC_CustomEmailService.getInteractionEmail(child.Id);
        Test.stopTest();

        System.assertEquals('queue@fecredit.com.vn', childResult.get('fromEmail'));
        System.assertEquals('parent@test.com', childResult.get('toEmail'));
    }

    @IsTest
    static void testGetInteractionEmail_IncomingEmailMessageFallback() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        c.FEC_Send_To__c = null;
        c.FEC_Interaction_Email__c = null;
        update c;

        insert new EmailMessage(
            ParentId = c.Id,
            FromAddress = 'incoming@customer.com',
            ToAddress = 'support@fecredit.com.vn',
            Incoming = true,
            Subject = 'Inbound',
            TextBody = 'Hello',
            MessageDate = Datetime.now()
        );

        Test.startTest();
        Map<String, String> result = FEC_CustomEmailService.getInteractionEmail(c.Id);
        Test.stopTest();

        System.assertEquals('incoming@customer.com', result.get('toEmail'));
    }

    @IsTest
    static void testGetInteractionEmail_ChildCaseFallback() {
        Case parent = [SELECT Id, FEC_Send_To__c, FEC_Interaction_Email__c FROM Case LIMIT 1];
        parent.FEC_Send_To__c = 'parent-queue@fecredit.com.vn';
        parent.FEC_Interaction_Email__c = 'parent-customer@test.com';
        update parent;

        Case child = new Case(
            Subject = 'Email Child Fallback',
            Status = 'Open',
            FEC_Interaction__c = parent.Id
        );
        insert child;

        Test.startTest();
        Map<String, String> result = FEC_CustomEmailService.getInteractionEmail(child.Id);
        Test.stopTest();

        System.assertEquals('parent-queue@fecredit.com.vn', result.get('fromEmail'));
        System.assertEquals('parent-customer@test.com', result.get('toEmail'));
    }

    @IsTest
    static void testSendEmailV2_WithCcAndMergeFields() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        String result = FEC_CustomEmailService.sendEmailV2(
            c.Id,
            'support@fecredit.com.vn',
            'customer@test.com',
            'cc@test.com',
            'Subject with merge',
            'Hello {{User.Name}}',
            null,
            ''
        );
        Test.stopTest();

        System.assertEquals('OK', result);
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :c.Id AND Subject LIKE 'Email Sent:%'];
        System.assertEquals(1, tasks.size());
    }

    @IsTest
    static void testSendEmailV2_SkipsBlankAttachments() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        List<FEC_CustomEmailService.AttachmentWrapper> attachments =
            new List<FEC_CustomEmailService.AttachmentWrapper>();
        FEC_CustomEmailService.AttachmentWrapper blank = new FEC_CustomEmailService.AttachmentWrapper();
        blank.fileName = '';
        blank.base64Data = '';
        attachments.add(blank);

        Test.startTest();
        String result = FEC_CustomEmailService.sendEmailV2(
            c.Id,
            'support@fecredit.com.vn',
            'customer@test.com',
            '',
            'No attachments',
            'Body',
            attachments,
            ''
        );
        Test.stopTest();

        System.assertEquals('OK', result);
    }

    @IsTest
    static void testFetchImageAsBase64_Non200() {
        Test.setMock(HttpCalloutMock.class, new MockImageHttpNotFound());

        Test.startTest();
        String dataUri = FEC_CustomEmailService.fetchImageAsBase64('https://example.com/missing.jpg');
        Test.stopTest();

        System.assertEquals(null, dataUri);
    }

    @IsTest
    static void testGetCaseFileInfosAndContentDocumentAttachments() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'CaseFile',
            PathOnClient = 'CaseFile.pdf',
            VersionData = Blob.valueOf('pdf-content')
        );
        insert cv;
        ContentVersion insertedCv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];
        insert new ContentDocumentLink(
            LinkedEntityId = c.Id,
            ContentDocumentId = insertedCv.ContentDocumentId,
            ShareType = 'V'
        );

        Test.startTest();
        List<Map<String, String>> files = FEC_CustomEmailService.getCaseFileInfos(c.Id);
        List<FEC_ServiceCaseEmailService.AttachmentWrapper> attachments =
            FEC_CustomEmailService.getEmailAttachmentsFromContentDocuments(
                new List<String>{ String.valueOf(insertedCv.ContentDocumentId) }
            );
        List<Map<String, String>> emptyFiles = FEC_CustomEmailService.getCaseFileInfos('');
        List<FEC_ServiceCaseEmailService.AttachmentWrapper> emptyAttachments =
            FEC_CustomEmailService.getEmailAttachmentsFromContentDocuments(new List<String>());
        Test.stopTest();

        System.assertEquals(1, files.size(), 'Phải trả về file gắn với Case.');
        System.assert(files[0].get('name').contains('CaseFile'), files[0].get('name'));
        System.assertEquals(1, attachments.size(), 'Phải build attachment từ ContentDocument.');
        System.assertEquals(
            String.valueOf(insertedCv.ContentDocumentId),
            attachments[0].contentDocumentId
        );
        System.assert(attachments[0].fileName.contains('CaseFile'), attachments[0].fileName);
        System.assertEquals(0, emptyFiles.size());
        System.assertEquals(0, emptyAttachments.size());
    }

    @IsTest
    static void testGetEmailMessageAttachmentsAndResolveTemplate() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        EmailMessage em = new EmailMessage(
            ParentId = c.Id,
            FromAddress = 'from@test.com',
            ToAddress = 'to@test.com',
            Incoming = false,
            Subject = 'Outbound',
            TextBody = 'Body',
            MessageDate = Datetime.now()
        );
        insert em;

        ContentVersion cv = new ContentVersion(
            Title = 'EmailAttachment',
            PathOnClient = 'EmailAttachment.txt',
            VersionData = Blob.valueOf('attach-body')
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
        insert new ContentDocumentLink(
            LinkedEntityId = em.Id,
            ContentDocumentId = docId,
            ShareType = 'V'
        );

        Test.startTest();
        Map<String, List<Map<String, String>>> emailAttachments =
            FEC_CustomEmailService.getEmailMessageAttachments(
                new List<String>{ String.valueOf(em.Id) }
            );
        Map<String, String> resolved = FEC_CustomEmailService.resolveEmailTemplate(
            c.Id,
            'Subject {{Case.Subject}}',
            'Body {{User.Name}}'
        );
        Map<String, List<Map<String, String>>> emptyEmailAttachments =
            FEC_CustomEmailService.getEmailMessageAttachments(new List<String>());
        Test.stopTest();

        System.assert(emailAttachments.containsKey(String.valueOf(em.Id)));
        System.assertEquals(1, emailAttachments.get(String.valueOf(em.Id)).size());
        System.assert(resolved.containsKey('subject'));
        System.assert(resolved.containsKey('body'));
        System.assertEquals(0, emptyEmailAttachments.size());
    }

    @IsTest
    static void testSendEmailForServiceCase() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        String result = FEC_CustomEmailService.sendEmailForServiceCase(
            c.Id,
            'support@fecredit.com.vn',
            'customer@test.com',
            '',
            'Service case subject',
            'Service case body',
            null,
            ''
        );
        Test.stopTest();

        System.assertEquals('OK', result);
    }

    @IsTest
    static void testPublicizeImagesForEmail_BlankAndExternal() {
        System.assertEquals(null, FEC_CustomEmailService.publicizeImagesForEmail(null));
        System.assertEquals('', FEC_CustomEmailService.publicizeImagesForEmail(''));
        System.assertEquals(
            '<p>No image</p>',
            FEC_CustomEmailService.publicizeImagesForEmail('<p>No image</p>')
        );
        System.assertEquals(
            '<img src="https://cdn.example.com/logo.png">',
            FEC_CustomEmailService.publicizeImagesForEmail('<img src="https://cdn.example.com/logo.png">')
        );
        System.assertEquals(
            '<img src="data:image/png;base64,abc">',
            FEC_CustomEmailService.publicizeImagesForEmail('<img src="data:image/png;base64,abc">')
        );
    }

    @IsTest
    static void testPublicizeImagesForEmail_ContentVersionRef() {
        ContentVersion cv = new ContentVersion(
            Title = 'EmailHeader',
            PathOnClient = 'EmailHeader.png',
            VersionData = Blob.valueOf('png-bytes')
        );
        insert cv;
        Id cvId = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].Id;

        insert new ContentDistribution(
            Name = 'Email Image Dist',
            ContentVersionId = cvId,
            PreferencesAllowViewInBrowser = true,
            PreferencesLinkLatestVersion = true,
            PreferencesNotifyOnVisit = false
        );

        String cvUrl = '/servlet/servlet/rtaImage?refid=' + cvId;

        Test.startTest();
        String result = FEC_CustomEmailService.publicizeImagesForEmail(
            '<img src="' + cvUrl + '">'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGetInteractionEmail_IsManualFlag() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        c.FEC_Is_Manual__c = true;
        update c;

        Test.startTest();
        Map<String, String> result = FEC_CustomEmailService.getInteractionEmail(c.Id);
        Test.stopTest();

        System.assertEquals('true', result.get('isManual'));
    }

    @IsTest
    static void testGetInteractionEmail_ParentReadsChildFallback() {
        Case parent = new Case(
            Subject = 'Interaction Parent',
            Status = 'Open'
        );
        insert parent;

        insert new Case(
            Subject = 'Customer Child',
            Status = 'Open',
            FEC_Interaction__c = parent.Id,
            FEC_Send_To__c = 'child-route@fecredit.com.vn',
            FEC_Interaction_Email__c = 'child-customer@test.com'
        );

        Test.startTest();
        Map<String, String> result = FEC_CustomEmailService.getInteractionEmail(parent.Id);
        Test.stopTest();

        System.assertEquals('child-route@fecredit.com.vn', result.get('fromEmail'));
        System.assertEquals('child-customer@test.com', result.get('toEmail'));
    }

    @IsTest
    static void testGetEmailTemplates_WithOutboundConfig() {
        User currentUser = [
            SELECT Id
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        currentUser.FEC_User_Group__c = 'CC';
        update currentUser;

        insert new FEC_Outbound_Email_Config__c(
            FEC_User_Group__c = 'CC',
            FEC_Email__c = 'supportcsm@fecredit.com.vn'
        );
        insert new FEC_Template__c(
            Name = 'Mailbox Template Test',
            FEC_Active__c = true,
            FEC_Applicable_for_Mailbox__c = 'supportcsm@fecredit.com.vn',
            FEC_Subject_Line__c = 'Subject',
            FEC_Body__c = 'Body'
        );

        Test.startTest();
        List<SObject> templates = FEC_CustomEmailService.getEmailTemplates();
        List<SObject> byMailbox = FEC_CustomEmailService.getEmailTemplatesByMailbox(
            'supportcsm@fecredit.com.vn'
        );
        Test.stopTest();

        System.assertNotEquals(null, templates);
        System.assertNotEquals(null, byMailbox);
    }

    @IsTest
    static void testGetFromAddresses_WithOutboundConfig() {
        User currentUser = [
            SELECT Id
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        currentUser.FEC_User_Group__c = 'CC';
        update currentUser;

        insert new FEC_Outbound_Email_Config__c(
            FEC_User_Group__c = 'CC',
            FEC_Email__c = 'other@fecredit.com.vn'
        );
        insert new FEC_Outbound_Email_Config__c(
            FEC_User_Group__c = 'CC',
            FEC_Email__c = 'queue-match@fecredit.com.vn'
        );

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        Map<String, Object> fromData = FEC_CustomEmailService.getFromAddresses(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, fromData);
        System.assert(fromData.containsKey('options'));
        List<Object> options = (List<Object>) fromData.get('options');
        System.assert(options != null && !options.isEmpty());
    }

    @IsTest
    static void testGetEmailAttachmentsFromContentDocuments_MimeTypes() {
        Map<String, String> paths = new Map<String, String>{
            'PdfFile' => 'PdfFile.pdf',
            'PngFile' => 'PngFile.png',
            'JpgFile' => 'JpgFile.jpg',
            'XlsxFile' => 'XlsxFile.xlsx',
            'DocxFile' => 'DocxFile.docx'
        };
        List<String> docIds = new List<String>();
        for (String title : paths.keySet()) {
            ContentVersion cv = new ContentVersion(
                Title = title,
                PathOnClient = paths.get(title),
                VersionData = Blob.valueOf('file-' + title)
            );
            insert cv;
            Id docId = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ].ContentDocumentId;
            docIds.add(String.valueOf(docId));
        }

        Test.startTest();
        List<FEC_ServiceCaseEmailService.AttachmentWrapper> attachments =
            FEC_CustomEmailService.getEmailAttachmentsFromContentDocuments(docIds);
        Test.stopTest();

        System.assertEquals(5, attachments.size());
        Map<String, String> mimeByName = new Map<String, String>();
        for (FEC_ServiceCaseEmailService.AttachmentWrapper att : attachments) {
            mimeByName.put(att.fileName, att.mimeType);
        }
        System.assertEquals(FEC_ConstantCommon.MIME_PDF, mimeByName.get('PdfFile.pdf'));
        System.assertEquals(FEC_ConstantCommon.MIME_PNG, mimeByName.get('PngFile.png'));
        System.assertEquals(FEC_ConstantCommon.MIME_JPEG, mimeByName.get('JpgFile.jpg'));
        System.assertEquals(FEC_ConstantCommon.MIME_EXCEL, mimeByName.get('XlsxFile.xlsx'));
        System.assertEquals(FEC_ConstantCommon.MIME_WORD, mimeByName.get('DocxFile.docx'));
    }

    @IsTest
    static void testResolveEmailTemplate_NullCaseAndTripleBrace() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        Map<String, String> nullCase = FEC_CustomEmailService.resolveEmailTemplate(
            null,
            '{{{Case.Subject}}}',
            '{{{User.Name}}}'
        );
        Map<String, String> resolved = FEC_CustomEmailService.resolveEmailTemplate(
            c.Id,
            '{{{Case.Subject}}}',
            'Hello {{{User.FirstName}}}'
        );
        Test.stopTest();

        System.assertEquals('{{Subject}}', nullCase.get('subject'));
        System.assert(resolved.get('subject').contains('Test Email Case'));
        System.assertNotEquals(null, resolved.get('body'));
    }

    @IsTest
    static void testSendEmailV2_WithInternalImagesAndExistingThreadToken() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'BodyImage',
            PathOnClient = 'BodyImage.png',
            VersionData = Blob.valueOf('img')
        );
        insert cv;
        Id cvId = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].Id;
        String body =
            'Hello<br/><img src="/servlet/servlet/rtaImage?refid=' + cvId + '">';

        Test.startTest();
        String result = FEC_CustomEmailService.sendEmailV2(
            c.Id,
            'support@fecredit.com.vn',
            'customer@test.com',
            '',
            'Subject [ ref:00D000000000001.500000000000001:ref ]',
            body,
            null,
            ''
        );
        Test.stopTest();

        System.assertEquals('OK', result);
    }

    @IsTest
    static void testSendEmailV2_CancelledStatusBlocked() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        c.Status = FEC_ConstantCommon.CASE_STATUS_CANCELLED;
        update c;

        Test.startTest();
        try {
            FEC_CustomEmailService.sendEmailV2(
                c.Id,
                'support@fecredit.com.vn',
                'customer@test.com',
                '',
                'Cancelled',
                'Body',
                null,
                ''
            );
            System.assert(false, 'Cancelled case should block email send.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidation_EmptyToEmail() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        try {
            FEC_CustomEmailService.sendEmailV2(
                c.Id,
                'support@fecredit.com.vn',
                '',
                '',
                'Subject',
                'Body',
                null,
                ''
            );
            System.assert(false, 'Empty To email must throw.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testFetchImageAsBase64_ContentTypeWithSemicolon() {
        Test.setMock(HttpCalloutMock.class, new MockImageHttpResponseWithCharset());

        Test.startTest();
        String dataUri = FEC_CustomEmailService.fetchImageAsBase64('https://example.com/image.jpg');
        Test.stopTest();

        System.assert(dataUri != null && dataUri.startsWith('data:image/jpeg;base64,'), dataUri);
    }

    @IsTest
    static void testFetchImageAsBase64_CalloutFailureThrows() {
        Test.setMock(HttpCalloutMock.class, new MockImageHttpThrows());

        Test.startTest();
        try {
            FEC_CustomEmailService.fetchImageAsBase64('https://example.com/broken.jpg');
            System.assert(false, 'Callout failure should throw AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    private class MockImageHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'image/jpeg');
            res.setBodyAsBlob(Blob.valueOf('fake-image'));
            return res;
        }
    }

    private class MockImageHttpNotFound implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('Not found');
            return res;
        }
    }

    private class MockImageHttpResponseWithCharset implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'image/jpeg; charset=utf-8');
            res.setBodyAsBlob(Blob.valueOf('fake-image'));
            return res;
        }
    }

    private class MockImageHttpThrows implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated callout failure');
        }
    }
}