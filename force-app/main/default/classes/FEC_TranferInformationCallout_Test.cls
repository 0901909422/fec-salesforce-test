@IsTest
private class FEC_TranferInformationCallout_Test {

    private static User adminUser() {
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE
            LIMIT 1
        ];
    }

    private static void ensureApiSettings() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Endpoint__c = 'https://mock-api.fecredit.com.vn';
        apiSetting.FEC_Call_Mock__c = false;
        apiSetting.FEC_Enviroment__c = 'Production';
        upsert apiSetting;
    }

    private static FEC_TranferInformationCallout.TransferCallInput buildValidTransferInput() {
        FEC_TranferInformationCallout.TransferCallInput req =
            new FEC_TranferInformationCallout.TransferCallInput();
        req.genesysId = 'GEN-123';
        req.requestorId = FEC_ConstantCommon.TRANSFER_CALL_REQUESTOR_ID_CSM;
        req.callData = new Map<String, String>{
            'productType' => 'CARD',
            'extAppId' => 'APP123456',
            'phoneNumber' => '0901234567',
            'category' => 'Request',
            'subCategory' => 'RC01',
            'subCode' => 'RC01.01',
            'remark' => 'Transfer remark',
            'csCaseID' => 'TRF0001'
        };
        return req;
    }

    @TestSetup
    static void setupData() {
        ensureApiSettings();

        String suffix = String.valueOf(System.currentTimeMillis()).right(6);
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Card',
            FEC_Code__c = 'C' + suffix,
            FEC_Active__c = true
        );
        insert pt;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Request',
            FEC_Code__c = 'R' + suffix,
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'RC01',
            FEC_Code__c = 'SC' + suffix,
            FEC_Active__c = true
        );
        insert subCat;
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'RC01.01',
            FEC_Code__c = 'CD' + suffix,
            FEC_Active__c = true
        );
        insert subCode;

        FEC_Nature_of_Case__c templateNoc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true
        );
        insert templateNoc;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Transfer Stage',
            FEC_Code__c = 'STG' + suffix,
            FEC_Nature_of_Cases__c = templateNoc.Id,
            FEC_Active__c = true
        );
        insert stage;

        Case c = new Case(
            Subject = 'Test Transfer Call',
            FEC_Is_Submited__c = false,
            FEC_External_Interaction_ID__c = 'GEN-123',
            FEC_Remark_for_Collections__c = 'Remark before transfer',
            FEC_ID_Search__c = 'TRF' + suffix,
            FEC_Phone_Number__c = '0901234567',
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_SubCategory__c = subCat.Id,
            FEC_SubCode__c = subCode.Id,
            FEC_Current_Case_Stage__c = stage.Id
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Contract_Number__c = 'APP123456'
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = [
                    SELECT Id
                    FROM FEC_Customer_History__c
                    WHERE FEC_Case__c = :c.Id
                    LIMIT 1
                ]
                .Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Transfer_Call_Error__c(
            FEC_Error_Message_EN__c = 'Connection error',
            FEC_Error_Message_VI__c = 'Lỗi kết nối'
        );
    }

    private class TransferCallSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"Code": "1", "ResultOfClass": "Success", "Reason": "OK", ' +
                '"TransID": "T123", "ActionDate": "2026-04-21T08:13:36.000Z"}'
            );
            return res;
        }
    }

    private class TransferCallFailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"Code": "E", "Reason": "Pega Error", "ResultOfClass": "Failed"}'
            );
            return res;
        }
    }

    private class TransferCallHttpErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"message":"Internal server error"}');
            return res;
        }
    }

    private class TransferCallErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('API Timeout');
        }
    }

    @IsTest
    static void testTransferCall_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new TransferCallSuccessMock());

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TranferInformationCallout.TransferCallResponse res =
                FEC_TranferInformationCallout.transferCallFromCase(c.Id, 'Valid Remark');
            Test.stopTest();

            System.assertEquals(true, res.success);
            Case updatedC = [
                SELECT FEC_Transfer_Status__c, FEC_Transfer_Data_to_Collections__c
                FROM Case
                WHERE Id = :c.Id
            ];
            System.assertEquals('Success', updatedC.FEC_Transfer_Status__c);
            System.assertEquals('Yes', updatedC.FEC_Transfer_Data_to_Collections__c);
        }
    }

    @IsTest
    static void testTransferCall_FailureUpdatesCase() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new TransferCallFailMock());

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TranferInformationCallout.TransferCallResponse res =
                FEC_TranferInformationCallout.transferCallFromCase(c.Id, 'Failed transfer');
            Test.stopTest();

            System.assertEquals(false, res.success);
            Case updatedC = [
                SELECT FEC_Transfer_Status__c, FEC_Failure_Reason__c
                FROM Case
                WHERE Id = :c.Id
            ];
            System.assertEquals('Failure', updatedC.FEC_Transfer_Status__c);
            System.assertNotEquals(null, updatedC.FEC_Failure_Reason__c);
        }
    }

    @IsTest
    static void testValidation_MissingData() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TranferInformationCallout.TransferCallResponse res =
                FEC_TranferInformationCallout.transferCallFromCase(c.Id, '');
            Test.stopTest();

            System.assertEquals(false, res.success);
        }
    }

    @IsTest
    static void testTransferCallFromCase_Guards() {
        System.runAs(adminUser()) {
            Test.startTest();

            FEC_TranferInformationCallout.TransferCallResponse nullCase =
                FEC_TranferInformationCallout.transferCallFromCase(null, 'Remark');
            System.assertEquals(false, nullCase.success);

            Id fakeCaseId =
                Case.SObjectType.getDescribe().getKeyPrefix() + '000000000001';
            FEC_TranferInformationCallout.TransferCallResponse missingCase =
                FEC_TranferInformationCallout.transferCallFromCase(fakeCaseId, 'Remark');
            System.assertEquals(false, missingCase.success);

            Case submitted = [SELECT Id FROM Case LIMIT 1];
            submitted.FEC_Is_Submited__c = true;
            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                update submitted;
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }

            FEC_TranferInformationCallout.TransferCallResponse readonlyRes =
                FEC_TranferInformationCallout.transferCallFromCase(
                    submitted.Id,
                    'Remark'
                );
            System.assertEquals(false, readonlyRes.success);

            Test.stopTest();
        }
    }

    @IsTest
    static void testGetCaseCallData() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        System.runAs(adminUser()) {
            Test.startTest();
            System.assertEquals(null, FEC_TranferInformationCallout.getCaseCallData(null));

            FEC_TranferInformationCallout.CaseCallData data =
                FEC_TranferInformationCallout.getCaseCallData(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, data);
            System.assertEquals('GEN-123', data.genesysId);
            Case row = [SELECT FEC_ID_Search__c FROM Case WHERE Id = :c.Id];
            System.assertEquals(row.FEC_ID_Search__c, data.csCaseID);
        }
    }

    @IsTest
    static void testGetCaseCallData_PhoneAndGenesysFallbacks() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);
        Case parent = new Case(
            Subject = 'Parent Interaction',
            FEC_External_Interaction_ID__c = 'GEN-PARENT',
            FEC_Phone_Number__c = '0912345678',
            FEC_ID_Search__c = 'PAR' + suffix
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert parent;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Case child = new Case(
            Subject = 'Child Case',
            FEC_Is_Submited__c = false,
            FEC_Interaction__c = parent.Id,
            FEC_Case_Phone_Number__c = '0987654321',
            FEC_ID_Search__c = 'CHD' + suffix,
            FEC_Product_Type__c = [SELECT Id FROM FEC_Product_Type__c LIMIT 1].Id,
            FEC_Category__c = [SELECT Id FROM FEC_Category__c LIMIT 1].Id,
            FEC_SubCategory__c = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1].Id,
            FEC_SubCode__c = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1].Id
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert child;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TranferInformationCallout.CaseCallData data =
                FEC_TranferInformationCallout.getCaseCallData(child.Id);
            Test.stopTest();

            System.assertEquals('GEN-PARENT', data.genesysId);
            System.assertEquals('0912345678', data.phoneNumber);
        }
    }

    @IsTest
    static void testEnsureCaseNocFromStageTemplate() {
        FEC_Product_Type__c pt = [SELECT Id FROM FEC_Product_Type__c LIMIT 1];
        FEC_Category__c cat = [SELECT Id FROM FEC_Category__c LIMIT 1];
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];
        FEC_Sub_Code__c subCode = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1];
        FEC_Nature_of_Case__c templateNoc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true
        );
        insert templateNoc;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'NOC Sync Stage',
            FEC_Code__c = 'SNC' + String.valueOf(System.currentTimeMillis()).right(5),
            FEC_Nature_of_Cases__c = templateNoc.Id,
            FEC_Active__c = true
        );
        insert stage;

        Case bareCase = new Case(
            Subject = 'Bare NOC Case',
            FEC_Is_Submited__c = false,
            FEC_Current_Case_Stage__c = stage.Id,
            FEC_ID_Search__c = 'NOC' + String.valueOf(System.currentTimeMillis()).right(6)
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert bareCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TranferInformationCallout.prepareRemarkForCollectionsTransfer(bareCase.Id);
            Test.stopTest();

            Case synced = [
                SELECT FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c
                FROM Case
                WHERE Id = :bareCase.Id
            ];
            System.assertEquals(pt.Id, synced.FEC_Product_Type__c);
            System.assertEquals(cat.Id, synced.FEC_Category__c);
            System.assertEquals(subCat.Id, synced.FEC_SubCategory__c);
        }
    }

    @IsTest
    static void testParseResponse_Variants() {
        Test.startTest();

        FEC_TranferInformationCallout.TransferCallResponse emptyRes =
            FEC_TranferInformationCallout.parseResponse(null, 200);
        System.assertEquals(false, emptyRes.success);

        FEC_TranferInformationCallout.TransferCallResponse successY =
            FEC_TranferInformationCallout.parseResponse('{"Code":"Y"}', 200);
        System.assertEquals(true, successY.success);

        FEC_TranferInformationCallout.TransferCallResponse successText =
            FEC_TranferInformationCallout.parseResponse('{"Code":"Success"}', 200);
        System.assertEquals(true, successText.success);

        FEC_TranferInformationCallout.TransferCallResponse apiError =
            FEC_TranferInformationCallout.parseResponse(
                '{"Code": "E", "Reason": "Pega Error", "ResultOfClass": "Failed"}',
                200
            );
        System.assertEquals(false, apiError.success);
        System.assertEquals('Pega Error', apiError.errorMessage);

        FEC_TranferInformationCallout.TransferCallResponse httpError =
            FEC_TranferInformationCallout.parseResponse(
                '{"errors":[{"message":"Collections unavailable"}]}',
                500
            );
        System.assertEquals(false, httpError.success);
        System.assertNotEquals(null, httpError.errorMessage);

        FEC_TranferInformationCallout.TransferCallResponse parseFail =
            FEC_TranferInformationCallout.parseResponse('not-json-body', 200);
        System.assertEquals(false, parseFail.success);

        FEC_TranferInformationCallout.TransferCallResponse hintOnly =
            FEC_TranferInformationCallout.parseResponse(
                '{"errorMessage":"Direct API failure"}',
                400
            );
        System.assertEquals(false, hintOnly.success);

        Test.stopTest();
    }

    @IsTest
    static void testHelperMethods() {
        insert new FEC_Transfer_Call_Error__c(
            FEC_Error_Message_EN__c = 'productType is invalid',
            FEC_Error_Message_VI__c = 'Loại sản phẩm không hợp lệ'
        );

        System.assertEquals(
            'Lỗi kết nối',
            FEC_TranferInformationCallout.resolveTransferCallErrorMessageVi('Connection error')
        );
        System.assertEquals(
            '',
            FEC_TranferInformationCallout.resolveTransferCallErrorMessageVi('')
        );
        System.assertEquals(
            'Unknown EN',
            FEC_TranferInformationCallout.resolveTransferCallErrorMessageVi('Unknown EN')
        );

        System.assertNotEquals(
            null,
            FEC_TranferInformationCallout.parseCollActionDatetime('2026-04-21T08:13:36.000Z')
        );
        System.assertNotEquals(
            null,
            FEC_TranferInformationCallout.parseCollActionDatetime('21/04/2026 08:13:36')
        );
        System.assertEquals(
            null,
            FEC_TranferInformationCallout.parseCollActionDatetime('invalid-date')
        );
    }

    @IsTest
    static void testNocSyncLogic() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TranferInformationCallout.prepareRemarkForCollectionsTransfer(null);
            FEC_TranferInformationCallout.prepareRemarkForCollectionsTransfer(c.Id);
            Test.stopTest();

            Case updatedC = [
                SELECT FEC_Remark_for_Collections__c
                FROM Case
                WHERE Id = :c.Id
            ];
            System.assertEquals(null, updatedC.FEC_Remark_for_Collections__c);
        }
    }

    @IsTest
    static void testPrepareRemark_SubmittedCaseNoOp() {
        Case c = [SELECT Id, FEC_Remark_for_Collections__c FROM Case LIMIT 1];
        c.FEC_Is_Submited__c = true;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TranferInformationCallout.prepareRemarkForCollectionsTransfer(c.Id);
            Test.stopTest();

            Case after = [
                SELECT FEC_Remark_for_Collections__c
                FROM Case
                WHERE Id = :c.Id
            ];
            System.assertNotEquals(null, after.FEC_Remark_for_Collections__c);
        }
    }

    @IsTest
    static void testTransferCallByCase() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new TransferCallSuccessMock());

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TranferInformationCallout.TransferCallResponse res =
                FEC_TranferInformationCallout.transferCallByCase(
                    c.Id,
                    'GEN-123',
                    FEC_ConstantCommon.TRANSFER_CALL_REQUESTOR_ID_CSM,
                    'By case remark'
                );
            Test.stopTest();

            System.assertEquals(true, res.success);
        }
    }

    @IsTest
    static void testTransferCall_DirectAndBuildBody() {
        Test.setMock(HttpCalloutMock.class, new TransferCallSuccessMock());
        FEC_TranferInformationCallout.TransferCallInput req = buildValidTransferInput();

        Test.startTest();
        String bodyJson = FEC_TranferInformationCallout.buildRequestBodyJson(req);
        FEC_TranferInformationCallout.TransferCallResponse res =
            FEC_TranferInformationCallout.transferCall(req);
        Test.stopTest();

        System.assert(bodyJson.contains('GEN-123'));
        System.assertEquals(true, res.success);
        System.assertNotEquals(null, FEC_TranferInformationCallout.responseLog);
    }

    @IsTest
    static void testSendRequest_HttpError() {
        Test.setMock(HttpCalloutMock.class, new TransferCallHttpErrorMock());

        Test.startTest();
        HttpResponse res = FEC_TranferInformationCallout.sendRequest(
            'https://mock-api.fecredit.com.vn/transfer',
            '{"genesysId":"GEN-123"}',
            FEC_CommonUltils.generateTransactionUUID(),
            FEC_ConstantCommon.TRANSFER_CALL_REQUESTOR_ID_CSM,
            Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT)
        );
        Test.stopTest();

        System.assertEquals(500, res.getStatusCode());
        System.assert(res.getBody().contains('Internal server error'));
    }

    @IsTest
    static void testValidate_RequiredFields() {
        Map<String, String> base = buildValidTransferInput().callData;

        assertValidationFails(buildInputWithBlankGenesysId());
        assertValidationFails(buildInputWithBlankRequestorId());
        assertValidationFails(inputWithoutCallData());
        assertValidationFails(buildInputWithData(base, 'phoneNumber', ''));
        assertValidationFails(buildInputWithData(base, 'phoneNumber', '12'));
        assertValidationFails(buildInputWithData(base, 'csCaseID', ''));
        assertValidationFails(buildInputWithData(base, 'extAppId', ''));
        assertValidationFails(buildInputWithData(base, 'productType', ''));
        assertValidationFails(buildInputWithData(base, 'productType', '@@@'));
        assertValidationFails(buildInputWithData(base, 'category', ''));
        assertValidationFails(buildInputWithData(base, 'subCategory', ''));
        assertValidationFails(buildInputWithData(base, 'subCode', ''));
        assertValidationFails(buildInputWithData(base, 'remark', ''));
    }

    @IsTest
    static void testEnsureCaseNocFromActualNature() {
        FEC_Product_Type__c pt = [SELECT Id FROM FEC_Product_Type__c LIMIT 1];
        FEC_Category__c cat = [SELECT Id FROM FEC_Category__c LIMIT 1];
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];
        FEC_Sub_Code__c subCode = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1];

        FEC_Actual_Nature_of_Case__c actualNoc = new FEC_Actual_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id
        );
        insert actualNoc;

        Case bareCase = new Case(
            Subject = 'Actual NOC Case',
            FEC_Is_Submited__c = false,
            FEC_Actual_Nature_of_Case__c = actualNoc.Id,
            FEC_ID_Search__c = 'ACT' + String.valueOf(System.currentTimeMillis()).right(6)
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert bareCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TranferInformationCallout.CaseCallData data =
                FEC_TranferInformationCallout.getCaseCallData(bareCase.Id);
            Test.stopTest();

            System.assertNotEquals(null, data);
            System.assertEquals('Card', data.productType);
            Case synced = [
                SELECT FEC_Product_Type__c, FEC_Category__c
                FROM Case
                WHERE Id = :bareCase.Id
            ];
            System.assertEquals(pt.Id, synced.FEC_Product_Type__c);
            System.assertEquals(cat.Id, synced.FEC_Category__c);
        }
    }

    @IsTest
    static void testGetCaseCallData_CasePhoneOnly() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);
        Case c = new Case(
            Subject = 'Phone fallback case',
            FEC_Is_Submited__c = false,
            FEC_Case_Phone_Number__c = '0987654321',
            FEC_ID_Search__c = 'PHN' + suffix,
            FEC_Product_Type__c = [SELECT Id FROM FEC_Product_Type__c LIMIT 1].Id,
            FEC_Category__c = [SELECT Id FROM FEC_Category__c LIMIT 1].Id,
            FEC_SubCategory__c = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1].Id,
            FEC_SubCode__c = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1].Id
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TranferInformationCallout.CaseCallData data =
                FEC_TranferInformationCallout.getCaseCallData(c.Id);
            Test.stopTest();

            System.assertEquals('0987654321', data.phoneNumber);
        }
    }

    @IsTest
    static void testTransferCall_CalloutException() {
        Test.setMock(HttpCalloutMock.class, new TransferCallErrorMock());
        FEC_TranferInformationCallout.TransferCallInput req = buildValidTransferInput();

        Test.startTest();
        FEC_TranferInformationCallout.TransferCallResponse res =
            FEC_TranferInformationCallout.transferCall(req);
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertNotEquals(null, res.errorMessage);
    }

    private static FEC_TranferInformationCallout.TransferCallInput inputWithoutCallData() {
        FEC_TranferInformationCallout.TransferCallInput req = buildValidTransferInput();
        req.callData = null;
        return req;
    }

    private static FEC_TranferInformationCallout.TransferCallInput buildInputWithBlankGenesysId() {
        FEC_TranferInformationCallout.TransferCallInput req = buildValidTransferInput();
        req.genesysId = '';
        return req;
    }

    private static FEC_TranferInformationCallout.TransferCallInput buildInputWithBlankRequestorId() {
        FEC_TranferInformationCallout.TransferCallInput req = buildValidTransferInput();
        req.requestorId = '';
        return req;
    }

    private static FEC_TranferInformationCallout.TransferCallInput buildInputWithData(
        Map<String, String> base,
        String fieldKey,
        String fieldValue
    ) {
        FEC_TranferInformationCallout.TransferCallInput req = buildValidTransferInput();
        Map<String, String> data = new Map<String, String>(base);
        data.put(fieldKey, fieldValue);
        req.callData = data;
        return req;
    }

    private static void assertValidationFails(
        FEC_TranferInformationCallout.TransferCallInput req
    ) {
        Boolean threw = false;
        try {
            FEC_TranferInformationCallout.transferCall(req);
        } catch (Exception ex) {
            threw = true;
            System.assert(
                ex instanceof FEC_APIServiceException ||
                    ex.getMessage() != null
            );
        }
        System.assertEquals(true, threw, 'Validation must throw for invalid transfer input.');
    }
}
