@IsTest
private class FEC_SecondaryController_Test {

    private static final String MOCK_DIGITAL_XML =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soapenv:Body><GetDigitalAccountStatusResponse>' +
        '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '<AccountStatus>' +
        '<DigitalAccount><Type>ZALO</Type><Status>Y</Status></DigitalAccount>' +
        '<DigitalAccount><Type>WEBSITE</Type><Status>N</Status></DigitalAccount>' +
        '<DigitalAccount><Type>FEMOBILEAPP</Type><Status>Y</Status></DigitalAccount>' +
        '</AccountStatus></GetDigitalAccountStatusResponse></soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_CUSTOMER_BASIC_XML =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soapenv:Body><GetCustomerInfoBasicResponse>' +
        '<Sys><Code>1</Code></Sys>' +
        '<CustomerBasicInfo><CIFNumber>123456</CIFNumber>' +
        '<PreferredContacts>' +
        '<PreferredContact>' +
        '<ContactId>C001</ContactId><Channel>Email</Channel>' +
        '<CommunicationType>Personal</CommunicationType>' +
        '<ContactString>test@fec.com</ContactString>' +
        '</PreferredContact>' +
        '<PreferredContact>' +
        '<ContactId>C002</ContactId><Channel>Phone</Channel>' +
        '<CommunicationType>Work</CommunicationType>' +
        '<ContactString>0901234567</ContactString>' +
        '</PreferredContact>' +
        '</PreferredContacts></CustomerBasicInfo>' +
        '</GetCustomerInfoBasicResponse></soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_RELATIVES_XML =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
        'xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfo">' +
        '<soapenv:Body><cif:GetRelativesListResponse>' +
        '<Sys><Code>1</Code></Sys><CIFNumber>123456</CIFNumber>' +
        '<Relatives><Relative>' +
        '<RelationType>Brother</RelationType><FullName>Nguyen Van A</FullName>' +
        '<PhoneNumber>0987654321</PhoneNumber></Relative></Relatives>' +
        '</cif:GetRelativesListResponse></soapenv:Body></soapenv:Envelope>';

    private class MultiSecondarySoapMock implements HttpCalloutMock {
        private Integer statusCode;

        MultiSecondarySoapMock(Integer statusCode) {
            this.statusCode = statusCode;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            if (statusCode != 200) {
                res.setBody('Error');
                return res;
            }

            String body = req.getBody() != null ? req.getBody() : '';
            res.setHeader('Content-Type', 'text/xml');
            if (body.contains('GetDigitalAccountStatus')) {
                res.setBody(MOCK_DIGITAL_XML);
            } else if (body.contains('GetCustomerInfoBasic')) {
                res.setBody(MOCK_CUSTOMER_BASIC_XML);
            } else if (body.contains('GetRelativesList')) {
                res.setBody(MOCK_RELATIVES_XML);
            } else {
                res.setBody(MOCK_DIGITAL_XML);
            }
            return res;
        }
    }

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

        String suffix = String.valueOf(System.currentTimeMillis());

        Case c1 = new Case(
            Subject = 'Test Case With Account',
            Status = 'New',
            FEC_ID_Search__c = 'SEC-' + suffix + '-1'
        );
        Case c2 = new Case(
            Subject = 'Test Case Without Account',
            Status = 'New',
            FEC_ID_Search__c = 'SEC-' + suffix + '-2'
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new List<Case>{ c1, c2 };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Case__c = c1.Id,
            FEC_CIF_Number__c = '123456',
            FEC_Work_Phone__c = '0901234567'
        );
        insert ch;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c1.Id,
                FEC_Account_or_Contract__c = ch.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static Case getCaseWithAccount() {
        return [SELECT Id, FEC_Account_or_Contract__c FROM Case WHERE Subject = 'Test Case With Account' LIMIT 1];
    }

    @IsTest
    static void testLoadSecondaryInfo_Success_API_Flow() {
        Case c = getCaseWithAccount();
        FEC_Customer_History__c ch = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
        ];
        ch.FEC_API_Cache_Secondary_Demo__c = null;
        update ch;

        Test.setMock(HttpCalloutMock.class, new MultiSecondarySoapMock(200));

        Test.startTest();
        FEC_SecondaryController.SecondaryInfoDTO result =
            FEC_SecondaryController.loadSecondaryInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Yes', result.zaloFollower);
        System.assertEquals('No', result.websiteAccount);
        System.assertEquals('Yes', result.mobileAppAccount);
        System.assertEquals('test@fec.com', result.email);
        System.assert(result.references != null && !result.references.isEmpty());
        System.assert(result.contactList != null && !result.contactList.isEmpty());
        System.assert(result.helpTexts != null);

