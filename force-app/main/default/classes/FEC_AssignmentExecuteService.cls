public with sharing class FEC_AssignmentExecuteService {
    public class ExecuteVisibilityResult {
        @AuraEnabled public Boolean value;
        @AuraEnabled public Boolean shouldUpdate;
    }
    
    private static final Set<String> CLOSED_STATUSES =
    new Set<String>{FEC_ConstantCommon.STATUS_COMPLETED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED,
        FEC_ConstantCommon.ASSIGNMENT_AUTORECALLED_STATUS,
    FEC_ConstantCommon.ASSIGNMENT_AUTOCOMPLETE_STATUS};
    
    @AuraEnabled
    public static ExecuteVisibilityResult canExecuteAssignment(Id caseId) {
        Id currentUserId = UserInfo.getUserId();
        
        System.debug('==============================');
        System.debug('START canExecuteAssignment');
        System.debug('caseId = ' + caseId);
        System.debug('currentUserId = ' + currentUserId);
        System.debug('==============================');
        
        /*
         * 1. Query case
         */
        Case caseRecord = getCaseForExecute(caseId);
        
        
        /*
         * 3. Active assignment check
         */
        Boolean hasActiveAssignment = hasActiveAssignment(caseId);
        
        System.debug('hasActiveAssignment = ' + hasActiveAssignment);
        
        if (!hasActiveAssignment) {
            System.debug('FAILED: No active assignment');
            
            return buildResult(caseRecord, false);
        }
        
        /*
         * 4. Assignment Users access
         */
        Boolean hasAccess = hasAssignmentUsersAccess(caseRecord, currentUserId);
        
        System.debug('hasAccess = ' + hasAccess);
        
        /*
         * 5. Return result
         */
        return buildResult(caseRecord, hasAccess);
    }
    
    /////////Helper Methods/////////
    
    private static Case getCaseForExecute(Id caseId) {
        return [
      SELECT Id, IsClosed, FEC_Can_Execute_Assignment__c,
      FEC_Assignment_Users__c FROM Case WHERE Id = : caseId LIMIT 1
    ];
    }
    
    private static Boolean hasActiveAssignment(Id caseId) {
        Integer countAssignment =
            [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = : caseId AND
              FEC_Assignment_Status__c NOT IN : CLOSED_STATUSES];
        
        return countAssignment > 0;
    }
    
    private static Boolean hasAssignmentUsersAccess(
    Case caseRecord, Id currentUserId) {
        if (caseRecord == null || currentUserId == null
        || String.isBlank(caseRecord.FEC_Assignment_Users__c)) {
            return false;
        }
        
        Set<String> assignmentValues =
            parseAssignmentUsers(caseRecord.FEC_Assignment_Users__c);
        
        /*
         * 1. User match
         */
        if (assignmentValues.contains(String.valueOf(currentUserId))) {
            return true;
        }
        
        /*
         * 2. Role match
         */
        User currentUser =
            [SELECT UserRoleId FROM User WHERE Id = : currentUserId LIMIT 1];
        
        if (currentUser.UserRoleId != null
        && assignmentValues.contains(String.valueOf(currentUser.UserRoleId))) {
            return true;
        }
        
        /*
         * 3. Queue match
         */
        for (String value : assignmentValues) {
            if (isQueueId(value)) {
                Id memberId = (Id) value;
                
                if (isUserInQueue(currentUserId, memberId)) {
                    return true;
                }
            }
        }
        
        return false;
    }
    
    private static Set<String> parseAssignmentUsers(String assignmentUsers) {
        Set<String> values = new Set<String>();
        
        if (String.isBlank(assignmentUsers)) {
            return values;
        }
        
        for (String value : assignmentUsers.split(';')) {
            if (!String.isBlank(value)) {
                values.add(value.trim());
            }
        }
        
        return values;
    }
    
    private static Boolean isUserInQueue(Id userId, Id queueId) {
        if (userId == null || queueId == null) {
            return false;
        }
        
        /*
         * Validate queue
         */
        List<Group> queueGroups =
            [SELECT Id, Type FROM Group WHERE Id = : queueId LIMIT 1];
        
        if (queueGroups.isEmpty() || queueGroups[0].Type != 'Queue') {
            return false;
        }
        
        /*
         * BFS traversal
         */
        Set<Id> visitedGroupIds = new Set<Id>();
        
        Set<Id> groupsToProcess = new Set<Id>{queueId};
        
        while (!groupsToProcess.isEmpty()) {
            Set<Id> currentBatch = new Set<Id>(groupsToProcess);
            
            groupsToProcess.clear();
            
            visitedGroupIds.addAll(currentBatch);
            
            List<GroupMember> members = [
      SELECT GroupId,
      UserOrGroupId FROM GroupMember WHERE GroupId IN : currentBatch
    ];
            
            for (GroupMember gm : members) {
                Id memberId = gm.UserOrGroupId;
                
                /*
                 * Direct user
                 */
                if (memberId == userId) {
                    return true;
                }
                
                /*
                 * Nested group
                 * - Public Group
                 * - Role
                 * - RoleAndSubordinates
                 */
                if (memberId.getSObjectType() == Group.SObjectType) {
                    if (!visitedGroupIds.contains(memberId)
                    && !groupsToProcess.contains(memberId)) {
                        groupsToProcess.add(memberId);
                    }
                }
            }
        }
        
        return false;
    }
    
    private static ExecuteVisibilityResult buildResult(
    Case caseRecord, Boolean canExecute) {
        ExecuteVisibilityResult result = new ExecuteVisibilityResult();
        
        result.value = canExecute;
        
        Boolean currentValue = caseRecord.FEC_Can_Execute_Assignment__c == true;
        
        result.shouldUpdate = currentValue != canExecute;
        
        System.debug('currentValue = ' + currentValue);
        
        System.debug('newValue = ' + canExecute);
        
        System.debug('shouldUpdate = ' + result.shouldUpdate);
        
        /*
         * Update Dynamic Action field
         */
        if (result.shouldUpdate) {
            try {
                System.debug('START UPDATE CASE');
                
                FEC_CaseTriggerHandler.isSystemUpdate = true;
                
                update new Case(
                    Id = caseRecord.Id, FEC_Can_Execute_Assignment__c = canExecute);
                
                System.debug('Case updated successfully');
                
            } catch (Exception e) {
                System.debug('FEC_AssignmentExecuteService ERROR: ' + e.getMessage());
                
                throw e;
                
            } finally {
                FEC_CaseTriggerHandler.isSystemUpdate = false;
            }
        }
        
        return result;
    }
    
    private static Boolean isQueueId(
        String value
    ) {
        
        return
            !String.isBlank(value)
            &&
            value.startsWith('00G')
            &&
            value.length() >= 15;
    }
    //----------------------------//
    
    @AuraEnabled
    public static void executeAssignment(Id caseId) {
        Id userId = UserInfo.getUserId();
        
        System.debug('==============================');
        System.debug('START executeAssignment');
        System.debug('caseId = ' + caseId);
        System.debug('userId = ' + userId);
        System.debug('==============================');
        
        User currentUser =
            [SELECT Id, UserRoleId FROM User WHERE Id = : userId LIMIT 1];
        
        /*
         * STEP 1
         * Query assignments
         */
        List<FEC_Assignment__c> assignments = [
    SELECT Id, Name, FEC_Assignment_Name__c, FEC_OwnerID__c,
    FEC_Assignment_Owner__c,
    FEC_Assignment_Status__c FROM FEC_Assignment__c WHERE FEC_Case__c = : caseId
        AND FEC_Assignment_Status__c NOT IN : CLOSED_STATUSES
  ];
        
        System.debug('assignments size = ' + assignments.size());
        
        /*
         * STEP 2
         * Collect queue names
         */
        Set<String> queueNames = new Set<String>();
        
        for (FEC_Assignment__c assignment : assignments) {
            if (assignment.FEC_Assignment_Owner__c == null
            && !String.isBlank(assignment.FEC_OwnerID__c)) {
                queueNames.add(assignment.FEC_OwnerID__c);
            }
        }
        
        System.debug('queueNames = ' + queueNames);
        
        /*
         * STEP 3
         * Query queues by name
         */
        Map<String, Group> queueByName = new Map<String, Group>();
        
        if (!queueNames.isEmpty()) {
            for (Group g : [
           SELECT Id, Name,
           Type FROM Group WHERE Type = 'Queue' AND Name IN : queueNames
         ]) {
                queueByName.put(g.Name, g);
            }
        }
        
        System.debug('queueByName = ' + queueByName);
        
        /*
         * STEP 4
         * Find executable assignments
         */
        List<FEC_Assignment__c> assignmentsToUpdate = new List<FEC_Assignment__c>();
        
        for (FEC_Assignment__c assignment : assignments) {
            Boolean matched = false;
            
            /*
             * DIRECT OWNER
             */
            if (assignment.FEC_Assignment_Owner__c == userId) {
                matched = true;
                
                System.debug('MATCH DIRECT OWNER => ' + assignment.Id);
            }
            
            /*
             * QUEUE OWNER
             */
            if (!matched && assignment.FEC_Assignment_Owner__c == null
            && queueByName.containsKey(assignment.FEC_OwnerID__c)) {
                Group queueGroup = queueByName.get(assignment.FEC_OwnerID__c);
                
                System.debug('CHECK QUEUE => ' + queueGroup.Name);
                
                /*
                 * direct user in queue
                 */
                Integer directUserCount =
                    [SELECT COUNT() FROM GroupMember WHERE
                GroupId = : queueGroup.Id AND UserOrGroupId = : userId];
                
                if (directUserCount > 0) {
                    matched = true;
                    
                    System.debug('MATCH DIRECT QUEUE USER');
                }
                
                /*
                 * role in queue
                 */
                if (!matched && currentUser.UserRoleId != null) {
                    Integer roleCount =
                        [SELECT COUNT() FROM GroupMember WHERE
                  GroupId = : queueGroup.Id AND UserOrGroupId IN(
                      SELECT Id FROM Group WHERE Type IN('Role',
                          'RoleAndSubordinates', 'RoleAndSubordinatesInternal')
                          AND RelatedId =
                          : currentUser.UserRoleId)];
                    
                    if (roleCount > 0) {
                        matched = true;
                        
                        System.debug('MATCH ROLE QUEUE');
                    }
                }
            }
            
            /*
             * TAKE OWNERSHIP
             */
            if (matched) {
                System.debug('TAKE ASSIGNMENT => ' + assignment.Id);
                
                assignment.FEC_Assignment_Owner__c = userId;
                assignmentsToUpdate.add(assignment);
            }
        }
        
        /*
         * STEP 5
         * UPDATE
         */
        if (!assignmentsToUpdate.isEmpty()) {
            try {
                FEC_CaseTriggerHandler.isSystemUpdate = true;
                
                update assignmentsToUpdate;
                
                System.debug('Assignments updated successfully');
                
            } catch (Exception e) {
                System.debug('executeAssignment ERROR = ' + e.getMessage());
                
                throw e;
                
            } finally {
                FEC_CaseTriggerHandler.isSystemUpdate = false;
            }
        }
    }
    
    @AuraEnabled
    public static String setAssignmentViewMode(Id recordId, String viewMode) {
        if (recordId == null) return null;
        
        List<Case> caselst = [
            SELECT
                Id,
                FEC_Assigment_Mode__c
            FROM Case
            WHERE Id = :recordId
        ];
        
        if (caselst.isEmpty())
            return null;
        
        Case c = caselst.get(0);
        
        FEC_CaseTriggerHandler.isSystemUpdate = true;
        update new Case(
            Id = recordId,
        FEC_Assigment_Mode__c = viewMode
            );
        return viewMode;
    }
    
    
    @AuraEnabled
    public static void forceShowExecuteAssignment(Id caseId) {
        if (caseId == null) {
            return;
        }
        
        try {
            System.debug('START forceShowExecuteAssignment');
            
            System.debug('caseId = ' + caseId);
            
            FEC_CaseTriggerHandler.isSystemUpdate = true;
            
            update new Case(Id = caseId, FEC_Can_Execute_Assignment__c = true);
            
            System.debug('FEC_Can_Execute_Assignment__c = true');
            
        } catch (Exception e) {
            System.debug('forceShowExecuteAssignment ERROR = ' + e.getMessage());
            
            throw new AuraHandledException(e.getMessage());
            
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = false;
        }
    }
}