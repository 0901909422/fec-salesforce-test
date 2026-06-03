@IsTest
private class FEC_CustomerIntegrationService_Test {

    private static final String ACCOUNT_NUMBER = '1234567890123456';

    private class CustomerIntegrationMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
            String body = req.getBody() != null ? req.getBody().toLowerCase() : '';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            if (endpoint.contains('customerlist') || body.contains('getcustomerlist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><cif:GetCustomerListResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
                    '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                    '<Count>1</Count><Customers><Customer>' +
                    '<CIFNumber>CIF-SYNC-001</CIFNumber>' +
                    '<FullName>Nguyen Van Sync</FullName>' +
                    '<NationalID>079123456789</NationalID>' +
                    '<DateOfBirth>1990-05-15</DateOfBirth>' +
                    '<Phones><PhoneNode><Type>Mobile</Type><Phone>0909998877</Phone></PhoneNode></Phones>' +
                    '<Emails><Email>sync@example.com</Email></Emails>' +
                    '</Customer></Customers>' +
                    '</cif:GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (endpoint.contains('customerinfobasic') || body.contains('getcustomerinfobasic')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCustomerInfoBasicResponse>' +
                    '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                    '<CustomerBasicInfo>' +
                    '<FullName>Nguyen Van Basic</FullName>' +
                    '<Gender>Male</Gender>' +
                    '<Birthday>1990-05-15</Birthday>' +
                    '<PreferredContacts>' +
                    '<PreferredContact><Contact><Channel>Email</Channel><ContactString>basic@example.com</ContactString></Contact></PreferredContact>' +
                    '</PreferredContacts>' +
                    '</CustomerBasicInfo>' +
                    '</GetCustomerInfoBasicResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (endpoint.contains('documentslist') || body.contains('getdocumentslist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetDocumentsListResponse>' +
                    '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                    '<Documents><Document><DocumentID>DOC-SYNC-001</DocumentID></Document></Documents>' +
                    '</GetDocumentsListResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            if (endpoint.contains('cardbasicinfo') || body.contains('getcardbasicinfo')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCardBasicInfoResponse>' +
                    '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
                    '<CardBasicInfo><MainCard><PlasticIndicator>PLASTIC-001</PlasticIndicator></MainCard></CardBasicInfo>' +
                    '</GetCardBasicInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
                return res;
            }

            res.setBody('');
            return res;
        }
    }

    @IsTest
    static void testQueryHistoryForSync() {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Query history sync',
                Status = 'New',
                FEC_ID_Search__c = 'CIS-Q-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_CIF_Number__c = 'CIF-QUERY',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_Customer_Name__c = 'Query User',
            FEC_National_ID_Passport_ID__c = '123456789',
            FEC_Primary_Phone__c = '0901112233',
            FEC_Email__c = 'query@example.com'
        );
        insert hist;

        Test.startTest();
        FEC_Customer_History__c loaded = FEC_CustomerIntegrationService.queryHistoryForSync(hist.Id);
        Test.stopTest();

        System.assertEquals(hist.Id, loaded.Id);
        System.assertEquals('CIF-QUERY', loaded.FEC_CIF_Number__c);
        System.assertEquals(ACCOUNT_NUMBER, loaded.FEC_Account_Number__c);
        System.assertEquals('Query User', loaded.FEC_Customer_Name__c);
    }

    @IsTest
    static void testSyncCustomer_Success() {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Integration Sync Test',
                Status = 'New',
                FEC_ID_Search__c = 'CIS-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result = FEC_CustomerIntegrationService.syncCustomer(
            hist, null, null, ACCOUNT_NUMBER
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Nguyen Van Sync', result.customerName);
        System.assertEquals('079123456789', result.nationalId);
        System.assertEquals('0909998877', result.primaryPhone);
        System.assertEquals('sync@example.com', result.emailAddress);
        System.assertEquals('PLASTIC-001', result.plasticID);
        System.assertEquals('CIF-SYNC-001', hist.FEC_CIF_Number__c);
        System.assertEquals('DOC-SYNC-001', hist.FEC_National_ID_Passport_ID__c);
    }

    @IsTest
    static void testSyncCustomer_WithProvidedCif() {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Integration CIF Test',
                Status = 'New',
                FEC_ID_Search__c = 'CIS-CIF-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result = FEC_CustomerIntegrationService.syncCustomer(
            hist, 'CIF123', '0901234567', ACCOUNT_NUMBER
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Nguyen Van Basic', result.customerName);
        System.assertEquals('Male', result.gender);
        System.assertEquals(Date.newInstance(1990, 5, 15), result.dateOfBirth);
        System.assertEquals('DOC-SYNC-001', result.nationalId);
        System.assertEquals('PLASTIC-001', result.plasticID);
    }

    @IsTest
    static void testSyncCustomer_NullInputs() {
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(null, null, null, null);
        Test.stopTest();

        System.assertEquals(null, result.customerName, 'Khi hist null, kết quả nên rỗng.');
    }

    @IsTest
    static void testSyncCustomer_NoCifReturnsEmpty() {
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, null, null, null);
        Test.stopTest();

        System.assertEquals(null, result.customerName);
        System.assertEquals(null, result.nationalId);
    }

    @IsTest
    static void testSyncCustomer_WithContractNumber() {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Integration Contract Test',
                Status = 'New',
                FEC_ID_Search__c = 'CIS-CTR-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Contract_Number__c = 'CTR-SYNC-001',
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, null, null, null);
        Test.stopTest();

        System.assertEquals('Nguyen Van Sync', result.customerName);
        System.assertEquals('079123456789', result.nationalId);
        System.assertEquals('CIF-SYNC-001', hist.FEC_CIF_Number__c);
        System.assertEquals('0909998877', result.primaryPhone);
    }

    @IsTest
    static void testSyncCustomer_FallbackAccountNumberParam() {
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_National_ID_Passport_ID__c = '123456789'
        );
        insert hist;

        Test.setMock(HttpCalloutMock.class, new CustomerIntegrationMock());
        Test.startTest();
        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, null, null, ACCOUNT_NUMBER);
        Test.stopTest();

        System.assertEquals('Nguyen Van Sync', result.customerName);
        System.assertEquals('CIF-SYNC-001', hist.FEC_CIF_Number__c);
    }
}
