@IsTest
private class FEC_GetCustomerList_Test {

    // XML mẫu giả lập phản hồi SOAP của dịch vụ
    private static final String MOCK_SOAP_RESPONSE = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <cif:GetCustomerListResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
        '      <Sys>' +
        '        <TransID>TXN123</TransID>' +
        '        <DateTime>2026-05-25 10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <Count>1</Count>' +
        '      <Customers>' +
        '        <Customer>' +
        '          <CIFNumber>CIF001</CIFNumber>' +
        '          <FullName>Nguyen Van A</FullName>' +
        '          <DateOfBirth>1990-01-01</DateOfBirth>' +
        '          <Phones>' +
        '            <PhoneNode><Type>Mobile</Type><Phone>0901234567</Phone></PhoneNode>' +
        '          </Phones>' +
        '          <Emails>' +
        '            <Email>test@example.com</Email>' +
        '          </Emails>' +
        '          <Applications>' +
        '            <Application>' +
        '              <ApplicationID>APP123</ApplicationID>' +
        '              <Product>Credit Card</Product>' +
        '            </Application>' +
        '          </Applications>' +
        '          <Addresses>' +
        '            <Address>' +
        '              <AddressType>Home</AddressType>' +
        '              <City>Hanoi</City>' +
        '            </Address>' +
        '          </Addresses>' +
        '        </Customer>' +
        '      </Customers>' +
        '    </cif:GetCustomerListResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @TestSetup
    static void setupData() {
        // Thiết lập Custom Setting để test logic map email trong môi trường Non-Production
        FEC_API_Setting__c apiSetting = new FEC_API_Setting__c(
            FEC_Enviroment__c = FEC_ConstantCommon.ENVIROMENT_NON_PRODUCTION,
            FEC_Call_Mock__c = false,
            FEC_Endpoint__c = 'https://test.com/api'
        );
        insert apiSetting;
    }

    @IsTest
    static void testGetCustomerList_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_SOAP_RESPONSE));
        
        Test.startTest();
        // Gọi hàm với tham số hợp lệ
        FEC_GetCustomerList.ResponseWrapper res = FEC_GetCustomerList.getCustomerList(
            FEC_ConstantCommon.REQUESTOR_CRM, // requestorId
            '0901234567', // phoneNumber
            true, // isReferenceSearch
            null, // fullName
            null, // nationalId
            null, // applicationId
            null, // creditCardNumber
            null, // accountNumber
            null, // contractNumber
            null, // email
            null  // personId
        );
        Test.stopTest();
        
        // Xác thực kết quả
        System.assertNotEquals(null, res, 'Kết quả không được null');
        System.assertEquals('1', res.Sys.Code, 'Mã Code trả về phải là 1.');
        System.assertEquals(1, res.Count, 'Count = 1');
        System.assertEquals(1, res.Customers.size(), 'Phải parse được 1 customer.');
        
        FEC_GetCustomerList.Customer cust = res.Customers[0];
        System.assertEquals('CIF001', cust.CIFNumber);
        System.assertEquals('0901234567', cust.Phones[0].Phone);
        System.assertEquals('test@example.com', cust.Emails[0].Email);
        System.assertEquals('APP123', cust.Applications[0].ApplicationID);
        System.assertEquals('Hanoi', cust.Addresses[0].City);
    }

    @IsTest
    static void testGetCustomerList_NonProdEmailMapping() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_SOAP_RESPONSE));
        
        Test.startTest();
        // Gọi hàm với email đặc biệt để test logic override accountNumber
        FEC_GetCustomerList.ResponseWrapper res = FEC_GetCustomerList.getCustomerList(
            FEC_ConstantCommon.REQUESTOR_CRM, 
            null, false, null, null, null, null, null, null, 
            'huyen.nguyen.7@fecredit.com.vn', // email
            null
        );
        Test.stopTest();
        
        System.assertNotEquals(null, res, 'API call thành công kể cả khi dùng mapped email.');
    }

    @IsTest
    static void testValidateRequest_Errors() {
        Test.startTest();
        
        // Test lỗi TransId (giả lập thông qua requestorId null)
        try {
            FEC_GetCustomerList.validate('TXN123', null, '2026-05-25 10:00:00', null, null, null, null, null, null, null);
            System.assert(false, 'Phải ném exception khi requestorId null');
        } catch (CalloutException e) { System.assert(true); }

        // Test lỗi định dạng Email (Invalid format)
        try {
            FEC_GetCustomerList.validate('TXN123', FEC_ConstantCommon.REQUESTOR_CRM, '2026-05-25 10:00:00', null, null, null, null, null, 'invalid_email_format', null);
            System.assert(false, 'Phải ném exception khi email sai định dạng');
        } catch (CalloutException e) { System.assert(true); }

        // Test lỗi PersonId
        try {
            FEC_GetCustomerList.validate('TXN123', FEC_ConstantCommon.REQUESTOR_CRM, '2026-05-25 10:00:00', null, null, null, null, null, null, 'INVALID123');
            System.assert(false, 'Phải ném exception khi PersonId không bắt đầu bằng P');
        } catch (CalloutException e) { System.assert(true); }

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