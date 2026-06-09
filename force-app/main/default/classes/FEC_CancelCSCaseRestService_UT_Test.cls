@IsTest
private class FEC_CancelCSCaseRestService_UT_Test {
    private static final String REQUEST_XML =
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soap:Body>' +
        '<CancelCSCaseRequest xmlns="urn:PegaRULES:SOAP:MyCase:Services">' +
        '<Sys><Channel>Inbound</Channel><TransactionID>UT-TXN-001</TransactionID><DateTime>2026-06-01T00:00:00.000Z</DateTime></Sys>' +
        '<CaseInfo><ContractOrAccountNumber>UT-ACC-001</ContractOrAccountNumber><PhoneNumber>0900000001</PhoneNumber><CaseID>UT-CS-REST-001</CaseID><UserType>Existing</UserType></CaseInfo>' +
        '</CancelCSCaseRequest>' +
        '</soap:Body>' +
        '</soap:Envelope>';

    private static RestResponse invokeWithBody(String body) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/CancelCSCase';
        req.httpMethod = 'POST';
        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }
        RestContext.request = req;
        RestContext.response = res;
        FEC_CancelCSCaseRestService.doPost();
        return res;
    }

    @IsTest
    static void testDoPostBlankBodyReturnsBadRequest() {
        Test.startTest();
        RestResponse res = invokeWithBody(null);
        Test.stopTest();

        String body = res.responseBody != null ? res.responseBody.toString() : '';
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST, res.statusCode);
        System.assert(body.contains('CancelCSCaseResponse'));
    }

    @IsTest
    static void testDoPostMalformedXmlReturnsBadRequest() {
        String invalidButParsableXml =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body></soap:Body>' +
            '</soap:Envelope>';
        Test.startTest();
        RestResponse res = invokeWithBody(invalidButParsableXml);
        Test.stopTest();
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST, res.statusCode);
        System.assert(res.responseBody.toString().contains('CancelCSCaseResponse'));
    }

    @IsTest
    static void testDoPostValidXmlCancelsCase() {
        Test.startTest();
        RestResponse res = invokeWithBody(REQUEST_XML);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, res.statusCode);
        System.assert(res.responseBody.toString().contains('CancelCSCaseResponse'));
    }
}
