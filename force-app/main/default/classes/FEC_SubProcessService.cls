public with sharing class FEC_SubProcessService {
    
    public class SubProcessWrapper {
        
        @AuraEnabled
        public Boolean showHoldCase = false;

        @AuraEnabled
        public Boolean showHoldCaseManual = false;

        @AuraEnabled
        public Boolean showHoldCaseAuto = false;
        
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

            if (recordId != null &&
                (productTypeId == null || categoryId == null || subCategoryId == null)) {
                List<Case> casesFromRecord = [
                    SELECT
                        FEC_Product_Type__c,
                        FEC_Category__c,
                        FEC_SubCategory__c,
                        FEC_SubCode__c,
                        FEC_NFU_Description_Result__c
                    FROM Case
                    WHERE Id = :recordId
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];
                if (!casesFromRecord.isEmpty()) {
                    Case caseRow = casesFromRecord[0];
                    productTypeId = caseRow.FEC_Product_Type__c;
                    categoryId = caseRow.FEC_Category__c;
                    subCategoryId = caseRow.FEC_SubCategory__c;
                    subCodeId = caseRow.FEC_SubCode__c;
                    if (String.isNotBlank(caseRow.FEC_NFU_Description_Result__c)) {
                        result.showHoldCaseAuto = true;
                        result.showHoldCase = true;
                    }
                }
            }
            
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
            
            // ===== HOLD CASE — Manual =====
            // tungnm37: chỉ hiển thị khi có config Manual + Active + Stage khớp với stage hiện tại của case
            Id currentStageId = null;
            if (recordId != null) {
                List<Case> caseForStage = [
                    SELECT FEC_Current_Case_Stage__c
                    FROM Case WHERE Id = :recordId
                    WITH SECURITY_ENFORCED LIMIT 1
                ];
                if (!caseForStage.isEmpty()) {
                    currentStageId = caseForStage[0].FEC_Current_Case_Stage__c;
                }
            }

            List<FEC_Hold_Case_Config__c> manualConfigs = [
                SELECT Id
                FROM FEC_Hold_Case_Config__c
                WHERE FEC_Nature_of_Cases__c = :noc.Id
                  AND Hold_Case_Type__c = 'Manual'
                  AND FEC_Active__c = true
                  AND FEC_Case_Stage__c != null
                  AND FEC_Case_Stage__c = :currentStageId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            result.showHoldCaseManual = !manualConfigs.isEmpty();

            // ===== HOLD CASE — Auto =====
            List<FEC_Hold_Case_Config__c> autoConfigs = [
                SELECT Id
                FROM FEC_Hold_Case_Config__c
                WHERE FEC_Nature_of_Cases__c = :noc.Id
                  AND Hold_Case_Type__c = 'Auto'
                  AND FEC_Active__c = true
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            result.showHoldCaseAuto = result.showHoldCaseAuto || !autoConfigs.isEmpty();

            result.showHoldCase = result.showHoldCaseManual || result.showHoldCaseAuto;
            
            return result;
            
        } catch (Exception ex) {
            
            throw new AuraHandledException(
                ex.getMessage()
                );
        }
    }
    
    @AuraEnabled(cacheable = true)
    public static Boolean getCase(Id caseId) {
       
        try {
            List<Case> caseRecord =
                [SELECT FEC_Is_Submited__c FROM Case WHERE Id = : caseId LIMIT 1];
            
            System.debug('FEC_Is_Submited__c = ' + caseRecord[0].FEC_Is_Submited__c);
            
            return caseRecord[0].FEC_Is_Submited__c;
            
        } catch (Exception e) {
            System.debug('getCase ERROR = ' + e.getMessage());
            
            throw new AuraHandledException(e.getMessage());
        }
    }
}