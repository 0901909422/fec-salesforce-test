@IsTest
private class FEC_IntFraudCaseDetailCtrl_Test {

    @TestSetup
    static void setupData() {
        Case testCase = new Case(Subject = 'Detail Test', Status = 'New');
        insert testCase;

        // Create FH root case
        FEC_Integration_Case__c fhCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-500010',
            FEC_Service_Case_ID__c = 'SVC-010',
            FEC_Case_Status__c = 'Investigating',
            FEC_Sys_Channel__c = 'PEGACSM',
            FEC_Creator_Email__c = 'owner@test.com',
            FEC_Category__c = 'CAT01',
            FEC_Sub_Category__c = 'SUB01',
            FEC_Integrate_Case_ID__c = testCase.Id
        );
        insert fhCase;

        // BU case
        FEC_Integration_Case__c buCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'BU-600010',
            FEC_Parent_CaseID__c = 'FH-500010',
            FEC_Service_Case_ID__c = 'SVC-010',
            FEC_Case_Status__c = 'Investigating',
            FEC_Sys_Channel__c = 'PEGACSM',
            FEC_Creator_Email__c = 'test@test.com'
        );
        insert buCase;

        // TK case
        FEC_Integration_Case__c tkCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'TK-700010',
            FEC_Parent_CaseID__c = 'BU-600010',
            FEC_Service_Case_ID__c = 'SVC-010',
            FEC_Case_Status__c = 'Investigating',
            FEC_Sys_Channel__c = 'PEGACSM',
            FEC_Creator_Email__c = 'test@test.com'
        );
        insert tkCase;

        // Case info
        FEC_Integration_Case_Info__c info = new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = tkCase.Id,
            FEC_Info_ID__c = 'TaskName',
            FEC_Info_Value__c = 'Test Task'
        );
        insert info;
    }

    @IsTest
    static void test_getFraudCaseDetail() {
        Test.startTest();
        Map<String, Object> result = FEC_IntegrationFraudCaseDetailController.getFraudCaseDetail('FH-500010');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('hierarchy'));
        System.assert(result.containsKey('tasks'));
    }

    @IsTest
    static void test_getFraudCaseDetail_blankId() {
        Test.startTest();
        try {
            FEC_IntegrationFraudCaseDetailController.getFraudCaseDetail('');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void test_getFraudCaseDetail_notFound() {
        Test.startTest();
        try {
            FEC_IntegrationFraudCaseDetailController.getFraudCaseDetail('FH-999999');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void test_getOriginalSnapshot_blank() {
        Test.startTest();
        Map<String, Object> result = FEC_IntegrationFraudCaseDetailController.getOriginalSnapshot('');
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void test_getOriginalSnapshot_noRecord() {
        Test.startTest();
        Map<String, Object> result = FEC_IntegrationFraudCaseDetailController.getOriginalSnapshot('NONEXIST');
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void test_getCasePrefixes() {
        Test.startTest();
        Map<String, String> prefixes = FEC_IntegrationFraudCaseDetailController.getCasePrefixes();
        Test.stopTest();

        System.assertEquals('FH-', prefixes.get('FH'));
        System.assertEquals('TK-', prefixes.get('TK'));
        System.assertEquals('SFT-', prefixes.get('SFT'));
    }

    @IsTest
    static void test_getIntegrationFieldTypes() {
        Test.startTest();
        Map<String, String> types = FEC_IntegrationFraudCaseDetailController.getIntegrationFieldTypes();
        Test.stopTest();

        System.assertEquals('file', types.get('FILE'));
        System.assertEquals('string', types.get('STRING'));
        System.assertEquals('number', types.get('NUMBER'));
    }
}
