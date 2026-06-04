@IsTest
private class FEC_IntSearchFraudCase_Test {

    @TestSetup
    static void setup() {
        FEC_Integration_Case__c fhCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-100001',
            FEC_Service_Case_ID__c = 'SVC-001',
            FEC_Sys_Channel__c = 'CH001',
            FEC_Case_Status__c = 'New',
            FEC_Category__c = 'CAT001',
            FEC_Sub_Category__c = 'SUBCAT001',
            FEC_Sub_Code__c = 'CODE001',
            FEC_Creator_Email__c = 'test@test.com'
        );
        insert fhCase;

        FEC_Integration_Case__c buCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'BU-200001',
            FEC_Service_Case_ID__c = 'SVC-001',
            FEC_Sys_Channel__c = 'CH001',
            FEC_Case_Status__c = 'New',
            FEC_Parent_CaseID__c = 'FH-100001'
        );
        insert buCase;

        FEC_Integration_Case__c tkCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'TK-300001',
            FEC_Service_Case_ID__c = 'SVC-001',
            FEC_Sys_Channel__c = 'CH001',
            FEC_Case_Status__c = 'New',
            FEC_Parent_CaseID__c = 'BU-200001'
        );
        insert tkCase;

        FEC_Integration_Case_Info__c info = new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = fhCase.Id,
            FEC_Info_ID__c = 'AccountNumber',
            FEC_Info_Value__c = 'ACC-001'
        );
        insert info;
    }

    @IsTest
    static void test_searchFraudCases_NoFilter() {
        Test.startTest();
        Map<String,Object> result = FEC_IntegrationSearchFraudCaseController.searchFraudCases(
            null, null, null, null, null, null, 1, 10, 'CreatedDate', 'DESC'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return result map');
        System.assert(result.containsKey('total'), 'Should contain total key');
    }

    @IsTest
    static void test_searchFraudCases_ByCaseId() {
        Test.startTest();
        Map<String,Object> result = FEC_IntegrationSearchFraudCaseController.searchFraudCases(
            'FH-100001', null, null, null, null, null, 1, 10, 'CreatedDate', 'DESC'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_searchFraudCases_ByAccountNumber() {
        Test.startTest();
        Map<String,Object> result = FEC_IntegrationSearchFraudCaseController.searchFraudCases(
            null, null, null, null, null, 'ACC-001', 1, 10, 'AccountNumber', 'ASC'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_searchFraudCases_ByNationalId() {
        Test.startTest();
        Map<String,Object> result = FEC_IntegrationSearchFraudCaseController.searchFraudCases(
            null, '123456789', null, null, null, null, 1, 10, 'CreatedDate', 'DESC'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_getFraudSubCases_NoData() {
        Test.startTest();
        Map<String,Object> result = FEC_IntegrationSearchFraudCaseController.getFraudSubCases('FH-NOTEXIST');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(0, result.get('total'));
    }

    @IsTest
    static void test_getFraudSubCases_WithData() {
        Test.startTest();
        Map<String,Object> result = FEC_IntegrationSearchFraudCaseController.getFraudSubCases('FH-100001');
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_getFraudSubCases_BlankInput() {
        Test.startTest();
        Map<String,Object> result = FEC_IntegrationSearchFraudCaseController.getFraudSubCases('');
        Test.stopTest();

        System.assertNotEquals(null, result);
    }
}