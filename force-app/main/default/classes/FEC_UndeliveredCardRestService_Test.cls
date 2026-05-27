/*------------------------------------------------------------
Author:        DuanNguyen 
Description:   Test class for FEC_UndeliveredCardRestService
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/05/20     DuanNguyen          Init
2026/05/27     DuanNguyen          Add assertions & extra coverage
------------------------------------------------------------*/
@isTest
private class FEC_UndeliveredCardRestService_Test {

    // ─── HELPERS ─────────────────────────────────────────────────────────────

    private static String buildRequestBody(String requestId, String accountNo, String trackingNo) {
        return '{'
            + '"requestId": "' + requestId + '",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "2026-05-19T15:30:00Z",'
            + '"delayRecords": [{'
            + '  "accountNo": "' + accountNo + '",'
            + '  "phone": "0901234567",'
            + '  "delayCode": 12,'
            + '  "delayNotes": "KHACH HANG HEN NGAY KHAC",'
            + '  "deliveryNotes": "Giao chung cu",'
            + '  "trackingNo": "' + trackingNo + '",'
            + '  "plasticId": "PLS55667788"'
            + '}]'
            + '}';
    }

    private static String buildValidRequestBody() {
        return buildRequestBody('REQ-20260519-0001', 'ACC123456789', 'TRK987654321');
    }

    private static void setupRestContext(String body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/v1/UndeliveredCard';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    private static FEC_UndeliveredCardRestService.UndeliveredCardResponse parseResponse() {
        String body = RestContext.response.responseBody.toString();
        return (FEC_UndeliveredCardRestService.UndeliveredCardResponse) JSON.deserialize(
            body, FEC_UndeliveredCardRestService.UndeliveredCardResponse.class
        );
    }

    // ─── TEST: Success ───────────────────────────────────────────────────────

    @isTest
    static void testDoPost_Success() {
        setupRestContext(buildValidRequestBody());

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Should return 200');
        FEC_UndeliveredCardRestService.UndeliveredCardResponse resp = parseResponse();
        System.assertEquals('200', resp.code);
        System.assertEquals(true, resp.isSuccessfully, 'Should be successful');
        System.assertEquals(1, resp.resultsSuccess.size(), 'One success record');
        System.assertEquals(0, resp.resultsFail.size(), 'No fail record');

        List<FEC_Undelivered_Card__c> inserted = [
            SELECT Id, FEC_Request_ID__c, FEC_Account_No__c, FEC_Tracking_No__c
            FROM FEC_Undelivered_Card__c
            WHERE FEC_Request_ID__c = 'REQ-20260519-0001'
        ];
        System.assertEquals(1, inserted.size(), 'Record should be inserted');
        System.assertEquals('ACC123456789', inserted[0].FEC_Account_No__c);
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

        System.assertEquals(200, RestContext.response.statusCode);
        FEC_UndeliveredCardRestService.UndeliveredCardResponse resp = parseResponse();
        System.assertEquals(2, resp.resultsSuccess.size(), 'Two success records');
        System.assertEquals(0, resp.resultsFail.size());
        System.assertEquals(2, [SELECT COUNT() FROM FEC_Undelivered_Card__c WHERE FEC_Request_ID__c = 'REQ-002']);
    }

    // ─── TEST: Duplicate requestId ───────────────────────────────────────────

    @isTest
    static void testDoPost_DuplicateRequestId() {
        insert new FEC_Undelivered_Card__c(
            FEC_Request_ID__c = 'REQ-DUP-001',
            FEC_Source_System__c = 'WAY4',
            FEC_Account_No__c = 'ACC-OLD',
            FEC_Tracking_No__c = 'TRK-OLD'
        );

        setupRestContext(buildRequestBody('REQ-DUP-001', 'ACC-NEW', 'TRK-NEW'));

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        FEC_UndeliveredCardRestService.UndeliveredCardResponse resp = parseResponse();
        System.assertEquals('400', resp.code);
        System.assert(resp.message.contains('already exists'), 'Should mention duplicate: ' + resp.message);
        System.assertEquals(1, [SELECT COUNT() FROM FEC_Undelivered_Card__c WHERE FEC_Request_ID__c = 'REQ-DUP-001'],
            'No new record inserted on duplicate');
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

        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('400', parseResponse().code);
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

        System.assertEquals(400, RestContext.response.statusCode);
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

        System.assertEquals(400, RestContext.response.statusCode);
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

        System.assertEquals(400, RestContext.response.statusCode);
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

        System.assertEquals(200, RestContext.response.statusCode, 'Header valid -> 200, item-level fail returned in body');
        FEC_UndeliveredCardRestService.UndeliveredCardResponse resp = parseResponse();
        System.assertEquals(false, resp.isSuccessfully);
        System.assertEquals(1, resp.resultsFail.size());
        System.assertEquals(0, resp.resultsSuccess.size());
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

        FEC_UndeliveredCardRestService.UndeliveredCardResponse resp = parseResponse();
        System.assertEquals(false, resp.isSuccessfully);
        System.assertEquals(1, resp.resultsFail.size());
    }

    // ─── TEST: Mixed valid + invalid records ─────────────────────────────────

