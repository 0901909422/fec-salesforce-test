/**
 * Unit tests for FEC_InsuranceInfoController (insurance sync, paging, sensitive log).
 */
@IsTest
private class FEC_InsuranceInfoController_Test {

    private static final String SUBJECT_SYNC = 'FEC_InsuranceInfoController_Test Sync';
    private static final String SUBJECT_BLANK_NID = 'FEC_InsuranceInfoController_Test Blank NID';
    private static final String SUBJECT_FETCH = 'FEC_InsuranceInfoController_Test Fetch';
    private static final String SUBJECT_NO_HISTORY = 'FEC_InsuranceInfoController_Test No History';
    private static final String NATIONAL_ID = '987654321';
    private static final String USER_EXISTING = 'INS_USER_EXISTING';
    private static final String USER_NEW = 'INS_USER_NEW';
    private static final String USER_CANCEL = 'INS_USER_CANCEL';
    private static final String USER_SLASH_DATE = 'INS_USER_SLASH';

    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Endpoint__c = 'https://test-api.fecredit.com.vn';
        apiSetting.FEC_Call_Mock__c = false;
        upsert apiSetting;

        Case syncCase = insertCase(SUBJECT_SYNC, NATIONAL_ID);
        FEC_Customer_History__c history = new FEC_Customer_History__c(
            Name = 'InsuranceInfo Test History',
            FEC_Case__c = syncCase.Id,
            FEC_National_ID_Passport_ID__c = NATIONAL_ID
        );
        insert history;

        insert new FEC_Insurance_Info__c(
            FEC_Customer_History__c = history.Id,
            FEC_User_ID__c = USER_EXISTING,
            FEC_Buyer_Name__c = 'Existing Buyer',
            FEC_Premium_Fee__c = 100000,
            FEC_Status__c = 'Còn hiệu lực'
        );

        Case fetchCase = insertCase(SUBJECT_FETCH, NATIONAL_ID);
        FEC_Customer_History__c fetchHistory = new FEC_Customer_History__c(
            Name = 'InsuranceInfo Fetch History',
            FEC_Case__c = fetchCase.Id
        );
        insert fetchHistory;

        List<FEC_Insurance_Info__c> rows = new List<FEC_Insurance_Info__c>();
        for (Integer i = 1; i <= 3; i++) {
            rows.add(new FEC_Insurance_Info__c(
                FEC_Customer_History__c = fetchHistory.Id,
                FEC_User_ID__c = 'FETCH_USER_' + i,
                FEC_Buyer_Name__c = 'Buyer ' + i,
                FEC_Premium_Fee__c = i * 1000
            ));
        }
        insert rows;

