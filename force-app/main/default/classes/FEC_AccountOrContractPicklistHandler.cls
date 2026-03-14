public without sharing class FEC_AccountOrContractPicklistHandler {
    
    public class GetProductsListResponse {
        @AuraEnabled public String productType;
        @AuraEnabled public String accountContractNumber;
        @AuraEnabled public String productName;
    }
    
    @AuraEnabled(cacheable=true)
    public static String getInteractionAccountNumber(String caseId){
        try {
            
            Case interactionCase = [
            SELECT Id, FEC_Account_or_Contract__r.FEC_Account_Number__c,
                   FEC_Account_or_Contract__r.FEC_CIF_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
            
            Map<String, String> result = new Map<String, String>();
            
            if (interactionCase.FEC_Account_or_Contract__r != null) {
                result.put('accountNumber', interactionCase.FEC_Account_or_Contract__r.FEC_Account_Number__c);
                result.put('cifNumber', interactionCase.FEC_Account_or_Contract__r.FEC_CIF_Number__c);
            }
            
            return JSON.serialize(result);
            
        } catch (Exception e) {
            return JSON.serialize(new Map<String, String>());
        }
    }
    
    @AuraEnabled
    public static List<GetProductsListResponse> getProductsListByCif(String cifNumber){
        
        
        if (String.isBlank(cifNumber)) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required,
            new List<String>{'CifNumber'})
            );
        }
        
        List<GetProductsListResponse> results = new List<GetProductsListResponse>();
        
        try {
            FEC_GetProductListCallout.CIF_GetProductsListResponse res =
                FEC_GetProductListCallout.callService(cifNumber);
            
            if (res == null || res.products == null) {
                return results;
            }
            
            for (FEC_GetProductListCallout.ProductInfo p : res.products) {
                
                GetProductsListResponse item = new GetProductsListResponse();
                if (String.isNotBlank(p.accountNumber) && Pattern.matches(FEC_ConstantCommon.PATTERN_CARD, p.accountNumber)) {
                    item.accountContractNumber = p.accountNumber;
                    item.productType = FEC_ConstantCommon.PRODUCT_TYPE_CARD;
                }
                else if (String.isNotBlank(p.contractNumber)) {
                    String contract = p.contractNumber;
                    if (Pattern.matches(FEC_ConstantCommon.PATTERN_INSURANCE, contract)) {
                        item.accountContractNumber = contract;
                        item.productType = FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE;
                    }
                    else if (Pattern.matches(FEC_ConstantCommon.PATTERN_LOAN, contract)) {
                        item.accountContractNumber = contract;
                        item.productType = FEC_ConstantCommon.PRODUCT_TYPE_LOAN;
                    }
                }
                item.productName = p.productName;
                results.add(item);
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return results;
    }
    
    @AuraEnabled
    public static void createHistory( Id caseId, String selectedAccountContractNumber, String selectedType, String cifNumber) {
        
        if(selectedType != FEC_ConstantCommon.PRODUCT_TYPE_UBANK){
            if (selectedAccountContractNumber == null || selectedAccountContractNumber.trim() == '') {
                throw new AuraHandledException(System.Label.FEC_MSG_Create_Customer_History_Field_Null);
            }
        }
        FEC_Customer_History__c rec = new FEC_Customer_History__c();
        
        if (selectedType == FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE) {
            rec.FEC_Contract_Number__c = selectedAccountContractNumber;
        } else if (selectedType == FEC_ConstantCommon.PRODUCT_TYPE_LOAN) {
            rec.FEC_Contract_Number__c = selectedAccountContractNumber;
            
        } else if (selectedType == FEC_ConstantCommon.PRODUCT_TYPE_CARD) {
            rec.FEC_Card_Number__c = selectedAccountContractNumber;
        }
        
        if(selectedType != FEC_ConstantCommon.PRODUCT_TYPE_UBANK){
            rec.Name = selectedAccountContractNumber;
            rec.FEC_Account_Number__c = selectedAccountContractNumber;
        }else{
            rec.Name = FEC_ConstantCommon.PRODUCT_TYPE_UBANK;
            rec.FEC_Account_Number__c = FEC_ConstantCommon.PRODUCT_TYPE_UBANK;
        }
        
        rec.FEC_Case__c = caseId;
        rec.FEC_Product_Code__c = selectedType;
        rec.FEC_CIF_Number__c = cifNumber;
        
        try {
            insert rec;
            // Update interaction with new customer history
            updateInteractionWithNewCustomerHistory(caseId, rec.Id);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updateInteractionWithNewCustomerHistory(Id caseId, Id customerHistoryId) {
        Case c = new Case(
            Id = caseId,
        FEC_Account_or_Contract__c = customerHistoryId
            );
        try {
            update c;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }
}