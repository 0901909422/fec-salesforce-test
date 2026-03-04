public without sharing class FEC_AccountOrContractPicklistHanlder {
    
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
            System.debug('Error getting account numbers: ' + e.getMessage());
            return JSON.serialize(new Map<String, String>());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<GetProductsListResponse> GetProductsListByCif(String cifNumber){
        
        
        if (String.isBlank(cifNumber)) {
            System.debug('CIF Number is blank');
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CifNumber'}));
        }
        
        List<GetProductsListResponse> results = new List<GetProductsListResponse>();
        FEC_GetProductListCallout.CIF_GetProductsListResponse res =
            FEC_GetProductListCallout.callService(cifNumber);
        
        // Log tổng quan
        System.debug('=== CODE === ' + res.code);
        System.debug('=== DESCRIPTION === ' + res.description);
        System.debug('=== CIF === ' + res.cifNumber);
        
        if (res == null || res.products == null) {
            return results;
        }
        // Log từng product
        if (res.products != null) {
            for (FEC_GetProductListCallout.ProductInfo p : res.products) {
                System.debug('--- PRODUCT ---');
                System.debug('Type: ' + p.productType);
                System.debug('Contract: ' + p.contractNumber);
                System.debug('Account: ' + p.accountNumber);
                System.debug('Card: ' + p.cardNumber);
                System.debug('DealId: ' + p.dealId);
                
                GetProductsListResponse item = new GetProductsListResponse();
                item.productType = p.productType;
                if (p.productType == FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE) {
                    item.accountContractNumber = p.contractNumber;
                    item.productType = p.productType;
                    item.productName = p.productName;
                } else if (p.productType == FEC_ConstantCommon.PRODUCT_TYPE_LOAN) {
                    item.accountContractNumber = p.contractNumber;
                    item.productType = p.productType;
                    item.productName = p.productName;
                } else if (p.productType == FEC_ConstantCommon.PRODUCT_TYPE_CARD) {
                    item.accountContractNumber = p.cardNumber;
                    item.productType = p.productType;
                    item.productName = p.productName;
                }
                results.add(item);
            }
        }
        return results;
        
    }
    
}