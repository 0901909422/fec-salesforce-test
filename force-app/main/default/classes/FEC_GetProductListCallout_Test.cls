@IsTest
private class FEC_GetProductListCallout_Test {

    // XML mẫu giả lập Response SOAP thành công
    private static final String MOCK_XML_SUCCESS = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfo">' +
        '  <soapenv:Body>' +
        '    <cif:GetProductsListResponse>' +
        '      <Sys>' +
        '        <TransID>TXN123</TransID>' +
        '        <DateTime>2026-05-25 10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <CIFNumber>CIF999</CIFNumber>' +
        '      <Products>' +
        '        <Product>' +
        '          <ProductName>Credit Card</ProductName>' +
        '          <ProductType>CARD</ProductType>' +
        '          <ApplicationID>APP001</ApplicationID>' +
        '        </Product>' +
        '      </Products>' +
        '    </cif:GetProductsListResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallService_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        Test.startTest();
        // Gọi phương thức callService
        FEC_GetProductListCallout.CIF_GetProductsListResponse res = FEC_GetProductListCallout.callService('CIF999');
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals('1', res.code, 'Code trả về phải là 1 (thành công).');
        System.assertEquals('CIF999', res.cifNumber);
        System.assertEquals(1, res.products.size(), 'Phải có 1 sản phẩm được trả về.');
        System.assertEquals('Credit Card', res.products[0].productName);
        System.assertEquals('APP001', res.products[0].applicationId);
    }

    @IsTest
    static void testCallService_HttpError() {
        // Giả lập lỗi HTTP 500
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        try {
            FEC_GetProductListCallout.callService('CIF999');
            System.assert(false, 'Phải ném CalloutException khi status != 200.');
        } catch (CalloutException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testParseResponse_MissingNode() {
        String invalidXml =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body/></soapenv:Envelope>';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, invalidXml));

        Test.startTest();
        try {
            FEC_GetProductListCallout.callService('CIF999');
            System.assert(false, 'Phải ném Exception khi missing GetProductsListResponse.');
        } catch (CalloutException e) {
            System.assert(
                e.getMessage().contains('GetProductsListResponse'),
                'Actual: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    // Helper class để Mock HTTP Response
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer code; String body;
        MockHttpResponseGenerator(Integer code, String body) { this.code = code; this.body = body; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.code);
            res.setBody(this.body);
            return res;
        }
    }
}