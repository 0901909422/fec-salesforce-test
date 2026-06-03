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
            FEC_CIF_Number__c = 'CIF123'
        );
        insert ch;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = ch.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
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
        Test.setMock(HttpCalloutMock.class, new SoapMock());

        Test.startTest();
        // Test luồng updateValue cho FullName
        FEC_UpdateCustomerBasicInfo.UpdateResult res = FEC_UpdateCustomerBasicInfo.updateValue(c.Id, FEC_UpdateCustomerBasicInfo.FULLNAME_UPDATE);
        Test.stopTest();

        System.assertNotEquals(null, res);
        // Kiểm tra Case đã được cập nhật action count
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