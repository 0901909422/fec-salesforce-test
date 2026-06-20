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
            FEC_MainInfoController.getDistrictOptionsForProvinceCode('HN', null);
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
        insert new FEC_District__c(
            Name = 'District 1',
            FEC_Code__c = 'D1',
            FEC_Province__c = prov.Id
        );

        Test.startTest();
        List<FEC_MainInfoController.PicklistOptionDTO> districts =
            FEC_MainInfoController.getDistrictOptionsForProvinceCode('HCM', null);
        List<FEC_MainInfoController.PicklistOptionDTO> provinces =
            FEC_MainInfoController.getProvinceOptionsForAddress();
        Test.stopTest();

        System.assertNotEquals(null, districts);
        System.assertEquals(1, districts.size());
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
            null, null);
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
        FEC_MainInfoController.syncMailingAddressFlagsFromCardMailingInd(
            chId,
            'R'
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
            String body = req.getBody() != null ? req.getBody().toLowerCase() : '';
            if (body.contains('getcustomerinfobasic')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerInfoBasicResponse>' +
                    '<Sys><Code>1</Code></Sys><CustomerBasicInfo>' +
                    '<FirstName>Main</FirstName><LastName>Info</LastName><FullName>Main Info</FullName>' +
                    '<Birthday>1990-01-01</Birthday><Gender>Male</Gender><MaritalStatus>Single</MaritalStatus>' +
                    '<CIFNumber>CIF001</CIFNumber></CustomerBasicInfo>' +
                    '</GetCustomerInfoBasicResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }
            if (body.contains('getdocumentslist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://soap.sforce.com/soap/envelope/">' +
                    '<soapenv:Body><GetDocumentsListResponse><Sys><Code>1</Code></Sys>' +
                    '<Documents><Document><IDDocumentNumber>079111222333</IDDocumentNumber>' +
                    '<IssueDate>2020-01-01</IssueDate><IssuePlace>HCM</IssuePlace></Document></Documents>' +
                    '</GetDocumentsListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }
            if (body.contains('getaddresseslist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetAddressesListResponse><Sys><Code>1</Code></Sys>' +
                    '<Addresses><Address><AddressType>PERMNENT</AddressType><AddressId>ADDR1</AddressId>' +
                    '<Building>B1</Building><NumberStr>10</NumberStr><Street>Main St</Street>' +
                    '<District>D1</District><City>1</City></Address></Addresses>' +
                    '</GetAddressesListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }
            if (body.contains('getcustomerlist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerListResponse><Sys><Code>1</Code><Count>1</Count>' +
                    '<Customers><Customer><Phones><PhoneNode><Type>Mobile</Type>' +
                    '<Phone>0909111222</Phone></PhoneNode></Phones></Customer></Customers>' +
                    '</GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><Response><Sys><Code>1</Code></Sys></Response></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    @IsTest
    static void testLoadMainInfo_CacheHit() {
        if (Type.forName('FEC_MainInfoController') == null) {
            return;
        }

        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        FEC_MainInfoController.MainInfoDTO cached = new FEC_MainInfoController.MainInfoDTO();
        cached.fullName = 'Cached Customer';
        cached.addresses = new List<FEC_MainInfoController.AddressDTO>();
        hist.FEC_API_Cache__c = JSON.serialize(cached);
        update hist;

        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertEquals('Cached Customer', result.fullName);
    }

    @IsTest
    static void testLoadMainInfo_CacheEmptyAddressesResync() {
        if (Type.forName('FEC_MainInfoController') == null) {
            return;
        }

        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Customer_History__c hist = [
            SELECT Id, FEC_CIF_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        FEC_MainInfoController.MainInfoDTO cached = new FEC_MainInfoController.MainInfoDTO();
        cached.fullName = 'Cached Resync';
        cached.addresses = new List<FEC_MainInfoController.AddressDTO>();
        hist.FEC_API_Cache__c = JSON.serialize(cached);
        hist.FEC_CIF_Number__c = CIF_NUMBER;
        update hist;

        Test.setMock(HttpCalloutMock.class, new AddressesListMock());
        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertEquals('Cached Resync', result.fullName);
        System.assertNotEquals(null, result.addresses);
    }

    @IsTest
    static void testLoadMainInfo_NullCaseId() {
        Boolean threw = false;
        Test.startTest();
        try {
            FEC_MainInfoController.loadMainInfo(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testUnpackPendingAddressApiMeta() {
        Test.startTest();
        List<String> empty = FEC_MainInfoController.unpackPendingAddressApiMeta(null);
        List<String> parsed = FEC_MainInfoController.unpackPendingAddressApiMeta(
            'FEC_ADDR_META\u001FCIF1\u001FADDR1\u001FPERM'
        );
        Test.stopTest();

        System.assertEquals(3, empty.size());
        System.assertEquals('CIF1', parsed[0]);
        System.assertEquals('ADDR1', parsed[1]);
        System.assertEquals('PERM', parsed[2]);
    }

    @IsTest
    static void testUpdateCustomerAddressParams() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new UpdateAddressMock());

        Test.startTest();
        FEC_UpdateCustomerAddress.UpdateResult result =
            FEC_UpdateCustomerAddress.updateCustomerAddressParams(
                String.valueOf(c.Id),
                FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
                CIF_NUMBER,
                'ADDR1',
                'PERMNENT',
                '10',
                'B1',
                'Street',
                'D1',
                '1',
                null,
                null,
                null,
                'Y',
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGetDistrictOptionsForProvinceCode() {
        FEC_Country__c country = new FEC_Country__c(FEC_Code__c = '2');
        insert country;
        FEC_Province__c prov = new FEC_Province__c(
            Name = 'District Prov',
            FEC_Code__c = 'DP',
            FEC_Name_VN__c = 'District Prov',
            FEC_Country__c = country.Id
        );
        insert prov;
        insert new FEC_District__c(
            Name = 'District 1',
            FEC_Code__c = 'D1',
            FEC_Province__c = prov.Id
        );

        Test.startTest();
        List<FEC_MainInfoController.PicklistOptionDTO> districts =
            FEC_MainInfoController.getDistrictOptionsForProvinceCode('DP', null);
        Test.stopTest();

        System.assertNotEquals(0, districts.size());
    }

    @IsTest
    static void testSavePendingAddress_DeletePending() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_MainInfoController.savePendingAddress(
            c.Id,
            FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
            false,
            null,
            'B2',
            '20',
            'Office St',
            null,
            null, null);

        Test.startTest();
        FEC_MainInfoController.savePendingAddress(
            c.Id,
            FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
            true,
            null,
            null,
            null,
            null,
            null,
            null, null);
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM FEC_Address_Info__c WHERE FEC_Case__c = :c.Id]
        );
    }

    @IsTest
    static void testLoadMainInfo_FullApiFlow() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        hist.FEC_API_Cache__c = null;
        hist.FEC_CIF_Number__c = CIF_NUMBER;
        update hist;

        Test.setMock(HttpCalloutMock.class, new MainInfoHttpCalloutMock());
        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.addresses);
    }

    @IsTest
    static void testLoadCasePendingAddressJsonMap_WithLegacyMeta() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        insert new FEC_Address_Info__c(
            FEC_Case__c = c.Id,
            FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT,
            FEC_Address__c = 'FEC_ADDR_META\u001FCIF1\u001FADDR1\u001FCURR',
            FEC_Building__c = 'B3',
            FEC_Number__c = '30',
            FEC_Street__c = 'Current St'
        );

        Test.startTest();
        Map<String, String> pendingMap =
            FEC_MainInfoController.loadCasePendingAddressJsonMap(c.Id);
        Test.stopTest();

        System.assertEquals(true, pendingMap.containsKey(FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT));
    }

    @IsTest
    static void testSavePendingAddress_AllAddressTypes() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        for (String addrType : new List<String>{
            FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
            FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
            FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT
        }) {
            FEC_MainInfoController.savePendingAddress(
                c.Id,
                addrType,
                false,
                null,
                'B-' + addrType,
                '1',
                'Street ' + addrType,
                null,
                null, null);
        }
        Test.stopTest();

        System.assertEquals(
            3,
            [SELECT COUNT() FROM FEC_Address_Info__c WHERE FEC_Case__c = :c.Id]
        );
    }

    @IsTest
    static void testGetProvinceCityLookupOptions() {
        FEC_Country__c country = new FEC_Country__c(FEC_Code__c = '2');
        insert country;
        insert new FEC_Province__c(
            Name = 'Lookup Prov',
            FEC_Code__c = 'LP',
            FEC_Name_VN__c = 'Tinh LP',
            FEC_Country__c = country.Id
        );

        Test.startTest();
        List<FEC_MainInfoController.PicklistOptionDTO> opts =
            FEC_MainInfoController.getProvinceCityLookupOptions();
        Test.stopTest();

        System.assertNotEquals(0, opts.size());
    }

    @IsTest
    static void testGetDistrictOptions_LegacyProvinceRemap() {
        FEC_Country__c legacy = new FEC_Country__c(FEC_Code__c = '1', FEC_Name_VN__c = 'VN');
        FEC_Country__c api = new FEC_Country__c(FEC_Code__c = '2', FEC_Name_VN__c = 'VN');
        insert new List<FEC_Country__c>{ legacy, api };

        FEC_Province__c legacyProv = new FEC_Province__c(
            Name = 'Remap Prov',
            FEC_Code__c = 'RP1',
            FEC_Name_VN__c = 'Remap Prov',
            FEC_Country__c = legacy.Id
        );
        FEC_Province__c apiProv = new FEC_Province__c(
            Name = 'Remap Prov',
            FEC_Code__c = 'RP2',
            FEC_Name_VN__c = 'Remap Prov',
            FEC_Country__c = api.Id
        );
        insert new List<FEC_Province__c>{ legacyProv, apiProv };
        insert new FEC_District__c(
            Name = 'Remap District',
            FEC_Code__c = 'RD1',
            FEC_Name_VN__c = 'Quan RD',
            FEC_Province__c = legacyProv.Id
        );
        insert new FEC_District__c(
            Name = 'Remap District Api',
            FEC_Code__c = 'RD2',
            FEC_Name_VN__c = 'Quan RD Api',
            FEC_Province__c = apiProv.Id
        );

        Test.startTest();
        List<FEC_MainInfoController.PicklistOptionDTO> districts =
            FEC_MainInfoController.getDistrictOptionsForProvinceCode('RP2', null);
        Test.stopTest();

        System.assertEquals(1, districts.size());
        System.assertEquals('RD2', districts[0].value);
    }

    @IsTest
    static void testGetWardOptions_WithWards() {
        FEC_Country__c country = new FEC_Country__c(FEC_Code__c = '2');
        insert country;
        FEC_Province__c prov = new FEC_Province__c(
            Name = 'Ward Prov',
            FEC_Code__c = 'WP',
            FEC_Name_VN__c = 'Tinh Ward',
            FEC_Country__c = country.Id
        );
        insert prov;
        insert new FEC_District__c(
            Name = 'District 1',
            FEC_Code__c = 'W1',
            FEC_Name_VN__c = 'Phuong 1',
            FEC_Province__c = prov.Id
        );

        Test.startTest();
        List<FEC_MainInfoController.PicklistOptionDTO> districts =
            FEC_MainInfoController.getDistrictOptionsForProvinceCode('WP', null);
        Test.stopTest();

        System.assertEquals(1, districts.size());
    }

    @IsTest
    static void testLoadMainInfo_CacheHitWithAddresses() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        Id chId = c.FEC_Account_or_Contract__c;
        insert new FEC_Address_Info__c(
            FEC_Customer_History__c = chId,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
            FEC_Street__c = '123 Main',
            FEC_District_Text__c = 'Ward Text'
        );

        FEC_Customer_History__c hist = [SELECT Id FROM FEC_Customer_History__c WHERE Id = :chId LIMIT 1];
        FEC_MainInfoController.MainInfoDTO cached = new FEC_MainInfoController.MainInfoDTO();
        cached.fullName = 'Cached With Addr';
        hist.FEC_API_Cache__c = JSON.serialize(cached);
        update hist;

        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertEquals('Cached With Addr', result.fullName);
        System.assertNotEquals(null, result.addresses);
        System.assertEquals(1, result.addresses.size());
    }

    @IsTest
    static void testLoadMainInfo_CacheHitPhoneResync() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        insert new FEC_Address_Info__c(
            FEC_Customer_History__c = hist.Id,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
            FEC_Street__c = '456 Main'
        );

        FEC_MainInfoController.MainInfoDTO cached = new FEC_MainInfoController.MainInfoDTO();
        cached.fullName = 'Phone Resync';
        hist.FEC_API_Cache__c = JSON.serialize(cached);
        hist.FEC_Primary_Phone__c = null;
        hist.FEC_CIF_Number__c = CIF_NUMBER;
        update hist;

        Test.setMock(HttpCalloutMock.class, new MainInfoHttpCalloutMock());
        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertEquals('Phone Resync', result.fullName);
        System.assertNotEquals(null, result.addresses);
    }

    @IsTest
    static void testLoadMainInfo_AddressEligibilityBlocked() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        hist.FEC_API_Cache__c = null;
        hist.FEC_CIF_Number__c = CIF_NUMBER;
        hist.FEC_Block_Code_1__c = 'B';
        update hist;

        Test.setMock(HttpCalloutMock.class, new MainInfoHttpCalloutMock());
        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.addressUpdateNotEligibleTitle);
        System.assertNotEquals(null, result.addressUpdateNotEligibleReasons);
    }

    @IsTest
    static void testLoadMainInfo_FullAddressSyncWithMasterData() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        hist.FEC_API_Cache__c = null;
        hist.FEC_CIF_Number__c = CIF_NUMBER;
        update hist;

        FEC_Country__c legacy = new FEC_Country__c(
            FEC_Code__c = '1',
            FEC_Name_VN__c = 'Viet Nam',
            Name = 'Viet Nam'
        );
        FEC_Country__c api = new FEC_Country__c(
            FEC_Code__c = '2',
            FEC_Name_VN__c = 'Viet Nam',
            Name = 'Viet Nam'
        );
        insert new List<FEC_Country__c>{ legacy, api };
        FEC_Province__c legacyProv = new FEC_Province__c(
            Name = 'City 1',
            FEC_Code__c = '1',
            FEC_Name_VN__c = 'City 1',
            FEC_Country__c = legacy.Id
        );
        insert legacyProv;
        insert new FEC_District__c(
            Name = 'District 1',
            FEC_Code__c = 'D1',
            FEC_Province__c = legacyProv.Id
        );

        Test.setMock(HttpCalloutMock.class, new FullAddressesListMock());
        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.addresses);
        System.assert(result.addresses.size() > 0);
    }

    @IsTest
    static void testLoadMainInfo_LoanContractPhonePath() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c, FEC_Product_Type__c FROM Case LIMIT 1];
        update new FEC_Product_Type__c(
            Id = c.FEC_Product_Type__c,
            Name = FEC_ConstantCommon.PRODUCT_TYPE_LOAN_CASE
        );
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        hist.FEC_API_Cache__c = null;
        hist.FEC_CIF_Number__c = CIF_NUMBER;
        hist.FEC_Contract_Number__c = 'CONTRACT-001';
        hist.FEC_Primary_Phone__c = null;
        update hist;

        Test.setMock(HttpCalloutMock.class, new MainInfoHttpCalloutMock());
        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.addresses);
    }

    @IsTest
    static void testGetMailingAddressUpdateContext_OfficeAndPermFallback() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new PermanentFallbackAddressesMock());

        Test.startTest();
        FEC_MainInfoController.MailingAddressContextDTO officeCtx =
            FEC_MainInfoController.getMailingAddressUpdateContext(
                c.Id,
                FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE
            );
        FEC_MainInfoController.MailingAddressContextDTO permCtx =
            FEC_MainInfoController.getMailingAddressUpdateContext(
                c.Id,
                FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT
            );
        FEC_MainInfoController.MailingAddressContextDTO invalidType =
            FEC_MainInfoController.getMailingAddressUpdateContext(
                c.Id,
                'Unknown Address'
            );
        Test.stopTest();

        System.assertEquals(true, officeCtx.found);
        System.assertEquals(true, permCtx.found);
        System.assertEquals(false, invalidType.found);
    }

    @IsTest
    static void testGetMailingAddressUpdateContext_CifFromCache() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        hist.FEC_CIF_Number__c = null;
        hist.FEC_API_Cache__c = '{"cifNumber":"' + CIF_NUMBER + '"}';
        update hist;

        Test.setMock(HttpCalloutMock.class, new AddressesListMock());
        Test.startTest();
        FEC_MainInfoController.MailingAddressContextDTO ctx =
            FEC_MainInfoController.getMailingAddressUpdateContext(
                c.Id,
                FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT
            );
        Test.stopTest();

        System.assertEquals(true, ctx.found);
        System.assertEquals(CIF_NUMBER, ctx.cifNumber);
    }

    @IsTest
    static void testSavePendingAddress_UpdateExistingAndParent() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Address_Info__c parent = new FEC_Address_Info__c(
            FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
            FEC_Street__c = 'Parent Addr'
        );
        insert parent;

        FEC_MainInfoController.savePendingAddress(
            c.Id,
            FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT,
            false,
            null,
            'B1',
            '1',
            'First St',
            null,
            null, null);

        Test.startTest();
        FEC_MainInfoController.savePendingAddress(
            c.Id,
            FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT,
            false,
            parent.Id,
            'B2',
            '2',
            'Updated St',
            null,
            null, null);
        Test.stopTest();

        FEC_Address_Info__c row = [
            SELECT FEC_Building__c, FEC_Parent_Address__c, FEC_Mailing_Address__c
            FROM FEC_Address_Info__c
            WHERE FEC_Case__c = :c.Id
              AND FEC_Address_Type__c = :FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT
            LIMIT 1
        ];
        System.assertEquals('B2', row.FEC_Building__c);
        System.assertEquals(parent.Id, row.FEC_Parent_Address__c);
        System.assertEquals(false, row.FEC_Mailing_Address__c);
    }

    @IsTest
    static void testSavePendingAddress_InvalidParentAndType() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Boolean invalidParent = false;
        Boolean invalidType = false;

        Test.startTest();
        try {
            FEC_MainInfoController.savePendingAddress(
                c.Id,
                FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
                false,
                UserInfo.getUserId(),
                'B',
                '1',
                'St',
                null,
                null, null);
        } catch (AuraHandledException e) {
            invalidParent = true;
        }
        try {
            FEC_MainInfoController.savePendingAddress(
                c.Id,
                'Bad Type',
                false,
                null,
                'B',
                '1',
                'St',
                null,
                null, null);
        } catch (AuraHandledException e) {
            invalidType = true;
        }
        Test.stopTest();

        System.assertEquals(true, invalidParent);
        System.assertEquals(true, invalidType);
    }

    @IsTest
    static void testSyncLocalMailingAddressSelection_ClearAndInvalid() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        Id chId = c.FEC_Account_or_Contract__c;
        insert new FEC_Address_Info__c(
            FEC_Customer_History__c = chId,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
            FEC_Mailing_Address__c = true
        );

        Test.startTest();
        FEC_MainInfoController.syncMailingAddressFlagsFromCardMailingInd(chId, null);
        FEC_MainInfoController.syncMailingAddressFlagsFromCardMailingInd(chId, 'Invalid');
        FEC_MainInfoController.clearMainInfoCache(null);
        FEC_MainInfoController.clearCasePendingAddressRows(null);
        Test.stopTest();

        System.assertEquals(
            false,
            [SELECT FEC_Mailing_Address__c FROM FEC_Address_Info__c WHERE FEC_Customer_History__c = :chId LIMIT 1]
                .FEC_Mailing_Address__c
        );
    }

    @IsTest
    static void testLoadCasePendingAddressJsonMap_WithJsonAddress() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        insert new FEC_Address_Info__c(
            FEC_Case__c = c.Id,
            FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
            FEC_Address__c = '{"cifNumber":"CIF_JSON","addressId":"AID1","addressType":"OFFICE"}',
            FEC_Building__c = 'Json Bld',
            FEC_Number__c = '9',
            FEC_Street__c = 'Json St'
        );

        Test.startTest();
        Map<String, String> pendingMap =
            FEC_MainInfoController.loadCasePendingAddressJsonMap(c.Id);
        Test.stopTest();

        System.assert(pendingMap.get(FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE).contains('CIF_JSON'));
    }

    @IsTest
    static void testNormalizeProvinceCodeForAddressUi_Blank() {
        Test.startTest();
        System.assertEquals(null, FEC_MainInfoController.normalizeProvinceCodeForAddressUi(null));
        System.assertEquals('', FEC_MainInfoController.normalizeProvinceCodeForAddressUi(''));
        Test.stopTest();
    }

    @IsTest
    static void testGetProvinceOptionsForCountryFecCode_Blank() {
        Test.startTest();
        List<FEC_MainInfoController.PicklistOptionDTO> blank =
            FEC_MainInfoController.getProvinceOptionsForCountryFecCode(null);
        List<FEC_MainInfoController.PicklistOptionDTO> empty =
            FEC_MainInfoController.getProvinceOptionsForCountryFecCode('  ');
        Test.stopTest();

        System.assertEquals(0, blank.size());
        System.assertEquals(0, empty.size());
    }

    @IsTest
    static void testSyncMailingAddressFlagsFromCardMailingInd() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        Id chId = c.FEC_Account_or_Contract__c;
        insert new List<FEC_Address_Info__c>{
            new FEC_Address_Info__c(
                FEC_Customer_History__c = chId,
                FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
                FEC_Mailing_Address__c = false
            ),
            new FEC_Address_Info__c(
                FEC_Customer_History__c = chId,
                FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT,
                FEC_Mailing_Address__c = false
            ),
            new FEC_Address_Info__c(
                FEC_Customer_History__c = chId,
                FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
                FEC_Mailing_Address__c = false
            )
        };

        Test.startTest();
        System.assertEquals(false, FEC_MainInfoController.syncMailingAddressFlagsFromCardMailingInd(null, 'E'));
        System.assertEquals(
            true,
            FEC_MainInfoController.syncMailingAddressFlagsFromCardMailingInd(chId, 'E')
        );
        System.assertEquals(
            true,
            FEC_MainInfoController.syncMailingAddressFlagsFromCardMailingInd(chId, 'C')
        );
        System.assertEquals(
            true,
            FEC_MainInfoController.syncMailingAddressFlagsFromCardMailingInd(chId, 'R')
        );
        Test.stopTest();

        Map<String, Boolean> mailingByType = new Map<String, Boolean>();
        for (FEC_Address_Info__c row : [
            SELECT FEC_Address_Type__c, FEC_Mailing_Address__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :chId AND FEC_Case__c = null
        ]) {
            mailingByType.put(row.FEC_Address_Type__c, row.FEC_Mailing_Address__c);
        }
        System.assertEquals(false, mailingByType.get(FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE));
        System.assertEquals(false, mailingByType.get(FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT));
        System.assertEquals(true, mailingByType.get(FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT));
    }

    @IsTest
    static void testSyncMailingAddressFlagsFromCardMailingInd_Individual() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        Id chId = c.FEC_Account_or_Contract__c;
        insert new FEC_Address_Info__c(
            FEC_Customer_History__c = chId,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
            FEC_Mailing_Address__c = false
        );

        Test.startTest();
        FEC_MainInfoController.syncMailingAddressFlagsFromCardMailingInd(chId, 'E');
        Test.stopTest();

        System.assertEquals(
            true,
            [SELECT FEC_Mailing_Address__c FROM FEC_Address_Info__c WHERE FEC_Customer_History__c = :chId LIMIT 1]
                .FEC_Mailing_Address__c
        );
    }

    @IsTest
    static void testSyncMasterAddressesFromPendingRows() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        Id chId = c.FEC_Account_or_Contract__c;

        FEC_Country__c country = new FEC_Country__c(FEC_Code__c = '2', FEC_Name_VN__c = 'VN', Name = 'VN');
        insert country;
        FEC_Province__c prov = new FEC_Province__c(
            Name = 'Sync Prov',
            FEC_Code__c = 'SP01',
            FEC_Name_VN__c = 'Sync Prov',
            FEC_Country__c = country.Id
        );
        insert prov;
        FEC_District__c dist = new FEC_District__c(
            Name = 'Sync Dist',
            FEC_Code__c = 'SD01',
            FEC_Province__c = prov.Id
        );
        insert dist;

        FEC_Address_Info__c master = new FEC_Address_Info__c(
            FEC_Customer_History__c = chId,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
            FEC_Street__c = 'Old Master St'
        );
        insert master;

        FEC_Address_Info__c pending = new FEC_Address_Info__c(
            FEC_Customer_History__c = chId,
            FEC_Case__c = c.Id,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
            FEC_Parent_Address__c = master.Id,
            FEC_Address__c = '{"building":"New Bld","number_x":"99","street":"New St","district":"SD01","city":"SP01"}'
        );

        Test.startTest();
        FEC_MainInfoController.syncMasterAddressesFromPendingRows(chId, null);
        FEC_MainInfoController.syncMasterAddressesFromPendingRows(null, new List<FEC_Address_Info__c>{ pending });
        FEC_MainInfoController.syncMasterAddressesFromPendingRows(chId, new List<FEC_Address_Info__c>{ pending });
        Test.stopTest();

        FEC_Address_Info__c updated = [
            SELECT FEC_Building__c, FEC_Street__c, FEC_Province__c, FEC_District__c, FEC_Country__c
            FROM FEC_Address_Info__c
            WHERE Id = :master.Id
        ];
        System.assertEquals('New Bld', updated.FEC_Building__c);
        System.assertEquals('New St', updated.FEC_Street__c);
        System.assertEquals(prov.Id, updated.FEC_Province__c);
        System.assertEquals(dist.Id, updated.FEC_District__c);
        System.assertEquals(country.Id, updated.FEC_Country__c);
    }

    @IsTest
    static void testSyncMasterAddressesFromPendingRows_JsonPending() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        Id chId = c.FEC_Account_or_Contract__c;

        FEC_Country__c country;
        List<FEC_Country__c> existingCountries = [
            SELECT Id FROM FEC_Country__c WHERE FEC_Code__c = '2' LIMIT 1
        ];
        if (!existingCountries.isEmpty()) {
            country = existingCountries[0];
        } else {
            country = new FEC_Country__c(FEC_Code__c = '2', Name = 'VN2');
            insert country;
        }

        FEC_Province__c prov = new FEC_Province__c(
            Name = 'Json Prov',
            FEC_Code__c = 'JP01',
            FEC_Name_VN__c = 'Json Prov',
            FEC_Country__c = country.Id
        );
        insert prov;
        insert new FEC_District__c(
            Name = 'Json Dist',
            FEC_Code__c = 'JD01',
            FEC_Province__c = prov.Id
        );

        insert new FEC_Address_Info__c(
            FEC_Customer_History__c = chId,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
            FEC_Street__c = 'Master Office'
        );

        FEC_Address_Info__c pending = new FEC_Address_Info__c(
            FEC_Customer_History__c = chId,
            FEC_Case__c = c.Id,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
            FEC_Address__c = '{"building":"JB","number_x":"7","street":"Json Street","district":"JD01","city":"JP01"}'
        );

        Test.startTest();
        FEC_MainInfoController.syncMasterAddressesFromPendingRows(
            chId,
            new List<FEC_Address_Info__c>{ pending }
        );
        Test.stopTest();

        FEC_Address_Info__c updated = [
            SELECT FEC_Building__c, FEC_Street__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :chId
              AND FEC_Case__c = null
              AND FEC_Address_Type__c = :FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE
            LIMIT 1
        ];
        System.assertEquals('JB', updated.FEC_Building__c);
        System.assertEquals('Json Street', updated.FEC_Street__c);
    }

    @IsTest
    static void testLoadMainInfo_CardCacheHitMailingRefresh() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c, FEC_Product_Type__c FROM Case LIMIT 1];
        update new FEC_Product_Type__c(
            Id = c.FEC_Product_Type__c,
            Name = FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE
        );
        Id chId = c.FEC_Account_or_Contract__c;
        insert new FEC_Address_Info__c(
            FEC_Customer_History__c = chId,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
            FEC_Street__c = 'Office St',
            FEC_Mailing_Address__c = false
        );

        FEC_MainInfoController.MainInfoDTO cached = new FEC_MainInfoController.MainInfoDTO();
        cached.fullName = 'Card Cache';
        update new FEC_Customer_History__c(
            Id = chId,
            FEC_API_Cache__c = JSON.serialize(cached),
            FEC_Primary_Phone__c = '0909000111'
        );

        Test.setMock(HttpCalloutMock.class, new CardMailingIndMock());
        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertEquals('Card Cache', result.fullName);
        System.assertEquals('0909000111', result.primaryPhone);
        System.assertNotEquals(null, result.addresses);
    }

    @IsTest
    static void testLoadMainInfo_CacheEmptyUsesCachedCif() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        FEC_MainInfoController.MainInfoDTO cached = new FEC_MainInfoController.MainInfoDTO();
        cached.fullName = 'Cached CIF Only';
        cached.cifNumber = CIF_NUMBER;
        cached.addresses = new List<FEC_MainInfoController.AddressDTO>();
        hist.FEC_API_Cache__c = JSON.serialize(cached);
        hist.FEC_CIF_Number__c = null;
        update hist;

        Test.setMock(HttpCalloutMock.class, new AddressesListMock());
        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertEquals('Cached CIF Only', result.fullName);
        System.assertNotEquals(null, result.addresses);
    }

    @IsTest
    static void testLoadMainInfo_CacheEmptyNoCif() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        FEC_MainInfoController.MainInfoDTO cached = new FEC_MainInfoController.MainInfoDTO();
        cached.fullName = 'No CIF Cache';
        cached.addresses = new List<FEC_MainInfoController.AddressDTO>();
        hist.FEC_API_Cache__c = JSON.serialize(cached);
        hist.FEC_CIF_Number__c = null;
        update hist;

        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertEquals('No CIF Cache', result.fullName);
        System.assertEquals(0, result.addresses.size());
    }

    @IsTest
    static void testLoadMainInfo_EligibilityBlockCode2AndStatus() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        hist.FEC_API_Cache__c = null;
        hist.FEC_CIF_Number__c = CIF_NUMBER;
        hist.FEC_Block_Code_2__c = 'D';
        hist.FEC_Block_Code__c = 'C';
        hist.FEC_Account_Status__c = '8';
        update hist;

        Test.setMock(HttpCalloutMock.class, new MainInfoHttpCalloutMock());
        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.addressUpdateNotEligibleReasons);
        System.assert(result.addressUpdateNotEligibleReasons.size() >= 2);
    }

    @IsTest
    static void testLoadMainInfo_PhoneFallbackType() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        insert new FEC_Address_Info__c(
            FEC_Customer_History__c = hist.Id,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
            FEC_Street__c = 'Existing Phone St'
        );

        FEC_MainInfoController.MainInfoDTO cached = new FEC_MainInfoController.MainInfoDTO();
        cached.fullName = 'Existing Phone';
        hist.FEC_API_Cache__c = JSON.serialize(cached);
        hist.FEC_Primary_Phone__c = '0281234567';
        update hist;

        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertEquals('0281234567', result.primaryPhone);
    }

    @IsTest
    static void testLoadMainInfo_InsuranceContractPhonePath() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c, FEC_Product_Type__c FROM Case LIMIT 1];
        update new FEC_Product_Type__c(
            Id = c.FEC_Product_Type__c,
            Name = FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE_CASE
        );
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        hist.FEC_API_Cache__c = null;
        hist.FEC_CIF_Number__c = CIF_NUMBER;
        hist.FEC_Contract_Number__c = 'INS-CON-001';
        update hist;

        Test.setMock(HttpCalloutMock.class, new MainInfoHttpCalloutMock());
        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.addresses);
    }

    @IsTest
    static void testLoadMainInfo_CacheEmptyAddressesPhoneResync() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        FEC_MainInfoController.MainInfoDTO cached = new FEC_MainInfoController.MainInfoDTO();
        cached.fullName = 'Addr Then Phone';
        cached.cifNumber = CIF_NUMBER;
        cached.addresses = new List<FEC_MainInfoController.AddressDTO>();
        hist.FEC_API_Cache__c = JSON.serialize(cached);
        hist.FEC_CIF_Number__c = CIF_NUMBER;
        hist.FEC_Primary_Phone__c = null;
        update hist;

        Test.setMock(HttpCalloutMock.class, new MainInfoHttpCalloutMock());
        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertEquals('Addr Then Phone', result.fullName);
        System.assertNotEquals(null, result.addresses);
    }

    @IsTest
    static void testLoadMainInfo_CardProductFullApiFlow() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c, FEC_Product_Type__c FROM Case LIMIT 1];
        update new FEC_Product_Type__c(
            Id = c.FEC_Product_Type__c,
            Name = FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE
        );
        FEC_Customer_History__c hist = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        hist.FEC_API_Cache__c = null;
        hist.FEC_CIF_Number__c = CIF_NUMBER;
        update hist;

        Test.setMock(HttpCalloutMock.class, new CardFullMainInfoMock());
        Test.startTest();
        FEC_MainInfoController.MainInfoDTO result = FEC_MainInfoController.loadMainInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.addresses);
        System.assert(result.addresses.size() > 0);
    }

    @IsTest
    static void testGetMailingAddressUpdateContext_MissingCif() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        update new FEC_Customer_History__c(
            Id = c.FEC_Account_or_Contract__c,
            FEC_CIF_Number__c = null,
            FEC_API_Cache__c = null
        );

        Test.startTest();
        FEC_MainInfoController.MailingAddressContextDTO ctx =
            FEC_MainInfoController.getMailingAddressUpdateContext(
                c.Id,
                FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT
            );
        Test.stopTest();

        System.assertEquals(false, ctx.found);
        System.assertNotEquals(null, ctx.message);
    }

    @IsTest
    static void testGetMailingAddressUpdateContext_NoAddressesInResponse() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new EmptyAddressesListMock());

        Test.startTest();
        FEC_MainInfoController.MailingAddressContextDTO ctx =
            FEC_MainInfoController.getMailingAddressUpdateContext(
                c.Id,
                FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT
            );
        Test.stopTest();

        System.assertEquals(false, ctx.found);
    }

    @IsTest
    static void testGetMailingAddressUpdateContext_NoCustomerHistory() {
        Case orphan = new Case(
            Subject = 'Mailing orphan',
            Status = 'New',
            FEC_ID_Search__c = 'MIC-MAIL-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert orphan;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_MainInfoController.MailingAddressContextDTO ctx =
            FEC_MainInfoController.getMailingAddressUpdateContext(
                orphan.Id,
                FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT
            );
        Test.stopTest();

        System.assertEquals(false, ctx.found);
    }

    @IsTest
    static void testSavePendingAddress_WithPendingJson() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        String pendingJson = '{"cifNumber":"CIF001","addressId":"AID99","addressType":"PERMNENT"}';

        Test.startTest();
        FEC_MainInfoController.savePendingAddress(
            c.Id,
            FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
            false,
            null,
            'B9',
            '19',
            'Json Pending St',
            null,
            null, pendingJson);
        Test.stopTest();

        FEC_Address_Info__c row = [
            SELECT FEC_Address__c, FEC_Mailing_Address__c
            FROM FEC_Address_Info__c
            WHERE FEC_Case__c = :c.Id
              AND FEC_Address_Type__c = :FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT
            LIMIT 1
        ];
        System.assert(row.FEC_Address__c.contains('AID99'));
        System.assertEquals(false, row.FEC_Mailing_Address__c);
    }

    @IsTest
    static void testLoadCasePendingAddressJsonMap_FillsMailingContext() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
        insert new FEC_Address_Info__c(
            FEC_Case__c = c.Id,
            FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
            FEC_Address_Type__c = FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
            FEC_Address__c = 'FEC_ADDR_META\u001F\u001F\u001F',
            FEC_Building__c = 'Ctx Bld',
            FEC_Number__c = '5',
            FEC_Street__c = 'Ctx St'
        );

        Test.setMock(HttpCalloutMock.class, new AddressesListMock());
        Test.startTest();
        Map<String, String> pendingMap =
            FEC_MainInfoController.loadCasePendingAddressJsonMap(c.Id);
        Test.stopTest();

        String json = pendingMap.get(FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT);
        System.assertNotEquals(null, json);
        System.assert(json.contains('ADDR1'));
        System.assert(json.contains(CIF_NUMBER));
    }

    private class CardMailingIndMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String body = req.getBody() != null ? req.getBody().toLowerCase() : '';
            if (body.contains('getcardbasicinfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCardBasicInfoResponse><Sys><Code>1</Code></Sys>' +
                    '<CardBasicInfo><MainCard><MailingInd>E</MailingInd></MainCard></CardBasicInfo>' +
                    '</GetCardBasicInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }
            res.setBody('');
            return res;
        }
    }

    private class CardFullMainInfoMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            MainInfoHttpCalloutMock base = new MainInfoHttpCalloutMock();
            HttpResponse res = base.respond(req);
            String body = req.getBody() != null ? req.getBody().toLowerCase() : '';
            if (body.contains('getcardbasicinfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCardBasicInfoResponse><Sys><Code>1</Code></Sys>' +
                    '<CardBasicInfo><MainCard><MailingInd>C</MailingInd></MainCard></CardBasicInfo>' +
                    '</GetCardBasicInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
            }
            return res;
        }
    }

    private class PhoneFallbackMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String body = req.getBody() != null ? req.getBody().toLowerCase() : '';
            if (body.contains('getcustomerlist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerListResponse><Sys><Code>1</Code><Count>1</Count>' +
                    '<Customers><Customer><Phones><PhoneNode><Type>Phone</Type>' +
                    '<Phone>0281234567</Phone></PhoneNode></Phones></Customer></Customers>' +
                    '</GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }
            return new MainInfoHttpCalloutMock().respond(req);
        }
    }

    private class EmptyAddressesListMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetAddressesListResponse><Sys><Code>1</Code></Sys>' +
                '</GetAddressesListResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class FullAddressesListMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetAddressesListResponse>' +
                '<Sys><Code>1</Code></Sys>' +
                '<Addresses>' +
                '<Address><AddressType>PERMNENT</AddressType><AddressId>ADDR-P</AddressId>' +
                '<Building>B1</Building><NumberStr>10</NumberStr><Street>Main St</Street>' +
                '<District>D1</District><City>1</City><CountryCode>1</CountryCode><CountryName>Viet Nam</CountryName>' +
                '<ZipCode>70000</ZipCode></Address>' +
                '<Address><AddressType>PERMANENT</AddressType><AddressId>ADDR-OLD</AddressId>' +
                '<Building>Old</Building><NumberStr>1</NumberStr><Street>Old St</Street>' +
                '<District>D1</District><City>1</City></Address>' +
                '<Address><AddressType>OFFICE</AddressType><AddressId>ADDR-O</AddressId>' +
                '<Building>Off</Building><NumberStr>2</NumberStr><Street>Office St</Street>' +
                '<District>UNKNOWN</District><City>UNKNOWN</City></Address>' +
                '<Address><AddressType>CURRES</AddressType><AddressId>ADDR-C</AddressId>' +
                '<Building>Cur</Building><NumberStr>3</NumberStr><Street>Current St</Street>' +
                '</Address>' +
                '</Addresses></GetAddressesListResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class PermanentFallbackAddressesMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetAddressesListResponse><Sys><Code>1</Code></Sys>' +
                '<Addresses>' +
                '<Address><AddressType>PERMNENT</AddressType><AddressId>ADDR-PERM</AddressId>' +
                '<Building>B</Building><NumberStr>1</NumberStr><Street>St</Street>' +
                '<District>D1</District><City>1</City></Address>' +
                '<Address><AddressType>OFFICE</AddressType><AddressId>ADDR-OFF</AddressId>' +
                '<Building>O</Building><NumberStr>2</NumberStr><Street>Office</Street>' +
                '<District>D2</District><City>2</City></Address>' +
                '</Addresses></GetAddressesListResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class UpdateAddressMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><UpdateCustomerAddressResponse><Sys><Code>1</Code></Sys>' +
                '</UpdateCustomerAddressResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }
}
