@IsTest
private class FEC_CheckAccountEligibilityCallout_Test {

    // Mock lớp Callout để giả lập response từ server
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://esbservice.fecredit.org/CMS_RewardDebitWS/">' +
                '<soapenv:Body>' +
                '<ns1:CheckAccountEligibilityResponse>' +
                '   <SysResponse><TransID>123</TransID><Status>0</Status><Description>Success</Description></SysResponse>' +
                '   <CustomerName>Nguyen Van A</CustomerName>' +
                '   <Products>' +
                '       <Product><ID>1</ID><Name>Card</Name><Price>100000</Price></Product>' +
                '   </Products>' +
                '</ns1:CheckAccountEligibilityResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class MockHttp500ResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    private class MockHttpInvalidXmlResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<InvalidXML>');
            return res;
        }
    }

    @IsTest
    static void testCheckAccountEligibility_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        // Gọi hàm kiểm tra (đảm bảo môi trường đã có config setting)
        FEC_CheckAccountEligibilityCallout.CheckAccountEligibilityResult result = 
            FEC_CheckAccountEligibilityCallout.checkAccountEligibility('123456789');
        Test.stopTest();

        // Xác minh kết quả
        System.assertEquals(true, result.success, 'Kết quả gọi API phải thành công.');
        System.assertEquals('Nguyen Van A', result.customerName);
        System.assert(result.products.size() > 0, 'Phải có sản phẩm trả về.');
        System.assertEquals(100000, result.products[0].price);
    }

    @IsTest
    static void testCheckAccountEligibility_InvalidParam() {
        Test.startTest();
        // Truyền tham số rỗng để test nhánh chặn lỗi đầu vào
        FEC_CheckAccountEligibilityCallout.CheckAccountEligibilityResult result = 
            FEC_CheckAccountEligibilityCallout.checkAccountEligibility('');
        Test.stopTest();

        System.assertEquals(false, result.success);
    }

    @IsTest
    static void testCheckAccountEligibility_ApiError() {
        Test.setMock(HttpCalloutMock.class, new MockHttp500ResponseGenerator());

        Test.startTest();
        FEC_CheckAccountEligibilityCallout.CheckAccountEligibilityResult result = 
            FEC_CheckAccountEligibilityCallout.checkAccountEligibility('123456789');
        Test.stopTest();

        System.assertEquals(500, result.httpStatus);
        System.assertEquals(false, result.success);
    }

    @IsTest
    static void testCheckAccountEligibility_ParsingError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpInvalidXmlResponseGenerator());

        Test.startTest();
        FEC_CheckAccountEligibilityCallout.CheckAccountEligibilityResult result = 
            FEC_CheckAccountEligibilityCallout.checkAccountEligibility('123456789');
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.errorMessage.contains('Parsing Error'));
    }
}