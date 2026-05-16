public with sharing class FEC_SubProcessService {
    
    public class SubProcessWrapper {
        
        @AuraEnabled
        public Boolean showHoldCase = false;
        
        @AuraEnabled
        public Boolean showRemovePhone = false;
        
        @AuraEnabled
        public Boolean showDNB = false;
        
        @AuraEnabled
        public Boolean showTransferCall = false;
    }
    
    @AuraEnabled(cacheable=true)
    public static SubProcessWrapper getSubProcesses(
        Id recordId,
    Id productTypeId,
    Id categoryId,
    Id subCategoryId,
    Id subCodeId
    ) {
        
        SubProcessWrapper result =
            new SubProcessWrapper();
        
        try {
            
            // ===== VALIDATION =====
            
            if (
                productTypeId == null ||
                categoryId == null ||
                subCategoryId == null
            ) {
                return result;
            }
            
            // ===== BUILD QUERY =====
            
            String query =
                'SELECT ' +
                'Id, ' +
                'FEC_Remove_Phone__c, ' +
                'FEC_Do_Not_Bother__c, ' +
                'FEC_Transfer_Call_to_Collection__c ' +
                'FROM FEC_Nature_of_Case__c ' +
                'WHERE ' +
                'FEC_Product_Type__c = :productTypeId ' +
                'AND FEC_Category__c = :categoryId ' +
                'AND FEC_Sub_Category__c = :subCategoryId ';
            
            // ===== SUB CODE =====
            
            if (subCodeId == null) {
                
                query +=
                    'AND FEC_Sub_Code__c = null ';
                
            } else {
                
                query +=
                    'AND FEC_Sub_Code__c = :subCodeId ';
            }
            
            query += 'LIMIT 1';
            
            // ===== QUERY NOC =====
            
            List<FEC_Nature_of_Case__c> nocList =
                Database.query(query);
            
            if (nocList.isEmpty()) {
                return result;
            }
            
            FEC_Nature_of_Case__c noc =
                nocList[0];
            
            // ===== REMOVE PHONE =====
            
            result.showRemovePhone =
                noc.FEC_Remove_Phone__c;
            
            // ===== DNB =====
            
            result.showDNB =
                noc.FEC_Do_Not_Bother__c;
            
            // ===== TRANSFER CALL =====
            
            result.showTransferCall =
                noc.FEC_Transfer_Call_to_Collection__c;
            
            // ===== HOLD CASE =====
            
            List<FEC_Hold_Case_Config__c> holdConfigs = [
                SELECT Id
                FROM FEC_Hold_Case_Config__c
                WHERE FEC_Nature_of_Cases__c = :noc.Id
                LIMIT 1
            ];
            
            result.showHoldCase =
                !holdConfigs.isEmpty();
            
            return result;
            
        } catch (Exception ex) {
            
            throw new AuraHandledException(
                ex.getMessage()
                );
        }
    }
    
    
    
    
    @AuraEnabled(cacheable=true)
    public static SubProcessWrapper getSubmittedSubProcesses(Id caseId) {
        
        SubProcessWrapper result =
            new SubProcessWrapper();
        
        try {
            
            List<Case> caseRecords = [
            SELECT
                Id,
                FEC_Is_Submited__c,
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_SubCategory__c,
                FEC_SubCode__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
            
            /*
             * Not submitted
             */
            if (
                caseRecords.isEmpty() ||
                !caseRecords[0].FEC_Is_Submited__c
            ) {
                return result;
            }
            
            /*
             * Get subprocess config from NOC
             */
            return getSubProcesses(
                caseRecords[0].Id,
            caseRecords[0].FEC_Product_Type__c,
            caseRecords[0].FEC_Category__c,
            caseRecords[0].FEC_SubCategory__c,
            caseRecords[0].FEC_SubCode__c
                );
            
        } catch (Exception e) {
            
            System.debug(
                'getSubmittedSubProcesses ERROR = ' +
                e.getMessage()
                );
            
            throw new AuraHandledException(
                e.getMessage()
                );
        }
    }
}