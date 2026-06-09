@IsTest
private class FEC_UpdateTransferInfoRestService_Test {

    private static void insertCase(Case c) {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static void setRestContext(String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/collections/v1/call-transfer';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
    }

    private static FEC_UpdateTransferInfoRestService.UpdateTransferInfoResponse parseResponse() {
        return (FEC_UpdateTransferInfoRestService.UpdateTransferInfoResponse) JSON.deserialize(
            RestContext.response.responseBody.toString(),
            FEC_UpdateTransferInfoRestService.UpdateTransferInfoResponse.class
        );
    }

    @TestSetup
    static void setupData() {
        insertCase(
            new Case(
                Subject = 'Test Transfer Info',
                FEC_ID_Search__c = 'S-12345'
            )
        );
    }

    @IsTest
    static void testDoPost_Success() {
        String jsonBody =
            '{' +
            '"Sys": {"TransID": "T1", "RequestorID": "Pega", "DateTime": "20260413T085557.495 GMT"},' +
            '"ServiceCaseID": "S-12345",' +
            '"RequestorID": "Pega",' +
            '"CollActionCode": "ACT001",' +
            '"CollSubActionCode": "SUB001",' +
            '"CollRemarks": "Test Remarks",' +
            '"CollOperator": "Agent01",' +
            '"CollActionDate": "20260413T085557.495 GMT"' +
            '}';

        setRestContext(jsonBody);

        Test.startTest();
        FEC_UpdateTransferInfoRestService.doPost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        FEC_UpdateTransferInfoRestService.UpdateTransferInfoResponse res = parseResponse();
        System.assertEquals(FEC_ConstantCommon.SUCCESS_MESSAGE, res.Status);

        Case updatedCase = [
            SELECT FEC_Coll_Action_Code__c, FEC_Coll_Remarks__c
            FROM Case
            WHERE FEC_ID_Search__c = 'S-12345'
        ];
        System.assertEquals('ACT001', updatedCase.FEC_Coll_Action_Code__c);
        System.assertEquals('Test Remarks', updatedCase.FEC_Coll_Remarks__c);
    }

    @IsTest
    static void testDoPost_CaseNotFound() {
        String jsonBody =
            '{' +
            '"ServiceCaseID": "NOT_EXIST",' +
            '"RequestorID": "Pega",' +
            '"CollActionCode": "ACT001"' +
            '}';

        setRestContext(jsonBody);

        Test.startTest();
        FEC_UpdateTransferInfoRestService.doPost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        FEC_UpdateTransferInfoRestService.UpdateTransferInfoResponse res = parseResponse();
        System.assertEquals(FEC_ConstantCommon.KEY_ERROR, res.Status);
        System.assert(
            res.Description.contains(FEC_ConstantCommon.UPDATE_TRANSFER_ERR_SERVICE_CASE_NOT_FOUND_PREFIX),
            'Description phải báo ServiceCaseID not found.'
        );
        System.assert(res.Description.contains('NOT_EXIST'));
    }

    @IsTest
    static void testDoPost_ValidationError() {
        String jsonBody = '{"ServiceCaseID": "S-12345", "RequestorID": "Pega"}';

        setRestContext(jsonBody);

        Test.startTest();
        FEC_UpdateTransferInfoRestService.doPost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        FEC_UpdateTransferInfoRestService.UpdateTransferInfoResponse res = parseResponse();
        System.assertEquals(FEC_ConstantCommon.KEY_ERROR, res.Status);
    }

    @IsTest
    static void testParsePegaDatetime() {
        String rawDate = '20260413T085557.495 GMT';

        Test.startTest();
        Datetime dt = FEC_UpdateTransferInfoRestService.parsePegaDatetime(rawDate);
        Test.stopTest();

        System.assertNotEquals(null, dt);
        System.assertEquals(2026, dt.year());
        System.assertEquals(4, dt.month());
    }
}
