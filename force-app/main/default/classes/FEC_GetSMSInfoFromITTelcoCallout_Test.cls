@IsTest
private class FEC_GetSMSInfoFromITTelcoCallout_Test {

    // XML mẫu thành công (đã tìm thấy bản ghi)
    private static final String MOCK_XML_SUCCESS = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetSMSInfoFromITTelcoResponse xmlns="http://esbservice.fecredit.org/SMSLogWS/">' +
        '      <Sys>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '        <TransID>TXN123</TransID>' +
        '      </Sys>' +
        '      <Records>' +
        '        <Phone>0901234567</Phone>' +
        '        <SMSTemplateCode>OTP_01</SMSTemplateCode>' +
        '        <SMSTemplateContent>OTP cua ban la: 123456</SMSTemplateContent>' +
        '        <SentDates>' +
        '          <SentDate>2026-04-15 10:00:00</SentDate>' +
        '        </SentDates>' +
        '      </Records>' +
        '    </GetSMSInfoFromITTelcoResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @TestSetup
    static void setupData() {
        // Tạo cấu hình API để tránh lỗi NullPointerException khi gọi mdt
        // FEC_API_Setting__c và FEC_API_Config__mdt cần được giả lập qua Query hoặc cấu hình
    }

    @IsTest
    static void testGetSmsInfo_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        Test.startTest();
        // Gọi service
        FEC_GetSMSInfoFromITTelcoCallout.GetSMSInfoResult result = FEC_GetSMSInfoFromITTelcoCallout.getSmsInfoFromItTelco('0901234567');
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals(true, result.success, 'Kết quả phải thành công.');
        System.assertEquals(true, result.dataFound, 'DataFound phải là true.');
        System.assertEquals(1, result.records.size(), 'Phải parse được 1 bản ghi.');
        System.assertEquals('OTP_01', result.records[0].smsTemplateCode);
        System.assertEquals(1, result.records[0].sentDates.size());
    }

    @IsTest
    static void testGetSmsInfo_Validation_EmptyPhone() {
        Test.startTest();
        FEC_GetSMSInfoFromITTelcoCallout.GetSMSInfoResult result = FEC_GetSMSInfoFromITTelcoCallout.getSmsInfoFromItTelco('');
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(String.isNotBlank(result.errorMessage));
    }

    @IsTest
    static void testGetSmsInfo_HttpError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        FEC_GetSMSInfoFromITTelcoCallout.GetSMSInfoResult result = FEC_GetSMSInfoFromITTelcoCallout.getSmsInfoFromItTelco('0901234567');
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(500, result.httpStatus);
    }

    // Helper class để Mock HTTP Response
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer code; String body;
        MockHttpResponseGenerator(Integer code, String body) { this.code = code; this.body = body; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.code);
            res.setBody(this.body);
            res.setHeader('Content-Type', 'text/xml');
            return res;
        }
    }
}