        insertCase(SUBJECT_BLANK_NID, null);
        insertCase(SUBJECT_NO_HISTORY, NATIONAL_ID);
    }

    private static Case insertCase(String subject, String nationalId) {
        Case c = new Case(
            Subject = subject,
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_National_ID_Passport_ID__c = nationalId
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    private static Case caseBySubject(String subject) {
        return [
            SELECT Id, FEC_National_ID_Passport_ID__c
            FROM Case
            WHERE Subject = :subject
            LIMIT 1
        ];
    }

    private static FEC_SearchByListNIDsServiceCallout.NIDsResponse buildSuccessResponse() {
        FEC_SearchByListNIDsServiceCallout.NIDsResponse response =
            new FEC_SearchByListNIDsServiceCallout.NIDsResponse();
        response.pxObjClass = 'Data-Portal-NIDResponse';
        response.sys = new FEC_SearchByListNIDsServiceCallout.Sys();
        response.sys.code = 200;
        response.sys.description = 'Success';

        response.result = new List<FEC_SearchByListNIDsServiceCallout.Result>{
            buildPolicy(
                USER_EXISTING,
                'Updated Buyer',
                '1990-06-15',
                '2035-12-31',
                null,
                '2500000'
            ),
            buildPolicy(
                USER_NEW,
                'New Buyer',
                '15/03/1988',
                '2030-06-30T12:00:00',
                null,
                '750000'
            ),
            buildPolicy(
                USER_CANCEL,
                'Cancelled Buyer',
                'bad-date',
                '2020-01-01',
                '2024-05-01',
                '500000'
            ),
            buildPolicy(
                USER_SLASH_DATE,
                'Slash Date Buyer',
                '01/12/1999',
                '01/01/2099',
                null,
                '100'
            )
        };
        return response;
    }

    private static FEC_SearchByListNIDsServiceCallout.Result buildPolicy(
        String userId,
        String buyerName,
        String buyerDob,
        String expireDate,
        String cancelDate,
        String premium
    ) {
        FEC_SearchByListNIDsServiceCallout.Result item =
            new FEC_SearchByListNIDsServiceCallout.Result();
        item.userID = userId;
        item.buyerName = buyerName;
        item.buyerDOB = buyerDob;
        item.buyerNID = NATIONAL_ID;
        item.productNameEn = 'Insurance Product';
        item.collectedPremiumFee = premium;
        item.buyerGender = 'M';
        item.insurerCompany = 'Test Insurer';
        item.policyNumber = 'POL_' + userId;
        item.buyerPhone = '0901234567';
        item.saleChannel = 'Branch';
        item.saleSubChannel = 'Sub';
        item.agentCode = 'AG01';
        item.agentName = 'Agent';
        item.paymentID = 'PAY_' + userId;
        item.effectiveDate = '2026-01-01';
        item.expireDate = expireDate;
        item.cancelDate = cancelDate;
        item.StatusDisplay = 'Active';
        return item;
    }

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(JSON.serialize(buildSuccessResponse()));
            return res;
        }
    }

    private class ApiErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"error":"server error"}');
            return res;
        }
    }

    private class EmptyResultMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            FEC_SearchByListNIDsServiceCallout.NIDsResponse body =
                new FEC_SearchByListNIDsServiceCallout.NIDsResponse();
            body.sys = new FEC_SearchByListNIDsServiceCallout.Sys();
            body.sys.code = 200;
            body.result = new List<FEC_SearchByListNIDsServiceCallout.Result>();

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(JSON.serialize(body));
            return res;
        }
    }

    @IsTest
    static void testSyncInsuranceData_BlankNid() {
        Case c = caseBySubject(SUBJECT_BLANK_NID);

        Test.startTest();
        FEC_InsuranceInfoController.SyncResult result =
            FEC_InsuranceInfoController.syncInsuranceData(c.Id);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(0, result.count);
    }

    @IsTest
    static void testSyncInsuranceData_ApiError() {
        Case c = caseBySubject(SUBJECT_SYNC);
        Test.setMock(HttpCalloutMock.class, new ApiErrorMock());

        Test.startTest();
        FEC_InsuranceInfoController.SyncResult result =
            FEC_InsuranceInfoController.syncInsuranceData(c.Id);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(0, result.count);
    }

    @IsTest
    static void testSyncInsuranceData_EmptyResult() {
        Case c = caseBySubject(SUBJECT_SYNC);
        Test.setMock(HttpCalloutMock.class, new EmptyResultMock());

        Test.startTest();
        FEC_InsuranceInfoController.SyncResult result =
            FEC_InsuranceInfoController.syncInsuranceData(c.Id);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(0, result.count);
    }

    @IsTest
    static void testSyncInsuranceData_Success() {
        Case c = caseBySubject(SUBJECT_SYNC);
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_InsuranceInfoController.SyncResult result =
            FEC_InsuranceInfoController.syncInsuranceData(c.Id);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(4, result.count);

        FEC_Customer_History__c history = [
            SELECT FEC_Insurance_Flag__c
            FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :c.Id
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        System.assertEquals('Yes', history.FEC_Insurance_Flag__c);

        FEC_Insurance_Info__c existing = [
            SELECT FEC_Buyer_Name__c, FEC_Premium_Fee__c, FEC_Status__c
            FROM FEC_Insurance_Info__c
            WHERE FEC_User_ID__c = :USER_EXISTING
            LIMIT 1
        ];
        System.assertEquals('Updated Buyer', existing.FEC_Buyer_Name__c);
        System.assertEquals(2500000, existing.FEC_Premium_Fee__c);
        System.assertEquals('Còn hiệu lực', existing.FEC_Status__c);

        FEC_Insurance_Info__c cancelled = [
            SELECT FEC_Status__c
            FROM FEC_Insurance_Info__c
            WHERE FEC_User_ID__c = :USER_CANCEL
            LIMIT 1
        ];
        System.assertEquals('Hết hiệu lực', cancelled.FEC_Status__c);
    }

    @IsTest
    static void testSyncInsuranceData_CreatesCustomerHistory() {
        Case c = caseBySubject(SUBJECT_NO_HISTORY);
        Test.setMock(HttpCalloutMock.class, new EmptyResultMock());

        System.assertEquals(
            0,
            [SELECT COUNT() FROM FEC_Customer_History__c WHERE FEC_Case__c = :c.Id]
        );

        Test.startTest();
        FEC_InsuranceInfoController.syncInsuranceData(c.Id);
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_Customer_History__c WHERE FEC_Case__c = :c.Id]
        );
    }

    @IsTest
    static void testFetchInsuranceInfos_NoHistory() {
        Case c = caseBySubject(SUBJECT_NO_HISTORY);

        FEC_InsuranceInfoController.PagedResult result =
            FEC_InsuranceInfoController.fetchInsuranceInfos(
                c.Id, 1, 10, 'FEC_User_ID__c', 'ASC'
            );

        System.assertEquals(0, result.totalCount);
        System.assertEquals(0, result.records.size());
    }

    @IsTest
    static void testFetchInsuranceInfos_PagingAndSort() {
        Case c = caseBySubject(SUBJECT_FETCH);

        FEC_InsuranceInfoController.PagedResult ascPage =
            FEC_InsuranceInfoController.fetchInsuranceInfos(
                c.Id, 1, 2, 'FEC_Premium_Fee__c', 'ASC'
            );
        System.assertEquals(3, ascPage.totalCount);
        System.assertEquals(2, ascPage.records.size());

        FEC_InsuranceInfoController.PagedResult descPage =
            FEC_InsuranceInfoController.fetchInsuranceInfos(
                c.Id, 2, 2, 'FEC_Premium_Fee__c', 'desc'
            );
        System.assertEquals(3, descPage.totalCount);
        System.assertEquals(1, descPage.records.size());

        FEC_InsuranceInfoController.PagedResult invalidSort =
            FEC_InsuranceInfoController.fetchInsuranceInfos(
                c.Id, 1, 10, 'NotARealField__c', 'ASC'
            );
        System.assertEquals(3, invalidSort.totalCount);
        System.assertEquals(3, invalidSort.records.size());
    }

    @IsTest
    static void testLogSensitiveAccess() {
        Case c = caseBySubject(SUBJECT_FETCH);

        Test.startTest();
        FEC_InsuranceInfoController.logSensitiveAccess(
            c.Id,
            'Insurance',
            'FEC_Buyer_Name__c'
        );
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_Sensitive_Data__c WHERE FEC_Related_Case__c = :c.Id]
        );
    }
}
