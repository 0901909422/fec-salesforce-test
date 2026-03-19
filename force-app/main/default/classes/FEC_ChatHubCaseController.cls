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
    public class FEC_InteractionCaseDTO {
        // =========================
        // BASIC INFO
        // =========================
        public String channel;
        public String subChannel;
        public String otherSubChannel;
        public String externalInteractionId;
        public String campaignName;
        public String agentId;
        
        // =========================
        // CUSTOMER INFO
        // =========================
        public String phoneNumber;
        public String nationalId;
        public String accountNumber;
        public String contractNumber;
        public String customerName;
        
        // =========================
        // INTERACTION DATA
        // =========================
        public String transcription;
        public String kycMethod;
        public String kycResult;
    }
    
    
    public class FEC_InteractionCaseGenesysDTO {
        public String phoneNumber;
        public String nationalID;
        public String genesysInteractionID;
        public String contractNum;
        public String cardAccountNum;
        public String agentID;
        public String campaignName;
        public String type;
        public String method;
    }
    
    public class FEC_InteractionCaseResponse {
        public Id caseId;
        public String linkId;
        public String caseNo;
    }
    
    public class FEC_CustomerCaseDTO {
        public String customerName;
        public String phoneNumber;
        public String userType;
        public String businessProcessId;
        public String productTypeId;
        public String categoryId;
        public String subCategoryId;
        public String subCodeId;
        public String remarks;
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
    
            // 3. Prepare DTO
            FEC_InteractionCaseDTO dto = new FEC_InteractionCaseDTO();
            
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
            FEC_InteractionCaseResponse response = createInteractionCaseChat(strDtoJson);
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
    public static Boolean saveChatHistoryAndAttachment(String strJsonData, Boolean isAttachmentOnly) {
        if (String.isBlank(strJsonData)) {
            throw new AuraHandledException('Chat history data is blank');
        }
        
        if (isAttachmentOnly == null) {
            isAttachmentOnly = false;
        }
        List<FEC_ChatHistory__c> listHistoriesToInsert = new List<FEC_ChatHistory__c>();
        List<Object> listRawHistory = (List<Object>)JSON.deserializeUntyped(strJsonData);
        
        if (listRawHistory == null || listRawHistory.isEmpty()) {
            throw new AuraHandledException('Chat history list is empty');
        }
        
        String strCaseId = '';
        // Extract sessionID from first item to find the newest Case
        Map<String, Object> firstItem = (Map<String, Object>)listRawHistory[0];
        String currentSessionId = (String)firstItem.get('sessionID');
        
        if (String.isNotBlank(currentSessionId)) {
            List<Case> lstCases = [SELECT Id FROM Case WHERE FEC_External_Interaction_ID__c = :currentSessionId LIMIT 1];
            if (!lstCases.isEmpty()) {
                strCaseId = lstCases[0].Id;
            }
        }
        
        // Fallback: Rarely occurs, but if not found by sessionID, use pegaID instead
        if (String.isBlank(strCaseId) && firstItem.containsKey('pegaID')) {
            strCaseId = FEC_Utils.getInteractionIdFromPegaId((String)firstItem.get('pegaID'));
        }
        Set<String> setExistingFileNames = new Set<String>();
        
        // Pre-process to collect all file names that need checking
        for(Object obj : listRawHistory) {
            Map<String, Object> mapItem = (Map<String, Object>)obj;

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
                if (!isAttachmentOnly) {
                    listHistoriesToInsert.add(objHistory);
                }
                
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
                        continue;
                    }
                }
            } else {
                if (!isAttachmentOnly) {
                    listHistoriesToInsert.add(objHistory);
                }
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
    /**
     * Combines verification and update of old Case into a single Transaction
     * @param strExtInteractionID: Current Session ID
     * @param newUsername: New Agent assigned
     */
    @AuraEnabled
    public static Boolean updateOldCaseInteractionId(String strExtInteractionID, String newUsername) {
        try {
            List<Case> listCases = [
                SELECT Id, FEC_External_Interaction_ID__c 
                FROM Case 
                WHERE FEC_External_Interaction_ID__c = :strExtInteractionID 
                LIMIT 1
            ];

            if (!listCases.isEmpty()) {
                Case oldCase = listCases[0];
                String newExtID = strExtInteractionID + '-Reassign-' + newUsername + '-' + String.valueOf(Datetime.now().getTime());
                oldCase.FEC_External_Interaction_ID__c = newExtID;
                update oldCase;
                return true;
            }
            return false;
        } catch (Exception e) {
            System.debug('Error updating Old Case: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static FEC_InteractionCaseResponse createInteractionCaseChat(String jsonInput) {
        FEC_InteractionCaseDTO dto = (FEC_InteractionCaseDTO)JSON.deserialize(jsonInput, FEC_InteractionCaseDTO.class);
        
        if (dto == null) {
            throw new IllegalArgumentException(System.Label.FEC_MSG_Interaction_Case_DTO_Null);
        }
        try {
            Id interactionRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME).getRecordTypeId();
            Case interactionCase = new Case();
            interactionCase.RecordTypeId = interactionRecordTypeId;
            
            // ---------------------------
            // CHANNEL / STATUS
            // ---------------------------
            
            
            if(dto.channel == FEC_ConstantCommon.CHANNEL_INBOUND_API) {
                interactionCase.FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
            } else if ( dto.channel == FEC_ConstantCommon.CHANNEL_OUTBOUND_API) {
                interactionCase.FEC_Channel__c = FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME;
            }
            if(dto.subChannel != null) {
                interactionCase.FEC_Interaction_Subchannel__c = dto.subChannel;
            }
            
            interactionCase.FEC_Other_Subchannel__c =dto.subChannel == 'Other' ? dto.otherSubChannel : null;
            interactionCase.FEC_External_Interaction_ID__c = dto.externalInteractionId;
            if (dto.channel == 'Chat') {
                interactionCase.Status = 'Pending';
            } else {
                interactionCase.Status = 'Open';
            }
            if(dto.campaignName != null) {
                interactionCase.FEC_Genesys_campaign_Name__c = dto.campaignName;
            }
            
            // ---------------------------
            // CUSTOMER INFO
            // ---------------------------
            interactionCase.FEC_Phone_Number__c = dto.phoneNumber;
            interactionCase.FEC_National_ID_Passport_ID__c = dto.nationalId;
            interactionCase.FEC_Account_Number__c = dto.accountNumber;
            interactionCase.FEC_Contract_Number__c = dto.contractNumber;
            
            // ---------------------------
            // INTERACTION DATA
            // ---------------------------
            interactionCase.FEC_Transcription__c = dto.transcription;
            interactionCase.FEC_KYC_Method__c = dto.kycMethod;
            // interactionCase.FEC_KYC_Result__c = dto.kycResult;
    
          
            
            insert interactionCase;
            
            interactionCase = [
                SELECT Id, FEC_Link_ID__c, OwnerId
                FROM Case
                WHERE Id = :interactionCase.Id
            ];
            
            // if(dto.agentId != null && dto.agentId != '') {
                //     System.debug('Assigning Agent ID: ' + dto.agentId + ' to User Id    : ' + interactionCase.OwnerId);
                //     User userInfo = [SELECT Id, FEC_Agent_ID__c FROM User WHERE Id = :interactionCase.OwnerId];
                //     userInfo.FEC_Agent_ID__c = dto.agentId;
                //     update userInfo;
            // }
            
            
            FEC_InteractionCaseResponse res = new FEC_InteractionCaseResponse();
            res.caseId = interactionCase.Id;
            res.linkId = interactionCase.FEC_Link_ID__c;
            
            if (res.linkId != null && res.linkId.contains('>')) {
                res.caseNo = res.linkId.substringBetween('>', '</');
            }
            
            return res;
        } catch (Exception e) {
            System.debug('Error creating Interaction Case: ' + e.getMessage());
            throw new AuraHandledException('Lỗi khi tạo Case tương tác: ' + e.getMessage());
        }
    }
}