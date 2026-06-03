@IsTest
private class FEC_DNBHandler_Test {

    private static final String MOCK_JSON_SUCCESS =
        '{' +
        '  "sys": {"code": "0", "message": "Success", "trans_id": "TXN-DNB"},' +
        '  "result": [' +
        '    {"nid": "123456789", "do_not_bother": true, "type": "PHONE", "type_value": "84901234567", "source": "Call", "reason": "Customer requested", "expected_exclude_time": "2026-12-31"},' +
        '    {"nid": "123456789", "do_not_bother": false, "type": "EMAIL", "type_value": "test@fecredit.com.vn", "source": "Email", "reason": "Other"}' +
        '  ]' +
        '}';

    private static final String MOCK_JSON_FAIL =
        '{' +
        '  "sys": {"code": "1", "message": "Invalid", "trans_id": "TXN-DNB"},' +
        '  "result": []' +
        '}';

    @TestSetup
    static void setupData() {
        insert new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://mock-api.fecredit.com.vn',
            FEC_Call_Mock__c = false
        );

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'DNB Test',
                Status = 'New',
                FEC_Phone_Number__c = '0901234567',
                FEC_Case_Phone_Number__c = '0901234567',
                FEC_Case_Email__c = 'test@fecredit.com.vn',
                FEC_National_ID_Passport_ID__c = '123456789',
                FEC_ID_Search__c = 'DNB-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_National_ID_Passport_ID__c = '123456789',
            FEC_Search_Result_National_ID__c = '123456789'
        );
        insert hist;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = hist.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private class DnbHttpMock implements HttpCalloutMock {
        Integer statusCode;
        String body;
        DnbHttpMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    private class PsDnbHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"sys":{"code":0,"message":"Success"},"result":[]}');
            return res;
        }
    }

    @IsTest
    static void testGetCaseData() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        FEC_DNBHandler.CaseInfoResponse res = FEC_DNBHandler.getCaseData(c.Id);
        Test.stopTest();
        System.assertEquals('0901234567', res.primaryPhoneNumber);
    }

    @IsTest
    static void testGetCaseNonExistingData() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        FEC_DNBHandler.CaseInfoNonExistingResponse res = FEC_DNBHandler.getCaseNonExistingData(c.Id);
        Test.stopTest();
        System.assertEquals('123456789', res.nationalId);
        System.assertEquals('0901234567', res.phoneNumber);
    }

    @IsTest
    static void testCheckDNB() {
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'DNB Cat',
            FEC_Code__c = 'DNBCAT',
            FEC_Active__c = true
        );
        insert cat;
        insert new FEC_Nature_of_Case__c(
            FEC_Category__c = cat.Id,
            FEC_Do_Not_Bother__c = true,
            FEC_Active__c = true
        );

        Test.startTest();
        System.assertEquals(true, FEC_DNBHandler.checkDNB(cat.Id, null, null));
        System.assertEquals(false, FEC_DNBHandler.checkDNB(null, null, null));
        Test.stopTest();
    }

    @IsTest
    static void testGetListDNBs() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c hist = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
        insert new FEC_Do_Not_Bother__c(
            FEC_Case__c = c.Id,
            FEC_Customer_History__c = hist.Id,
            FEC_Current_Status__c = 'Active',
            FEC_Action__c = true
        );

        Test.startTest();
        List<FEC_DNBHandler.DNBResponseItem> listDnb = FEC_DNBHandler.getListDNBs(c.Id);
        Test.stopTest();

        System.assertEquals(1, listDnb.size());
        System.assertEquals('Active', listDnb[0].doNotBother);
    }

    @IsTest
    static void testGetDNBResultTable() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        insert new FEC_Do_Not_Bother__c(
            FEC_Case__c = c.Id,
            FEC_Action__c = true,
            FEC_DNB_Channel__c = 'Call',
            FEC_Type__c = 'Primary Phone',
            FEC_Phone_Email__c = '0901234567'
        );

        Test.startTest();
        List<FEC_DNBHandler.DNBResultWrapper> rows = FEC_DNBHandler.getDNBResultTable(c.Id);
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals(true, rows[0].action);
    }

    @IsTest
    static void testCheckDNBExisting() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_JSON_SUCCESS));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res = FEC_DNBHandler.checkDNBExisting(c.Id);
        Test.stopTest();

        System.assertEquals(true, res.success);
    }

    @IsTest
    static void testCheckDNBNonExisting() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_JSON_SUCCESS));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_DNBHandler.checkDNBNonExisting(c.Id, '123456789');
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals(
            '123456789',
            [SELECT FEC_National_ID_Passport_ID__c FROM Case WHERE Id = :c.Id].FEC_National_ID_Passport_ID__c
        );
    }

    @IsTest
    static void testGetDNBResultForHandling_InsertsRows() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_JSON_SUCCESS));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_DNBHandler.getDNBResultForHandling(c.Id);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assert(
            [SELECT COUNT() FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = :c.Id] > 0,
            'Phải insert DNB rows khi API thành công.'
        );
    }

    @IsTest
    static void testGetDNBResultForHandlingNonExisting() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_JSON_SUCCESS));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_DNBHandler.getDNBResultForHandlingNonExisting(c.Id, '123456789');
        Test.stopTest();

        System.assertEquals(true, res.success);
    }

    @IsTest
    static void testGetDNBResultForHandling_ApiFailure() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_JSON_FAIL));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_DNBHandler.getDNBResultForHandling(c.Id);
        Test.stopTest();

        System.assertEquals(false, res.success);
    }

    @IsTest
    static void testGetDNBResultC360_NoNationalId() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        update new FEC_Customer_History__c(
            Id = [SELECT FEC_Account_or_Contract__c FROM Case WHERE Id = :c.Id].FEC_Account_or_Contract__c,
            FEC_Search_Result_National_ID__c = null
        );

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res = FEC_DNBHandler.getDNBResultC360(c.Id);
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertEquals('No National ID found', res.errorMessage);
    }

    @IsTest
    static void testGetDNBResultC360_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_JSON_SUCCESS));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res = FEC_DNBHandler.getDNBResultC360(c.Id);
        Test.stopTest();

        System.assertEquals(true, res.success);
    }

    @IsTest
    static void testCreateDNB_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Do_Not_Bother__c dnb = new FEC_Do_Not_Bother__c(
            FEC_Case__c = c.Id,
            FEC_Current_Status__c = 'Inactive'
        );
        insert dnb;

        List<Object> payload = new List<Object>{
            new Map<String, Object>{
                'dnb_id' => dnb.Id,
                'reason' => 'not_interested',
                'remarks' => 'Updated'
            }
        };

        Test.setMock(HttpCalloutMock.class, new PsDnbHttpMock());
        Test.startTest();
        FEC_PsDNBServiceCallout.DNBResult res = FEC_DNBHandler.createDNB(payload);
        Test.stopTest();

        System.assertEquals('0', res.code);
        FEC_Do_Not_Bother__c updated = [
            SELECT FEC_Action__c, FEC_Updated_Reason__c
            FROM FEC_Do_Not_Bother__c
            WHERE Id = :dnb.Id
        ];
        System.assertEquals(true, updated.FEC_Action__c);
        System.assertEquals('Not interested', updated.FEC_Updated_Reason__c);
    }

    @IsTest
    static void testCreateDNB_EmptyPayloadThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            FEC_DNBHandler.createDNB(new List<Object>());
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testUpdateFieldDoNotBother() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        FEC_DNBHandler.updateFieldDoNotBother(c.Id, 'yes');
        Test.stopTest();
        System.assertEquals('Yes', [SELECT FEC_Is_DNB__c FROM Case WHERE Id = :c.Id].FEC_Is_DNB__c);
    }

    @IsTest
    static void testUpdateDNBProcessCount() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        Integer failCount = FEC_DNBHandler.updateDNBProcessCount(c.Id, false);
        Integer successCount = FEC_DNBHandler.updateDNBProcessCount(c.Id, true);
        Test.stopTest();
        System.assertEquals(1, failCount);
        System.assertEquals(0, successCount);
    }

    @IsTest
    static void testCreateExistingDNBRows() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_JSON_SUCCESS));

        Test.startTest();
        FEC_DNBHandler.createExistingDNBRows(c.Id);
        Test.stopTest();

        System.assert([SELECT COUNT() FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = :c.Id] > 0);
    }

    @IsTest
    static void testCreateNonExistingDNBRows() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_JSON_SUCCESS));

        Test.startTest();
        FEC_DNBHandler.createNonExistingDNBRows(c.Id, '123456789');
        Test.stopTest();

        System.assert([SELECT COUNT() FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = :c.Id] > 0);
    }

    @IsTest
    static void testCheckDNB_WithSubCategoryAndSubCode() {
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'DNB Cat2',
            FEC_Code__c = 'DNBCAT2',
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'DNB Sub',
            FEC_Code__c = 'DNBSUB',
            FEC_Active__c = true
        );
        insert subCat;
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'DNB SC',
            FEC_Code__c = 'DNBSC',
            FEC_Active__c = true
        );
        insert subCode;
        insert new FEC_Nature_of_Case__c(
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Do_Not_Bother__c = true,
            FEC_Active__c = true
        );

        Test.startTest();
        System.assertEquals(true, FEC_DNBHandler.checkDNB(cat.Id, subCat.Id, subCode.Id));
        System.assertEquals(false, FEC_DNBHandler.checkDNB(cat.Id, subCat.Id, null));
        Test.stopTest();
    }

    @IsTest
    static void testGetDNBResultForHandlingNonExisting() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_JSON_SUCCESS));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_DNBHandler.getDNBResultForHandlingNonExisting(c.Id, '123456789');
        Test.stopTest();

        System.assertEquals(true, res.success);
    }

    @IsTest
    static void testGetDNBResultForHandlingNonExisting_AlreadyExists() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        insert new FEC_Do_Not_Bother__c(FEC_Case__c = c.Id, FEC_Action__c = false);
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(200, MOCK_JSON_SUCCESS));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_DNBHandler.getDNBResultForHandlingNonExisting(c.Id, '123456789');
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals('DNB already exists', res.errorMessage);
    }

    @IsTest
    static void testCheckDNBExisting_ApiFailure() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(500, 'Server Error'));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res = FEC_DNBHandler.checkDNBExisting(c.Id);
        Test.stopTest();

        System.assertEquals(false, res.success);
    }

    @IsTest
    static void testUpdateFieldDoNotBother_No() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        FEC_DNBHandler.updateFieldDoNotBother(c.Id, 'no');
        Test.stopTest();
        System.assertEquals('No', [SELECT FEC_Is_DNB__c FROM Case WHERE Id = :c.Id].FEC_Is_DNB__c);
    }

    @IsTest
    static void testCreateDNB_FullPayload() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        List<Object> payload = new List<Object>{
            new Map<String, Object>{
                'reason' => 'not_interested',
                'full_name' => 'Test User',
                'nid' => '123456789',
                'do_not_bother' => true,
                'type' => 'PHONE',
                'type_value' => '84901234567',
                'contract_id' => 'CONTRACT1'
            }
        };

        Test.setMock(HttpCalloutMock.class, new PsDnbHttpMock());
        Test.startTest();
        FEC_PsDNBServiceCallout.DNBResult res = FEC_DNBHandler.createDNB(payload);
        Test.stopTest();

        System.assertEquals('0', res.code);
    }

    @IsTest
    static void testGetDNBResultC360_HttpError() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new DnbHttpMock(500, 'Error'));

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res = FEC_DNBHandler.getDNBResultC360(c.Id);
        Test.stopTest();

        System.assertEquals(false, res.success);
    }
}
