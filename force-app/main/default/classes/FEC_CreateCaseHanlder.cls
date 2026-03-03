public without sharing class FEC_CreateCaseHanlder {
    
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
    
    @AuraEnabled
    public static FEC_InteractionCaseResponse createInteractionCase(FEC_InteractionCaseDTO dto) {
        
        if (dto == null) {
            throw new IllegalArgumentException(System.Label.FEC_MSG_Interaction_Case_DTO_Null);
        }
        Id interactionRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME).getRecordTypeId();
        Case interactionCase = new Case();
        interactionCase.RecordTypeId = interactionRecordTypeId;
        
        // ---------------------------
        // CHANNEL / STATUS
        // ---------------------------
        
        
        if( dto.channel == FEC_ConstantCommon.CHANNEL_INBOUND_API ) {
            interactionCase.FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        }else if ( dto.channel == FEC_ConstantCommon.CHANNEL_OUTBOUND_API ) {
            interactionCase.FEC_Channel__c = FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME;
        }
        if( dto.subChannel != null ) {
            interactionCase.FEC_Interaction_Subchannel__c = dto.subChannel;
        }
        
        interactionCase.FEC_Other_Subchannel__c =
            dto.subChannel == 'Other' ? dto.otherSubChannel : null;
        interactionCase.FEC_External_Interaction_ID__c = dto.externalInteractionId;
        if (dto.channel == 'Chat') {
            interactionCase.Status = 'Pending';
        } else {
            interactionCase.Status = 'Open';
        }
        interactionCase.FEC_Genesys_campaign_Name__c = dto.campaignName;
        
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
    }
    
    
    
    public static Case createInteractionCaseGenesys(FEC_InteractionCaseGenesysDTO dto) {
        
        if (dto == null) {
            throw new IllegalArgumentException(System.Label.FEC_MSG_Interaction_Case_DTO_Null);
        }
        Id interactionRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME).getRecordTypeId();
        Case interactionCase = new Case();
        interactionCase.RecordTypeId = interactionRecordTypeId;
        if( dto.type == FEC_ConstantCommon.CHANNEL_INBOUND_API ) {
            interactionCase.FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
            interactionCase.FEC_Interaction_Subchannel__c = FEC_ConstantCommon.CHANNEL_INBOUND_SUBCHANNEL_NAME;

        }else if ( dto.type == FEC_ConstantCommon.CHANNEL_OUTBOUND_API ) {
            interactionCase.FEC_Channel__c = FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME;
            interactionCase.FEC_Interaction_Subchannel__c = FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME;
        }
        interactionCase.FEC_External_Interaction_ID__c = dto.genesysInteractionID;
        interactionCase.Status = 'Open';
        interactionCase.FEC_Genesys_campaign_Name__c = dto.campaignName;
        interactionCase.FEC_Phone_Number__c = dto.phoneNumber;
        interactionCase.FEC_Search_Phone_Number__c = dto.phoneNumber;
        interactionCase.FEC_National_ID_Passport_ID__c = dto.nationalId;
        interactionCase.FEC_Account_Number__c = dto.cardAccountNum;
        interactionCase.FEC_Contract_Number__c = dto.contractNum;
          if(dto.method == 'Auto') {
            interactionCase.FEC_Interaction_View_Mode__c  = 'handling';
        }
        insert interactionCase;
        
        Case createdInteraction  = [
            SELECT Id, FEC_Link_ID__c, OwnerId, FEC_Channel__c, FEC_Phone_Number__c,
                    FEC_National_ID_Passport_ID__c,
                    FEC_External_Interaction_ID__c,
                    FEC_Contract_Number__c,
                    FEC_Account_Number__c,
                    FEC_Genesys_campaign_Name__c
            FROM Case
            WHERE Id = :interactionCase.Id
        ];
        
        if(dto.agentId != null && dto.agentId != '') {
            System.debug('Assigning Agent ID: ' + dto.agentId + ' to User Id    : ' + createdInteraction.OwnerId);
            User userInfo = [SELECT Id, FEC_Agent_ID__c,FEC_Main_Queue__c FROM User WHERE Id = :createdInteraction.OwnerId];
            userInfo.FEC_Agent_ID__c = dto.agentId;
            // userInfo.FEC_Main_Queue__c = 'default value';
            update userInfo;
        }
        
        return createdInteraction;
        
    }
    
    public static Case createCustomerCase(
        FEC_CustomerCaseDTO dto,
    Id interactionCaseId
    ) {
        Id customerRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME).getRecordTypeId();
        Case c = new Case();
        c.RecordTypeId = customerRecordTypeId;
        
        c.FEC_Customer_Name__c = dto.customerName;
        c.FEC_Phone_Number__c = dto.phoneNumber;
        c.FEC_Customer_Type__c = dto.userType;
        c.FEC_Business_Process__c = dto.businessProcessId;
        c.FEC_Product_Type__c = dto.productTypeId;
        c.FEC_Category__c = dto.categoryId;
        c.FEC_SubCategory__c = dto.subCategoryId;
        c.FEC_SubCode__c = dto.subCodeId;
        c.FEC_Remarks__c = dto.remarks;
        
        c.FEC_Interaction__c = interactionCaseId;
        
        insert c;
        return c;
    }
    
}