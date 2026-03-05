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
        // String strCaseID = null;
        
        // Find Case by the External Interaction ID field
        // Sử dụng SOQL for Loop để tránh limit heap size (nếu cần xử lý nhiều bản ghi)
        // Ở đây là hàm check đơn lẻ, nhưng vẫn đảm bảo cú pháp.
        // for (Case caseRecord : [
        //     SELECT Id
        //     FROM Case
        //     WHERE FEC_External_Interaction_ID__c = :strExtInteractionID
        //     LIMIT 1
        // ]) {
        //     strCaseID = caseRecord.Id;
        // }
        // return strCaseID;

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
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */ 
    // old code
    // @AuraEnabled
    // public static String formatDateTimeToString(Datetime dtDateTime) {
    //     // Example of using standard Salesforce methods
    //     // Link Refer: https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm
    //     String strYear = String.valueOf(dtDateTime.yearGmt());
    //     String strMonth = String.valueOf(dtDateTime.monthGmt()).leftPad(2, '0');
    //     String strDay = String.valueOf(dtDateTime.dayGmt()).leftPad(2, '0');
    //     String strHour = String.valueOf(dtDateTime.hourGmt()).leftPad(2, '0');
    //     String strMinute = String.valueOf(dtDateTime.minuteGmt()).leftPad(2, '0');
    //     String strSecond = String.valueOf(dtDateTime.secondGmt()).leftPad(2, '0');

    //     return strYear + strMonth + strDay + 'T' + strHour + strMinute + strSecond + '.0 GMT';
    // }

    // new code
    @AuraEnabled
    public static String formatDateTimeToString(Datetime dtDateTime) {
        if (dtDateTime == null) return '';
        return dtDateTime.formatGmt('yyyyMMdd\'T\'HHmmss\'.0 GMT\'');
    }

    /** * parseChatHubDatetime
    * Parses datetime string from ChatHub to Datetime object.
    * Handles ISO 8601 format and similar datetime strings.
    * @param strDateTime: Datetime string from ChatHub.
    * @return dtParsed: Parsed Datetime object, or null if parsing fails.
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */
    // Old code
    // public static Datetime parseChatHubDatetime(String strDateTime) {
    //     if (String.isBlank(strDateTime)) {
    //         return null;
    //     }
        
    //     try {
    //         // Try parsing ISO 8601 format (e.g., 2025-12-03T10:30:45.000Z or 2025-12-03T10:30:45)
    //         // Remove 'Z' suffix if present
    //         System.debug('### [FEC] parseChatHubDatetime Input strDateTime: ' + strDateTime);

    //         String strCleanDateTime = strDateTime.removeEnd('Z');
            
    //         // Handle format like "2025-12-03T10:30:45.000"
    //         if (strCleanDateTime.contains('T')) {
    //             return Datetime.valueOfGmt(strCleanDateTime.replace('T', ' '));
    //         }
            
    //         // Fallback: Try standard parsing
    //         return Datetime.valueOf(strDateTime);
    //     } catch (Exception e) {
    //         System.debug('### [FEC] Error parsing datetime: ' + strDateTime + ' - Error: ' + e.getMessage());
    //         return null;
    //     }
    // }

    // New code
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
            // Goal: Transform "2026-02-03 14:39:02 GMT+0700" into ISO 8601 format "2026-02-03T14:39:02+0700"
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
            System.debug('### [FEC] Error parsing datetime: ' + strDateTime + ' - Error: ' + e.getMessage());
            
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
}