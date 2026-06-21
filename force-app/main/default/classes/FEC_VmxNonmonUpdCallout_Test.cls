@IsTest
private class FEC_VmxNonmonUpdCallout_Test {

    @TestSetup
    static void setup() {
        insert new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://api.test.com'
        );
    }

    private class VmxSoapMock implements HttpCalloutMock {
        private String xmlBody;

        public VmxSoapMock(String xmlBody) {
            this.xmlBody = xmlBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(this.xmlBody);
            return res;
        }
    }

    private static FEC_VmxNonmonUpdCallout.NonmonUpdInput buildTestInput() {
        FEC_VmxNonmonUpdCallout.NonmonUpdInput input = FEC_VmxNonmonUpdCallout.buildDefaultInput();
        input.account = '0001500080001514285';
        input.memo1 = '18/06/2026 16:03-Action-AccountBlock-S-73028115';
        input.memo2 = 'Old Block Code = New Block Code =C';
        return input;
    }

    @IsTest
    static void testExecuteNonmonUpdate_Success() {
        String successXml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<WSResponse>' +
                '<Sys><TransID>T123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
                '<VMX_NONMON_UPD>' +
                '<VMX_ROOT><VMX_MSGOUT>' +
                    '<SVC_RETURN>P</SVC_RETURN><RC_NBR_OCCUR>0</RC_NBR_OCCUR>' +
                    '<OUTPUT_AREA><ORG>150</ORG></OUTPUT_AREA>' +
                '</VMX_MSGOUT></VMX_ROOT>' +
                '</VMX_NONMON_UPD>' +
            '</WSResponse>' +
            '</soapenv:Body></soapenv:Envelope>';

        Test.setMock(HttpCalloutMock.class, new VmxSoapMock(successXml));

        Test.startTest();
        FEC_VmxNonmonUpdCallout.NonmonUpdResult result =
            FEC_VmxNonmonUpdCallout.executeNonmonUpdate(buildTestInput());
        FEC_VmxNonmonUpdCallout.logApiResponse();
        Test.stopTest();

        System.assertEquals('1', result.responseCode);
        System.assertEquals('P', result.svcReturn);
        System.assertEquals(true, FEC_VmxNonmonUpdCallout.isNonmonUpdSuccess(result));
    }

    @IsTest
    static void testValidation_MissingAccount() {
        FEC_VmxNonmonUpdCallout.NonmonUpdInput input = buildTestInput();
        input.account = null;

        Test.startTest();
        try {
            FEC_VmxNonmonUpdCallout.executeNonmonUpdate(input);
            System.assert(false, 'Expected validation exception');
        } catch (CalloutException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testExecuteNonmonUpdate_HttpError() {
        Test.setMock(HttpCalloutMock.class, new HttpErrorMock());

        Test.startTest();
        try {
            FEC_VmxNonmonUpdCallout.executeNonmonUpdate(buildTestInput());
            System.assert(false, 'Expected callout exception');
        } catch (Exception e) {
            System.assert(true);
        } finally {
            FEC_VmxNonmonUpdCallout.logApiResponse();
        }
        Test.stopTest();
    }

    private class HttpErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
}
