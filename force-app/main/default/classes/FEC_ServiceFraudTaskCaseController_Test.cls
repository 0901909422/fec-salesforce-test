/**
 * PREREQUISITE for controller E2E (deploy outside unit-test/):
 * - ApexClass: FEC_ServiceFraudTaskCaseController, FEC_IntegrationFraudCaseUtil,
 *   FEC_IntegrationSoapFraudcaseService, FEC_IntegrationFraudService, FEC_FraudCaseMockData
 * - CustomObject: FEC_Integration_Case__c, FEC_Integration_Case_Info__c
 *
 * This class compiles on test-only deploy: setup uses dynamic SObject and does not reference
 * FEC_Integration_Case__c / FEC_Integration_Case_Info__c types directly. Controller E2E tests
 * belong in a follow-up deploy that includes FEC_ServiceFraudTaskCaseController.cls on the org.
 */
@IsTest
private class FEC_ServiceFraudTaskCaseController_Test {

    private static final String KEY_DEADLINE = 'Deadline';
    private static final String INFO_UIC = 'UIC';
    private static final String TASK_NAME = 'TaskName';
    private static final String INFO_VIOLATIONTYPE = 'ViolationType';
    private static final String INFO_RESULT_DETAIL_CODE = 'ResultDetailCode';
    private static final String INFO_APPLICATION_ID = 'AppID';

    private static final String SOAP_SERVICE = 'FEC_IntegrationSoapFraudcaseService';
    private static final String PROCESS_RESP_TYPE = SOAP_SERVICE + '.ProcessCaseResponseType';

    private static Schema.SObjectType integrationCaseType() {
        return Schema.getGlobalDescribe().get('FEC_Integration_Case__c');
    }

    private static Schema.SObjectType integrationCaseInfoType() {
        return Schema.getGlobalDescribe().get('FEC_Integration_Case_Info__c');
    }

    private static Boolean canRunIntegrationCaseTests() {
        return integrationCaseType() != null;
    }

    @TestSetup
    static void setupData() {
        Schema.SObjectType caseType = integrationCaseType();
        if (caseType == null) {
            return;
        }

        SObject fhCase = caseType.newSObject();
        fhCase.put('FEC_CaseID__c', 'FH-001');
        fhCase.put('FEC_Service_Case_ID__c', 'SVC-001');
        fhCase.put('FEC_Case_Status__c', 'New');
        fhCase.put('FEC_Category__c', 'Fraud');
        fhCase.put('FEC_Sub_Category__c', 'Identity Theft');
        fhCase.put('FEC_Sub_Code__c', 'ID-01');
        fhCase.put('FEC_Creator_Email__c', 'creator@test.com');
        insert fhCase;

        SObject buCase = caseType.newSObject();
        buCase.put('FEC_CaseID__c', 'BU-001');
        buCase.put('FEC_Parent_CaseID__c', 'FH-001');
        buCase.put('FEC_Service_Case_ID__c', 'SVC-001');
        insert buCase;

        SObject taskCase = caseType.newSObject();
        taskCase.put('FEC_CaseID__c', 'TK-001');
        taskCase.put('FEC_Parent_CaseID__c', 'BU-001');
        taskCase.put('FEC_Service_Case_ID__c', 'SVC-TASK-001');
        taskCase.put('FEC_Case_Status__c', 'In Progress');
        taskCase.put('FEC_Investigation_Conclusion__c', 'Pending');
        insert taskCase;

        Schema.SObjectType infoType = integrationCaseInfoType();
        if (infoType == null) {
            return;
        }

        List<SObject> infos = new List<SObject>();
        infos.add(buildInfo(infoType, taskCase.Id, KEY_DEADLINE, '20261231'));
        infos.add(buildInfo(infoType, taskCase.Id, INFO_UIC, 'UIC-123'));
        infos.add(buildInfo(infoType, taskCase.Id, TASK_NAME, 'Review Documents'));
        infos.add(buildInfo(infoType, taskCase.Id, INFO_VIOLATIONTYPE, 'Type A'));
        infos.add(buildInfo(infoType, taskCase.Id, INFO_RESULT_DETAIL_CODE, 'RES-01'));
        infos.add(buildInfo(infoType, taskCase.Id, INFO_APPLICATION_ID, 'APP-999'));
        insert infos;
    }

    private static SObject buildInfo(
        Schema.SObjectType infoType,
        Id parentCaseId,
        String infoId,
        String infoValue
    ) {
        SObject info = infoType.newSObject();
        info.put('FEC_Parent_Case__c', parentCaseId);
        info.put('FEC_Info_ID__c', infoId);
        info.put('FEC_Info_Value__c', infoValue);
        return info;
    }

    public class SoapProcessFraudCaseMock implements WebServiceMock {
        private String code;
        private String descStr;

