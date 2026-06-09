@IsTest
private class FEC_GetCardSecInfo_Test {

    // XML mẫu giả lập Response SOAP phức tạp
    private static final String MOCK_XML_RESPONSE = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetCardSecInfoResponse>' +
        '      <Sys><TransID>TXN123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
        '      <CardSecInfo>' +
        '        <MainCardProduct><PurchaseLimit>50000000</PurchaseLimit></MainCardProduct>' +
        '        <IPPs>' +
        '          <IPP>' +
        '            <IPPPlan>TestPlan</IPPPlan>' +
        '            <OPENING_BALANCE_1>1000000</OPENING_BALANCE_1>' +
        '          </IPP>' +
        '        </IPPs>' +
        '        <FinancialTransactions>' +
        '           <FinancialTransaction>' +
        '               <Description>Payment Test</Description>' +
        '               <TRNXAmount>200000</TRNXAmount>' +
        '           </FinancialTransaction>' +
        '        </FinancialTransactions>' +
        '      </CardSecInfo>' +
        '    </GetCardSecInfoResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallGetCardSecInfo_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_RESPONSE));

        Test.startTest();
        FEC_GetCardSecInfo.ResponseWrapper res = FEC_GetCardSecInfo.callGetCardSecInfo(
            'TXN12345678901234567890123456789012', 
            FEC_ConstantCommon.REQUESTOR_CRM,
            '2026-05-22 10:00:00',
            'ACC123',
            false
        );
        Test.stopTest();

