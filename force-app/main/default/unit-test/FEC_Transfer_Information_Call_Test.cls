/**
 * Unit tests for FEC_Transfer_Information_Call (Transfer Information API wrapper).
 */
@IsTest
private class FEC_Transfer_Information_Call_Test {

    private static User adminUser() {
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE
            LIMIT 1
        ];
    }

    private static FEC_Transfer_Information_Call.TransferInformationInput buildValidInput() {
        FEC_Transfer_Information_Call.TransferInformationInput req =
            new FEC_Transfer_Information_Call.TransferInformationInput();
        req.genesysId = 'GEN-TIC-001';
        req.requestorId = FEC_ConstantCommon.TRANSFER_CALL_REQUESTOR_ID_CSM;
        req.callData = new Map<String, String>{
            'productType' => 'CARD',
            'extAppId' => 'APP987654',
            'phoneNumber' => '0909876543',
            'category' => 'Request',
            'subCategory' => 'RC02',
            'subCode' => 'RC02.01',
            'remark' => 'Transfer information remark',
            'csCaseID' => 'TIC0001'
        };
        return req;
    }

    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Endpoint__c = 'https://mock-api.fecredit.com.vn';
        apiSetting.FEC_Call_Mock__c = false;
        upsert apiSetting;

        String suffix = String.valueOf(System.currentTimeMillis()).right(6);
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Card',
            FEC_Code__c = 'PT' + suffix,
            FEC_Active__c = true
        );
        insert pt;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Request',
            FEC_Code__c = 'CA' + suffix,
            FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'RC02',
            FEC_Code__c = 'SC' + suffix,
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'RC02.01',
            FEC_Code__c = 'SX' + suffix,
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
            Name = 'TIC Stage',
            FEC_Code__c = 'STG' + suffix,
            FEC_Nature_of_Cases__c = templateNoc.Id,
            FEC_Active__c = true
        );
        insert stage;

        Case c = new Case(
            Subject = 'Transfer Information Call Test',
            FEC_External_Interaction_ID__c = 'GEN-TIC-001',
            FEC_ID_Search__c = 'TIC' + suffix,
            FEC_Phone_Number__c = '0909876543',
            FEC_Remark_for_Collections__c = 'Case remark',
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_SubCategory__c = subCat.Id,
            FEC_SubCode__c = subCode.Id,
            FEC_Current_Case_Stage__c = stage.Id,
            FEC_Is_Submited__c = false
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Contract_Number__c = 'APP987654'
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
    }

    private class TransferSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"Code":"1","ResultOfClass":"Success","Reason":"OK","TransID":"TIC-TRANS-1"}'
            );
            return res;
        }
    }

    private class TransferFailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"Code":"E","Reason":"Pega error","ResultOfClass":"Failed"}');
            return res;
        }
    }

    private class TransferCalloutExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Transfer API timeout');
        }
    }

    @IsTest
    static void testFormatHeaderDateTime() {
        String fromGmt = FEC_Transfer_Information_Call.formatHeaderDateTime(
            Datetime.newInstanceGmt(2025, 10, 27, 7, 20, 8)
        );
        System.assertEquals('20251027T072008.000 GMT', fromGmt);

        String fromNull = FEC_Transfer_Information_Call.formatHeaderDateTime(null);
        System.assert(fromNull.endsWith(' GMT'), 'Formatted datetime must end with GMT.');
        System.assert(fromNull.contains('T'), 'Formatted datetime must contain T separator.');
    }

    @IsTest
    static void testBuildRequestPayload_Structure() {
        FEC_Transfer_Information_Call.TransferInformationInput input = buildValidInput();
        String payload = FEC_Transfer_Information_Call.buildRequestPayload(
            input,
            'TRANS-001',
            '20251027T072008.000 GMT'
        );

        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(payload);
        Map<String, Object> headers = (Map<String, Object>) root.get('headers');
        Map<String, Object> body = (Map<String, Object>) root.get('body');

        System.assertEquals('TRANS-001', headers.get('TransID'));
        System.assertEquals('20251027T072008.000 GMT', headers.get('DateTime'));
        System.assertEquals(input.requestorId, headers.get('RequestorID'));
        System.assertEquals('GEN-TIC-001', body.get('genesysId'));
        System.assertEquals('TIC0001', body.get('csCaseID'));

        List<Object> dataRows = (List<Object>) body.get('data');
        System.assertEquals(7, dataRows.size(), 'Payload must include ordered data fields.');
        Map<String, Object> firstRow = (Map<String, Object>) dataRows[0];
        System.assertEquals('productType', firstRow.get('fieldKey'));
        System.assertEquals('CARD', firstRow.get('fieldValue'));
    }

    @IsTest
    static void testTransferCall_Success() {
        Test.setMock(HttpCalloutMock.class, new TransferSuccessMock());

        Test.startTest();
        FEC_TranferInformationCallout.TransferCallResponse res =
            FEC_Transfer_Information_Call.transferCall(buildValidInput());
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals(200, res.httpStatus);
        System.assertNotEquals(null, FEC_Transfer_Information_Call.responseLog);
        System.assertEquals(
            'FEC_Transfer_Information_Call',
            FEC_Transfer_Information_Call.responseLog.apiName
        );
    }

    @IsTest
    static void testTransferCall_ApiReturnsError() {
        Test.setMock(HttpCalloutMock.class, new TransferFailMock());

        Test.startTest();
        FEC_TranferInformationCallout.TransferCallResponse res =
            FEC_Transfer_Information_Call.transferCall(buildValidInput());
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertEquals('E', res.Code);
    }

    @IsTest
    static void testTransferCall_CalloutException() {
        Test.setMock(HttpCalloutMock.class, new TransferCalloutExceptionMock());

        Test.startTest();
        FEC_TranferInformationCallout.TransferCallResponse res =
            FEC_Transfer_Information_Call.transferCall(buildValidInput());
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertEquals(FEC_ConstantCommon.SUCCESS_CODE_E, res.Code);
        System.assert(res.errorMessage.contains('Transfer API timeout'));
    }

    @IsTest
    static void testTransferCall_ValidationErrors() {
        FEC_Transfer_Information_Call.TransferInformationInput blankGenesys =
            buildValidInput();
        blankGenesys.genesysId = '';

        try {
            FEC_Transfer_Information_Call.transferCall(blankGenesys);
            System.assert(false, 'Blank Genesys ID must throw.');
        } catch (FEC_APIServiceException ex) {
            System.assert(true);
        }

        FEC_Transfer_Information_Call.TransferInformationInput blankRequestor =
            buildValidInput();
        blankRequestor.requestorId = '';

        try {
            FEC_Transfer_Information_Call.transferCall(blankRequestor);
            System.assert(false, 'Blank Requestor ID must throw.');
        } catch (FEC_APIServiceException ex) {
            System.assert(true);
        }

        FEC_Transfer_Information_Call.TransferInformationInput noCallData =
            buildValidInput();
        noCallData.callData = null;

        try {
            FEC_Transfer_Information_Call.transferCall(noCallData);
            System.assert(false, 'Missing call data must throw.');
        } catch (FEC_APIServiceException ex) {
            System.assert(true);
        }

        FEC_Transfer_Information_Call.TransferInformationInput missingPhone =
            buildValidInput();
        missingPhone.callData.put('phoneNumber', '');

        try {
            FEC_Transfer_Information_Call.transferCall(missingPhone);
            System.assert(false, 'Blank phone number must throw.');
        } catch (FEC_APIServiceException ex) {
            System.assert(true);
        }
    }

    @IsTest
    static void testTransferCallByCase_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new TransferSuccessMock());

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_TranferInformationCallout.TransferCallResponse res =
                FEC_Transfer_Information_Call.transferCallByCase(
                    c.Id,
                    'GEN-TIC-001',
                    FEC_ConstantCommon.TRANSFER_CALL_REQUESTOR_ID_CSM
                );
            Test.stopTest();

            System.assertEquals(true, res.success);
            System.assertEquals(200, res.httpStatus);
        }
    }

    @IsTest
    static void testTransferCallByCase_NullCaseId() {
        Test.setMock(HttpCalloutMock.class, new TransferSuccessMock());

        Test.startTest();
        FEC_TranferInformationCallout.TransferCallResponse res =
            FEC_Transfer_Information_Call.transferCallByCase(
                null,
                'GEN-TIC-001',
                FEC_ConstantCommon.TRANSFER_CALL_REQUESTOR_ID_CSM
            );
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertEquals(FEC_ConstantCommon.SUCCESS_CODE_E, res.Code);
        System.assertNotEquals(null, res.errorMessage);
    }
}
