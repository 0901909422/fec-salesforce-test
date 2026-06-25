@IsTest
private class FEC_UpdateCustomerBasicInfo_Test {

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

        // Tạo Case trước, sau đó tạo Customer History có FEC_Case__c
        Case c = new Case(
            Subject = 'Test Update Basic Info',
            FEC_Updated_Info_First_Name__c = 'Toan',
            FEC_Updated_Info_Last_Name__c = 'Nguyen',
            FEC_Is_Test_API__c = false
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_CIF_Number__c = 'CIF123',
            FEC_First_Name__c = 'Toan',
            FEC_Middle_Name__c = '-',
            FEC_Last_Name__c = 'Nguyen',
            FEC_Customer_Name__c = 'Nguyen - Toan',
            FEC_Short_Name__c = 'NT',
            FEC_Title__c = 'Mr',
            FEC_Date_of_Birth__c = Date.newInstance(1990, 1, 15),
            FEC_Gender__c = 'M'
        );
        insert ch;

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'Full Name Update Process',
            FEC_Code__c = FEC_UpdateCustomerBasicInfo.FULLNAME_UPDATE,
            FEC_Active__c = true
        );
        insert bp;

        FEC_Actual_Nature_of_Case__c actualNoc = new FEC_Actual_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id
        );
        insert actualNoc;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = ch.Id,
                FEC_Actual_Nature_of_Case__c = actualNoc.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private class SoapMockCapture implements HttpCalloutMock {
        public String requestBody;

        public HttpResponse respond(HttpRequest req) {
            Dom.Document doc = req.getBodyDocument();
            requestBody = doc != null ? doc.toXmlString() : req.getBody();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                        '<soapenv:Body>' +
                        '<cif:UpdateCustomerBasicInfoResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
                        '<Sys><TransID>T123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
                        '</cif:UpdateCustomerBasicInfoResponse>' +
                        '</soapenv:Body>' +
                        '</soapenv:Envelope>');
            return res;
        }
    }

    // Mock cho SOAP Callout
    private class SoapMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                        '<soapenv:Body>' +
                        '<cif:UpdateCustomerBasicInfoResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
                        '<Sys><TransID>T123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
                        '</cif:UpdateCustomerBasicInfoResponse>' +
                        '</soapenv:Body>' +
                        '</soapenv:Envelope>');
            return res;
        }
    }

    @IsTest
    static void testUpdateCustomerBasicInfo_Success() {
        FEC_UpdateCustomerBasicInfo.CustomerBasicInfo info = new FEC_UpdateCustomerBasicInfo.CustomerBasicInfo();
        info.cifNumber = 'CIF123';
        info.fullName = 'Nguyen Toan';

        Test.setMock(HttpCalloutMock.class, new SoapMock());

        Test.startTest();
        FEC_UpdateCustomerBasicInfo.UpdateResult res = FEC_UpdateCustomerBasicInfo.updateCustomerBasicInfo(info);
        Test.stopTest();

        System.assertEquals(true, res.success, 'API phải trả về thành công.');
        System.assertEquals('1', res.code);
    }

    @IsTest
    static void testUpdateValue_FullNameUpdate() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        SoapMockCapture captureMock = new SoapMockCapture();
        Test.setMock(HttpCalloutMock.class, captureMock);

        Test.startTest();
        FEC_UpdateCustomerBasicInfo.UpdateResult res = FEC_UpdateCustomerBasicInfo.updateValue(c.Id, FEC_UpdateCustomerBasicInfo.FULLNAME_UPDATE);
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assert(captureMock.requestBody.contains('<ShortName>NT</ShortName>'));
        System.assert(captureMock.requestBody.contains('<Title>Mr</Title>'));
        System.assert(captureMock.requestBody.contains('<Birthday>1990-01-15</Birthday>'));
        System.assert(captureMock.requestBody.contains('<Gender>M</Gender>'));
        Case updatedCase = [SELECT FEC_Process_Action_Count__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(-1, updatedCase.FEC_Process_Action_Count__c, 'Count phải reset về -1 khi thành công.');
    }

    @IsTest
    static void testValidation_GenderError() {
        FEC_UpdateCustomerBasicInfo.CustomerBasicInfo info = new FEC_UpdateCustomerBasicInfo.CustomerBasicInfo();
        info.cifNumber = 'CIF123';
        info.gender = 'INVALID_GENDER'; // Picklist không tồn tại

        Test.startTest();
        try {
            FEC_UpdateCustomerBasicInfo.updateCustomerBasicInfo(info);
            System.assert(false, 'Phải ném Exception vì Gender không hợp lệ.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Error message không được null.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testParseResponse_MalformedXml() {
        // Test parse response bị lỗi hoặc thiếu node
        String badXml = '<soapenv:Envelope></soapenv:Envelope>';
        
        Test.startTest();
        FEC_UpdateCustomerBasicInfo.UpdateResult res = FEC_UpdateCustomerBasicInfo.parseResponse(badXml, 200);
        Test.stopTest();
        
        System.assertEquals(false, res.success);
    }

    @IsTest
    static void testUpdateValue_DobUpdate() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Business_Process__c dobBp = new FEC_Business_Process__c(
            Name = 'Date of Birth Update Process',
            FEC_Code__c = FEC_UpdateCustomerBasicInfo.DOB_UPDATE,
            FEC_Active__c = true
        );
        insert dobBp;

        FEC_Actual_Nature_of_Case__c actualNoc = new FEC_Actual_Nature_of_Case__c(
            FEC_Business_Process__c = dobBp.Id
        );
        insert actualNoc;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Actual_Nature_of_Case__c = actualNoc.Id,
                FEC_Updated_Info_Date_of_Birth__c = Date.newInstance(1985, 6, 20)
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        SoapMockCapture captureMock = new SoapMockCapture();
        Test.setMock(HttpCalloutMock.class, captureMock);

        Test.startTest();
        FEC_UpdateCustomerBasicInfo.UpdateResult res = FEC_UpdateCustomerBasicInfo.updateValue(
            c.Id,
            FEC_UpdateCustomerBasicInfo.DOB_UPDATE
        );
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assert(captureMock.requestBody.contains('<CIFNumber>CIF123</CIFNumber>'));
        System.assert(captureMock.requestBody.contains('<FirstName>Toan</FirstName>'));
        System.assert(captureMock.requestBody.contains('<MiddleName>-</MiddleName>'));
        System.assert(captureMock.requestBody.contains('<LastName>Nguyen</LastName>'));
        System.assert(captureMock.requestBody.contains('<FullName>Nguyen - Toan</FullName>'));
        System.assert(captureMock.requestBody.contains('<ShortName>NT</ShortName>'));
        System.assert(captureMock.requestBody.contains('<Title>Mr</Title>'));
        System.assert(captureMock.requestBody.contains('<Birthday>1985-06-20</Birthday>'));
        System.assert(captureMock.requestBody.contains('<Gender>M</Gender>'));
        System.assert(captureMock.requestBody.contains('<RequestorID>PEGA_CSM</RequestorID>'));
    }

    @IsTest
    static void testUpdateValue_DobUpdate_InvalidBusinessProcess() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        try {
            FEC_UpdateCustomerBasicInfo.updateValue(
                c.Id,
                FEC_UpdateCustomerBasicInfo.DOB_UPDATE
            );
            System.assert(false, 'Phải ném Exception vì Business Process không phải Date of Birth Update.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Business Process is invalid.'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpdateValue_GenderUpdate() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Business_Process__c genderBp = new FEC_Business_Process__c(
            Name = 'Gender Update Process',
            FEC_Code__c = FEC_UpdateCustomerBasicInfo.GENDER_UPDATE,
            FEC_Active__c = true
        );
        insert genderBp;

        FEC_Actual_Nature_of_Case__c actualNoc = new FEC_Actual_Nature_of_Case__c(
            FEC_Business_Process__c = genderBp.Id
        );
        insert actualNoc;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Actual_Nature_of_Case__c = actualNoc.Id,
                FEC_Updated_Info_Gender__c = 'F'
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        SoapMockCapture captureMock = new SoapMockCapture();
        Test.setMock(HttpCalloutMock.class, captureMock);

        Test.startTest();
        FEC_UpdateCustomerBasicInfo.UpdateResult res = FEC_UpdateCustomerBasicInfo.updateValue(
            c.Id,
            FEC_UpdateCustomerBasicInfo.GENDER_UPDATE
        );
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assert(captureMock.requestBody.contains('<CIFNumber>CIF123</CIFNumber>'));
        System.assert(captureMock.requestBody.contains('<FirstName>Toan</FirstName>'));
        System.assert(captureMock.requestBody.contains('<MiddleName>-</MiddleName>'));
        System.assert(captureMock.requestBody.contains('<LastName>Nguyen</LastName>'));
        System.assert(captureMock.requestBody.contains('<FullName>Nguyen - Toan</FullName>'));
        System.assert(captureMock.requestBody.contains('<ShortName>NT</ShortName>'));
        System.assert(captureMock.requestBody.contains('<Title>Mr</Title>'));
        System.assert(captureMock.requestBody.contains('<Birthday>1990-01-15</Birthday>'));
        System.assert(captureMock.requestBody.contains('<Gender>F</Gender>'));
        System.assert(captureMock.requestBody.contains('<RequestorID>PEGA_CSM</RequestorID>'));
    }

    @IsTest
    static void testUpdateValue_GenderUpdate_InvalidBusinessProcess() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        try {
            FEC_UpdateCustomerBasicInfo.updateValue(
                c.Id,
                FEC_UpdateCustomerBasicInfo.GENDER_UPDATE
            );
            System.assert(false, 'Phải ném Exception vì Business Process không phải Gender Update.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Business Process is invalid.'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpdateValue_FullNameUpdate_InvalidBusinessProcess() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Business_Process__c phoneBp = new FEC_Business_Process__c(
            Name = 'Phone Update Process',
            FEC_Code__c = FEC_UpdateCustomerContact.PHONE_UPDATE,
            FEC_Active__c = true
        );
        insert phoneBp;

        FEC_Actual_Nature_of_Case__c actualNoc = new FEC_Actual_Nature_of_Case__c(
            FEC_Business_Process__c = phoneBp.Id
        );
        insert actualNoc;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Actual_Nature_of_Case__c = actualNoc.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        try {
            FEC_UpdateCustomerBasicInfo.updateValue(
                c.Id,
                FEC_UpdateCustomerBasicInfo.FULLNAME_UPDATE
            );
            System.assert(false, 'Phải ném Exception vì Business Process không phải Full Name Update.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Business Process is invalid.'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testBuildUpdatedFullName() {
        System.assertEquals(
            'Nguyen Van Toan',
            FEC_UpdateCustomerBasicInfo.buildUpdatedFullName('Nguyen', 'Van', 'Toan')
        );
        System.assertEquals(
            'Nguyen Toan',
            FEC_UpdateCustomerBasicInfo.buildUpdatedFullName('Nguyen', null, 'Toan')
        );
        System.assertEquals(
            'Van',
            FEC_UpdateCustomerBasicInfo.buildUpdatedFullName(null, 'Van', '')
        );
        System.assertEquals(
            '',
            FEC_UpdateCustomerBasicInfo.buildUpdatedFullName(null, '', null)
        );
    }

    @IsTest
    static void testCheckLength() {
        // Test kiểm tra độ dài field (255 chars)
        FEC_UpdateCustomerBasicInfo.CustomerBasicInfo info = new FEC_UpdateCustomerBasicInfo.CustomerBasicInfo();
        info.cifNumber = 'A'.repeat(256); // Quá dài

        Test.startTest();
        try {
            FEC_UpdateCustomerBasicInfo.updateCustomerBasicInfo(info);
            System.assert(false, 'Phải ném Exception vì CIFNumber vượt quá 255 ký tự.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Error message không được null.');
        }
        Test.stopTest();
    }
}