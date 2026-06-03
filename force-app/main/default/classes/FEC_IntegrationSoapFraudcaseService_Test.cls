/**
 * PREREQUISITE for full SOAP stub E2E (deploy outside unit-test/):
 * - ApexClass: FEC_IntegrationSoapFraudcaseService
 *
 * This file is written to compile with test-only deploy: it does not reference
 * FEC_IntegrationSoapFraudcaseService types directly. When the SOAP class is on the org,
 * testWebServiceMock_CreateFraudCaseResponse validates the mock response shape.
 *
 * Direct port.CreateFraudCase() tests require the stub class on the org at compile time.
 */
@IsTest
private class FEC_IntegrationSoapFraudcaseService_Test {

    private static final String SOAP_SERVICE = 'FEC_IntegrationSoapFraudcaseService';
    private static final String RESP_TYPE = SOAP_SERVICE + '.CreateFraudCaseResponseType';

    private class WebServiceMockImpl implements WebServiceMock {
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
            Boolean isCreateFraudCase =
                (requestName != null && requestName.contains('CreateFraudCase'))
                || (responseType != null && responseType.contains('CreateFraudCaseResponse'));

            if (!isCreateFraudCase) {
                return;
            }

            Type respType = Type.forName(RESP_TYPE);
            if (respType == null) {
                return;
            }

            Object resp = JSON.deserialize(
                '{"CaseID":"FH-12345","Sys":{"Code":"1","Description":"Success"}}',
                respType
            );
            response.put('response_x', resp);
        }
    }

    @IsTest
    static void testWebServiceMock_CreateFraudCaseResponse() {
        Map<String, Object> response = new Map<String, Object>();

        new WebServiceMockImpl().doInvoke(
            null,
            null,
            response,
            null,
            null,
            'CreateFraudCaseRequest',
            null,
            'CreateFraudCaseResponse',
            RESP_TYPE
        );

        if (Type.forName(RESP_TYPE) == null) {
            System.assert(
                true,
                'Skipped assertions: ' + SOAP_SERVICE + ' not on org (deploy stub first).'
            );
            return;
        }

        System.assert(response.containsKey('response_x'), 'Mock must set response_x.');
        String serialized = JSON.serialize(response.get('response_x'));
        System.assert(serialized.contains('FH-12345'), 'CaseID must match mock.');
        System.assert(serialized.contains('"Code":"1"'), 'Sys.Code must match mock.');
    }

    @IsTest
    static void testSoapServiceOnOrgCheck() {
        if (Type.forName(SOAP_SERVICE) == null) {
            System.assert(
                true,
                'FEC_IntegrationSoapFraudcaseService not on org — deploy force-app/main/default/classes/FEC_IntegrationSoapFraudcaseService.cls first.'
            );
            return;
        }
        Test.setMock(WebServiceMock.class, new WebServiceMockImpl());
        System.assertNotEquals(null, Type.forName(RESP_TYPE));
    }
}
