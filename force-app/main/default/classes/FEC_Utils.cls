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
        String strCaseID = null;
        
        // Find Case by the External Interaction ID field
        // Sử dụng SOQL for Loop để tránh limit heap size (nếu cần xử lý nhiều bản ghi)
        // Ở đây là hàm check đơn lẻ, nhưng vẫn đảm bảo cú pháp.
        for (Case caseRecord : [
            SELECT Id
            FROM Case
            WHERE FEC_ExternalInteractionID__c = :strExtInteractionID
            LIMIT 1
        ]) {
            strCaseID = caseRecord.Id;
        }

        return strCaseID;
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
        // Tương tự logic trong Core JS getInteractionChannel(chatChannel) [cite: 33]
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

    // Example of using standard data type method (tương tự formatDatetime trong Core JS [cite: 34])
    /** * formatDateTimeToString
    * Converts a Datetime to a custom formatted string (e.g., YYYYMMDDThhmmss.0 GMT).
    * @param dtDateTime: Datetime value to format.
    * @return strFormatted: Formatted Datetime string.
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */ 
    public static String formatDateTimeToString(Datetime dtDateTime) {
        // Example of using standard Salesforce methods
        // Link Refer: https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm
        String strYear = String.valueOf(dtDateTime.yearGmt());
        String strMonth = String.valueOf(dtDateTime.monthGmt()).leftPad(2, '0');
        String strDay = String.valueOf(dtDateTime.dayGmt()).leftPad(2, '0');
        String strHour = String.valueOf(dtDateTime.hourGmt()).leftPad(2, '0');
        String strMinute = String.valueOf(dtDateTime.minuteGmt()).leftPad(2, '0');
        String strSecond = String.valueOf(dtDateTime.secondGmt()).leftPad(2, '0');

        return strYear + strMonth + strDay + 'T' + strHour + strMinute + strSecond + '.0 GMT';
    }
}