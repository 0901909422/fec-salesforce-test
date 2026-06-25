@IsTest
private class FEC_UpdateCustomerContact_Test {

    private static String validChannel() {
        List<FEC_CommonUltils.PicklistOption> opts = FEC_CommonUltils.getPicklistOptions(
            'Case',
            'FEC_Channel__c'
        );
        return (opts != null && !opts.isEmpty()) ? opts[0].value : null;
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

        // 1. Tạo Case trước, sau đó Customer History phải có FEC_Case__c
        String channel = validChannel();
        Case c = new Case(
            Subject = 'Test Update Contact',
            FEC_Channel__c = channel
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
            FEC_Email__c = 'test@example.com',
            FEC_Primary_Phone__c = '0901234567'
        );
        insert ch;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = ch.Id,
                FEC_Original_Info_Phone_Number__c = '0901234567',
                FEC_Updated_Info_Phone_Number__c = '0909876543',
                FEC_Original_Info_Phone_Type__c = 'Mobile',
                FEC_Updated_Info_Phone_Type__c = 'Mobile',
                FEC_Original_Info_Email__c = 'test@example.com',
                FEC_Updated_Info_Email__c = 'updated@example.com'
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        // 2. Tạo Contact List để test hàm getMatchingContactList
        FEC_Contact_List__c contact = new FEC_Contact_List__c(
            FEC_Customer_History__c = ch.Id,
            FEC_Contact_ID__c = 'C001',
            FEC_Channel__c = 'Phone',
            FEC_Communication_Type__c = 'Mobile',
            FEC_Contact_String__c = '0901234567'
        );
        insert contact;
    }

