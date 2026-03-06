/** * FEC_Utils
* Utility class for common functions such as data formatting and SOQL lookups.
* @created    : 2025/12/03 long.nguyen.50
* @modified   : 
*/ 
public with sharing class FEC_Utils {

    /** * checkExistCaseByExtInteractionID
    * Checks if a Case already exists using the External Interaction ID (Session ID).
    * @param strExtInteractionID: External Interaction ID (Session ID)
    * @return strCaseID: ID of the existing Case, or null if not found.
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
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
    
    /** * getInteractionChannel
    * Maps the chat channel name from ChatHub to the required Interaction Channel label.
    * @param strChatChannel: Chat channel name from ChatHub (e.g., 'facebook', 'zalo').
    * @return strInteractionChannel: Mapped Interaction Channel label (e.g., 'Facebook', 'Zalo').
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */ 
    @AuraEnabled(cacheable=true)
    public static String getInteractionChannel(String strChatChannel) {
        // Handle Null/Blank input safely
        if (String.isBlank(strChatChannel)) {
            return 'Other';
        }
        
        // Map channel names similar to Core JS getInteractionChannel logic
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

    // Example of using standard data type method
    /** * formatDateTimeToString
    * Converts a Datetime to a custom formatted string (e.g., YYYYMMDDThhmmss.0 GMT).
    * @param dtDateTime: Datetime value to format.
    * @return strFormatted: Formatted Datetime string.
    */ 
    @AuraEnabled
    public static String formatDateTimeToString(Datetime dtDateTime) {
        if (dtDateTime == null) return '';
        return dtDateTime.formatGmt('yyyyMMdd\'T\'HHmmss\'.0 GMT\'');
    }

    /**
     * Parses datetime string from ChatHub (supports GMT+XXXX format).
     * Input: string datetime example "2026-02-03 14:39:02 GMT+0700"
     * Output: Datetime Object (converted to system standard UTC)
     */
    public static Datetime parseChatHubDatetime(String strDateTime) {
        if (String.isBlank(strDateTime)) {
            return null;
        }
        
        try {
            String jsonStr = strDateTime;

            // Handle special cases containing "GMT" (e.g., "2026-02-03 14:39:02 GMT+0700")
            // Example: Transform "2026-02-03 14:39:02 GMT+0700" into ISO 8601 format "2026-02-03T14:39:02+0700"
            if (jsonStr.contains('GMT')) {
                // 1. Remove the redundant " GMT" string
                // Result: "2026-02-03 14:39:02+0700"
                jsonStr = jsonStr.replace(' GMT', ''); 
                
                // 2. Replace the space between date and time with 'T' to match ISO 8601 standard
                // Result: "2026-02-03T14:39:02+0700"
                jsonStr = jsonStr.replace(' ', 'T');
            }
            
            // Use JSON.deserialize so Salesforce automatically calculates the Offset (+7h, -5h, etc.)
            // and stores the correct UTC value.
            return (Datetime)JSON.deserialize('"' + jsonStr + '"', Datetime.class);

        } catch (Exception e) {
            // Fallback: Attempt standard Datetime.valueOf parsing if the above method fails
            try {
                return Datetime.valueOf(strDateTime);
            } catch (Exception ex) {
                return null;
            }
        }
    }

    /** * mappingKYCs
    * Maps KYC status from ChatHub to internal representation.
    * @param strKYC: KYC status from ChatHub (e.g., 'KYC', 'NOT KYC').
    * @return strMappedKYC: Mapped KYC status ('Pass', 'Fail', 'Other').
    * @created: 
    */
    @AuraEnabled(cacheable=true)
    public static String mappingKYCs (String strKYC) {
        // Handle Null/Blank input safely
        if (String.isBlank(strKYC)) {
            return 'Other';
        }
        Map<String, String> mapKYCs = new Map<String, String>{
            'KYC' => 'Pass',
            'NOT KYC'  => 'Fail',
            'KYCed' => 'Pass'
        };
        if (mapKYCs.containsKey(strKYC)) {
            return mapKYCs.get(strKYC);
        }
        return 'Other';
    }

    /** * getInteractionIdFromPegaId
    * Retrieves the Case ID by searching for the Pega ID.
    * @param pegaID: Pega ID to search for.
    * @return caseId: ID of the found Case, or null if not found.
    * @created: 
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

    /**
     * Tải file từ URL và trả về định dạng Blob
     * @param fileUrl: Đường dẫn (S3 URL) của file cần tải
     * @return Blob: Dữ liệu nhị phân của file
     */
    public static Blob downloadFileAsBlob(String fileUrl) {
        if (String.isBlank(fileUrl)) {
            throw new CalloutException('File URL is empty');
        }

        HttpRequest request = new HttpRequest();
        request.setEndpoint(fileUrl);
        request.setMethod('GET');
        request.setTimeout(60000); // Timeout 60s
        
        Http http = new Http();
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() == 200) {
            return response.getBodyAsBlob();
        } else {
            throw new CalloutException('Error downloading file: HTTP ' + response.getStatusCode());
        }
    }
}