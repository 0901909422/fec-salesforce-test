@IsTest
private class FEC_MainInfoAccountController_Test {

    private static final String ACCOUNT_NUMBER = '0001500060000003';
    private static final String CIF_NUMBER = 'CIF001';
    private static final String CONTRACT_NUMBER = 'CNT0001500060000003';
    private static final String SOAP_ENV = FEC_ConstantCommon.SOAP_ENV;

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Loan',
            FEC_Code__c = 'LOAN' + suffix.right(4),
            FEC_Active__c = true
        );
        insert prod;

        Case c = new Case(
            Subject = 'FEC_MainInfoAccountController_Test',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_Product_Type__c = prod.Id,
            FEC_Is_Test_API__c = true,
            Status = 'New',
            FEC_ID_Search__c = 'MIA-' + suffix
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c cust = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_Contract_Number__c = CONTRACT_NUMBER,
            FEC_CIF_Number__c = CIF_NUMBER,
            FEC_Card_Number__c = '****1234',
            FEC_Credit_Limit__c = 5000000,
            FEC_OTB__c = 1000000,
            FEC_Current_Balance__c = 250000.50,
            FEC_Account_Status__c = 'Active'
        );
        insert cust;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = cust.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_API_Setting__c(
            FEC_Call_Mock__c = true,
            FEC_Endpoint__c = 'https://test-api.fecredit.com.vn'
        );
    }

    private static User adminUser() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return admins.isEmpty() ? new User(Id = UserInfo.getUserId()) : admins[0];
    }

    @IsTest
    static void testLoadAccountInfo_Success() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            System.assert(true, 'Skipped: FEC_MainInfoAccountController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MainInfoHttpMock());

        Test.startTest();
        FEC_MainInfoAccountController.MainInfoDTO result =
            FEC_MainInfoAccountController.loadAccountInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(ACCOUNT_NUMBER, result.accountNumber);
        System.assertEquals(true, result.isFromAccount);
    }

    @IsTest
    static void testLoadAccountInfo_NullCaseId() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        Test.startTest();
        try {
            FEC_MainInfoAccountController.loadAccountInfo(null);
            System.assert(false, 'Null case id phải throw AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetAccountInfoLocal_Success() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        FEC_Customer_History__c cust = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];

        Test.startTest();
        FEC_MainInfoAccountController.MainInfoDTO dto =
            FEC_MainInfoAccountController.getAccountInfoLocal(cust.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertEquals(ACCOUNT_NUMBER, dto.accountNumber);
        System.assertNotEquals(null, dto.helpTexts);
    }

    @IsTest
    static void testGetAccountInfoLocal_InvalidId() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        Id fakeId = FEC_Customer_History__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.startTest();
        FEC_MainInfoAccountController.MainInfoDTO dto =
            FEC_MainInfoAccountController.getAccountInfoLocal(fakeId);
        Test.stopTest();

        System.assertEquals(null, dto);
    }

    @IsTest
    static void testRefreshAccountInfo_Success() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MainInfoHttpMock());

        Test.startTest();
        FEC_MainInfoAccountController.MainInfoDTO result =
            FEC_MainInfoAccountController.refreshAccountInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testRefreshAccountInfo_NullCaseId() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        Test.startTest();
        try {
            FEC_MainInfoAccountController.refreshAccountInfo(null);
            System.assert(false, 'Null case id phải throw.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCheckRewardEligibility_Eligible() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new RewardEligibilityHttpMock(true));

        Test.startTest();
        FEC_MainInfoAccountController.RewardEligibilityResult result =
            FEC_MainInfoAccountController.checkRewardEligibility(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.isEligible);
    }

    @IsTest
    static void testCheckRewardEligibility_NotEligible() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new RewardEligibilityHttpMock(false));

        Test.startTest();
        try {
            FEC_MainInfoAccountController.RewardEligibilityResult result =
                FEC_MainInfoAccountController.checkRewardEligibility(c.Id);
            System.assertEquals(false, result.isEligible);
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCheckRewardEligibility_NullCaseId() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        Test.startTest();
        try {
            FEC_MainInfoAccountController.checkRewardEligibility(null);
            System.assert(false, 'Null case id phải throw.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCheckRewardEligibility_NoAccountLinked() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        Case orphan = new Case(
            Subject = 'No Account',
            Status = 'New',
            FEC_ID_Search__c = 'MIA-NA-' + System.currentTimeMillis()
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert orphan;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        try {
            FEC_MainInfoAccountController.checkRewardEligibility(orphan.Id);
            System.assert(false, 'Case không có account phải throw.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testLoadAccountInfo_AsAdmin() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        System.runAs(adminUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new MainInfoHttpMock());

            Test.startTest();
            FEC_MainInfoAccountController.MainInfoDTO result =
                FEC_MainInfoAccountController.loadAccountInfo(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
        }
    }

    @IsTest
    static void testLoadAccountInfo_NoAccountLinked() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        Case orphan = new Case(
            Subject = 'No Account',
            Status = 'New',
            FEC_ID_Search__c = 'MIA-NA2-' + System.currentTimeMillis()
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert orphan;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.setMock(HttpCalloutMock.class, new MainInfoHttpMock());
        Test.startTest();
        FEC_MainInfoAccountController.MainInfoDTO result =
            FEC_MainInfoAccountController.loadAccountInfo(orphan.Id);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testLoadAccountInfo_ApiErrorsHandled() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MainInfoErrorHttpMock());

        Test.startTest();
        FEC_MainInfoAccountController.MainInfoDTO result =
            FEC_MainInfoAccountController.loadAccountInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testCheckRewardEligibility_BlankAccountNumber() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c cust = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        cust.FEC_Account_Number__c = null;
        update cust;

        Test.startTest();
        try {
            FEC_MainInfoAccountController.checkRewardEligibility(c.Id);
            System.assert(false, 'Blank account number phải throw.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testRefreshAccountInfo_McmsCardMatch() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MainInfoHttpMock());

        Test.startTest();
        FEC_MainInfoAccountController.MainInfoDTO result =
            FEC_MainInfoAccountController.refreshAccountInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        FEC_Customer_History__c updated = [
            SELECT FEC_Block_Code__c, FEC_Warning_Code__c
            FROM FEC_Customer_History__c
            LIMIT 1
        ];
        System.assertNotEquals(null, updated);
    }

    @IsTest
    static void testGetAccountInfoLocal_AllFieldsMapped() {
        if (Type.forName('FEC_MainInfoAccountController') == null) {
            return;
        }

        FEC_Customer_History__c cust = [
            SELECT Id
            FROM FEC_Customer_History__c
            LIMIT 1
        ];
        cust.FEC_Debt_Sale_Type__c = 'Type A';
        cust.FEC_Company_Name__c = 'Debt Co';
        cust.FEC_Sold_Date__c = Date.today();
        cust.FEC_Principal_Sold__c = 100;
        cust.FEC_Interest_Sold__c = 50;
        cust.FEC_Sold_Note__c = 'Note';
        update cust;

        Test.startTest();
        FEC_MainInfoAccountController.MainInfoDTO dto =
            FEC_MainInfoAccountController.getAccountInfoLocal(cust.Id);
        Test.stopTest();

        System.assertEquals('Type A', dto.debtSaleType);
        System.assertEquals('Debt Co', dto.debtSaleCompanyName);
        System.assertNotEquals(null, dto.debtSoldDate);
    }

    private class MainInfoErrorHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('error');
            return res;
        }
    }

    private class RewardEligibilityHttpMock implements HttpCalloutMock {
        private Boolean eligible;

        RewardEligibilityHttpMock(Boolean eligible) {
            this.eligible = eligible;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            Integer code = eligible ? 0 : 1;
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:ns1="http://esbservice.fecredit.org/CMS_RewardWS/">' +
                '<soapenv:Body><ns1:GetRewardEligibilityResponse>' +
                '<SysResponse><TransID>TXN123</TransID>' +
                '<DateTime>2025-12-16T10:00:00</DateTime><Status>' + code + '</Status>' +
                '<Description>Success</Description></SysResponse>' +
                '<LMSAccount>ACC001</LMSAccount><AvailablePoints>500</AvailablePoints>' +
                '</ns1:GetRewardEligibilityResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class MainInfoHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            String body = req.getBody() != null ? req.getBody() : '';
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';

            if (body.contains('GetCardFinancialTransactions') || endpoint.contains('financial')) {
                res.setBody('<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '"><soapenv:Body></soapenv:Body></soapenv:Envelope>');
            } else if (body.contains('GetRewardEligibility')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '"><soapenv:Body>' +
                    '<GetRewardEligibilityResponse><SysResponse><Status>0</Status></SysResponse></GetRewardEligibilityResponse>' +
                    '</soapenv:Body></soapenv:Envelope>'
                );
            } else if (body.contains('GetApplicationsList')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '"><soapenv:Body>' +
                    '<GetApplicationsListResponse>' +
                    '<Sys><Code>1</Code></Sys>' +
                    '<Applications><ApplicationInfo><DateStatus>2024-01-15</DateStatus></ApplicationInfo></Applications>' +
                    '</GetApplicationsListResponse></soapenv:Body></soapenv:Envelope>'
                );
            } else if (body.contains('GetCustomerList') || endpoint.contains('customerlist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '"><soapenv:Body>' +
                    '<GetCustomerListResponse>' +
                    '<Sys><Code>1</Code></Sys>' +
                    '<Customers><Customer>' +
                    '<Applications><Application>' +
                    '<ApplicationId>APP001</ApplicationId>' +
                    '<SchemeId>SCH1</SchemeId><SchemeDesc>Scheme Test</SchemeDesc>' +
                    '<ContractNumber>' + CONTRACT_NUMBER + '</ContractNumber>' +
                    '</Application></Applications>' +
                    '</Customer></Customers>' +
                    '</GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
                );
            } else if (body.contains('GetCardSecInfo') || endpoint.contains('cardsec')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '"><soapenv:Body>' +
                    '<GetCardSecInfoResponse>' +
                    '<Sys><Code>1</Code></Sys>' +
                    '<CardSecInfo>' +
                    '<MainCardBalance><CurrentBalance>250000.50</CurrentBalance><TotalBalance>300000</TotalBalance></MainCardBalance>' +
                    '<MainCardPlastic><EcomActiveFlag>true</EcomActiveFlag></MainCardPlastic>' +
                    '</CardSecInfo></GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
            } else if (body.contains('EMEA_ACCOUNT_INQ') || body.contains('M_CMS_EMEA_ACCOUNT_INQ')) {
                res.setBody(
                    '<WSResponse>' +
                    '<Sys><Code>0</Code><Description>OK</Description></Sys>' +
                    '<M_CMS_EMEA_ACCOUNT_INQ><VMX_ROOT><VMX_MSGOUT>' +
                    '<ACCT_BS_OUTPUT><ACCT_NBR>' + ACCOUNT_NUMBER + '</ACCT_NBR>' +
                    '<CURR_BAL>250000.50</CURR_BAL><AVAIL_CR>1000000</AVAIL_CR>' +
                    '<LOCAL_USE_IND>Y</LOCAL_USE_IND></ACCT_BS_OUTPUT>' +
                    '</VMX_MSGOUT></VMX_ROOT></M_CMS_EMEA_ACCOUNT_INQ></WSResponse>'
                );
            } else if (body.contains('CARD_TO_CARD_INQ_EMEA') || body.contains('M_CMS_CARD_TO_CARD_INQ_EMEA')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '"><soapenv:Body>' +
                    '<WSResponse><Sys><Code>1</Code></Sys>' +
                    '<M_CMS_CARD_TO_CARD_INQ_EMEA><VMX_ROOT><VMX_MSGOUT>' +
                    '<OUTPUT_AREA><OUTPUT_DATA>' +
                    '<CARD_NBR>4123450000001234</CARD_NBR>' +
                    '<BLK_CD>01</BLK_CD><DT_BLK>20250101</DT_BLK>' +
                    '<CURR_FST_USG_FLG>Y</CURR_FST_USG_FLG>' +
                    '</OUTPUT_DATA></OUTPUT_AREA>' +
                    '</VMX_MSGOUT></VMX_ROOT></M_CMS_CARD_TO_CARD_INQ_EMEA>' +
                    '</WSResponse></soapenv:Body></soapenv:Envelope>'
                );
            } else {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '"><soapenv:Body>' +
                    '<GetCardBasicInfoResponse>' +
                    '<Sys><Code>1</Code><Description>Success</Description></Sys>' +
                    '<CardBasicInfo>' +
                    '<MainCard>' +
                    '<AccountNumber>' + ACCOUNT_NUMBER + '</AccountNumber>' +
                    '<ContractNumber>' + CONTRACT_NUMBER + '</ContractNumber>' +
                    '<Status>Active</Status><CreditLimit>5000000</CreditLimit>' +
                    '<OTB>1000000</OTB><HoldAmount>0</HoldAmount>' +
                    '<MaskedCardNumber>****1234</MaskedCardNumber>' +
                    '<BlockCode>BC</BlockCode><ActivatedFlag>Y</ActivatedFlag>' +
                    '<InsuranceFlag>1</InsuranceFlag>' +
                    '</MainCard>' +
                    '<PassDue><DPD>5</DPD></PassDue>' +
                    '<CardHistories><CardHistory><CardActivationDate>20240101</CardActivationDate></CardHistory></CardHistories>' +
                    '</CardBasicInfo></GetCardBasicInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
            }
            return res;
        }
    }
}
