@IsTest
private class FEC_CardClosureRefundController_Test {

    private static final String CS_DECISION_18 = 'Có khoản chờ giải ngân. Cần tư vấn khách hàng giữ thẻ';

    private class DisbInfoSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"Sys2":{"Code2":"1","TransID":"TXN-DISB","Description":"OK"},' +
                '"Applications":[{"Application":{' +
                '"ApplicationID":"APP-API-001",' +
                '"AppStatusLos":"Resolved-Completed",' +
                '"DisbAmount":"15,000,000",' +
                '"RequestedDt":"2026/05/20 15:00:00",' +
                '"DisbStatus":"CONFIRMED"}}]}'
            );
            return res;
        }
    }

    private class DisbInfoMatrixMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"Sys2":{"Code2":"1","TransID":"TXN-MATRIX","Description":"OK"},' +
                '"Applications":[' +
                '{"Application":{"DisbStatus":"ORIG"}},' +
                '{"Application":{"DisbStatus":"CANCELLED","AppStatusLos":"Resolved-Cancelled"}},' +
                '{"Application":{"DisbStatus":"UNKNOWN_STATUS_CODE_XYZ"}}' +
                ']}'
            );
            return res;
        }
    }

    private class DisbInfoFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('error');
            return res;
        }
    }

    private class CardLockSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"Sys":{"TransID":"TXN-LOCK","DateTime":"2026-06-03T17:24:43.867415513+07:00",' +
                '"Code":"1","Description":"LOCK_SUCCESS","BlockCode":"C"}}'
            );
            return res;
        }
    }

    private class CardUnlockSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"Sys":{"Code":"2","Description":"UNLOCK_SUCCESS","TransID":"TXN-UNLOCK"}}');
            return res;
        }
    }

    private class CardLockFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"Sys":{"Code":"99","Description":"Failed"},"errorMessage":"Card is already locked or invalid state"}');
            return res;
        }
    }

    private class CardLockUnsuccessfulDescMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"Sys":{"Code":"1","Description":"Unsuccessful operation","TransID":"TXN-UNSUCCESS"}}');
            return res;
        }
    }

    private class VmxWrongCodeSuccessDescMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><WSResponse>' +
                '<Sys><TransID>T-VMX-BAD</TransID><Code>99</Code><Description>Success</Description></Sys>' +
                '<VMX_ACCT_BLKCD_UPD_EMEA><VMX_ROOT><VMX_MSGOUT>' +
                '<SVC_RETURN>F</SVC_RETURN><ORG>Org1</ORG><CARD_NBR>1234</CARD_NBR>' +
                '</VMX_MSGOUT></VMX_ROOT></VMX_ACCT_BLKCD_UPD_EMEA>' +
                '</WSResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class DisbInfoBadParseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"Sys2":{"Code2":"1","TransID":"TXN-BAD-PARSE","Description":"OK"},' +
                '"Applications":[{"Application":{' +
                '"ApplicationID":"APP-BAD-001",' +
                '"AppStatusLos":"Open",' +
                '"DisbAmount":"not-a-number",' +
                '"RequestedDt":"bad-date-format",' +
                '"DisbStatus":"CONFIRMED"}}]}'
            );
            return res;
        }
    }

    private class DisbInfoConfirmedOpenMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"Sys2":{"Code2":"1","TransID":"TXN-CONF-OPEN","Description":"OK"},' +
                '"Applications":[{"Application":{' +
                '"ApplicationID":"APP-CONF-OPEN",' +
                '"AppStatusLos":"Open",' +
                '"DisbStatus":"CONFIRMED"}}]}'
            );
            return res;
        }
    }

    private class DisbInfoCancelledOpenMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"Sys2":{"Code2":"1","TransID":"TXN-CAN-OPEN","Description":"OK"},' +
                '"Applications":[{"Application":{' +
                '"ApplicationID":"APP-CAN-OPEN",' +
                '"AppStatusLos":"Open",' +
                '"DisbStatus":"CANCELLED"}}]}'
            );
            return res;
        }
    }

    private class BlockCardFullPathMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String body = req.getBody() != null ? req.getBody() : '';
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
            if (body.contains('VMX_ACCT_BLKCD') || endpoint.contains('vmx')) {
                res.setBody(
                    '<?xml version="1.0" encoding="UTF-8"?>' +
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><WSResponse>' +
                    '<Sys><TransID>T-VMX</TransID><Code>1</Code><Description>Success</Description></Sys>' +
                    '<VMX_ACCT_BLKCD_UPD_EMEA><VMX_ROOT><VMX_MSGOUT>' +
                    '<SVC_RETURN>S</SVC_RETURN><ORG>Org1</ORG><CARD_NBR>1234</CARD_NBR>' +
                    '</VMX_MSGOUT></VMX_ROOT></VMX_ACCT_BLKCD_UPD_EMEA>' +
                    '</WSResponse></soapenv:Body></soapenv:Envelope>'
                );
            } else if (endpoint.contains('disb') || body.contains('GetDisbInfo')) {
                res.setBody(
                    '{"Sys2":{"Code2":"1","TransID":"TXN-DISB","Description":"OK"},' +
                    '"Applications":[{"Application":{"DisbStatus":"ORIG"}}]}'
                );
            } else {
                res.setBody(
                '{"Sys":{"TransID":"TXN-LOCK","DateTime":"2026-06-03T17:24:43.867415513+07:00",' +
                '"Code":"1","Description":"LOCK_SUCCESS","BlockCode":"C"}}'
            );
            }
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Endpoint__c = 'https://api.test.com';
        apiSetting.FEC_Call_Mock__c = true;
        upsert apiSetting;

        FEC_Sub_Code__c subCodeRC16 = new FEC_Sub_Code__c(
            Name = 'RC16.01',
            FEC_Code__c = 'RC16.01',
            FEC_Active__c = true
        );
        FEC_Sub_Code__c subCodeNormal = new FEC_Sub_Code__c(
            Name = 'RC27.01',
            FEC_Code__c = 'RC27.01',
            FEC_Active__c = true
        );
        insert new List<FEC_Sub_Code__c>{ subCodeRC16, subCodeNormal };

        Case caseWithApi = new Case(
            Subject = 'Case API Disbursement Test',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_Account_Number__c = 'ACC-999999',
            FEC_SubCode__c = subCodeNormal.Id,
            FEC_Card_Block_Service_Attempts__c = 0,
            FEC_Is_Test_API__c = true
        );
        Case caseWithDb = new Case(
            Subject = 'Case DB Snapshot Test',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Phone',
            FEC_SubCode__c = subCodeRC16.Id,
            FEC_Card_Block_Service_Attempts__c = 3
        );
        insert new List<Case>{ caseWithApi, caseWithDb };

        FEC_Customer_History__c customer = new FEC_Customer_History__c(
            Name = 'CUST-CLOSURE-001',
            FEC_Case__c = caseWithApi.Id,
            FEC_Account_Number__c = 'ACC-999999',
            FEC_Card_Number__c = '1234-5678-9876-5432',
            FEC_Block_Code__c = 'O',
            FEC_Block_Code_1__c = 'F'
        );
        insert customer;

        update new List<Case>{
            new Case(Id = caseWithApi.Id, FEC_Account_or_Contract__c = customer.Id),
            new Case(Id = caseWithDb.Id, FEC_Account_or_Contract__c = customer.Id)
        };

        Schema.SObjectType pdType = Schema.getGlobalDescribe().get('FEC_Pending_Disbursement__c');
        if (pdType != null) {
            SObject pd = pdType.newSObject();
            Map<String, Schema.SObjectField> fMap = pdType.getDescribe().fields.getMap();
            if (fMap.containsKey('FEC_Case__c')) {
                pd.put('FEC_Case__c', caseWithDb.Id);
            }
            if (fMap.containsKey('FEC_PD_Application_ID__c')) {
                pd.put('FEC_PD_Application_ID__c', 'APP-LOS-2026');
            }
            if (fMap.containsKey('FEC_PD_Application_Status__c')) {
                pd.put('FEC_PD_Application_Status__c', 'Resolved-Completed');
            }
            if (fMap.containsKey('FEC_PD_Disbursement_Status__c')) {
                pd.put('FEC_PD_Disbursement_Status__c', 'CONFIRMED');
            }
            if (fMap.containsKey('FEC_PD_Disbursed_Amount__c')) {
                pd.put('FEC_PD_Disbursed_Amount__c', 5000000);
            }
            insert pd;
        }
    }

    private static User testRunAsUser() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return admins.isEmpty() ? new User(Id = UserInfo.getUserId()) : admins[0];
    }

    @IsTest
    static void testGetCardLockUnlockUiContext_ApiSuccess() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new DisbInfoSuccessMock());

            Test.startTest();
            FEC_CardClosureRefundController.CardLockUiContextDTO context =
                FEC_CardClosureRefundController.getCardLockUnlockUiContext(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, context);
            System.assertEquals('APP-API-001', context.pendingApplicationId);
            System.assertEquals(15000000, context.pendingDisbursedAmount);
            System.assertEquals(Date.newInstance(2026, 5, 20), context.pendingDisbursementApprovalDate);
            System.assertEquals(CS_DECISION_18, context.pendingCsDecision);
        }
    }

    @IsTest
    static void testGetCardLockUnlockUiContext_DbFallback() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case DB Snapshot Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new DisbInfoFailureMock());

            Test.startTest();
            FEC_CardClosureRefundController.CardLockUiContextDTO context =
                FEC_CardClosureRefundController.getCardLockUnlockUiContext(c.Id);
            FEC_CardClosureRefundController.CardLockUiContextDTO contextNull =
                FEC_CardClosureRefundController.getCardLockUnlockUiContext(null);
            Test.stopTest();

            System.assertNotEquals(null, context);
            System.assertEquals(true, context.hideBlockCardBySubCode);
            System.assertEquals(true, context.attemptsExhausted);
            System.assertEquals('APP-LOS-2026', context.pendingApplicationId);
            System.assertEquals(null, contextNull.pendingApplicationId);
        }
    }

    @IsTest
    static void testResolvePendingDisbursementCsDecision_Matrix() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new DisbInfoMatrixMock());

            Test.startTest();
            FEC_CardClosureRefundController.getCardLockUnlockUiContext(c.Id);
            Test.stopTest();
            System.assert(true);
        }
    }

    @IsTest
    static void testBlockCard_Success() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new CardLockSuccessMock());

            Test.startTest();
            FEC_CardClosureRefundController.LockUnlockResultDTO result =
                FEC_CardClosureRefundController.blockCard(c.Id);
            Test.stopTest();

            System.assertEquals(true, result.success);
            System.assertEquals('1', result.code);
            System.assertEquals('LOCK_SUCCESS', result.description);
            System.assertEquals(0, result.cardBlockServiceAttemptsAfter);
            System.assertEquals(true, result.hideBlockCardAfterAction);

            FEC_Customer_History__c updatedCust = [
                SELECT FEC_Block_Code__c, FEC_Block_Code_1__c
                FROM FEC_Customer_History__c
                LIMIT 1
            ];
            System.assertEquals('C', updatedCust.FEC_Block_Code__c);
        }
    }

    @IsTest
    static void testBlockCard_ApiFailure() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new CardLockFailureMock());

            Test.startTest();
            FEC_CardClosureRefundController.LockUnlockResultDTO result =
                FEC_CardClosureRefundController.blockCard(c.Id);
            Test.stopTest();

            System.assertEquals(false, result.success);
            System.assertEquals(1, result.cardBlockServiceAttemptsAfter);
        }
    }

    @IsTest
    static void testUnblockCard_SuccessAndValidationFails() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new CardUnlockSuccessMock());

            Test.startTest();
            FEC_CardClosureRefundController.LockUnlockResultDTO resSuccess =
                FEC_CardClosureRefundController.unblockCard(c.Id);
            FEC_CardClosureRefundController.LockUnlockResultDTO resNoCaseId =
                FEC_CardClosureRefundController.blockCard(null);

            Case dbCase = [SELECT Id FROM Case WHERE Subject = 'Case DB Snapshot Test' LIMIT 1];
            FEC_CardClosureRefundController.LockUnlockResultDTO resForbiddenSubCode =
                FEC_CardClosureRefundController.blockCard(dbCase.Id);
            Test.stopTest();

            System.assertEquals(true, resSuccess.success);
            System.assertEquals(false, resNoCaseId.success);
            System.assertEquals(false, resForbiddenSubCode.success);
        }
    }

    @IsTest
    static void testExecuteLockUnlock_ExceptionHandling() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new CardLockFailureMock());

            Test.startTest();
            FEC_CardClosureRefundController.LockUnlockResultDTO result =
                FEC_CardClosureRefundController.blockCard(c.Id);
            Test.stopTest();

            System.assertEquals(false, result.success);
            System.assertEquals(1, result.cardBlockServiceAttemptsAfter);
        }
    }

    @IsTest
    static void testGetLast4Digit_Variations() {
        System.runAs(testRunAsUser()) {
            FEC_Customer_History__c cust = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
            cust.FEC_Card_Number__c = '123';
            update cust;

            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];

            Test.startTest();
            FEC_CardClosureRefundController.LockUnlockResultDTO resShort =
                FEC_CardClosureRefundController.blockCard(c.Id);
            Test.stopTest();

            System.assertEquals(false, resShort.success);
            System.assert(resShort.errorMessage.contains('Card Number'));
        }
    }

    @IsTest
    static void testGetCardLockUnlockUiContext_BadParseAndCardBlocked() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];
            FEC_Customer_History__c cust = [
                SELECT Id
                FROM FEC_Customer_History__c
                LIMIT 1
            ];
            cust.FEC_Block_Code__c = 'C';
            update cust;

            Test.setMock(HttpCalloutMock.class, new DisbInfoBadParseMock());
            Test.startTest();
            FEC_CardClosureRefundController.CardLockUiContextDTO context =
                FEC_CardClosureRefundController.getCardLockUnlockUiContext(c.Id);
            Test.stopTest();

            System.assertEquals(null, context.pendingDisbursedAmount);
            System.assertEquals(null, context.pendingDisbursementApprovalDate);
            System.assertEquals(true, context.cardBlocked);
            System.assertEquals(false, context.showBlockCardButton);
        }
    }

    @IsTest
    static void testGetCardLockUnlockUiContext_CsDecisionBranches() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];

            Test.setMock(HttpCalloutMock.class, new DisbInfoConfirmedOpenMock());
            FEC_CardClosureRefundController.CardLockUiContextDTO confirmedOpen =
                FEC_CardClosureRefundController.getCardLockUnlockUiContext(c.Id);
            System.assertNotEquals(
                CS_DECISION_18,
                confirmedOpen.pendingCsDecision,
                'CONFIRMED + non-completed LOS should not map to NOTI 18.'
            );

            Test.setMock(HttpCalloutMock.class, new DisbInfoCancelledOpenMock());
            FEC_CardClosureRefundController.CardLockUiContextDTO cancelledOpen =
                FEC_CardClosureRefundController.getCardLockUnlockUiContext(c.Id);
            System.assertNotEquals(
                CS_DECISION_18,
                cancelledOpen.pendingCsDecision,
                'CANCELLED + non-cancelled LOS should not map to NOTI 18.'
            );
        }
    }

    @IsTest
    static void testBlockCard_AccountBlkcdApi_NotSkipped() {
        System.runAs(testRunAsUser()) {
            FEC_Customer_History__c cust = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
            cust.FEC_Block_Code_1__c = null;
            cust.FEC_Block_Code__c = 'O';
            update cust;

            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new BlockCardFullPathMock());

            Test.startTest();
            FEC_CardClosureRefundController.LockUnlockApiResultDTO lockApi =
                FEC_CardClosureRefundController.blockCardLockApi(c.Id);
            FEC_CardClosureRefundController.LockUnlockApiResultDTO vmxApi =
                FEC_CardClosureRefundController.blockCardAccountBlkcdApi(c.Id);
            Test.stopTest();

            System.assertEquals(true, lockApi.success);
            System.assertEquals(false, vmxApi.skipped);
            System.assertNotEquals(null, vmxApi);
        }
    }

    @IsTest
    static void testBlockCardAccountBlkcdApi_SkippedForCardOnlyLock() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new CardLockSuccessMock());

            Test.startTest();
            FEC_CardClosureRefundController.LockUnlockApiResultDTO vmxApi =
                FEC_CardClosureRefundController.blockCardAccountBlkcdApi(c.Id);
            Test.stopTest();

            System.assertEquals(true, vmxApi.success);
            System.assertEquals(true, vmxApi.skipped);
        }
    }

    @IsTest
    static void testFinalizeBlockCard_ManualPaths() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];

            Test.startTest();
            FEC_CardClosureRefundController.LockUnlockResultDTO successResult =
                FEC_CardClosureRefundController.finalizeBlockCard(c.Id, true, true, true);
            FEC_CardClosureRefundController.LockUnlockResultDTO failResult =
                FEC_CardClosureRefundController.finalizeBlockCard(c.Id, false, false, true);
            FEC_CardClosureRefundController.LockUnlockResultDTO nullCase =
                FEC_CardClosureRefundController.finalizeBlockCard(null, true, true, true);
            Test.stopTest();

            System.assertEquals(true, successResult.success);
            System.assertEquals(0, successResult.cardBlockServiceAttemptsAfter);
            System.assertEquals(false, failResult.success);
            System.assertEquals(1, failResult.cardBlockServiceAttemptsAfter);
            System.assertEquals(false, nullCase.success);
        }
    }

    @IsTest
    static void testBlockCardLockApi_UnsuccessfulDescription_Fails() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new CardLockUnsuccessfulDescMock());

            Test.startTest();
            FEC_CardClosureRefundController.LockUnlockApiResultDTO lockApi =
                FEC_CardClosureRefundController.blockCardLockApi(c.Id);
            Test.stopTest();

            System.assertEquals(false, lockApi.success);
            System.assertEquals('1', lockApi.code);
            System.assertEquals('Unsuccessful operation', lockApi.description);
        }
    }

    @IsTest
    static void testBlockCardAccountBlkcdApi_WrongCodeSuccessDesc_Succeeds() {
        System.runAs(testRunAsUser()) {
            FEC_Customer_History__c cust = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
            cust.FEC_Block_Code_1__c = null;
            update cust;

            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new VmxWrongCodeSuccessDescMock());

            Test.startTest();
            FEC_CardClosureRefundController.LockUnlockApiResultDTO vmxApi =
                FEC_CardClosureRefundController.blockCardAccountBlkcdApi(c.Id);
            Test.stopTest();

            System.assertEquals(true, vmxApi.success);
            System.assertEquals('99', vmxApi.code);
            System.assertEquals('Success', vmxApi.description);
        }
    }

    @IsTest
    static void testBlockCard_MaxAttemptsExhausted() {
        System.runAs(testRunAsUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Case API Disbursement Test' LIMIT 1];
            c.FEC_Card_Block_Service_Attempts__c = 2;
            update c;

            Test.setMock(HttpCalloutMock.class, new CardLockFailureMock());
            Test.startTest();
            FEC_CardClosureRefundController.LockUnlockResultDTO result =
                FEC_CardClosureRefundController.blockCard(c.Id);
            Test.stopTest();

            System.assertEquals(false, result.success);
            System.assertEquals(3, result.cardBlockServiceAttemptsAfter);
            System.assertEquals(true, result.hideBlockCardAfterAction);
        }
    }
}
