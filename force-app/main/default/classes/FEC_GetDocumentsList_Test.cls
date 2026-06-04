@IsTest
private class FEC_GetDocumentsList_Test {

    // =========================================================================
    // DỮ LIỆU MOCK XML
    // =========================================================================
    
    // Mock XML cho trường hợp Thành công (Code = 1)
    private static final String MOCK_XML_SUCCESS = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetDocumentsListResponse>' +
        '      <Sys>' +
        '        <TransID>TXN12345</TransID>' +
        '        <DateTime>2026-01-17 10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <CIFNumber>CIF999</CIFNumber>' +
        '      <Documents>' +
        '        <Document>' +
        '          <DocumentID>DOC001</DocumentID>' +
        '          <DocumentType>ID_CARD</DocumentType>' +
        '          <IssueDate>2020-01-01</IssueDate>' +
        '          <IDDocumentNumber>079123456789</IDDocumentNumber>' +
        '          <IssuePlace>Hanoi</IssuePlace>' +
        '          <OmnidocsLink>https://omnidocs.test/doc001</OmnidocsLink>' +
        '        </Document>' +
        '      </Documents>' +
        '    </GetDocumentsListResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    // Mock XML cho trường hợp Lỗi Logic API (Code != 1)
    private static final String MOCK_XML_API_ERROR = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetDocumentsListResponse>' +
        '      <Sys>' +
        '        <TransID>TXN12345</TransID>' +
        '        <DateTime>2026-01-17 10:00:00</DateTime>' +
        '        <Code>0</Code>' +
        '        <Description>CIF not found</Description>' +
        '      </Sys>' +
        '    </GetDocumentsListResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    // =========================================================================
    // TEST CASES
    // =========================================================================

    @IsTest
    static void testCallGetDocumentsList_Success() {
        // 1. Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        // 2. Gọi hàm chính
        Test.startTest();
        FEC_GetDocumentsList.ResponseWrapper res = FEC_GetDocumentsList.callGetDocumentsList(
            'TXN123456789', 
            FEC_ConstantCommon.REQUESTOR_CRM, 
            '2026-01-17 10:00:00',
            'CIF999'
        );
        Test.stopTest();

        // 3. Xác thực kết quả
        System.assertNotEquals(null, res, 'Kết quả không được null.');
        System.assertEquals(1, res.Sys.Code, 'Mã Code trả về phải là 1.');
        System.assertEquals('CIF999', res.CIFNumber, 'CIF Number phải khớp.');
        System.assertEquals(1, res.Documents.size(), 'Phải parse được 1 document.');
        
        System.assertEquals('DOC001', res.Documents[0].DocumentID);
        System.assertEquals('ID_CARD', res.Documents[0].DocumentType);
        System.assertEquals('079123456789', res.Documents[0].IDDocumentNumber);
    }

    @IsTest
    static void testCallGetDocumentsList_HttpError() {
        // Giả lập lỗi HTTP 500 từ Server
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        try {
            FEC_GetDocumentsList.callGetDocumentsList(
                'TXN123', FEC_ConstantCommon.REQUESTOR_CRM, '2026-01-17 10:00:00', 'CIF123'
            );
            System.assert(false, 'Phải throw CalloutException khi HTTP Status != 200.');
        } catch (CalloutException e) {
            System.assert(true, 'Bắt đúng Exception.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testCallGetDocumentsList_ApiError() {
        // Giả lập API gọi thành công (HTTP 200) nhưng trả về Code = 0
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_API_ERROR));

        Test.startTest();
        try {
            FEC_GetDocumentsList.callGetDocumentsList(
                'TXN123', FEC_ConstantCommon.REQUESTOR_CRM, '2026-01-17 10:00:00', 'CIF123'
            );
            System.assert(false, 'Phải throw CalloutException khi Sys.Code != 1.');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('CIF not found'), 'Thông báo lỗi phải chứa Description từ XML.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateRequest_Errors() {
        Test.startTest();
        
        // 1. Lỗi TransId rỗng
        try {
            FEC_GetDocumentsList.callGetDocumentsList('', FEC_ConstantCommon.REQUESTOR_CRM, '2026-01-17 10:00:00', 'CIF123');
            System.assert(false, 'Phải báo lỗi khi TransID rỗng.');
        } catch (CalloutException e) { System.assert(true); }

        // 2. Lỗi RequestorID không hợp lệ
        try {
            FEC_GetDocumentsList.callGetDocumentsList('TXN1', 'INVALID_REQ', '2026-01-17 10:00:00', 'CIF123');
            System.assert(false, 'Phải báo lỗi khi RequestorID không hợp lệ.');
        } catch (CalloutException e) { System.assert(true); }

        // 3. Lỗi DateTime sai định dạng
        try {
            FEC_GetDocumentsList.callGetDocumentsList('TXN1', FEC_ConstantCommon.REQUESTOR_CRM, 'invalid_date', 'CIF123');
            System.assert(false, 'Phải báo lỗi khi DateTime sai định dạng.');
        } catch (CalloutException e) { System.assert(true); }

        // 4. Lỗi CIFNumber rỗng
        try {
            FEC_GetDocumentsList.callGetDocumentsList('TXN1', FEC_ConstantCommon.REQUESTOR_CRM, '2026-01-17 10:00:00', '');
            System.assert(false, 'Phải báo lỗi khi CIFNumber rỗng.');
        } catch (CalloutException e) { System.assert(true); }

        Test.stopTest();
    }

    // =========================================================================
    // HELPER CLASS MOCK HTTP RESPONSE
    // =========================================================================
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer statusCode;
        String responseBody;
        
        MockHttpResponseGenerator(Integer statusCode, String responseBody) { 
            this.statusCode = statusCode; 
            this.responseBody = responseBody; 
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.responseBody);
            return res;
        }
    }
}