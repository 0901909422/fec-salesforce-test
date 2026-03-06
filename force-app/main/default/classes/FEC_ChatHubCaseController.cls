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
                throw new AuraHandledException('SessionID is missing');
            }
    
            String strDtoJson = JSON.serialize(dto);
    
            // 4. Call existing Handler to create Case
            FEC_CreateCaseHanlder.FEC_InteractionCaseResponse response = FEC_CreateCaseHanlder.createInteractionCase(strDtoJson);
            return new CaseCreationResponse(response.caseId, response.caseNo);
    
        } catch (Exception e) {
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
        if (String.isBlank(strJsonData)) {
            throw new AuraHandledException('Chat history data is blank');
        }
        
        List<FEC_ChatHistory__c> listHistoriesToInsert = new List<FEC_ChatHistory__c>();
        List<Object> listRawHistory = (List<Object>)JSON.deserializeUntyped(strJsonData);
        
        if (listRawHistory == null || listRawHistory.isEmpty()) {
            throw new AuraHandledException('Chat history list is empty');
        }
        
        String strCaseId = '';
        Set<String> setExistingFileNames = new Set<String>();
        
         // Pre-process to collect all file names that need checking
        for(Object obj : listRawHistory) {
            Map<String, Object> mapItem = (Map<String, Object>)obj;
            if(String.isBlank(strCaseId)) {
                strCaseId = FEC_Utils.getInteractionIdFromPegaId((String)mapItem.get('pegaID'));
            }
            
            String strMessageType = (String)mapItem.get('messageType');
            if (strMessageType == 'attachment' || strMessageType == 'image') {
                Datetime dtCreatedAt = FEC_Utils.parseChatHubDatetime((String)mapItem.get('createdAt'));
                String fileNameConvert = (FEC_Utils.formatDateTimeToString(dtCreatedAt) + '_' + (String)mapItem.get('fileName')).trim();
                setExistingFileNames.add(fileNameConvert);
            }
        }

        Map<String, Boolean> mapExistingFiles = new Map<String, Boolean>();
        if (!setExistingFileNames.isEmpty()) {
            for (ContentDocumentLink link : [
                SELECT ContentDocument.Title 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :strCaseId 
                AND ContentDocument.Title IN :setExistingFileNames
            ]) {
                mapExistingFiles.put(link.ContentDocument.Title.trim(), true);
            }
        }

        List<ContentVersion> listCvToInsert = new List<ContentVersion>();

        for(Object obj : listRawHistory) {
            Map<String, Object> mapItem = (Map<String, Object>)obj;
            if(String.isBlank(strCaseId)) {
                strCaseId = FEC_Utils.getInteractionIdFromPegaId((String)mapItem.get('pegaID'));
            }

            FEC_ChatHistory__c objHistory = new FEC_ChatHistory__c();
            objHistory.FEC_Case__c = strCaseId;
            objHistory.FEC_SessionID__c = (String)mapItem.get('sessionID');
            objHistory.FEC_SenderName__c = (String)mapItem.get('senderName');
            objHistory.FEC_Message__c = (String)mapItem.get('message');
            objHistory.FEC_MessageType__c = (String)mapItem.get('messageType');
            objHistory.FEC_ChatChannel__c = (String)mapItem.get('chatChannel');
            objHistory.FEC_IsAgent__c = (Boolean)mapItem.get('isAgent');
            objHistory.FEC_CreatedAt__c = FEC_Utils.parseChatHubDatetime((String)mapItem.get('createdAt'));
            
            if (objHistory.FEC_MessageType__c == 'attachment' || objHistory.FEC_MessageType__c == 'image') {
                String fileNameConvert = (FEC_Utils.formatDateTimeToString(objHistory.FEC_CreatedAt__c) + '_' + (String)mapItem.get('fileName')).trim();
                objHistory.FEC_Message__c = fileNameConvert;
                listHistoriesToInsert.add(objHistory);
                
                if (mapExistingFiles.containsKey(fileNameConvert)) {
                    System.debug('### File already exists, skipping attachment: ' + fileNameConvert);
                    continue;  
                } else {
                    System.debug('### New file, proceeding to download: ' + fileNameConvert);
                    try {
                        String fileUrl = (String)mapItem.get('fileUrl');
                        Blob fileBlob = FEC_Utils.downloadFileAsBlob(fileUrl);
                        
                        ContentVersion cv = new ContentVersion();
                        cv.Title = fileNameConvert;          
                        cv.PathOnClient = fileNameConvert;     
                        cv.VersionData = fileBlob;
                        cv.FirstPublishLocationId = strCaseId;
                        cv.Description = ''; 
                        
                        listCvToInsert.add(cv); 
                    } catch(Exception e) {
                        System.debug('### Error downloading file: ' + e.getMessage());
                        // Todo: Return false to end when error, continue to run next record
                        // return false; 
                        continue;
                    }
                }
            } else {
                listHistoriesToInsert.add(objHistory);
            }
        }

        try {
            if(!listCvToInsert.isEmpty()) {
                insert listCvToInsert;
            }
            if(!listHistoriesToInsert.isEmpty()) {
                insert listHistoriesToInsert;
            }
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving chat history: ' + e.getMessage());
        }
    }
}