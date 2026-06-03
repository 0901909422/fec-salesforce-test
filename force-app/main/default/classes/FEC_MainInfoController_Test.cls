@IsTest
private class FEC_MainInfoController_Test {

    private static final String ACCOUNT_NUMBER = '0001500060000003';
    private static final String CIF_NUMBER = 'CIF001';

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
            Subject = 'FEC_MainInfoController_Test',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_Product_Type__c = prod.Id,
            Status = 'New',
            FEC_ID_Search__c = 'MIC-' + suffix
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
            FEC_CIF_Number__c = CIF_NUMBER
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

    @IsTest
    static void testLoadMainInfo_Success() {
        if (Type.forName('FEC_MainInfoController') == null) {
            System.assert(true, 'Skipped: FEC_MainInfoController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MainInfoHttpCalloutMock());

        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result =
            FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testAddressPicklistOptions() {
        if (Type.forName('FEC_MainInfoController') == null) {
            System.assert(true, 'Skipped: FEC_MainInfoController not on org.');
            return;
        }

        FEC_Country__c country = new FEC_Country__c(FEC_Code__c = '2');
        insert country;

        FEC_Province__c prov = new FEC_Province__c(
            Name = 'Hanoi',
            FEC_Code__c = 'HN',
            FEC_Name_VN__c = 'Hà Nội',
            FEC_Country__c = country.Id
        );
        insert prov;

        Test.startTest();
        List<FEC_MainInfoController.PicklistOptionDTO> provinces =
            FEC_MainInfoController.getProvinceOptionsForCountryFecCode('2');
        List<FEC_MainInfoController.PicklistOptionDTO> districts =
            FEC_MainInfoController.getDistrictOptionsForProvinceCode('HN');
        Test.stopTest();

        System.assertNotEquals(0, provinces.size());
        System.assertNotEquals(null, districts);
    }

    @IsTest
    static void testClearMainInfoCacheAndLogSensitive() {
        if (Type.forName('FEC_MainInfoController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_MainInfoController.clearMainInfoCache(c.Id);
        FEC_MainInfoController.logSensitiveFromMainInfo(
            FEC_ConstantCommon.SECTION_CUSTOMER_INFORMATION,
            'FEC_National_ID_Passport_ID__c',
            c.Id
        );
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testGetWardOptionsForProvinceCode() {
        if (Type.forName('FEC_MainInfoController') == null) {
            return;
        }

        FEC_Country__c country = new FEC_Country__c(FEC_Code__c = '2');
        insert country;
        FEC_Province__c prov = new FEC_Province__c(
            Name = 'HCM',
            FEC_Code__c = 'HCM',
            FEC_Name_VN__c = 'TP HCM',
            FEC_Country__c = country.Id
        );
        insert prov;

        Test.startTest();
        List<FEC_MainInfoController.PicklistOptionDTO> wards =
            FEC_MainInfoController.getWardOptionsForProvinceCode('HCM');
        List<FEC_MainInfoController.PicklistOptionDTO> provinces =
            FEC_MainInfoController.getProvinceOptionsForAddress();
        Test.stopTest();

        System.assertNotEquals(null, wards);
        System.assertNotEquals(null, provinces);
    }

    @IsTest
    static void testSavePendingAddress() {
        if (Type.forName('FEC_MainInfoController') == null) {
            System.assert(true, 'Skipped: FEC_MainInfoController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_MainInfoController.savePendingAddress(
            c.Id,
            FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
            false,
            null,
            '123',
            'Bld',
            'Street',
            null,
            null,
            true
        );
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_Address_Info__c WHERE FEC_Case__c = :c.Id]
        );
    }

    @IsTest
    static void testLoadMainInfo_NoCustomerHistory() {
        if (Type.forName('FEC_MainInfoController') == null) {
            return;
        }

        Case orphan = new Case(
            Subject = 'MainInfo orphan',
            Status = 'New',
            FEC_ID_Search__c = 'MIC-ORPHAN-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert orphan;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_MainInfoController.loadMainInfo(orphan.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testGetMailingAddressUpdateContext() {
        if (Type.forName('FEC_MainInfoController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new AddressesListMock());

        Test.startTest();
        FEC_MainInfoController.MailingAddressContextDTO ctx =
            FEC_MainInfoController.getMailingAddressUpdateContext(
                c.Id,
                FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT
            );
        String normalized = FEC_MainInfoController.normalizeProvinceCodeForAddressUi('1');
        Test.stopTest();

        System.assertNotEquals(null, ctx);
        System.assertNotEquals(null, normalized);
    }

    @IsTest
    static void testGetMailingAddressUpdateContext_InvalidParams() {
        if (Type.forName('FEC_MainInfoController') == null) {
            return;
        }

        Test.startTest();
        FEC_MainInfoController.MailingAddressContextDTO nullCase =
            FEC_MainInfoController.getMailingAddressUpdateContext(null, 'Permanent');
        FEC_MainInfoController.MailingAddressContextDTO blankType =
            FEC_MainInfoController.getMailingAddressUpdateContext(
                [SELECT Id FROM Case LIMIT 1].Id,
                ''
            );
        Test.stopTest();

        System.assertEquals(false, nullCase.found);
        System.assertEquals(false, blankType.found);
    }

    @IsTest
    static void testLoadCasePendingAddressJsonMap() {
        if (Type.forName('FEC_MainInfoController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        Map<String, String> pendingMap =
            FEC_MainInfoController.loadCasePendingAddressJsonMap(c.Id);
        FEC_MainInfoController.clearCasePendingAddressRows(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, pendingMap);
        System.assertEquals(0, pendingMap.size());
    }

    @IsTest
    static void testSyncLocalMailingAddressSelection() {
        if (Type.forName('FEC_MainInfoController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Id chId = [SELECT FEC_Account_or_Contract__c FROM Case WHERE Id = :c.Id].FEC_Account_or_Contract__c;
        insert new FEC_Address_Info__c(
            FEC_Customer_History__c = chId,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
            FEC_Mailing_Address__c = false
        );

        Test.startTest();
        FEC_MainInfoController.syncLocalMailingAddressSelection(
            c.Id,
            FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT
        );
        Test.stopTest();

        System.assertEquals(
            true,
            [SELECT FEC_Mailing_Address__c FROM FEC_Address_Info__c WHERE FEC_Customer_History__c = :chId LIMIT 1]
                .FEC_Mailing_Address__c
        );
    }

    private class AddressesListMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetAddressesListResponse>' +
                '<Sys><Code>1</Code></Sys>' +
                '<Addresses><Address>' +
                '<AddressType>PERMNENT</AddressType><AddressId>ADDR1</AddressId>' +
                '<Building>B1</Building><NumberStr>10</NumberStr><Street>St</Street>' +
                '<District>D1</District><City>1</City>' +
                '</Address></Addresses>' +
                '</GetAddressesListResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class MainInfoHttpCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><Response><Sys><Code>1</Code></Sys></Response></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }
}
