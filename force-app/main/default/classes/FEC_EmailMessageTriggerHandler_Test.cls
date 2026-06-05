@IsTest
private class FEC_EmailMessageTriggerHandler_Test {

    @TestSetup
    static void setupData() {
        // 1. Tạo Customer Case (Parent)
        Id customerRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME).getRecordTypeId();
        
        Case parentCase = new Case(
            Subject = 'Parent Case',
            RecordTypeId = customerRtId,
            Status = 'Open'
        );
        insert parentCase;

        // 2. Tạo Interaction Case (Child)
        Case childCase = new Case(
            Subject = 'Interaction Case',
            ParentId = parentCase.Id,
            Status = 'Open'
        );
        insert childCase;
    }

    @IsTest
    static void testRedirectIncomingReplyToServiceCase() {
        Case childCase = [SELECT Id, ParentId FROM Case WHERE Subject = 'Interaction Case' LIMIT 1];

        // 3. Tạo EmailMessage incoming (đây là hành động trigger gọi handler)
        EmailMessage em = new EmailMessage(
            ParentId = childCase.Id,
            Incoming = true,
            ThreadIdentifier = 'THREAD-123',
            MessageIdentifier = 'MSG-456', // Khác với ThreadIdentifier
            FromAddress = 'customer@test.com',
            ToAddress = 'support@fecredit.com.vn',
            Subject = 'Re: Parent Case [ ref:00D000000000000.500000000000000:ref ]',
            HtmlBody = '<body>Test body</body>'
        );

        Test.startTest();
        insert em;
        Test.stopTest();

        // 4. Xác thực EmailMessage đã được copy sang Parent Case
        List<EmailMessage> parentEmails = [
            SELECT Id, ParentId, Subject 
            FROM EmailMessage 
            WHERE ParentId = :childCase.ParentId
        ];

        System.assertEquals(1, parentEmails.size(), 'EmailMessage phải được copy sang Customer Case gốc.');
        System.assert(!parentEmails[0].Subject.contains('[ ref:'), 'Token ref phải được loại bỏ khỏi subject.');
    }

    @IsTest
    static void testDoNotRedirectIfSameThread() {
        Case childCase = [SELECT Id, ParentId FROM Case WHERE Subject = 'Interaction Case' LIMIT 1];

        // Trường hợp ThreadIdentifier == MessageIdentifier (không phải reply)
        EmailMessage em = new EmailMessage(
            ParentId = childCase.Id,
            Incoming = true,
            ThreadIdentifier = 'T1',
            MessageIdentifier = 'T1',
            Subject = 'Test'
        );

        Test.startTest();
        insert em;
        Test.stopTest();

        List<EmailMessage> parentEmails = [SELECT Id FROM EmailMessage WHERE ParentId = :childCase.ParentId];
        System.assertEquals(0, parentEmails.size(), 'EmailMessage không được copy nếu ThreadIdentifier trùng MessageIdentifier.');
    }
}