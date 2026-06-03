/**
 * Unit tests for FEC_BancaController (Banca / insurance load and detail).
 */
@IsTest
private class FEC_BancaController_Test {

    private static final String SUBJECT_CASE     = 'FEC_BancaController_Test Case';
    private static final String SUBJECT_PHONE    = 'FEC_BancaController_Test Phone Case';
    private static final String SUBJECT_EMPTY    = 'FEC_BancaController_Test Empty Case';
    private static final String NATIONAL_ID      = '123456789';
    private static final String PRIMARY_PHONE    = '0987654321';
    private static final String USER_EXISTING    = 'USER_EXISTING';
    private static final String USER_NID         = 'USR_NID_01';
    private static final String USER_PHONE       = 'USR_PHONE_01';

    /** Mirrors FEC_BancaController.BancaDTO for assertions without inner-type reference. */
    private class BancaDtoMirror {
        public Id Id;
        public Id caseId;
        public String userId;
        public String buyerName;
        public String premiumFree;
        public String status;
        public String productName;
    }

    /**
     * Routes HTTP mock by endpoint path (SearchByListNIDs vs SearchByListPhones).
     */
    private class BancaInsuranceCalloutMock implements HttpCalloutMock {
        private Integer callCount = 0;

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(FEC_ConstantCommon.HTTP_STATUS_OK);
            res.setHeader('Content-Type', FEC_ConstantCommon.API_CONTENT_TYPE_JSON);

            String endpoint = req.getEndpoint() != null ? req.getEndpoint() : '';
            String body = req.getBody() != null ? req.getBody() : '';

