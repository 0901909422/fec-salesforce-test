/**
 * Test class for FEC_Utils
 * Bao phủ:
 *  - checkExistCaseByExtInteractionID
 *  - updateExtInteractionIDForCase
 *  - getInteractionIdFromPegaId
 *  - getInteractionChannel
 *  - mappingKYCs
 *  - formatDateTimeToString
 *  - parseChatHubDatetime
 *  - downloadFileAsBlob
 *  - sendRequest
 */
@isTest
private class FEC_UtilsTest {

    private static final String EXT_INTERACTION_ID = 'EXT-INT-001';
    private static final String PEGA_ID            = 'PEGA-12345';

    @testSetup
    static void setupTestData() {
        Case c1 = new Case(
            Subject = 'Case with External Interaction',
            Status  = 'New',
            FEC_External_Interaction_ID__c = EXT_INTERACTION_ID
        );
        Case c2 = new Case(
            Subject = 'Case with Pega ID',
            Status  = 'New',
            FEC_ID_Search__c = PEGA_ID
        );
        Case c3 = new Case(
            Subject = 'Plain Case',
            Status  = 'New'
        );
        insert new List<Case>{ c1, c2, c3 };
    }

    // ---------------------------------------------------------
    // checkExistCaseByExtInteractionID
    // ---------------------------------------------------------

    @isTest
    static void testCheckExistCaseByExtInteractionID_Found() {
        Test.startTest();
        String caseId = FEC_Utils.checkExistCaseByExtInteractionID(EXT_INTERACTION_ID);
        Test.stopTest();

        System.assertNotEquals(null, caseId, 'Phải trả về Case Id khi đã tồn tại');
    }

    @isTest
    static void testCheckExistCaseByExtInteractionID_NotFound() {
        Test.startTest();
        String caseId = FEC_Utils.checkExistCaseByExtInteractionID('NOT-EXIST-XXX');
        Test.stopTest();

        System.assertEquals(null, caseId, 'Phải trả null khi không tồn tại');
    }

    // ---------------------------------------------------------
    // updateExtInteractionIDForCase
    // ---------------------------------------------------------

    @isTest
    static void testUpdateExtInteractionIDForCase() {
        Case plainCase = [SELECT Id FROM Case WHERE Subject = 'Plain Case' LIMIT 1];
        String newExtId = 'EXT-INT-NEW-999';

        Test.startTest();
        FEC_Utils.updateExtInteractionIDForCase(plainCase.Id, newExtId);
        Test.stopTest();

        Case updated = [SELECT FEC_External_Interaction_ID__c FROM Case WHERE Id = :plainCase.Id];
        System.assertEquals(newExtId, updated.FEC_External_Interaction_ID__c, 'External Interaction ID phải được cập nhật');
    }

    // ---------------------------------------------------------
    // getInteractionIdFromPegaId
    // ---------------------------------------------------------

    @isTest
    static void testGetInteractionIdFromPegaId_Found() {
        Test.startTest();
        String caseId = FEC_Utils.getInteractionIdFromPegaId(PEGA_ID);
        Test.stopTest();

        System.assertNotEquals(null, caseId, 'Phải tìm thấy Case theo Pega ID');
    }

    @isTest
    static void testGetInteractionIdFromPegaId_NotFound() {
        Test.startTest();
        String caseId = FEC_Utils.getInteractionIdFromPegaId('PEGA-NOT-EXIST');
        Test.stopTest();

        System.assertEquals(null, caseId, 'Phải trả null khi Pega ID không tồn tại');
    }

    // ---------------------------------------------------------
    // getInteractionChannel
    // ---------------------------------------------------------

    @isTest
    static void testGetInteractionChannel_AllMappings() {
        System.assertEquals('Facebook', FEC_Utils.getInteractionChannel('facebook'));
        System.assertEquals('Facebook', FEC_Utils.getInteractionChannel('FACEBOOK'),  'Phải case-insensitive');
        System.assertEquals('FE App',   FEC_Utils.getInteractionChannel('appchat'));
        System.assertEquals('Zalo',     FEC_Utils.getInteractionChannel('zalo'));
        System.assertEquals('Website',  FEC_Utils.getInteractionChannel('webchat'));
        System.assertEquals('Other',    FEC_Utils.getInteractionChannel('unknown_channel'));
        System.assertEquals('Other',    FEC_Utils.getInteractionChannel(null));
        System.assertEquals('Other',    FEC_Utils.getInteractionChannel(''));
    }

    // ---------------------------------------------------------
    // mappingKYCs
    // ---------------------------------------------------------

