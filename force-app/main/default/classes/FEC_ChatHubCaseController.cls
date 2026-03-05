/** * FEC_ChatHubCaseController
* Controller to handle various events received from ChatHub, including Case creation, 
* new message processing, and saving chat history/attachments.
* @created    : 2025/12/03 long.nguyen.50
* @modified   : 
*/ 
public with sharing class FEC_ChatHubCaseController {
    
    // Naming convention: String: strName, Datetime: dtStartDate, List: listAccounts
    
    // Wrapper class for Case creation response
    public class CaseCreationResponse {
        @AuraEnabled
        public String caseId { get; set; }
        @AuraEnabled
        public String caseNo { get; set; }
        
        public CaseCreationResponse(String caseId, String caseNo) {
            this.caseId = caseId;
            this.caseNo = caseNo;
        }
    }
    
    /** * createCaseOnNewSession
    * Handles the incoming 'createCaseRequestEvent' to create a new Case record.
    * @param strJsonData: JSON string containing chat session and customer info.
    * @return CaseCreationResponse: Object containing caseId and caseNo of the newly created Case.
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */
    @AuraEnabled
    public static CaseCreationResponse createCaseOnNewSession(String strJsonData) {
        try {
            if (String.isBlank(strJsonData)) {
                // System.debug('### [FEC] Input JSON is empty');
                return null;
            }
    
            // 1. Parse JSON
            Map<String, Object> mapRaw = (Map<String, Object>)JSON.deserializeUntyped(strJsonData);
            // System.debug('### [FEC] Parsed JSON Map: ' + mapRaw);
            // NULL CHECK: Ensure root map is not null
            if (mapRaw == null) return null;
            // System.debug('### [FEC] chatSession mapRaw: ' + mapRaw.get('chatSession'));
    
            // 2. Safe Extraction of Child Maps
            // Initialize as empty maps if key is missing to avoid NullPointerException on .get()
            Object objSession = mapRaw.get('chatSession');
            Map<String, Object> mapSession = (objSession != null) ? (Map<String, Object>)objSession : new Map<String, Object>();
    
            Object objCustomer = mapRaw.get('customerInfo');
            Map<String, Object> mapCustomer = (objCustomer != null) ? (Map<String, Object>)objCustomer : new Map<String, Object>();
    
            // 3. Prepare DTO for FEC_CreateCaseHanlder
            FEC_CreateCaseHanlder.FEC_InteractionCaseDTO dto = new FEC_CreateCaseHanlder.FEC_InteractionCaseDTO();
            
            dto.channel = 'Chat'; 
            
            String strRawChannel = (mapSession.containsKey('chatChannel')) ? (String)mapSession.get('chatChannel') : '';

            // Safe .get() calls (even if map is empty, .get() returns null, not Exception)
            dto.subChannel = FEC_Utils.getInteractionChannel(strRawChannel);
            dto.externalInteractionId = (String)mapSession.get('sessionID');
            dto.phoneNumber = (String)mapCustomer.get('phoneNumber');
            dto.nationalId = (String)mapCustomer.get('nationalID');
            dto.customerName = (String)mapCustomer.get('customerName');
            // dto.kycResult = (String)mapCustomer.get('kYCStatus');
            dto.kycResult = FEC_Utils.mappingKYCs((String)mapCustomer.get('kYCStatus'));
            // Optional: Validation
            if (String.isBlank(dto.externalInteractionId)) {
                System.debug('### [FEC] Warning: Missing SessionID');
                // Decide if you want to return null or continue
                throw new AuraHandledException('SessionID is missing');
            }
    
            String strDtoJson = JSON.serialize(dto);
    
            // 4. Call existing Handler to create Case
            FEC_CreateCaseHanlder.FEC_InteractionCaseResponse response = FEC_CreateCaseHanlder.createInteractionCase(strDtoJson);
            System.debug('response: ' + response);
            return new CaseCreationResponse(response.caseId, response.caseNo);
    
        } catch (Exception e) {
            // System.debug('### [FEC] Error in createChatSessionCase: ' + e.getMessage() + ' ' + e.getStackTraceString());
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
        // System.debug('### [FEC] saveChatHistory Input: ' + strJsonData);
        if (String.isBlank(strJsonData)) {
            // old code
            // return false;

            // new code
            throw new AuraHandledException('Chat history data is blank');
        }
        
        // System.debug('### [FEC] JSON.deserializeUntyped: ' + JSON.deserializeUntyped(strJsonData));
        List<FEC_ChatHistory__c> listHistoriesToInsert = new List<FEC_ChatHistory__c>();
        List<Object> listRawHistory = (List<Object>)JSON.deserializeUntyped(strJsonData);
        System.debug('listRawHistory');
        System.debug(listRawHistory);
        
        // Check if listRawHistory is empty
        if (listRawHistory == null || listRawHistory.isEmpty()) {
            // System.debug('### [FEC] Chat history list is empty');
            // old code
            // return false;

            // new code
            throw new AuraHandledException('Chat history list is empty');
        }
        
        // Map<String, Object> mapFirstItem = (Map<String, Object>)listRawHistory[0];
        // System.debug('listRawHistory PegaID: ' + mapFirstItem.get('pegaID'));
        // System.debug('listRawHistory SessionID: ' + mapFirstItem.get('sessionID'));
        // System.debug('listRawHistory SenderName: ' + mapFirstItem.get('senderName'));
        // System.debug('listRawHistory Message: ' + mapFirstItem.get('message'));
        // System.debug('listRawHistory MessageType: ' + mapFirstItem.get('messageType'));
        // System.debug('listRawHistory ChatChannel: ' + mapFirstItem.get('chatChannel'));
        // System.debug('listRawHistory CreatedAt: ' + mapFirstItem.get('createdAt'));
        // Set<String> setSignaturesInInput = new Set<String>();
        String strCaseId = '';
        
        // Collect all attachment file names and case IDs before loop to batch query
        Set<String> setExistingFileNames = new Set<String>();
        Map<String, List<String>> mapCaseToFileNames = new Map<String, List<String>>();
        
        // Pre-process to collect all file names that need checking
        for(Object obj : listRawHistory) {
            Map<String, Object> mapItem = (Map<String, Object>)obj;
            
            if(String.isBlank(strCaseId)) {
                String pegaID = (String)mapItem.get('pegaID');
                strCaseId = FEC_Utils.getInteractionIdFromPegaId(pegaID);
            }
            
            String strMessageType = (String)mapItem.get('messageType');
            if (strMessageType == 'attachment' || strMessageType == 'image') {
                String strCreatedAt = (String)mapItem.get('createdAt');
                Datetime dtCreatedAt = FEC_Utils.parseChatHubDatetime(strCreatedAt);
                String fileNameConvert = (FEC_Utils.formatDateTimeToString(dtCreatedAt) + '_' + (String)mapItem.get('fileName')).trim();
                setExistingFileNames.add(fileNameConvert);
            }

            // Datetime dt = FEC_Utils.parseChatHubDatetime((String)mapItem.get('createdAt'));
            // String sig = (String)mapItem.get('pegaID') + '|' + 
            //          (String)mapItem.get('sessionID') + '|' + 
            //          (String)mapItem.get('senderName') + '|' + 
            //          (String)mapItem.get('messageType') + '|' + 
            //          String.valueOf(dt.getTime());
            // setSignaturesInInput.add(sig);
        }
        System.debug('strCaseId: ' + strCaseId);

        // Batch query all existing files at once
        Map<String, Boolean> mapExistingFiles = new Map<String, Boolean>();
        // System.debug('setExistingFileNames: ' + setExistingFileNames);
        if (!setExistingFileNames.isEmpty()) {
            // System.debug('query listExistingLinks: ');
            // System.debug( [
            //     SELECT ContentDocument.Title 
            //     FROM ContentDocumentLink 
            //     WHERE LinkedEntityId = :strCaseId 
            // ]);
            // System.debug('strCaseId: '  + strCaseId);
            // System.debug('setExistingFileNames: ' + setExistingFileNames);
            List<ContentDocumentLink> listExistingLinks = [
                SELECT ContentDocument.Title 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :strCaseId 
                AND ContentDocument.Title IN :setExistingFileNames
            ];
            // System.debug('listExistingLinks: ' + listExistingLinks);
            for (ContentDocumentLink link : listExistingLinks) {
                mapExistingFiles.put(link.ContentDocument.Title.trim(), true);
            }
            // System.debug('mapExistingFiles: ' + mapExistingFiles);
        }

        // 1. Process Chat History
        for(Object obj : listRawHistory) {
            Map<String, Object> mapItem = (Map<String, Object>)obj;
            // Get PegaID (mapped to Case ID in SF)
            if(String.isBlank(strCaseId)) {
                strCaseId = FEC_Utils.getInteractionIdFromPegaId((String)mapItem.get('pegaID'));
            }

            FEC_ChatHistory__c objHistory = new FEC_ChatHistory__c();
            objHistory.FEC_Case__c = strCaseId; // Assuming pegaID is SF Case ID sent back earlier
            objHistory.FEC_SessionID__c = (String)mapItem.get('sessionID');
            objHistory.FEC_SenderName__c = (String)mapItem.get('senderName');
            objHistory.FEC_Message__c = (String)mapItem.get('message');
            objHistory.FEC_MessageType__c = (String)mapItem.get('messageType');
            objHistory.FEC_ChatChannel__c = (String)mapItem.get('chatChannel');
            objHistory.FEC_IsAgent__c = (Boolean)mapItem.get('isAgent');
            
            // Handle Timestamp using Util
            // objHistory.FEC_ExternalCreatedAt__c = FEC_Utils.parseChatHubDatetime(strCreatedAt);

            objHistory.FEC_CreatedAt__c = FEC_Utils.parseChatHubDatetime((String)mapItem.get('createdAt'));
            if (objHistory.FEC_MessageType__c == 'attachment' || objHistory.FEC_MessageType__c == 'image') {
                String fileNameConvert = (FEC_Utils.formatDateTimeToString(objHistory.FEC_CreatedAt__c) + '_' + (String)mapItem.get('fileName')).trim();
                System.debug('(String)mapItem.get fileName: ' + (String)mapItem.get('fileName'));
                System.debug('fileNameConvert: ' + fileNameConvert);
                objHistory.FEC_Message__c = fileNameConvert;
                listHistoriesToInsert.add(objHistory);
                // Check if file already exists using pre-queried map
                if (mapExistingFiles.containsKey(fileNameConvert)) {
                    continue;  // Skip this file, but continue processing other messages
                } else {
                    try{
                        FEC_AttachmentController.downloadAndSaveBase64(
                            (String)mapItem.get('fileUrl'), 
                            objHistory.FEC_Case__c, 
                            fileNameConvert,
                            null
                        );
                    }catch(Exception e){
                        return false;
                    }
                }
            }else{
                listHistoriesToInsert.add(objHistory);
            }
        }

        try {
            if(!listHistoriesToInsert.isEmpty()) {
                System.debug('insert listHistoriesToInsert:');
                System.debug(listHistoriesToInsert.size());
                System.debug(listHistoriesToInsert);
                insert listHistoriesToInsert;
            }
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving chat history: ' + e.getMessage());
        }
    }

    /**
     * Helper to handle attachment download asynchronously
     * @param strCaseId: Case ID
     * @param strFileUrl: URL from ChatHub
     * @param strFileName: File Name
     * @return void
     * @created: 
     * @modified: 
     */
    @future(callout=true)
    public static void handleAttachmentAsync(String strCaseId, String strFileUrl, String strFileName) {
        // Logic integration with FEC_CreateCSCaseService goes here
        // Example: FEC_CreateCSCaseService.saveFile(strCaseId, strFileUrl, strFileName);
    }
}