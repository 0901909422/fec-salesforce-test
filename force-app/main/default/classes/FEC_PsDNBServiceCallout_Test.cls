@IsTest
private class FEC_PsDNBServiceCallout_Test {

    public class DNBHttpMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        public DNBHttpMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.body);
            return res;
        }
    }

    private class CalloutExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated callout failure');
        }
    }

    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        if (String.isBlank(apiSetting.FEC_Endpoint__c)) {
            apiSetting.FEC_Endpoint__c = 'https://mock-api.fecredit.com.vn';
            upsert apiSetting;
        }
    }

    private static List<FEC_PsDNBServiceCallout.DNBRequest> validRequestList() {
        FEC_PsDNBServiceCallout.DNBRequest r = new FEC_PsDNBServiceCallout.DNBRequest();
        r.reason = 'Test';
        r.full_name = 'Test User';
        r.nid = '12345';
        r.do_not_bother = true;
        r.type = 'A';
        r.type_value = 'Val';
        return new List<FEC_PsDNBServiceCallout.DNBRequest>{ r };
    }

    @IsTest
    static void testNotifyPsDNB_Success() {
        String successBody =
            '{"sys":{"code":0, "trans_id":"T123", "message":"Success"}, "result":[]}';
        Test.setMock(HttpCalloutMock.class, new DNBHttpMock(200, successBody));

        Test.startTest();
        FEC_PsDNBServiceCallout.DNBResult result =
            FEC_PsDNBServiceCallout.notifyPsDNB(validRequestList());
        Test.stopTest();

        System.assertEquals(true, result.success, 'Kết quả phải là success.');
        System.assertEquals('0', result.code);
    }

    @IsTest
    static void testNotifyPsDNB_ValidationErrors() {
        Test.startTest();
        System.assertEquals(false, FEC_PsDNBServiceCallout.notifyPsDNB(null).success);

        List<FEC_PsDNBServiceCallout.DNBRequest> reqList =
            new List<FEC_PsDNBServiceCallout.DNBRequest>{
                new FEC_PsDNBServiceCallout.DNBRequest()
            };
        System.assertEquals(false, FEC_PsDNBServiceCallout.notifyPsDNB(reqList).success);

        FEC_PsDNBServiceCallout.DNBRequest r = new FEC_PsDNBServiceCallout.DNBRequest();
        r.reason = 'R';
        r.full_name = 'F';
        r.nid = 'A'.repeat(256);
        r.do_not_bother = true;
        r.type = 'T';
        r.type_value = 'V';
        System.assertEquals(
            false,
            FEC_PsDNBServiceCallout.notifyPsDNB(
                new List<FEC_PsDNBServiceCallout.DNBRequest>{ r }
            ).success
        );
        Test.stopTest();
    }

    @IsTest
    static void testParseResponse_ErrorCases() {
        FEC_PsDNBServiceCallout.DNBResult res404 =
            FEC_PsDNBServiceCallout.parseResponse('Error', 404);
        System.assertEquals(false, res404.success);

        FEC_PsDNBServiceCallout.DNBResult resEmpty =
            FEC_PsDNBServiceCallout.parseResponse('', 200);
        System.assertEquals(false, resEmpty.success);

        FEC_PsDNBServiceCallout.DNBResult resBadJson =
            FEC_PsDNBServiceCallout.parseResponse('{"sys": "invalid"}', 200);
        System.assertEquals(false, resBadJson.success);
    }

    @IsTest
    static void testSendRequest_WithMock() {
        Test.setMock(
            HttpCalloutMock.class,
            new DNBHttpMock(
                200,
                '{"sys":{"code":0,"trans_id":"TXN1","message":"OK"},"result":[]}'
            )
        );

        Test.startTest();
        HttpResponse res = FEC_PsDNBServiceCallout.sendRequest(validRequestList());
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(200, res.getStatusCode());
    }

    @IsTest
    static void testNotifyPsDNB_HttpError() {
        Test.setMock(HttpCalloutMock.class, new DNBHttpMock(500, 'Internal Server Error'));

        Test.startTest();
        FEC_PsDNBServiceCallout.DNBResult result =
            FEC_PsDNBServiceCallout.notifyPsDNB(validRequestList());
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.errorMessage.contains('500'));
    }

    @IsTest
    static void testNotifyPsDNB_CalloutException() {
        Test.setMock(HttpCalloutMock.class, new CalloutExceptionMock());

        Test.startTest();
        FEC_PsDNBServiceCallout.DNBResult result =
            FEC_PsDNBServiceCallout.notifyPsDNB(validRequestList());
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.errorMessage);
    }
}
