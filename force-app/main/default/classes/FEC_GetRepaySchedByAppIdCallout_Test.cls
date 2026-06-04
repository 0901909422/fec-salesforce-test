@IsTest
private class FEC_GetRepaySchedByAppIdCallout_Test {

    private static final String MOCK_SUCCESS_JSON =
        '{' +
        '"pxObjClass":"Data-RepaymentSchedule",' +
        '"Data":[{' +
        '"ResponseInfo":{' +
        '"Status":"SUCCESS",' +
        '"CUSTOMER_NAME":"Nguyen Van A",' +
        '"CONTRACT_NUMBER":"CN-001",' +
        '"N_TENURE":12,' +
        '"TOTAL_LOAN_AMOUNT":10000000,' +
        '"RepaymentScheduleItems":[{' +
        '"DUE_DATE":"2026-07-01",' +
        '"PRINCIPAL_AMOUNT":800000,' +
        '"INTEREST_AMOUNT":120000,' +
        '"TOTAL_REPAYMENT_FEE":920000' +
        '}]' +
        '}' +
        '}]' +
        '}';

    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Endpoint__c = 'https://test-api.fecredit.com.vn';
        apiSetting.FEC_Call_Mock__c = false;
        upsert apiSetting;
    }

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody(MOCK_SUCCESS_JSON);
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"error":"server error"}');
            return res;
        }
    }

    @IsTest
    static void testGetRepaymentScheduleByAppId_Success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_GetRepaymentScheduleByAppIdCallout.GetRepaymentScheduleResponse result =
            FEC_GetRepaymentScheduleByAppIdCallout.getRepaymentScheduleByAppId(
                'APP-123456',
                'PEGA-CSM'
            );
        Test.stopTest();

        System.assertEquals(true, FEC_GetRepaymentScheduleByAppIdCallout.isSuccess(result));
        FEC_GetRepaymentScheduleByAppIdCallout.RepaymentScheduleResponseInfo info =
            FEC_GetRepaymentScheduleByAppIdCallout.getFirstResponseInfo(result);
        System.assertNotEquals(null, info);
        System.assertEquals('SUCCESS', info.Status);
        System.assertEquals('Nguyen Van A', info.CUSTOMER_NAME);
        System.assertEquals('CN-001', info.CONTRACT_NUMBER);
        System.assertEquals(1, info.RepaymentScheduleItems.size());
    }

    @IsTest
    static void testGetRepaymentScheduleByAppId_HttpError() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        FEC_GetRepaymentScheduleByAppIdCallout.GetRepaymentScheduleResponse result =
            FEC_GetRepaymentScheduleByAppIdCallout.getRepaymentScheduleByAppId('APP-999', null);
        Test.stopTest();

        System.assertEquals(false, FEC_GetRepaymentScheduleByAppIdCallout.isSuccess(result));
        System.assertEquals('500', result.errorCode);
        System.assertNotEquals(null, result.errorMessage);
    }

    @IsTest
    static void testGetRepaymentScheduleByAppId_BlankAppId() {
        Test.startTest();
        FEC_GetRepaymentScheduleByAppIdCallout.GetRepaymentScheduleResponse result =
            FEC_GetRepaymentScheduleByAppIdCallout.getRepaymentScheduleByAppId('  ', null);
        Test.stopTest();

        System.assertEquals(false, FEC_GetRepaymentScheduleByAppIdCallout.isSuccess(result));
        System.assertEquals('CALLOUT_EXCEPTION', result.errorCode);
        System.assertNotEquals(null, result.errorMessage);
    }

    @IsTest
    static void testParseResponseBody_WithResponseInfo() {
        Test.startTest();
        FEC_GetRepaymentScheduleByAppIdCallout.GetRepaymentScheduleResponse parsed =
            FEC_GetRepaymentScheduleByAppIdCallout.parseResponseBody(MOCK_SUCCESS_JSON);
        Test.stopTest();

        System.assertNotEquals(null, parsed.Data);
        System.assertEquals(1, parsed.Data.size());
        System.assertEquals('SUCCESS', parsed.Data[0].ResponseInfo.Status);
    }

    @IsTest
    static void testMapResponseInfo_FlatFields() {
        Map<String, Object> infoMap = new Map<String, Object>{
            'Status' => 'SUCCESS',
            'CUSTOMER_NAME' => 'Flat Customer',
            'CONTRACT_NUMBER' => 'CN-FLAT',
            'N_TENURE' => 12,
            'IS_NORMAL_RATE' => 'Y',
            'RepaymentScheduleItems' => new List<Object>{
                new Map<String, Object>{
                    'DUE_DATE' => '2026-08-01',
                    'PRINCIPAL_AMOUNT' => 500000
                }
            }
        };

        Test.startTest();
        FEC_GetRepaymentScheduleByAppIdCallout.RepaymentScheduleResponseInfo info =
            FEC_GetRepaymentScheduleByAppIdCallout.mapResponseInfo(infoMap);
        Test.stopTest();

        System.assertEquals('SUCCESS', info.Status);
        System.assertEquals('Flat Customer', info.CUSTOMER_NAME);
        System.assertEquals('CN-FLAT', info.CONTRACT_NUMBER);
        System.assertEquals(1, info.RepaymentScheduleItems.size());
    }

    @IsTest
    static void testParseResponseBody_UntypedFallback() {
        String jsonBody =
            '{' +
            '"pxObjClass":"Flat",' +
            '"Data":[{"Status":"SUCCESS","CUSTOMER_NAME":"Fallback Customer"}]' +
            '}';

        Test.startTest();
        FEC_GetRepaymentScheduleByAppIdCallout.GetRepaymentScheduleResponse parsed =
            FEC_GetRepaymentScheduleByAppIdCallout.parseResponseBody(jsonBody);
        Test.stopTest();

        System.assertNotEquals(null, parsed);
    }

    @IsTest
    static void testIsSuccessAndGetFirstResponseInfo_EdgeCases() {
        Test.startTest();
        System.assertEquals(false, FEC_GetRepaymentScheduleByAppIdCallout.isSuccess(null));
        System.assertEquals(
            null,
            FEC_GetRepaymentScheduleByAppIdCallout.getFirstResponseInfo(null)
        );

        FEC_GetRepaymentScheduleByAppIdCallout.GetRepaymentScheduleResponse empty =
            new FEC_GetRepaymentScheduleByAppIdCallout.GetRepaymentScheduleResponse();
        empty.Data = new List<FEC_GetRepaymentScheduleByAppIdCallout.RepaymentScheduleDataRecord>();
        System.assertEquals(false, FEC_GetRepaymentScheduleByAppIdCallout.isSuccess(empty));
        Test.stopTest();
    }
}
