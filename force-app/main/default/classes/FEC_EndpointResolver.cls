/**
 * FEC_EndpointResolver
 * Centralized utility for resolving API endpoints from FEC_API_Config__mdt.
 * Supports both Named Credential mode and direct URL mode.
 *
 * When FEC_Use_Named_Credential__c = true:
 *   endpoint = 'callout:<Named_Credential>' + FEC_Endpoint__c
 *   API key header is NOT added (Named Credential handles auth).
 *
 * When FEC_Use_Named_Credential__c = false:
 *   endpoint = FEC_Endpoint__c (full URL)
 *   API key header is added from FEC_API_Key__c if present.
 */
public with sharing class FEC_EndpointResolver {

    private static final String CALLOUT_PREFIX = 'callout:';
    private static final String HEADER_API_KEY = 'X-API-KEY';

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
        if (cfg.FEC_Use_Named_Credential__c && String.isNotBlank(cfg.FEC_Named_Credential__c)) {
            return CALLOUT_PREFIX + cfg.FEC_Named_Credential__c + cfg.FEC_Endpoint__c;
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
        if (!cfg.FEC_Use_Named_Credential__c && String.isNotBlank(cfg.FEC_API_Key__c)) {
            req.setHeader(HEADER_API_KEY, cfg.FEC_API_Key__c);
        }
    }
}
