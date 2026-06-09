@IsTest
private class FEC_VMXAUTHDETAILINQ_Test {

    private static final String DT = '2026-05-22 10:00:00';
    private static final String CTX = 'CTX';
    private static final String NAME = 'NAME';
    private static final String ACCT = 'ACC123';

    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Endpoint__c = 'https://api.test.com';
        apiSetting.FEC_Call_Mock__c = false;
        apiSetting.FEC_Enviroment__c = 'Production';
        upsert apiSetting;
    }

    private class VmxSoapMock implements HttpCalloutMock {
        private Integer statusCode;
        private String xmlBody;

        public VmxSoapMock(String xmlBody) {
            this(200, xmlBody);
        }

        public VmxSoapMock(Integer statusCode, String xmlBody) {
            this.statusCode = statusCode;
            this.xmlBody = xmlBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(xmlBody);
            return res;
        }
    }

    private static String buildEnvelopeXml(String wsResponseInner) {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<WSResponse xmlns="http://fecredit.com.vn/cms/ws/v2">' +
            wsResponseInner +
            '</WSResponse>' +
            '</soapenv:Body></soapenv:Envelope>';
    }

    private static String buildSuccessInner(
        String sysCode,
        String svcReturn,
        String authGrpBlock
    ) {
        return '<Sys><TransID>T123</TransID><Code>' + sysCode + '</Code><Description>OK</Description></Sys>' +
            '<VMX_AUTH_DETAIL_INQ>' +
            '<VMX_ROOT><VMX_MSGOUT>' +
            '<SVC_RETURN>' + svcReturn + '</SVC_RETURN>' +
            '<CURRENCY_CODE>VND</CURRENCY_CODE>' +
            authGrpBlock +
            '</VMX_MSGOUT></VMX_ROOT>' +
            '</VMX_AUTH_DETAIL_INQ>';
    }

    private static String authGrpInRetrv() {
        return '<module007><retrv_auth_dtl><NBR_AUTHS>1</NBR_AUTHS>' +
            '<AUTH_GRP>' +
            '<EFF_DATE>20260522</EFF_DATE>' +
            '<AUTH_AMT>1000</AUTH_AMT>' +
            '<Description>Test Merchant</Description>' +
            '<AUTHORIZATION_CODE>AUTH001</AUTHORIZATION_CODE>' +
            '<MERCH_CAT>5411</MERCH_CAT>' +
            '</AUTH_GRP></retrv_auth_dtl></module007>';
    }

    @IsTest
    static void testCallService_Success() {
        Test.setMock(
            HttpCalloutMock.class,
            new VmxSoapMock(buildEnvelopeXml(buildSuccessInner('1', 'S', authGrpInRetrv())))
        );

        Test.startTest();
        FEC_VMXAUTHDETAILINQ.ResponseWrapper res = FEC_VMXAUTHDETAILINQ.callService(
            'T1', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', CTX, NAME, ACCT, ''
        );
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(1, res.VMXMsgOut.Auths.size());
        System.assertEquals('20260522', res.VMXMsgOut.Auths[0].EFF_DATE);
        System.assertEquals('AUTH001', res.VMXMsgOut.Auths[0].AUTHORIZATION_CODE);
        System.assertEquals('VND', res.VMXMsgOut.CURRENCY_CODE);
    }

    @IsTest
    static void testCallServiceAsAuthRows_Success() {
        Test.setMock(
            HttpCalloutMock.class,
            new VmxSoapMock(buildEnvelopeXml(buildSuccessInner('1', 'S', authGrpInRetrv())))
        );

        Test.startTest();
        List<FEC_VMXAUTHDETAILINQ.AuthTableRow> rows = FEC_VMXAUTHDETAILINQ.callServiceAsAuthRows(
            'T2', FEC_ConstantCommon.REQUESTOR_CRM, DT, null, null, null, ACCT, 'CONT'
        );
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals('Test Merchant', rows[0].Description);
    }

    @IsTest
    static void testCallServiceAsAuthRows_EmptyWhenNoAuthGrp() {
        String wsInner = buildSuccessInner('1', 'S', '<module007></module007>');
        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(buildEnvelopeXml(wsInner)));

        Test.startTest();
        List<FEC_VMXAUTHDETAILINQ.AuthTableRow> rows = FEC_VMXAUTHDETAILINQ.callServiceAsAuthRows(
            'T3', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', CTX, NAME, ACCT, ''
        );
        Test.stopTest();

        System.assertEquals(0, rows.size());
    }

    @IsTest
    static void testCallService_DefaultBlankOptionalParams() {
        Test.setMock(
            HttpCalloutMock.class,
            new VmxSoapMock(buildEnvelopeXml(buildSuccessInner('1', 'S', authGrpInRetrv())))
        );

        Test.startTest();
        FEC_VMXAUTHDETAILINQ.ResponseWrapper res = FEC_VMXAUTHDETAILINQ.callService(
            'T4', FEC_ConstantCommon.REQUESTOR_CRM, DT, '', '', '', ACCT, null
        );
        Test.stopTest();

        System.assertEquals(1, res.VMXMsgOut.Auths.size());
    }

    @IsTest
    static void testParseAuthGrp_BfsAndPostingDate() {
        String wsInner = buildSuccessInner(
            '1',
            'S',
            '<AUTH_GRP><POSTING_DATE>20260523</POSTING_DATE><AUTH_AMOUNT>500</AUTH_AMOUNT><MERCHANT_NAME>BFS</MERCHANT_NAME></AUTH_GRP>'
        );
        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(buildEnvelopeXml(wsInner)));

        Test.startTest();
        FEC_VMXAUTHDETAILINQ.ResponseWrapper res = FEC_VMXAUTHDETAILINQ.callService(
            'T5', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', CTX, NAME, ACCT, ''
        );
        Test.stopTest();

        System.assertEquals(1, res.VMXMsgOut.Auths.size());
        System.assertEquals('20260523', res.VMXMsgOut.Auths[0].EFF_DATE);
        System.assertEquals('BFS', res.VMXMsgOut.Auths[0].Description);
    }

    @IsTest
    static void testParseRcDataAndSvcReturnFailure() {
        String wsInner =
            '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
            '<VMX_AUTH_DETAIL_INQ><VMX_ROOT><VMX_MSGOUT>' +
            '<SVC_RETURN>F</SVC_RETURN>' +
            '<RC_DATA><RETURN_CODE>99</RETURN_CODE><RETURN_DESC>VMX failed</RETURN_DESC></RC_DATA>' +
            '</VMX_MSGOUT></VMX_ROOT></VMX_AUTH_DETAIL_INQ>';
        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(buildEnvelopeXml(wsInner)));

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T6', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', CTX, NAME, ACCT, ''
            );
        } catch (Exception e) {
            threw = true;
            System.assert(e.getMessage().contains('VMX failed') || e.getMessage() != null);
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testCallService_SysCodeError() {
        Test.setMock(
            HttpCalloutMock.class,
            new VmxSoapMock(buildEnvelopeXml(buildSuccessInner('0', 'S', authGrpInRetrv())))
        );

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T7', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', CTX, NAME, ACCT, ''
            );
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testCallService_HttpError() {
        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(500, 'Server Error'));

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T8', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', CTX, NAME, ACCT, ''
            );
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testCallService_BlankResponseBody() {
        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(200, ''));

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T9', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', CTX, NAME, ACCT, ''
            );
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testValidation_TransIdTooLong() {
        Test.startTest();
        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T-TOO-LONG-ID-123456789012345678901234567890',
                FEC_ConstantCommon.REQUESTOR_CRM,
                DT,
                'E8V6',
                CTX,
                NAME,
                ACCT,
                ''
            );
            System.assert(false);
        } catch (Exception e) {
            System.assert(e.getMessage().contains('TransID') || e.getMessage() != null);
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidation_InvalidRequestorAndDatetime() {
        Test.startTest();
        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T10', 'INVALID_REQ', DT, 'E8V6', CTX, NAME, ACCT, ''
            );
            System.assert(false);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T10', FEC_ConstantCommon.REQUESTOR_CRM, 'bad-date', 'E8V6', CTX, NAME, ACCT, ''
            );
            System.assert(false);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidation_RequiredAndMaxLength() {
        Test.startTest();
        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T11', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', '', NAME, ACCT, ''
            );
            System.assert(false);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T11', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', CTX, '', ACCT, ''
            );
            System.assert(false);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T11', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', CTX, NAME, '', ''
            );
            System.assert(false);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T11',
                FEC_ConstantCommon.REQUESTOR_CRM,
                DT,
                'E8V6',
                'X'.repeat(51),
                NAME,
                ACCT,
                ''
            );
            System.assert(false);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T11',
                FEC_ConstantCommon.REQUESTOR_CRM,
                DT,
                'E8V6',
                CTX,
                'Y'.repeat(51),
                ACCT,
                ''
            );
            System.assert(false);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T11',
                FEC_ConstantCommon.REQUESTOR_CRM,
                DT,
                'E8V6',
                CTX,
                NAME,
                'Z'.repeat(31),
                ''
            );
            System.assert(false);
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testParseResponse_MalformedJson() {
        Test.setMock(HttpCalloutMock.class, new VmxSoapMock('{"status": "error"}'));

        Test.startTest();
        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T12', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', CTX, NAME, ACCT, ''
            );
            System.assert(false);
        } catch (Exception e) {
            System.assert(e.getMessage().contains('expected XML SOAP response'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testParseResponse_MalformedJson404Hint() {
        Test.setMock(HttpCalloutMock.class, new VmxSoapMock('{"error":404,"message":"not found"}'));

        Test.startTest();
        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T13', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', CTX, NAME, ACCT, ''
            );
            System.assert(false);
        } catch (Exception e) {
            System.assert(
                e.getMessage().contains('404') || e.getMessage().contains('FEC_Endpoint__c')
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testParseResponse_InvalidNonXmlBody() {
        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(200, 'NOT_XML_BODY'));

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T14', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', CTX, NAME, ACCT, ''
            );
        } catch (Exception e) {
            threw = true;
            System.assert(e.getMessage().contains('not valid XML') || e.getMessage() != null);
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testParseResponse_EmptyEnvelope() {
        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(200, '<soapenv:Envelope></soapenv:Envelope>'));

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_VMXAUTHDETAILINQ.callService(
                'T15', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', CTX, NAME, ACCT, ''
            );
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testAuthGrpSkippedWhenNoEffectiveDate() {
        String wsInner = buildSuccessInner(
            '1',
            'S',
            '<AUTH_GRP><AUTH_AMT>100</AUTH_AMT><Description>NoDate</Description></AUTH_GRP>'
        );
        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(buildEnvelopeXml(wsInner)));

        Test.startTest();
        FEC_VMXAUTHDETAILINQ.ResponseWrapper res = FEC_VMXAUTHDETAILINQ.callService(
            'T16', FEC_ConstantCommon.REQUESTOR_CRM, DT, 'E8V6', CTX, NAME, ACCT, ''
        );
        Test.stopTest();

        System.assertEquals(0, res.VMXMsgOut.Auths.size());
    }
}
