/** * FEC_ChatHubCaseController
* Controller to handle various events received from ChatHub, including Case creation, 
* new message processing, and saving chat history/attachments.
* @created    : 2025/12/03 long.nguyen.50
* @modified   : 
*/ 
public with sharing class FEC_ChatHubCaseController {
    
    // Quy ước đặt tên biến: String: strName, Datetime: dtStartDate, List: listAccounts
    
    /** * createCaseOnNewSession
    * Handles the incoming 'createCaseRequestEvent' to create a new Case record.
    * @param strJsonData: JSON string containing chat session and customer info.
    * @return strCaseID: ID of the newly created Case or null/error string.
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */
    @AuraEnabled
    public static String createCaseOnNewSession(String strJsonData) {
        System.debug('### [FEC] createChatSessionCase Input: ' + strJsonData);
        try {
            if (String.isBlank(strJsonData)) {
                System.debug('### [FEC] Input JSON is empty');
                return null;
            }
    
            // 1. Parse JSON
            Map<String, Object> mapRaw = (Map<String, Object>)JSON.deserializeUntyped(strJsonData);
            
            // NULL CHECK: Ensure root map is not null
            if (mapRaw == null) return null;
    
            // 2. Safe Extraction of Child Maps
            // Initialize as empty maps if key is missing to avoid NullPointerException on .get()
            Object objSession = mapRaw.get('chatSession');
            Map<String, Object> mapSession = (objSession != null) ? (Map<String, Object>)objSession : new Map<String, Object>();
    
            Object objCustomer = mapRaw.get('customerInfo');
            Map<String, Object> mapCustomer = (objCustomer != null) ? (Map<String, Object>)objCustomer : new Map<String, Object>();
    
            // 3. Prepare DTO for FEC_CreateCaseHanlder
            FEC_CreateCaseHanlder.FEC_InteractionCaseDTO dto = new FEC_CreateCaseHanlder.FEC_InteractionCaseDTO();
            
            dto.channel = 'Chat'; 
            
            // Safe .get() calls (even if map is empty, .get() returns null, not Exception)
            dto.subChannel = FEC_Utils.getInteractionChannel((String)mapSession.get('chatChannel'));
            dto.externalInteractionId = (String)mapSession.get('sessionID');
            dto.phoneNumber = (String)mapCustomer.get('phoneNumber');
            dto.nationalId = (String)mapCustomer.get('nationalID');
            dto.kycResult = (String)mapCustomer.get('kYCStatus');
            
            // Optional: Validation
            if (String.isBlank(dto.externalInteractionId)) {
                 System.debug('### [FEC] Warning: Missing SessionID');
                 // Decide if you want to return null or continue
            }
    
            String strDtoJson = JSON.serialize(dto);
    
            // 4. Call existing Handler to create Case
            FEC_CreateCaseHanlder.FEC_InteractionCaseResponse response = FEC_CreateCaseHanlder.createInteractionCase(strDtoJson);
            
            return response.caseId;
    
        } catch (Exception e) {
            System.debug('### [FEC] Error in createChatSessionCase: ' + e.getMessage() + ' ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** * saveChatHistoryAndAttachment
    * Handles the incoming 'sessionHistoryByIdEvent' to save full chat history and attachments.
    * @param strJsonData: JSON string containing full chat history list.
    * @return isSuccess: Boolean indicating if the operation was successful.
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */ 
    @AuraEnabled
    public static Boolean saveChatHistoryAndAttachment(String strJsonData) {
        System.debug('### [FEC] saveChatHistory Input: ' + strJsonData);
        if (String.isBlank(strJsonData)) return false;

        List<FEC_ChatHistory__c> listHistoriesToInsert = new List<FEC_ChatHistory__c>();
        List<Object> listRawHistory = (List<Object>)JSON.deserializeUntyped(strJsonData);
        
        // Use Set to collect Case Ids to query if needed, avoiding SOQL in loop
        String strCaseId = '';

        // 1. Process Chat History
        for(Object obj : listRawHistory) {
            Map<String, Object> mapItem = (Map<String, Object>)obj;
            
            // Get PegaID (mapped to Case ID in SF)
            if(String.isBlank(strCaseId)) {
                strCaseId = (String)mapItem.get('pegaID');
            }

            FEC_ChatHistory__c objHistory = new FEC_ChatHistory__c();
            objHistory.FEC_Case__c = (String)mapItem.get('pegaID'); // Assuming pegaID is SF Case ID sent back earlier
            objHistory.FEC_SessionID__c = (String)mapItem.get('sessionID');
            objHistory.FEC_SenderName__c = (String)mapItem.get('senderName');
            objHistory.FEC_Message__c = (String)mapItem.get('message');
            objHistory.FEC_MessageType__c = (String)mapItem.get('messageType');
            objHistory.FEC_ChatChannel__c = (String)mapItem.get('chatChannel');
            
            // Handle Timestamp using Util
            String strCreatedAt = (String)mapItem.get('createdAt');
            // objHistory.FEC_ExternalCreatedAt__c = FEC_Utils.parseChatHubDatetime(strCreatedAt);

            listHistoriesToInsert.add(objHistory);

            // 2. Handle Attachment Logic
            // If message type is attachment, we might need to call the File Service
            if (objHistory.FEC_MessageType__c == 'attachment' || objHistory.FEC_MessageType__c == 'image') {
                 // Logic to call FEC_CreateCSCaseService or similar to download file from URL
                 // This should likely be an async call (Queueable/Future) to avoid holding the transaction
                 handleAttachmentAsync(strCaseId, (String)mapItem.get('message'), (String)mapItem.get('fileName'));
            }
        }

        try {
            if(!listHistoriesToInsert.isEmpty()) {
                insert listHistoriesToInsert;
            }
            return true;
        } catch (Exception e) {
            System.debug('### [FEC] Error saving history: ' + e.getMessage());
            return false;
        }
    }

    /**
     * Helper to handle attachment download asynchronously
     * @param strCaseId Case ID
     * @param strFileUrl URL from ChatHub
     * @param strFileName File Name
     */
    @future(callout=true)
    public static void handleAttachmentAsync(String strCaseId, String strFileUrl, String strFileName) {
        // Logic integration with FEC_CreateCSCaseService goes here
        // Example: FEC_CreateCSCaseService.saveFile(strCaseId, strFileUrl, strFileName);
        System.debug('Downloading file: ' + strFileName + ' from ' + strFileUrl);
    }
}