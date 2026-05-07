/**
 * FEC_EndpointResolver
 * Centralized utility for resolving API endpoints from FEC_API_Config__mdt.
 * Supports both Named Credential mode and direct URL mode, with auto-fallback.
 *
 * Resolution logic:
 *   1. If FEC_Use_Named_Credential__c = true AND Named Credential exists on org:
 *        endpoint = 'callout:<NC>' + <path extracted from FEC_Endpoint__c>
 *        API key header is NOT added (Named Credential handles auth).
 *   2. Otherwise (NC disabled OR NC not found on org):
 *        endpoint = FEC_Endpoint__c (full URL)
 *        API key header is added from FEC_API_Key__c if present.
 */
public with sharing class FEC_EndpointResolver {

    private static final String CALLOUT_PREFIX = 'callout:';
    private static final String HEADER_API_KEY = 'X-API-KEY';

    // Cache NamedCredential existence check per transaction to avoid repeated SOQL
    @TestVisible
    private static Map<String, Boolean> namedCredentialCache = new Map<String, Boolean>();

    /**
     * Resolves the full endpoint URL for a given config record.
     * @param configName  DeveloperName of the FEC_API_Config__mdt record
     * @return fully qualified endpoint string
     */
    public static String resolveEndpoint(String configName) {
        FEC_API_Config__mdt cfg = FEC_API_Config__mdt.getInstance(configName);
        if (cfg == null || String.isBlank(cfg.FEC_Endpoint__c)) {
            throw new CalloutException(System.Label.FEC_MSG_Endpoint_Null);
        }
        if (shouldUseNamedCredential(cfg)) {
            String path = extractPath(cfg.FEC_Endpoint__c);
            return CALLOUT_PREFIX + cfg.FEC_Named_Credential__c + path;
        }
        return cfg.FEC_Endpoint__c;
    }

    /**
     * Applies auth headers (API key) to the request when NOT using Named Credential.
     * When using Named Credential, headers are managed by the credential itself.
     * @param req         HttpRequest to set headers on
     * @param configName  DeveloperName of the FEC_API_Config__mdt record
     */
    public static void applyAuthHeaders(HttpRequest req, String configName) {
        FEC_API_Config__mdt cfg = FEC_API_Config__mdt.getInstance(configName);
        if (cfg == null) {
            return;
        }
        if (!shouldUseNamedCredential(cfg) && String.isNotBlank(cfg.FEC_API_Key__c)) {
            req.setHeader(HEADER_API_KEY, cfg.FEC_API_Key__c);
        }
    }

    // ─── Private Helpers ───────────────────────────────────────────

    /**
     * Returns true only when NC mode is enabled AND the referenced
     * Named Credential actually exists on the org.
     */
    private static Boolean shouldUseNamedCredential(FEC_API_Config__mdt cfg) {
        if (cfg == null || !cfg.FEC_Use_Named_Credential__c) {
            return false;
        }
        if (String.isBlank(cfg.FEC_Named_Credential__c)) {
            return false;
        }
        return namedCredentialExists(cfg.FEC_Named_Credential__c);
    }

    /**
     * Checks if a Named Credential exists on the org. Result is cached per transaction.
     */
    @TestVisible
    private static Boolean namedCredentialExists(String developerName) {
        if (String.isBlank(developerName)) {
            return false;
        }
        if (namedCredentialCache.containsKey(developerName)) {
            return namedCredentialCache.get(developerName);
        }
        Boolean exists = false;
        try {
            List<NamedCredential> ncs = [
                SELECT Id FROM NamedCredential
                WHERE DeveloperName = :developerName LIMIT 1
            ];
            exists = !ncs.isEmpty();
        } catch (Exception ex) {
            // Query fails if user lacks ViewSetup permission — treat as not found
            exists = false;
        }
        namedCredentialCache.put(developerName, exists);
        return exists;
    }

    /**
     * Extracts the path portion from a full URL. Returns input unchanged if parsing fails
     * or if input is already a path (starts with '/').
     */
    private static String extractPath(String endpoint) {
        if (String.isBlank(endpoint) || endpoint.startsWith('/')) {
            return endpoint;
        }
        try {
            Url parsed = new Url(endpoint);
            String path = parsed.getPath();
            return String.isBlank(path) ? '' : path;
        } catch (Exception ex) {
            return endpoint;
        }
    }
}
