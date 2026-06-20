@IsTest(SeeAllData=false)
private class FEC_MobileAppNotificationCallout_Test {

    private static final String BASE_ENDPOINT = 'https://unit-test.example.com';
    private static final String PHONE_VN = '0971953842';
    private static final String NATIONAL_ID = '123456789012';
    private static final String CONTENT = 'Unit test content';
    private static final String TITLE = 'Unit test title';

    private class ForcedMockException extends Exception {}

    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();

        if (apiSetting == null || apiSetting.Id == null) {
            insert new FEC_API_Setting__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                FEC_Endpoint__c = BASE_ENDPOINT
            );
        } else {
            apiSetting.FEC_Endpoint__c = BASE_ENDPOINT;
            update apiSetting;
        }
    }

    private class MobileAppHttpMock implements HttpCalloutMock {
        private String scenario;

        MobileAppHttpMock(String scenario) {
            this.scenario = scenario;
        }

        public HttpResponse respond(HttpRequest req) {
            if (scenario == 'THROW') {
                throw new ForcedMockException('Forced mock callout failure');
            }

            assertCommonHeaders(req);

            if (req.getMethod() == 'GET') {
                return respondToCheckUser(req);
            }

            if (req.getMethod() == 'POST') {
                return respondToPushNotification(req);
            }

            System.assert(false, 'Unexpected HTTP method: ' + req.getMethod());
            return newResponse(500, 'Unexpected HTTP method');
        }

        private void assertCommonHeaders(HttpRequest req) {
            System.assertNotEquals(null, req.getHeader('TransID'), 'TransID header is required.');
            System.assertNotEquals(null, req.getHeader('DateTime'), 'DateTime header is required.');
            System.assertEquals(
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                req.getHeader('RequestorID'),
                'RequestorID header is incorrect.'
            );
        }

        private HttpResponse respondToCheckUser(HttpRequest req) {
            System.assert(
                req.getEndpoint().contains('PhoneNumber=' + PHONE_VN),
                'PhoneNumber should be normalized and URL encoded.'
            );
            System.assert(
                req.getEndpoint().contains('NationalID=' + NATIONAL_ID),
                'NationalID query param is missing.'
            );

            // FEC_CommonUltils may send GET body as null or blank string depending on implementation.
            System.assert(
                String.isBlank(req.getBody()),
                'GET request body should be null or blank.'
            );

            if (scenario == 'CHECK_EMPTY_BODY') {
                return newResponse(204, '');
            }

            if (scenario == 'CHECK_NOT_EXIST') {
                return newResponse(200, apiResponseBody('0', 'CUSTOMER_NOT_EXIST'));
            }

            return newResponse(200, apiResponseBody('1', 'CUSTOMER_EXIST'));
        }

        private HttpResponse respondToPushNotification(HttpRequest req) {
            System.assertEquals(
                FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
                req.getHeader('Content-Type'),
                'Content-Type header is incorrect.'
            );

            System.assert(
                String.isNotBlank(req.getBody()),
                'POST request body is required.'
            );

            Map<String, Object> payload =
                (Map<String, Object>) JSON.deserializeUntyped(req.getBody());

            System.assertEquals(CONTENT, (String) payload.get('Content'));
            System.assertEquals(NATIONAL_ID, (String) payload.get('NationalID'));
            System.assertEquals(PHONE_VN, (String) payload.get('PhoneNumber'));
            System.assertEquals(TITLE, (String) payload.get('Title'));
            System.assertEquals('pega_csm', (String) payload.get('Event_Source'));
            System.assertEquals('pega_csm_support', (String) payload.get('Event_Name'));

            if (scenario == 'SEND_EMPTY_BODY') {
                return newResponse(202, '');
            }

            if (scenario == 'SEND_HTTP_500') {
                return newResponse(500, apiResponseBody('0', 'FAILED'));
            }

            return newResponse(200, apiResponseBody('1', 'SUCCESS'));
        }
    }

    @IsTest
    static void normalizeVietnamPhone_shouldNormalizeCommonFormats() {
        System.assertEquals(
            '0971953842',
            FEC_MobileAppNotificationCallout.normalizeVietnamPhone('84971953842')
        );
        System.assertEquals(
            '0971953842',
            FEC_MobileAppNotificationCallout.normalizeVietnamPhone('+84971953842')
        );
        System.assertEquals(
            '0971953842',
            FEC_MobileAppNotificationCallout.normalizeVietnamPhone('0971953842')
        );
        System.assertEquals(
            null,
            FEC_MobileAppNotificationCallout.normalizeVietnamPhone(null)
        );
        System.assertEquals(
            '',
            FEC_MobileAppNotificationCallout.normalizeVietnamPhone('')
        );
    }

    @IsTest
    static void checkUserExist_shouldReturnCustomerExist_whenApiReturnsSuccess() {
        clearStaticLogs();
        Test.setMock(HttpCalloutMock.class, new MobileAppHttpMock('CHECK_SUCCESS'));

        Test.startTest();
        FEC_MobileAppNotificationCallout.CheckUserResponse result =
            FEC_MobileAppNotificationCallout.checkUserExist('+84971953842', NATIONAL_ID);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(200, result.httpStatusCode);
        System.assertEquals('1', result.code);
        System.assertEquals('CUSTOMER_EXIST', result.description);
        System.assertEquals('T-UNIT-TEST', result.transId);
        System.assertEquals(true, result.isCustomerExist);
        System.assertNotEquals(null, result.rawResponse);
        System.assertEquals(null, FEC_MobileAppNotificationCallout.responseLogCheckUserExist);
    }

    @IsTest
    static void checkUserExist_shouldReturnNotExist_whenApiReturnsNonMatchingBody() {
        clearStaticLogs();
        Test.setMock(HttpCalloutMock.class, new MobileAppHttpMock('CHECK_NOT_EXIST'));

        Test.startTest();
        FEC_MobileAppNotificationCallout.CheckUserResponse result =
            FEC_MobileAppNotificationCallout.checkUserExist('84971953842', NATIONAL_ID);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(200, result.httpStatusCode);
        System.assertEquals('0', result.code);
        System.assertEquals('CUSTOMER_NOT_EXIST', result.description);
        System.assertEquals(false, result.isCustomerExist);
        System.assertEquals(null, FEC_MobileAppNotificationCallout.responseLogCheckUserExist);
    }

    @IsTest
    static void checkUserExist_shouldReturnSuccessWithoutParsedBody_whenBodyIsBlank() {
        clearStaticLogs();
        Test.setMock(HttpCalloutMock.class, new MobileAppHttpMock('CHECK_EMPTY_BODY'));

        Test.startTest();
        FEC_MobileAppNotificationCallout.CheckUserResponse result =
            FEC_MobileAppNotificationCallout.checkUserExist('0971953842', NATIONAL_ID);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(204, result.httpStatusCode);
        System.assertEquals('', result.rawResponse);
        System.assertEquals(null, result.code);
        System.assertEquals(null, result.description);
        System.assertEquals(null, result.isCustomerExist);
        System.assertEquals(null, FEC_MobileAppNotificationCallout.responseLogCheckUserExist);
    }

    @IsTest
    static void checkUserExist_shouldReturnCalloutError_whenCalloutThrowsException() {
        clearStaticLogs();
        Test.setMock(HttpCalloutMock.class, new MobileAppHttpMock('THROW'));

        Test.startTest();
        FEC_MobileAppNotificationCallout.CheckUserResponse result =
            FEC_MobileAppNotificationCallout.checkUserExist('0971953842', NATIONAL_ID);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(599, result.httpStatusCode);
        System.assertEquals('CALLOUT_ERROR', result.description);
        System.assertEquals(false, result.isCustomerExist);
        System.assert(result.rawResponse.contains('Forced mock callout failure'));
        System.assertEquals(null, FEC_MobileAppNotificationCallout.responseLogCheckUserExist);
    }

    @IsTest
    static void sendNotification_shouldReturnSentSuccess_whenApiReturnsSuccess() {
        clearStaticLogs();
        Test.setMock(HttpCalloutMock.class, new MobileAppHttpMock('SEND_SUCCESS'));

        Test.startTest();
        FEC_MobileAppNotificationCallout.SendNotificationResponse result =
            FEC_MobileAppNotificationCallout.sendNotification(
                CONTENT,
                NATIONAL_ID,
                '+84971953842',
                TITLE
            );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(200, result.httpStatusCode);
        System.assertEquals('1', result.code);
        System.assertEquals('SUCCESS', result.description);
        System.assertEquals('T-UNIT-TEST', result.transId);
        System.assertEquals(true, result.isSentSuccess);
        System.assertNotEquals(null, result.rawResponse);
        System.assertEquals(null, FEC_MobileAppNotificationCallout.responseLogPushNotification);
    }

    @IsTest
    static void sendNotification_shouldReturnFail_whenApiReturnsHttp500() {
        clearStaticLogs();
        Test.setMock(HttpCalloutMock.class, new MobileAppHttpMock('SEND_HTTP_500'));

        Test.startTest();
        FEC_MobileAppNotificationCallout.SendNotificationResponse result =
            FEC_MobileAppNotificationCallout.sendNotification(
                CONTENT,
                NATIONAL_ID,
                '84971953842',
                TITLE
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(500, result.httpStatusCode);
        System.assertEquals('0', result.code);
        System.assertEquals('FAILED', result.description);
        System.assertEquals(false, result.isSentSuccess);
        System.assertEquals(null, FEC_MobileAppNotificationCallout.responseLogPushNotification);
    }

    @IsTest
    static void sendNotification_shouldReturnSuccessWithoutParsedBody_whenBodyIsBlank() {
        clearStaticLogs();
        Test.setMock(HttpCalloutMock.class, new MobileAppHttpMock('SEND_EMPTY_BODY'));

        Test.startTest();
        FEC_MobileAppNotificationCallout.SendNotificationResponse result =
            FEC_MobileAppNotificationCallout.sendNotification(
                CONTENT,
                NATIONAL_ID,
                '0971953842',
                TITLE
            );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(202, result.httpStatusCode);
        System.assertEquals('', result.rawResponse);
        System.assertEquals(null, result.code);
        System.assertEquals(null, result.description);
        System.assertEquals(null, result.isSentSuccess);
        System.assertEquals(null, FEC_MobileAppNotificationCallout.responseLogPushNotification);
    }

    @IsTest
    static void sendNotification_shouldReturnCalloutError_whenCalloutThrowsException() {
        clearStaticLogs();
        Test.setMock(HttpCalloutMock.class, new MobileAppHttpMock('THROW'));

        Test.startTest();
        FEC_MobileAppNotificationCallout.SendNotificationResponse result =
            FEC_MobileAppNotificationCallout.sendNotification(
                CONTENT,
                NATIONAL_ID,
                '0971953842',
                TITLE
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(599, result.httpStatusCode);
        System.assertEquals('CALLOUT_ERROR', result.description);
        System.assertEquals(false, result.isSentSuccess);
        System.assert(result.rawResponse.contains('Forced mock callout failure'));
        System.assertEquals(null, FEC_MobileAppNotificationCallout.responseLogPushNotification);
    }

    @IsTest
    static void sendNotificationWithoutLogging_shouldKeepResponseLog_thenWriteLogSendNotiShouldClearIt() {
        clearStaticLogs();
        Test.setMock(HttpCalloutMock.class, new MobileAppHttpMock('SEND_SUCCESS'));

        Test.startTest();
        FEC_MobileAppNotificationCallout.SendNotificationResponse result =
            FEC_MobileAppNotificationCallout.sendNotificationWithoutLogging(
                CONTENT,
                NATIONAL_ID,
                '+84971953842',
                TITLE
            );

        System.assertEquals(true, result.success);
        System.assertEquals(true, result.isSentSuccess);
        System.assertNotEquals(
            null,
            FEC_MobileAppNotificationCallout.responseLogPushNotification,
            'sendNotificationWithoutLogging should keep responseLogPushNotification for later logging.'
        );

        FEC_MobileAppNotificationCallout.writeLogSendNoti();
        Test.stopTest();

        System.assertEquals(
            null,
            FEC_MobileAppNotificationCallout.responseLogPushNotification,
            'writeLogSendNoti should clear responseLogPushNotification after logging.'
        );
    }

    @IsTest
    static void sendNotificationWithoutLogging_shouldKeepErrorResponseLog_whenCalloutThrowsException() {
        clearStaticLogs();
        Test.setMock(HttpCalloutMock.class, new MobileAppHttpMock('THROW'));

        Test.startTest();
        FEC_MobileAppNotificationCallout.SendNotificationResponse result =
            FEC_MobileAppNotificationCallout.sendNotificationWithoutLogging(
                CONTENT,
                NATIONAL_ID,
                '0971953842',
                TITLE
            );

        System.assertEquals(false, result.success);
        System.assertEquals(599, result.httpStatusCode);
        System.assertEquals('CALLOUT_ERROR', result.description);
        System.assertEquals(false, result.isSentSuccess);
        System.assertNotEquals(
            null,
            FEC_MobileAppNotificationCallout.responseLogPushNotification,
            'Error response log should be kept for later logging.'
        );

        FEC_MobileAppNotificationCallout.writeLogSendNoti();
        Test.stopTest();

        System.assertEquals(null, FEC_MobileAppNotificationCallout.responseLogPushNotification);
    }

    @IsTest
    static void writeLogSendNoti_shouldReturnSafely_whenResponseLogIsNull() {
        clearStaticLogs();

        Test.startTest();
        FEC_MobileAppNotificationCallout.writeLogSendNoti();
        Test.stopTest();

        System.assertEquals(null, FEC_MobileAppNotificationCallout.responseLogPushNotification);
    }

    private static void clearStaticLogs() {
        FEC_MobileAppNotificationCallout.responseLogCheckUserExist = null;
        FEC_MobileAppNotificationCallout.responseLogPushNotification = null;
    }

    private static HttpResponse newResponse(Integer statusCode, String body) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setStatus(statusCode >= 200 && statusCode < 300 ? 'OK' : 'ERROR');
        res.setBody(body);
        return res;
    }

    private static String apiResponseBody(String code, String description) {
        return JSON.serialize(new Map<String, Object>{
            'Code' => code,
            'DateTime' => '2026-06-19T10:00:00.000+07:00',
            'Description' => description,
            'TransID' => 'T-UNIT-TEST'
        });
    }
}