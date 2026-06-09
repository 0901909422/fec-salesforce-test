@IsTest
private class FEC_SearchController_Test {

    private static final String VALID_ACCOUNT_NUMBER = '1234567890123456';
    private static final String VALID_CONTRACT_NUMBER = '12345678-123456-1234';

    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        if (String.isBlank(apiSetting.FEC_Endpoint__c)) {
            apiSetting.FEC_Endpoint__c = 'https://mock-api.fecredit.com.vn';
            apiSetting.FEC_Call_Mock__c = false;
            upsert apiSetting;
        }

        // 1. Tạo Product Type
        FEC_Product_Type__c productType = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = FEC_ConstantCommon.CASE_INTERNAL_REQUEST // Phục vụ createInternalCaseOnSkip
        );
        insert productType;

        // 2. Tạo Case RecordTypes (nếu Org không có, hãy xử lý fallback)
        RecordType rtSearch = [SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = :FEC_ConstantCommon.CASE_SEARCH_RECORD_TYPE_DEV_NAME LIMIT 1];
        
        Case testCase = new Case(
            Subject = 'Test Search Case',
            Status = 'New',
            RecordTypeId = rtSearch.Id,
            FEC_National_ID_Passport_ID__c = '123456789',
            FEC_ID_Search__c = 'SRC-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert testCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Case__c = testCase.Id,
            FEC_Customer_Name__c = 'Test Customer',
            FEC_Primary_Phone__c = '0901234567'
        );
        insert ch;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = testCase.Id,
                FEC_Account_or_Contract__c = ch.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    // =====================================================================
    // MOCK CLASSES
    // =====================================================================
    private class CardBasicInfoMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetCardBasicInfoResponse>' +
                '<Sys><Code>1</Code><Description>Success</Description></Sys>' +
                '<CardBasicInfo><MainCard><Status>Active</Status></MainCard></CardBasicInfo>' +
                '</GetCardBasicInfoResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class LoanAppHistoryMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{' +
                '  "Sys": {"TransID": "TXN123", "DateTime": "2026-05-25T10:00:00Z", "Code": 1, "Description": "Success"},' +
                '  "AppInfos": [{' +
                '    "APPLICATION_ID": "APP123", "USER_ID": "USR01", "USER_NAME": "Test User",' +
                '    "ACTIVITIY_ID": "ACT01", "ACTIVITIY_NAME": "Review", "STATUS_ID": "Open",' +
                '    "EDIT_DATE": "2026-05-25", "END_DATE": "2026-05-26", "CREATED_DATE": "2026-05-24"' +
                '  }]' +
                '}'
            );
            return res;
        }
    }

    private class MultiSearchCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String body = req.getBody() != null ? req.getBody() : '';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (body.contains('GetCustomerList')) {
                res.setHeader('Content-Type', 'text/xml');
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><cif:GetCustomerListResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
                    '<Sys><Code>1</Code></Sys><Customers><Customer><Applications>' +
                    '<Application><ApplicationID>APP123</ApplicationID></Application>' +
                    '</Applications></Customer></Customers></cif:GetCustomerListResponse>' +
                    '</soapenv:Body></soapenv:Envelope>'
                );
            } else {
                res.setHeader('Content-Type', 'text/xml');
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCardBasicInfoResponse>' +
                    '<Sys><Code>1</Code></Sys></GetCardBasicInfoResponse>' +
                    '</soapenv:Body></soapenv:Envelope>'
                );
            }
            return res;
        }
    }

    // =====================================================================
    // TEST METHODS
    // =====================================================================

    @IsTest
    static void testGetCaseAndFlags() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Id missingCaseId = Id.valueOf('500000000000001AAA');

        Test.startTest();
        System.assertEquals(null, FEC_SearchController.getCase(null));
        System.assertEquals(null, FEC_SearchController.getCaseSearchFlags(null));
        System.assertEquals(null, FEC_SearchController.getCase(missingCaseId));
        System.assertEquals(null, FEC_SearchController.getCaseSearchFlags(missingCaseId));

        Case resultCase = FEC_SearchController.getCase(c.Id);
        Case resultFlags = FEC_SearchController.getCaseSearchFlags(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, resultCase);
        System.assertEquals(c.Id, resultCase.Id);
        System.assertNotEquals(null, resultFlags);
    }

    @IsTest
    static void testCreateHistory_WithExistingCase() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MultiSearchCalloutMock());

        Test.startTest();
        // Nhánh fieldName = 'AccountNumber'
        Id caseId1 = FEC_SearchController.createHistory(
            VALID_ACCOUNT_NUMBER, 'AccountNumber', c.Id, 'Card', 'Credit Card', 
            'CIF123', '0901234567', 'Nguyen Van A', 'APP123', false, 'POL123', '0123456789', '9876543210'
        );
        
        // Nhánh fieldName = 'UserId' (Không truyền caseId, là ListView)
        Id caseId2 = FEC_SearchController.createHistory(
            VALID_CONTRACT_NUMBER, 'UserId', null, 'Loan', 'Credit Card',
            'CIF123', '0901234567', 'Nguyen Van B', 'APP456', true, VALID_CONTRACT_NUMBER, '0123456789', null
        );
        Test.stopTest();

        System.assertEquals(c.Id, caseId1, 'Phải cập nhật Case hiện tại.');
        System.assertNotEquals(null, caseId2, 'Phải tạo Case mới khi isListView = true.');
        
        // Kiểm tra dữ liệu tạo ra
        List<FEC_Customer_History__c> histories = [
            SELECT Id, FEC_Account_Number__c, FEC_Search_Result_National_ID__c
            FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :caseId1 OR FEC_Case__c = :caseId2
        ];
        System.assert(histories.size() >= 2);
    }

    @IsTest
    static void testCreateHistory_ContractNumberInsuranceAndNewCase() {
        Test.setMock(HttpCalloutMock.class, new MultiSearchCalloutMock());

        Test.startTest();
        Id insuranceCaseId = FEC_SearchController.createHistory(
            VALID_CONTRACT_NUMBER,
            'ContractNumber',
            null,
            FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE,
            'Credit Card',
            'CIF-INS',
            '0901111222',
            'Insurance Customer',
            'APP-INS',
            false,
            'POL-INS',
            '111222333',
            '444555666'
        );

        Id userOnCaseId = FEC_SearchController.createHistory(
            VALID_CONTRACT_NUMBER,
            'UserId',
            [SELECT Id FROM Case LIMIT 1].Id,
            'Loan',
            'Credit Card',
            null,
            '0903333444',
            'User On Case',
            null,
            false,
            'POL-X',
            '777888999',
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, insuranceCaseId);
        System.assertNotEquals(null, userOnCaseId);
        Case insuranceCase = [
            SELECT FEC_Contract_Number__c, FEC_Search_National_ID__c
            FROM Case
            WHERE Id = :insuranceCaseId
        ];
        System.assertEquals(VALID_CONTRACT_NUMBER, insuranceCase.FEC_Contract_Number__c);
        System.assert(insuranceCase.FEC_Search_National_ID__c.contains('111222333'));
    }

    @IsTest
    static void testCreateHistory_ValidationFail() {
        Test.startTest();
        try {
            FEC_SearchController.createHistory('', '', null, '', '', '', '', '', '', false, '', '', '');
            System.assert(false, 'Phải ném Exception khi fieldName rỗng.');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetApplicationHistory() {
        Test.setMock(HttpCalloutMock.class, new LoanAppHistoryMock());

        Boolean blankThrown = false;
        Test.startTest();
        try {
            FEC_SearchController.getApplicationHistory('');
        } catch (AuraHandledException e) {
            blankThrown = true;
        }

        List<Map<String, String>> historyList = FEC_SearchController.getApplicationHistory('APP123');
        Test.stopTest();

        System.assertEquals(true, blankThrown);
        System.assertNotEquals(null, historyList);
        System.assertEquals(1, historyList.size());
        System.assertEquals('Test User', historyList[0].get('user'));
    }

    @IsTest
    static void testRevealNationalId() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_SearchController.revealNationalId(c.Id, 'NID Field');
        FEC_SearchController.revealNationalId(c.Id, '');
        Test.stopTest();

        System.assert(true, 'Audit log completed without exception.');
    }

    @IsTest
    static void testGetCardInfoByAccountNumber() {
        Test.setMock(HttpCalloutMock.class, new CardBasicInfoMock());

        Boolean blankThrown = false;
        Test.startTest();
        try {
            FEC_SearchController.getCardInfoByAccountNumber('');
        } catch (AuraHandledException e) {
            blankThrown = true;
        }

        FEC_GetCardBasicInfo.ResponseWrapper res =
            FEC_SearchController.getCardInfoByAccountNumber(VALID_ACCOUNT_NUMBER);
        Test.stopTest();

        System.assertEquals(true, blankThrown);
        System.assertNotEquals(null, res);
    }

    @IsTest
    static void testCreateInternalCaseOnSkip() {
        Test.startTest();
        Id internalCaseId = FEC_SearchController.createInternalCaseOnSkip();
        Test.stopTest();

        Case internalCase = [SELECT FEC_Skip_Search_Internal_Case__c, FEC_Account_Contract_Number_PL__c FROM Case WHERE Id = :internalCaseId];
        System.assertEquals(true, internalCase.FEC_Skip_Search_Internal_Case__c);
        System.assertEquals(FEC_ConstantCommon.CASE_INTERNAL_REQUEST, internalCase.FEC_Account_Contract_Number_PL__c);
    }

    @IsTest
    static void testGetHistoryStatus() {
        FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c emptyHist = new FEC_Customer_History__c(FEC_Case__c = c.Id);
        insert emptyHist;

        Test.startTest();
        Map<String, Object> statusMap = FEC_SearchController.getHistoryStatus(ch.Id);
        Map<String, Object> notReadyMap = FEC_SearchController.getHistoryStatus(emptyHist.Id);
        Test.stopTest();

        System.assertEquals(true, statusMap.get('isReady'));
        System.assertEquals('Test Customer', statusMap.get('customerName'));
        System.assertEquals(false, notReadyMap.get('isReady'));
    }

    @IsTest
    static void testCheckFieldEditPermissions() {
        Test.startTest();
        Map<String, Boolean> perms = FEC_SearchController.checkFieldEditPermissions('Case', new List<String>{'Subject', 'InvalidField__c'});
        Map<String, Boolean> invalidObjectPerms =
            FEC_SearchController.checkFieldEditPermissions('NotARealObject__c', new List<String>{'Name'});
        Test.stopTest();

        System.assertEquals(true, perms.containsKey('Subject'));
        System.assertEquals(false, perms.get('InvalidField__c'), 'Trường không tồn tại phải trả về false.');
        System.assertEquals(true, invalidObjectPerms.isEmpty());
    }

    @IsTest
    static void testOtherGetters() {
        Test.startTest();
        // Lấy Profile
        String profileName = FEC_SearchController.getCurrentUserProfileName();
        System.assertNotEquals(null, profileName);

        // Code này test Custom Metadata (sẽ lấy từ Org nếu có, không lỗi null pointer)
        String mockAccNumber = FEC_SearchController.getTestServiceErrorAccountNumber();
        
        // Helper SOQL
        List<FEC_B2_Contract__c> b2 = FEC_SearchController.getB2Contracts('CNT123');
        List<FEC_Cash_24_Contract__c> cash = FEC_SearchController.getCash24Contracts('CNT123');
        Case createdCase = FEC_SearchController.createCustomerCase('Name', '123');
        Test.stopTest();

        System.assert(b2.isEmpty());
        System.assert(cash.isEmpty());
        System.assertNotEquals(null, createdCase.Id);
    }
}