/**
 * FEC_EndpointResolverTest
 * Tests for FEC_EndpointResolver — endpoint resolution và auth header application.
 * Uses FEC_Campaign_Ingest custom metadata record from the org.
 */
@isTest
private class FEC_EndpointResolverTest {

    private static final String EXISTING_CONFIG_NAME = 'FEC_Campaign_Ingest';
    private static final String INVALID_CONFIG_NAME = 'FEC_NonExistentConfig_xyz';

    @isTest
    static void testResolveEndpoint_ReturnsCalloutPrefix_WhenNamedCredentialExists() {
        // Force cache: Named Credential "exists"
        FEC_EndpointResolver.namedCredentialCache.put('FEC_API', true);

        Test.startTest();
        String endpoint = FEC_EndpointResolver.resolveEndpoint(EXISTING_CONFIG_NAME);
        Test.stopTest();

        Assert.isTrue(endpoint.startsWith('callout:'),
            'Endpoint should start with callout: when NC exists, got: ' + endpoint);
        Assert.isTrue(endpoint.contains('FEC_API'),
            'Endpoint should contain Named Credential name, got: ' + endpoint);
    }

    @isTest
    static void testResolveEndpoint_ReturnsFullUrl_WhenNamedCredentialMissing() {
        // Force cache: Named Credential "does not exist" → fallback to direct URL
        FEC_EndpointResolver.namedCredentialCache.put('FEC_API', false);

        Test.startTest();
        String endpoint = FEC_EndpointResolver.resolveEndpoint(EXISTING_CONFIG_NAME);
        Test.stopTest();

        Assert.isFalse(endpoint.startsWith('callout:'),
            'Endpoint should NOT start with callout: when NC missing, got: ' + endpoint);
        Assert.isTrue(String.isNotBlank(endpoint),
            'Endpoint should not be blank');
    }

    @isTest
    static void testResolveEndpoint_ThrowsCalloutException_WhenConfigNotFound() {
        Boolean thrown = false;
        Test.startTest();
        try {
            FEC_EndpointResolver.resolveEndpoint(INVALID_CONFIG_NAME);
        } catch (CalloutException ex) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown, 'Should throw CalloutException for invalid config name');
    }

    @isTest
    static void testApplyAuthHeaders_AddsApiKey_WhenNamedCredentialMissing() {
        // NC missing → API key header should be applied
        FEC_EndpointResolver.namedCredentialCache.put('FEC_API', false);

        HttpRequest req = new HttpRequest();

        Test.startTest();
        FEC_EndpointResolver.applyAuthHeaders(req, EXISTING_CONFIG_NAME);
        Test.stopTest();

        String apiKey = req.getHeader('X-API-KEY');
        Assert.isTrue(String.isNotBlank(apiKey),
            'X-API-KEY header should be set when NC is missing');
    }

    @isTest
    static void testApplyAuthHeaders_DoesNotAddApiKey_WhenNamedCredentialExists() {
        // NC exists → header should NOT be applied (NC handles auth)
        FEC_EndpointResolver.namedCredentialCache.put('FEC_API', true);

        HttpRequest req = new HttpRequest();

        Test.startTest();
        FEC_EndpointResolver.applyAuthHeaders(req, EXISTING_CONFIG_NAME);
        Test.stopTest();

        String apiKey = req.getHeader('X-API-KEY');
        Assert.isTrue(String.isBlank(apiKey),
            'X-API-KEY header should NOT be set when NC exists');
    }

    @isTest
    static void testApplyAuthHeaders_NoOp_WhenConfigNotFound() {
        HttpRequest req = new HttpRequest();

        Test.startTest();
        // Should silently return without error
        FEC_EndpointResolver.applyAuthHeaders(req, INVALID_CONFIG_NAME);
        Test.stopTest();

        String apiKey = req.getHeader('X-API-KEY');
        Assert.isTrue(String.isBlank(apiKey),
            'Header should not be set when config does not exist');
    }

    @isTest
    static void testNamedCredentialExists_ReturnsFalse_ForBlankName() {
        Test.startTest();
        Boolean result = FEC_EndpointResolver.namedCredentialExists(null);
        Boolean resultBlank = FEC_EndpointResolver.namedCredentialExists('');
        Test.stopTest();

        Assert.areEqual(false, result, 'null name should return false');
        Assert.areEqual(false, resultBlank, 'blank name should return false');
    }

    @isTest
    static void testNamedCredentialExists_UsesCache_OnRepeatedCalls() {
        // Pre-seed cache with a sentinel value
        String key = 'FEC_TEST_NC_XYZ_' + Crypto.getRandomInteger();
        FEC_EndpointResolver.namedCredentialCache.put(key, true);

        Test.startTest();
        Boolean first = FEC_EndpointResolver.namedCredentialExists(key);
        Boolean second = FEC_EndpointResolver.namedCredentialExists(key);
        Test.stopTest();

        Assert.areEqual(true, first, 'Should hit cache and return seeded value');
        Assert.areEqual(true, second, 'Repeated call should return same cached value');
    }
}
