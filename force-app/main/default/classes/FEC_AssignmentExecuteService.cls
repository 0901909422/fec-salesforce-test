public with sharing class FEC_AssignmentExecuteService {
    
    public class ExecuteVisibilityResult {
        @AuraEnabled public Boolean value;
        @AuraEnabled public Boolean shouldUpdate;
    }
    
    private static final Set<String> CLOSED_STATUSES = new Set<String>{
        FEC_ConstantCommon.STATUS_COMPLETED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED,
        FEC_ConstantCommon.ASSIGNMENT_AUTORECALLED_STATUS,
        FEC_ConstantCommon.ASSIGNMENT_AUTOCOMPLETE_STATUS
    };
    
    @AuraEnabled
    public static ExecuteVisibilityResult canExecuteAssignment(Id caseId) {
        
        Id userId = UserInfo.getUserId();
        
        // Integer activeAssignmentCount = [
        //     SELECT COUNT()
        //     FROM FEC_Assignment__c
        //     WHERE
        //         FEC_Case__c = :caseId
        //         AND FEC_Assignment_Owner__c = :userId
        //         AND FEC_Assignment_Status__c NOT IN :CLOSED_STATUSES
        // ];
        
        
        Set<Id> queueIds = new Set<Id>();
        
        for (GroupMember gm : [
            SELECT GroupId
            FROM GroupMember
            WHERE UserOrGroupId = :userId
        ]) {
            queueIds.add(gm.GroupId);
        }
        
        Integer activeAssignmentCount = [
            SELECT COUNT()
            FROM FEC_Assignment__c
            WHERE
                FEC_Case__c = :caseId
                AND FEC_Assignment_Status__c NOT IN :CLOSED_STATUSES
                AND (
                    FEC_Assignment_Owner__c = :userId
                    OR (
                        FEC_Assignment_Owner__c = null
                        AND FEC_OwnerID__c IN :queueIds
                    )
                )
        ];
        
        Boolean canExecute = activeAssignmentCount > 0;
        
        Case caseRecord = [
            SELECT
                Id,
                FEC_Can_Execute_Assignment__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        
        ExecuteVisibilityResult result =
            new ExecuteVisibilityResult();
        
        result.value = canExecute;
        
        Boolean currentValue =
            caseRecord.FEC_Can_Execute_Assignment__c == true;
        
        result.shouldUpdate =
            currentValue != canExecute;
        
        if (result.shouldUpdate) {
            
            try {
                
                FEC_CaseTriggerHandler.isSystemUpdate = true;
                
                update new Case(
                    Id = caseId,
                FEC_Can_Execute_Assignment__c = canExecute
                    );
                
            } catch (Exception e) {
                
                System.debug(
                    'FEC_AssignmentExecuteService ERROR: '
                    + e.getMessage()
                    );
                
                throw e;
                
            } finally {
                
                FEC_CaseTriggerHandler.isSystemUpdate = false;
            }
        }
        
        return result;
    }
}