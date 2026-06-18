@IsTest(SeeAllData=false)
private class FEC_MobileAppNotificationCallout_Test {

    @TestSetup
    static void setupData() {
        // Hierarchy Custom Setting used by FEC_API_Setting__c.getOrgDefaults()
        FEC_API_Setting__c setting = new FEC_API_Setting__c();
        setting.SetupOwnerId = UserInfo.getOrganizationId();
        setting.FEC_Endpoint__c = 'https://mobile-app-unit-test.example';
        insert setting;
    }

    private class MobileAppHttpMock implements HttpCalloutMock {
        private String expectedMethod;
        private Integer statusCode;
        private String responseBody;
        private Boolean throwException;
        private Boolean validateCheckUserRequest;
        private Boolean validatePushRequest;

        MobileAppHttpMock(
            String expectedMethod,
            Integer statusCode,
            String responseBody,
            Boolean throwException,
            Boolean validateCheckUserRequest,
            Boolean validatePushRequest
        ) {
            this.expectedMethod = expectedMethod;
            this.statusCode = statusCode;
            this.responseBody = responseBody;
            this.throwException = throwException;
            this.validateCheckUserRequest = validateCheckUserRequest;
            this.validatePushRequest = validatePushRequest;
        }

        public HttpResponse respond(HttpRequest req) {
            if (throwException) {
                throw new CalloutException('Simulated timeout');
            }

            System.assertEquals(
                expectedMethod,
                req.getMethod(),
                'Unexpected HTTP method.'
            );

            if (validateCheckUserRequest) {
                System.assert(
                    req.getEndpoint().contains('PhoneNumber=0971953842'),
                    'PhoneNumber should be normalized and URL encoded in endpoint.'
                );
                System.assert(
                    req.getEndpoint().contains('NationalID=NID123'),
                    'NationalID should be included in endpoint.'
                );
                System.assert(
                    String.isBlank(req.getBody()),
                    'GET request body should be blank.'
                );
            }

            if (validatePushRequest) {
                System.assertNotEquals(
                    null,
                    req.getBody(),
                    'POST request body should not be null.'
                );

                Map<String, Object> body =
                    (Map<String, Object>) JSON.deserializeUntyped(req.getBody());

                System.assertEquals('Hello content', body.get('Content'));
                System.assertEquals('NID123', body.get('NationalID'));
                System.assertEquals('0971953842', body.get('PhoneNumber'));
                System.assertEquals('Hello title', body.get('Title'));
                System.assertEquals('pega_csm', body.get('Event_Source'));
                System.assertEquals('pega_csm_support', body.get('Event_Name'));
            }

            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setStatus(statusCode + ' Unit Test');
            res.setBody(responseBody == null ? '' : responseBody);
            return res;
        }
    }

    private static String buildResponseBody(String code, String description, String transId) {
        return JSON.serialize(new Map<String, Object>{
            'Code' => code,
            'DateTime' => '2026-06-11T15:00:00.000+07:00',
            'Description' => description,
            'TransID' => transId
        });
    }

    @IsTest
    static void normalizeVietnamPhone_shouldHandleValidFormats() {
        System.assertEquals(
            null,
            FEC_MobileAppNotificationCallout.normalizeVietnamPhone(null)
        );

        System.assertEquals(
            '',
            FEC_MobileAppNotificationCallout.normalizeVietnamPhone('')
        );

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
    }

    @IsTest
    static void checkUserExist_shouldReturnCustomerExist_whenApiReturnsSuccess() {
        Test.setMock(
            HttpCalloutMock.class,
            new MobileAppHttpMock(
                'GET',
                200,
                buildResponseBody('1', 'CUSTOMER_EXIST', 'TRANS_CHECK_SUCCESS'),
                false,
                true,
                false
            )
        );

        Test.startTest();
        FEC_MobileAppNotificationCallout.CheckUserResponse result =
            FEC_MobileAppNotificationCallout.checkUserExist(
                '+84971953842',
                'NID123'
            );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(200, result.httpStatusCode);
        System.assertEquals('1', result.code);
        System.assertEquals('CUSTOMER_EXIST', result.description);
        System.assertEquals('TRANS_CHECK_SUCCESS', result.transId);
        System.assertEquals(true, result.isCustomerExist);
        System.assertNotEquals(null, result.rawResponse);

        System.assertEquals(
            null,
            FEC_MobileAppNotificationCallout.responseLogCheckUserExist,
            'Static response log should be cleared after logging.'
        );
    }

