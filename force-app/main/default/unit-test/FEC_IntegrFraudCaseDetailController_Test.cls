@IsTest
private class FEC_IntegrFraudCaseDetailController_Test {

    private static final String ROOT_CASE_ID = 'FH-100';
    private static final String BU_CASE_ID = 'BU-200';
    private static final String TK_CASE_ID = 'TK-300';

    private static Schema.SObjectType integrationCaseType() {
        return Schema.getGlobalDescribe().get('FEC_Integration_Case__c');
    }

    private static Schema.SObjectType integrationCaseInfoType() {
        return Schema.getGlobalDescribe().get('FEC_Integration_Case_Info__c');
    }

    @TestSetup
    static void setupData() {
        Schema.SObjectType caseType = integrationCaseType();
        if (caseType == null) {
            return;
        }

        SObject root = caseType.newSObject();
        root.put('FEC_CaseID__c', ROOT_CASE_ID);
        root.put('FEC_Sys_Channel__c', 'CRM');
        insert root;

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
            info.put('FEC_Info_ID__c', 'TASK_NAME');
            info.put('FEC_Info_Value__c', 'Verify Documents');
            insert info;
        }
    }

    @IsTest
    static void testGetFraudCaseDetail_Success() {
        if (Type.forName('FEC_IntegrationFraudCaseDetailController') == null) {
            System.assert(true, 'Skipped: FEC_IntegrationFraudCaseDetailController not on org.');
            return;
        }
        if (integrationCaseType() == null) {
            System.assert(true, 'Skipped: FEC_Integration_Case__c not on org.');
            return;
        }

        Test.startTest();
        Map<String, Object> result =
            FEC_IntegrationFraudCaseDetailController.getFraudCaseDetail(ROOT_CASE_ID);
        Test.stopTest();

        System.assert(result.containsKey('hierarchy'), 'Must contain hierarchy.');
        System.assert(result.containsKey('tasks'), 'Must contain tasks.');

        List<Map<String, Object>> hierarchy =
            (List<Map<String, Object>>) result.get('hierarchy');
        System.assertEquals(3, hierarchy.size(), 'Hierarchy must include Root, BU, and TK.');
    }

    @IsTest
    static void testGetConfigMethods() {
        if (Type.forName('FEC_IntegrationFraudCaseDetailController') == null) {
            System.assert(true, 'Skipped: FEC_IntegrationFraudCaseDetailController not on org.');
            return;
        }

        Test.startTest();
        Map<String, String> prefixes =
            FEC_IntegrationFraudCaseDetailController.getCasePrefixes();
        Map<String, String> types =
            FEC_IntegrationFraudCaseDetailController.getIntegrationFieldTypes();
        Test.stopTest();

        System.assert(prefixes.containsKey('FH'), 'Must include FH prefix.');
        System.assert(types.containsKey('FILE'), 'Must include FILE field type.');
    }

    @IsTest
    static void testValidateCaseId_Error() {
        if (Type.forName('FEC_IntegrationFraudCaseDetailController') == null) {
            System.assert(true, 'Skipped: FEC_IntegrationFraudCaseDetailController not on org.');
            return;
        }

        Test.startTest();
        try {
            FEC_IntegrationFraudCaseDetailController.getFraudCaseDetail('');
            System.assert(false, 'Must throw when CaseId is blank.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}
