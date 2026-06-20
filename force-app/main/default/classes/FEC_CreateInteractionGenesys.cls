public without sharing class FEC_CreateInteractionGenesys {
    
    public class GenesysRequest
    {
        @AuraEnabled public String phoneNumber {get; set;}
        @AuraEnabled public String nationalID {get; set;}
        @AuraEnabled public String genesysInteractionID {get; set;}
        @AuraEnabled public String contractNum {get; set;}
        @AuraEnabled public String cardAccountNum {get; set;}
        @AuraEnabled public String agentID {get; set;}
        @AuraEnabled public String campaignName {get; set;}
        @AuraEnabled public String type {get; set;}
        @AuraEnabled public String method {get; set;}
        
    }
    
    public class ChatHubCreateInteractionRequest {
        public CustomerInfo customerInfo;
        public ChatSession chatSession;
    }
    
    public class CustomerInfo {
        public String customerID;
        public String customerName;
        public String decryptNationalID;
        public String kYCStatus;
        public String nationalID;
        public String phoneNumber;
        public String applicationID;
        public String emailAddress;
        public String email;
        public String contractNumber;
        public String contractNum;
        public String contactNumber;
        public String accountNumber;
        public String cardAccountNum;
    }
    
    public class ChatSession {
        public String agentID;
        public String chatChannel;
        public String chatID;
        public String createdAt;
        public String customerID;
        public String customerName;
        public Boolean hasNewMessage;
        public String lastMessage;
        public String sessionID;
        public String sessionStatus;
        public String updatedAt;
        public String topic;
        public String note;
        public Boolean isAutomationCaseChat;
    }
    
    public class GenesysResposnse
    {
        public String phoneNumber;
        public String nationalID;
        public String genesysInteractionID;
        public String contractNum;
        public String cardAccountNum;
        public String agentID;
        public String campaignName;
        public String type;
        
        
    }
    
    public class InteractionResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String message;
        @AuraEnabled public Id recordId;
        public GenesysResposnse response;
        
        public InteractionResult(Boolean isSuccess, String message, Id recordId, GenesysResposnse response) {
            this.isSuccess = isSuccess;
            this.message = message;
            this.recordId = recordId;
            this.response = response;
        }
        
    }
    
    @AuraEnabled
    public static InteractionResult createInteraction(GenesysRequest request) {
        try {
            System.debug('Received Request: ' + JSON.serialize(request));
            String validationError = validateRequest(request);
            if (validationError != null) {
                return new InteractionResult(false, validationError, null,null);
            }
            
            FEC_CreateCaseHandler.FEC_InteractionCaseGenesysDTO dto = new FEC_CreateCaseHandler.FEC_InteractionCaseGenesysDTO();
            dto.phoneNumber = request.phoneNumber;
            dto.nationalID = request.nationalID;
            dto.genesysInteractionID = request.genesysInteractionID;
            dto.contractNum = request.contractNum;
            dto.cardAccountNum = request.cardAccountNum;
            dto.agentID = request.agentID;
            dto.campaignName = request.campaignName;
            dto.type = request.type;
            dto.method = request.method;
            Case createdCase = FEC_CreateCaseHandler.createInteractionCaseGenesys(dto);
            
            GenesysResposnse response = new GenesysResposnse();
            response.phoneNumber = createdCase.FEC_Phone_Number__c;
            response.nationalID = createdCase.FEC_National_ID_Passport_ID__c;
            response.genesysInteractionID = createdCase.FEC_External_Interaction_ID__c;
            response.contractNum = createdCase.FEC_Contract_Number__c;
            response.cardAccountNum = createdCase.FEC_Account_Number__c;
            response.agentID = request.agentID;
            response.campaignName = createdCase.FEC_Genesys_campaign_Name__c;
            response.type = createdCase.FEC_Channel__c;
            
            return new InteractionResult(true, System.Label.FEC_MSG_Create_Interaction_Success, createdCase.Id, response);
        } catch (Exception e) {
            return new InteractionResult(false, String.format(System.Label.FEC_MSG_Create_Interaction_Error, new List<String>{e.getMessage()}), null, null);
        }
    }
    
    public static FEC_CreateCaseHandler.FEC_InteractionCaseDTO mapToDTO(
        ChatHubCreateInteractionRequest req
    ) {
        if (req == null || req.chatSession == null) {
            throw new IllegalArgumentException('Invalid ChatHub payload');
        }
        
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto =
            new FEC_CreateCaseHandler.FEC_InteractionCaseDTO();
        
        
        dto.channel = FEC_ConstantCommon.CHANNEL_CHAT;
        
        String rawChannel = req.chatSession.chatChannel;
        dto.subChannel = normalizeChannel(rawChannel);
        
        if (dto.subChannel == FEC_ConstantCommon.CHANNEL_EXTERNAL_SUBCHANNEL_OTHER_NAME) {
            dto.otherSubChannel = rawChannel;
        }
        
        dto.externalInteractionId = req.chatSession.sessionID;
        
        dto.campaignName = req.chatSession.topic;
        
        dto.agentId = req.chatSession.agentID;
        
        
        if (req.customerInfo != null) {
            CustomerInfo ci = req.customerInfo;
            dto.customerName = ci.customerName;
            dto.phoneNumber = String.isNotBlank(ci.phoneNumber) ? ci.phoneNumber : null;
            dto.nationalId = String.isNotBlank(ci.decryptNationalID)
                ? ci.decryptNationalID
                : ci.nationalID;
            dto.email = firstNonBlank(ci.emailAddress, ci.email);
            dto.applicationId = ci.applicationID;
            applyContractAndAccountToDto(dto, ci);
        }
        
        dto.chatHistory = req.chatSession.lastMessage;
        
        dto.kycMethod = mapKycMethod(req.customerInfo != null ? req.customerInfo.kYCStatus : null);
        dto.kycStatus = req.customerInfo != null ? req.customerInfo.kYCStatus : null;
        dto.kycResult = deriveKycResult(req.customerInfo != null ? req.customerInfo.kYCStatus : null);

        dto.isAutomationCaseChat = req.chatSession.isAutomationCaseChat;
        return dto;
    }
    private static String firstNonBlank(String first, String second) {
        if (String.isNotBlank(first)) {
            return first;
        }
        return String.isNotBlank(second) ? second : null;
    }

    private static void applyContractAndAccountToDto(
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto,
        CustomerInfo ci
    ) {
        if (dto == null || ci == null) {
            return;
        }

        String explicitAccount = firstNonBlank(ci.accountNumber, ci.cardAccountNum);
        if (String.isNotBlank(explicitAccount)) {
            applyContractOrAccountNumberToDto(dto, explicitAccount);
        }

        if (String.isBlank(dto.accountNumber) && String.isBlank(dto.contractNumber)) {
            String contractOrContact = firstNonBlank(
                ci.contractNumber,
                firstNonBlank(ci.contractNum, ci.contactNumber)
            );
            applyContractOrAccountNumberToDto(dto, contractOrContact);
        }
    }

    private static void applyContractOrAccountNumberToDto(
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto,
        String contractOrAccountNumber
    ) {
        if (dto == null || String.isBlank(contractOrAccountNumber)) {
            return;
        }
        if (Pattern.matches(FEC_ConstantCommon.PATTERN_ACCOUNT_NUMBER, contractOrAccountNumber)) {
            dto.accountNumber = contractOrAccountNumber;
            dto.contractNumber = null;
        } else if (Pattern.matches(FEC_ConstantCommon.PATTERN_CONTRACT_NUMBER, contractOrAccountNumber)) {
            dto.contractNumber = contractOrAccountNumber;
            dto.accountNumber = null;
        }
    }

    private static String normalizeChannel(String channel) {
        if (String.isBlank(channel)) return null;
        
        String normalized = channel.trim().toLowerCase();
        
        if (normalized == FEC_ConstantCommon.CHANNEL_FACEBOOK_LOWER) {
            return FEC_ConstantCommon.CHANNEL_FACEBOOK;
        }
        if (normalized == FEC_ConstantCommon.CHANNEL_ZALO_LOWER) {
            return FEC_ConstantCommon.CHANNEL_ZALO;
        }
        if (normalized == FEC_ConstantCommon.CHANNEL_WEBCHAT_LOWER) {
            return FEC_ConstantCommon.CHANNEL_WEBCHAT;
        }
        if (normalized == FEC_ConstantCommon.CHANNEL_APPCHAT_LOWER) {
            return FEC_ConstantCommon.CASE_SUBCHANNEL_MOBILE_APP;
        }
        
        return FEC_ConstantCommon.CHANNEL_EXTERNAL_SUBCHANNEL_OTHER_NAME;
    }
    
    private static String mapKycMethod(String kycStatus) {
        if (String.isBlank(kycStatus)) return null;
        
        return FEC_ConstantCommon.KYC_METHOD_OTHER;
    }
    
    private static String deriveKycResult(String kycStatus) {
        if (String.isBlank(kycStatus)) return null;
        
        if (kycStatus == FEC_ConstantCommon.KYC_STATUS_NOT_KYC ) return FEC_ConstantCommon.KYC_RESULT_FAIL ;
        if (kycStatus == FEC_ConstantCommon.KYC_STATUS_KYC ) return FEC_ConstantCommon.KYC_RESULT_PASS ;
        
        return 'Fail';
    }
    
    public static InteractionResult createInteractionFromChat(
        ChatHubCreateInteractionRequest req
    ) {
        try {
            if (req == null || req.chatSession == null) {
                return new InteractionResult(false, 'Invalid payload', null, null);
            }
            
            FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto = mapToDTO(req);
            
            
            FEC_CreateCaseHandler.FEC_InteractionCaseResponse res =
                FEC_CreateCaseHandler.createInteractionCaseChat(dto);
            
            if (res == null || res.caseId == null) {
                return new InteractionResult(false, 'Create failed', null, null);
            }
            
            return new InteractionResult(
                true,
            'Success',
            res.caseId,
            null
                );
            
        } catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage());
            
            return new InteractionResult(
                false,
            e.getMessage(),
            null,
            null
                );
        }
    }
    
    private static String validateRequest(GenesysRequest req) {
        
        if (req == null) {
            return System.Label.FEC_MSG_Genesys_Request_Null;
        }
        if (String.isBlank(req.type)) {
            return System.Label.FEC_MSG_Genesys_Request_Type_Null;
        }
        if(req.type != FEC_ConstantCommon.CHANNEL_OUTBOUND_API && req.type != FEC_ConstantCommon.CHANNEL_INBOUND_API) {
            return System.Label.FEC_MSG_Genesys_Request_Invalid_Type;
        }
        // Call channel must have phone number
        if (( req.type == FEC_ConstantCommon.CHANNEL_OUTBOUND_API )
        && String.isBlank(req.phoneNumber)) {
            return System.Label.FEC_MSG_Genesys_Phone_Number_Null;
        }
        return null; // no error
    }
    
    public class EmailGenesysRequest {
        @AuraEnabled public String fromEmail        {get; set;}
        @AuraEnabled public String sendTo           {get; set;}
        @AuraEnabled public String genesysInteractionID {get; set;}
        @AuraEnabled public String phoneNum         {get; set;}
        @AuraEnabled public String nationalID       {get; set;}
        @AuraEnabled public String contractNum      {get; set;}
        @AuraEnabled public String cardAccountNum   {get; set;}
        @AuraEnabled public String agentID          {get; set;}
        @AuraEnabled public String subject          {get; set;}
        @AuraEnabled public String structuredText   {get; set;}
    }
    
    @AuraEnabled
    public static InteractionResult createEmailInteraction(EmailGenesysRequest request) {
        try {
            if (request == null || String.isBlank(request.genesysInteractionID)) {
                return new InteractionResult(false, 'GenesysInteractionID is required', null, null);
            }
            
            Id rtId = Schema.SObjectType.Case
                .getRecordTypeInfosByDeveloperName()
                .get('Interaction').getRecordTypeId();
            
            Case c = new Case(
                RecordTypeId                   = rtId,
            FEC_Channel__c                 = FEC_ConstantCommon.CHANNEL_EMAIL_NAME,
            FEC_Interaction_Subchannel__c  = FEC_ConstantCommon.CHANNEL_EMAIL_INCOMING_SUBCHANNEL_NAME,
            FEC_Interaction_View_Mode__c   = FEC_ConstantCommon.INTERACTION_HANDLING_MODE,
            Subject                        = String.isNotBlank(request.subject) ? request.subject : ('Email from ' + request.fromEmail),
            // Interaction Email: từ Genesys, ghi vào cả 2 field (search + display)
            FEC_Interaction_Email__c       = request.fromEmail,
            FEC_Search_Email_Address__c    = request.fromEmail,
            // Send To: mailbox FEC nhận email
            FEC_Send_To__c                 = request.sendTo,
            // External Interaction ID: ID từ Genesys
            FEC_External_Interaction_ID__c = request.genesysInteractionID,
            // Thông tin KH từ Genesys
            FEC_Phone_Number__c            = request.phoneNum,
            FEC_Search_Phone_Number__c     = request.phoneNum,
            FEC_National_ID_Passport_ID__c = request.nationalID,
            FEC_Search_National_ID__c      = request.nationalID,
            FEC_Contract_Number__c         = request.contractNum,
            FEC_Search_Contract_Number__c  = request.contractNum,
            FEC_Account_Number__c          = request.cardAccountNum,
            FEC_Search_Account_Number__c   = request.cardAccountNum,
            Status                         = FEC_ConstantCommon.CASE_STATUS_OPEN
                );
            insert c;
            
            Case created = [
                SELECT Id, FEC_Channel__c, FEC_Interaction_Email__c,
                       FEC_External_Interaction_ID__c, FEC_Phone_Number__c,
                       FEC_National_ID_Passport_ID__c, FEC_Contract_Number__c,
                       FEC_Account_Number__c, FEC_Send_To__c, OwnerId
                FROM Case WHERE Id = :c.Id
            ];
            
            if (String.isNotBlank(request.agentID)) {
                List<User> agents = [SELECT Id FROM User WHERE FEC_Agent_ID__c = :request.agentID AND IsActive = true LIMIT 1];
                if (!agents.isEmpty()) {
                    Case caseToUpdate = new Case(Id = created.Id, OwnerId = agents[0].Id);
                    update caseToUpdate;
                }
            }
            
            // Tạo EmailMessage để hiển thị email thread trong Chatter Feed
            if (String.isNotBlank(request.fromEmail)) {
                String emailSubject = String.isNotBlank(request.subject) ? request.subject : ('Email from ' + request.fromEmail);
                String bodyContent = String.isNotBlank(request.structuredText)
                    ? request.structuredText
                    : (String.isNotBlank(request.subject) ? request.subject : ('Email from ' + request.fromEmail));
                String plainBodyContent = bodyContent != null
                    ? bodyContent.replaceAll('<[^>]+>', '')
                    : null;
                EmailMessage em = new EmailMessage(
                    ParentId     = created.Id,
                FromAddress  = request.fromEmail,
                ToAddress    = request.sendTo,
                Subject      = emailSubject,
                TextBody     = plainBodyContent,
                HtmlBody     = bodyContent,
                Incoming     = true,
                Status       = FEC_ConstantCommon.SUCCESS_STATUS_CODE // New
                    );
                insert em;
            }
            
            GenesysResposnse response = new GenesysResposnse();
            response.genesysInteractionID = created.FEC_External_Interaction_ID__c;
            response.type                 = created.FEC_Channel__c;
            response.phoneNumber          = request.phoneNum;
            response.nationalID           = request.nationalID;
            response.contractNum          = request.contractNum;
            response.cardAccountNum       = request.cardAccountNum;
            response.agentID              = request.agentID;
            
            return new InteractionResult(true, System.Label.FEC_MSG_Create_Interaction_Success, created.Id, response);
        } catch (Exception e) {
            return new InteractionResult(false, e.getMessage(), null, null);
        }
    }
    
    @AuraEnabled
    public static InteractionResult createDummyInteraction() {
        try {
            InteractionResult result = FEC_GenesysCreateDummyInteraction.createDummyInteraction();
            return result;
        } catch (Exception e) {
            return new InteractionResult(false,  e.getMessage(), null, null);
        }
    }
}