    @isTest
    static void testMappingKYCs_AllValues() {
        System.assertEquals('Pass',  FEC_Utils.mappingKYCs('KYC'));
        System.assertEquals('Pass',  FEC_Utils.mappingKYCs('KYCed'));
        System.assertEquals('Fail',  FEC_Utils.mappingKYCs('NOT KYC'));
        System.assertEquals('Other', FEC_Utils.mappingKYCs('SOMETHING_ELSE'));
        System.assertEquals('Other', FEC_Utils.mappingKYCs(null));
        System.assertEquals('Other', FEC_Utils.mappingKYCs(''));
    }

    // ---------------------------------------------------------
    // formatDateTimeToString
    // ---------------------------------------------------------

    @isTest
    static void testFormatDateTimeToString_Null() {
        System.assertEquals('', FEC_Utils.formatDateTimeToString(null), 'Null phải trả về chuỗi rỗng');
    }

    @isTest
    static void testFormatDateTimeToString_Valid() {
        Datetime dt = Datetime.newInstanceGmt(2026, 3, 12, 14, 39, 2);
        String result = FEC_Utils.formatDateTimeToString(dt);

        System.assertNotEquals(null, result);
        System.assert(result.contains('GMT'),       'Output phải có hậu tố GMT');
        System.assert(result.startsWith('20260312'),'Output phải bắt đầu bằng yyyyMMdd');
    }

    // ---------------------------------------------------------
    // parseChatHubDatetime
    // ---------------------------------------------------------

    @isTest
    static void testParseChatHubDatetime_Blank() {
        System.assertEquals(null, FEC_Utils.parseChatHubDatetime(null));
        System.assertEquals(null, FEC_Utils.parseChatHubDatetime(''));
    }

    @isTest
    static void testParseChatHubDatetime_GMTOffset() {
        // 14:39:02 GMT+0700  =>  07:39:02 UTC
        Datetime result = FEC_Utils.parseChatHubDatetime('2026-02-03 14:39:02 GMT+0700');

        System.assertNotEquals(null, result, 'Phải parse được chuỗi GMT+0700');
        System.assertEquals(2026, result.yearGmt());
        System.assertEquals(2,    result.monthGmt());
        System.assertEquals(3,    result.dayGmt());
        System.assertEquals(7,    result.hourGmt(),   'Giờ GMT phải = giờ local - 7');
        System.assertEquals(39,   result.minuteGmt());
        System.assertEquals(2,    result.secondGmt());
    }

    @isTest
    static void testParseChatHubDatetime_FallbackValueOf() {
        // Chuỗi không có 'GMT' => đi vào nhánh JSON.deserialize, có thể fail
        // và rớt về Datetime.valueOf
        Datetime result = FEC_Utils.parseChatHubDatetime('2026-02-03 14:39:02');
        System.assertNotEquals(null, result, 'Fallback Datetime.valueOf phải parse OK');
    }

    @isTest
    static void testParseChatHubDatetime_Invalid() {
        Datetime result = FEC_Utils.parseChatHubDatetime('not-a-datetime');
        System.assertEquals(null, result, 'Chuỗi không hợp lệ phải trả null');
    }

    // ---------------------------------------------------------
    // downloadFileAsBlob
    // ---------------------------------------------------------

    @isTest
    static void testDownloadFileAsBlob_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        Blob result = FEC_Utils.downloadFileAsBlob('https://example.com/file.pdf');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Phải trả về blob khi HTTP 200');
        System.assertEquals('Mocked file content', result.toString());
    }

    @isTest
    static void testDownloadFileAsBlob_BlankUrl() {
        Test.startTest();
        try {
            FEC_Utils.downloadFileAsBlob('');
            System.assert(false, 'Phải throw CalloutException khi URL rỗng');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testDownloadFileAsBlob_HttpError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpError());

        Test.startTest();
        try {
            FEC_Utils.downloadFileAsBlob('https://example.com/file.pdf');
            System.assert(false, 'Phải throw CalloutException khi HTTP != 200');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ---------------------------------------------------------
    // sendRequest
    // ---------------------------------------------------------

    @isTest
    static void testSendRequest_GetSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        HttpResponse res = FEC_Utils.sendRequest(
            FEC_ConstantCommon.API_METHOD_GET,
            'https://example.com/api',
            null,
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(200, res.getStatusCode());
    }

    @isTest
    static void testSendRequest_PostWithCustomHeaders() {
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Map<String, String> headers = new Map<String, String>{
            'Authorization' => 'Bearer token123'
        };

        Test.startTest();
        HttpResponse res = FEC_Utils.sendRequest(
            FEC_ConstantCommon.API_METHOD_POST,
            'https://example.com/api',
            '{"name":"John"}',
            headers
        );
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(200, res.getStatusCode());
    }

    // ---------------------------------------------------------
    // Mock classes
    // ---------------------------------------------------------

    private class MockHttpSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('Mocked file content');
            res.setStatusCode(200);
            return res;
        }
    }

    private class MockHttpError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
}
