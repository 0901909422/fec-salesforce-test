public with sharing class FEC_ChatHistoryController {
    public class ChatDataWrapper {
        @AuraEnabled public List<FEC_ChatHistory__c> messages;
        @AuraEnabled public Map<String, String> fileMap; // Map<Tên File, ContentVersionId>
    }
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
            // Lưu ý: Key là Title (tên file), Value là Id
            // Bạn cần đảm bảo FEC_Message__c lưu đúng Title của file (thường không bao gồm đuôi file nếu upload qua chuẩn Salesforce, hoặc bao gồm tùy logic của bạn)
            result.fileMap.put(cv.Title, cv.Id);
            
            // Phòng hờ trường hợp FEC_Message__c lưu cả đuôi file (ví dụ: image.png)
            if (cv.FileExtension != null) {
                 result.fileMap.put(cv.Title + '.' + cv.FileExtension, cv.Id);
            }
        }


        System.debug('caseId: ' + caseId);
        // List<FEC_ChatHistory__c> chatMessages = [SELECT Id, 
        //                FEC_Message__c, 
        //                FEC_SenderName__c, 
        //                FEC_MessageType__c, 
        //                FEC_CreatedAt__c,
        //                FEC_IsAgent__c,
        //                CreatedById
        //         FROM FEC_ChatHistory__c 
        //         WHERE FEC_Case__c = :caseId 
        //         ORDER BY FEC_CreatedAt__c ASC];
        // System.debug('chatMessages: ');
        // System.debug(chatMessages);
        // return chatMessages;
        return result;
    }
}