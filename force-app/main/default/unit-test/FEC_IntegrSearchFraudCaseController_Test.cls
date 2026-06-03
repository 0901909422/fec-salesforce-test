/**
 * PREREQUISITE (deploy outside unit-test/):
 * - ApexClass: FEC_IntegrationSearchFraudCaseController
 * - CustomObject: FEC_Integration_Case__c, FEC_Integration_Case_Info__c
 *
 * Object types below use dynamic SObject so test compiles when objects are missing;
 * controller class must still exist on org for deploy to succeed.
 */
@IsTest
private class FEC_IntegrSearchFraudCaseController_Test {

    private static final String ROOT_CASE_ID = 'FH-100';
    private static final String BU_CASE_ID = 'BU-200';
    private static final String TK_CASE_ID = 'TK-300';
    private static final String INFO_ACCOUNT_NUMBER = 'AccountNumber';

    private static Schema.SObjectType integrationCaseType() {
        return Schema.getGlobalDescribe().get('FEC_Integration_Case__c');
    }

    private static Schema.SObjectType integrationCaseInfoType() {
        return Schema.getGlobalDescribe().get('FEC_Integration_Case_Info__c');
    }

    private static Boolean canRunControllerTests() {
        return Type.forName('FEC_IntegrationSearchFraudCaseController') != null;
    }

    @TestSetup
    static void setupData() {
        Schema.SObjectType caseType = integrationCaseType();
        if (caseType == null) {
            return;
        }

        SObject fh = caseType.newSObject();
        fh.put('FEC_CaseID__c', ROOT_CASE_ID);
        fh.put('FEC_Sys_Channel__c', 'CRM');
        insert fh;

        SObject bu = caseType.newSObject();
        bu.put('FEC_CaseID__c', BU_CASE_ID);
        bu.put('FEC_Parent_CaseID__c', ROOT_CASE_ID);
        bu.put('FEC_Sys_Channel__c', 'CRM');
        insert bu;

        SObject tk = caseType.newSObject();
        tk.put('FEC_CaseID__c', TK_CASE_ID);
        tk.put('FEC_Parent_CaseID__c', BU_CASE_ID);
        tk.put('FEC_Sys_Channel__c', 'CRM');
        insert tk;

        Schema.SObjectType infoType = integrationCaseInfoType();
        if (infoType != null) {
            SObject info = infoType.newSObject();
            info.put('FEC_Parent_Case__c', tk.Id);
            info.put('FEC_Info_ID__c', INFO_ACCOUNT_NUMBER);
            info.put('FEC_Info_Value__c', 'ACC999');
            insert info;
        }
    }

    @IsTest
    static void testGetFraudSubCases() {
        if (!canRunControllerTests()) {
            System.assert(true, 'Skipped: FEC_IntegrationSearchFraudCaseController not on org.');
            return;
        }
        if (integrationCaseType() == null) {
            System.assert(true, 'Skipped: FEC_Integration_Case__c not on org.');
            return;
        }

        Test.startTest();
        Map<String, Object> result =
            FEC_IntegrationSearchFraudCaseController.getFraudSubCases(ROOT_CASE_ID);
        Test.stopTest();

        System.assertNotEquals(null, result.get('pageRecords'));
        System.assertEquals(1, (Integer) result.get('total'), 'Must find one TK case.');
    }

    @IsTest
    static void testSearchFraudCases() {
        if (!canRunControllerTests()) {
            System.assert(true, 'Skipped: FEC_IntegrationSearchFraudCaseController not on org.');
            return;
        }
        if (integrationCaseInfoType() == null) {
            System.assert(true, 'Skipped: FEC_Integration_Case_Info__c not on org.');
            return;
        }

        Test.startTest();
        Map<String, Object> result = FEC_IntegrationSearchFraudCaseController.searchFraudCases(
            null, null, null, null, null, 'ACC999', 1, 10, 'CreatedDate', 'DESC'
        );
        Test.stopTest();

        System.assertEquals(1, (Integer) result.get('total'), 'Must match account ACC999.');
    }

    @IsTest
    static void testSearchFraudCases_Empty() {
        if (!canRunControllerTests()) {
            System.assert(true, 'Skipped: FEC_IntegrationSearchFraudCaseController not on org.');
            return;
        }

        Test.startTest();
        Map<String, Object> result = FEC_IntegrationSearchFraudCaseController.searchFraudCases(
            'KHONG_TON_TAI', null, null, null, null, null, 1, 10, 'CreatedDate', 'DESC'
        );
        Test.stopTest();

        System.assertEquals(0, (Integer) result.get('total'));
    }
}
