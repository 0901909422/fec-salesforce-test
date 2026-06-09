@IsTest
private class FEC_UpdateDisbStatusRestService_Test {

    private static void insertCase(Case c) {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static void updateCase(Case c) {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static void setRestContext(String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UpdateServiceCases/v1/Update_Disbursement_Status';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
    }

    private static String responseCode() {
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        return (String) body.get('Code');
    }

    @TestSetup
    static void setupData() {
        insertCase(
            new Case(
                Subject = 'Test Disbursement',
                FEC_ID_Search__c = 'CRM12345',
                Status = 'New'
            )
        );
    }

    @IsTest
    static void testDoPost_Success() {
        String jsonBody =
            '{' +
            '"Sys": {' +
            '"TransID": "T123",' +
            '"RequestorID": "CRM",' +
            '"DateTime": "2026-05-27T10:00:00Z"' +
            '},' +
            '"CRMID": "CRM12345",' +
            '"DISB_STATUS": "Withdrawn",' +
            '"DISB_DT": "2026-05-27",' +
            '"DESC": "Test Remarks"' +
            '}';

        setRestContext(jsonBody);

        Test.startTest();
        FEC_UpdateDisbursementStatusRestService.doPost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('200', responseCode());

        Case updatedCase = [
            SELECT Status, FEC_Disbursement_Status__c, FEC_Remarks__c
            FROM Case
            WHERE FEC_ID_Search__c = 'CRM12345'
        ];
        System.assertEquals(
            FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            updatedCase.Status
        );
        System.assertEquals('Test Remarks', updatedCase.FEC_Remarks__c);
    }

    @IsTest
    static void testDoPost_ValidationFailed() {
        String jsonBody =
            '{' +
            '"Sys": {"TransID": "T123", "RequestorID": "CRM", "DateTime": "2026-05-27T10:00:00Z"},' +
            '"CRMID": "CRM12345"' +
            '}';

        setRestContext(jsonBody);

        Test.startTest();
        FEC_UpdateDisbursementStatusRestService.doPost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void testDoPost_CaseNotFound() {
        String jsonBody =
            '{' +
            '"Sys": {"TransID": "T123", "RequestorID": "CRM", "DateTime": "2026-05-27T10:00:00Z"},' +
            '"CRMID": "NOT_EXIST",' +
            '"DISB_STATUS": "Withdrawn",' +
            '"DISB_DT": "2026-05-27"' +
            '}';

        setRestContext(jsonBody);

        Test.startTest();
        FEC_UpdateDisbursementStatusRestService.doPost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('105', responseCode());
    }

    @IsTest
    static void testDoPost_AlreadyResolved() {
        insertCase(
            new Case(
                Subject = 'Closed',
                FEC_ID_Search__c = 'CRM999',
                Status = 'New'
            )
        );
        updateCase(
            new Case(
                Id = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'CRM999' LIMIT 1].Id,
                Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED
            )
        );

        String jsonBody =
            '{' +
            '"Sys": {"TransID": "T123", "RequestorID": "CRM", "DateTime": "2026-05-27T10:00:00Z"},' +
            '"CRMID": "CRM999",' +
            '"DISB_STATUS": "Withdrawn",' +
            '"DISB_DT": "2026-05-27"' +
            '}';

        setRestContext(jsonBody);

        Test.startTest();
        FEC_UpdateDisbursementStatusRestService.doPost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('201', responseCode(), 'Phải trả về lỗi 201 (Business Error).');
    }
}