    @IsTest
    static void checkUserExist_shouldReturnFalse_whenCustomerDoesNotExist() {
        Test.setMock(
            HttpCalloutMock.class,
            new MobileAppHttpMock(
                'GET',
                200,
                buildResponseBody('0', 'CUSTOMER_NOT_EXIST', 'TRANS_CHECK_NOT_EXIST'),
                false,
                false,
                false
            )
        );

        Test.startTest();
        FEC_MobileAppNotificationCallout.CheckUserResponse result =
            FEC_MobileAppNotificationCallout.checkUserExist(
                '0971953842',
                'NID123'
            );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(200, result.httpStatusCode);
        System.assertEquals('0', result.code);
        System.assertEquals('CUSTOMER_NOT_EXIST', result.description);
        System.assertEquals(false, result.isCustomerExist);
    }

    @IsTest
    static void checkUserExist_shouldHandleBlankResponseBody() {
        Test.setMock(
            HttpCalloutMock.class,
            new MobileAppHttpMock(
                'GET',
                204,
                '',
                false,
                false,
                false
            )
        );

        Test.startTest();
        FEC_MobileAppNotificationCallout.CheckUserResponse result =
            FEC_MobileAppNotificationCallout.checkUserExist(
                '0971953842',
                'NID123'
            );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(204, result.httpStatusCode);
        System.assertEquals('', result.rawResponse);
        System.assertEquals(null, result.code);
        System.assertEquals(null, result.description);
        System.assertEquals(null, result.transId);
        System.assertEquals(null, result.isCustomerExist);
    }

