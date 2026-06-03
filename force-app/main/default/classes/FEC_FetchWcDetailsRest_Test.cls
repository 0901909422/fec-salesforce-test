@IsTest
private class FEC_FetchWcDetailsRest_Test {
    private static RestRequest buildPostRequest(String body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/collections/v1/welcome-call-details';
        req.httpMethod = 'POST';
        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }
        return req;
    }

    private static Map<String, Object> parseResponse(RestResponse res) {
        System.assertNotEquals(null, res.responseBody, 'Response body should not be null.');
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    @IsTest
    static void testDoPost_blankBody_returnsBadRequest() {
        RestContext.request = buildPostRequest(null);
        RestContext.response = new RestResponse();

        Test.startTest();
        FEC_FetchWelcomeCallDetailsRestService.doPost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> payload = parseResponse(RestContext.response);
        Map<String, Object> sys = (Map<String, Object>) payload.get('Sys');
        System.assertEquals('-1', (String) sys.get('Code'));
        System.assertEquals('Error', (String) sys.get('Status'));
    }

    @IsTest
    static void testDoPost_invalidJson_returnsBadRequest() {
        RestContext.request = buildPostRequest('{invalid-json}');
        RestContext.response = new RestResponse();

        Test.startTest();
        FEC_FetchWelcomeCallDetailsRestService.doPost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> payload = parseResponse(RestContext.response);
        Map<String, Object> sys = (Map<String, Object>) payload.get('Sys');
        System.assertEquals('-1', (String) sys.get('Code'));
        System.assert(((String) sys.get('Description')).contains('Invalid JSON'));
    }

    @IsTest
    static void testDoPost_blankContract_returnsBadRequest() {
        RestContext.request = buildPostRequest(
            '{"RequestorID":"REQ-01","TransID":"T-1","DateTime":"2026-01-01T00:00:00.000Z","ContractNumber":"   "}'
        );
        RestContext.response = new RestResponse();

        Test.startTest();
        FEC_FetchWelcomeCallDetailsRestService.doPost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> payload = parseResponse(RestContext.response);
        Map<String, Object> sys = (Map<String, Object>) payload.get('Sys');
        System.assertEquals('-1', (String) sys.get('Code'));
        System.assertEquals('Contract number is blank', (String) sys.get('Description'));
    }

    @IsTest
    static void testDoPost_notFound_successCode1() {
        RestContext.request = buildPostRequest(
            '{"RequestorID":"REQ-02","TransID":"T-2","DateTime":"2026-01-01T00:00:00.000Z","ContractNumber":"NO-DATA-123"}'
        );
        RestContext.response = new RestResponse();

        Test.startTest();
        FEC_FetchWelcomeCallDetailsRestService.doPost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> payload = parseResponse(RestContext.response);
        Map<String, Object> sys = (Map<String, Object>) payload.get('Sys');
        System.assertEquals('Success', (String) sys.get('Status'));
        System.assertEquals('1', (String) sys.get('Code'));
        System.assertEquals('REQ02', (String) sys.get('RequestorID'));
    }

    @IsTest
    static void testDoPost_simulateCannotOpenCase_returnsFailureMinus2() {
        FEC_FetchWelcomeCallDetailsRestService.simulateCannotOpenCase = true;
        RestContext.request = buildPostRequest(
            '{"RequestorID":"REQ-03","TransID":"","DateTime":"","ContractNumber":"ANY-123"}'
        );
        RestContext.response = new RestResponse();

        Test.startTest();
        FEC_FetchWelcomeCallDetailsRestService.doPost();
        Test.stopTest();

        FEC_FetchWelcomeCallDetailsRestService.simulateCannotOpenCase = false;

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> payload = parseResponse(RestContext.response);
        Map<String, Object> sys = (Map<String, Object>) payload.get('Sys');
        System.assertEquals('Error', (String) sys.get('Status'));
        System.assertEquals('-2', (String) sys.get('Code'));
        System.assertEquals('Cannot open Case details', (String) sys.get('Description'));
    }
}
