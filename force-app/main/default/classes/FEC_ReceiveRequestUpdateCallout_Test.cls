@IsTest
private class FEC_ReceiveRequestUpdateCallout_Test {

    private static final String MOCK_RESPONSE_SUCCESS =
        '{' +
        '"pxObjClass":"FECredit-Int-CrdDlvry-ReceiveRequestUpdateResponse",' +
        '"Sys":{' +
        '"Code":"1",' +
        '"Description":"SUCCESS",' +
        '"pxObjClass":"FECredit-Int-",' +
        '"RequestDateTime":"2026-06-16T15:00:31.179857+07:00",' +
        '"TransID":"d1139f8e-04b2-455d-a5d6-16416915d0bb"' +
        '}' +
        '}';

    private class MockSuccessCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assert(
                req.getEndpoint() != null && req.getEndpoint().contains('ReceiveRequestUpdate'),
                'Endpoint phải ghép từ FEC_API_Setting__c + FEC_API_Config.ReceiveRequestUpdate.'
            );
            System.assertEquals('application/json', req.getHeader('Content-Type'));

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            System.assert(payload.containsKey('headers'), 'Request phải có headers.');
            System.assert(payload.containsKey('parameters'), 'Request phải có parameters.');
            System.assert(payload.containsKey('body'), 'Request phải có body.');

            Map<String, Object> body = (Map<String, Object>) payload.get('body');
            System.assertEquals('YES', body.get('Status'));
            System.assertEquals('1000093144949', body.get('OrderCode'));
            System.assertEquals('01', body.get('Status_Code'));
            System.assertEquals('PegaCSM', body.get('RequestorID'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(MOCK_RESPONSE_SUCCESS);
            return res;
        }
    }

    private class MockHttpErrorCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        insert new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://api-gateway.fecredit.com.vn'
        );
    }

    private static Boolean isEndpointConfigured() {
        FEC_API_Setting__c setting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt cfg = FEC_API_Config__mdt.getInstance(FEC_ReceiveRequestUpdateCallout.API_CONFIG_NAME);
        return String.isNotBlank(
            FEC_CommonUltils.buildCalloutEndpoint(setting?.FEC_Endpoint__c, cfg?.FEC_Endpoint__c)
        );
    }

    private static FEC_ReceiveRequestUpdateCallout.RequestBody buildSampleBody() {
        FEC_ReceiveRequestUpdateCallout.RequestBody body =
            new FEC_ReceiveRequestUpdateCallout.RequestBody();
        body.Status = 'YES';
        body.OrderCode = '1000093144949';
        body.requestDate = '2026-06-16T15:00:31';
        body.Status_Code = '01';
        body.Notes = '84888370193 + Số 39A Hà Huy Giáp, Phường An Phú Đông, Thành phố Hồ Chí Minh + đầu giờ chiều';
        body.RequestorID = FEC_ConstantCommon.REQUESTOR_PEGA_CSM;
        body.TransactionId = 'd1139f8e-04b2-455d-a5d6-16416915d0bb';
        return body;
    }

    @IsTest
    static void testSendRequest_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        Test.startTest();
        if (!isEndpointConfigured()) {
            try {
                FEC_ReceiveRequestUpdateCallout.sendRequest(buildSampleBody());
                System.assert(false, 'Phải ném CalloutException khi chưa deploy FEC_API_Config.ReceiveRequestUpdate.');
            } catch (CalloutException e) {
                System.assertNotEquals(null, e.getMessage());
            }
        } else {
            FEC_ReceiveRequestUpdateCallout.CalloutResult result =
                FEC_ReceiveRequestUpdateCallout.sendRequest(buildSampleBody());

            System.assertEquals(true, result.isSuccess);
            System.assertEquals(200, result.httpStatusCode);
            System.assertNotEquals(null, result.response);
            System.assertEquals('1', result.response.Sys.Code);
            System.assertEquals('SUCCESS', result.response.Sys.Description);
            System.assertEquals('d1139f8e-04b2-455d-a5d6-16416915d0bb', result.response.Sys.TransID);
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendRequest_OverloadedMethod() {
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        Test.startTest();
        if (isEndpointConfigured()) {
            FEC_ReceiveRequestUpdateCallout.CalloutResult result =
                FEC_ReceiveRequestUpdateCallout.sendRequest(
                    'YES',
                    '1000093144949',
                    '01',
                    'Test notes',
                    '2026-06-16T15:00:31'
                );
            System.assertEquals(true, result.isSuccess);
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendRequest_HttpError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpErrorCallout());

        Test.startTest();
        if (isEndpointConfigured()) {
            FEC_ReceiveRequestUpdateCallout.CalloutResult result =
                FEC_ReceiveRequestUpdateCallout.sendRequest(buildSampleBody());

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(500, result.httpStatusCode);
            System.assertNotEquals(null, result.errorMessage);
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateRequest_MissingOrderCode() {
        FEC_ReceiveRequestUpdateCallout.RequestBody body = buildSampleBody();
        body.OrderCode = null;

        try {
            FEC_ReceiveRequestUpdateCallout.sendRequest(body);
            System.assert(false, 'Phải báo lỗi khi thiếu OrderCode.');
        } catch (Exception e) {
            System.assert(
                e.getMessage().contains('OrderCode') || e.getMessage().contains('null'),
                'Actual: ' + e.getMessage()
            );
        }
    }

    @IsTest
    static void testResolveEndpoint_UsesApiSetting() {
        if (!isEndpointConfigured()) {
            return;
        }

        String endpoint = FEC_ReceiveRequestUpdateCallout.resolveEndpoint();
        System.assert(
            endpoint.startsWith('https://api-gateway.fecredit.com.vn'),
            'Endpoint phải lấy base từ FEC_API_Setting__c.'
        );
        System.assert(
            endpoint.contains('/esb/cms_247api_rest/v1/ReceiveRequestUpdate'),
            'Endpoint phải khớp metadata ReceiveRequestUpdate.'
        );
    }

    @IsTest
    static void testBuildRequest_Structure() {
        FEC_ReceiveRequestUpdateCallout.RequestWrapper request =
            FEC_ReceiveRequestUpdateCallout.buildRequest(buildSampleBody());

        System.assertNotEquals(null, request.headers);
        System.assertEquals('application/json', request.headers.get('Content-Type'));
        System.assertNotEquals(null, request.parameters);
        System.assertEquals(0, request.parameters.size());
        System.assertEquals('YES', request.body.Status);
    }

    @IsTest
    static void testIsSuccess() {
        FEC_ReceiveRequestUpdateCallout.ResponseWrapper response =
            (FEC_ReceiveRequestUpdateCallout.ResponseWrapper) JSON.deserialize(
                MOCK_RESPONSE_SUCCESS,
                FEC_ReceiveRequestUpdateCallout.ResponseWrapper.class
            );

        System.assertEquals(true, FEC_ReceiveRequestUpdateCallout.isSuccess(response));
    }
}