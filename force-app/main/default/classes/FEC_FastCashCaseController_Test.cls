@IsTest
private class FEC_FastCashCaseController_Test {

    private static final String VALID_ACCOUNT = '0001500010000000261';

    @TestSetup
    static void setupData() {
        insert new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://api-gateway.test.local',
            FEC_Call_Mock__c = false
        );

        FEC_Product_Type__c productType = new FEC_Product_Type__c(
            Name = 'Card',
            FEC_Code__c = 'CC',
            FEC_Active__c = true
        );
        insert productType;

        FEC_Sub_Category__c subCatRc35 = new FEC_Sub_Category__c(
            Name = 'RC35',
            FEC_Code__c = 'RC35',
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subCatOther = new FEC_Sub_Category__c(
            Name = 'RC27',
            FEC_Code__c = 'RC27',
            FEC_Active__c = true
        );
        insert new List<FEC_Sub_Category__c>{ subCatRc35, subCatOther };

        Case mainCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            mainCase = new Case(
                Subject = 'Fast Cash Test',
                Status = 'New',
                FEC_Account_Number__c = VALID_ACCOUNT,
                FEC_Application_ID__c = 'APP-CRM-001',
                FEC_Max_Amount__c = 5000000,
                FEC_Requested_Amount__c = 1000000,
                FEC_Disbursement_Status__c = FEC_ConstantCommon.DISB_API_STATUS_WITHDRAWN,
                FEC_Disbursement_Date__c = Date.today(),
                FEC_Product_Type__c = productType.Id,
                FEC_SubCategory__c = subCatRc35.Id,
                FEC_ID_Search__c = 'FCASH-' + String.valueOf(System.currentTimeMillis())
            );
            insert mainCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = mainCase.Id,
            FEC_Account_Number__c = VALID_ACCOUNT,
            FEC_Disbursement_Date__c = Date.today().addDays(-1)
        );
        insert hist;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = mainCase.Id,
                FEC_Account_or_Contract__c = hist.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Pending_Disbursement__c(
            FEC_Case__c = mainCase.Id,
            FEC_PD_Disbursement_Status__c = FEC_ConstantCommon.DISB_API_STATUS_CANCELLED_BY_CUSTOMER,
            FEC_PD_Application_ID__c = 'APP-CRM-001'
        );
    }

    private static Id fakeCaseId() {
        return (Id) (Case.SObjectType.getDescribe().getKeyPrefix() + '0'.repeat(12) + 'AAA');
    }

    private static Case getMainCase() {
        return [
            SELECT Id, FEC_Max_Amount__c
            FROM Case
            WHERE Subject = 'Fast Cash Test'
            LIMIT 1
        ];
    }

    private class FastCashApiMock implements HttpCalloutMock {
        private String ippEligible;
        private String cardRemainingCash;
        private String cmsCode;

        FastCashApiMock(String ippEligible, String cardRemainingCash, String cmsCode) {
            this.ippEligible = ippEligible;
            this.cardRemainingCash = cardRemainingCash;
            this.cmsCode = cmsCode;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String endpoint = req.getEndpoint() == null ? '' : req.getEndpoint();
            String body = req.getBody() == null ? '' : req.getBody();

            if (body.contains('CheckEligibility')) {
                if ('fail'.equals(ippEligible)) {
                    res.setBody(
                        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://fecredit.com.vn/CMS_IPP_BlockWS">' +
                        '<soapenv:Body><ns1:CheckEligibilityResponse>' +
                        '<Sys><Code>2</Code><Description>Account not found</Description></Sys>' +
                        '</ns1:CheckEligibilityResponse></soapenv:Body></soapenv:Envelope>'
                    );
                } else {
                    res.setBody(
                        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://fecredit.com.vn/CMS_IPP_BlockWS">' +
                        '<soapenv:Body><ns1:CheckEligibilityResponse>' +
                        '<Sys><TransID>123</TransID><Code>0</Code><Description>Success</Description></Sys>' +
                        '<Details><AccEligibility>' + ippEligible + '</AccEligibility></Details>' +
                        '</ns1:CheckEligibilityResponse></soapenv:Body></soapenv:Envelope>'
                    );
                }
            } else if (body.contains('GetCardSecInfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCardSecInfoResponse>' +
                    '<Sys><Code>1</Code><Description>Success</Description></Sys>' +
                    '<CardSecInfo><MainCardBalance><RemainingCashLimit>' + cardRemainingCash + '</RemainingCashLimit></MainCardBalance></CardSecInfo>' +
                    '</GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
            } else if (body.contains('CMSIPPBlock')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + FEC_ConstantCommon.SOAP_ENV + '">' +
                    '<soapenv:Body>' +
                    '<CMSIPPBlockResponse xmlns="http://fecredit.com.vn/CMS_IPP_BlockWS">' +
                    '<Sys>' +
                    '<TransID>TRX-123</TransID>' +
                    '<DateTime>2026-05-28T18:00:00</DateTime>' +
                    '<Code>' + cmsCode + '</Code>' +
                    '<Description>Block result</Description>' +
                    '</Sys>' +
                    '<AvailableCredit>1500000</AvailableCredit>' +
                    '</CMSIPPBlockResponse>' +
                    '</soapenv:Body>' +
                    '</soapenv:Envelope>'
                );
            } else if (body.contains('GetCustomerList')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><cif:GetCustomerListResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
                    '<Sys><Code>1</Code><Description>Success</Description></Sys>' +
                    '<Customers><Customer><Applications><Application><ApplicationID>APP-FROM-LIST</ApplicationID></Application></Applications></Customer></Customers>' +
                    '</cif:GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
                );
            } else if (endpoint.contains('APPLICATION_ID')) {
                res.setBody(
                    '{' +
                    '"Sys":{"TransID":"TXN-1","DateTime":"2026-10-25T10:00:00.000Z","Code":1,"Description":"Success"},' +
                    '"CustomerSaleInfos":[{"APPLICATION_ID":"APP-CRM-001","DISB_CHANNEL":"BRANCH"}]' +
                    '}'
                );
            } else {
                res.setBody('');
            }
            return res;
        }
    }

    @IsTest
    static void testGetCaseFastCashState_NullAndNotFound() {
        Test.startTest();
        FEC_FastCashCaseController.CaseFastCashStateDTO nullDto =
            FEC_FastCashCaseController.getCaseFastCashState(null);
        FEC_FastCashCaseController.CaseFastCashStateDTO missingDto =
            FEC_FastCashCaseController.getCaseFastCashState(fakeCaseId());
        Test.stopTest();

        System.assertEquals(null, nullDto.actualNatureOfCaseId);
        System.assertEquals(null, missingDto.applicationId);
    }

    @IsTest
    static void testGetCaseFastCashState_ReturnsMappedValues() {
        Case c = getMainCase();

        Test.startTest();
        FEC_FastCashCaseController.CaseFastCashStateDTO state =
            FEC_FastCashCaseController.getCaseFastCashState(c.Id);
        Test.stopTest();

        System.assertEquals('APP-CRM-001', state.applicationId);
        System.assertEquals(1000000, state.requestedAmount);
        System.assertEquals(5000000, state.maxAmount);
        System.assertEquals(
            FEC_ConstantCommon.FAST_CASH_DISB_STATUS_RESOLVED_CUSTOMER_CANCELLED,
            state.disbursementStatus
        );
        System.assertNotEquals(null, state.disbursementDate);
    }

    @IsTest
    static void testSaveFastCashCaseAmounts_SuccessAndNullCaseId() {
        Case c = getMainCase();

        Test.startTest();
        FEC_FastCashCaseController.SaveFastCashResultDTO invalid =
            FEC_FastCashCaseController.saveFastCashCaseAmounts(null, 100, 200);
        FEC_FastCashCaseController.SaveFastCashResultDTO success =
            FEC_FastCashCaseController.saveFastCashCaseAmounts(c.Id, 2000000, 6000000);
        Test.stopTest();

        System.assertEquals(false, invalid.success);
        System.assertEquals(true, success.success);

        Case updated = [
            SELECT FEC_Requested_Amount__c, FEC_Max_Amount__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals(2000000, updated.FEC_Requested_Amount__c);
        System.assertEquals(6000000, updated.FEC_Max_Amount__c);
    }

    @IsTest
    static void testCheckFastCashEligibility_ValidationAndNoAccount() {
        FEC_CaseTriggerHandler.isExecuting = true;
        Case noAccCase;
        try {
            noAccCase = new Case(
                Subject = 'No Account',
                FEC_ID_Search__c = 'FCASH-NA-' + String.valueOf(System.currentTimeMillis())
            );
            insert noAccCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_FastCashCaseController.FastCashEligibilityDTO nullCase =
            FEC_FastCashCaseController.checkFastCashEligibility(null);
        FEC_FastCashCaseController.FastCashEligibilityDTO missingCase =
            FEC_FastCashCaseController.checkFastCashEligibility(fakeCaseId());
        FEC_FastCashCaseController.FastCashEligibilityDTO noAccount =
            FEC_FastCashCaseController.checkFastCashEligibility(noAccCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, nullCase.technicalMessage);
        System.assertNotEquals(null, missingCase.technicalMessage);
        System.assertEquals('NO_ACCOUNT', noAccount.errorCode);
        System.assertEquals(true, noAccount.callCompleted);
    }

    @IsTest
    static void testCheckFastCashEligibility_IppFailure() {
        Case c = getMainCase();
        Test.setMock(HttpCalloutMock.class, new FastCashApiMock('fail', '0', '1'));

        Test.startTest();
        FEC_FastCashCaseController.FastCashEligibilityDTO ippFail =
            FEC_FastCashCaseController.checkFastCashEligibility(c.Id);
        Test.stopTest();

        System.assertEquals(true, ippFail.callCompleted);
        System.assertNotEquals(null, ippFail.errorDescription);
    }

    @IsTest
    static void testCheckFastCashEligibility_NotEligibleFromIpp() {
        Case c = getMainCase();
        Test.setMock(HttpCalloutMock.class, new FastCashApiMock('false', '0', '1'));

        Test.startTest();
        FEC_FastCashCaseController.FastCashEligibilityDTO notEligible =
            FEC_FastCashCaseController.checkFastCashEligibility(c.Id);
        Test.stopTest();

        System.assertEquals(true, notEligible.callCompleted);
        System.assertNotEquals(null, notEligible.fastCashStatus);
    }

    @IsTest
    static void testCheckFastCashEligibility_Eligible() {
        Case c = getMainCase();
        Test.setMock(HttpCalloutMock.class, new FastCashApiMock('true', '5000000', '1'));

        Test.startTest();
        FEC_FastCashCaseController.FastCashEligibilityDTO eligible =
            FEC_FastCashCaseController.checkFastCashEligibility(c.Id);
        Test.stopTest();

        System.assertEquals(true, eligible.callCompleted);
        System.assertEquals(5000000, eligible.maxAmount);
    }

    @IsTest
    static void testCheckFastCashEligibility_ZeroCashLimit() {
        Case c = getMainCase();
        Test.setMock(HttpCalloutMock.class, new FastCashApiMock('true', '0', '1'));

        Test.startTest();
        FEC_FastCashCaseController.FastCashEligibilityDTO zeroLimit =
            FEC_FastCashCaseController.checkFastCashEligibility(c.Id);
        Test.stopTest();

        System.assertEquals('LIMIT', zeroLimit.errorCode);
    }

    @IsTest
    static void testPrepareFastCashBlockContext_ValidationErrors() {
        Test.startTest();
        FEC_FastCashCaseController.FastCashBlockContextDTO nullCase =
            FEC_FastCashCaseController.prepareFastCashBlockContext(null);
        FEC_FastCashCaseController.FastCashBlockContextDTO missingCase =
            FEC_FastCashCaseController.prepareFastCashBlockContext(fakeCaseId());
        Test.stopTest();

        System.assertEquals(false, nullCase.success);
        System.assertEquals(false, missingCase.success);
    }

    @IsTest
    static void testPrepareFastCashBlockContext_SuccessWithApplicationId() {
        Case c = getMainCase();
        Test.setMock(HttpCalloutMock.class, new FastCashApiMock('true', '5000000', '1'));

        Test.startTest();
        FEC_FastCashCaseController.FastCashBlockContextDTO withAppId =
            FEC_FastCashCaseController.prepareFastCashBlockContext(c.Id);
        Test.stopTest();

        System.assertEquals(true, withAppId.success);
        System.assertEquals('APP-CRM-001', withAppId.crmId);
        System.assertEquals('BRANCH', withAppId.disbChannel);
    }

    @IsTest
    static void testPrepareFastCashBlockContext_ResolveApplicationFromCustomerList() {
        Case c = getMainCase();
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Application_ID__c = null
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.setMock(HttpCalloutMock.class, new FastCashApiMock('true', '5000000', '1'));
        Test.startTest();
        FEC_FastCashCaseController.FastCashBlockContextDTO ctx =
            FEC_FastCashCaseController.prepareFastCashBlockContext(c.Id);
        Test.stopTest();

        System.assertEquals(true, ctx.success);
        System.assertEquals('APP-FROM-LIST', ctx.crmId);
    }

    @IsTest
    static void testExecuteFastCashBlock_ValidationErrors() {
        Case c = getMainCase();

        Test.startTest();
        FEC_FastCashCaseController.BlockResultDTO missingParams =
            FEC_FastCashCaseController.executeFastCashBlock(c.Id, null, 'APP-CRM-001', 'BRANCH');
        FEC_FastCashCaseController.BlockResultDTO missingChannel =
            FEC_FastCashCaseController.executeFastCashBlock(c.Id, 1000000, null, null);
        Test.stopTest();

        System.assertEquals(false, missingParams.success);
        System.assertEquals(false, missingChannel.success);
    }

    @IsTest
    static void testExecuteFastCashBlock_Success() {
        Case c = getMainCase();
        if ([SELECT COUNT() FROM FEC_API_Setting__c] == 0) {
            insert new FEC_API_Setting__c(
                FEC_Endpoint__c = 'https://api-gateway.fecredit.com.vn'
            );
        }
        Test.setMock(HttpCalloutMock.class, new FastCashApiMock('true', '5000000', '1'));

        Test.startTest();
        FEC_FastCashCaseController.BlockResultDTO success =
            FEC_FastCashCaseController.executeFastCashBlock(
                c.Id,
                1000000,
                'APP-CRM-001',
                'BRANCH'
            );
        Test.stopTest();

        System.assertNotEquals(null, success, 'Kết quả block không được null.');
        if (!success.success) {
            System.assertNotEquals(null, success.errorMessage, 'Nếu fail thì phải có errorMessage.');
        } else {
            System.assertEquals('1', success.sysCode);
        }
    }

    @IsTest
    static void testExecuteFastCashBlock_BusinessFailure() {
        Case c = getMainCase();
        Test.setMock(HttpCalloutMock.class, new FastCashApiMock('true', '5000000', '99'));

        Test.startTest();
        FEC_FastCashCaseController.BlockResultDTO businessFail =
            FEC_FastCashCaseController.executeFastCashBlock(
                c.Id,
                1000000,
                'APP-CRM-001',
                'BRANCH'
            );
        Test.stopTest();

        System.assertEquals(false, businessFail.success);
        System.assertNotEquals(null, businessFail.errorMessage);
    }

    @IsTest
    static void testExecuteFastCashBlock_FecCmsResponseCodes() {
        Case c = getMainCase();
        Map<String, Boolean> expectedSuccess = new Map<String, Boolean>{
            '0' => true,
            '1' => true,
            '4' => true,
            '2' => false,
            '10' => false,
            '21' => false
        };
        for (String code : expectedSuccess.keySet()) {
            Test.setMock(HttpCalloutMock.class, new FastCashApiMock('true', '5000000', code));
            FEC_FastCashCaseController.BlockResultDTO result =
                FEC_FastCashCaseController.executeFastCashBlock(
                    c.Id,
                    1000000,
                    'APP-CRM-001',
                    'BRANCH'
                );
            System.assertEquals(
                expectedSuccess.get(code),
                result.success,
                'CMSIPPBlock Code ' + code
            );
            System.assertEquals(code, result.sysCode, 'sysCode phải khớp Code ' + code);
            if (!result.success) {
                System.assertNotEquals(null, result.errorMessage, 'Code ' + code + ' fail phải có errorMessage');
            }
        }
    }

    @IsTest
    static void testFinalizeFastCashOnSubmit_Rc35AndNonRc35() {
        Case rc35Case = getMainCase();
        delete [SELECT Id FROM FEC_Pending_Disbursement__c WHERE FEC_Case__c = :rc35Case.Id];

        FEC_Sub_Category__c otherSub = [
            SELECT Id
            FROM FEC_Sub_Category__c
            WHERE FEC_Code__c = 'RC27'
            LIMIT 1
        ];

        FEC_CaseTriggerHandler.isExecuting = true;
        Case otherCase;
        try {
            otherCase = new Case(
                Subject = 'Non RC35',
                Status = 'New',
                FEC_Account_Number__c = VALID_ACCOUNT,
                FEC_SubCategory__c = otherSub.Id,
                FEC_ID_Search__c = 'FCASH-OTHER-' + String.valueOf(System.currentTimeMillis())
            );
            insert otherCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_FastCashCaseController.SaveFastCashResultDTO rc35Result =
            FEC_FastCashCaseController.finalizeFastCashOnSubmit(rc35Case.Id, 1500000, 5000000);
        FEC_FastCashCaseController.SaveFastCashResultDTO otherResult =
            FEC_FastCashCaseController.finalizeFastCashOnSubmit(otherCase.Id, 1500000, 5000000);
        Test.stopTest();

        System.assertEquals(true, rc35Result.success);
        System.assertEquals(true, otherResult.success);

        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_Pending_Disbursement__c WHERE FEC_Case__c = :rc35Case.Id],
            'RC35 submit phải tạo pending disbursement.'
        );

        System.assertEquals(
            0,
            [SELECT COUNT() FROM FEC_Pending_Disbursement__c WHERE FEC_Case__c = :otherCase.Id]
        );
    }

    @IsTest
    static void testMapDisbursementStatusAndHelpers() {
        Test.startTest();
        System.assertEquals(
            FEC_ConstantCommon.FAST_CASH_DISB_STATUS_SUCCESS,
            FEC_FastCashCaseController.mapDisbursementStatusForDisplay(
                FEC_ConstantCommon.DISB_API_STATUS_WITHDRAWN
            )
        );
        System.assertEquals(
            FEC_ConstantCommon.FAST_CASH_DISB_STATUS_RESOLVED_CUSTOMER_CANCELLED,
            FEC_FastCashCaseController.mapDisbursementStatusForDisplay(
                FEC_ConstantCommon.DISB_API_STATUS_CANCELLED_BY_CUSTOMER
            )
        );
        System.assertEquals(
            FEC_ConstantCommon.FAST_CASH_DISB_STATUS_RESOLVED_WITHDRAWAL_EXPIRED,
            FEC_FastCashCaseController.mapDisbursementStatusForDisplay(
                FEC_ConstantCommon.DISB_API_STATUS_AUTO_CANCELLED
            )
        );
        System.assertEquals(
            'CustomStatus',
            FEC_FastCashCaseController.mapApiDisbursementStatusToCaseValue('CustomStatus')
        );
        System.assertEquals(null, FEC_FastCashCaseController.mapDisbursementStatusForDisplay(null));
        Test.stopTest();
    }

    @IsTest
    static void testUpsertPendingDisbursementAndUpdateHistoryDate() {
        Case c = getMainCase();
        delete [SELECT Id FROM FEC_Pending_Disbursement__c WHERE FEC_Case__c = :c.Id];

        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];

        Test.startTest();
        FEC_FastCashCaseController.upsertPendingDisbursementStatus(
            c.Id,
            FEC_ConstantCommon.FAST_CASH_DISB_STATUS_PENDING_CUSTOMER_WITHDRAWAL,
            'APP-UPSERT-001'
        );
        FEC_FastCashCaseController.upsertPendingDisbursementStatus(
            c.Id,
            FEC_ConstantCommon.FAST_CASH_DISB_STATUS_SUCCESS,
            'APP-UPSERT-001'
        );
        FEC_FastCashCaseController.updateCustomerHistoryDisbursementDate(hist.Id, Date.today());
        FEC_FastCashCaseController.upsertPendingDisbursementStatus(null, 'X', 'Y');
        FEC_FastCashCaseController.updateCustomerHistoryDisbursementDate(null, Date.today());
        Test.stopTest();

        FEC_Pending_Disbursement__c pending = [
            SELECT Id, FEC_PD_Disbursement_Status__c, FEC_PD_Application_ID__c
            FROM FEC_Pending_Disbursement__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, pending.Id, 'Phải upsert được pending disbursement.');
        if (String.isNotBlank(pending.FEC_PD_Disbursement_Status__c)) {
            System.assertEquals(FEC_ConstantCommon.FAST_CASH_DISB_STATUS_SUCCESS, pending.FEC_PD_Disbursement_Status__c);
        }
        if (String.isNotBlank(pending.FEC_PD_Application_ID__c)) {
            System.assertEquals('APP-UPSERT-001', pending.FEC_PD_Application_ID__c);
        }

        FEC_Customer_History__c updatedHist = [
            SELECT FEC_Disbursement_Date__c
            FROM FEC_Customer_History__c
            WHERE Id = :hist.Id
        ];
        System.assertNotEquals(null, updatedHist.FEC_Disbursement_Date__c);
    }
}
