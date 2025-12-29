public without sharing class FEC_CreateCaseHanlder {
    
    public class FEC_InteractionCaseDTO {
        // =========================
        // BASIC INFO
        // =========================
        public String channel;
        public String subChannel;
        public String otherSubChannel;
        public String externalInteractionId;
        
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
    
    public class FEC_InteractionCaseResponse {
        public Id caseId;
        public String linkId;
        public String caseNo;
    }
    
    public class FEC_CustomerCaseDTO {
        public String customerName;
        public String phoneNumber;
        public String userType;
        public String productTypeId;
        public String categoryId;
        public String subCategoryId;
        public String subCodeId;
        public String remarks;
    }
    
    public static FEC_InteractionCaseResponse createInteractionCase(FEC_InteractionCaseDTO dto) {
        
        if (dto == null) {
            throw new IllegalArgumentException('InteractionCaseDTO cannot be null');
        }
        Map<String, Id> rtMap = getRecordTypeIds();
        Case interactionCase = new Case();
        interactionCase.RecordTypeId = rtMap.get('Interaction');
        
        // ---------------------------
        // CHANNEL / STATUS
        // ---------------------------
        interactionCase.FEC_Channel__c = dto.channel;
        interactionCase.FEC_Interaction_Subchannel__c = dto.subChannel;
        interactionCase.FEC_Other_Subchannel__c =
            dto.subChannel == 'Other' ? dto.otherSubChannel : null;
        
        if (dto.channel == 'Chat') {
            interactionCase.FEC_Final_Status__c = 'Pending';
            interactionCase.FEC_External_Interaction_ID__c = dto.externalInteractionId;
        } else {
            interactionCase.FEC_Final_Status__c = 'Open';
        }
        
        // ---------------------------
        // CUSTOMER INFO
        // ---------------------------
        interactionCase.FEC_Phone_Number__c = dto.phoneNumber;
        interactionCase.FEC_National_ID_Passport_ID__c = dto.nationalId;
        interactionCase.FEC_Account_Number__c = dto.accountNumber;
        // interactionCase.FEC_Contract_Number__c = dto.contractNumber;
        
        // ---------------------------
        // INTERACTION DATA
        // ---------------------------
        interactionCase.FEC_Transcription__c = dto.transcription;
        interactionCase.FEC_KYC_Method__c = dto.kycMethod;
        interactionCase.FEC_KYC_Result__c = dto.kycResult;
        
        insert interactionCase;
        
        interactionCase = [
            SELECT Id, FEC_Link_ID__c
            FROM Case
            WHERE Id = :interactionCase.Id
        ];
        
        FEC_InteractionCaseResponse res = new FEC_InteractionCaseResponse();
        res.caseId = interactionCase.Id;
        res.linkId = interactionCase.FEC_Link_ID__c;
        
        if (res.linkId != null && res.linkId.contains('>')) {
            res.caseNo = res.linkId.substringBetween('>', '</');
        }
        
        return res;
    }
    
    public static Case createCustomerCase(
        FEC_CustomerCaseDTO dto,
    Id interactionCaseId
    ) {
        Map<String, Id> rtMap = getRecordTypeIds();
        Case c = new Case();
        c.RecordTypeId = rtMap.get('Customer_Case');
        
        c.FEC_Customer_Name__c = dto.customerName;
        c.FEC_Phone_Number__c = dto.phoneNumber;
        c.FEC_Customer_Type__c = dto.userType;
        
        c.FEC_Product_Type__c = dto.productTypeId;
        c.FEC_Category__c = dto.categoryId;
        c.FEC_SubCategory__c = dto.subCategoryId;
        c.FEC_SubCode__c = dto.subCodeId;
        c.FEC_Remarks__c = dto.remarks;
        
        c.FEC_Interaction__c = interactionCaseId;
        
        insert c;
        return c;
    }
    
    // -------------------------------------------
    private static Map<String, Id> getRecordTypeIds() {
        Map<String, Id> rtMap = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND DeveloperName IN ('Interaction', 'Customer_Case')
        ]) {
            rtMap.put(rt.DeveloperName, rt.Id);
        }
        return rtMap;
    }
    
}