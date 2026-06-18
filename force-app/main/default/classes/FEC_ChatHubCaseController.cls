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
        public String kycStatus;
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

            // 1. Normalize ChatHub JSON aliases before deserialize
            strJsonData = normalizeChatHubCustomerInfoJson(strJsonData);

            // 2. Deserialize payload directly into the ChatHub request wrapper
            FEC_CreateInteractionGenesys.ChatHubCreateInteractionRequest req =
                (FEC_CreateInteractionGenesys.ChatHubCreateInteractionRequest) JSON.deserialize(
                    strJsonData,
                    FEC_CreateInteractionGenesys.ChatHubCreateInteractionRequest.class
                );
            System.debug('req: ');
            System.debug(req);
            // 3. Create the Interaction Case through FEC_CreateInteractionGenesys
            FEC_CreateInteractionGenesys.InteractionResult result =
                FEC_CreateInteractionGenesys.createInteractionFromChat(req);

            if (result == null || result.isSuccess != true || result.recordId == null) {
                String strError = (result != null && result.message != null)
                    ? result.message
                    : System.Label.FEC_Error_CreateInteractionCase;
                throw new AuraHandledException(strError);
            }

            ensureInteractionCaseHandlingMode(result.recordId);

            // 3. InteractionResult only returns recordId, so query Link ID to build caseNo
            String strCaseNo = null;
            Case createdCase = [
                SELECT Id, FEC_Link_ID__c
                FROM Case
                WHERE Id = :result.recordId
                LIMIT 1
            ];
            if (createdCase.FEC_Link_ID__c != null && createdCase.FEC_Link_ID__c.contains('>')) {
                strCaseNo = createdCase.FEC_Link_ID__c.substringBetween('>', '</');
            }

            return new CaseCreationResponse(result.recordId, strCaseNo);

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** * getMapSafe
    * Safely casts an untyped JSON value to Map<String, Object>.
    * Returns an empty map when the value is null or not an object,
    * preventing TypeException during JSON.deserializeUntyped processing.
    */
    private static Map<String, Object> getMapSafe(Object objValue) {
        return (objValue instanceof Map<String, Object>)
            ? (Map<String, Object>)objValue
            : new Map<String, Object>();
    }

    /** * getStringSafe
    * Safely extracts a String value from an untyped map.
    * Uses String.valueOf so values arriving as number/boolean from
    * JSON.deserializeUntyped are converted instead of throwing TypeException.
    */
    private static String getStringSafe(Map<String, Object> mapData, String strKey) {
        Object objValue = (mapData != null) ? mapData.get(strKey) : null;
        return (objValue == null) ? null : String.valueOf(objValue);
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
            throw new AuraHandledException(System.Label.FEC_Error_ChatHistory_Blank);
        }
        
        if (isAttachmentOnly == null) {
            isAttachmentOnly = false;
        }
        List<FEC_ChatHistory__c> listHistoriesToInsert = new List<FEC_ChatHistory__c>();
        List<Object> listRawHistory = (List<Object>)JSON.deserializeUntyped(strJsonData);
        
        if (listRawHistory == null || listRawHistory.isEmpty()) {
            throw new AuraHandledException(System.Label.FEC_Error_ChatHistory_Empty);
        }
        
        String strCaseId = '';
        // Extract sessionID from first item to find the newest Case
        Map<String, Object> firstItem = (Map<String, Object>)listRawHistory[0];
        String currentSessionId = (String)firstItem.get('sessionID');
        
        if (String.isNotBlank(currentSessionId)) {
            // FOR UPDATE: lock Case row to serialize concurrent calls (e.g. 2 ChatHub tabs in different browsers)
            // and prevent duplicate FEC_ChatHistory__c being inserted from parallel transactions.
            List<Case> lstCases = [SELECT Id FROM Case WHERE FEC_External_Interaction_ID__c = :currentSessionId LIMIT 1 FOR UPDATE];
            if (!lstCases.isEmpty()) {
                strCaseId = lstCases[0].Id;
            }
        }
        
        if (String.isBlank(strCaseId) && firstItem.containsKey('chatID')) {
            String chatId = (String) firstItem.get('chatID');
            if (String.isNotBlank(chatId)) {
                List<Case> lstCasesByChatId = [
                    SELECT Id
                    FROM Case
                    WHERE FEC_External_Interaction_ID__c = :chatId
                    LIMIT 1
                ];
                if (!lstCasesByChatId.isEmpty()) {
                    strCaseId = lstCasesByChatId[0].Id;
                }
            }
        }

        // Fallback: Rarely occurs, but if not found by sessionID, use pegaID instead
        if (String.isBlank(strCaseId) && firstItem.containsKey('pegaID')) {
            strCaseId = FEC_Utils.getInteractionIdFromPegaId((String)firstItem.get('pegaID'));
        }
        
        // Pre-load existing chat history keys to avoid duplicates when the same payload
        // is submitted from multiple ChatHub tabs/browsers for the same Case.
        // Primary key: FEC_MessageID__c (unique external Id from ChatHub).
        // Fallback key: CreatedAt|SenderName|MessageType (for legacy records without messageID).
        Set<String> setExistingMessageIds = new Set<String>();
        Set<String> setExistingHistoryKeys = new Set<String>();
        if (String.isNotBlank(strCaseId)) {
            for (FEC_ChatHistory__c ch : [
                SELECT FEC_MessageID__c, FEC_CreatedAt__c, FEC_SenderName__c, FEC_MessageType__c
                FROM FEC_ChatHistory__c
                WHERE FEC_Case__c = :strCaseId
            ]) {
                if (String.isNotBlank(ch.FEC_MessageID__c)) {
                    setExistingMessageIds.add(ch.FEC_MessageID__c);
                }
                setExistingHistoryKeys.add(buildChatHistoryKey(ch.FEC_CreatedAt__c, ch.FEC_SenderName__c, ch.FEC_MessageType__c));
            }
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
            objHistory.FEC_MessageID__c = (String)mapItem.get('messageID');
            
            // Detect duplicates. Prefer messageID (unique External Id from ChatHub);
            // fall back to composite key for legacy records that have no messageID.
            String strHistoryKey = buildChatHistoryKey(objHistory.FEC_CreatedAt__c, objHistory.FEC_SenderName__c, objHistory.FEC_MessageType__c);
            Boolean isDuplicateHistory;
            if (String.isNotBlank(objHistory.FEC_MessageID__c)) {
                isDuplicateHistory = setExistingMessageIds.contains(objHistory.FEC_MessageID__c);
            } else {
                isDuplicateHistory = setExistingHistoryKeys.contains(strHistoryKey);
            }
            
            if (objHistory.FEC_MessageType__c == 'attachment' || objHistory.FEC_MessageType__c == 'image') {
                String fileNameConvert = (FEC_Utils.formatDateTimeToString(objHistory.FEC_CreatedAt__c) + '_' + (String)mapItem.get('fileName')).trim();
                objHistory.FEC_Message__c = fileNameConvert;
                if (!isAttachmentOnly && !isDuplicateHistory) {
                    listHistoriesToInsert.add(objHistory);
                    if (String.isNotBlank(objHistory.FEC_MessageID__c)) {
                        setExistingMessageIds.add(objHistory.FEC_MessageID__c);
                    }
                    setExistingHistoryKeys.add(strHistoryKey);
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
                        // Mark as existing to avoid duplicate downloads within the same payload
                        mapExistingFiles.put(fileNameConvert, true);
                    } catch(Exception e) {
                        System.debug('### Error downloading file: ' + e.getMessage());
                        continue;
                    }
                }
            } else {
                if (!isAttachmentOnly && !isDuplicateHistory) {
                    listHistoriesToInsert.add(objHistory);
                    if (String.isNotBlank(objHistory.FEC_MessageID__c)) {
                        setExistingMessageIds.add(objHistory.FEC_MessageID__c);
                    }
                    setExistingHistoryKeys.add(strHistoryKey);
                }
            }
        }

        FEC_FileActionOnReviewService.enterChatHubFileUploadBypass();
        try {
            if(!listCvToInsert.isEmpty()) {
                insert listCvToInsert;
            }
            if(!listHistoriesToInsert.isEmpty()) {
                // allOrNone = false: tolerate DUPLICATE_VALUE from the unique
                // FEC_MessageID__c constraint when 2 concurrent transactions
                // (e.g. ChatHub opened in 2 browsers) try to insert the same message.
                Database.SaveResult[] results = Database.insert(listHistoriesToInsert, false);
                for (Integer i = 0; i < results.size(); i++) {
                    if (!results[i].isSuccess()) {
                        Boolean isDupOnly = true;
                        for (Database.Error err : results[i].getErrors()) {
                            if (err.getStatusCode() != StatusCode.DUPLICATE_VALUE) {
                                isDupOnly = false;
                                break;
                            }
                        }
                        if (!isDupOnly) {
                            throw new AuraHandledException(System.Label.FEC_Error_SaveChatHistory + results[i].getErrors()[0].getMessage());
                        }
                        System.debug('### Skipped duplicate ChatHistory messageID=' + listHistoriesToInsert[i].FEC_MessageID__c);
                    }
                }
            }
            return true;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_SaveChatHistory + e.getMessage());
        } finally {
            FEC_FileActionOnReviewService.exitChatHubFileUploadBypass();
        }
    }
    
    @TestVisible
    private static void ensureInteractionCaseHandlingMode(Id caseId) {
        if (caseId == null) {
            return;
        }

        List<Case> cases = [
            SELECT Id, FEC_Interaction_View_Mode__c, RecordType.DeveloperName
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return;
        }

        Case existingCase = cases[0];
        Boolean isInteractionCase = FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME.equals(
            existingCase.RecordType != null ? existingCase.RecordType.DeveloperName : null
        );
        if (!isInteractionCase
            || FEC_ConstantCommon.INTERACTION_HANDLING_MODE.equals(existingCase.FEC_Interaction_View_Mode__c)) {
            return;
        }

        update new Case(
            Id = caseId,
            FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE
        );
    }

    /**
     * Builds a deterministic composite key for a chat history entry, used to detect duplicates
     * when the same payload is submitted concurrently from multiple ChatHub tabs/browsers.
     */
    private static String buildChatHistoryKey(Datetime dtCreatedAt, String strSenderName, String strMessageType) {
        String strDt = (dtCreatedAt == null) ? '' : String.valueOf(dtCreatedAt.getTime());
        return strDt + '|' + (strSenderName == null ? '' : strSenderName) + '|' + (strMessageType == null ? '' : strMessageType);
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
             throw new IllegalArgumentException(System.Label.FEC_Error_InteractionDTO_Null);
        }
        try {
            // ---------------------------
            // DEDUP: nếu đã có Case với cùng External Interaction ID thì trả về Case cũ
            // (tránh DUPLICATE_VALUE khi user F5/mở 2 tab/retry network với cùng sessionID)
            // ---------------------------
            if (String.isNotBlank(dto.externalInteractionId)) {
                List<Case> lstExisting = [
                    SELECT Id, FEC_Link_ID__c
                    FROM Case
                    WHERE FEC_External_Interaction_ID__c = :dto.externalInteractionId
                    LIMIT 1
                ];
                if (!lstExisting.isEmpty()) {
                    FEC_InteractionCaseResponse existingRes = new FEC_InteractionCaseResponse();
                    existingRes.caseId = lstExisting[0].Id;
                    existingRes.linkId = lstExisting[0].FEC_Link_ID__c;
                    if (existingRes.linkId != null && existingRes.linkId.contains('>')) {
                        existingRes.caseNo = existingRes.linkId.substringBetween('>', '</');
                    }
                    return existingRes;
                }
            }

            Id interactionRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME).getRecordTypeId();
            Case interactionCase = new Case();
            interactionCase.RecordTypeId = interactionRecordTypeId;
            interactionCase.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE;
        // ---------------------------
            // CHANNEL / STATUS
        // ---------------------------
            interactionCase.FEC_Channel__c = dto.channel;
            if(dto.subChannel != null) {
                interactionCase.FEC_Interaction_Subchannel__c = dto.subChannel;
            }

            interactionCase.FEC_Other_Subchannel__c = dto.subChannel == 'Other' ? dto.otherSubChannel : null;
            interactionCase.FEC_External_Interaction_ID__c = dto.externalInteractionId;
            if (dto.channel == FEC_ConstantCommon.CHANNEL_CHAT) {
                interactionCase.Status = FEC_ConstantCommon.CASE_STATUS_PENDING;
            } else {
                interactionCase.Status = FEC_ConstantCommon.CASE_STATUS_OPEN;
            }
            if(dto.campaignName != null) {
                interactionCase.FEC_Genesys_campaign_Name__c = dto.campaignName;
            }
            
        // ---------------------------
            // CUSTOMER INFO
        // ---------------------------
            interactionCase.FEC_Phone_Number__c = dto.phoneNumber;
            interactionCase.FEC_National_ID_Passport_ID__c = dto.nationalId;
            interactionCase.FEC_Search_National_ID__c = dto.nationalId;
            interactionCase.FEC_Account_Number__c = dto.accountNumber;
            interactionCase.FEC_Contract_Number__c = dto.contractNumber;
            interactionCase.FEC_Customer_Username__c = dto.customerName;
        // ---------------------------
            // INTERACTION DATA
        // ---------------------------
            interactionCase.FEC_Transcription__c = dto.transcription;
            interactionCase.FEC_KYC_Method__c = dto.kycMethod;
            interactionCase.FEC_KYC_Status__c = dto.kycStatus;
            // interactionCase.FEC_KYC_Result__c = dto.kycResult;

            // Mark as Chat Automation since case is created from ChatHub
            interactionCase.FEC_Is_Chat_Automation__c = true;

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
            throw new AuraHandledException(System.Label.FEC_Error_CreateInteractionCase + e.getMessage());
        }
    }

    @TestVisible
    private static String normalizeChatHubCustomerInfoJson(String strJsonData) {
        if (String.isBlank(strJsonData)) {
            return strJsonData;
        }

        Object parsed = JSON.deserializeUntyped(strJsonData);
        if (!(parsed instanceof Map<String, Object>)) {
            return strJsonData;
        }

        Map<String, Object> root = (Map<String, Object>) parsed;
        Object customerInfoObj = root.get('customerInfo');
        if (!(customerInfoObj instanceof Map<String, Object>)) {
            return strJsonData;
        }

        Map<String, Object> customerInfo = (Map<String, Object>) customerInfoObj;
        copyAliasIfBlank(customerInfo, 'applicationID', 'applicationId');
        copyAliasIfBlank(customerInfo, 'emailAddress', 'email');
        copyAliasIfBlank(customerInfo, 'contractNumber', 'contractNum');
        copyAliasIfBlank(customerInfo, 'contractNumber', 'contactNumber');
        copyAliasIfBlank(customerInfo, 'accountNumber', 'cardAccountNum');

        return JSON.serialize(root);
    }

    private static void copyAliasIfBlank(
        Map<String, Object> customerInfo,
        String targetKey,
        String sourceKey
    ) {
        if (customerInfo == null || String.isBlank(sourceKey) || String.isBlank(targetKey)) {
            return;
        }
        if (customerInfo.containsKey(targetKey) && customerInfo.get(targetKey) != null) {
            return;
        }
        if (!customerInfo.containsKey(sourceKey) || customerInfo.get(sourceKey) == null) {
            return;
        }
        customerInfo.put(targetKey, customerInfo.get(sourceKey));
    }
}