    // Mock cho SOAP Callout
    private class SoapMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                        '<soapenv:Body>' +
                        '<cif:UpdateCustomerContactResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
                        '<Sys><TransID>T123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
                        '</cif:UpdateCustomerContactResponse>' +
                        '</soapenv:Body>' +
                        '</soapenv:Envelope>');
            return res;
        }
    }

    private class SoapCaptureMock implements HttpCalloutMock {
        public String requestBody;

        public HttpResponse respond(HttpRequest req) {
            requestBody = req.getBody();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                        '<soapenv:Body>' +
                        '<cif:UpdateCustomerContactResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
                        '<Sys><TransID>T123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
                        '</cif:UpdateCustomerContactResponse>' +
                        '</soapenv:Body>' +
                        '</soapenv:Envelope>');
            return res;
        }
    }

    @IsTest
    static void testUpdateCustomerContact_Success() {
        FEC_UpdateCustomerContact.CustomerContactRequest req = new FEC_UpdateCustomerContact.CustomerContactRequest();
        req.CIFNumber = 'CIF123';
        req.Channel = validChannel();
        req.CommunicationType = 'Phone';
        req.ContactString = '0901234567';

        Test.setMock(HttpCalloutMock.class, new SoapMock());

        Test.startTest();
        FEC_UpdateCustomerContact.UpdateContactResult res = FEC_UpdateCustomerContact.updateCustomerContact(req);
        Test.stopTest();

        System.assertEquals(true, res.success, 'API phải trả về thành công.');
        System.assertEquals('1', res.code);
    }

    @IsTest
    static void testUpdateValue_PhoneUpdate() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new SoapMock());

        Test.startTest();
        FEC_UpdateCustomerContact.UpdateContactResult res = 
            FEC_UpdateCustomerContact.updateValue(c.Id, FEC_UpdateCustomerContact.PHONE_UPDATE);
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(true, res.success);
    }

    @IsTest
    static void testUpdateValue_EmailUpdate_ThrowsNotSupported() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new SoapMock());

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_UpdateCustomerContact.updateValue(c.Id, FEC_UpdateCustomerContact.EMAIL_UPDATE);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Email Update không được hỗ trợ qua API Mobile.');
    }

    @IsTest
    static void testUpdateValue_InvalidMethod_ThrowsAndIncrementsCount() {
        Case c = [SELECT Id, FEC_Process_Action_Count__c FROM Case LIMIT 1];

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_UpdateCustomerContact.updateValue(c.Id, 'INVALID_METHOD');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw);
        Case after = [SELECT FEC_Process_Action_Count__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(1, after.FEC_Process_Action_Count__c, 'Khi lỗi phải tăng action count.');
    }

    @IsTest
    static void testValidation_Error() {
        // Test thiếu CIFNumber
        FEC_UpdateCustomerContact.CustomerContactRequest req = new FEC_UpdateCustomerContact.CustomerContactRequest();
        
        Test.startTest();
        try {
            FEC_UpdateCustomerContact.updateCustomerContact(req);
            System.assert(false, 'Phải ném ngoại lệ khi thiếu dữ liệu.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Error message không được null.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testParseResponse_NullAndSysNull() {
        Test.startTest();
        FEC_UpdateCustomerContact.UpdateContactResult nullRes =
            FEC_UpdateCustomerContact.parseResponse(null, 200);
        FEC_UpdateCustomerContact.UpdateContactResult sysNullRes =
            FEC_UpdateCustomerContact.parseResponse(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                '<cif:UpdateCustomerContactResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
                '</cif:UpdateCustomerContactResponse>' +
                '</soapenv:Body>' +
                '</soapenv:Envelope>',
                200
            );
        Test.stopTest();

        System.assertEquals(false, nullRes.success);
        System.assertEquals(false, sysNullRes.success);
    }

    @IsTest
    static void testBuildEnvelope_WithOptionalFields() {
        FEC_UpdateCustomerContact.CustomerContactRequest req = new FEC_UpdateCustomerContact.CustomerContactRequest();
        req.CIFNumber = 'CIF123';
        req.Channel = validChannel();
        req.CommunicationType = FEC_ConstantCommon.PHONE;
        req.ContactString = '0901234567';
        req.OfficeExtension = '123';
        req.ReceiveStatement = 'Y';

        Test.startTest();
        String env = FEC_UpdateCustomerContact.buildEnvelope(
            req,
            FEC_UpdateCustomerContact.generateTransId(),
            FEC_UpdateCustomerContact.formatTimestamp()
        );
        Test.stopTest();

        System.assert(env.contains('OfficeExtension'));
        System.assert(env.contains('ReceiveStatement'));
        System.assert(env.contains('UpdateCustomerContact'));
    }

    @IsTest
    static void testValidation_InvalidChannelAndContactString() {
        // channel quá dài
        FEC_UpdateCustomerContact.CustomerContactRequest req1 = new FEC_UpdateCustomerContact.CustomerContactRequest();
        req1.CIFNumber = 'CIF123';
        req1.Channel = 'X'.repeat(256);
        req1.CommunicationType = FEC_ConstantCommon.PHONE;
        req1.ContactString = '0901234567';
        try {
            FEC_UpdateCustomerContact.updateCustomerContact(req1);
            System.assert(false, 'Phải ném exception khi Channel vượt max length.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }

        // invalid phone
        FEC_UpdateCustomerContact.CustomerContactRequest req2 = new FEC_UpdateCustomerContact.CustomerContactRequest();
        req2.CIFNumber = 'CIF123';
        req2.Channel = validChannel();
        req2.CommunicationType = FEC_ConstantCommon.PHONE;
        req2.ContactString = '12';
        try {
            FEC_UpdateCustomerContact.updateCustomerContact(req2);
            System.assert(false, 'Phải ném exception khi ContactString invalid.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }

        // invalid communication type
        FEC_UpdateCustomerContact.CustomerContactRequest req3 = new FEC_UpdateCustomerContact.CustomerContactRequest();
        req3.CIFNumber = 'CIF123';
        req3.Channel = validChannel();
        req3.CommunicationType = 'Fax';
        req3.ContactString = '0901234567';
        try {
            FEC_UpdateCustomerContact.updateCustomerContact(req3);
            System.assert(false, 'Phải ném exception khi CommunicationType invalid.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @IsTest
    static void testLogApiResponse_ClearsResponseLog() {
        FEC_UpdateCustomerContact.CustomerContactRequest req = new FEC_UpdateCustomerContact.CustomerContactRequest();
        req.CIFNumber = 'CIF123';
        req.Channel = validChannel();
        req.CommunicationType = FEC_ConstantCommon.PHONE;
        req.ContactString = '0901234567';
        Test.setMock(HttpCalloutMock.class, new SoapMock());

        Test.startTest();
        FEC_UpdateCustomerContact.updateCustomerContact(req);
        Test.stopTest();

        System.assertNotEquals(null, FEC_UpdateCustomerContact.responseLog);
        FEC_UpdateCustomerContact.logApiResponse();
        System.assertEquals(null, FEC_UpdateCustomerContact.responseLog);
    }

    @IsTest
    static void testGetMatchingContactList_PicksLargestContactIdAmongDuplicates() {
        Case c = [
            SELECT Id, FEC_Account_or_Contract__c,
                   FEC_Original_Info_Phone_Number__c, FEC_Original_Info_Phone_Type__c
            FROM Case
            LIMIT 1
        ];
        FEC_Customer_History__c ch = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];

        insert new List<FEC_Contact_List__c>{
            new FEC_Contact_List__c(
                FEC_Customer_History__c = ch.Id,
                FEC_Contact_ID__c = '4320772567',
                FEC_Channel__c = 'Phone',
                FEC_Communication_Type__c = 'Work Phone',
                FEC_Contact_String__c = '84377021595'
            ),
            new FEC_Contact_List__c(
                FEC_Customer_History__c = ch.Id,
                FEC_Contact_ID__c = '4320772568',
                FEC_Channel__c = 'Phone',
                FEC_Communication_Type__c = 'Mobile',
                FEC_Contact_String__c = '84377021595'
            ),
            new FEC_Contact_List__c(
                FEC_Customer_History__c = ch.Id,
                FEC_Contact_ID__c = '4320772570',
                FEC_Channel__c = 'Phone',
                FEC_Communication_Type__c = 'Mobile',
                FEC_Contact_String__c = '84377021595'
            ),
            new FEC_Contact_List__c(
                FEC_Customer_History__c = ch.Id,
                FEC_Contact_ID__c = '4320772572',
                FEC_Channel__c = 'Phone',
                FEC_Communication_Type__c = 'Mobile',
                FEC_Contact_String__c = '84377021595'
            ),
            new FEC_Contact_List__c(
                FEC_Customer_History__c = ch.Id,
                FEC_Contact_ID__c = '4320772575',
                FEC_Channel__c = 'Phone',
                FEC_Communication_Type__c = 'Work Phone',
                FEC_Contact_String__c = '84377021595'
            )
        };

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Original_Info_Phone_Number__c = '84377021595',
                FEC_Original_Info_Phone_Type__c = 'Mobile'
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        c = [
            SELECT Id, FEC_Account_or_Contract__c,
                   FEC_Original_Info_Phone_Number__c, FEC_Original_Info_Phone_Type__c
            FROM Case
            WHERE Id = :c.Id
        ];

        Test.startTest();
        List<FEC_Contact_List__c> phoneMatch = FEC_UpdateCustomerContact.getMatchingContactList(
            c,
            FEC_UpdateCustomerContact.PHONE_UPDATE
        );
        Test.stopTest();

        System.assertEquals(1, phoneMatch.size(), 'Phải chọn đúng 1 contact khớp.');
        System.assertEquals(
            '4320772572',
            phoneMatch[0].FEC_Contact_ID__c,
            'Phải lấy FEC_Contact_ID__c lớn nhất trong các bản ghi Mobile khớp SĐT.'
        );
        System.assertEquals(
            'Mobile',
            phoneMatch[0].FEC_Communication_Type__c,
            'Phải lấy CommunicationType Mobile.'
        );
        System.assertEquals(
            'Phone',
            phoneMatch[0].FEC_Channel__c,
            'Phải lấy FEC_Channel__c từ bản ghi Mobile đã match.'
        );
    }

    @IsTest
    static void testGetMatchingContactList() {
        Case c = [
            SELECT Id, FEC_Account_or_Contract__c,
                   FEC_Original_Info_Phone_Number__c, FEC_Original_Info_Email__c,
                   FEC_Original_Info_Phone_Type__c
            FROM Case
            LIMIT 1
        ];

        Test.startTest();
        List<FEC_Contact_List__c> phoneMatch = FEC_UpdateCustomerContact.getMatchingContactList(
            c,
            FEC_UpdateCustomerContact.PHONE_UPDATE
        );
        List<FEC_Contact_List__c> emailMatch = FEC_UpdateCustomerContact.getMatchingContactList(
            c,
            FEC_UpdateCustomerContact.EMAIL_UPDATE
        );
        Test.stopTest();

        System.assert(phoneMatch.size() > 0, 'Phải tìm thấy contact Mobile.');
        System.assertEquals(0, emailMatch.size(), 'Email Update không match contact list.');
    }

    @IsTest
    static void testUpdateValue_NonMobilePhoneUpdate_Throws() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Original_Info_Phone_Type__c = 'Work Phone',
                FEC_Updated_Info_Phone_Type__c = 'Work Phone'
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_UpdateCustomerContact.updateValue(c.Id, FEC_UpdateCustomerContact.PHONE_UPDATE);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Work Phone không được gọi API qua luồng Mobile.');
    }

    @IsTest
    static void testUpdateValue_SendsContactListChannelAndCommunicationType() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Contact_List__c contact = [
            SELECT FEC_Channel__c, FEC_Communication_Type__c
            FROM FEC_Contact_List__c
            WHERE FEC_Contact_ID__c = 'C001'
            LIMIT 1
        ];

        SoapCaptureMock captureMock = new SoapCaptureMock();
        Test.setMock(HttpCalloutMock.class, captureMock);

        Test.startTest();
        FEC_UpdateCustomerContact.UpdateContactResult res =
            FEC_UpdateCustomerContact.updateValue(c.Id, FEC_UpdateCustomerContact.PHONE_UPDATE);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assert(
            captureMock.requestBody.contains('<ContactId>C001</ContactId>'),
            'Mobile phải gửi ContactId từ FEC_Contact_List__c.'
        );
        System.assert(
            captureMock.requestBody.contains(
                '<Channel>' + contact.FEC_Channel__c + '</Channel>'
            ),
            'Phải gửi Channel từ FEC_Contact_List__c.'
        );
        System.assert(
            captureMock.requestBody.contains(
                '<CommunicationType>' + contact.FEC_Communication_Type__c + '</CommunicationType>'
            ),
            'Phải gửi CommunicationType từ FEC_Contact_List__c.'
        );
    }
}