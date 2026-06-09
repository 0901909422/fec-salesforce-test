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
}