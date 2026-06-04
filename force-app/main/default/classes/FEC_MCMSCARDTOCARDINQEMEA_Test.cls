@IsTest
private class FEC_MCMSCARDTOCARDINQEMEA_Test {

    private static final String SOAP_ENV = FEC_ConstantCommon.SOAP_ENV;
    private static final String VALID_TRANS_ID = '123456789012345678901234567890123456';
    private static final String VALID_DATETIME = '2026-04-14 10:00:00';

    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Endpoint__c = 'https://test-api.fecredit.com.vn';
        apiSetting.FEC_Call_Mock__c = false;
        apiSetting.FEC_Enviroment__c = 'Production';
        upsert apiSetting;
    }

    private static void registerCalloutMock(Integer statusCode, String responseBody) {
        Test.setMock(
            HttpCalloutMock.class,
            new MockHttpResponse(statusCode, responseBody)
        );
    }

    private static String buildSuccessXml() {
        return '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
            '<soapenv:Body>' +
            '<WSResponse>' +
            '<Sys><TransID>TXN001</TransID><DateTime>2026-04-14 10:00:00</DateTime>' +
            '<Code>1</Code><Description>Success</Description></Sys>' +
            '<M_CMS_CARD_TO_CARD_INQ_EMEA>' +
            '<VMX_ROOT><VMX_MSGOUT>' +
            '<SVC_RETURN>S</SVC_RETURN>' +
            '<RC_NBR_OCCUR>1</RC_NBR_OCCUR>' +
            '<RC_DATA><RETURN_CODE>00</RETURN_CODE><RETURN_DESC>OK</RETURN_DESC></RC_DATA>' +
            '<OUTPUT_AREA><MORE_RECS>0</MORE_RECS><NBR_OF_OCCUR>1</NBR_OF_OCCUR>' +
            '<OUTPUT_DATA>' +
            '<SEQ>1</SEQ><ORG>ORG1</ORG><CARD_NBR>4111111111111111</CARD_NBR>' +
            '<CARD_SEQ>1</CARD_SEQ><STAT>A</STAT><TYPE_OF_CARD>1</TYPE_OF_CARD>' +
            '<CARDHOLDER_TYPE>1</CARDHOLDER_TYPE><GNDR_CD>1</GNDR_CD>' +
            '<EMAIL_NOTIFY>1</EMAIL_NOTIFY><SMS_OUTCOME>0</SMS_OUTCOME><EMBLM_ID>1</EMBLM_ID>' +
            '<MS_ACCT_LOGO>100</MS_ACCT_LOGO><PIN_SUPPR>0</PIN_SUPPR>' +
            '</OUTPUT_DATA>' +
            '</OUTPUT_AREA>' +
            '</VMX_MSGOUT></VMX_ROOT>' +
            '</M_CMS_CARD_TO_CARD_INQ_EMEA>' +
            '</WSResponse>' +
            '</soapenv:Body></soapenv:Envelope>';
    }

    private static String buildSysErrorXml() {
        return '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
            '<soapenv:Body><WSResponse>' +
            '<Sys><Code>99</Code><Description>System Error</Description></Sys>' +
            '</WSResponse></soapenv:Body></soapenv:Envelope>';
    }

    private static String buildSvcFailureXml() {
        return '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
            '<soapenv:Body><WSResponse>' +
            '<Sys><Code>1</Code><Description>Success</Description></Sys>' +
            '<M_CMS_CARD_TO_CARD_INQ_EMEA>' +
            '<VMX_ROOT><VMX_MSGOUT>' +
            '<SVC_RETURN>F</SVC_RETURN>' +
            '<RC_DATA><RETURN_CODE>ERR01</RETURN_CODE><RETURN_DESC>Business failure</RETURN_DESC></RC_DATA>' +
            '</VMX_MSGOUT></VMX_ROOT>' +
            '</M_CMS_CARD_TO_CARD_INQ_EMEA>' +
            '</WSResponse></soapenv:Body></soapenv:Envelope>';
    }

    private static FEC_MCMSCARDTOCARDINQEMEA.ResponseWrapper callWithDefaults(
        String transId,
        String requestorId,
        String dateTimeStr,
        String vmxVersion,
        String context,
        String signOnName,
        String org,
        String cardNbr,
        String name
    ) {
        return FEC_MCMSCARDTOCARDINQEMEA.callService(
            transId,
            requestorId,
            dateTimeStr,
            vmxVersion,
            context,
            signOnName,
            org,
            cardNbr,
            name
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
        String cardNbr,
        String name
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
                cardNbr,
                name
            );
            System.assert(false, 'Expected CalloutException: ' + label);
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage(), label);
        }
    }

    @IsTest
    static void testCallService_Success() {
        registerCalloutMock(200, buildSuccessXml());

        Test.startTest();
        FEC_MCMSCARDTOCARDINQEMEA.ResponseWrapper result = callWithDefaults(
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V2',
            'CONTEXT_TEST',
            'SIGNON_TEST',
            'ORG_TEST',
            '1234567890123456789',
            'TEST NAME'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(1, result.Sys.Code);
        System.assertEquals('S', result.VMXMsgOut.SVC_RETURN);
        System.assertEquals(1, result.VMXMsgOut.OUTPUT_AREA.OUTPUT_DATA.size());
        System.assertEquals('4111111111111111', result.VMXMsgOut.OUTPUT_AREA.OUTPUT_DATA[0].CARD_NBR);
    }

    @IsTest
    static void testCallService_NonProductionUsesHardCodeCard() {
        FEC_API_Setting__c setting = FEC_API_Setting__c.getOrgDefaults();
        setting.FEC_Enviroment__c = FEC_ConstantCommon.ENVIROMENT_NON_PRODUCTION;
        update setting;

        registerCalloutMock(200, buildSuccessXml());

        Test.startTest();
        FEC_MCMSCARDTOCARDINQEMEA.ResponseWrapper result = callWithDefaults(
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_PORTAL,
            VALID_DATETIME,
            'V2',
            'CTX',
            'SIGNON',
            'ORG1',
            '9999999999999999999',
            null
        );
        Test.stopTest();

        System.assertEquals(1, result.Sys.Code);
    }

    @IsTest
    static void testCallService_LongNameTruncated() {
        registerCalloutMock(200, buildSuccessXml());

        Test.startTest();
        FEC_MCMSCARDTOCARDINQEMEA.ResponseWrapper result = callWithDefaults(
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_MOBILE_APP,
            '2026-04-14T10:00:00',
            'V2',
            'CTX',
            'SIGNON',
            'ORG1',
            '1234567890123456789',
            'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        );
        Test.stopTest();

        System.assertEquals(1, result.Sys.Code);
    }

    @IsTest
    static void testCallService_HttpError() {
        registerCalloutMock(500, '');

        Test.startTest();
        assertCalloutException(
            'HTTP error',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V2',
            'CTX',
            'SIGNON',
            'ORG1',
            '1234567890123456789',
            null
        );
        Test.stopTest();
    }

    @IsTest
    static void testCallService_SysCodeError() {
        registerCalloutMock(200, buildSysErrorXml());

        Test.startTest();
        assertCalloutException(
            'Sys code error',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
            VALID_DATETIME,
            'V2',
            'CTX',
            'SIGNON',
            'ORG1',
            '1234567890123456789',
            'NAME'
        );
        Test.stopTest();
    }

    @IsTest
    static void testCallService_SvcReturnFailure() {
        registerCalloutMock(200, buildSvcFailureXml());

        Test.startTest();
        assertCalloutException(
            'SVC_RETURN failure',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V2',
            'CTX',
            'SIGNON',
            'ORG1',
            '1234567890123456789',
            null
        );
        Test.stopTest();
    }

    @IsTest
    static void testValidateRequest_Error() {
        registerCalloutMock(200, buildSuccessXml());

        Test.startTest();
        assertCalloutException(
            'blank TransID',
            '',
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V2',
            'CTX',
            'SIGNON',
            'ORG1',
            '1234567890123456789',
            null
        );

        assertCalloutException(
            'invalid requestor',
            VALID_TRANS_ID,
            'INVALID',
            VALID_DATETIME,
            'V2',
            'CTX',
            'SIGNON',
            'ORG1',
            '1234567890123456789',
            null
        );

        assertCalloutException(
            'invalid datetime',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            'not-a-datetime',
            'V2',
            'CTX',
            'SIGNON',
            'ORG1',
            '1234567890123456789',
            null
        );

        assertCalloutException(
            'context too long',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V2',
            'X'.repeat(51),
            'SIGNON',
            'ORG1',
            '1234567890123456789',
            null
        );

        assertCalloutException(
            'card number too long',
            VALID_TRANS_ID,
            FEC_ConstantCommon.REQUESTOR_CRM,
            VALID_DATETIME,
            'V2',
            'CTX',
            'SIGNON',
            'ORG1',
            '12345678901234567890',
            null
        );
        Test.stopTest();
    }

    private class MockHttpResponse implements HttpCalloutMock {
        Integer statusCode;
        String body;

        MockHttpResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }
}
