@IsTest
private class FEC_VmxAcctBlkcdUpdEmeaCallout_Test {

    @TestSetup
    static void setup() {
        // Setup API Setting cơ bản
        insert new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://api.test.com'
        );
    }

    @IsTest
    static void testUpdateAccountBlockCode_Success() {
        // 1. Dữ liệu response XML chuẩn
        String successXml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<WSResponse>' +
                '<Sys><TransID>T123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
                '<VMX_ACCT_BLKCD_UPD_EMEA>' +
                '<VMX_ROOT><VMX_MSGOUT>' +
                    '<SVC_RETURN>S</SVC_RETURN><ORG>Org1</ORG><CARD_NBR>1234</CARD_NBR>' +
                '</VMX_MSGOUT></VMX_ROOT>' +
                '</VMX_ACCT_BLKCD_UPD_EMEA>' +
            '</WSResponse>' +
            '</soapenv:Body></soapenv:Envelope>';

        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(successXml));

        // 2. Chuẩn bị Input
        FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdInput input = FEC_VmxAcctBlkcdUpdEmeaCallout.buildDefaultInput('12345678');
        
        Test.startTest();
        FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdResult result = FEC_VmxAcctBlkcdUpdEmeaCallout.updateAccountBlockCode(input);
        Test.stopTest();

        // 3. Assert
        System.assertEquals('1', result.responseCode);
        System.assertEquals('1234', result.cardNbr);
        System.assert(FEC_VmxAcctBlkcdUpdEmeaCallout.isBlkcdUpdSuccess(result));
    }

    @IsTest
    static void testValidation_MissingInput() {
        Test.startTest();
        try {
            // Gửi null input để test validate
            FEC_VmxAcctBlkcdUpdEmeaCallout.updateAccountBlockCode(null);
            System.assert(false, 'Phải ném ngoại lệ khi input null');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException || e instanceof CalloutException);
        }
        Test.stopTest();
    }

    @IsTest
    static void testParseLegacyResponse() {
        // WSResponse root: VMX_ROOT nằm trong VMX_ACCT_BLKCD_UPD_EMEA (parseVmxMsgOut path)
        String legacyXml =
            '<WSResponse>' +
            '<Sys><TransID>T999</TransID><Code>1</Code><Description>Success</Description></Sys>' +
            '<VMX_ACCT_BLKCD_UPD_EMEA>' +
            '<VMX_ROOT><VMX_MSGOUT>' +
            '<SVC_RETURN>S</SVC_RETURN><ORG>LegacyOrg</ORG>' +
            '</VMX_MSGOUT></VMX_ROOT>' +
            '</VMX_ACCT_BLKCD_UPD_EMEA>' +
            '</WSResponse>';

        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(legacyXml));

        FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdInput input =
            FEC_VmxAcctBlkcdUpdEmeaCallout.buildDefaultInput('8888');

        Test.startTest();
        FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdResult result =
            FEC_VmxAcctBlkcdUpdEmeaCallout.updateAccountBlockCode(input);
        Test.stopTest();

        System.assertEquals('1', result.responseCode);
        System.assertEquals('LegacyOrg', result.org);
        System.assertEquals('S', result.svcReturn);
    }

    @IsTest
    static void testHelperMethods() {
        System.assertEquals(false, FEC_VmxAcctBlkcdUpdEmeaCallout.isBlkcdUpdDescriptionSuccess(null));
        System.assertEquals(true, FEC_VmxAcctBlkcdUpdEmeaCallout.isBlkcdUpdDescriptionSuccess('Operation Success'));
        System.assertEquals(false, FEC_VmxAcctBlkcdUpdEmeaCallout.isVmxSvcReturnFailure(null));

        FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdResult failResult =
            new FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdResult();
        failResult.svcReturn = 'F';
        System.assert(FEC_VmxAcctBlkcdUpdEmeaCallout.isVmxSvcReturnFailure(failResult));
        System.assertEquals(false, FEC_VmxAcctBlkcdUpdEmeaCallout.isBlkcdUpdSuccess(failResult));
        System.assertEquals(false, FEC_VmxAcctBlkcdUpdEmeaCallout.isBlkcdUpdBusinessSuccess(failResult));

        FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdResult errResult =
            new FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdResult();
        errResult.vmxReturnDesc = 'VMX error';
        errResult.responseDesc = 'System error';
        System.assertEquals('VMX error', FEC_VmxAcctBlkcdUpdEmeaCallout.resolveBlkcdUpdErrorMessage(errResult));
        System.assertEquals(null, FEC_VmxAcctBlkcdUpdEmeaCallout.resolveBlkcdUpdErrorMessage(null));

        FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdResult bizSuccess =
            new FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdResult();
        bizSuccess.responseCode = '0';
        bizSuccess.responseDesc = 'Completed with Success';
        bizSuccess.svcReturn = 'S';
        System.assert(FEC_VmxAcctBlkcdUpdEmeaCallout.isBlkcdUpdBusinessSuccess(bizSuccess));
    }

    @IsTest
    static void testApplyDesignDefaults_MinimalInput() {
        String successXml =
            '<WSResponse>' +
            '<Sys><TransID>T100</TransID><Code>1</Code><Description>Success</Description></Sys>' +
            '<VMX_ACCT_BLKCD_UPD_EMEA><VMX_ROOT><VMX_MSGOUT>' +
            '<SVC_RETURN>S</SVC_RETURN><ORG>DefaultOrg</ORG>' +
            '</VMX_MSGOUT></VMX_ROOT></VMX_ACCT_BLKCD_UPD_EMEA></WSResponse>';
        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(successXml));

        FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdInput input =
            new FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdInput();
        input.cardNbr = '9999888877776666';

        Test.startTest();
        FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdResult result =
            FEC_VmxAcctBlkcdUpdEmeaCallout.updateAccountBlockCode(input);
        Test.stopTest();

        System.assertEquals('1', result.responseCode);
        System.assertEquals('DefaultOrg', result.org);
    }

    @IsTest
    static void testSvcReturnFailure() {
        String failureXml =
            '<WSResponse>' +
            '<Sys><TransID>T200</TransID><Code>1</Code><Description>Success</Description></Sys>' +
            '<VMX_ACCT_BLKCD_UPD_EMEA><VMX_ROOT><VMX_MSGOUT>' +
            '<SVC_RETURN>F</SVC_RETURN>' +
            '<RC_DATA><RETURN_DESC>Block update failed</RETURN_DESC></RC_DATA>' +
            '</VMX_MSGOUT></VMX_ROOT></VMX_ACCT_BLKCD_UPD_EMEA></WSResponse>';
        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(failureXml));

        Test.startTest();
        try {
            FEC_VmxAcctBlkcdUpdEmeaCallout.updateAccountBlockCode(
                FEC_VmxAcctBlkcdUpdEmeaCallout.buildDefaultInput('12345678')
            );
            System.assert(false, 'Expected failure when SVC_RETURN is F.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSysCodeErrorWithoutSuccessDescription() {
        String errorXml =
            '<WSResponse>' +
            '<Sys><TransID>T250</TransID><Code>99</Code><Description>Failed</Description></Sys>' +
            '<VMX_ACCT_BLKCD_UPD_EMEA><VMX_ROOT><VMX_MSGOUT>' +
            '<SVC_RETURN>S</SVC_RETURN>' +
            '</VMX_MSGOUT></VMX_ROOT></VMX_ACCT_BLKCD_UPD_EMEA></WSResponse>';
        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(errorXml));

        Test.startTest();
        try {
            FEC_VmxAcctBlkcdUpdEmeaCallout.updateAccountBlockCode(
                FEC_VmxAcctBlkcdUpdEmeaCallout.buildDefaultInput('12345678')
            );
            System.assert(false, 'Expected sys code error.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testHttpError() {
        FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdInput input =
            FEC_VmxAcctBlkcdUpdEmeaCallout.buildDefaultInput('12345678');

        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(500, 'Server Error'));
        Test.startTest();
        try {
            FEC_VmxAcctBlkcdUpdEmeaCallout.updateAccountBlockCode(input);
            System.assert(false, 'Expected HTTP error.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testBlankResponseBody() {
        FEC_VmxAcctBlkcdUpdEmeaCallout.BlkcdUpdInput input =
            FEC_VmxAcctBlkcdUpdEmeaCallout.buildDefaultInput('12345678');

        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(200, ''));
        Test.startTest();
        try {
            FEC_VmxAcctBlkcdUpdEmeaCallout.updateAccountBlockCode(input);
            System.assert(false, 'Expected blank response error.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
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
            res.setStatus(statusCode == 200 ? 'OK' : 'Internal Server Error');
            return res;
        }
    }
}