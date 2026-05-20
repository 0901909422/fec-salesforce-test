public with sharing class FEC_ChatHistoryController {
    public class ChatDataWrapper {
        @AuraEnabled public List<FEC_ChatHistory__c> messages;
        @AuraEnabled public Map<String, String> fileMap; // Map<FileName, ContentVersionId>
        @AuraEnabled public Boolean isChatAutomation;
        @AuraEnabled public Boolean hasManualChatHistory;
        @AuraEnabled public String manualChatHistoryContent;
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

        // Query Case to check if it's Chat Automation and if manual chat history exists
        List<Case> cases = [SELECT FEC_Is_Chat_Automation__c, FEC_Chat_History__c FROM Case WHERE Id = :caseId LIMIT 1];
        result.isChatAutomation = !cases.isEmpty() && cases[0].FEC_Is_Chat_Automation__c;
        result.hasManualChatHistory = !cases.isEmpty() && String.isNotBlank(cases[0].FEC_Chat_History__c);
        result.manualChatHistoryContent = !cases.isEmpty() ? cases[0].FEC_Chat_History__c : null;

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

    /** * saveManualChatHistory
    * Saves a manual chat history message directly to the Case's FEC_Chat_History__c field.
    * @param caseId: ID of the Case to save chat history for.
    * @param message: The message text to save.
    */
    @AuraEnabled
    public static void saveManualChatHistory(Id caseId, String message) {
        if (String.isBlank(message)) {
            throw new AuraHandledException('Message cannot be blank.');
        }
        
        update new Case(Id = caseId, FEC_Chat_History__c = message);
    }
}