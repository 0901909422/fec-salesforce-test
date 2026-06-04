@IsTest
private class FEC_ServiceFraudTaskCase_Test {

    private class FraudServiceMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                '<ns1:ProcessCaseResponse xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
                '<ns1:Sys><ns1:Code>1</ns1:Code><ns1:Description>OK</ns1:Description></ns1:Sys>' +
                '</ns1:ProcessCaseResponse>' +
                '</soap:Body></soap:Envelope>'
            );
            return res;
        }
    }

    @TestSetup
    static void setup() {
        // Create Case
        Case c = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Phone',
            FEC_ID_Search__c = 'SVC-001'
        );
        insert c;

        // Create FH (root) integration case
        FEC_Integration_Case__c fhCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-100001',
            FEC_Service_Case_ID__c = 'SVC-001',
            FEC_Sys_Channel__c = 'CH001',
            FEC_Case_Status__c = 'New',
            FEC_Category__c = 'CAT001',
            FEC_Sub_Category__c = 'SUBCAT001',
            FEC_Sub_Code__c = 'CODE001',
            FEC_Creator_Email__c = 'fh@test.com'
        );
        insert fhCase;

        // Create BU intermediate case (parent = FH)
        FEC_Integration_Case__c buCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'BU-200001',
            FEC_Service_Case_ID__c = 'SVC-001',
            FEC_Sys_Channel__c = 'CH001',
            FEC_Case_Status__c = 'New',
            FEC_Parent_CaseID__c = 'FH-100001'
        );
        insert buCase;

        // Create TK leaf case linked to the Case via FEC_Integrate_Case_ID__c
        FEC_Integration_Case__c tkCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'TK-300001',
            FEC_Service_Case_ID__c = 'SVC-001',
            FEC_Sys_Channel__c = 'CH001',
            FEC_Case_Status__c = 'New',
            FEC_Parent_CaseID__c = 'BU-200001',
            FEC_Integrate_Case_ID__c = c.Id,
            FEC_Investigation_Conclusion__c = 'Confirmed',
            FEC_Creator_Email__c = 'tk@test.com'
        );
        insert tkCase;

        // Create case info entries to exercise populateCaseAndTask
        insert new List<FEC_Integration_Case_Info__c>{
            new FEC_Integration_Case_Info__c(
                FEC_Parent_Case__c = tkCase.Id,
                FEC_Info_ID__c = 'UIC',
                FEC_Info_Value__c = 'CS'
            ),
            new FEC_Integration_Case_Info__c(
                FEC_Parent_Case__c = tkCase.Id,
                FEC_Info_ID__c = 'TaskName',
                FEC_Info_Value__c = 'Test Task'
            ),
            new FEC_Integration_Case_Info__c(
                FEC_Parent_Case__c = tkCase.Id,
                FEC_Info_ID__c = 'AppID',
                FEC_Info_Value__c = 'APP-001'
            )
        };

        // Create case remark
        FEC_Case_Remarks__c remark = new FEC_Case_Remarks__c(
            FEC_Case__c = c.Id,
            FEC_Case_Remarks__c = 'Test remark',
            FEC_User__c = UserInfo.getUserId(),
            FEC_Stage_Name__c = 'New'
        );
        insert remark;
    }

    @IsTest
    static void test_getCaseData_Blank() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto = 
            FEC_ServiceFraudTaskCaseController.getCaseData('');
        Test.stopTest();

        System.assertNotEquals(null, dto);
    }

    @IsTest
    static void test_getCaseData_Found() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto = 
            FEC_ServiceFraudTaskCaseController.getCaseData(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertNotEquals(null, dto.task, 'Should populate task info');
    }

    @IsTest
    static void test_getCaseData_NotFound() {
        Case c = new Case(Subject = 'Other', Status = 'New', Origin = 'Phone');
        insert c;

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto = 
            FEC_ServiceFraudTaskCaseController.getCaseData(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto);
    }

    @IsTest
    static void test_submitProcessCaseDecision_Success() {
        Test.setMock(HttpCalloutMock.class, new FraudServiceMock());
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_ServiceFraudTaskCaseController.submitProcessCaseDecision(
                c.Id, 'Confirmed', 'Sub', 'Reason', 'Test remarks'
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_submitProcessCaseDecision_NoServiceCase() {
        // Use a Case with no matching FEC_Integration_Case__c record
        Case orphanCase = new Case(Subject = 'Orphan', Status = 'New', Origin = 'Phone');
        insert orphanCase;

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_ServiceFraudTaskCaseController.submitProcessCaseDecision(
                orphanCase.Id, 'Confirmed', 'Sub', 'Reason', 'Test remarks'
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(false, result.success, 'Should fail when service case not found');
    }

    @IsTest
    static void test_submitProcessCaseDecision_BlankRemarks() {
        Test.setMock(HttpCalloutMock.class, new FraudServiceMock());
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_ServiceFraudTaskCaseController.submitProcessCaseDecision(
                c.Id, 'Cancelled', 'Sub', 'Reason', ''
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_getRemarksData() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_IntegrationFraudCaseUtil.RemarksInfo> result = 
            FEC_ServiceFraudTaskCaseController.getRemarksData(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.size() > 0, 'Should return at least one remark');
    }

    @IsTest
    static void test_getCustomerData_Blank() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.CustomerInfo cust = 
            FEC_ServiceFraudTaskCaseController.getCustomerData('');
        Test.stopTest();

        System.assertNotEquals(null, cust);
    }

    @IsTest
    static void test_getCustomerData_Found() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.CustomerInfo cust = 
            FEC_ServiceFraudTaskCaseController.getCustomerData(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, cust);
    }

    @IsTest
    static void test_getCustomerData_NotFound() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.CustomerInfo cust = 
            FEC_ServiceFraudTaskCaseController.getCustomerData('001000000000000');
        Test.stopTest();

        System.assertNotEquals(null, cust);
    }
}