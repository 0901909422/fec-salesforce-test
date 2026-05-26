/*------------------------------------------------------------
Author:        DuanNguyen 
Description:   Test class for FEC_UndeliveredCardRestService
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/05/20     DuanNguyen          Init
------------------------------------------------------------*/
@isTest
private class FEC_UndeliveredCardRestService_Test {

    // ─── HELPERS ─────────────────────────────────────────────────────────────

    private static String buildValidRequestBody() {
        return '{'
            + '"requestId": "REQ-20260519-0001",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "2026-05-19T15:30:00Z",'
            + '"delayRecords": [{'
            + '  "accountNo": "ACC123456789",'
            + '  "phone": "0901234567",'
            + '  "delayCode": 12,'
            + '  "delayNotes": "KHACH HANG HEN NGAY KHAC",'
            + '  "deliveryNotes": "Giao chung cu",'
            + '  "trackingNo": "TRK987654321",'
            + '  "plasticId": "PLS55667788"'
            + '}]'
            + '}';
    }

    private static void setupRestContext(String body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/v1/UndeliveredCard';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);

        RestResponse res = new RestResponse();

        RestContext.request = req;
        RestContext.response = res;
    }

    // ─── TEST: Success ───────────────────────────────────────────────────────

    @isTest
    static void testDoPost_Success() {
        setupRestContext(buildValidRequestBody());

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest(); 
    }

    // ─── TEST: Multiple records ──────────────────────────────────────────────

    @isTest
    static void testDoPost_MultipleRecords() {
        String body = '{'
            + '"requestId": "REQ-002",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "2026-05-19T10:00:00Z",'
            + '"delayRecords": ['
            + '  {"accountNo": "ACC001", "phone": "0901111111", "delayCode": 1, "delayNotes": "Note1", "deliveryNotes": "Del1", "trackingNo": "TRK001", "plasticId": "PLS001"},'
            + '  {"accountNo": "ACC002", "phone": "0902222222", "delayCode": 2, "delayNotes": "Note2", "deliveryNotes": "Del2", "trackingNo": "TRK002", "plasticId": "PLS002"}'
            + ']}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest(); 
    }

    // ─── TEST: Validation - Missing requestId ────────────────────────────────

    @isTest
    static void testDoPost_MissingRequestId() {
        String body = '{'
            + '"requestId": "",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "2026-05-19T15:30:00Z",'
            + '"delayRecords": [{"accountNo": "ACC001", "phone": "09011", "delayCode": 1, "delayNotes": "", "deliveryNotes": "", "trackingNo": "TRK001", "plasticId": "PLS001"}]'
            + '}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest(); 
    }

    // ─── TEST: Validation - Missing sourceSystem ─────────────────────────────

    @isTest
    static void testDoPost_MissingSourceSystem() {
        String body = '{'
            + '"requestId": "REQ-003",'
            + '"sourceSystem": "",'
            + '"sendDateTime": "2026-05-19T15:30:00Z",'
            + '"delayRecords": [{"accountNo": "ACC001", "phone": "09011", "delayCode": 1, "delayNotes": "", "deliveryNotes": "", "trackingNo": "TRK001", "plasticId": "PLS001"}]'
            + '}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest(); 
    }

    // ─── TEST: Validation - Missing sendDateTime ─────────────────────────────

    @isTest
    static void testDoPost_MissingSendDateTime() {
        String body = '{'
            + '"requestId": "REQ-004",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "",'
            + '"delayRecords": [{"accountNo": "ACC001", "phone": "09011", "delayCode": 1, "delayNotes": "", "deliveryNotes": "", "trackingNo": "TRK001", "plasticId": "PLS001"}]'
            + '}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest(); 
    }

    // ─── TEST: Validation - Empty delayRecords ───────────────────────────────

    @isTest
    static void testDoPost_EmptyDelayRecords() {
        String body = '{'
            + '"requestId": "REQ-005",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "2026-05-19T15:30:00Z",'
            + '"delayRecords": []'
            + '}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest(); 
    }

    // ─── TEST: Validation - Missing accountNo in record ──────────────────────

    @isTest
    static void testDoPost_MissingAccountNo() {
        String body = '{'
            + '"requestId": "REQ-006",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "2026-05-19T15:30:00Z",'
            + '"delayRecords": [{"accountNo": "", "phone": "09011", "delayCode": 1, "delayNotes": "", "deliveryNotes": "", "trackingNo": "TRK001", "plasticId": "PLS001"}]'
            + '}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest(); 
    }

    // ─── TEST: Validation - Missing trackingNo ───────────────────────────────

    @isTest
    static void testDoPost_MissingTrackingNo() {
        String body = '{'
            + '"requestId": "REQ-007",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "2026-05-19T15:30:00Z",'
            + '"delayRecords": [{"accountNo": "ACC001", "phone": "09011", "delayCode": 1, "delayNotes": "", "deliveryNotes": "", "trackingNo": "", "plasticId": "PLS001"}]'
            + '}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest(); 
    }

    // ─── TEST: Validation - Missing plasticId ────────────────────────────────

    @isTest
    static void testDoPost_MissingPlasticId() {
        String body = '{'
            + '"requestId": "REQ-008",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "2026-05-19T15:30:00Z",'
            + '"delayRecords": [{"accountNo": "ACC001", "phone": "09011", "delayCode": 1, "delayNotes": "", "deliveryNotes": "", "trackingNo": "TRK001", "plasticId": ""}]'
            + '}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest(); 
    }

    // ─── TEST: Validation - accountNo exceeds max length ─────────────────────

    @isTest
    static void testDoPost_AccountNoExceedsMaxLength() {
        String longAccountNo = 'A'.repeat(51);
        String body = '{'
            + '"requestId": "REQ-009",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "2026-05-19T15:30:00Z",'
            + '"delayRecords": [{"accountNo": "' + longAccountNo + '", "phone": "09011", "delayCode": 1, "delayNotes": "", "deliveryNotes": "", "trackingNo": "TRK001", "plasticId": "PLS001"}]'
            + '}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode);
    }

    // ─── TEST: Validation - phone exceeds max length ─────────────────────────

    @isTest
    static void testDoPost_PhoneExceedsMaxLength() {
        String longPhone = '0'.repeat(21);
        String body = '{'
            + '"requestId": "REQ-010",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "2026-05-19T15:30:00Z",'
            + '"delayRecords": [{"accountNo": "ACC001", "phone": "' + longPhone + '", "delayCode": 1, "delayNotes": "", "deliveryNotes": "", "trackingNo": "TRK001", "plasticId": "PLS001"}]'
            + '}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest(); 
    }

    // ─── TEST: Invalid JSON body ─────────────────────────────────────────────

    @isTest
    static void testDoPost_InvalidJson() {
        setupRestContext('{ invalid json }');

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest(); 
    }

    // ─── TEST: Null delayRecords ─────────────────────────────────────────────

    @isTest
    static void testDoPost_NullDelayRecords() {
        String body = '{'
            + '"requestId": "REQ-011",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "2026-05-19T15:30:00Z"'
            + '}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest(); 
    }

    // ─── TEST: Record with null optional fields ──────────────────────────────

    @isTest
    static void testDoPost_NullOptionalFields() {
        String body = '{'
            + '"requestId": "REQ-012",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "2026-05-19T15:30:00Z",'
            + '"delayRecords": [{"accountNo": "ACC001", "phone": null, "delayCode": null, "delayNotes": null, "deliveryNotes": null, "trackingNo": "TRK001", "plasticId": "PLS001"}]'
            + '}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest(); 
    }
}