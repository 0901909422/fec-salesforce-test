@IsTest
private class FEC_MockupEndpoint_Test {

    @IsTest
    static void testEndpointConstants() {
        // Kiểm tra một vài endpoint tiêu biểu để đảm bảo hằng số được định nghĩa
        System.assertNotEquals(null, FEC_MockupEndpoint.GET_CUSTOMER_LIST_ENDPOINT_MOCKUP);
        System.assertNotEquals(null, FEC_MockupEndpoint.EMEA_ACCOUNT_INQ_ENDPOINT_MOCKUP);
        System.assertNotEquals(null, FEC_MockupEndpoint.ADD_IPP_ENDPOINT_MOCKUP);

        // Kiểm tra định dạng cơ bản của URL
        System.assert(FEC_MockupEndpoint.GET_CUSTOMER_LIST_ENDPOINT_MOCKUP.startsWith('https://'), 
            'Endpoint phải bắt đầu bằng https://');
        
        // Kiểm tra độ dài tối thiểu để đảm bảo không phải chuỗi rỗng
        System.assert(FEC_MockupEndpoint.GET_CUSTOMER_LIST_ENDPOINT_MOCKUP.length() > 20, 
            'URL endpoint quá ngắn, có thể đã bị thay đổi sai.');
    }
}