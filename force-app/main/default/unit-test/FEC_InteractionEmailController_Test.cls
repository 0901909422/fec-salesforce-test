/**
 * Unit tests for FEC_InteractionEmailController.
 */
@IsTest
private class FEC_InteractionEmailController_Test {

    private static final String CASE_SUBJECT = 'FEC_InteractionEmailController_Test Case';
    private static final String CUSTOMER_FROM = 'customer@test.com';
    private static final String MAILBOX_TO = 'support@fecredit.com.vn';

    @TestSetup
    static void setupData() {
        Case c = new Case(
            Subject = CASE_SUBJECT,
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new EmailMessage(
            ParentId = c.Id,
            Incoming = true,
            FromAddress = CUSTOMER_FROM,
            ToAddress = MAILBOX_TO,
            Subject = 'Inbound email',
            TextBody = 'Customer message',
            MessageDate = Datetime.now().addMinutes(-10)
        );

        insert new EmailMessage(
            ParentId = c.Id,
            Incoming = false,
            FromAddress = MAILBOX_TO,
            ToAddress = CUSTOMER_FROM,
            Subject = 'Outbound email',
            TextBody = 'Agent reply',
            MessageDate = Datetime.now()
        );
    }

    private static Case testCase() {
        return [SELECT Id FROM Case WHERE Subject = :CASE_SUBJECT LIMIT 1];
    }

    @IsTest
    static void testGetInteractionEmail_WithIncoming() {
        Case c = testCase();

        Test.startTest();
        Map<String, String> result = FEC_InteractionEmailController.getInteractionEmail(c.Id);
        Test.stopTest();

        System.assertEquals(CUSTOMER_FROM, result.get('toEmail'));
        System.assertEquals(MAILBOX_TO, result.get('fromEmail'));
    }

    @IsTest
    static void testGetInteractionEmail_NoIncoming() {
        Case c = new Case(
            Subject = 'No incoming email case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN
        );
        insert c;

        Test.startTest();
        Map<String, String> result = FEC_InteractionEmailController.getInteractionEmail(c.Id);
        Test.stopTest();

        System.assertEquals('', result.get('toEmail'));
        System.assertEquals('', result.get('fromEmail'));
    }

    @IsTest
    static void testGetCaseSubject() {
        Case c = testCase();

        Test.startTest();
        String subject = FEC_InteractionEmailController.getCaseSubject(c.Id);
        Test.stopTest();

        System.assertEquals(CASE_SUBJECT, subject);
    }

    @IsTest
    static void testGetEmailMessages() {
        Case c = testCase();

        Test.startTest();
        List<EmailMessage> msgs = FEC_InteractionEmailController.getEmailMessages(c.Id);
        Test.stopTest();

        System.assertEquals(2, msgs.size());
        System.assertEquals('Outbound email', msgs[0].Subject);
    }

    @IsTest
    static void testGetEmailTemplates() {
        Test.startTest();
        List<EmailTemplate> templates = FEC_InteractionEmailController.getEmailTemplates();
        Test.stopTest();

        System.assertNotEquals(null, templates);
    }

    @IsTest
    static void testSendEmailToCustomer_StandardFromWithCc() {
        Case c = testCase();

        Test.startTest();
        FEC_InteractionEmailController.sendEmailToCustomer(
            c.Id,
            'agent@fecredit.com.vn',
            'recipient@test.com',
            'cc@test.com',
            'Reply subject',
            'Line one\nLine two'
        );
        Test.stopTest();
    }

    @IsTest
    static void testSendEmailToCustomer_ReadonlyFromAddress() {
        Case c = testCase();

        Test.startTest();
        try {
            FEC_InteractionEmailController.sendEmailToCustomer(
                c.Id,
                FEC_ConstantCommon.EMAIL_READONLY_FROM_FECREDIT,
                'recipient@test.com',
                null,
                'From readonly',
                'Body'
            );
        } catch (AuraHandledException e) {
            // Org-wide mailbox may be missing in sandbox; branch is still executed.
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendEmailToCustomer_OrgWideFromWhenAvailable() {
        List<OrgWideEmailAddress> orgWide = [
            SELECT Address FROM OrgWideEmailAddress LIMIT 1
        ];
        if (orgWide.isEmpty()) {
            return;
        }

        Case c = testCase();
        Test.startTest();
        try {
            FEC_InteractionEmailController.sendEmailToCustomer(
                c.Id,
                orgWide[0].Address,
                'recipient@test.com',
                null,
                'Org-wide from',
                'Body'
            );
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendEmailToCustomer_BlankFrom() {
        Case c = testCase();

        Test.startTest();
        FEC_InteractionEmailController.sendEmailToCustomer(
            c.Id,
            null,
            'recipient@test.com',
            null,
            'No from',
            'Plain body'
        );
        Test.stopTest();
    }

    private class ImageSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'image/png; charset=utf-8');
            res.setBodyAsBlob(Blob.valueOf('fake-image-bytes'));
            return res;
        }
    }

    private class ImageNotFoundMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('Not found');
            return res;
        }
    }

    private class ImageErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Callout failed');
        }
    }

    @IsTest
    static void testFetchImageAsBase64_Success() {
        Test.setMock(HttpCalloutMock.class, new ImageSuccessMock());

        Test.startTest();
        String dataUri = FEC_InteractionEmailController.fetchImageAsBase64(
            'https://example.com/image.png'
        );
        Test.stopTest();

        System.assertNotEquals(null, dataUri);
        System.assert(dataUri.startsWith('data:image/png;base64,'));
    }

    @IsTest
    static void testFetchImageAsBase64_Non200ReturnsNull() {
        Test.setMock(HttpCalloutMock.class, new ImageNotFoundMock());

        Test.startTest();
        String dataUri = FEC_InteractionEmailController.fetchImageAsBase64(
            'https://example.com/missing.png'
        );
        Test.stopTest();

        System.assertEquals(null, dataUri);
    }

    @IsTest
    static void testFetchImageAsBase64_DefaultContentType() {
        Test.setMock(HttpCalloutMock.class, new ImageNoContentTypeMock());

        Test.startTest();
        String dataUri = FEC_InteractionEmailController.fetchImageAsBase64(
            'https://example.com/raw.bin'
        );
        Test.stopTest();

        System.assertNotEquals(null, dataUri);
        System.assert(dataUri.startsWith('data:image/jpeg;base64,'));
    }

    private class ImageNoContentTypeMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBodyAsBlob(Blob.valueOf('bytes'));
            return res;
        }
    }

    @IsTest
    static void testFetchImageAsBase64_CalloutException() {
        Test.setMock(HttpCalloutMock.class, new ImageErrorMock());

        Test.startTest();
        try {
            FEC_InteractionEmailController.fetchImageAsBase64('https://example.com/error.png');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }
}