        FEC_Customer_History__c updated = [
            SELECT FEC_API_Cache_Secondary_Demo__c, FEC_Zalo_Follower__c, FEC_Email__c
            FROM FEC_Customer_History__c
            WHERE Id = :ch.Id
        ];
        System.assertNotEquals(null, updated.FEC_API_Cache_Secondary_Demo__c);
        System.assertEquals('Yes', updated.FEC_Zalo_Follower__c);
        System.assertEquals('test@fec.com', updated.FEC_Email__c);

        System.assertEquals(
            2,
            [SELECT COUNT() FROM FEC_Contact_List__c WHERE FEC_Customer_History__c = :ch.Id]
        );
    }

    @IsTest
    static void testLoadSecondaryInfo_CacheHit_Flow() {
        Case c = getCaseWithAccount();

        FEC_SecondaryController.SecondaryInfoDTO mockDto = new FEC_SecondaryController.SecondaryInfoDTO();
        mockDto.zaloFollower = 'Yes';
        mockDto.email = 'cache@fec.com';
        mockDto.contactList = new List<FEC_SecondaryController.ContactDTO>();
        mockDto.references = new List<FEC_SecondaryController.ReferenceDTO>();

        update new FEC_Customer_History__c(
            Id = c.FEC_Account_or_Contract__c,
            FEC_API_Cache_Secondary_Demo__c = JSON.serialize(mockDto)
        );

        Test.startTest();
        FEC_SecondaryController.SecondaryInfoDTO result =
            FEC_SecondaryController.loadSecondaryInfo(c.Id);
        Test.stopTest();

        System.assertEquals('Yes', result.zaloFollower);
        System.assertEquals('cache@fec.com', result.email);
        System.assertNotEquals(null, result.helpTexts);
    }

    @IsTest
    static void testLoadSecondaryInfo_Error_Handling() {
        Case cNoAccount = [
            SELECT Id FROM Case WHERE Subject = 'Test Case Without Account' LIMIT 1
        ];

        Test.startTest();
        try {
            FEC_SecondaryController.loadSecondaryInfo(null);
            System.assert(false, 'Expected exception for null Case Id.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            FEC_SecondaryController.loadSecondaryInfo(cNoAccount.Id);
            System.assert(false, 'Expected exception when Case has no account.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testLoadSecondaryInfo_API_Failures() {
        Case c = getCaseWithAccount();
        FEC_Customer_History__c ch = [
            SELECT Id FROM FEC_Customer_History__c WHERE Id = :c.FEC_Account_or_Contract__c
        ];
        ch.FEC_API_Cache_Secondary_Demo__c = null;
        update ch;

        Test.setMock(HttpCalloutMock.class, new MultiSecondarySoapMock(500));

        Test.startTest();
        FEC_SecondaryController.SecondaryInfoDTO result =
            FEC_SecondaryController.loadSecondaryInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(
            null,
            [SELECT FEC_API_Cache_Secondary_Demo__c FROM FEC_Customer_History__c WHERE Id = :ch.Id]
                .FEC_API_Cache_Secondary_Demo__c
        );
    }

    @IsTest
    static void testLoadSecondaryInfo_WithExistingContacts() {
        Case c = getCaseWithAccount();
        Id chId = c.FEC_Account_or_Contract__c;

        insert new FEC_Contact_List__c(
            FEC_Customer_History__c = chId,
            FEC_Channel__c = 'Phone',
            FEC_Communication_Type__c = 'Mobile',
            FEC_Contact_String__c = '0911111111',
            FEC_Contact_ID__c = 'EXIST01'
        );

        update new FEC_Customer_History__c(
            Id = chId,
            FEC_API_Cache_Secondary_Demo__c = null
        );

        Test.setMock(HttpCalloutMock.class, new MultiSecondarySoapMock(200));

        Test.startTest();
        FEC_SecondaryController.SecondaryInfoDTO result =
            FEC_SecondaryController.loadSecondaryInfo(c.Id);
        Test.stopTest();

        System.assert(result.contactList.size() >= 1);
    }

    @IsTest
    static void testLogSensitiveFromSecondaryInfo() {
        Case c = getCaseWithAccount();

        Test.startTest();
        FEC_SecondaryController.logSensitiveFromSecondaryInfo(
            'Secondary Info Section',
            'Zalo Follower',
            c.Id
        );
        Test.stopTest();

        System.assert(true, 'Audit log completed without error.');
    }
}
