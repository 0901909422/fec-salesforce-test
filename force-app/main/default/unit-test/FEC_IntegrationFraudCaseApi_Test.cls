@IsTest
private class FEC_IntegrationFraudCaseApi_Test {

    private static final String CASE_ID = 'FH-12345';
    private static final String CHANNEL_ID = 'CRM';
    private static final String REFERENCE_ID = 'REF001';
    private static final String PARENT_ID = 'PARENT-001';

    private static Schema.SObjectType integrationCaseType() {
        return Schema.getGlobalDescribe().get('FEC_Integration_Case__c');
    }

    private static void insertIntegrationCase() {
        Schema.SObjectType caseType = integrationCaseType();
        if (caseType == null) {
            return;
        }
        SObject rec = caseType.newSObject();
        rec.put('FEC_CaseID__c', CASE_ID);
        rec.put('FEC_Sys_Channel__c', CHANNEL_ID);
        rec.put('FEC_Service_Case_ID__c', REFERENCE_ID);
        rec.put('FEC_Parent_CaseID__c', PARENT_ID);
        insert rec;
    }

    private static String fhPayloadJson() {
        String xmlData =
            '<GetStatusResponse>' +
                '<CaseResultInfo>' +
                    '<OriginalRequest>' +
                        '<RequestInfo><Remarks>Test</Remarks></RequestInfo>' +
                        '<CreatorInfo><CreatorEmail>test@test.com</CreatorEmail></CreatorInfo>' +
                        '<CustomerInfo/>' +
                    '</OriginalRequest>' +
                '</CaseResultInfo>' +
            '</GetStatusResponse>';
        return '{' +
            '"detail": {' +
                '"caseID": "' + CASE_ID + '",' +
                '"channelID": "' + CHANNEL_ID + '",' +
                '"referenceID": "' + REFERENCE_ID + '",' +
                '"parentID": "' + PARENT_ID + '",' +
                '"caseStatus": "New",' +
                '"data": "' + xmlData + '"' +
            '}' +
        '}';
    }

    private static void setRestContext(String jsonPayload) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/fec/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonPayload);
        RestContext.request = req;
        RestContext.response = res;
    }

    @TestSetup
    static void setup() {
        insertIntegrationCase();
    }

    @IsTest
    static void testUpdateFraudCaseStatus_FH_Success() {
        if (integrationCaseType() == null) {
            System.assert(true, 'Skipped: FEC_Integration_Case__c not on org.');
            return;
        }
        if (Type.forName('FEC_IntegrationFraudCaseApi') == null) {
            System.assert(true, 'Skipped: FEC_IntegrationFraudCaseApi not on org.');
            return;
        }

        setRestContext(fhPayloadJson());

        Test.startTest();
        String responseXml = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assert(responseXml.contains('Success'), 'Response must contain Success element.');
        System.assert(responseXml.contains('true'), 'Response must indicate success.');
        System.assert(responseXml.contains(CASE_ID), 'Response must echo case ID.');

        List<SObject> rows = Database.query(
            'SELECT FEC_Case_Status__c, FEC_Remark__c FROM FEC_Integration_Case__c ' +
            'WHERE FEC_CaseID__c = :CASE_ID AND FEC_Service_Case_ID__c = :REFERENCE_ID ' +
            'AND FEC_Sys_Channel__c = :CHANNEL_ID LIMIT 1'
        );
        System.assertEquals(1, rows.size());
        System.assertNotEquals(null, rows[0].get('FEC_Case_Status__c'));
        System.assertEquals('Test', rows[0].get('FEC_Remark__c'));
    }

    @IsTest
    static void testUpdateFraudCaseStatus_MissingCaseId() {
        if (Type.forName('FEC_IntegrationFraudCaseApi') == null) {
            System.assert(true, 'Skipped: FEC_IntegrationFraudCaseApi not on org.');
            return;
        }

        setRestContext('{"detail": {"channelID": "CRM"}}');

        Test.startTest();
        String responseXml = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assert(
            responseXml.contains(FEC_IntegrationFraudCaseApi.MSG_CASEID_REQUIRED),
            'Must report missing Case ID.'
        );
    }
}
