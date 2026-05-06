public with sharing class FEC_AssignmentExecuteService {
    
    public class ExecuteVisibilityResult {
        @AuraEnabled public Boolean value;
        @AuraEnabled public Boolean shouldUpdate;
    }
    
    @AuraEnabled
    public static ExecuteVisibilityResult canExecuteAssignment(Id caseId) {
        
        Id userId = UserInfo.getUserId();
        
        List<FEC_Assignment__c> assignments = [
            SELECT
                Id,
                FEC_Assignment_Owner__c,
                FEC_Assignment_Status__c
            FROM FEC_Assignment__c
            WHERE FEC_Case__c = :caseId
        ];
        
        Boolean canExecute = false;
        
        for (FEC_Assignment__c a : assignments) {
            
            if (
                a.FEC_Assignment_Owner__c == userId &&
                !(
                a.FEC_Assignment_Status__c == FEC_ConstantCommon.STATUS_COMPLETED ||
                a.FEC_Assignment_Status__c == FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED ||
                a.FEC_Assignment_Status__c == FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED ||
                a.FEC_Assignment_Status__c == FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED ||
                a.FEC_Assignment_Status__c == FEC_ConstantCommon.ASSIGNMENT_AUTORECALLED_STATUS ||
                a.FEC_Assignment_Status__c == FEC_ConstantCommon.ASSIGNMENT_AUTOCOMPLETE_STATUS
                )
            ) {
                canExecute = true;
                break;
            }
        }
        
        Case caseRecord = [
            SELECT
                Id,
                FEC_Can_Execute_Assignment__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        
        ExecuteVisibilityResult result = new ExecuteVisibilityResult();
        
        result.value = canExecute;
        
        result.shouldUpdate =
            caseRecord.FEC_Can_Execute_Assignment__c != canExecute;
        
        if (result.shouldUpdate) {
            
            try {
                
                FEC_CaseTriggerHandler.isSystemUpdate = true;
                
                update new Case(
                    Id = caseId,
                FEC_Can_Execute_Assignment__c = canExecute
                    );
                
            } finally {
                
                FEC_CaseTriggerHandler.isSystemUpdate = false;
                
            }
        }
        
        return result;
    }
}