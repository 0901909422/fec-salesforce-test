@IsTest
private class FEC_BixIngestCallout_Test {

    /* ============================================================
     * MOCK CALLOUT: Giả lập phản hồi API BIX thành công (HTTP 200)
     * ============================================================ */
    private class MockSuccessCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status": "success", "message": "Data ingested successfully"}');
            return res;
        }
    }

    /* ============================================================
     * MOCK CALLOUT: Giả lập phản hồi lỗi nghiệp vụ từ API (HTTP 400)
     * ============================================================ */
    private class MockBadRequestCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status": "fail", "error": "Invalid JSON format"}');
            return res;
        }
    }

    /* ============================================================
     * MOCK CALLOUT: Giả lập lỗi mất kết nối mạng đột ngột (Ném Exception)
     * ============================================================ */
    private class MockExceptionCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Read timed out or connection refused');
        }
    }

    private static Boolean isBixIngestEndpointConfigured() {
        FEC_API_Config__mdt cfg = FEC_API_Config__mdt.getInstance(FEC_BixIngestCallout.API_CONFIG_NAME);
        return cfg != null && String.isNotBlank(cfg.FEC_Endpoint__c);
    }

    private static void assertMissingEndpointConfig(CalloutException e) {
        System.assertNotEquals(null, e.getMessage(), 'Phải có thông báo lỗi khi thiếu cấu hình API.');
        System.assert(
            e.getMessage().contains('Endpoint') || e.getMessage().contains('null'),
            'Lỗi phải báo endpoint chưa cấu hình. Actual: ' + e.getMessage()
        );
    }

    /**
     * Kịch bản 1: Gọi hàm gửi yêu cầu sendRequest thành công (HTTP 200).
     */
    @IsTest
    static void testSendRequest_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        String samplePayload = '{"leadId": "00Qxxxxxxxxxxxx", "score": 85}';

        Test.startTest();
        if (!isBixIngestEndpointConfigured()) {
            try {
                FEC_BixIngestCallout.sendRequest(samplePayload);
                System.assert(false, 'Phải ném CalloutException khi chưa deploy FEC_API_Config.FEC_BIX_Ingest.');
            } catch (CalloutException e) {
                assertMissingEndpointConfig(e);
            }
        } else {
            FEC_BixIngestCallout.BixIngestResult result = FEC_BixIngestCallout.sendRequest(samplePayload);
            System.assertNotEquals(null, result, 'Kết quả trả về không được rỗng.');
            System.assertEquals(true, result.isSuccess, 'Trường isSuccess phải bằng true khi HTTP Status là 200.');
            System.assertEquals(200, result.httpStatusCode, 'Mã trạng thái phản hồi phải ghi nhận là 200.');
            System.assert(result.responseBody.contains('success'), 'Nội dung phản hồi thô thu được phải chính xác.');
            System.assertEquals(null, result.errorMessage, 'Không được có lỗi ghi nhận khi gọi thành công.');
        }
        Test.stopTest();
    }

    /**
     * Kịch bản 2: Gọi hàm sendRequest phát sinh lỗi nghiệp vụ từ hệ thống đích (HTTP 400).
     */
    @IsTest
    static void testSendRequest_BadRequestError() {
        Test.setMock(HttpCalloutMock.class, new MockBadRequestCallout());
        String samplePayload = '{"corruptedData": true}';

        Test.startTest();
        if (!isBixIngestEndpointConfigured()) {
            try {
                FEC_BixIngestCallout.sendRequest(samplePayload);
                System.assert(false, 'Phải ném CalloutException khi chưa deploy FEC_API_Config.FEC_BIX_Ingest.');
            } catch (CalloutException e) {
                assertMissingEndpointConfig(e);
            }
        } else {
            FEC_BixIngestCallout.BixIngestResult result = FEC_BixIngestCallout.sendRequest(samplePayload);
            System.assertNotEquals(null, result);
            System.assertEquals(false, result.isSuccess, 'Trường isSuccess phải bằng false khi gặp HTTP 400.');
            System.assertEquals(400, result.httpStatusCode);
            System.assertNotEquals(null, result.errorMessage, 'Hệ thống phải sinh chuỗi thông báo lỗi.');
            System.assert(result.errorMessage.contains('HTTP 400'), 'Thông báo lỗi phải hiển thị rõ mã HTTP 400.');
        }
        Test.stopTest();
    }

    /**
     * Kịch bản 3: Gặp sự cố kết nối mạng / Timeout (khối catch trong sendRequest).
     */
    @IsTest
    static void testSendRequest_ConnectionTimeoutException() {
        Test.setMock(HttpCalloutMock.class, new MockExceptionCallout());

        Test.startTest();
        if (!isBixIngestEndpointConfigured()) {
            try {
                FEC_BixIngestCallout.sendRequest('{}');
                System.assert(false, 'Phải ném CalloutException khi chưa deploy FEC_API_Config.FEC_BIX_Ingest.');
            } catch (CalloutException e) {
                assertMissingEndpointConfig(e);
            }
        } else {
            FEC_BixIngestCallout.BixIngestResult result = FEC_BixIngestCallout.sendRequest('{}');
            System.assertNotEquals(null, result);
            System.assertEquals(false, result.isSuccess, 'Gặp lỗi Exception kết nối thì isSuccess bắt buộc phải là false.');
            System.assertEquals(
                'Read timed out or connection refused',
                result.errorMessage,
                'Thông báo lỗi lưu lại phải khớp với mã ngoại lệ.'
            );
        }
        Test.stopTest();
    }

    /**
     * Kịch bản 4: Kiểm tra resolveEndpoint — metadata có hoặc thiếu trên org.
     */
    @IsTest
    static void testResolveEndpoint_MetadataFlow() {
        Test.startTest();
        if (!isBixIngestEndpointConfigured()) {
            try {
                FEC_BixIngestCallout.resolveEndpoint();
                System.assert(false, 'Phải ném CalloutException khi chưa deploy FEC_API_Config.FEC_BIX_Ingest.');
            } catch (CalloutException e) {
                assertMissingEndpointConfig(e);
            }
        } else {
            String url = FEC_BixIngestCallout.resolveEndpoint();
            System.assert(url.startsWith('callout:FEC_API'), 'Endpoint phải đi qua Named Credential FEC_API.');
            System.assert(url.contains('/api/v1/bix/ingest_bix'), 'Endpoint phải khớp Custom Metadata FEC_BIX_Ingest.');
        }
        Test.stopTest();
    }
}
