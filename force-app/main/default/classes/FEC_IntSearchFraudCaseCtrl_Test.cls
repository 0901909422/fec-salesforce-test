@IsTest
private class FEC_IntSearchFraudCaseCtrl_Test {

    @TestSetup
    static void setupData() {
        // Create FH case
        FEC_Integration_Case__c fhCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-500001',
            FEC_Service_Case_ID__c = 'SVC-001',
            FEC_Case_Status__c = 'Investigating',
            FEC_Sys_Channel__c = 'PEGACSM',
            FEC_Creator_Email__c = 'test@test.com',
            FEC_Category__c = 'CAT01',
            FEC_Sub_Category__c = 'SUB01'
        );
        insert fhCase;

        // Create BU case under FH
        FEC_Integration_Case__c buCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'BU-600001',
            FEC_Parent_CaseID__c = 'FH-500001',
            FEC_Service_Case_ID__c = 'SVC-001',
            FEC_Case_Status__c = 'Investigating',
            FEC_Sys_Channel__c = 'PEGACSM',
            FEC_Creator_Email__c = 'test@test.com'
        );
        insert buCase;

        // Create TK case under BU
        FEC_Integration_Case__c tkCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'TK-700001',
            FEC_Parent_CaseID__c = 'BU-600001',
            FEC_Service_Case_ID__c = 'SVC-001',
            FEC_Case_Status__c = 'Investigating',
            FEC_Sys_Channel__c = 'PEGACSM',
            FEC_Creator_Email__c = 'test@test.com'
        );
        insert tkCase;

        // Create case info for account number
        FEC_Integration_Case_Info__c info = new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = fhCase.Id,
            FEC_Info_ID__c = 'AccountNumber',
            FEC_Info_Value__c = '123456789'
        );
        insert info;
    }

    @IsTest
    static void test_searchFraudCases_noFilter() {
        Test.startTest();
        Map<String, Object> result = FEC_IntegrationSearchFraudCaseController.searchFraudCases(
            null, null, null, null, null, null, 1, 10, 'CreatedDate', 'DESC'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('total'));
    }

    @IsTest
    static void test_searchFraudCases_withCaseIdFilter() {
        Test.startTest();
        Map<String, Object> result = FEC_IntegrationSearchFraudCaseController.searchFraudCases(
            'FH-500001', null, null, null, null, null, 1, 10, 'FEC_CaseID__c', 'ASC'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        Integer total = (Integer) result.get('total');
        System.assert(total >= 1, 'Should find at least 1 case');
    }

    @IsTest
    static void test_searchFraudCases_withAccountNumberFilter() {
        Test.startTest();
        Map<String, Object> result = FEC_IntegrationSearchFraudCaseController.searchFraudCases(
            null, null, null, null, null, '123456789', 1, 10, 'CreatedDate', 'DESC'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_searchFraudCases_sortByAccountNumber() {
        Test.startTest();
        Map<String, Object> result = FEC_IntegrationSearchFraudCaseController.searchFraudCases(
            null, null, null, null, null, null, 1, 10, 'AccountNumber', 'ASC'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_searchFraudCases_noMatch() {
        Test.startTest();
        Map<String, Object> result = FEC_IntegrationSearchFraudCaseController.searchFraudCases(
            null, '999999999', null, null, null, null, 1, 10, 'CreatedDate', 'DESC'
        );
        Test.stopTest();

        Integer total = (Integer) result.get('total');
        System.assertEquals(0, total);
    }

    @IsTest
    static void test_getFraudSubCases_valid() {
        Test.startTest();
        Map<String, Object> result = FEC_IntegrationSearchFraudCaseController.getFraudSubCases('FH-500001');
        Test.stopTest();

        System.assertNotEquals(null, result);
        Integer total = (Integer) result.get('total');
        System.assert(total >= 1, 'Should find TK cases');
    }

    @IsTest
    static void test_getFraudSubCases_blank() {
        Test.startTest();
        Map<String, Object> result = FEC_IntegrationSearchFraudCaseController.getFraudSubCases('');
        Test.stopTest();

        Integer total = (Integer) result.get('total');
        System.assertEquals(0, total);
    }

    @IsTest
    static void test_getFraudSubCases_noMatch() {
        Test.startTest();
        Map<String, Object> result = FEC_IntegrationSearchFraudCaseController.getFraudSubCases('FH-999999');
        Test.stopTest();

        Integer total = (Integer) result.get('total');
        System.assertEquals(0, total);
    }
}
