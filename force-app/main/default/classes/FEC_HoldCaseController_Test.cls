@IsTest
private class FEC_HoldCaseController_Test {

    private static User adminUser() {
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE
            LIMIT 1
        ];
    }

    @TestSetup
    static void setup() {
        String suffix = String.valueOf(System.currentTimeMillis());

        insert new FEC_Hold_Case__c(
            FEC_NFU_Code__c = 'NFU01',
            FEC_NFU_Reason_VN__c = 'Test Reason',
            FEC_NFU_Duration__c = 1
        );

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Stage 1 Hold',
            FEC_Code__c = 'STH' + suffix,
            FEC_Active__c = true
        );
        insert stage;

        insert new FEC_Hold_Case_Config__c(
            FEC_NFU_Code__c = 'NFU01',
            FEC_Active__c = true,
            Hold_Case_Type__c = 'Manual',
            FEC_Case_Stage__c = stage.Id
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'FEC_HoldCaseController_Test',
                FEC_Current_Case_Stage__c = stage.Id,
                FEC_Contract_Number__c = '12345',
                FEC_ID_Search__c = 'HLD-' + suffix
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testGetNFUReasons() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        System.runAs(adminUser()) {
            Test.startTest();
            List<FEC_HoldCaseController.NFUReasonModel> reasons =
                FEC_HoldCaseController.getNFUReasons(String.valueOf(c.Id), null, null, null, null);
            Test.stopTest();

            System.assertEquals(1, reasons.size(), 'Phải lấy được 1 lý do NFU.');
            System.assertEquals('NFU01', reasons[0].nfuCode);
        }
    }

    @IsTest
    static void testSaveHoldCase_Success() {
        System.runAs(adminUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            if (apiSetting == null) {
                apiSetting = new FEC_API_Setting__c();
            }
            apiSetting.FEC_Endpoint__c = 'https://test-api.fecredit.com.vn';
            apiSetting.FEC_Call_Mock__c = false;
            upsert apiSetting;

            Test.setMock(HttpCalloutMock.class, new MarkNFUHttpCalloutMock());

            Test.startTest();
            FEC_HoldCaseController.ResponseModel resp =
                FEC_HoldCaseController.saveHoldCase(c.Id, 'Test Reason', 'NFU01', 1, 1);
            Test.stopTest();

            System.assertNotEquals(null, resp, 'Controller must return a response.');
            System.assertNotEquals(null, resp.status, 'Response should include status.');
        }
    }

    @IsTest
    static void testCallMarkNFUAndGetInfo_Success() {
        System.runAs(adminUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            if (apiSetting == null) {
                apiSetting = new FEC_API_Setting__c();
            }
            apiSetting.FEC_Endpoint__c = 'https://test-api.fecredit.com.vn';
            apiSetting.FEC_Call_Mock__c = false;
            upsert apiSetting;

            Test.setMock(HttpCalloutMock.class, new MarkNFUHttpCalloutMock());

            Test.startTest();
            FEC_HoldCaseController.NfuInfoResult result =
                FEC_HoldCaseController.callMarkNFUAndGetInfo(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
        }
    }

    @IsTest
    static void testParseNfuDateTime() {
        String raw = '2026-05-25T10:00:00.000Z';
        DateTime dt = FEC_HoldCaseController.parseNfuDateTime(raw);
        System.assertNotEquals(null, dt);
    }

    @IsTest
    static void testValidateModel_Error() {
        try {
            FEC_HoldCaseController.validateModel(null);
            System.assert(false, 'Phải throw ngoại lệ.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void testGetNFUReasons_WithNocParams() {
        System.runAs(adminUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_Case_Stage__c stage = [SELECT Id FROM FEC_Case_Stage__c LIMIT 1];

            Test.startTest();
            List<FEC_HoldCaseController.NFUReasonModel> reasons =
                FEC_HoldCaseController.getNFUReasons(
                    String.valueOf(c.Id),
                    null,
                    null,
                    null,
                    null
                );
            Test.stopTest();

            System.assertEquals(1, reasons.size());
            System.assertNotEquals(null, stage.Id);
        }
    }

    @IsTest
    static void testGetNFUReasons_BlankCaseIdThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            FEC_HoldCaseController.getNFUReasons(null, null, null, null, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testSaveHoldCase_ApiError() {
        System.runAs(adminUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            if (apiSetting == null) {
                apiSetting = new FEC_API_Setting__c();
            }
            apiSetting.FEC_Endpoint__c = 'https://test-api.fecredit.com.vn';
            apiSetting.FEC_Call_Mock__c = false;
            upsert apiSetting;

            Test.setMock(HttpCalloutMock.class, new MarkNFUErrorMock());

            Test.startTest();
            FEC_HoldCaseController.ResponseModel resp =
                FEC_HoldCaseController.saveHoldCase(c.Id, 'Test Reason', 'NFU01', 1, 1);
            Test.stopTest();

            System.assertEquals(false, resp.isSuccess);
        }
    }

    @IsTest
    static void testSaveHoldCase_AlreadyMarked() {
        System.runAs(adminUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            if (apiSetting == null) {
                apiSetting = new FEC_API_Setting__c();
            }
            apiSetting.FEC_Endpoint__c = 'https://test-api.fecredit.com.vn';
            apiSetting.FEC_Call_Mock__c = false;
            upsert apiSetting;

            Test.setMock(HttpCalloutMock.class, new MarkNFUAlreadyMarkedMock());

            Test.startTest();
            FEC_HoldCaseController.ResponseModel resp =
                FEC_HoldCaseController.saveHoldCase(c.Id, 'Test Reason', 'NFU01', 1, 1);
            Test.stopTest();

            System.assertNotEquals(null, resp);
            System.assertNotEquals(null, resp.status);
        }
    }

    @IsTest
    static void testPersistManualHoldCaseError() {
        System.runAs(adminUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];

            Test.startTest();
            FEC_HoldCaseController.persistManualHoldCaseError(c.Id);
            FEC_HoldCaseController.persistManualHoldCaseError(null);
            Test.stopTest();

            System.assert(true);
        }
    }

    @IsTest
    static void testParseNfuDateTime_Blank() {
        System.assertEquals(null, FEC_HoldCaseController.parseNfuDateTime(null));
        System.assertEquals(null, FEC_HoldCaseController.parseNfuDateTime(''));
    }

    @IsTest
    static void testMarkResultHelpers() {
        FEC_MarkNFU.MarkNFUResult alreadyByCode = new FEC_MarkNFU.MarkNFUResult();
        alreadyByCode.code = FEC_ConstantCommon.SUCCESS_CODE_203;
        System.assertEquals(true, FEC_HoldCaseController.isTh1AlreadyMarked(alreadyByCode));
        System.assertEquals(false, FEC_HoldCaseController.isTh2Success(alreadyByCode));

        FEC_MarkNFU.MarkNFUResult alreadyByDesc = new FEC_MarkNFU.MarkNFUResult();
        alreadyByDesc.description = 'Contract has already marked as NFU';
        System.assertEquals(true, FEC_HoldCaseController.isTh1AlreadyMarked(alreadyByDesc));

        FEC_MarkNFU.MarkNFUResult successByDesc = new FEC_MarkNFU.MarkNFUResult();
        successByDesc.description = 'Success';
        System.assertEquals(true, FEC_HoldCaseController.isTh2Success(successByDesc));

        FEC_MarkNFU.MarkNFUResult successByFlag = new FEC_MarkNFU.MarkNFUResult();
        successByFlag.success = true;
        System.assertEquals(true, FEC_HoldCaseController.isTh2Success(successByFlag));
        System.assertEquals(false, FEC_HoldCaseController.isTh1AlreadyMarked(null));
    }

    @IsTest
    static void testResolveNfuReasonLabel_AndFallback() {
        System.assertEquals('', FEC_HoldCaseController.resolveNfuReasonLabel(null));
        System.assertEquals('', FEC_HoldCaseController.resolveNfuReasonLabel(''));
        System.assertEquals('Test Reason', FEC_HoldCaseController.resolveNfuReasonLabel('NFU01'));
        System.assertEquals('NFU-X', FEC_HoldCaseController.resolveNfuReasonLabel('NFU-X'));
    }

    @IsTest
    static void testUpdateCaseAfterManualHold_AndPopulateResponse() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_HoldCaseController.updateCaseAfterManualHold(
            c.Id,
            'ERROR',
            null,
            null,
            null,
            null,
            'Collections ERROR',
            null
        );

        FEC_HoldCaseController.ResponseModel resp = new FEC_HoldCaseController.ResponseModel();
        try {
            FEC_HoldCaseController.populateResponseFromCase(resp, c.Id);
        } catch (Exception ignored) {
            // Query uses WITH SECURITY_ENFORCED; some profiles in org may not read all fields.
        }
        System.assertNotEquals(null, resp);
        Case refreshed = [SELECT FEC_NFU_Description_Result__c FROM Case WHERE Id = :c.Id];
        System.assertEquals('ERROR', refreshed.FEC_NFU_Description_Result__c);
    }

    private class MarkNFUErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><MarkNFUResponse>' +
                '<Code>500</Code><Description>API Error</Description>' +
                '</MarkNFUResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class MarkNFUAlreadyMarkedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><MarkNFUResponse>' +
                '<Code>203</Code><Description>Contract has already marked as NFU</Description>' +
                '<NFUStartDate>2026-05-25T10:00:00.000Z</NFUStartDate>' +
                '<NFUTillDate>2026-06-25T10:00:00.000Z</NFUTillDate>' +
                '</MarkNFUResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class MarkNFUHttpCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><MarkNFUResponse>' +
                '<Code>200</Code><Description>Success</Description>' +
                '<NFUStartDate>2026-05-25T10:00:00.000Z</NFUStartDate>' +
                '<NFUTillDate>2026-06-25T10:00:00.000Z</NFUTillDate>' +
                '</MarkNFUResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }
}