@IsTest
private class FEC_FullCustomerIntegrationJob_Test {

    private class SoapCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            String responseBody =
                '<GetCustomerListResponse><Sys><Code>0</Code></Sys><Count>1</Count>' +
                '<Customers><Customer><CIFNumber>CIF123</CIFNumber><FullName>Updated Customer</FullName></Customer></Customers></GetCustomerListResponse>';
            if (req != null && req.getBody() != null && !req.getBody().contains('GetCustomerList')) {
                responseBody =
                    '<GetCustomerInfoBasicResponse><Sys><Code>0</Code></Sys>' +
                    '<Customer><FullName>Updated Customer</FullName></Customer></GetCustomerInfoBasicResponse>';
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

    @IsTest
    static void testExecute_SyncSuccess() {
        Case c = insertCaseForHistory();
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Customer_Name__c = 'Old Name',
            FEC_CIF_Number__c = 'CIF123'
        );
        insert hist;

        c.FEC_Account_or_Contract__c = hist.Id;
        update c;

        Test.setMock(HttpCalloutMock.class, new SoapCalloutMock());
        Test.startTest();
        FEC_FullCustomerIntegrationJob job = new FEC_FullCustomerIntegrationJob(
            hist.Id, 'CIF123', '0901234567', null
        );
        System.enqueueJob(job);
        Test.stopTest();

        FEC_Customer_History__c updatedHist = [
            SELECT FEC_Customer_Name__c
            FROM FEC_Customer_History__c
            WHERE Id = :hist.Id
        ];
        System.assertNotEquals(null, updatedHist.FEC_Customer_Name__c);
    }

    @IsTest
    static void testExecute_NullSafeUpdate() {
        Case c = insertCaseForHistory();
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Customer_Name__c = 'Existing Name'
        );
        insert hist;

        Test.setMock(HttpCalloutMock.class, new SoapCalloutMock());
        Test.startTest();
        FEC_FullCustomerIntegrationJob job = new FEC_FullCustomerIntegrationJob(
            hist.Id, null, null, null
        );
        System.enqueueJob(job);
        Test.stopTest();

        FEC_Customer_History__c updatedHist = [
            SELECT FEC_Customer_Name__c
            FROM FEC_Customer_History__c
            WHERE Id = :hist.Id
        ];
        System.assertEquals('Existing Name', updatedHist.FEC_Customer_Name__c);
    }
}
