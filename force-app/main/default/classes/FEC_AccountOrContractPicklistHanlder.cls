public without sharing class FEC_AccountOrContractPicklistHanlder {
    
    public class GetProductsListResponse {
        @AuraEnabled public String productType;
        @AuraEnabled public String accountContractNumber;
        @AuraEnabled public String productName;
    }
    
    
    @AuraEnabled(cacheable=false)
    public static List<GetProductsListResponse> GetProductsListByCif(String cifNumber){
        
        String cif = '';
        
        if (String.isBlank(cifNumber)) {
            cif = '22475420';
        }else{
            cif = cifNumber;
        }
        
        
        List<GetProductsListResponse> results = new List<GetProductsListResponse>();
        FEC_GetProductListCallout.CIF_GetProductsListResponse res =
            FEC_GetProductListCallout.callService(cif);
        
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
                if (p.productType == 'Insurance') {
                    item.accountContractNumber = p.contractNumber;
                    item.productType = p.productType;
                    item.productName = p.productName;
                } else if (p.productType == 'Loan') {
                    item.accountContractNumber = p.contractNumber;
                    item.productType = p.productType;
                    item.productName = p.productName;
                } else if (p.productType == 'Card') {
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