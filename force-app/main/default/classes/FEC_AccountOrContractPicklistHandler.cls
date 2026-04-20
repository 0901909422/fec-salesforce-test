public without sharing class FEC_AccountOrContractPicklistHandler {
    
    public class GetProductsListResponse {
        @AuraEnabled public String productType;
        @AuraEnabled public String accountContractNumber;
        @AuraEnabled public String productName;
        @AuraEnabled public String phone;
    }
    
    @AuraEnabled
    public static String getInteractionAccountNumber(String caseId){
        try {
            Case interactionCase = [
            SELECT Id, FEC_Product_Type__r.Name,
                   FEC_Account_or_Contract__r.FEC_Contract_Number__c,
                   FEC_Account_or_Contract__r.FEC_Account_Number__c,
                   FEC_Account_or_Contract__r.FEC_Product_Code__c,
                   FEC_Account_or_Contract__r.FEC_CIF_Number__c,
                   FEC_Has_Account_or_Contract__c,
                   FEC_Phone_Number__c 
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
            
            Map<String, Object> result = new Map<String, Object>();
            
            if (interactionCase.FEC_Account_or_Contract__r != null) {
                
                String productCode =
                    interactionCase.FEC_Product_Type__r.Name ;
                
                String accountNumber;
                
                // 🎯 CORE LOGIC
                if (productCode.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_LOAN.toLowerCase() ||
                productCode.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE.toLowerCase()) {
                    
                    accountNumber =
                        interactionCase.FEC_Account_or_Contract__r.FEC_Contract_Number__c;
                    
                } else if (productCode.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_CARD.toLowerCase() ) {
                    
                    accountNumber =
                        interactionCase.FEC_Account_or_Contract__r.FEC_Account_Number__c;
                }else if (productCode.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_UBANK.toLowerCase()) {
                    accountNumber = interactionCase.FEC_Account_or_Contract__r.FEC_Product_Code__c;
                }
                
                result.put('accountNumber', accountNumber);
                result.put('cifNumber',
                interactionCase.FEC_Account_or_Contract__r.FEC_CIF_Number__c);
                result.put('productCode', productCode);
                result.put('hasContractAccount',
                interactionCase.FEC_Has_Account_or_Contract__c);
                result.put('phone', interactionCase.FEC_Phone_Number__c);
                
            }
            
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage());
            return JSON.serialize(new Map<String, Object>());
        }
    }
    
    @AuraEnabled
    public static string getCustomerHistoryId(Id caseId){
        try {
            Case c = [
            SELECT Id, FEC_Account_or_Contract__c    
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
            return c.FEC_Account_or_Contract__c;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String getAccountNumberCustomerCase(String caseId, String customerHistoryId){
        try {
            Case customerCase = [
            SELECT Id, FEC_Product_Type__r.Name,
                   FEC_Account_or_Contract__r.FEC_Contract_Number__c,
                   FEC_Account_or_Contract__r.FEC_Account_Number__c,
                   FEC_Account_or_Contract__r.FEC_Product_Code__c,
                   FEC_Account_or_Contract__r.FEC_CIF_Number__c,
                   FEC_Has_Account_or_Contract__c,
                   FEC_Phone_Number__c 
            FROM Case
            WHERE Id = :caseId AND FEC_Account_or_Contract__c = :customerHistoryId
            LIMIT 1
        ];
            
            Map<String, Object> result = new Map<String, Object>();
            
            if (customerCase.FEC_Account_or_Contract__r != null) {
                
                String productCode =
                    customerCase.FEC_Product_Type__r.Name ;
                
                String accountNumber;
                
                // 🎯 CORE LOGIC
                if (productCode.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_LOAN.toLowerCase() ||
                productCode.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE.toLowerCase()) {
                    
                    accountNumber =
                        customerCase.FEC_Account_or_Contract__r.FEC_Contract_Number__c;
                    
                } else if (productCode.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_CARD.toLowerCase()) {
                    
                    accountNumber =
                        customerCase.FEC_Account_or_Contract__r.FEC_Account_Number__c;
                }else if(productCode.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_UBANK.toLowerCase()) {
                    accountNumber = customerCase.FEC_Account_or_Contract__r.FEC_Product_Code__c;
                }
                
                result.put('accountNumber', accountNumber);
                result.put('cifNumber',
                customerCase.FEC_Account_or_Contract__r.FEC_CIF_Number__c);
                result.put('productCode', productCode);
                result.put('hasContractAccount',
                customerCase.FEC_Has_Account_or_Contract__c);
                result.put('phone', customerCase.FEC_Phone_Number__c);
                
            }
            
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage());
            return JSON.serialize(new Map<String, Object>());
        }
    }
    
    @AuraEnabled
    public static string getInteractionViewMode(Id caseId){
        try {
            Case c = [
            SELECT FEC_Interaction_View_Mode__c    
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
            return c.FEC_Interaction_View_Mode__c;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id getInteractionIdFromCustomerCase(Id caseId) {
        Case c = [
        SELECT FEC_Interaction__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
    ];
        return c.FEC_Interaction__c;
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
            
            // ================= 1. COLLECT CARD NUMBERS =================
            Set<String> cardNumbers = new Set<String>();
            
            for (FEC_GetProductListCallout.ProductInfo p : res.products) {
                if (String.isNotBlank(p.accountNumber) &&
                Pattern.matches(FEC_ConstantCommon.PATTERN_CARD, p.accountNumber)) {
                    
                    cardNumbers.add(p.accountNumber);
                }
            }
            
            // ================= 2. CALLOUT (OUTSIDE LOOP) =================
            Map<String, String> cardIndicatorMap = new Map<String, String>();
            
            if (!cardNumbers.isEmpty()) {
                cardIndicatorMap = fetchCardIndicators(cardNumbers);
            }
            
            // ================= 3. BUILD RESULT =================
            for (FEC_GetProductListCallout.ProductInfo p : res.products) {
                
                System.debug('Product Info: ' + JSON.serialize(p));
                
                GetProductsListResponse item = new GetProductsListResponse();
                
                if (String.isNotBlank(p.accountNumber) &&
                Pattern.matches(FEC_ConstantCommon.PATTERN_CARD, p.accountNumber)) {
                    
                    item.accountContractNumber = p.accountNumber;
                    item.productType = FEC_ConstantCommon.PRODUCT_TYPE_CARD;
                    
                    String indicator = cardIndicatorMap.get(p.accountNumber);
                    
                    item.productName = indicator;
                    
                } else if (String.isNotBlank(p.contractNumber)) {
                    
                    String contract = p.contractNumber;
                    
                    if (Pattern.matches(FEC_ConstantCommon.PATTERN_INSURANCE, contract)) {
                        item.accountContractNumber = contract;
                        item.productType = FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE;
                    }
                    else if (Pattern.matches(FEC_ConstantCommon.PATTERN_LOAN, contract)) {
                        item.accountContractNumber = contract;
                        item.productType = FEC_ConstantCommon.PRODUCT_TYPE_LOAN;
                    }
                    
                    item.productName = p.productName;
                }
                
                results.add(item);
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        
        return results;
    }
    
    
    private static Map<String, String> fetchCardIndicators(Set<String> cardNumbers) {
        
        Map<String, String> result = new Map<String, String>();
        
        for (String acc : cardNumbers) {
            try {
                String transId = UUID.randomUUID().toString();
                String requestorId = FEC_ConstantCommon.REQUESTOR_CRM;
                String dateTimeStr = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
                
                FEC_GetCardBasicInfo.ResponseWrapper res =
                    FEC_GetCardBasicInfo.callGetCardBasicInfo(
                    transId,
                requestorId,
                dateTimeStr,
                acc
                    );
                
                if (res != null &&
                    res.CardBasicInfo != null &&
                    res.CardBasicInfo.MainCard != null &&
                res.CardBasicInfo.MainCard.PlasticIndicator != null) {
                    
                    result.put(acc, res.CardBasicInfo.MainCard.PlasticIndicator);
                }
                
            } catch (Exception e) {
                System.debug('Card API error: ' + acc + ' - ' + e.getMessage());
            }
        }
        
        return result;
    }
    
    @AuraEnabled
    public static void createHistory( Id caseId, String selectedAccountContractNumber, String selectedType, String cifNumber, String phone) {
        
        System.debug('selectedType = ' + selectedType);
        System.debug('selectedAccountContractNumber = ' + selectedAccountContractNumber);
        System.debug('cifNumber = ' + cifNumber);
        System.debug('phone = ' + phone);
        
        if(selectedType != FEC_ConstantCommon.PRODUCT_TYPE_UBANK){
            if (selectedAccountContractNumber == null || selectedAccountContractNumber.trim() == '') {
                throw new AuraHandledException(System.Label.FEC_MSG_Create_Customer_History_Field_Null);
            }
        }
        FEC_Customer_History__c rec = new FEC_Customer_History__c();
        rec.Name = selectedAccountContractNumber;
        if (selectedType.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE || selectedType.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_LOAN.toLowerCase()) {
            rec.FEC_Contract_Number__c = selectedAccountContractNumber;
        } else if (selectedType.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_CARD.toLowerCase()) {
            rec.FEC_Account_Number__c = selectedAccountContractNumber;
        }else if(selectedType.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_UBANK.toLowerCase()){
            rec.FEC_Account_Number__c = selectedAccountContractNumber;
        }
        rec.FEC_Case__c = caseId;
        rec.FEC_Product_Code__c = selectedType;
        rec.FEC_CIF_Number__c = cifNumber;
        System.debug('rec BEFORE insert = ' + rec);
        
        FEC_Product_Type__c productType = getProductTypeByName(selectedType);
        try {
            insert rec;
            // Update interaction with new customer history
            Id productTypeId = (productType != null) ? productType.Id : null;
            
            updateInteractionWithNewCustomerHistory(
                caseId,
            rec.Id,
            productTypeId,
            selectedType,
            selectedAccountContractNumber
                );
            
            System.enqueueJob(new FEC_FullCustomerIntegrationJob(
                rec.Id,
            cifNumber,
            phone,
            selectedAccountContractNumber
                ));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    
    @AuraEnabled
    public static void createHistoryNonExistingCustomer( Id caseId, String selectedType) {
        
        
        FEC_Customer_History__c rec = new FEC_Customer_History__c();
        
        if(selectedType.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_UBANK.toLowerCase())
        {
            rec.Name = FEC_ConstantCommon.PRODUCT_TYPE_UBANK;
            rec.FEC_Account_Number__c = FEC_ConstantCommon.PRODUCT_TYPE_UBANK;
        }
        else if(selectedType.toLowerCase() == FEC_ConstantCommon.PRODUCT_NON_EXISTING_CUSTOMER.toLowerCase())
        {
            rec.Name = FEC_ConstantCommon.PRODUCT_NON_EXISTING_CUSTOMER;
            rec.FEC_Account_Number__c = FEC_ConstantCommon.PRODUCT_NON_EXISTING_CUSTOMER;
        }
        
        rec.FEC_Case__c = caseId;
        rec.FEC_Product_Code__c = selectedType;
        rec.FEC_Customer_Type__c = FEC_ConstantCommon.CUSTOMER_HISTORY_NON_EXISTING_CUSTOMER;
        FEC_Product_Type__c productType = null;
        
        if(selectedType == FEC_ConstantCommon.PRODUCT_TYPE_UBANK) {
            productType = getProductTypeByName(selectedType);
        }
        
        try {
            insert rec;
            // Update interaction with new customer history
            if(productType != null) {
                updateInteractionWithNewCustomerHistory(caseId, rec.Id, productType.Id, selectedType, null);
            } else {
                updateInteractionWithNewCustomerHistory(caseId, rec.Id, null, selectedType, null);
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updateInteractionWithNewCustomerHistory(
        Id caseId,
    Id customerHistoryId,
    Id productTypeId,
    String productType,
    String accountContractNumber
    ) {
        Case c = new Case(
            Id = caseId,
        FEC_Account_or_Contract__c = customerHistoryId,
        FEC_Product_Type__c = productTypeId
            );
        
        if (productType.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_LOAN.toLowerCase() ||
        productType.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE.toLowerCase()) {
            
            if (String.isNotBlank(accountContractNumber)) {
                c.FEC_Contract_Number__c = accountContractNumber;
                c.FEC_Account_Number__c = null  ;
            }
            
        } else if (productType.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_CARD.toLowerCase()) {
            
            if (String.isNotBlank(accountContractNumber)) {
                c.FEC_Account_Number__c = accountContractNumber;
                c.FEC_Contract_Number__c = null;
            }
        }else if(productType.toLowerCase() == FEC_ConstantCommon.PRODUCT_TYPE_UBANK.toLowerCase()){
            c.FEC_Account_Number__c = FEC_ConstantCommon.PRODUCT_TYPE_UBANK;
            c.FEC_Contract_Number__c = null;
        }
        
        try {
            update c;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }
    
    @AuraEnabled
    public static FEC_Product_Type__c getProductTypeByName(String keyword) {
        try {
            if (String.isBlank(keyword)) {
                return null;
            }
            
            String likePattern = '%' + keyword.trim() + '%';
            
            List<FEC_Product_Type__c> productTypes = [
                SELECT Id, FEC_Code__c, FEC_Name_VN__c, Name
                FROM FEC_Product_Type__c
                WHERE Name LIKE :likePattern
            ];
            if (productTypes.isEmpty()) {
                return null;
            }
            return productTypes[0];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String getInteractionCustomerType(Id caseId){
        try {
            Case c = [
            SELECT FEC_Customer_Type__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
         ];
            return c.FEC_Customer_Type__c;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    //Hieutt74 - Get account/contract number from first customer history record of interaction
    //Updated by Hieutt74 - 2026-04-17 - Add product code check to ensure correct account/contract number is returned
    @AuraEnabled
    public static String getInteractionFirstCustomerHistoryAccountNumber(Id caseId){
        try {
            if (caseId == null) return null;
            
            List<FEC_Customer_History__c> histories = [
            SELECT Id, FEC_Account_Number__c, FEC_Contract_Number__c, CreatedDate, FEC_Product_Code__c  
            FROM FEC_Customer_History__c 
            WHERE FEC_Case__c = :caseId 
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
            
            if (histories.isEmpty()) return null;
            
            FEC_Customer_History__c record = histories[0];
            
            String productCode = record.FEC_Product_Code__c;
            if (String.isBlank(productCode)) return null;
            
            if (productCode.equalsIgnoreCase(FEC_ConstantCommon.PRODUCT_TYPE_LOAN) ||
            productCode.equalsIgnoreCase(FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE)) {
                
                return record.FEC_Contract_Number__c;
                
            } else if (productCode.equalsIgnoreCase(FEC_ConstantCommon.PRODUCT_TYPE_CARD)) {
                
                return record.FEC_Account_Number__c;
            }
            
            return null;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}