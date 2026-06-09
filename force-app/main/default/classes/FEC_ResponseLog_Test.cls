@IsTest
private class FEC_ResponseLog_Test {

    @IsTest
    static void testConstructorAndFields() {
        // 1. Chuẩn bị dữ liệu mẫu
        String apiName = 'FEC_TestAPI';
        String endpoint = 'https://api.test.com';
        String method = 'POST';
        String requestBody = '{"data": "test"}';
        String errorMessage = null;
        
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBody('{"status": "ok"}');

        Test.startTest();
        // 2. Khởi tạo đối tượng
        FEC_ResponseLog log = new FEC_ResponseLog(
            apiName, 
            endpoint, 
            method, 
            requestBody, 
            mockResponse, 
            errorMessage
        );
        Test.stopTest();

        // 3. Kiểm tra các giá trị được gán chính xác
        System.assertEquals(apiName, log.apiName, 'ApiName phải khớp.');
        System.assertEquals(endpoint, log.endpoint, 'Endpoint phải khớp.');
        System.assertEquals(method, log.method, 'Method phải khớp.');
        System.assertEquals(requestBody, log.requestBody, 'RequestBody phải khớp.');
        System.assertEquals(200, log.response.getStatusCode(), 'StatusCode của Response phải khớp.');
        System.assertEquals(errorMessage, log.errorMessage, 'ErrorMessage phải khớp.');
    }
}