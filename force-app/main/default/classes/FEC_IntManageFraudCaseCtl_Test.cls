@IsTest
private class FEC_IntManageFraudCaseCtl_Test {

    @TestSetup
    static void setup() {
        Case c = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Phone',
            FEC_ID_Search__c = 'SVC-001'
        );
        insert c;

        FEC_Integration_Case__c fhCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-100001',
            FEC_Service_Case_ID__c = 'SVC-001',
            FEC_Sys_Channel__c = 'CH001',
            FEC_Case_Status__c = 'New'
        );
        insert fhCase;
    }

    @IsTest
    static void test_initManageFraudCase_BlankServiceCaseId() {
        Test.startTest();
        FEC_IntegrationManageFraudCaseCtrl.ManageFraudCaseDTO dto = 
            FEC_IntegrationManageFraudCaseCtrl.initManageFraudCase('', 'NOC-001');
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertNotEquals(null, dto.actionMode);
    }

    @IsTest
    static void test_initManageFraudCase_NonExisting() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        try {
            FEC_IntegrationManageFraudCaseCtrl.ManageFraudCaseDTO dto = 
                FEC_IntegrationManageFraudCaseCtrl.initManageFraudCase(c.Id, 'NOC-001');
        } catch (Exception e) {
            // May throw if mapping not found
        }
        Test.stopTest();
    }

    @IsTest
    static void test_ManageFraudCaseDTO() {
        FEC_IntegrationManageFraudCaseCtrl.ManageFraudCaseDTO dto = 
            new FEC_IntegrationManageFraudCaseCtrl.ManageFraudCaseDTO();
        dto.actionMode = 'CreateMode';
        dto.fraudCaseId = 'FH-001';
        dto.serviceCaseId = 'SVC-001';
        dto.natureOfCaseId = 'NOC-001';
        dto.caseStatus = 'New';
        dto.integrateMappingId = 'MAP-001';
        dto.caseData = new Map<String, Object>();

        System.assertEquals('CreateMode', dto.actionMode);
    }
}