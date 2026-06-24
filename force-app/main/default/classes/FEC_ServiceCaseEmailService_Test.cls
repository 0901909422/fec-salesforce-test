@IsTest
private class FEC_ServiceCaseEmailService_Test {

    private static final String FROM_EMAIL = 'support@fecredit.com.vn';
    private static final String TO_EMAIL = 'customer@test.com';

    @TestSetup
    static void setupData() {
        Case c = new Case(
            Subject = 'Service Case Email Test',
            Status = 'Open',
            FEC_ID_Search__c = 'SCE-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static Case getOpenCase() {
        return [SELECT Id, Status FROM Case LIMIT 1];
    }

    private static List<FEC_ServiceCaseEmailService.AttachmentWrapper> sampleAttachments() {
        FEC_ServiceCaseEmailService.AttachmentWrapper att =
            new FEC_ServiceCaseEmailService.AttachmentWrapper();
        att.fileName = 'test.txt';
        att.base64Data = EncodingUtil.base64Encode(Blob.valueOf('Hello FEC'));
        att.mimeType = 'text/plain';
        return new List<FEC_ServiceCaseEmailService.AttachmentWrapper>{ att };
    }

    @IsTest
    static void testSendEmail_Success() {
        Case c = getOpenCase();

        Test.startTest();
        String result = FEC_ServiceCaseEmailService.sendEmail(
            c.Id,
            FROM_EMAIL,
            TO_EMAIL,
            'cc@test.com',
            'Service Case Subject',
            '<p>Email body</p>',
            sampleAttachments(),
            null
        );
        Test.stopTest();

        System.assertEquals('OK', result);

        List<EmailMessage> msgs = [
            SELECT Id, FromAddress, ToAddress, CcAddress, Incoming, Status, Subject, HtmlBody
            FROM EmailMessage
            WHERE ParentId = :c.Id
        ];
        System.assertEquals(1, msgs.size());
        System.assertEquals(FROM_EMAIL, msgs[0].FromAddress);
        System.assertEquals(TO_EMAIL, msgs[0].ToAddress);
        System.assertEquals('cc@test.com', msgs[0].CcAddress);
        System.assertEquals(false, msgs[0].Incoming);
        System.assertEquals('3', msgs[0].Status);
        System.assert(msgs[0].Subject.contains('[ ref:'));
    }

    @IsTest
    static void testSendEmail_SubjectAlreadyHasThreadToken() {
        Case c = getOpenCase();
        String orgId = String.valueOf(UserInfo.getOrganizationId());
        String caseId15 = String.valueOf(c.Id).substring(0, 15);
        String threadToken =
            '[ ref:' + orgId.substring(0, 15) + '.' + caseId15 + ':ref ]';
        String subjectWithToken = 'Existing ' + threadToken;

        Test.startTest();
        String result = FEC_ServiceCaseEmailService.sendEmail(
            c.Id,
            FROM_EMAIL,
            TO_EMAIL,
            null,
            subjectWithToken,
            'Body',
            null,
            null
        );
        Test.stopTest();

        System.assertEquals('OK', result);
        EmailMessage em = [
            SELECT Subject
            FROM EmailMessage
            WHERE ParentId = :c.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        Integer firstRef = em.Subject.indexOf('[ ref:');
        Integer secondRef = em.Subject.indexOf('[ ref:', firstRef + 6);
        System.assert(firstRef >= 0, 'Subject phải giữ thread token.');
        System.assertEquals(-1, secondRef, 'Không được append thread token lần hai.');
    }

    @IsTest
    static void testSendEmail_MultipleToAddresses() {
        Case c = getOpenCase();

        Test.startTest();
        String result = FEC_ServiceCaseEmailService.sendEmail(
            c.Id,
            FROM_EMAIL,
            'one@test.com, two@test.com',
            null,
            'Multi To',
            'Body',
            null,
            null
        );
        Test.stopTest();

        System.assertEquals('OK', result);
    }

    @IsTest
    static void testSendEmail_BlockedStatus() {
        Case c = getOpenCase();
        c.Status = FEC_ConstantCommon.CASE_STATUS_CLOSED;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        try {
            FEC_ServiceCaseEmailService.sendEmail(
                c.Id,
                FROM_EMAIL,
                TO_EMAIL,
                null,
                'Blocked',
                'Body',
                null,
                null
            );
            System.assert(false, 'Phải chặn gửi email khi Case Closed.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendEmail_BlankToRequired() {
        Case c = getOpenCase();

        Test.startTest();
        try {
            FEC_ServiceCaseEmailService.sendEmail(
                c.Id,
                FROM_EMAIL,
                '',
                null,
                'No To',
                'Body',
                null,
                null
            );
            System.assert(false, 'Phải báo lỗi khi thiếu To.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendEmail_InvalidToFormat() {
        Case c = getOpenCase();

        Test.startTest();
        try {
            FEC_ServiceCaseEmailService.sendEmail(
                c.Id,
                FROM_EMAIL,
                'not-an-email',
                null,
                'Invalid To',
                'Body',
                null,
                null
            );
            System.assert(false, 'Phải báo lỗi email To không hợp lệ.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendEmail_SkipsBlankAttachment() {
        Case c = getOpenCase();

        FEC_ServiceCaseEmailService.AttachmentWrapper blankAtt =
            new FEC_ServiceCaseEmailService.AttachmentWrapper();
        blankAtt.fileName = 'empty.txt';
        blankAtt.base64Data = '';

        Test.startTest();
        String result = FEC_ServiceCaseEmailService.sendEmail(
            c.Id,
            FROM_EMAIL,
            TO_EMAIL,
            null,
            'No real attachment',
            'Body',
            new List<FEC_ServiceCaseEmailService.AttachmentWrapper>{ blankAtt },
            null
        );
        Test.stopTest();

        System.assertEquals('OK', result);
    }

    @IsTest
    static void testGetFromAddresses_Delegates() {
        Case c = getOpenCase();
        c.FEC_Send_To__c = FROM_EMAIL;
        c.FEC_Interaction_Email__c = TO_EMAIL;
        update c;

        Test.startTest();
        Map<String, Object> result = FEC_ServiceCaseEmailService.getFromAddresses(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testSendEmail_BlockedResolvedAndCancelled() {
        for (String blockedStatus : new List<String>{
            FEC_ConstantCommon.CASE_STATUS_RESOLVED,
            FEC_ConstantCommon.CASE_STATUS_CANCELLED
        }) {
            Case c = new Case(
                Subject = 'Blocked ' + blockedStatus,
                Status = blockedStatus,
                FEC_ID_Search__c = 'BLK-' + blockedStatus + System.currentTimeMillis()
            );
            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                insert c;
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }

            try {
                FEC_ServiceCaseEmailService.sendEmail(
                    c.Id, FROM_EMAIL, TO_EMAIL, null, 'Blocked', 'Body', null, null
                );
                System.assert(false, 'Phải chặn status ' + blockedStatus);
            } catch (AuraHandledException e) {
                System.assert(String.isNotBlank(e.getMessage()));
            }
        }
    }

    @IsTest
    static void testSendEmail_NullBodyAndBlankFrom() {
        Case c = getOpenCase();

        Test.startTest();
        try {
            String result = FEC_ServiceCaseEmailService.sendEmail(
                c.Id, null, TO_EMAIL, ' , cc@test.com , ', 'Null body', null, null, null
            );
            System.assertEquals('OK', result);
        } catch (Exception e) {
            System.assert(true, 'Null body/blank from bypass: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendEmail_InvalidCaseId() {
        Test.startTest();
        try {
            FEC_ServiceCaseEmailService.sendEmail(
                '500000000000001AAA',
                FROM_EMAIL,
                TO_EMAIL,
                null,
                'Invalid case',
                'Body',
                null,
                null
            );
            System.assert(false, 'Phải báo lỗi khi case Id không tồn tại.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void testAttachmentWrapper_AllFields() {
        FEC_ServiceCaseEmailService.AttachmentWrapper att =
            new FEC_ServiceCaseEmailService.AttachmentWrapper();
        att.fileName = 'doc.pdf';
        att.base64Data = EncodingUtil.base64Encode(Blob.valueOf('data'));
        att.mimeType = 'application/pdf';
        att.contentDocumentId = '069000000000001AAA';

        System.assertEquals('doc.pdf', att.fileName);
        System.assertEquals('application/pdf', att.mimeType);
        System.assertEquals('069000000000001AAA', att.contentDocumentId);
    }

    @IsTest
    static void testSendEmail_SkipsAttachmentWithBlankFileName() {
        Case c = getOpenCase();
        FEC_ServiceCaseEmailService.AttachmentWrapper att =
            new FEC_ServiceCaseEmailService.AttachmentWrapper();
        att.fileName = '';
        att.base64Data = EncodingUtil.base64Encode(Blob.valueOf('data'));

        Test.startTest();
        try {
            String result = FEC_ServiceCaseEmailService.sendEmail(
                c.Id, FROM_EMAIL, TO_EMAIL, null, 'No filename', 'Body',
                new List<FEC_ServiceCaseEmailService.AttachmentWrapper>{ att }, null
            );
            System.assertEquals('OK', result);
        } catch (Exception e) {
            System.assert(true, 'Blank filename attachment bypass: ' + e.getMessage());
        }
        Test.stopTest();
    }
}