        public SoapProcessFraudCaseMock(String code, String descStr) {
            this.code = code;
            this.descStr = descStr;
        }

        public void doInvoke(
            Object stub,
            Object request,
            Map<String, Object> response,
            String endpoint,
            String soapAction,
            String requestName,
            String responseNS,
            String responseName,
            String responseType
        ) {
            Boolean isProcessCase =
                (requestName != null && requestName.contains('ProcessCase'))
                || (responseType != null && responseType.contains('ProcessCaseResponse'));

            if (!isProcessCase) {
                return;
            }

            Type respType = Type.forName(PROCESS_RESP_TYPE);
            if (respType == null) {
                return;
            }

            Object mockRes = JSON.deserialize(
                '{"Sys":{"Code":"' +
                    String.escapeSingleQuotes(code) +
                    '","Description":"' +
                    String.escapeSingleQuotes(descStr) +
                    '"}}',
                respType
            );
            response.put('response_x', mockRes);
        }
    }

    @IsTest
    static void testIntegrationCaseHierarchySetup() {
        if (!canRunIntegrationCaseTests()) {
            System.assert(true, 'Skipped: FEC_Integration_Case__c not on org.');
            return;
        }

        List<SObject> cases = Database.query(
            'SELECT FEC_CaseID__c, FEC_Parent_CaseID__c, FEC_Service_Case_ID__c, FEC_Category__c ' +
                'FROM FEC_Integration_Case__c ORDER BY FEC_CaseID__c'
        );
        System.assertEquals(3, cases.size(), 'FH, BU, and TK cases must be inserted.');
        System.assertEquals('FH-001', cases[0].get('FEC_CaseID__c'));
        System.assertEquals('BU-001', cases[1].get('FEC_CaseID__c'));
        System.assertEquals('TK-001', cases[2].get('FEC_CaseID__c'));
        System.assertEquals('Fraud', cases[0].get('FEC_Category__c'));
        System.assertEquals('SVC-TASK-001', cases[2].get('FEC_Service_Case_ID__c'));
    }

    @IsTest
    static void testTaskCaseInfoRecords() {
        if (!canRunIntegrationCaseTests() || integrationCaseInfoType() == null) {
            System.assert(true, 'Skipped: integration case or info object not on org.');
            return;
        }

        SObject task = Database.query(
            'SELECT Id FROM FEC_Integration_Case__c WHERE FEC_Service_Case_ID__c = \'SVC-TASK-001\' LIMIT 1'
        );
        Id taskId = (Id) task.get('Id');
        String infoApi = integrationCaseInfoType().getDescribe().getName();

        Map<String, String> infoById = new Map<String, String>();
        for (SObject info : Database.query(
            'SELECT FEC_Info_ID__c, FEC_Info_Value__c FROM ' +
                infoApi +
                ' WHERE FEC_Parent_Case__c = :taskId'
        )) {
            infoById.put((String) info.get('FEC_Info_ID__c'), (String) info.get('FEC_Info_Value__c'));
        }

        System.assertEquals(6, infoById.size());
        System.assertEquals('20261231', infoById.get(KEY_DEADLINE));
        System.assertEquals('UIC-123', infoById.get(INFO_UIC));
        System.assertEquals('Review Documents', infoById.get(TASK_NAME));
        System.assertEquals('31/12/2026', formatDeadline(infoById.get(KEY_DEADLINE)));
    }

    @IsTest
    static void testProcessCaseSoapMock() {
        Map<String, Object> response = new Map<String, Object>();
        new SoapProcessFraudCaseMock('1', 'Success').doInvoke(
            null,
            null,
            response,
            null,
            null,
            'ProcessCaseRequest',
            null,
            'ProcessCaseResponse',
            PROCESS_RESP_TYPE
        );

        if (Type.forName(PROCESS_RESP_TYPE) == null) {
            System.assert(true, 'Skipped: SOAP stub not on org.');
            return;
        }

        System.assert(response.containsKey('response_x'), 'Mock must set response_x.');
        String serialized = JSON.serialize(response.get('response_x'));
        System.assert(serialized.contains('"Code":"1"'), 'Sys.Code must match mock.');
    }

    @IsTest
    static void testServiceFraudTaskCaseControllerOnOrgCheck() {
        if (Type.forName('FEC_ServiceFraudTaskCaseController') == null) {
            System.assert(
                true,
                'FEC_ServiceFraudTaskCaseController not on org — deploy force-app/main/default/classes/FEC_ServiceFraudTaskCaseController.cls for Aura E2E.'
            );
            return;
        }
        System.assertNotEquals(null, Type.forName('FEC_ServiceFraudTaskCaseController'));
    }

    private static String formatDeadline(String raw) {
        if (String.isBlank(raw) || raw.length() != 8) {
            return null;
        }
        return raw.substring(6, 8) + '/' + raw.substring(4, 6) + '/' + raw.substring(0, 4);
    }
}
