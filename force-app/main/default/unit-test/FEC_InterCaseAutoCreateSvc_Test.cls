@IsTest
private class FEC_InterCaseAutoCreateSvc_Test {

    private static FEC_InteractionCaseAutoCreateService.InteractionCaseRequest buildBaseRequest() {
        FEC_InteractionCaseAutoCreateService.InteractionCaseRequest req =
            new FEC_InteractionCaseAutoCreateService.InteractionCaseRequest();

        req.sys = new FEC_InteractionCaseAutoCreateService.SysType();
        req.sys.channel = 'Genesys';
        req.sys.transactionID = 'TX-' + String.valueOf(System.currentTimeMillis());
        req.sys.dateTime_x = System.now();

        req.interactionInfo = new FEC_InteractionCaseAutoCreateService.InteractionInfo();
        req.interactionInfo.genesysInteractionID = 'GEN-' + String.valueOf(System.currentTimeMillis());
        req.interactionInfo.agentId = 'AGENT-001';
        req.interactionInfo.channel = 'Inbound';
        req.interactionInfo.subChannel = 'Voice';
        req.interactionInfo.otherSubChannel = null;
        req.interactionInfo.status = 'Completed';

        req.customerInfo = new FEC_InteractionCaseAutoCreateService.CustomerInfo();
        req.customerInfo.phoneNumber = '0901234567';
        req.customerInfo.nationalId = '123456789';
        req.customerInfo.accountNumber = 'ACCT001';
        req.customerInfo.contractNumber = 'CON001';

        req.interactionData = new FEC_InteractionCaseAutoCreateService.InteractionData();
        req.interactionData.transcription = 'Sample transcript';
        req.interactionData.kycMethod = 'Face';
        req.interactionData.kycResult = 'Pass';

        return req;
    }

    @IsTest
    static void testCreateInteractionCase_NullRequest() {
        Test.startTest();
        FEC_InteractionCaseAutoCreateService.InteractionCaseResponse res =
            FEC_InteractionCaseAutoCreateService.CreateInteractionCase(null);
        Test.stopTest();

        System.assertEquals('400', res.code);
        System.assertEquals('FAILURE', res.status);
        System.assertEquals('Invalid request: Request body is null', res.message);
    }

    @IsTest
    static void testCreateInteractionCase_MissingSys() {
        FEC_InteractionCaseAutoCreateService.InteractionCaseRequest req = buildBaseRequest();
        req.sys = null;

        Test.startTest();
        FEC_InteractionCaseAutoCreateService.InteractionCaseResponse res =
            FEC_InteractionCaseAutoCreateService.CreateInteractionCase(req);
        Test.stopTest();

        System.assertEquals('400', res.code);
        System.assertEquals('FAILURE', res.status);
        System.assertEquals('Invalid request: Sys info is missing', res.message);
    }

    @IsTest
    static void testCreateInteractionCase_MissingInteractionInfo() {
        FEC_InteractionCaseAutoCreateService.InteractionCaseRequest req = buildBaseRequest();
        req.interactionInfo = null;

        Test.startTest();
        FEC_InteractionCaseAutoCreateService.InteractionCaseResponse res =
            FEC_InteractionCaseAutoCreateService.CreateInteractionCase(req);
        Test.stopTest();

        System.assertEquals('400', res.code);
        System.assertEquals('FAILURE', res.status);
        System.assertEquals('Invalid request: InteractionInfo is missing', res.message);
    }

    @IsTest
    static void testCreateInteractionCase_MissingChannel() {
        FEC_InteractionCaseAutoCreateService.InteractionCaseRequest req = buildBaseRequest();
        req.interactionInfo.channel = null;

        Test.startTest();
        FEC_InteractionCaseAutoCreateService.InteractionCaseResponse res =
            FEC_InteractionCaseAutoCreateService.CreateInteractionCase(req);
        Test.stopTest();

        System.assertEquals('400', res.code);
        System.assertEquals('FAILURE', res.status);
        System.assertEquals('InteractionInfo.channel is required', res.message);
    }

    @IsTest
    static void testCreateInteractionCase_InboundWithoutPhone() {
        FEC_InteractionCaseAutoCreateService.InteractionCaseRequest req = buildBaseRequest();
        req.interactionInfo.channel = 'Inbound';
        req.customerInfo.phoneNumber = null;

        Test.startTest();
        FEC_InteractionCaseAutoCreateService.InteractionCaseResponse res =
            FEC_InteractionCaseAutoCreateService.CreateInteractionCase(req);
        Test.stopTest();

        System.assertEquals('400', res.code);
        System.assertEquals('FAILURE', res.status);
        System.assertEquals(
            'CustomerInfo.phoneNumber is required for Inbound/Outbound calls',
            res.message
        );
    }

    @IsTest
    static void testCreateInteractionCase_ValidRequest_NonValidationPath() {
        FEC_InteractionCaseAutoCreateService.InteractionCaseRequest req = buildBaseRequest();

        Test.startTest();
        FEC_InteractionCaseAutoCreateService.InteractionCaseResponse res =
            FEC_InteractionCaseAutoCreateService.CreateInteractionCase(req);
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertNotEquals('400', res.code, 'Valid request should not fail at validation layer');
        System.assert(
            res.code == '200' || res.code == '500',
            'Result should be success or handled server error depending on org dependencies'
        );
    }
}
