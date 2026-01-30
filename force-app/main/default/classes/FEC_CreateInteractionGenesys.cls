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

            return new InteractionResult(true, 'Create Interaction successful', createdCase.Id, response);
        } catch (Exception e) {
            System.debug('Error creating interaction: ' + e.getMessage());
            return new InteractionResult(false, 'Create Interaction failed: ' + e.getMessage(), null, null);
        }
    }
    
    private static String validateRequest(GenesysRequest req) {
        
        if (req == null) return 'Invalid request: Request body is null';
        if (String.isBlank(req.type)) return 'Type is required';

        if(req.type != FEC_ConstantCommon.CHANNEL_OUTBOUND_API && req.type != FEC_ConstantCommon.CHANNEL_INBOUND_API) {
            return 'Invalid Type. Must be either OutboundEstablished or InboundRinging';
        }
        
        // Call channel must have phone number
        if (( req.type == FEC_ConstantCommon.CHANNEL_OUTBOUND_API )
            && String.isBlank(req.phoneNumber))
        {
            return 'PhoneNumber is required for Outbound calls';
        }
        
        
        return null; // no error
    }
    
}