        System.assertEquals(1, res.Sys.Code);
        System.assertNotEquals(null, res.CardSecInfo.MainCardProduct);
        System.assertEquals(50000000, res.CardSecInfo.MainCardProduct.PurchaseLimit);
        System.assertEquals(1, res.CardSecInfo.IPPs.size());
        System.assertEquals(1000000, res.CardSecInfo.IPPs[0].OpeningBalance);
        System.assertEquals(1, res.CardSecInfo.FinancialTransactions.size());
    }

    @IsTest
    static void testValidateRequest_ThrowsException() {
        Test.startTest();
        try {
            // Test lỗi validation do AccountNumber quá dài (>255)
            FEC_GetCardSecInfo.callGetCardSecInfo('TXN1', FEC_ConstantCommon.REQUESTOR_CRM, '2026-05-22 10:00:00', 'A'.repeat(256), false);
            System.assert(false, 'Phải ném ngoại lệ khi AccountNumber quá dài.');
        } catch (CalloutException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetCardSecInfo_Wrapper() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_RESPONSE));

        Test.startTest();
        FEC_GetCardSecInfo.ResponseWrapper res = FEC_GetCardSecInfo.getCardSecInfo('ACC123');
        FEC_GetCardSecInfo.logApiResponse();
        Test.stopTest();

        System.assertEquals(1, res.Sys.Code);
        System.assertNotEquals(null, res.CardSecInfo);
    }

    @IsTest
    static void testCallGetCardSecInfo_RichXmlSummaryAndScheduleIPP() {
        String richXml =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '  <soapenv:Body><GetCardSecInfoResponse>' +
            '    <Sys><TransID>TXN123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
            '    <CardSecInfo>' +
            '      <MainCardProduct><PurchaseLimit>50000000</PurchaseLimit><DailyRetailLimit>1000</DailyRetailLimit>' +
            '<CashLimit>2000</CashLimit><Rate>1.5</Rate></MainCardProduct>' +
            '      <CardFullPayment><DailyInterestCard>1</DailyInterestCard><CardPrincipal>2</CardPrincipal></CardFullPayment>' +
            '      <MainCardPlastic><EmbossingName>TEST</EmbossingName><EcomActiveFlag>1</EcomActiveFlag></MainCardPlastic>' +
            '      <MainCardBalance><CurrentBalance>200</CurrentBalance></MainCardBalance>' +
            '      <PassDue><ResponsibleUnit>Unit1</ResponsibleUnit></PassDue>' +
            '      <SupplementaryCards><SupplementaryCard><CardNumber>SC1</CardNumber></SupplementaryCard></SupplementaryCards>' +
            '      <CardsDeliveries><CardsDelivery><CardNumber>CD1</CardNumber></CardsDelivery></CardsDeliveries>' +
            '      <IPPs>' +
            '        <IPP><IPPPlan>SchedulePlan</IPPPlan><IPPRecordNo>REC1</IPPRecordNo><Term>12</Term>' +
            '<CurrentTerm>2</CurrentTerm><IPPOpenDate>2026-01-01</IPPOpenDate><OPENING_BALANCE_1>1000000</OPENING_BALANCE_1>' +
            '<PAYMENT_AMT_1>100</PAYMENT_AMT_1></IPP>' +
            '        <IPP><IPPPlan>SummaryPlan</IPPPlan><IPPRecordNo>REC2</IPPRecordNo><Term>6</Term>' +
            '<OpenDate>2026-02-01</OpenDate><IPPBalance>5000</IPPBalance><PaymentAmount>200</PaymentAmount></IPP>' +
            '      </IPPs>' +
            '      <CardStatements><CardStatement><MPA>100</MPA><TotalPaymentDue>50</TotalPaymentDue></CardStatement></CardStatements>' +
            '      <FinancialTransactions><FinancialTransaction><Description>Payment</Description>' +
            '<TRNXAmount>200000</TRNXAmount></FinancialTransaction></FinancialTransactions>' +
            '    </CardSecInfo></GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>';

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, richXml));

        Test.startTest();
        FEC_GetCardSecInfo.ResponseWrapper res = FEC_GetCardSecInfo.callGetCardSecInfo(
            'TXN12345678901234567890123456789012',
            FEC_ConstantCommon.REQUESTOR_CRM,
            '2026-05-22 10:00:00',
            'ACC123',
            false
        );
        Test.stopTest();

        System.assertEquals(2, res.CardSecInfo.IPPs.size());
        System.assertEquals('SchedulePlan', res.CardSecInfo.IPPs[0].IPPPlan);
        System.assertEquals(12, res.CardSecInfo.IPPs[0].term);
        System.assertEquals('2026-01-01', res.CardSecInfo.IPPs[0].IPPOpenDate);
        System.assertEquals('SummaryPlan', res.CardSecInfo.IPPs[1].IPPPlan);
        System.assertEquals('2026-02-01', res.CardSecInfo.IPPs[1].IPPOpenDate);
        System.assertEquals(1, res.CardSecInfo.CardStatements.size());
        System.assertNotEquals(null, res.CardSecInfo.CardFullPayment);
        System.assertNotEquals(null, res.CardSecInfo.SupplementaryCards);
    }

    @IsTest
    static void testCallGetCardSecInfo_IsTestApiAndHttpError() {
        Test.startTest();
        try {
            FEC_GetCardSecInfo.callGetCardSecInfo(
                'TXN12345678901234567890123456789012',
                FEC_ConstantCommon.REQUESTOR_CRM,
                '2026-05-22 10:00:00',
                'ACC123',
                true
            );
            System.assert(false, 'isTestApi=true phải ném CalloutException.');
        } catch (CalloutException ex) {
            System.assert(true);
        }

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'error'));
        try {
            FEC_GetCardSecInfo.callGetCardSecInfo(
                'TXN12345678901234567890123456789012',
                FEC_ConstantCommon.REQUESTOR_CRM,
                '2026-05-22 10:00:00',
                'ACC123',
                false
            );
            System.assert(false, 'HTTP 500 phải ném CalloutException.');
        } catch (CalloutException ex) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testCallGetCardSecInfo_ApiErrorCode() {
        String errorXml =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '  <soapenv:Body><GetCardSecInfoResponse>' +
            '    <Sys><Code>99</Code><Description>API failed</Description></Sys>' +
            '  </GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, errorXml));

        Test.startTest();
        try {
            FEC_GetCardSecInfo.callGetCardSecInfo(
                'TXN12345678901234567890123456789012',
                FEC_ConstantCommon.REQUESTOR_CRM,
                '2026-05-22 10:00:00',
                'ACC123',
                false
            );
            System.assert(false, 'Sys.Code != 1 phải ném CalloutException.');
        } catch (CalloutException ex) {
            System.assert(true);
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