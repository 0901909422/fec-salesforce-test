@IsTest
private class FEC_VmxAcctBlkcdUpdEmeaCallout_Test {

    @TestSetup
    static void setup() {
        // Setup API Setting cơ bản
        insert new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://api.test.com'
        );
    }

    private class VmxSoapMock implements HttpCalloutMock {
        private String xmlBody;
        public VmxSoapMock(String xmlBody) { this.xmlBody = xmlBody; }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(this.xmlBody);
            return res;
        }
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
}