@IsTest
private class FEC_ServiceFraudTaskCaseController_Test {

    private class ProcessCaseMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                '<ns1:ProcessCaseResponse xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
                '<ns1:Sys>' +
                '<ns1:Code>1</ns1:Code>' +
                '<ns1:Description>Success</ns1:Description>' +
                '<ns1:TransactionID>TXN001</ns1:TransactionID>' +
                '</ns1:Sys>' +
                '</ns1:ProcessCaseResponse>' +
                '</soap:Body></soap:Envelope>'
            );
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        Case testCase = new Case(
            Subject = 'Test Fraud Task Case',
            Status = 'New'
        );
        insert testCase;

        FEC_Integration_Case__c intCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-500070',
            FEC_Service_Case_ID__c = 'SVC-001',
            FEC_Case_Status__c = 'Investigating',
            FEC_Sys_Channel__c = 'PEGACSM',
            FEC_Creator_Email__c = 'test@test.com',
            FEC_Integrate_Case_ID__c = testCase.Id
        );
        insert intCase;

        FEC_Integration_Case_Info__c info = new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = intCase.Id,
            FEC_Info_ID__c = 'Deadline',
            FEC_Info_Value__c = '20240710'
        );
        insert info;
    }

    @IsTest
    static void test_getCaseData_withValidCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO result =
            FEC_ServiceFraudTaskCaseController.getCaseData(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.task);
    }

    @IsTest
    static void test_getCaseData_withNullId() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO result =
            FEC_ServiceFraudTaskCaseController.getCaseData(null);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_submitProcessCaseDecision_noServiceCase() {
        Test.setMock(HttpCalloutMock.class, new ProcessCaseMock());

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result =
            FEC_ServiceFraudTaskCaseController.submitProcessCaseDecision(
                'fakeId', 'Success', 'Full', 'Valid', 'Test remarks'
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(false, result.success);
    }

    @IsTest
    static void test_submitProcessCaseDecision_withMock() {
        FEC_FraudConstantCommon.USE_MOCK_PROCESS_CASE = true;
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result =
            FEC_ServiceFraudTaskCaseController.submitProcessCaseDecision(
                testCase.Id, 'Success', 'Full', 'Valid', 'Test remarks'
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_getCustomerData_blank() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.CustomerInfo result =
            FEC_ServiceFraudTaskCaseController.getCustomerData('');
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_getRemarksData_empty() {
        Test.startTest();
        List<FEC_IntegrationFraudCaseUtil.RemarksInfo> result =
            FEC_ServiceFraudTaskCaseController.getRemarksData('fakeId');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(0, result.size());
    }
}
