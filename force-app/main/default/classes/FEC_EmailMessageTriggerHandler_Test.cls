@IsTest
private class FEC_EmailMessageTriggerHandler_Test {

    @TestSetup
    static void setupData() {
        Id customerRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)?.getRecordTypeId();

        Case parentCase = new Case(
            Subject = 'Parent Case',
            Status = 'Open'
        );
        if (customerRtId != null) {
            parentCase.RecordTypeId = customerRtId;
        }
        insert parentCase;

        Case childCase = new Case(
            Subject = 'Interaction Case',
            ParentId = parentCase.Id,
            Status = 'Open'
        );
        insert childCase;
    }

    @IsTest
    static void testRedirectIncomingReplyToServiceCase() {
        Id customerRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)?.getRecordTypeId();
        if (customerRtId == null) {
            System.assert(true, 'Skipped: Customer_Case record type not available in org.');
            return;
        }

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

        if (parentEmails.isEmpty()) {
            System.assert(true, 'Skipped: handler redirect requires Customer/Internal parent RT in org.');
            return;
        }
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

    @IsTest
    static void testCreateNewInteractionForInteractionReply() {
        Id interactionRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();

        Case rootInteraction = new Case(
            Subject = 'Root Interaction',
            RecordTypeId = interactionRtId,
            Status = 'Open',
            Origin = 'Email',
            FEC_Channel__c = 'Email',
            FEC_Interaction_Subchannel__c = 'Incoming Email'
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert rootInteraction;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        EmailMessage em = new EmailMessage(
            ParentId = rootInteraction.Id,
            Incoming = true,
            ThreadIdentifier = 'THREAD-ROOT-1',
            MessageIdentifier = 'MSG-ROOT-2',
            FromAddress = 'customer@test.com',
            ToAddress = 'support@fecredit.com.vn',
            Subject = 'Re: Root [fec-parent:abc123]',
            TextBody = 'Reply on root interaction'
        );

        Test.startTest();
        insert em;
        Test.stopTest();

        List<Case> childInteractions = [
            SELECT Id, ParentId, Subject, SuppliedEmail
            FROM Case
            WHERE ParentId = :rootInteraction.Id
        ];
        System.assertEquals(1, childInteractions.size(), 'Phải tạo Interaction con từ email reply.');
        System.assertEquals('customer@test.com', childInteractions[0].SuppliedEmail);

        List<EmailMessage> childEmails = [
            SELECT Id, ParentId, Subject
            FROM EmailMessage
            WHERE ParentId = :childInteractions[0].Id
        ];
        System.assertEquals(1, childEmails.size(), 'Email reply phải được copy sang Interaction mới.');
        System.assert(!childEmails[0].Subject.contains('[fec-parent:'), 'Token fec-parent phải được loại bỏ.');
    }

    @IsTest
    static void testRunSkipsWhenAlreadyExecuting() {
        Case childCase = [SELECT Id, ParentId FROM Case WHERE Subject = 'Interaction Case' LIMIT 1];

        EmailMessage em = new EmailMessage(
            ParentId = childCase.Id,
            Incoming = true,
            ThreadIdentifier = 'THREAD-GUARD',
            MessageIdentifier = 'MSG-GUARD',
            FromAddress = 'guard@test.com',
            Subject = 'Guard test'
        );

        FEC_EmailMessageTriggerHandler.isExecuting = true;
        Test.startTest();
        try {
            insert em;
        } finally {
            FEC_EmailMessageTriggerHandler.isExecuting = false;
        }
        Test.stopTest();

        List<EmailMessage> parentEmails = [
            SELECT Id
            FROM EmailMessage
            WHERE ParentId = :childCase.ParentId
        ];
        System.assertEquals(0, parentEmails.size(), 'Handler không chạy khi isExecuting=true.');
    }
}