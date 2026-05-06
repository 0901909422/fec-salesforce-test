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
        
        Boolean canExecute = false;
        
        // 1. Check mode
        if (c.FEC_Interaction_View_Mode__c == FEC_ConstantCommon.INTERACTION_REVIEW_MODE) {
            
            // 2. Check closed
            if (!c.IsClosed) {
                
                Boolean isOwnerUser = (c.OwnerId == userId);
                Boolean isQueueMember = false;
                
                // 3. Nếu owner là Queue
                if (String.valueOf(c.OwnerId).startsWith(FEC_ConstantCommon.QUEUE_ID_START)) {
                    
                    List<GroupMember> gm = [
                        SELECT Id
                        FROM GroupMember
                        WHERE GroupId = :c.OwnerId
                        AND UserOrGroupId = :userId
                        LIMIT 1
                    ];
                    
                    isQueueMember = !gm.isEmpty();
                }
                
                if (isOwnerUser || isQueueMember) {
                    
                    Integer count =
                        c.FEC_Assignment_Count__c == null
                        ? 0
                        : Integer.valueOf(c.FEC_Assignment_Count__c);
                    
                    // 4. Assignment logic
                    if (count == 0) {
                        
                        canExecute = true;
                        
                    } else {
                        
                        // 5. Profile check
                        User u = [
                            SELECT Profile.Name
                            FROM User
                            WHERE Id = :userId
                        ];
                        
                        if (
                            u.Profile.Name == FEC_ConstantCommon.TEAM_CS_SUPPORT ||
                            u.Profile.Name == FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE
                        ) {
                            canExecute = true;
                        }
                    }
                }
            }
        }
        
        ExecuteVisibilityResult result = new ExecuteVisibilityResult();
        
        result.value = canExecute;
        
        result.shouldUpdate =
            c.FEC_Can_Execute__c != canExecute;
        
        if (result.shouldUpdate) {
            
            try {
                
                FEC_CaseTriggerHandler.isSystemUpdate = true;
                
                update new Case(
                    Id = caseId,
                FEC_Can_Execute__c = canExecute
                    );
                
            } finally {
                
                FEC_CaseTriggerHandler.isSystemUpdate = false;
                
            }
        }
        
        return result;
    }
}