@IsTest
private class FEC_EmeaAccountInqService_Test {

    private class EmeaAccountInqMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;

        EmeaAccountInqMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setBody(body);
            res.setStatusCode(statusCode);
            return res;
        }
    }

    private static final String MOCK_WS_RESPONSE =
        '<WSResponse>' +
        '  <Sys><TransID>123</TransID><Code>0</Code><Description>Success</Description></Sys>' +
        '  <M_CMS_EMEA_ACCOUNT_INQ>' +
        '    <VMX_ROOT>' +
        '      <VMX_MSGOUT>' +
        '        <SVC_RETURN>0</SVC_RETURN>' +
        '        <ACCT_BS_OUTPUT>' +
        '          <ACCT_NBR>123456789</ACCT_NBR>' +
        '          <SHORT_NAME>Test User</SHORT_NAME>' +
        '          <CUST_NBR>CIF001</CUST_NBR>' +
        '          <CURR_BAL>1000.50</CURR_BAL>' +
        '          <INCOME>5000</INCOME>' +
        '          <AMT_MEMO_DB>100</AMT_MEMO_DB>' +
        '          <AMT_MEMO_CR>50</AMT_MEMO_CR>' +
        '          <DT_OPENED>20200101</DT_OPENED>' +
        '          <INT_STAT>ACTIVE</INT_STAT>' +
        '          <AVAIL_CR>2000</AVAIL_CR>' +
        '          <BLK_CD_1>A</BLK_CD_1>' +
        '          <FAS_WARN_CD>' +
        '            <WARN_CD_X><WARN_CD>01</WARN_CD></WARN_CD_X>' +
        '          </FAS_WARN_CD>' +
        '          <NA_DATA_TBL>' +
        '            <NA_DATA>' +
        '              <NA_FIRST_NAME>John</NA_FIRST_NAME>' +
        '              <NA_MOB_PH>0901234567</NA_MOB_PH>' +
        '              <NA_CITY>Hanoi</NA_CITY>' +
        '            </NA_DATA>' +
        '          </NA_DATA_TBL>' +
        '        </ACCT_BS_OUTPUT>' +
        '      </VMX_MSGOUT>' +
        '    </VMX_ROOT>' +
        '  </M_CMS_EMEA_ACCOUNT_INQ>' +
        '</WSResponse>';

    private static final String MOCK_OLD_FORMAT_RESPONSE =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
        'xmlns:svc="http://fecredit.com.vn/CMS_VMXIntegrationWS">' +
        '  <soapenv:Body>' +
        '    <svc:M_CMS_EMEA_ACCOUNT_INQResponse>' +
        '      <Sys><TransID>OLD123</TransID><Code>0</Code><Description>Old Success</Description></Sys>' +
        '      <VMX_ROOT>' +
        '        <VMX_MSGOUT>' +
        '          <ACCT_BS_OUTPUT>' +
        '            <ACCT_NBR>987654321</ACCT_NBR>' +
        '            <CURR_BAL>2500.75</CURR_BAL>' +
        '            <SHORT_NAME>Legacy User</SHORT_NAME>' +
        '          </ACCT_BS_OUTPUT>' +
        '        </VMX_MSGOUT>' +
        '      </VMX_ROOT>' +
        '    </svc:M_CMS_EMEA_ACCOUNT_INQResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    private static FEC_EmeaAccountInqService.EmeaInput buildValidInput() {
        FEC_EmeaAccountInqService.EmeaInput input = new FEC_EmeaAccountInqService.EmeaInput();
        input.context = 'C01';
        input.name = 'Test';
        input.org = '150';
        input.account = '123456';
        input.dualInd = 'Y';
        input.vmxVersion = '1.0';
        return input;
    }

    @IsTest
    static void testCallAccountInquiry_Success() {
        Test.setMock(HttpCalloutMock.class, new EmeaAccountInqMock(200, MOCK_WS_RESPONSE));

        Test.startTest();
        FEC_EmeaAccountInqService.EmeaResult result =
            FEC_EmeaAccountInqService.callAccountInquiry(buildValidInput());
        Test.stopTest();

        System.assertEquals('123456789', result.acctNbr);
        System.assertEquals(1000.50, result.currBal);
        System.assertEquals('Test User', result.shortName);
        System.assertEquals('CIF001', result.custNbr);
        System.assertEquals(100, result.amtMemoDb);
        System.assertEquals(50, result.amtMemoCr);
        System.assertEquals('ACTIVE', result.intStat);
        System.assertEquals(2000, result.availCr);
        System.assertEquals('A', result.blkCd1);
        System.assertEquals(Date.newInstance(2020, 1, 1), result.dtOpened);
        System.assertEquals('John', result.naFirstName);
        System.assertEquals('0901234567', result.naMobPh);
        System.assertEquals('Hanoi', result.naCity);
        System.assertNotEquals(null, result.warnCodes);
        System.assert(result.warnCodeStr.contains('01'));
    }

    @IsTest
    static void testCallAccountInquiry_OldFormatResponse() {
        Test.setMock(HttpCalloutMock.class, new EmeaAccountInqMock(200, MOCK_OLD_FORMAT_RESPONSE));

        Test.startTest();
        FEC_EmeaAccountInqService.EmeaResult result =
            FEC_EmeaAccountInqService.callAccountInquiry(buildValidInput());
        Test.stopTest();

        System.assertEquals('987654321', result.acctNbr);
        System.assertEquals(2500.75, result.currBal);
        System.assertEquals('Legacy User', result.shortName);
        System.assertEquals('OLD123', result.transId);
    }

    @IsTest
    static void testCallAccountInquiry_Non200() {
        Test.setMock(HttpCalloutMock.class, new EmeaAccountInqMock(500, 'Server Error'));

        Test.startTest();
        try {
            FEC_EmeaAccountInqService.callAccountInquiry(buildValidInput());
            System.assert(false, 'Phải ném AuraHandledException khi HTTP != 200.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCallAccountInquiry_EmptyBody() {
        Test.setMock(HttpCalloutMock.class, new EmeaAccountInqMock(200, ''));

        Test.startTest();
        try {
            FEC_EmeaAccountInqService.callAccountInquiry(buildValidInput());
            System.assert(false, 'Phải ném AuraHandledException khi body rỗng.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateInput_ThrowsException() {
        FEC_EmeaAccountInqService.EmeaInput input = new FEC_EmeaAccountInqService.EmeaInput();

        Test.startTest();
        try {
            FEC_EmeaAccountInqService.callAccountInquiry(input);
            System.assert(false, 'Phải ném Exception khi thiếu input bắt buộc.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    private static final String MOCK_SOAP_ENVELOPE_RESPONSE =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
        'xmlns:v2="http://fecredit.com.vn/cms/ws/v2">' +
        '  <soapenv:Body>' +
        '    <v2:WSResponse>' +
        '      <Sys><TransID>ENV123</TransID><Code>0</Code><Description>Envelope OK</Description></Sys>' +
        '      <M_CMS_EMEA_ACCOUNT_INQ>' +
        '        <VMX_ROOT><VMX_MSGOUT>' +
        '          <ACCT_BS_OUTPUT>' +
        '            <ACCT_NBR>555666777</ACCT_NBR>' +
        '            <SHORT_NAME>Envelope User</SHORT_NAME>' +
        '            <CURR_BAL>99.99</CURR_BAL>' +
        '          </ACCT_BS_OUTPUT>' +
        '        </VMX_MSGOUT></VMX_ROOT>' +
        '      </M_CMS_EMEA_ACCOUNT_INQ>' +
        '    </v2:WSResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallAccountInquiry_SoapEnvelopeFormat() {
        Test.setMock(HttpCalloutMock.class, new EmeaAccountInqMock(200, MOCK_SOAP_ENVELOPE_RESPONSE));

        Test.startTest();
        FEC_EmeaAccountInqService.EmeaResult result =
            FEC_EmeaAccountInqService.callAccountInquiry(buildValidInput());
        Test.stopTest();

        System.assertEquals('555666777', result.acctNbr);
        System.assertEquals('Envelope User', result.shortName);
        System.assertEquals(99.99, result.currBal);
        System.assertEquals('ENV123', result.transId);
    }

    @IsTest
    static void testCallAccountInquiry_EmptyWsResponse() {
        Test.setMock(HttpCalloutMock.class, new EmeaAccountInqMock(200, '<Envelope><Body></Body></Envelope>'));

        Test.startTest();
        FEC_EmeaAccountInqService.EmeaResult result =
            FEC_EmeaAccountInqService.callAccountInquiry(buildValidInput());
        Test.stopTest();

        System.assertEquals(null, result.acctNbr);
        System.assertEquals(null, result.responseCode);
    }

    @IsTest
    static void testCallAccountInquiry_WithoutOptionalFields() {
        FEC_EmeaAccountInqService.EmeaInput input = buildValidInput();
        input.dualInd = null;
        input.vmxVersion = null;

        Test.setMock(HttpCalloutMock.class, new EmeaAccountInqMock(200, MOCK_WS_RESPONSE));
        Test.startTest();
        FEC_EmeaAccountInqService.EmeaResult result =
            FEC_EmeaAccountInqService.callAccountInquiry(input);
        Test.stopTest();

        System.assertEquals('123456789', result.acctNbr);
    }
}
