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
        
        /*
         * Parse values
         * Example:
         * "DQ - CS Customer Care; hieu dev"
         */
        Set<String> assignmentValues =
            parseAssignmentUsers(caseRecord.FEC_Assignment_Users__c);
        
        if (assignmentValues.isEmpty()) {
            return false;
        }
        
        /*
         * Current user
         */
        User currentUser = [
    SELECT Id, Name, UserRoleId FROM User WHERE Id = : currentUserId LIMIT 1
  ];
        
        /*
         * 1. Direct user match
         */
        if (assignmentValues.contains(currentUser.Name)) {
            return true;
        }
        
        /*
         * 2. Find queues by name
         */
        List<Group> queues = [
    SELECT Id,
    Name FROM Group WHERE Name IN : assignmentValues AND Type = 'Queue'
  ];
        
        if (queues.isEmpty()) {
            return false;
        }
        
        Set<Id> queueIds = new Set<Id>();
        
        for (Group g : queues) {
            queueIds.add(g.Id);
        }
        
        /*
         * 3. Direct queue membership
         */
        if (isUserInQueues(currentUserId, queueIds)) {
            return true;
        }
        
        /*
         * 4. Queue role membership
         */
        if (isUserRoleInQueues(currentUserId, queueIds)) {
            return true;
        }
        
        return false;
    }
    
    private static Set<String> parseAssignmentUsers(String assignmentUsers) {
        Set<String> values = new Set<String>();
        
        if (String.isBlank(assignmentUsers)) {
            return values;
        }
        
        // tungnm37 fix: split bằng ',' - delimiter chuẩn
        for (String value : assignmentUsers.split(',')) {
            if (!String.isBlank(value)) {
                values.add(value.trim());
            }
        }
        
        return values;
    }
    
    private static Boolean isUserInQueues(Id userId, Set<Id> queueIds) {
        if (userId == null || queueIds == null || queueIds.isEmpty()) {
            return false;
        }
        
        /*
         * Validate queue ids
         */
        List<Group> queueGroups =
            [SELECT Id FROM Group WHERE Id IN : queueIds AND Type = 'Queue'];
        
        if (queueGroups.isEmpty()) {
            return false;
        }
        
        Set<Id> validQueueIds = new Set<Id>();
        
        for (Group g : queueGroups) {
            validQueueIds.add(g.Id);
        }
        
        /*
         * Recursive traversal
         */
        Set<Id> visitedGroupIds = new Set<Id>();
        
        Set<Id> groupsToProcess = new Set<Id>(validQueueIds);
        
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
                 * Nested groups
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
    
    private static Boolean isUserRoleInQueues(Id userId, Set<Id> queueIds) {
        if (userId == null || queueIds == null || queueIds.isEmpty()) {
            return false;
        }
        
        /*
         * Current user role
         */
        User userRecord =
            [SELECT Id, UserRoleId FROM User WHERE Id = : userId LIMIT 1];
        
        if (userRecord.UserRoleId == null) {
            return false;
        }
        
        /*
         * Queue role groups
         */
        List<Group> queueRoleGroups = [
    SELECT Id, Type,
    RelatedId FROM Group WHERE Id IN(
        SELECT UserOrGroupId FROM GroupMember WHERE GroupId IN
        : queueIds) AND Type IN('Role', 'RoleAndSubordinates')
  ];
        
        if (queueRoleGroups.isEmpty()) {
            return false;
        }
        
        /*
         * Role ids from queues
         */
        Set<Id> queueRoleIds = new Set<Id>();
        
        for (Group g : queueRoleGroups) {
            if (g.RelatedId != null) {
                queueRoleIds.add(g.RelatedId);
            }
        }
        
        return queueRoleIds.contains(userRecord.UserRoleId);
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
                createRoutingActionHistory(
                    assignmentsToUpdate,
                userId,
                caseId
                    );
                
            } catch (Exception e) {
                System.debug('executeAssignment ERROR = ' + e.getMessage());
                
                throw e;
                
            } finally {
                FEC_CaseTriggerHandler.isSystemUpdate = false;
            }
        }
    }
    
    private static void createRoutingActionHistory(
    List<FEC_Assignment__c> assignments, Id currentUserId, Id caseId) {
        if (assignments == null || assignments.isEmpty() || currentUserId == null
        || caseId == null) {
            return;
        }
        
        /*
         * Current user
         */
        User currentUser = [
    SELECT Id, Email, UserRole.Name FROM User WHERE Id = : currentUserId LIMIT 1
  ];
        
        /*
         * Case info
         */
        Case caseRecord = [
    SELECT Id,
    FEC_Current_Case_Stage__r.FEC_Code__c FROM Case WHERE Id = : caseId LIMIT 1
  ];
        
        /*
         * Collect updated owner ids
         */
        Set<Id> updatedOwnerIds = new Set<Id>();
        
        for (FEC_Assignment__c assignment : assignments) {
            if (assignment.FEC_Assignment_Owner__c != null) {
                updatedOwnerIds.add(assignment.FEC_Assignment_Owner__c);
            }
        }
        
        /*
         * Query updated owners
         */
        Map<Id, User> userById = new Map<Id, User>();
        
        if (!updatedOwnerIds.isEmpty()) {
            userById = new Map<Id, User>(
                [SELECT Id, Email FROM User WHERE Id IN : updatedOwnerIds]);
        }
        
        /*
         * Create histories
         */
        List<FEC_Routing_Action_History__c> histories =
            new List<FEC_Routing_Action_History__c>();
        
        for (FEC_Assignment__c assignment : assignments) {
            User updatedOwner = userById.get(assignment.FEC_Assignment_Owner__c);
            
            FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c();
            
            history.FEC_Routing_Action__c = 'Change Owner';
            
            history.FEC_Routing_Action_Type__c = 'Assignment';
            
            /*
             * Original queue/user owner
             */
            history.FEC_Original_User_Queue__c = assignment.FEC_OwnerID__c;
            
            /*
             * Updated owner email
             */
            if (updatedOwner != null) {
                history.FEC_Updated_User_Queue__c = updatedOwner.Email;
            }
            
            /*
             * Execute user
             */
            history.FEC_User__c = currentUser.Email;
            
            /*
             * Execute user role
             */
            if (currentUser.UserRole != null) {
                history.FEC_User_Role__c = currentUser.UserRole.Name;
            }
            
            /*
             * Stage code
             */
            if (caseRecord.FEC_Current_Case_Stage__r != null) {
                history.FEC_Stage_Name__c =
                    caseRecord.FEC_Current_Case_Stage__r.FEC_Code__c;
            }
            
            /*
             * Assignment
             */
            history.FEC_Assignment__c = assignment.Id;
            
            /*
             * Case
             */
            history.FEC_Case__c = caseId;
            
            histories.add(history);
        }
        
        if (!histories.isEmpty()) {
            insert histories;
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

///HieuTT Update