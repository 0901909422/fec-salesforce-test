public with sharing class FEC_CaseExecuteService {
    
    public class ExecuteVisibilityResult {
        @AuraEnabled public Boolean value;
        @AuraEnabled public Boolean shouldUpdate;
    }
    
    @AuraEnabled
    public static ExecuteVisibilityResult canExecute(Id caseId) {
        
        Case c = [
            SELECT
                Id,
                OwnerId,
                IsClosed,
                FEC_Interaction_View_Mode__c,
                FEC_Assignment_Count__c,
                FEC_Can_Execute__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        
        Id userId = UserInfo.getUserId();
        
        System.debug('=== FEC_CaseExecuteService START ===');
        System.debug('Case Id: ' + caseId);
        System.debug('User Id: ' + userId);
        
        Boolean currentValue =
            c.FEC_Can_Execute__c == true;
        
        /*
         * Nếu đã TRUE rồi
         * và owner hiện tại vẫn là user
         * thì không recompute nữa
         */
        if (
            currentValue &&
            c.OwnerId == userId
        ) {
            
            System.debug('SKIP: already TRUE and same owner');
            
            ExecuteVisibilityResult result =
                new ExecuteVisibilityResult();
            
            result.value = true;
            result.shouldUpdate = false;
            
            return result;
        }
        
        Boolean canExecute = false;
        
        // 1. View mode check
        if (
            c.FEC_Interaction_View_Mode__c !=
            FEC_ConstantCommon.INTERACTION_REVIEW_MODE
        ) {
            
            System.debug('FAILED: Invalid interaction mode');
            
            return buildResult(c, false);
        }
        
        // 2. Closed check
        if (c.IsClosed) {
            
            System.debug('FAILED: Case is closed');
            
            return buildResult(c, false);
        }
        
        Boolean isOwnerUser =
            c.OwnerId == userId;
        
        Boolean isQueueMember = false;
        
        // 3. Queue member check
        if (
            c.OwnerId != null &&
            String.valueOf(c.OwnerId)
                .startsWith(FEC_ConstantCommon.QUEUE_ID_START)
        ) {
            
            isQueueMember = [
                SELECT COUNT()
                FROM GroupMember
                WHERE
                    GroupId = :c.OwnerId
                    AND UserOrGroupId = :userId
            ] > 0;
        }
        
        System.debug('isOwnerUser=' + isOwnerUser);
        System.debug('isQueueMember=' + isQueueMember);
        
        if (!(isOwnerUser || isQueueMember)) {
            
            System.debug(
                'FAILED: User is not owner or queue member'
            );
            
            return buildResult(c, false);
        }
        
        Integer assignmentCount =
            c.FEC_Assignment_Count__c == null
            ? 0
            : Integer.valueOf(c.FEC_Assignment_Count__c);
        
        System.debug(
            'assignmentCount=' + assignmentCount
        );
        
        // 4. No assignment
        if (assignmentCount == 0) {
            
            canExecute = true;
            
        } else {
            
            // 5. Profile check
            String profileName = [
                SELECT Profile.Name
                FROM User
                WHERE Id = :userId
            ].Profile.Name;
            
            System.debug(
                'profileName=' + profileName
            );
            
            canExecute =
                profileName ==
                    FEC_ConstantCommon.TEAM_CS_SUPPORT
                ||
                profileName ==
                    FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE;
        }
        
        System.debug(
            'FINAL canExecute=' + canExecute
        );
        
        return buildResult(c, canExecute);
    }
    
    private static ExecuteVisibilityResult buildResult(
        Case c,
        Boolean canExecute
    ) {
        
        ExecuteVisibilityResult result =
            new ExecuteVisibilityResult();
        
        result.value = canExecute;
        
        Boolean currentValue =
            c.FEC_Can_Execute__c == true;
        
        result.shouldUpdate =
            currentValue != canExecute;
        
        System.debug(
            'currentValue=' + currentValue
        );
        
        System.debug(
            'shouldUpdate=' + result.shouldUpdate
        );
        
        if (result.shouldUpdate) {
            
            try {
                
                FEC_CaseTriggerHandler.isSystemUpdate = true;
                
                update new Case(
                    Id = c.Id,
                    FEC_Can_Execute__c = canExecute
                );
                
                System.debug(
                    'Case updated successfully'
                );
                
            } catch (Exception e) {
                
                System.debug(
                    'UPDATE ERROR: ' + e.getMessage()
                );
                
                throw e;
                
            } finally {
                
                FEC_CaseTriggerHandler.isSystemUpdate = false;
            }
        }
        
        return result;
    }
}