            // Match Phones before NIDs; use request key "phone": not substring "phone" in buyerPhone.
            if (endpoint.contains('SearchByListPhones') || body.contains('"phone":')) {
                res.setBody(JSON.serialize(buildPhoneResponse()));
            } else if (endpoint.contains('SearchByListNIDs') || body.contains('"nationalID":')) {
                res.setBody(JSON.serialize(buildNidResponse()));
            } else if (callCount == 1) {
                res.setBody(JSON.serialize(buildNidResponse()));
            } else {
                res.setBody(JSON.serialize(buildPhoneResponse()));
            }
            return res;
        }
    }

    private class BancaInsuranceCalloutErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    private static Case insertCaseWithCustomerHistory(
        String subject,
        String nationalId,
        String primaryPhone
    ) {
        Case c = new Case(
            Subject = subject,
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN
        );
        insert c;

        FEC_Customer_History__c history = new FEC_Customer_History__c(
            Name = 'FEC_BancaController_Test ' + subject,
            FEC_Case__c = c.Id,
            FEC_National_ID_Passport_ID__c = nationalId,
            FEC_Primary_Phone__c = primaryPhone
        );
        insert history;

        c.FEC_Account_or_Contract__c = history.Id;
        update c;
        return c;
    }

    @TestSetup
    static void setupData() {
        Case c = insertCaseWithCustomerHistory(SUBJECT_CASE, NATIONAL_ID, PRIMARY_PHONE);

        insert new FEC_Insurance_Info__c(
            FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
            FEC_User_ID__c = USER_EXISTING,
            FEC_Buyer_Name__c = 'Nguyen Van A',
            FEC_Premium_Fee__c = 500000,
            FEC_Status__c = 'Active'
        );
    }

    private static Case testCase() {
        return [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            WHERE Subject = :SUBJECT_CASE
            LIMIT 1
        ];
    }

    private static Map<String, FEC_Insurance_Info__c> insuranceByUserId(Id customerHistoryId) {
        Map<String, FEC_Insurance_Info__c> byUser = new Map<String, FEC_Insurance_Info__c>();
        for (FEC_Insurance_Info__c row : [
            SELECT FEC_User_ID__c
            FROM FEC_Insurance_Info__c
            WHERE FEC_Customer_History__c = :customerHistoryId
        ]) {
            if (String.isNotBlank(row.FEC_User_ID__c)) {
                byUser.put(row.FEC_User_ID__c, row);
            }
        }
        return byUser;
    }

    private static FEC_SearchByListNIDsServiceCallout.NIDsResponse buildNidResponse() {
        FEC_SearchByListNIDsServiceCallout.NIDsResponse response =
            new FEC_SearchByListNIDsServiceCallout.NIDsResponse();
        response.result = new List<FEC_SearchByListNIDsServiceCallout.Result>{
            (FEC_SearchByListNIDsServiceCallout.Result) JSON.deserialize(
                '{' +
                    '"userID":"' + USER_NID + '",' +
                    '"buyerName":"Buyer NID",' +
                    '"buyerDOB":"1995-01-01",' +
                    '"buyerNID":"' + NATIONAL_ID + '",' +
                    '"productNameEn":"Banca Product NID",' +
                    '"collectedPremiumFee":"1500000",' +
                    '"StatusDisplay":"In Force",' +
                    '"buyerGender":"M",' +
                    '"saleChannel":"Telesales",' +
                    '"insurerCompany":"Company A",' +
                    '"saleSubChannel":"Sub 01",' +
                    '"policyNumber":"POL_NID_999",' +
                    '"agentCode":"AG_01",' +
                    '"buyerPhone":"' + PRIMARY_PHONE + '",' +
                    '"agentName":"Agent NID",' +
                    '"expireDate":"2030-01-01",' +
                    '"paymentID":"PAY_NID_01",' +
                    '"effectiveDate":"2026-01-01"' +
                '}',
                FEC_SearchByListNIDsServiceCallout.Result.class
            )
        };
        return response;
    }

    private static FEC_SearchByListPhonesServiceCallout.PhonesResponse buildPhoneResponse() {
        FEC_SearchByListPhonesServiceCallout.Result item =
            new FEC_SearchByListPhonesServiceCallout.Result();
        item.userID = USER_PHONE;
        item.buyerName = 'Buyer Phone';
        item.buyerDOB = '1992-05-05';
        item.buyerNID = NATIONAL_ID;
        item.productNameEn = 'Banca Product Phone';
        item.collectedPremiumFee = 2000000.0;
        item.statusDisplay = 'In Force';
        item.buyerGender = 'F';
        item.saleChannel = 'Digital';
        item.insurerCompany = 'Company B';
        item.saleSubChannel = 'Sub 02';
        item.policyNumber = 'POL_PHONE_888';
        item.agentCode = 'AG_02';
        item.buyerPhone = PRIMARY_PHONE;
        item.agentName = 'Agent Phone';
        item.expireDate = '2029-12-31';
        item.paymentID = 'PAY_PHONE_01';
        item.effectiveDate = '2026-02-02';

        FEC_SearchByListPhonesServiceCallout.PhonesResponse response =
            new FEC_SearchByListPhonesServiceCallout.PhonesResponse();
        response.result = new List<FEC_SearchByListPhonesServiceCallout.Result>{ item };
        return response;
    }

    private static List<BancaDtoMirror> loadInsuranceList(Id caseId) {
        return (List<BancaDtoMirror>) JSON.deserialize(
            JSON.serialize(FEC_BancaController.loadataInsurance(caseId)),
            List<BancaDtoMirror>.class
        );
    }

    private static BancaDtoMirror loadInsuranceDetailMirror(Id insuranceId) {
        return (BancaDtoMirror) JSON.deserialize(
            JSON.serialize(FEC_BancaController.loadInsuranceDetail(insuranceId)),
            BancaDtoMirror.class
        );
    }

    private static Set<String> userIdsFromResults(List<BancaDtoMirror> results) {
        Set<String> ids = new Set<String>();
        for (BancaDtoMirror row : results) {
            if (row != null && String.isNotBlank(row.userId)) {
                ids.add(row.userId);
            }
        }
        return ids;
    }

    @IsTest
    static void loadataInsurance_nullCaseId_throwsAuraHandled() {
        Boolean thrown = false;

        Test.startTest();
        try {
            FEC_BancaController.loadataInsurance(null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Null Case Id must throw AuraHandledException.');
    }

    @IsTest
    static void loadataInsurance_withCallouts_persistsAndReturnsRows() {
        Case cs = testCase();
        System.assertNotEquals(null, cs.FEC_Account_or_Contract__c, 'Case must link to Customer History.');

        Test.setMock(HttpCalloutMock.class, new BancaInsuranceCalloutMock());

        Test.startTest();
        List<BancaDtoMirror> results = loadInsuranceList(cs.Id);
        Test.stopTest();

        Map<String, FEC_Insurance_Info__c> byUser = insuranceByUserId(cs.FEC_Account_or_Contract__c);

        System.assertNotEquals(null, results);
        System.assert(byUser.size() >= 2, 'Expected at least seed and NID rows.');
        System.assertEquals(results.size(), byUser.size(), 'Returned DTO count must match DB rows.');

        Set<String> userIds = userIdsFromResults(results);
        System.assert(userIds.contains(USER_EXISTING), 'Seed insurance must remain in results.');
        System.assert(userIds.contains(USER_NID), 'NID callout row must be persisted.');
        System.assert(byUser.containsKey(USER_EXISTING));
        System.assert(byUser.containsKey(USER_NID));
        // Phone callout is covered in loadataInsurance_phoneCallout_persistsRow.
    }

    @IsTest
    static void loadataInsurance_phoneCallout_persistsRow() {
        Case cs = insertCaseWithCustomerHistory(SUBJECT_PHONE, null, PRIMARY_PHONE);
        Test.setMock(HttpCalloutMock.class, new BancaInsuranceCalloutMock());

        Test.startTest();
        List<BancaDtoMirror> results = loadInsuranceList(cs.Id);
        Test.stopTest();

        Map<String, FEC_Insurance_Info__c> byUser =
            insuranceByUserId(cs.FEC_Account_or_Contract__c);

        System.assertNotEquals(null, results);
        System.assertEquals(1, byUser.size(), 'Phone-only case must persist one callout row.');
        System.assert(userIdsFromResults(results).contains(USER_PHONE), 'Phone callout row must be persisted.');
        System.assert(byUser.containsKey(USER_PHONE));
        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_Insurance_Info__c WHERE FEC_User_ID__c = :USER_PHONE],
            'Phone user must be stored once.'
        );
    }

    @IsTest
    static void loadataInsurance_noSearchKeys_returnsExistingRowsOnly() {
        Case emptyCase = insertCaseWithCustomerHistory(SUBJECT_EMPTY, null, null);

        Test.startTest();
        List<BancaDtoMirror> results = loadInsuranceList(emptyCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertEquals(0, results.size(), 'No NID/phone must skip callouts and return no insurance rows.');
    }

    @IsTest
    static void loadataInsurance_calloutFailure_doesNotCrash() {
        Test.setMock(HttpCalloutMock.class, new BancaInsuranceCalloutErrorMock());

        Test.startTest();
        List<BancaDtoMirror> results = loadInsuranceList(testCase().Id);
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assert(
            userIdsFromResults(results).contains(USER_EXISTING),
            'Callout errors are caught; existing DB rows must still be returned.'
        );
    }

    @IsTest
    static void loadInsuranceDetail_success() {
        FEC_Insurance_Info__c insurance = [
            SELECT Id
            FROM FEC_Insurance_Info__c
            WHERE FEC_User_ID__c = :USER_EXISTING
            LIMIT 1
        ];

        Test.startTest();
        BancaDtoMirror detail = loadInsuranceDetailMirror(insurance.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail);
        System.assertEquals(USER_EXISTING, detail.userId);
        System.assert(
            detail.premiumFree != null && detail.premiumFree.contains('500000'),
            'Premium fee must be serialized as a string containing 500000.'
        );
        System.assertEquals('Active', detail.status);
    }

    @IsTest
    static void loadInsuranceDetail_nullId_returnsNull() {
        Test.startTest();
        BancaDtoMirror detail = loadInsuranceDetailMirror(null);
        Test.stopTest();

        System.assertEquals(null, detail, 'Null insurance Id must return null.');
    }
}