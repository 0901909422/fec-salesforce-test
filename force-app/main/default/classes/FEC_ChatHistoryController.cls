public with sharing class FEC_ChatHistoryController {
    public class ChatDataWrapper {
        @AuraEnabled public List<FEC_ChatHistory__c> messages;
        @AuraEnabled public Map<String, String> fileMap; // Map<FileName, ContentVersionId>
        @AuraEnabled public Boolean isChatAutomation;
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
            SELECT Id,FEC_Message__c, FEC_SenderName__c, FEC_MessageType__c, FEC_CreatedAt__c,FEC_IsAgent__c,FEC_Is_Manual__c,CreatedById
            FROM FEC_ChatHistory__c 
            WHERE FEC_Case__c = :caseId 
            ORDER BY FEC_CreatedAt__c ASC
        ];

        // Query Case to check if it's Chat Automation
        List<Case> cases = [SELECT FEC_Is_Chat_Automation__c FROM Case WHERE Id = :caseId LIMIT 1];
        result.isChatAutomation = !cases.isEmpty() && cases[0].FEC_Is_Chat_Automation__c;

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
    * Saves a manual chat message entered by the user for non-automation cases.
    * @param caseId: ID of the Case to save chat history for.
    * @param message: The message text to save.
    * @return Id: The Id of the newly created FEC_ChatHistory__c record.
    */
    @AuraEnabled
    public static Id saveManualChatHistory(Id caseId, String message) {
        if (String.isBlank(message)) {
            throw new AuraHandledException('Message cannot be blank.');
        }
        
        User currentUser = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        
        FEC_ChatHistory__c chatHistory = new FEC_ChatHistory__c();
        chatHistory.FEC_Case__c = caseId;
        chatHistory.FEC_Message__c = message;
        chatHistory.FEC_SenderName__c = currentUser.Name;
        chatHistory.FEC_MessageType__c = 'text';
        chatHistory.FEC_IsAgent__c = true;
        chatHistory.FEC_Is_Manual__c = true;
        chatHistory.FEC_CreatedAt__c = Datetime.now();
        
        insert chatHistory;
        return chatHistory.Id;
    }
}