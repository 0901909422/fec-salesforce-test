public with sharing class FEC_ChatHistoryController {
    public class ChatDataWrapper {
        @AuraEnabled public List<FEC_ChatHistory__c> messages;
        @AuraEnabled public Map<String, String> fileMap; // Map<FileName, ContentVersionId>
    }
    
    /** * getChatMessages
    * Retrieves chat history messages and associated file attachments for a given case.
    * @param caseId: ID of the Case to retrieve chat history for.
    * @return ChatDataWrapper: Wrapper containing messages list and file map.
    */
    @AuraEnabled(cacheable=true)
    public static ChatDataWrapper getChatMessages(Id caseId) {

        ChatDataWrapper result = new ChatDataWrapper();
        result.messages = [
            SELECT Id,FEC_Message__c, FEC_SenderName__c, FEC_MessageType__c, FEC_CreatedAt__c,FEC_IsAgent__c,CreatedById
            FROM FEC_ChatHistory__c 
            WHERE FEC_Case__c = :caseId 
            ORDER BY FEC_CreatedAt__c ASC
        ];

        List<ContentVersion> files = [
            SELECT Id, Title, FileExtension 
            FROM ContentVersion 
            WHERE FirstPublishLocationId = :caseId 
            AND IsLatest = true
        ];
        result.fileMap = new Map<String, String>();
        for(ContentVersion cv : files) {
            // Note: Key is Title (file name), Value is Id.
            // Ensure FEC_Message__c stores the correct Title of the file (may or may not include file extension depending on upload method).
            result.fileMap.put(cv.Title, cv.Id);
            
            // Fallback case where FEC_Message__c stores file name with extension (e.g., image.png).
            if (cv.FileExtension != null) {
                 result.fileMap.put(cv.Title + '.' + cv.FileExtension, cv.Id);
            }
        }
        return result;
    }
}