    @IsTest
    static void checkUserExist_shouldHandleServerErrorResponse() {
        Test.setMock(
            HttpCalloutMock.class,
            new MobileAppHttpMock(
                'GET',
                500,
                buildResponseBody('999', 'INTERNAL_SERVER_ERROR', 'TRANS_CHECK_500'),
                false,
                false,
                false
            )
        );

        Test.startTest();
        FEC_MobileAppNotificationCallout.CheckUserResponse result =
            FEC_MobileAppNotificationCallout.checkUserExist(
                '0971953842',
                'NID123'
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(500, result.httpStatusCode);
        System.assertEquals('999', result.code);
        System.assertEquals('INTERNAL_SERVER_ERROR', result.description);
        System.assertEquals(false, result.isCustomerExist);
    }

    @IsTest
    static void checkUserExist_shouldHandleCalloutException() {
        Test.setMock(
            HttpCalloutMock.class,
            new MobileAppHttpMock(
                'GET',
                599,
                null,
                true,
                false,
                false
            )
        );

        Test.startTest();
        FEC_MobileAppNotificationCallout.CheckUserResponse result =
            FEC_MobileAppNotificationCallout.checkUserExist(
                '0971953842',
                'NID123'
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(599, result.httpStatusCode);
        System.assertEquals('CALLOUT_ERROR', result.description);
        System.assertEquals(false, result.isCustomerExist);
        System.assert(
            result.rawResponse.contains('Simulated timeout'),
            'Raw response should contain exception message.'
        );

        System.assertEquals(
            null,
            FEC_MobileAppNotificationCallout.responseLogCheckUserExist,
            'Static response log should be cleared after exception logging.'
        );
    }

    @IsTest
    static void sendNotification_shouldReturnSentSuccess_whenApiReturnsSuccess() {
        Test.setMock(
            HttpCalloutMock.class,
            new MobileAppHttpMock(
                'POST',
                200,
                buildResponseBody('1', 'SUCCESS', 'TRANS_PUSH_SUCCESS'),
                false,
                false,
                true
            )
        );

        Test.startTest();
        FEC_MobileAppNotificationCallout.SendNotificationResponse result =
            FEC_MobileAppNotificationCallout.sendNotification(
                'Hello content',
                'NID123',
                '+84971953842',
                'Hello title'
            );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(200, result.httpStatusCode);
        System.assertEquals('1', result.code);
        System.assertEquals('SUCCESS', result.description);
        System.assertEquals('TRANS_PUSH_SUCCESS', result.transId);
        System.assertEquals(true, result.isSentSuccess);
        System.assertNotEquals(null, result.rawResponse);

        System.assertEquals(
            null,
            FEC_MobileAppNotificationCallout.responseLogPushNotification,
            'Static response log should be cleared after logging.'
        );
    }

    @IsTest
    static void sendNotification_shouldReturnFalse_whenApiReturnsFailureDescription() {
        Test.setMock(
            HttpCalloutMock.class,
            new MobileAppHttpMock(
                'POST',
                200,
                buildResponseBody('0', 'FAILED', 'TRANS_PUSH_FAILED'),
                false,
                false,
                false
            )
        );

        Test.startTest();
        FEC_MobileAppNotificationCallout.SendNotificationResponse result =
            FEC_MobileAppNotificationCallout.sendNotification(
                'Hello content',
                'NID123',
                '0971953842',
                'Hello title'
            );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(200, result.httpStatusCode);
        System.assertEquals('0', result.code);
        System.assertEquals('FAILED', result.description);
        System.assertEquals(false, result.isSentSuccess);
    }

    @IsTest
    static void sendNotification_shouldHandleBlankResponseBody() {
        Test.setMock(
            HttpCalloutMock.class,
            new MobileAppHttpMock(
                'POST',
                204,
                '',
                false,
                false,
                false
            )
        );

        Test.startTest();
        FEC_MobileAppNotificationCallout.SendNotificationResponse result =
            FEC_MobileAppNotificationCallout.sendNotification(
                'Hello content',
                'NID123',
                '0971953842',
                'Hello title'
            );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(204, result.httpStatusCode);
        System.assertEquals('', result.rawResponse);
        System.assertEquals(null, result.code);
        System.assertEquals(null, result.description);
        System.assertEquals(null, result.transId);
        System.assertEquals(null, result.isSentSuccess);
    }

    @IsTest
    static void sendNotification_shouldHandleServerErrorResponse() {
        Test.setMock(
            HttpCalloutMock.class,
            new MobileAppHttpMock(
                'POST',
                500,
                buildResponseBody('999', 'INTERNAL_SERVER_ERROR', 'TRANS_PUSH_500'),
                false,
                false,
                false
            )
        );

        Test.startTest();
        FEC_MobileAppNotificationCallout.SendNotificationResponse result =
            FEC_MobileAppNotificationCallout.sendNotification(
                'Hello content',
                'NID123',
                '0971953842',
                'Hello title'
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(500, result.httpStatusCode);
        System.assertEquals('999', result.code);
        System.assertEquals('INTERNAL_SERVER_ERROR', result.description);
        System.assertEquals(false, result.isSentSuccess);
    }

    @IsTest
    static void sendNotification_shouldHandleCalloutException() {
        Test.setMock(
            HttpCalloutMock.class,
            new MobileAppHttpMock(
                'POST',
                599,
                null,
                true,
                false,
                false
            )
        );

        Test.startTest();
        FEC_MobileAppNotificationCallout.SendNotificationResponse result =
            FEC_MobileAppNotificationCallout.sendNotification(
                'Hello content',
                'NID123',
                '0971953842',
                'Hello title'
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(599, result.httpStatusCode);
        System.assertEquals('CALLOUT_ERROR', result.description);
        System.assertEquals(false, result.isSentSuccess);
        System.assert(
            result.rawResponse.contains('Simulated timeout'),
            'Raw response should contain exception message.'
        );

        System.assertEquals(
            null,
            FEC_MobileAppNotificationCallout.responseLogPushNotification,
            'Static response log should be cleared after exception logging.'
        );
    }
}