    @isTest
    static void testDoPost_MixedValidAndInvalid() {
        String body = '{'
            + '"requestId": "REQ-MIX-001",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "2026-05-19T15:30:00Z",'
            + '"delayRecords": ['
            + '  {"accountNo": "ACC-OK", "phone": "09011", "delayCode": 1, "delayNotes": "", "deliveryNotes": "", "trackingNo": "TRK-OK", "plasticId": "PLS001"},'
            + '  {"accountNo": "", "phone": "09012", "delayCode": 2, "delayNotes": "", "deliveryNotes": "", "trackingNo": "TRK-FAIL", "plasticId": "PLS002"}'
            + ']}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest();

        FEC_UndeliveredCardRestService.UndeliveredCardResponse resp = parseResponse();
        System.assertEquals(1, resp.resultsSuccess.size(), 'One should succeed');
        System.assertEquals(1, resp.resultsFail.size(), 'One should fail validation');
        System.assertEquals(false, resp.isSuccessfully);
        System.assertEquals(1, [SELECT COUNT() FROM FEC_Undelivered_Card__c WHERE FEC_Request_ID__c = 'REQ-MIX-001']);
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

        FEC_UndeliveredCardRestService.UndeliveredCardResponse resp = parseResponse();
        System.assertEquals(1, resp.resultsFail.size());
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

        System.assertEquals(1, parseResponse().resultsFail.size());
    }

    // ─── TEST: Validation - delayNotes/deliveryNotes/trackingNo/plasticId exceed max ─

    @isTest
    static void testDoPost_OtherFieldsExceedMaxLength() {
        String longDelayNotes    = 'A'.repeat(301);
        String longDeliveryNotes = 'B'.repeat(101);
        String longTrackingNo    = 'C'.repeat(51);
        String longPlasticId     = 'D'.repeat(31);

        // delayNotes > 300
        setupRestContext('{"requestId":"REQ-LEN-1","sourceSystem":"WAY4","sendDateTime":"2026-05-19T15:30:00Z","delayRecords":[{"accountNo":"ACC","phone":"09","delayCode":1,"delayNotes":"' + longDelayNotes + '","deliveryNotes":"","trackingNo":"TRK","plasticId":"PLS"}]}');
        FEC_UndeliveredCardRestService.doPost();
        System.assertEquals(1, parseResponse().resultsFail.size(), 'delayNotes too long');

        // deliveryNotes > 100
        setupRestContext('{"requestId":"REQ-LEN-2","sourceSystem":"WAY4","sendDateTime":"2026-05-19T15:30:00Z","delayRecords":[{"accountNo":"ACC","phone":"09","delayCode":1,"delayNotes":"","deliveryNotes":"' + longDeliveryNotes + '","trackingNo":"TRK","plasticId":"PLS"}]}');
        FEC_UndeliveredCardRestService.doPost();
        System.assertEquals(1, parseResponse().resultsFail.size(), 'deliveryNotes too long');

        // trackingNo > 50
        setupRestContext('{"requestId":"REQ-LEN-3","sourceSystem":"WAY4","sendDateTime":"2026-05-19T15:30:00Z","delayRecords":[{"accountNo":"ACC","phone":"09","delayCode":1,"delayNotes":"","deliveryNotes":"","trackingNo":"' + longTrackingNo + '","plasticId":"PLS"}]}');
        FEC_UndeliveredCardRestService.doPost();
        System.assertEquals(1, parseResponse().resultsFail.size(), 'trackingNo too long');

        // plasticId > 30
        setupRestContext('{"requestId":"REQ-LEN-4","sourceSystem":"WAY4","sendDateTime":"2026-05-19T15:30:00Z","delayRecords":[{"accountNo":"ACC","phone":"09","delayCode":1,"delayNotes":"","deliveryNotes":"","trackingNo":"TRK","plasticId":"' + longPlasticId + '"}]}');
        FEC_UndeliveredCardRestService.doPost();
        System.assertEquals(1, parseResponse().resultsFail.size(), 'plasticId too long');
    }

    // ─── TEST: Invalid sendDateTime format (parseSendDateTime returns null) ──

    @isTest
    static void testDoPost_InvalidSendDateTimeFormat() {
        String body = '{'
            + '"requestId": "REQ-DT-INVALID",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "not-a-date",'
            + '"delayRecords": [{"accountNo": "ACC001", "phone": "09011", "delayCode": 1, "delayNotes": "", "deliveryNotes": "", "trackingNo": "TRK001", "plasticId": "PLS001"}]'
            + '}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest();

        // Header passes (sendDateTime is not blank), record goes through with null receivedDt
        System.assertEquals(200, RestContext.response.statusCode);
        FEC_UndeliveredCardRestService.UndeliveredCardResponse resp = parseResponse();
        System.assertEquals(1, resp.resultsSuccess.size());
    }

    // ─── TEST: Invalid JSON body ─────────────────────────────────────────────

    @isTest
    static void testDoPost_InvalidJson() {
        setupRestContext('{ invalid json }');

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode, 'Malformed JSON should produce 500');
        System.assertEquals('500', parseResponse().code);
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

        System.assertEquals(400, RestContext.response.statusCode);
    }

    // ─── TEST: Record with null optional fields ──────────────────────────────

    @isTest
    static void testDoPost_NullOptionalFields() {
        String body = '{'
            + '"requestId": "REQ-012",'
            + '"sourceSystem": "WAY4",'
            + '"sendDateTime": "2026-05-19T15:30:00Z",'
            + '"delayRecords": [{"accountNo": "ACC001", "phone": null, "delayCode": null, "delayNotes": null, "deliveryNotes": null, "trackingNo": "TRK001", "plasticId": null}]'
            + '}';

        setupRestContext(body);

        Test.startTest();
        FEC_UndeliveredCardRestService.doPost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        FEC_UndeliveredCardRestService.UndeliveredCardResponse resp = parseResponse();
        System.assertEquals(true, resp.isSuccessfully);
        System.assertEquals(1, resp.resultsSuccess.size());
    }
}
