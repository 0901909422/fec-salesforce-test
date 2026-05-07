public with sharing class FEC_Utils {

    // ===== CASE & RECORD LOOKUP METHODS =====

    /**
     * Checks if a Case already exists using the External Interaction ID (Session ID).
     * Used to prevent duplicate case creation for the same chat session.
     * 
     * @param strExtInteractionID - External Interaction ID (Chat Session ID from ChatHub)
     * @return String - Case ID if found, null if no matching case exists
     * @throws None - Returns null gracefully if record not found
     */
    @AuraEnabled
    public static String checkExistCaseByExtInteractionID(String strExtInteractionID) {
        List<Case> cases = [
            SELECT Id
            FROM Case
            WHERE FEC_External_Interaction_ID__c = :strExtInteractionID
            LIMIT 1
        ];

        return cases.isEmpty() ? null : cases[0].Id;
    }

    @AuraEnabled
    public static void updateExtInteractionIDForCase(String caseID, String strExtInteractionID) {
        System.debug('Updating Case ID: ' + caseID + ' with new External Interaction ID: ' + strExtInteractionID);
        Case caseToUpdate = new Case(
            Id = caseID,
            FEC_External_Interaction_ID__c = strExtInteractionID
        );
        System.debug('case before update: ' + caseToUpdate);
        update caseToUpdate;
    }

    /**
     * Retrieves Case ID by searching for Pega ID (internal case reference number).
     * Maps external Pega ID to internal Salesforce Case ID for cross-system integration.
     * 
     * @param pegaID - Pega ID string to search for (from ChatHub/external system)
     * @return String - Salesforce Case ID if found, null if no matching case exists
     * @throws None - Returns null gracefully if record not found
     */
    @AuraEnabled
    public static String getInteractionIdFromPegaId(String pegaID) {
        List<Case> cases = [
            SELECT Id
            FROM Case
            WHERE FEC_ID_Search__c = :pegaID
            LIMIT 1
        ];
        return cases.isEmpty() ? null : cases[0].Id;
    }

    // ===== DATA MAPPING & TRANSFORMATION METHODS =====

    /**
     * Maps chat channel names from ChatHub to Salesforce Interaction Channel labels.
     * Standardizes channel naming across systems for consistent record tagging.
     * 
     * Channel Mapping:
     * - 'facebook' => 'Facebook'
     * - 'appchat'  => 'FE App'
     * - 'zalo'     => 'Zalo'
     * - 'webchat'  => 'Website'
     * - others     => 'Other' (default)
     * 
     * @param strChatChannel - Channel name from ChatHub (case-insensitive)
     * @return String - Mapped Interaction Channel label for Salesforce
     */
    @AuraEnabled(cacheable=true)
    public static String getInteractionChannel(String strChatChannel) {
        // Guard: Handle null or blank input safely
        if (String.isBlank(strChatChannel)) {
            return 'Other';
        }
        
        // Define mapping from ChatHub channel names to Salesforce labels
        Map<String, String> mapChannels = new Map<String, String>{
            'facebook' => 'Facebook',
            'appchat'  => 'FE App',
            'zalo'     => 'Zalo',
            'webchat'  => 'Website'
        };

        String strChatChannelLower = strChatChannel.toLowerCase();

        if (mapChannels.containsKey(strChatChannelLower)) {
            return mapChannels.get(strChatChannelLower);
        }
        
        return 'Other';
    }

    /**
     * Maps KYC (Know Your Customer) status from ChatHub to internal representation.
     * Converts external KYC verification status to standardized internal values.
     * 
     * KYC Mapping:
     * - 'KYC' or 'KYCed'  => 'Pass'
     * - 'NOT KYC'         => 'Fail'
     * - others            => 'Other'
     * 
     * @param strKYC - KYC status string from ChatHub/external system
     * @return String - Mapped KYC status ('Pass', 'Fail', or 'Other')
     */
    @AuraEnabled(cacheable=true)
    public static String mappingKYCs(String strKYC) {
        // Guard: Handle null or blank input safely
        if (String.isBlank(strKYC)) {
            return 'Other';
        }
        
        // Define mapping for KYC status values
        Map<String, String> mapKYCs = new Map<String, String>{
            'KYC'     => 'Pass',
            'NOT KYC' => 'Fail',
            'KYCed'   => 'Pass'
        };
        
        if (mapKYCs.containsKey(strKYC)) {
            return mapKYCs.get(strKYC);
        }
        
        return 'Other';
    }

    /**
     * Converts Datetime to formatted string in GMT format.
     * Used for exporting datetime values to external systems (ChatHub, APIs, etc).
     * 
     * Format Output: YYYYMMDDThhmmss.0 GMT (e.g., "20260312T143902.0 GMT")
     * 
     * @param dtDateTime - Datetime value to format (system timezone)
     * @return String - Formatted datetime string in GMT, or empty string if null
     */
    @AuraEnabled
    public static String formatDateTimeToString(Datetime dtDateTime) {
        if (dtDateTime == null) {
            return '';
        }
        return dtDateTime.formatGmt(FEC_ConstantCommon.DATETIME_FORMAT_GMT);
    }

    /**
     * Parses datetime string from ChatHub into Salesforce Datetime object.
     * Handles GMT timezone offset format (e.g., "2026-02-03 14:39:02 GMT+0700").
     * Automatically converts to UTC for consistent storage.
     * 
     * Input Format: "YYYY-MM-DD HH:mm:ss GMT±HHMM"
     * Processing:
     * 1. Removes " GMT" prefix to isolate timezone offset
     * 2. Converts space to 'T' for ISO 8601 compliance
     * 3. Uses JSON.deserialize for automatic UTC conversion
     * 
     * Fallback: Attempts standard Datetime.valueOf parsing if ISO 8601 fails
     * 
     * @param strDateTime - Datetime string from ChatHub with timezone offset
     * @return Datetime - Converted Datetime object (UTC), or null if parse fails
     * @throws None - Returns null gracefully on parsing errors
     */
    public static Datetime parseChatHubDatetime(String strDateTime) {
        if (String.isBlank(strDateTime)) {
            return null;
        }
        
        try {
            String jsonStr = strDateTime;

            // Handle GMT timezone format (e.g., "2026-02-03 14:39:02 GMT+0700")
            if (jsonStr.contains('GMT')) {
                // Step 1: Remove " GMT" prefix to isolate timezone offset
                // Example: "2026-02-03 14:39:02 GMT+0700" => "2026-02-03 14:39:02+0700"
                jsonStr = jsonStr.replace(' GMT', '');
                
                // Step 2: Replace space with 'T' for ISO 8601 format
                // Example: "2026-02-03 14:39:02+0700" => "2026-02-03T14:39:02+0700"
                jsonStr = jsonStr.replace(' ', 'T');
            }
            
            // Use JSON.deserialize to automatically calculate UTC offset and store correct UTC value
            return (Datetime)JSON.deserialize('"' + jsonStr + '"', Datetime.class);

        } catch (Exception e) {
            // Fallback: Attempt standard Datetime.valueOf parsing
            try {
                return Datetime.valueOf(strDateTime);
            } catch (Exception ex) {
                // Both parsing methods failed, return null
                return null;
            }
        }
    }

    // ===== FILE & HTTP COMMUNICATION METHODS =====

    /**
     * Downloads file from URL and returns as Blob (binary format).
     * Used for retrieving attachments/documents from S3 or external URLs.
     * 
     * @param fileUrl - Complete URL to file (S3 URL or direct download link)
     * @return Blob - Binary data of downloaded file
     * @throws CalloutException - If URL is blank or HTTP request fails
     * 
     * Notes:
     * - HTTP Timeout: 60 seconds (Salesforce limit: 120 seconds)
     * - Requires Named Credential or remote site whitelist for external URLs
     * - Only succeeds on HTTP 200 status code
     */
    public static Blob downloadFileAsBlob(String fileUrl) {
        if (String.isBlank(fileUrl)) {
            throw new CalloutException(System.Label.FEC_Error_FileURL_Empty);
        }

        HttpResponse response = sendRequest(FEC_ConstantCommon.API_METHOD_GET, fileUrl, null, null);
        
        if (response != null && response.getStatusCode() == FEC_ConstantCommon.HTTP_STATUS_OK) {
            return response.getBodyAsBlob();
        } else {
            Integer statusCode = response != null ? response.getStatusCode() : 0;
            throw new CalloutException(System.Label.FEC_Error_DownloadFile + statusCode);
        }
    }

    /**
     * Sends generic HTTP request to external API endpoints.
     * Unified method for all REST API calls (GET, POST, PUT, DELETE).
     * 
     * Configuration:
     * - Default Content-Type: application/json
     * - Default Accept: application/json
     * - HTTP Timeout: 120 seconds (Salesforce maximum)
     * - Supports custom headers and request body
     * 
     * @param method - HTTP method: 'GET', 'POST', 'PUT', 'DELETE'
     * @param endpoint - API endpoint URL (can use Named Credential format)
     * @param body - JSON request body (null for GET requests)
     * @param headers - Map of custom headers (null if not needed)
     * @return HttpResponse - Response object containing status, headers, and body
     * @throws None - Returns null on connection error (see System.debug logs)
     * 
     * Usage Example:
     * Map<String, String> customHeaders = new Map<String, String>{
     *     'Authorization' => 'Bearer token123'
     * };
     * HttpResponse resp = FEC_Utils.sendRequest('POST', 'https://api.example.com/data', 
     *     '{"name":"John"}', customHeaders);
     */
    public static HttpResponse sendRequest(String method, String endpoint, String body, Map<String, String> headers) {
        // Build merged headers: default JSON headers + custom headers
        Map<String, String> mergedHeaders = new Map<String, String>{
            FEC_ConstantCommon.HTTP_HEADER_CONTENT_TYPE => FEC_ConstantCommon.API_CONTENT_TYPE_JSON_UTF8,
            FEC_ConstantCommon.HTTP_HEADER_ACCEPT => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
        };

        // Add/override with custom headers if provided
        if (headers != null) {
            mergedHeaders.putAll(headers);
        }

        // For GET requests, do not send body
        String requestBody = (String.isNotBlank(body) && method != FEC_ConstantCommon.API_METHOD_GET) ? body : null;

        try {
            HttpResponse response = FEC_CommonUltils.calloutApiWithHeaders(endpoint, method, mergedHeaders, requestBody);
            System.debug('HTTP Status Code: ' + response.getStatusCode());
            System.debug('HTTP Response Body: ' + response.getBody());         
            return response;
        } catch (Exception e) {
            System.debug('API Connection Error: ' + e.getMessage());
            return null; 
        }
    }
}