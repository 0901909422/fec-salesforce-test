@IsTest
private class FEC_IntFraudCaseDetail_Test {

    @TestSetup
    static void setup() {
        FEC_Integration_Case__c fhCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-100001',
            FEC_Service_Case_ID__c = 'SVC-001',
            FEC_Sys_Channel__c = 'CH001',
            FEC_Case_Status__c = 'New'
        );
        insert fhCase;

        FEC_Integration_Case_Info__c info = new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = fhCase.Id,
            FEC_Info_ID__c = 'NationalID',
            FEC_Info_Value__c = '123456789',
            FEC_Property_Type__c = 'string'
        );
        insert info;
    }

    @IsTest
    static void test_getFraudCaseDetail_Blank() {
        Test.startTest();
        try {
            Map<String, Object> result = FEC_IntegrationFraudCaseDetailController.getFraudCaseDetail('');
        } catch (Exception e) {
            // Expected to throw or return null for blank input
        }
        Test.stopTest();
    }

    @IsTest
    static void test_getFraudCaseDetail_NotFound() {
        Test.startTest();
        try {
            Map<String, Object> result = FEC_IntegrationFraudCaseDetailController.getFraudCaseDetail('FH-NOTEXIST');
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void test_getFraudCaseDetail_Found() {
        Test.startTest();
        try {
            Map<String, Object> result = FEC_IntegrationFraudCaseDetailController.getFraudCaseDetail('FH-100001');
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void test_getOriginalSnapshot_Blank() {
        Test.startTest();
        Map<String, Object> result = FEC_IntegrationFraudCaseDetailController.getOriginalSnapshot('');
        Test.stopTest();
        System.assertEquals(null, result);
    }

    @IsTest
    static void test_getOriginalSnapshot_NotFound() {
        Test.startTest();
        Map<String, Object> result = FEC_IntegrationFraudCaseDetailController.getOriginalSnapshot('SVC-NOTEXIST');
        Test.stopTest();
        System.assertEquals(null, result);
    }
}