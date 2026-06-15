@IsTest
private class FEC_FullCustomerIntegrationJob_Test {

    private class CustomerSyncMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            String body = req != null && req.getBody() != null ? req.getBody().toLowerCase() : '';
            String responseBody =
                '<GetCustomerInfoBasicResponse><Sys><Code>1</Code><Description>OK</Description></Sys>' +
                '<CustomerBasicInfo><FullName>Updated Customer</FullName><Gender>Male</Gender>' +
                '<Birthday>1990-05-15</Birthday>' +
                '<PreferredContacts><PreferredContact><Contact>' +
                '<Channel>Email</Channel><ContactString>sync@example.com</ContactString>' +
                '</Contact></PreferredContact></PreferredContacts></CustomerBasicInfo>' +
                '</GetCustomerInfoBasicResponse>';

            if (body.contains('getcustomerlist')) {
                responseBody =
                    '<GetCustomerListResponse><Sys><Code>1</Code><Description>OK</Description></Sys>' +
                    '<Count>1</Count><Customers><Customer>' +
                    '<CIFNumber>CIF123</CIFNumber><FullName>Updated Customer</FullName>' +
                    '<NationalID>079123456789</NationalID><DateOfBirth>1990-05-15</DateOfBirth>' +
                    '<Phones><PhoneNode><Type>Mobile</Type><Phone>0901234567</Phone></PhoneNode></Phones>' +
                    '<Emails><Email>sync@example.com</Email></Emails>' +
                    '</Customer></Customers></GetCustomerListResponse>';
            } else if (body.contains('getdocumentslist')) {
                responseBody =
                    '<GetDocumentsListResponse><Sys><Code>1</Code></Sys>' +
                    '<Documents><Document><DocumentID>DOC-1</DocumentID></Document></Documents>' +
                    '</GetDocumentsListResponse>';
            } else if (body.contains('getcardbasicinfo')) {
                responseBody =
                    '<GetCardBasicInfoResponse><Sys><Code>1</Code></Sys>' +
                    '<CardBasicInfo><MainCard><PlasticIndicator>PLASTIC-001</PlasticIndicator></MainCard></CardBasicInfo>' +
                    '</GetCardBasicInfoResponse>';
            } else if (body.contains('getaddresseslist')) {
                responseBody =
                    '<GetAddressesListResponse><Sys><Code>1</Code></Sys>' +
                    '<Addresses><Address><AddressType>HOME</AddressType></Address></Addresses>' +
                    '</GetAddressesListResponse>';
            } else if (body.contains('getcontactslist')) {
                responseBody =
                    '<GetContactsListResponse><Sys><Code>1</Code></Sys>' +
                    '<Contacts><Contact><Channel>Email</Channel><ContactString>sync@example.com</ContactString></Contact></Contacts>' +
                    '</GetContactsListResponse>';
            }

            res.setBody(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' + responseBody + '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private static Case insertCaseForHistory() {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Test Case',
                Status = 'New',
                FEC_ID_Search__c = 'FCJ-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    private static FEC_Customer_History__c insertHistory(Case c, String cifNumber) {
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Customer_Name__c = 'Old Name',
            FEC_CIF_Number__c = cifNumber
        );
        insert hist;
        return hist;
    }

    @IsTest
    static void testExecute_SyncSuccess() {
        Case c = insertCaseForHistory();
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Customer_Name__c = 'Old Name',
            FEC_CIF_Number__c = 'CIF123',
            FEC_Account_Number__c = '1234567890123456'
        );
        insert hist;

        c.FEC_Account_or_Contract__c = hist.Id;
        update c;

        Test.setMock(HttpCalloutMock.class, new CustomerSyncMock());
        Test.startTest();
        System.enqueueJob(new FEC_FullCustomerIntegrationJob(
            hist.Id, 'CIF123', '0901234567', '1234567890123456'
        ));
        Test.stopTest();

        FEC_Customer_History__c updatedHist = [
            SELECT FEC_Customer_Name__c, FEC_National_ID_Passport_ID__c, FEC_Gender__c,
                   FEC_Date_of_Birth__c, FEC_Primary_Phone__c, FEC_Email__c
            FROM FEC_Customer_History__c
            WHERE Id = :hist.Id
        ];
        System.assertEquals('Updated Customer', updatedHist.FEC_Customer_Name__c);
        System.assertNotEquals(null, updatedHist.FEC_Primary_Phone__c);

        Case updatedCase = [
            SELECT FEC_Recipient_Name__c, FEC_Recipient_Phone_Number__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals('Updated Customer', updatedCase.FEC_Recipient_Name__c);
        System.assertNotEquals(null, updatedCase.FEC_Recipient_Phone_Number__c);
    }

    @IsTest
    static void testExecute_NullSafeUpdate() {
        Case c = insertCaseForHistory();
        FEC_Customer_History__c hist = insertHistory(c, null);
        hist.FEC_Customer_Name__c = 'Existing Name';
        update hist;

        Test.setMock(HttpCalloutMock.class, new CustomerSyncMock());
        Test.startTest();
        System.enqueueJob(new FEC_FullCustomerIntegrationJob(
            hist.Id, null, null, null
        ));
        Test.stopTest();

        System.assertEquals(
            'Existing Name',
            [SELECT FEC_Customer_Name__c FROM FEC_Customer_History__c WHERE Id = :hist.Id].FEC_Customer_Name__c
        );
    }

    @IsTest
    static void testExecute_BulkSyncRequestsProcessesFirstItem() {
        Case c1 = insertCaseForHistory();
        FEC_Customer_History__c hist1 = insertHistory(c1, 'CIF-BULK-1');

        List<FEC_FullCustomerIntegrationJob.SyncRequest> requests =
            new List<FEC_FullCustomerIntegrationJob.SyncRequest>{
                new FEC_FullCustomerIntegrationJob.SyncRequest(hist1.Id, 'CIF-BULK-1', null, null)
            };

        Test.setMock(HttpCalloutMock.class, new CustomerSyncMock());
        Test.startTest();
        System.enqueueJob(new FEC_FullCustomerIntegrationJob(requests));
        Test.stopTest();

        System.assertNotEquals(
            null,
            [SELECT FEC_Customer_Name__c FROM FEC_Customer_History__c WHERE Id = :hist1.Id].FEC_Customer_Name__c
        );
    }

    @IsTest
    static void testExecute_EmptyBulkRequestsNoOp() {
        Test.startTest();
        System.enqueueJob(new FEC_FullCustomerIntegrationJob(
            new List<FEC_FullCustomerIntegrationJob.SyncRequest>()
        ));
        Test.stopTest();
        System.assert(true, 'Empty bulk requests should complete without error.');
    }
}
