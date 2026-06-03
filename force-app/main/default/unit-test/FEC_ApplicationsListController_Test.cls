/**
 * Unit tests for FEC_ApplicationsListController.
 */
@IsTest
private class FEC_ApplicationsListController_Test {

    private static final String APP_ID = '123456789';
    private static final String CIF = 'CIF000001';
    private static final String ACCOUNT_NUM = '0001500010000000261';
    private static final String CONTRACT_NUM = '12345678-1234567-123';

    private static User adminUser() {
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE
            LIMIT 1
        ];
    }

    @TestSetup
    static void setupMasterData() {
        FEC_API_Setting__c apiSetting = new FEC_API_Setting__c(
            FEC_Enviroment__c = FEC_ConstantCommon.ENVIROMENT_NON_PRODUCTION,
            FEC_Call_Mock__c = false,
            FEC_Endpoint__c = 'https://test.example.com'
        );
        insert apiSetting;

        FEC_Country__c country = new FEC_Country__c(Name = 'Viet Nam', FEC_Code__c = 'VN');
        insert country;

        insert new FEC_Province__c(
            Name = 'Ha Noi',
            FEC_Name_VN__c = 'Ha Noi VN',
            FEC_Code__c = 'HN',
            FEC_Country__c = country.Id
        );
        insert new FEC_District__c(
            Name = 'Cau Giay',
            FEC_Name_VN__c = 'Cau Giay VN',
            FEC_Code__c = 'CG',
            FEC_Country__c = country.Id,
            FEC_Province__c = [SELECT Id FROM FEC_Province__c LIMIT 1].Id
        );
    }

    private static FEC_Product_Type__c insertProductType(String name) {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = name,
            FEC_Code__c = 'PT' + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6)
        );
        insert pt;
        return pt;
    }

    private static Case insertCaseWithCustomerHistory(String productTypeName) {
        FEC_Product_Type__c pt = insertProductType(productTypeName);
        FEC_CaseTriggerHandler.isExecuting = true;
        Case c = new Case(Subject = 'FEC_ApplicationsListController_Test');
        insert c;
        FEC_CaseTriggerHandler.isExecuting = false;

        FEC_Customer_History__c history = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = ACCOUNT_NUM,
            FEC_Contract_Number__c = CONTRACT_NUM
        );
        insert history;

        c.FEC_Product_Type__c = pt.Id;
        c.FEC_Account_or_Contract__c = history.Id;
        update c;
        return c;
    }

    private static String mockCustomerListXml() {
        return '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<cif:GetCustomerListResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
            '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
            '<Count>1</Count>' +
            '<Customers><Customer>' +
            '<CIFNumber>' + CIF + '</CIFNumber>' +
            '<NationalID>012345678901</NationalID>' +
            '<Phones><PhoneNode><Phone>0901111222</Phone></PhoneNode></Phones>' +
            '<Emails><Email>user@example.com</Email></Emails>' +
            '<Applications><Application>' +
            '<ApplicationID>' + APP_ID + '</ApplicationID>' +
            '<AccountNumber>' + ACCOUNT_NUM + '</AccountNumber>' +
            '<ContractNumber>' + CONTRACT_NUM + '</ContractNumber>' +
            '</Application></Applications>' +
            '<Addresses><Address>' +
            '<AddressType>' + FEC_ConstantCommon.ADDRESS_TYPE_CURRES + '</AddressType>' +
            '<Building>B1</Building><HouseNumber>10</HouseNumber><Street>Le Loi</Street>' +
            '<Ward>W1</Ward><District>CG</District><City>HN</City>' +
            '<CountryName>Vietnam</CountryName><ZipCode>100000</ZipCode>' +
            '</Address></Addresses>' +
            '</Customer></Customers>' +
            '</cif:GetCustomerListResponse></soapenv:Body></soapenv:Envelope>';
    }

    private static String mockApplicationsListXml() {
        return '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body><GetApplicationsListResponse>' +
            '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
            '<CIFNumber>' + CIF + '</CIFNumber>' +
            '<Applications><Application>' +
            '<ApplicationID>' + APP_ID + '</ApplicationID>' +
            '<ProductGroup>Card</ProductGroup>' +
            '<LastStatus>Approved</LastStatus>' +
            '<DateStatus>2026-01-15</DateStatus>' +
            '</Application></Applications>' +
            '</GetApplicationsListResponse></soapenv:Body></soapenv:Envelope>';
    }

    private static String mockAddressesListXml() {
        return '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body><GetAddressesListResponse>' +
            '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
            '<CIFNumber>' + CIF + '</CIFNumber>' +
            '<Addresses>' +
            '<Address>' +
            '<AddressType>' + FEC_ConstantCommon.ADDRESS_TYPE_PERMNENT + '</AddressType>' +
            '<Building>B2</Building><Number>20</Number><Street>Tran Phu</Street>' +
            '<Ward>W2</Ward><District>CG</District><City>HN</City>' +
            '<CountryName>Vietnam</CountryName><ZipCode>100001</ZipCode>' +
            '</Address>' +
            '<Address>' +
            '<AddressType>' + FEC_ConstantCommon.ADDRESS_TYPE_OFFICE + '</AddressType>' +
            '<Building>B3</Building><Number>30</Number><Street>Nguyen Trai</Street>' +
            '<Ward>W3</Ward><District>XX</District><City>YY</City>' +
            '<CountryName>Vietnam</CountryName><ZipCode>100002</ZipCode>' +
            '</Address>' +
            '</Addresses>' +
            '</GetAddressesListResponse></soapenv:Body></soapenv:Envelope>';
    }

    private static String mockSaleDisburseJson() {
        return '{' +
            '"Sys":{"TransID":"TXN-SALE","DateTime":"2026-05-27T10:00:00.000Z","Code":1,"Description":"OK"},' +
            '"CustomerSaleInfos":[{"APPLICATION_ID":"' + APP_ID + '",' +
            '"CC_CODE":"CC01","CC_NAME":"CC Name","DSA_CODE":"DSA01","DSA_NAME":"DSA Name",' +
            '"TSA_CODE":"TSA01","TSA_NAME":"TSA Name"}]' +
            '}';
    }

    private class ApplicationsListCompositeMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String body = req.getBody() != null ? req.getBody() : '';
            String endpoint = req.getEndpoint() != null ? req.getEndpoint() : '';
            String responseBody;

            if (body.contains('GetCustomerList')) {
                responseBody = mockCustomerListXml();
            } else if (body.contains('GetApplicationsList')) {
                responseBody = mockApplicationsListXml();
            } else if (body.contains('GetAddressesList')) {
                responseBody = mockAddressesListXml();
            } else if (endpoint.contains('APPLICATION_ID') || req.getMethod() == 'GET') {
                responseBody = mockSaleDisburseJson();
            } else {
                responseBody = mockCustomerListXml();
            }

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(responseBody);
            return res;
        }
    }

    @IsTest
    static void loadApplicationInfo_nullCaseId_throws() {
        Boolean thrown = false;
        try {
            FEC_ApplicationsListController.loadApplicationInfo(null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        System.assert(thrown, 'Null case Id must throw AuraHandledException.');
    }

    @IsTest
    static void loadApplicationInfo_existingCache_skipsApiCall() {
        System.runAs(adminUser()) {
            Case c = insertCaseWithCustomerHistory(FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE);
            String cacheJson = '[{"applicationId":"APP-CACHED","lastStatus":"Open"}]';
            FEC_Application_List__c al = new FEC_Application_List__c(
                FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
                FEC_API_Cache_Applications__c = cacheJson
            );
            insert al;

            Test.startTest();
            FEC_ApplicationsListController.loadApplicationInfo(c.Id);
            Test.stopTest();

            al = [
                SELECT FEC_API_Cache_Applications__c
                FROM FEC_Application_List__c
                WHERE Id = :al.Id
            ];
            System.assertEquals(cacheJson, al.FEC_API_Cache_Applications__c);
        }
    }

    @IsTest
    static void loadApplicationInfo_noCache_apiFailsWithoutPersistingCache() {
        System.runAs(adminUser()) {
            Case c = insertCaseWithCustomerHistory(FEC_ConstantCommon.PRODUCT_TYPE_LOAN_CASE);
            Test.startTest();
            FEC_ApplicationsListController.loadApplicationInfo(c.Id);
            Test.stopTest();

            List<FEC_Application_List__c> rows = [
                SELECT Id
                FROM FEC_Application_List__c
                WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
            ];
            System.assertEquals(0, rows.size(), 'Failed API call must not upsert cache row.');
        }
    }

    @IsTest
    static void loadApplicationInfo_fullApiSuccess_populatesCache() {
        System.runAs(adminUser()) {
            Case c = insertCaseWithCustomerHistory(FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE);
            Test.setMock(HttpCalloutMock.class, new ApplicationsListCompositeMock());

            Test.startTest();
            FEC_ApplicationsListController.loadApplicationInfo(c.Id);
            Test.stopTest();

            FEC_Application_List__c al = [
                SELECT FEC_API_Cache_Applications__c
                FROM FEC_Application_List__c
                WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
                LIMIT 1
            ];
            System.assertNotEquals(null, al.FEC_API_Cache_Applications__c);
            System.assert(al.FEC_API_Cache_Applications__c.contains(APP_ID));

            List<FEC_ApplicationsListController.ApplicationRowDTO> rows =
                FEC_ApplicationsListController.getApplicationsForUI(c.Id);
            System.assertEquals(1, rows.size());
            System.assertEquals(APP_ID, rows[0].applicationId);
            System.assertEquals('Approved', rows[0].lastStatus);
            System.assertEquals('Card', rows[0].productGroup);
            System.assertEquals(ACCOUNT_NUM, rows[0].accountNumber);
            System.assertEquals('012345678901', rows[0].nationalPassportID);
            System.assertEquals('0901111222', rows[0].registrationPhone);
            System.assertEquals('user@example.com', rows[0].registrationEmail);
            System.assertNotEquals(null, rows[0].currentAddress);
            System.assertNotEquals(null, rows[0].permanentAddress);
            System.assertNotEquals(null, rows[0].officeAddress);
            System.assertEquals('CC01', rows[0].ccCode);
            System.assertEquals('DSA01', rows[0].dSACode);

            FEC_ApplicationsListController.ApplicationRowDTO detail =
                FEC_ApplicationsListController.loadApplicationDetail(al.Id, APP_ID);
            System.assertEquals(APP_ID, detail.applicationId);
            System.assertEquals(c.Id, detail.caseId);
        }
    }

    @IsTest
    static void loadApplicationInfo_blankCacheRecord_callsApi() {
        System.runAs(adminUser()) {
            Case c = insertCaseWithCustomerHistory(FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE);
            insert new FEC_Application_List__c(
                FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
                FEC_API_Cache_Applications__c = null
            );
            Test.setMock(HttpCalloutMock.class, new ApplicationsListCompositeMock());

            Test.startTest();
            FEC_ApplicationsListController.loadApplicationInfo(c.Id);
            Test.stopTest();

            FEC_Application_List__c al = [
                SELECT FEC_API_Cache_Applications__c
                FROM FEC_Application_List__c
                WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
                LIMIT 1
            ];
            System.assert(al.FEC_API_Cache_Applications__c.contains(APP_ID));
        }
    }

    @IsTest
    static void loadApplicationInfo_customerWithoutApplications_skipsRow() {
        System.runAs(adminUser()) {
            Case c = insertCaseWithCustomerHistory(FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE);
            Test.setMock(HttpCalloutMock.class, new CustomerListNoAppsMock());

            Test.startTest();
            FEC_ApplicationsListController.loadApplicationInfo(c.Id);
            Test.stopTest();

            FEC_Application_List__c al = [
                SELECT FEC_API_Cache_Applications__c
                FROM FEC_Application_List__c
                WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
                LIMIT 1
            ];
            System.assertEquals('[]', al.FEC_API_Cache_Applications__c);
        }
    }

    private class CustomerListNoAppsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String xml =
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><cif:GetCustomerListResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
                '<Sys><Code>1</Code></Sys><Count>1</Count>' +
                '<Customers><Customer><CIFNumber>' + CIF + '</CIFNumber></Customer></Customers>' +
                '</cif:GetCustomerListResponse></soapenv:Body></soapenv:Envelope>';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(xml);
            return res;
        }
    }

    @IsTest
    static void getApplicationsForUI_nullCaseId_returnsEmpty() {
        System.assertEquals(
            0,
            FEC_ApplicationsListController.getApplicationsForUI(null).size()
        );
    }

    @IsTest
    static void getApplicationsForUI_noCustomerHistory_returnsEmpty() {
        Case c = new Case(Subject = 'FEC_ApplicationsListController_Test_noCH');
        insert c;
        System.assertEquals(
            0,
            FEC_ApplicationsListController.getApplicationsForUI(c.Id).size()
        );
    }

    @IsTest
    static void getApplicationsForUI_withCache_returnsDtos() {
        System.runAs(adminUser()) {
            Case c = insertCaseWithCustomerHistory(FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE);
            insert new FEC_Application_List__c(
                FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
                FEC_API_Cache_Applications__c =
                    '[{"applicationId":"APP-1","lastStatus":"Approved","accountNumber":"N/A"}]'
            );

            List<FEC_ApplicationsListController.ApplicationRowDTO> rows =
                FEC_ApplicationsListController.getApplicationsForUI(c.Id);

            System.assertEquals(1, rows.size());
            System.assertEquals('APP-1', rows[0].applicationId);
            System.assertEquals('Approved', rows[0].lastStatus);
            System.assertNotEquals(null, rows[0].helpTexts);
        }
    }

    @IsTest
    static void loadApplicationDetail_returnsMatchingRowAndCaseId() {
        System.runAs(adminUser()) {
            Case c = insertCaseWithCustomerHistory(FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE);
            FEC_Application_List__c al = new FEC_Application_List__c(
                FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
                FEC_API_Cache_Applications__c =
                    '[{"applicationId":"APP-99","productGroup":"Card"}]'
            );
            insert al;

            FEC_ApplicationsListController.ApplicationRowDTO dto =
                FEC_ApplicationsListController.loadApplicationDetail(al.Id, 'APP-99');

            System.assertNotEquals(null, dto);
            System.assertEquals('APP-99', dto.applicationId);
            System.assertEquals('Card', dto.productGroup);
            System.assertEquals(al.Id, dto.Id);
            System.assertEquals(c.Id, dto.caseId);
        }
    }

    @IsTest
    static void loadApplicationDetail_nullOrUnknown_returnsNull() {
        System.assertEquals(
            null,
            FEC_ApplicationsListController.loadApplicationDetail(null, 'X')
        );

        System.runAs(adminUser()) {
            Case c = insertCaseWithCustomerHistory(FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE);
            FEC_Application_List__c al = new FEC_Application_List__c(
                FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
                FEC_API_Cache_Applications__c = '[{"applicationId":"APP-1"}]'
            );
            insert al;

            System.assertEquals(
                null,
                FEC_ApplicationsListController.loadApplicationDetail(al.Id, 'NOT-FOUND')
            );
        }
    }

    @IsTest
    static void logSensitiveFromMainInfo_completes() {
        System.runAs(adminUser()) {
            Case c = insertCaseWithCustomerHistory(FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE);
            FEC_ApplicationsListController.logSensitiveFromMainInfo(
                'Applications',
                'National ID',
                c.Id
            );
        }
    }
}
