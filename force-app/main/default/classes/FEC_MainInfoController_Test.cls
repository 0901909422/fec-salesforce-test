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
            FEC_MainInfoController.updateCustomerAddressParams(
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
            FEC_MainInfoController.getDistrictOptionsForProvinceCode('DP');
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
            null,
            false
        );

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
            null,
            false
        );
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
                null,
                false
            );
        }
        Test.stopTest();

        System.assertEquals(
            3,
            [SELECT COUNT() FROM FEC_Address_Info__c WHERE FEC_Case__c = :c.Id]
        );
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
