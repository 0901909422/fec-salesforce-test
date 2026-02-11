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
            
            FEC_CreateCaseHanlder.FEC_InteractionCaseGenesysDTO dto = new FEC_CreateCaseHanlder.FEC_InteractionCaseGenesysDTO();
            dto.phoneNumber = request.phoneNumber;
            dto.nationalID = request.nationalID;
            dto.genesysInteractionID = request.genesysInteractionID;
            dto.contractNum = request.contractNum;
            dto.cardAccountNum = request.cardAccountNum;
            dto.agentID = request.agentID;
            dto.campaignName = request.campaignName;
            dto.type = request.type;
            dto.method = request.method;
            Case createdCase = FEC_CreateCaseHanlder.createInteractionCaseGenesys(dto);

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
    
    @AuraEnabled
    public static InteractionResult createDummyInteraction() {
        try {
            GenesysRequest request = new GenesysRequest();
            request.phoneNumber = '1234567890';
            request.nationalID = '123456789';
            request.genesysInteractionID =UUID.randomUUID()
                .toString()
                .replace('-', '')
                .substring(0, 20);
            
            request.contractNum = 'dummy_contract_num';
            request.cardAccountNum = 'dummy_card_account_num';
            request.agentID = 'dummy_id'+Math.random();
            request.campaignName = 'dummy_campaign_name';
            request.type = 'OutboundEstablished';
            request.method = 'Auto';
            InteractionResult result = createInteraction(request);
            return result;
        } catch (Exception e) {
            System.debug('Error creating dummy interaction: ' + e.getMessage());
            return new InteractionResult(false, 'Create Dummy Interaction failed: ' + e.getMessage(), null, null);
        }
    }
}