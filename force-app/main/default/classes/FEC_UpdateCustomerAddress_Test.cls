@IsTest
private class FEC_UpdateCustomerAddress_Test {

    private static User adminUser() {
        List<User> rows = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return rows.isEmpty() ? new User(Id = UserInfo.getUserId()) : rows[0];
    }

    private static void ensureApiSettings() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Endpoint__c = 'https://mock-api.fecredit.com.vn';
        apiSetting.FEC_Call_Mock__c = false;
        apiSetting.FEC_Enviroment__c = 'Production';
        upsert apiSetting;
    }

    @TestSetup
    static void setupData() {
        ensureApiSettings();

        // Setup Country và Province để test logic remap
        FEC_Country__c country1 = new FEC_Country__c(Name = 'Vietnam Legacy', FEC_Code__c = '1');
        FEC_Country__c country2 = new FEC_Country__c(Name = 'Vietnam API', FEC_Code__c = '2');
        insert new List<FEC_Country__c>{country1, country2};

        FEC_Province__c p1 = new FEC_Province__c(Name = 'Hanoi', FEC_Name_VN__c = 'Hanoi', FEC_Code__c = 'HN1', FEC_Country__c = country1.Id);
        FEC_Province__c p2 = new FEC_Province__c(Name = 'Hanoi', FEC_Name_VN__c = 'Hanoi', FEC_Code__c = 'HN2', FEC_Country__c = country2.Id);
        insert new List<FEC_Province__c>{p1, p2};

        // District (dùng cho updateValue)
        FEC_District__c d1 = new FEC_District__c(Name = 'District Legacy', FEC_Code__c = 'D1', FEC_Country__c = country1.Id, FEC_Province__c = p1.Id);
        FEC_District__c d2 = new FEC_District__c(Name = 'District API', FEC_Code__c = 'D2', FEC_Country__c = country2.Id, FEC_Province__c = p2.Id);
        insert new List<FEC_District__c>{d1, d2};

        // Case + Customer History (dùng cho updateValue)
        Case c = new Case(
            Subject = 'Test Update Address Case',
            Status = 'New'
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_CIF_Number__c = 'CIF001'
        );
        insert ch;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Account_or_Contract__c = ch.Id);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    // Mock API Response
    private class SoapMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            // Lưu ý: parseResponse() đọc Sys với namespace = null, nên response XML
            // không được dùng default namespace cho Sys (dùng prefix cho response node).
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                '<cif:UpdateCustomerAddressResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
                '<Sys><TransID>T123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
                '</cif:UpdateCustomerAddressResponse>' +
                '</soapenv:Body>' +
                '</soapenv:Envelope>'
            );
            return res;
        }
    }

    private class SoapNoTransIdMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                '<cif:UpdateCustomerAddressResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
                '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                '</cif:UpdateCustomerAddressResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class ThrowingCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated callout failure');
        }
    }

    private class SoapFailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                '<cif:UpdateCustomerAddressResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
                '<Sys><TransID>T999</TransID><Code>0</Code><Description>Failed</Description></Sys>' +
                '</cif:UpdateCustomerAddressResponse>' +
                '</soapenv:Body>' +
                '</soapenv:Envelope>'
            );
            return res;
        }
    }

    @IsTest
    static void testUpdateCustomerAddress_Success() {
        FEC_UpdateCustomerAddress.CustomerAddressInfo info = new FEC_UpdateCustomerAddress.CustomerAddressInfo();
        info.cifNumber = 'CIF001';
        info.addressId = 'ADD001';
        info.addressType = 'Home';
        info.city = 'HN1'; // Sẽ bị remap sang HN2

        Test.setMock(HttpCalloutMock.class, new SoapMock());
        
        Test.startTest();
        FEC_UpdateCustomerAddress.UpdateResult res = FEC_UpdateCustomerAddress.updateCustomerAddress(info);
        Test.stopTest();

        System.assertEquals(true, res.success, 'API phải trả về thành công.');
        System.assertEquals('1', res.code);
    }

    @IsTest
    static void testUpdateCustomerAddressParams_Success() {
        Test.setMock(HttpCalloutMock.class, new SoapMock());
        System.runAs(adminUser()) {
            Test.startTest();
            FEC_UpdateCustomerAddress.UpdateResult res = FEC_UpdateCustomerAddress.updateCustomerAddressParams(
                null,
                null,
                'CIF001',
                'ADD001',
                'Home',
                '1',
                'Building',
                'Street',
                'D1',
                'HN1',
                '',
                '',
                '',
                'Yes',
                'No',
                'Yes',
                'No'
            );
            Test.stopTest();
            System.assertEquals(true, res.success);
            System.assertEquals('1', res.code);
        }
    }

    @IsTest
    static void testRemapProvinceCityCode_BlankInput() {
        System.assertEquals(null, FEC_UpdateCustomerAddress.remapProvinceCityCodeForCountryTwo(null));
        System.assertEquals('', FEC_UpdateCustomerAddress.remapProvinceCityCodeForCountryTwo(''));
    }

    @IsTest
    static void testRemapProvinceCityCode() {
        // Test logic remap từ code bộ 1 sang bộ 2
        String newCode = FEC_UpdateCustomerAddress.remapProvinceCityCodeForCountryTwo('HN1');
        System.assertEquals('HN2', newCode, 'Mã tỉnh phải được remap từ HN1 sang HN2.');

        // Test trường hợp không cần remap (truyền thẳng mã bộ 2)
        String sameCode = FEC_UpdateCustomerAddress.remapProvinceCityCodeForCountryTwo('HN2');
        System.assertEquals('HN2', sameCode);
    }

    @IsTest
    static void testRemapProvinceCityCode_NoSourceOrAmbiguousTarget() {
        // No source row
        System.assertEquals('UNKNOWN', FEC_UpdateCustomerAddress.remapProvinceCityCodeForCountryTwo('UNKNOWN'));

        // Ambiguous target (2 rows bộ 2 cùng tên) => giữ nguyên mã bộ 1
        FEC_Country__c country2 = [SELECT Id FROM FEC_Country__c WHERE FEC_Code__c = '2' LIMIT 1];
        insert new FEC_Province__c(
            Name = 'Hanoi',
            FEC_Name_VN__c = 'Hanoi',
            FEC_Code__c = 'HN2_DUP',
            FEC_Country__c = country2.Id
        );
        System.assertEquals('HN1', FEC_UpdateCustomerAddress.remapProvinceCityCodeForCountryTwo('HN1'));
    }

    @IsTest
    static void testValidationErrors() {
        Boolean nullInfoThrown = false;
        Boolean missingFieldThrown = false;

        Test.startTest();
        try {
            FEC_UpdateCustomerAddress.updateCustomerAddress(null);
        } catch (AuraHandledException e) {
            nullInfoThrown = true;
        }

        FEC_UpdateCustomerAddress.CustomerAddressInfo incomplete = new FEC_UpdateCustomerAddress.CustomerAddressInfo();
        incomplete.cifNumber = 'CIF001';
        try {
            FEC_UpdateCustomerAddress.updateCustomerAddress(incomplete);
        } catch (AuraHandledException e) {
            missingFieldThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, nullInfoThrown);
        System.assertEquals(true, missingFieldThrown);
    }

    @IsTest
    static void testUpdateValue_BlankAndInvalidCaseId() {
        Boolean blankCaseThrown = false;
        Boolean invalidCaseThrown = false;

        Test.startTest();
        try {
            FEC_UpdateCustomerAddress.updateValue('', new Map<String, String>(), 'Test');
        } catch (FEC_APIServiceException e) {
            blankCaseThrown = true;
        }
        try {
            FEC_UpdateCustomerAddress.updateValue('500000000000001AAA', new Map<String, String>(), 'Test');
        } catch (FEC_APIServiceException e) {
            invalidCaseThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, blankCaseThrown);
        System.assertEquals(true, invalidCaseThrown);
    }

    @IsTest
    static void testUpdateCustomerAddress_CalloutException() {
        FEC_UpdateCustomerAddress.CustomerAddressInfo info = new FEC_UpdateCustomerAddress.CustomerAddressInfo();
        info.cifNumber = 'CIF001';
        info.addressId = 'ADD001';
        info.addressType = 'Home';

        Test.setMock(HttpCalloutMock.class, new ThrowingCalloutMock());
        Test.startTest();
        FEC_UpdateCustomerAddress.UpdateResult res = FEC_UpdateCustomerAddress.updateCustomerAddress(info);
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertNotEquals(null, res.errorMessage);
        System.assertNotEquals(null, FEC_UpdateCustomerAddress.responseLog);
    }

    @IsTest
    static void testUpdateCustomerAddress_FillsMissingResultFields() {
        FEC_UpdateCustomerAddress.CustomerAddressInfo info = new FEC_UpdateCustomerAddress.CustomerAddressInfo();
        info.cifNumber = 'CIF001';
        info.addressId = 'ADD001';
        info.addressType = 'Home';
        info.city = 'HN2';

        Test.setMock(HttpCalloutMock.class, new SoapNoTransIdMock());
        Test.startTest();
        FEC_UpdateCustomerAddress.UpdateResult res = FEC_UpdateCustomerAddress.updateCustomerAddress(info);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertNotEquals(null, res.transId);
        System.assertEquals(200, res.httpStatus);
        System.assertNotEquals(null, res.rawResponse);
    }

    @IsTest
    static void testUpdateCustomerAddressParams_InvalidCaseIdSkipsMerge() {
        Test.setMock(HttpCalloutMock.class, new SoapMock());
        Test.startTest();
        FEC_UpdateCustomerAddress.UpdateResult res =
            FEC_UpdateCustomerAddress.updateCustomerAddressParams(
                'not-a-valid-case-id',
                FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
                'CIF001',
                'ADD001',
                'Home',
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null
            );
        Test.stopTest();
        System.assertEquals(true, res.success);
    }

    @IsTest
    static void testParseResponse_Error() {
        // Test parse XML lỗi hoặc thiếu node
        String xml = '<soapenv:Envelope><soapenv:Body><Error>System Failed</Error></soapenv:Body></soapenv:Envelope>';
        
        Test.startTest();
        FEC_UpdateCustomerAddress.UpdateResult res = FEC_UpdateCustomerAddress.parseResponse(xml, 200);
        Test.stopTest();
        
        System.assertEquals(false, res.success);
    }

    @IsTest
    static void testParseResponse_Code4AndInvalidXml() {
        String code4Xml =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<cif:UpdateCustomerAddressResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
            '<Sys><TransID>T4</TransID><Code>4</Code><Description>Accepted</Description></Sys>' +
            '</cif:UpdateCustomerAddressResponse></soapenv:Body></soapenv:Envelope>';

        Test.startTest();
        FEC_UpdateCustomerAddress.UpdateResult code4Res = FEC_UpdateCustomerAddress.parseResponse(code4Xml, 200);
        FEC_UpdateCustomerAddress.UpdateResult emptyBodyRes = FEC_UpdateCustomerAddress.parseResponse(
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body></soapenv:Body></soapenv:Envelope>',
            200
        );
        Test.stopTest();

        System.assertEquals(true, code4Res.success);
        System.assertEquals('4', code4Res.code);
        System.assertEquals(false, emptyBodyRes.success);
    }

    @IsTest
    static void testParseResponse_NullAndSysNull() {
        Test.startTest();
        FEC_UpdateCustomerAddress.UpdateResult nullRes = FEC_UpdateCustomerAddress.parseResponse(null, 200);
        FEC_UpdateCustomerAddress.UpdateResult sysNullRes = FEC_UpdateCustomerAddress.parseResponse(
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<cif:UpdateCustomerAddressResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
            '</cif:UpdateCustomerAddressResponse>' +
            '</soapenv:Body></soapenv:Envelope>',
            200
        );
        Test.stopTest();

        System.assertEquals(false, nullRes.success);
        System.assertEquals(false, sysNullRes.success);
    }

    @IsTest
    static void testToSingleChar() {
        // Test helper private dùng TestVisible hoặc access thông qua phương thức public
        // Vì toSingleChar là private, gọi updateCustomerAddress sẽ gián tiếp cover nó
        FEC_UpdateCustomerAddress.CustomerAddressInfo info = new FEC_UpdateCustomerAddress.CustomerAddressInfo();
        info.cifNumber = 'C'; info.addressId = 'A'; info.addressType = 'T';
        info.isMailingAddress = 'Yes'; // Sẽ convert sang 'Y'
        
        Test.setMock(HttpCalloutMock.class, new SoapMock());
        Test.startTest();
        FEC_UpdateCustomerAddress.updateCustomerAddress(info);
        Test.stopTest();
        
        // Kiểm tra logAPI hoặc debug log để xác nhận XML chứa Y
    }

    @IsTest
    static void testUpdateValue_NoPendingRows() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Test Update Address Case' LIMIT 1];
        System.runAs(adminUser()) {
            Test.startTest();
            FEC_UpdateCustomerAddress.UpdateResult res =
                FEC_UpdateCustomerAddress.updateValue(String.valueOf(c.Id), new Map<String, String>(), 'TestMethod');
            Test.stopTest();

            System.assertNotEquals(null, res);
            System.assertEquals(false, res.success);
            System.assert(res.actionCount != null, 'actionCount phải được set.');
        }
    }

    @IsTest
    static void testUpdateValue_WithPendingRow_Failure() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case WHERE Subject = 'Test Update Address Case' LIMIT 1];
        FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c WHERE Id = :c.FEC_Account_or_Contract__c LIMIT 1];
        FEC_Country__c country2 = [SELECT Id FROM FEC_Country__c WHERE FEC_Code__c = '2' LIMIT 1];
        FEC_Province__c prov2 = [SELECT Id FROM FEC_Province__c WHERE FEC_Code__c = 'HN2' LIMIT 1];
        FEC_District__c dist2 = [SELECT Id FROM FEC_District__c WHERE FEC_Code__c = 'D2' LIMIT 1];

        // Pending row dạng JSON để tránh gọi unpackPendingAddressApiMeta / merge context.
        String pendingJson =
            '{' +
            '\"cifNumber\":\"CIF001\",' +
            '\"addressId\":\"ADD001\",' +
            '\"addressType\":\"Home\",' +
            '\"number_x\":\"1\",' +
            '\"building\":\"B\",' +
            '\"street\":\"S\",' +
            '\"district\":\"D2\",' +
            '\"city\":\"HN2\"' +
            '}';

        insert new FEC_Address_Info__c(
            Name = 'Pending Current',
            FEC_Customer_History__c = ch.Id,
            FEC_Case__c = c.Id,
            FEC_Address_Type__c = 'Current Address',
            FEC_Country__c = country2.Id,
            FEC_Province__c = prov2.Id,
            FEC_District__c = dist2.Id,
            FEC_Address__c = pendingJson,
            FEC_Mailing_Address__c = false
        );

        Test.setMock(HttpCalloutMock.class, new SoapFailMock());
        System.runAs(adminUser()) {
            Test.startTest();
            FEC_UpdateCustomerAddress.UpdateResult res =
                FEC_UpdateCustomerAddress.updateValue(String.valueOf(c.Id), new Map<String, String>(), 'TestMethod');
            Test.stopTest();

            System.assertNotEquals(null, res);
            System.assertEquals(false, res.success, 'Mock fail phải trả về thất bại.');
            System.assert(res.actionCount != null, 'actionCount phải được set.');
        }
    }

    @IsTest
    static void testUpdateValue_WithPendingRowLegacyMeta() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case WHERE Subject = 'Test Update Address Case' LIMIT 1];
        FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c WHERE Id = :c.FEC_Account_or_Contract__c LIMIT 1];
        FEC_Country__c country2 = [SELECT Id FROM FEC_Country__c WHERE FEC_Code__c = '2' LIMIT 1];
        FEC_Province__c prov2 = [SELECT Id FROM FEC_Province__c WHERE FEC_Code__c = 'HN2' LIMIT 1];
        FEC_District__c dist2 = [SELECT Id FROM FEC_District__c WHERE FEC_Code__c = 'D2' LIMIT 1];

        String legacyMeta = 'FEC_ADDR_META\u001FCIF001\u001FADD001\u001FHome';

        insert new FEC_Address_Info__c(
            Name = 'Pending Office',
            FEC_Customer_History__c = ch.Id,
            FEC_Case__c = c.Id,
            FEC_Address_Type__c = 'Office Address',
            FEC_Country__c = country2.Id,
            FEC_Province__c = prov2.Id,
            FEC_District__c = dist2.Id,
            FEC_Number__c = '99',
            FEC_Building__c = 'Tower',
            FEC_Street__c = 'Main',
            FEC_Address__c = legacyMeta,
            FEC_Mailing_Address__c = false
        );

        Test.setMock(HttpCalloutMock.class, new SoapMock());
        System.runAs(adminUser()) {
            Test.startTest();
            FEC_UpdateCustomerAddress.UpdateResult res =
                FEC_UpdateCustomerAddress.updateValue(String.valueOf(c.Id), new Map<String, String>(), 'LegacyMeta');
            Test.stopTest();

            System.assertEquals(true, res.success);
        }
    }

    @IsTest
    static void testUpdateValue_WithPendingRow_Success() {
        Case c = [SELECT Id, FEC_Account_or_Contract__c FROM Case WHERE Subject = 'Test Update Address Case' LIMIT 1];
        FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c WHERE Id = :c.FEC_Account_or_Contract__c LIMIT 1];
        FEC_Country__c country2 = [SELECT Id FROM FEC_Country__c WHERE FEC_Code__c = '2' LIMIT 1];
        FEC_Province__c prov2 = [SELECT Id FROM FEC_Province__c WHERE FEC_Code__c = 'HN2' LIMIT 1];
        FEC_District__c dist2 = [SELECT Id FROM FEC_District__c WHERE FEC_Code__c = 'D2' LIMIT 1];

        String pendingJson =
            '{' +
            '\"cifNumber\":\"CIF001\",' +
            '\"addressId\":\"ADD001\",' +
            '\"addressType\":\"Home\",' +
            '\"number_x\":\"1\",' +
            '\"building\":\"B\",' +
            '\"street\":\"S\",' +
            '\"district\":\"D2\",' +
            '\"city\":\"HN2\",' +
            '\"isMailingAddress\":\"Y\"' +
            '}';

        insert new FEC_Address_Info__c(
            Name = 'Pending Permanent',
            FEC_Customer_History__c = ch.Id,
            FEC_Case__c = c.Id,
            FEC_Address_Type__c = 'Permanent Address',
            FEC_Country__c = country2.Id,
            FEC_Province__c = prov2.Id,
            FEC_District__c = dist2.Id,
            FEC_Address__c = pendingJson,
            FEC_Mailing_Address__c = true
        );

        Test.setMock(HttpCalloutMock.class, new SoapMock());
        System.runAs(adminUser()) {
            Test.startTest();
            FEC_UpdateCustomerAddress.UpdateResult res =
                FEC_UpdateCustomerAddress.updateValue(String.valueOf(c.Id), new Map<String, String>(), 'TestMethod');
            Test.stopTest();

            System.assertNotEquals(null, res);
            System.assertEquals(true, res.success);
            System.assert(res.actionCount != null);
        }
    }

    @IsTest
    static void testLogApiResponse_ClearsResponseLog() {
        FEC_UpdateCustomerAddress.CustomerAddressInfo info = new FEC_UpdateCustomerAddress.CustomerAddressInfo();
        info.cifNumber = 'CIF001';
        info.addressId = 'ADD001';
        info.addressType = 'Home';
        info.city = 'HN2';

        Test.setMock(HttpCalloutMock.class, new SoapMock());
        Test.startTest();
        FEC_UpdateCustomerAddress.updateCustomerAddress(info);
        Test.stopTest();

        System.assertNotEquals(null, FEC_UpdateCustomerAddress.responseLog);
        FEC_UpdateCustomerAddress.logApiResponse();
        System.assertEquals(null, FEC_UpdateCustomerAddress.responseLog);

        FEC_UpdateCustomerAddress.responseLog = null;
        FEC_UpdateCustomerAddress.logApiResponse();
    }

    @IsTest
    static void testUpdateCustomerAddress_AllOptionalFields() {
        FEC_UpdateCustomerAddress.CustomerAddressInfo info = new FEC_UpdateCustomerAddress.CustomerAddressInfo();
        info.cifNumber = 'CIF001';
        info.addressId = 'ADD001';
        info.addressType = 'Home';
        info.number_x = '1';
        info.building = 'B';
        info.street = 'S';
        info.district = 'D2';
        info.city = 'HN1'; // remap sang HN2
        info.propertyStatus = 'Owned';
        info.years = '1';
        info.months = '2';
        info.isMailingAddress = 'No';
        info.isPrimary = 'Yes';
        info.receiveStatement = '1';
        info.cardDelivery = '0';

        Test.setMock(HttpCalloutMock.class, new SoapMock());
        Test.startTest();
        FEC_UpdateCustomerAddress.UpdateResult res = FEC_UpdateCustomerAddress.updateCustomerAddress(info);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals('1', res.code);
    }
}