@IsTest
private class FEC_GetCardTransactions_Test {

    private static final String MOCK_JSON_RESPONSE =
        '{' +
        '  "Sys": {"Code": 1, "Description": "Success", "TransID": "TXN123"},' +
        '  "CardTransactions": [{' +
        '    "IPPPlan": "PLAN001", ' +
        '    "PlanDescription": "Installment Plan"' +
        '  }]' +
        '}';

    @IsTest
    static void testGetCardTransactions_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_RESPONSE));

        Test.startTest();
        FEC_GetCardTransactions.CardTxnResponse res = FEC_GetCardTransactions.getCardTransactions(
            'TXN123', FEC_ConstantCommon.REQUESTOR_CRM, 'ACC123', Date.today().addDays(-7), Date.today()
        );
        Test.stopTest();

        System.assertEquals(1, res.Sys.Code, 'Kết quả phải thành công.');
        System.assertEquals('PLAN001', res.CardTransactions[0].IPPPlan);
    }

    @IsTest
    static void testGetCardTransactions_Http500() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        FEC_GetCardTransactions.CardTxnResponse res = FEC_GetCardTransactions.getCardTransactions(
            'TXN500', FEC_ConstantCommon.REQUESTOR_CRM, 'ACC500', Date.today().addDays(-3), Date.today()
        );
        Test.stopTest();

        System.assertEquals('500', res.errorCode);
        System.assertNotEquals(null, res.errorMessage);
    }

    @IsTest
    static void testValidateRequest_InvalidRange() {
        Test.startTest();
        FEC_GetCardTransactions.ValidationResult val = FEC_GetCardTransactions.validateRequest(
            'TXN1', FEC_ConstantCommon.REQUESTOR_CRM, 'ACC1', Date.today(), Date.today().addDays(-1)
        );
        Test.stopTest();

        System.assertEquals(false, val.isValid, 'Ngày kết thúc không được nhỏ hơn ngày bắt đầu.');
        System.assertEquals(System.Label.FEC_MSG_EndDate_Must_StartDate, val.errorMessage);
    }

    @IsTest
    static void testValidateRequest_BlankFields() {
        Date startDate = Date.today().addDays(-7);
        Date endDate = Date.today();

        Test.startTest();
        FEC_GetCardTransactions.ValidationResult blankTransId =
            FEC_GetCardTransactions.validateRequest('', FEC_ConstantCommon.REQUESTOR_CRM, 'ACC1', startDate, endDate);
        FEC_GetCardTransactions.ValidationResult blankRequestor =
            FEC_GetCardTransactions.validateRequest('TXN1', '', 'ACC1', startDate, endDate);
        FEC_GetCardTransactions.ValidationResult invalidRequestor =
            FEC_GetCardTransactions.validateRequest('TXN1', 'INVALID', 'ACC1', startDate, endDate);
        FEC_GetCardTransactions.ValidationResult blankAccount =
            FEC_GetCardTransactions.validateRequest('TXN1', FEC_ConstantCommon.REQUESTOR_CRM, '', startDate, endDate);
        FEC_GetCardTransactions.ValidationResult blankStartDate =
            FEC_GetCardTransactions.validateRequest('TXN1', FEC_ConstantCommon.REQUESTOR_CRM, 'ACC1', null, endDate);
        FEC_GetCardTransactions.ValidationResult blankEndDate =
            FEC_GetCardTransactions.validateRequest('TXN1', FEC_ConstantCommon.REQUESTOR_CRM, 'ACC1', startDate, null);
        Test.stopTest();

        System.assertEquals(false, blankTransId.isValid);
        System.assertEquals(System.Label.FEC_MSG_TransID_Null, blankTransId.errorMessage);
        System.assertEquals(false, blankRequestor.isValid);
        System.assertEquals(System.Label.FEC_MSG_RequestorID_Null, blankRequestor.errorMessage);
        System.assertEquals(false, invalidRequestor.isValid);
        System.assertEquals(false, blankAccount.isValid);
        System.assertEquals(false, blankStartDate.isValid);
        System.assertEquals(false, blankEndDate.isValid);
    }

    @IsTest
    static void testIsSuccess() {
        FEC_GetCardTransactions.CardTxnResponse successRes = new FEC_GetCardTransactions.CardTxnResponse();
        successRes.Sys = new FEC_GetCardTransactions.Sys();
        successRes.Sys.Code = 1;

        FEC_GetCardTransactions.CardTxnResponse failRes = new FEC_GetCardTransactions.CardTxnResponse();
        failRes.Sys = new FEC_GetCardTransactions.Sys();
        failRes.Sys.Code = 0;

        Test.startTest();
        System.assertEquals(true, FEC_GetCardTransactions.isSuccess(successRes));
        System.assertEquals(false, FEC_GetCardTransactions.isSuccess(failRes));
        System.assertEquals(false, FEC_GetCardTransactions.isSuccess(null));
        Test.stopTest();
    }

    @IsTest
    static void testValidateResponse() {
        FEC_GetCardTransactions.CardTxnResponse nullRes = null;
        FEC_GetCardTransactions.CardTxnResponse errorRes = new FEC_GetCardTransactions.CardTxnResponse();
        errorRes.errorCode = '404';
        errorRes.errorMessage = 'Not Found';
        FEC_GetCardTransactions.CardTxnResponse sysNullRes = new FEC_GetCardTransactions.CardTxnResponse();
        FEC_GetCardTransactions.CardTxnResponse badCodeRes = new FEC_GetCardTransactions.CardTxnResponse();
        badCodeRes.Sys = new FEC_GetCardTransactions.Sys();
        badCodeRes.Sys.Code = 0;
        badCodeRes.Sys.Description = 'Business Error';
        FEC_GetCardTransactions.CardTxnResponse okRes = new FEC_GetCardTransactions.CardTxnResponse();
        okRes.Sys = new FEC_GetCardTransactions.Sys();
        okRes.Sys.Code = 1;

        Test.startTest();
        FEC_GetCardTransactions.ValidationResult nullVal = FEC_GetCardTransactions.validateResponse(nullRes);
        FEC_GetCardTransactions.ValidationResult errorVal = FEC_GetCardTransactions.validateResponse(errorRes);
        FEC_GetCardTransactions.ValidationResult sysNullVal = FEC_GetCardTransactions.validateResponse(sysNullRes);
        FEC_GetCardTransactions.ValidationResult badCodeVal = FEC_GetCardTransactions.validateResponse(badCodeRes);
        FEC_GetCardTransactions.ValidationResult okVal = FEC_GetCardTransactions.validateResponse(okRes);
        Test.stopTest();

        System.assertEquals(false, nullVal.isValid);
        System.assertEquals(System.Label.FEC_MSG_Response_Null, nullVal.errorMessage);
        System.assertEquals(false, errorVal.isValid);
        System.assertEquals('404 - Not Found', errorVal.errorMessage);
        System.assertEquals(false, sysNullVal.isValid);
        System.assertEquals(System.Label.FEC_MSG_Response_Sys_Null, sysNullVal.errorMessage);
        System.assertEquals(false, badCodeVal.isValid);
        System.assertEquals('Business Error', badCodeVal.errorMessage);
        System.assertEquals(true, okVal.isValid);
    }

    @IsTest
    static void testConvertToResultWrapper_Error() {
        FEC_GetCardTransactions.CardTxnResponse res = new FEC_GetCardTransactions.CardTxnResponse();
        res.errorCode = '404';
        res.errorMessage = 'Not Found';

        Test.startTest();
        FEC_GetCardTransactions.ResultWrapper wrapper = FEC_GetCardTransactions.convertToResultWrapper(res);
        Test.stopTest();

        System.assertEquals(false, wrapper.isSuccess);
        System.assertEquals('404 - Not Found', wrapper.errorMessage);
    }

    @IsTest
    static void testIsSuccess_NullSys() {
        FEC_GetCardTransactions.CardTxnResponse res = new FEC_GetCardTransactions.CardTxnResponse();

        Test.startTest();
        System.assertEquals(false, FEC_GetCardTransactions.isSuccess(res));
        Test.stopTest();
    }

    @IsTest
    static void testConvertToResultWrapper_NullTransactions() {
        FEC_GetCardTransactions.CardTxnResponse res = new FEC_GetCardTransactions.CardTxnResponse();
        res.Sys = new FEC_GetCardTransactions.Sys();
        res.Sys.Code = 1;
        res.Sys.TransID = 'TXN-EMPTY';
        res.CardTransactions = null;

        Test.startTest();
        FEC_GetCardTransactions.ResultWrapper wrapper = FEC_GetCardTransactions.convertToResultWrapper(res);
        Test.stopTest();

        System.assertEquals(true, wrapper.isSuccess);
        System.assertEquals(0, wrapper.transactions.size());
    }

    @IsTest
    static void testConvertToResultWrapper_Success() {
        FEC_GetCardTransactions.CardTxnResponse res = new FEC_GetCardTransactions.CardTxnResponse();
        res.Sys = new FEC_GetCardTransactions.Sys();
        res.Sys.Code = 1;
        res.Sys.TransID = 'TXN-OK';
        res.CardTransactions = new List<FEC_GetCardTransactions.CardTransaction>();
        FEC_GetCardTransactions.CardTransaction txn = new FEC_GetCardTransactions.CardTransaction();
        txn.IPPPlan = 'PLAN002';
        res.CardTransactions.add(txn);

        Test.startTest();
        FEC_GetCardTransactions.ResultWrapper wrapper = FEC_GetCardTransactions.convertToResultWrapper(res);
        Test.stopTest();

        System.assertEquals(true, wrapper.isSuccess);
        System.assertEquals('TXN-OK', wrapper.transId);
        System.assertEquals(1, wrapper.transactions.size());
        System.assertEquals('PLAN002', wrapper.transactions[0].IPPPlan);
    }

    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer code;
        String body;

        MockHttpResponseGenerator(Integer code, String body) {
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
