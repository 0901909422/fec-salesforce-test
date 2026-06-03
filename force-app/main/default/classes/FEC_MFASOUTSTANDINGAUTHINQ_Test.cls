@IsTest
private class FEC_MFASOUTSTANDINGAUTHINQ_Test {

    private static final String VALID_TRANS_ID = '123456789012345678901234567890123456';
    private static final String VALID_DATETIME = '2026-01-29 10:00:00';
    private static final String VALID_CONTEXT = 'CONTEXT';
    private static final String VALID_SIGNON = 'SIGNON';
    private static final String VALID_ORG = 'ORG1';
    private static final String VALID_ACCT = 'ACC123456789';

    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Call_Mock__c = false;
        apiSetting.FEC_Endpoint__c = 'https://test-api.fecredit.com.vn';
        upsert apiSetting;
    }

    private static void registerCalloutMock(Integer statusCode, String responseBody) {
        Test.setMock(
            HttpCalloutMock.class,
            new MockHttpResponse(statusCode, responseBody)
        );
    }

    private static void registerDefaultCalloutMock() {
        registerCalloutMock(200, buildSuccessXml());
    }

    private static String buildSuccessXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<WSResponse>' +
            '<Sys>' +
            '<TransID>TXN001</TransID>' +
            '<DateTime>2026-01-29 10:00:00</DateTime>' +
            '<Code>1</Code>' +
            '<Description>Success</Description>' +
            '</Sys>' +
            '<M_FAS_OUTSTANDING_AUTH_INQ>' +
            '<VMX_ROOT><VMX_MSGOUT>' +
            '<SVC_RETURN>S</SVC_RETURN>' +
            '<RC_NBR_OCCUR>1</RC_NBR_OCCUR>' +
            '<RC_DATA>' +
            '<RETURN_CODE>00</RETURN_CODE>' +
            '<RETURN_DESC>OK</RETURN_DESC>' +
            '</RC_DATA>' +
            '<O_CURR_NOD>1</O_CURR_NOD>' +
            '<O_CURR_NBR>2</O_CURR_NBR>' +
            '<FOREIGN_USE>0</FOREIGN_USE>' +
            '<ORG>ORG1</ORG>' +
            '<ACCT>ACC123456789</ACCT>' +
            '<REQ_TYPE>INQ</REQ_TYPE>' +
            '<MORE_DATA_FLAG>0</MORE_DATA_FLAG>' +
            '<NBR_RETURNED_ITEMS>1</NBR_RETURNED_ITEMS>' +
            '<NEXT_TOKEN>' +
            '<EFF_DATE_NEXT>20260129</EFF_DATE_NEXT>' +
            '<TIME_NEXT>100000</TIME_NEXT>' +
            '</NEXT_TOKEN>' +
            '<PREV_TOKEN>' +
            '<EFF_DATE_PREV>20260128</EFF_DATE_PREV>' +
            '<TIME_PREV>090000</TIME_PREV>' +
            '</PREV_TOKEN>' +
            '</VMX_MSGOUT></VMX_ROOT>' +
            '</M_FAS_OUTSTANDING_AUTH_INQ>' +
            '</WSResponse>' +
            '</soapenv:Body></soapenv:Envelope>';
    }

    private static String buildSysErrorXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body><WSResponse>' +
            '<Sys><Code>99</Code><Description>System Error</Description></Sys>' +
            '</WSResponse></soapenv:Body></soapenv:Envelope>';
    }

    private static String buildSvcFailureXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body><WSResponse>' +
            '<Sys><Code>1</Code><Description>Success</Description></Sys>' +
            '<M_FAS_OUTSTANDING_AUTH_INQ>' +
            '<VMX_ROOT><VMX_MSGOUT>' +
            '<SVC_RETURN>F</SVC_RETURN>' +
            '<RC_DATA>' +
            '<RETURN_CODE>ERR01</RETURN_CODE>' +
            '<RETURN_DESC>Business failure</RETURN_DESC>' +
            '</RC_DATA>' +
            '</VMX_MSGOUT></VMX_ROOT>' +
            '</M_FAS_OUTSTANDING_AUTH_INQ>' +
            '</WSResponse></soapenv:Body></soapenv:Envelope>';
    }

    private static FEC_MFASOUTSTANDINGAUTHINQ.ResponseWrapper callWithDefaults(
        String transId,
        String requestorId,
        String dateTimeStr,
        String vmxVersion,
        String context,
        String signOnName,
        String org,
        String acct
    ) {
        return FEC_MFASOUTSTANDINGAUTHINQ.callService(
            transId,
            requestorId,
            dateTimeStr,
            vmxVersion,
            context,
            signOnName,
            org,
            acct
        );
    }

    private static void assertCalloutException(
        String label,
        String transId,
        String requestorId,
        String dateTimeStr,
        String vmxVersion,
        String context,
        String signOnName,
        String org,
        String acct
    ) {
        try {
            callWithDefaults(
                transId,
                requestorId,
                dateTimeStr,
                vmxVersion,
                context,
                signOnName,
                org,
                acct
            );
            System.assert(false, 'Expected CalloutException: ' + label);
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage(), label);
        }
    }

    @IsTest
    static void testCallService_Success_WithFullPayload() {
        registerDefaultCalloutMock();
        Test.startTest();
        FEC_MFASOUTSTANDINGAUTHINQ.ResponseWrapper result = callWithDefaults(
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            FEC_ConstantCommon.REQUESTOR_VMXVERSION,
            VALID_CONTEXT,
            VALID_SIGNON,
            VALID_ORG,
            VALID_ACCT
        );
        Test.stopTest();

        System.assertEquals(1, result.Sys.Code);
        System.assertEquals('S', result.VMXMsgOut.SVC_RETURN);
        System.assertEquals(1, result.VMXMsgOut.RC_NBR_OCCUR);
        System.assertEquals(1, result.VMXMsgOut.RC_DATA.size());
        System.assertEquals('00', result.VMXMsgOut.RC_DATA[0].RETURN_CODE);
        System.assertEquals('OK', result.VMXMsgOut.RC_DATA[0].RETURN_DESC);
        System.assertEquals('ORG1', result.VMXMsgOut.ORG);
        System.assertEquals('ACC123456789', result.VMXMsgOut.ACCT);
        System.assertEquals('INQ', result.VMXMsgOut.REQ_TYPE);
        System.assertNotEquals(null, result.VMXMsgOut.NEXT_TOKEN);
        System.assertEquals('20260129', result.VMXMsgOut.NEXT_TOKEN.EFF_DATE);
        System.assertEquals(100000, result.VMXMsgOut.NEXT_TOKEN.TIME_X);
        System.assertNotEquals(null, result.VMXMsgOut.PREV_TOKEN);
        System.assertEquals('20260128', result.VMXMsgOut.PREV_TOKEN.EFF_DATE);
        System.assertEquals(90000, result.VMXMsgOut.PREV_TOKEN.TIME_X);
    }

    @IsTest
    static void testCallService_Success_WithoutVmxVersion() {
        registerDefaultCalloutMock();
        Test.startTest();
        FEC_MFASOUTSTANDINGAUTHINQ.ResponseWrapper result = callWithDefaults(
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_PORTAL,
            '2026-01-29T10:00:00',
            null,
            VALID_CONTEXT,
            VALID_SIGNON,
            VALID_ORG,
            VALID_ACCT
        );
        Test.stopTest();

        System.assertEquals(1, result.Sys.Code);
        System.assertEquals('S', result.VMXMsgOut.SVC_RETURN);
    }

    @IsTest
    static void testCallService_UsesMockEndpointWhenFlagSet() {
        FEC_API_Setting__c setting = FEC_API_Setting__c.getOrgDefaults();
        setting.FEC_Call_Mock__c = true;
        update setting;

        registerDefaultCalloutMock();
        Test.startTest();
        FEC_MFASOUTSTANDINGAUTHINQ.ResponseWrapper result = callWithDefaults(
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_MOBILE_APP,
            VALID_DATETIME,
            '',
            VALID_CONTEXT,
            VALID_SIGNON,
            VALID_ORG,
            VALID_ACCT
        );
        Test.stopTest();

        System.assertEquals('S', result.VMXMsgOut.SVC_RETURN);
    }

    @IsTest
    static void testCallService_HttpError() {
        registerCalloutMock(500, 'Internal Server Error');
        Test.startTest();
        try {
            callWithDefaults(
                VALID_TRANS_ID,
                FEC_ConstantCommon.REQUESTOR_CRM,
                VALID_DATETIME,
                'V1',
                VALID_CONTEXT,
                VALID_SIGNON,
                VALID_ORG,
                VALID_ACCT
            );
            System.assert(false, 'Expected HTTP error.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCallService_BlankResponseBody() {
        registerCalloutMock(200, '');
        Test.startTest();
        try {
            callWithDefaults(
                VALID_TRANS_ID,
                FEC_ConstantCommon.REQUESTOR_CRM,
                VALID_DATETIME,
                'V1',
                VALID_CONTEXT,
                VALID_SIGNON,
                VALID_ORG,
                VALID_ACCT
            );
            System.assert(false, 'Expected error for blank body.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCallService_SysCodeError() {
        registerCalloutMock(200, buildSysErrorXml());
        Test.startTest();
        try {
            callWithDefaults(
                VALID_TRANS_ID,
                FEC_ConstantCommon.REQUESTOR_CRM,
                VALID_DATETIME,
                'V1',
                VALID_CONTEXT,
                VALID_SIGNON,
                VALID_ORG,
                VALID_ACCT
            );
            System.assert(false, 'Expected Sys code error.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCallService_SvcReturnFailure() {
        registerCalloutMock(200, buildSvcFailureXml());
        Test.startTest();
        try {
            callWithDefaults(
                VALID_TRANS_ID,
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                VALID_DATETIME,
                'V1',
                VALID_CONTEXT,
                VALID_SIGNON,
                VALID_ORG,
                VALID_ACCT
            );
            System.assert(false, 'Expected SVC_RETURN failure.');
        } catch (CalloutException e) {
            System.assert(true, 'SVC_RETURN F phải throw CalloutException.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateRequest_TransIdErrors() {
        registerDefaultCalloutMock();
        Test.startTest();
        assertCalloutException(
            'blank TransID',
            '',
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V1',
            VALID_CONTEXT,
            VALID_SIGNON,
            VALID_ORG,
            VALID_ACCT
        );
        assertCalloutException(
            'TransID too long',
            VALID_TRANS_ID + 'X',
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V1',
            VALID_CONTEXT,
            VALID_SIGNON,
            VALID_ORG,
            VALID_ACCT
        );
        Test.stopTest();
    }

    @IsTest
    static void testValidateRequest_RequestorAndDatetimeErrors() {
        registerDefaultCalloutMock();
        Test.startTest();
        assertCalloutException(
            'invalid RequestorID',
            VALID_TRANS_ID,
            'INVALID',
            VALID_DATETIME,
            'V1',
            VALID_CONTEXT,
            VALID_SIGNON,
            VALID_ORG,
            VALID_ACCT
        );
        assertCalloutException(
            'blank Datetime',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            '',
            'V1',
            VALID_CONTEXT,
            VALID_SIGNON,
            VALID_ORG,
            VALID_ACCT
        );
        assertCalloutException(
            'invalid Datetime',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            'not-a-date',
            'V1',
            VALID_CONTEXT,
            VALID_SIGNON,
            VALID_ORG,
            VALID_ACCT
        );
        Test.stopTest();
    }

    @IsTest
    static void testValidateRequest_ContextAndSignOnErrors() {
        String long51 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXY';

        registerDefaultCalloutMock();
        Test.startTest();
        assertCalloutException(
            'blank Context',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V1',
            '',
            VALID_SIGNON,
            VALID_ORG,
            VALID_ACCT
        );
        assertCalloutException(
            'Context too long',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V1',
            long51,
            VALID_SIGNON,
            VALID_ORG,
            VALID_ACCT
        );
        assertCalloutException(
            'blank SignOnName',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V1',
            VALID_CONTEXT,
            '',
            VALID_ORG,
            VALID_ACCT
        );
        assertCalloutException(
            'SignOnName too long',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V1',
            VALID_CONTEXT,
            long51,
            VALID_ORG,
            VALID_ACCT
        );
        Test.stopTest();
    }

    @IsTest
    static void testValidateRequest_OrgAndAcctErrors() {
        String long11 = '12345678901';
        String long31 = '1234567890123456789012345678901';

        registerDefaultCalloutMock();
        Test.startTest();
        assertCalloutException(
            'blank Org',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V1',
            VALID_CONTEXT,
            VALID_SIGNON,
            '',
            VALID_ACCT
        );
        assertCalloutException(
            'Org too long',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V1',
            VALID_CONTEXT,
            VALID_SIGNON,
            long11,
            VALID_ACCT
        );
        assertCalloutException(
            'blank Acct',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V1',
            VALID_CONTEXT,
            VALID_SIGNON,
            VALID_ORG,
            ''
        );
        assertCalloutException(
            'Acct too long',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V1',
            VALID_CONTEXT,
            VALID_SIGNON,
            VALID_ORG,
            long31
        );
        Test.stopTest();
    }

    private class MockHttpResponse implements HttpCalloutMock {
        Integer code;
        String body;

        MockHttpResponse(Integer code, String body) {
            this.code = code;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.code);
            res.setBody(this.body);
            return res;
        }
    }
}
