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
            System.debug('Error creating interaction: ' + e.getMessage());
            return new InteractionResult(false, String.format(System.Label.FEC_MSG_Create_Interaction_Error, new List<String>{e.getMessage()}), null, null);
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
                FEC_Channel__c                 = 'Email',
                FEC_Interaction_Subchannel__c  = 'Incoming Email',
                FEC_Interaction_View_Mode__c   = 'handling',
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
                FEC_Contract_Number__c         = request.contractNum,
                FEC_Account_Number__c          = request.cardAccountNum,
                Status                         = 'Open'
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
                EmailMessage em = new EmailMessage(
                    ParentId     = created.Id,
                    FromAddress  = request.fromEmail,
                    ToAddress    = request.sendTo,
                    Subject      = emailSubject,
                    TextBody     = String.isNotBlank(request.subject) ? request.subject : ('Email from ' + request.fromEmail),
                    Incoming     = true,
                    Status       = '0' // New
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
            System.debug('Error creating dummy interaction: ' + e.getMessage());
            return new InteractionResult(false, 'Create Dummy Interaction failed: ' + e.getMessage(), null, null);
        }
    }
}
