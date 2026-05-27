public without sharing class FEC_AssignmentExecuteService {
    
    public class ExecuteVisibilityResult {
        @AuraEnabled public Boolean value;
        @AuraEnabled public Boolean shouldUpdate;
    }
    
    public class ExecuteAssignmentResult {
        @AuraEnabled public Integer claimedCount;
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
        
        //thangtv: không có quyền → ẩn nút Execute Assignment
        if (!hasAccess) {
            return buildResult(caseRecord, false);
        }
        
        /*
         * 5. User còn Routing assignment chưa Completed (chưa submit xong)
         */
        //thangtv: ẩn nút khi user đã submit hết assignment liên quan (Status = Completed)
        Boolean hasPendingForUser = hasPendingRoutingAssignmentForUser(
            caseId,
        currentUserId
            );
        
        System.debug('hasPendingForUser = ' + hasPendingForUser);
        
        return buildResult(caseRecord, hasPendingForUser);
    }
    
    //thangtv: gọi lại sau Submit Assignment để cập nhật FEC_Can_Execute_Assignment__c
    @AuraEnabled
    public static ExecuteVisibilityResult refreshExecuteAssignmentVisibility(Id caseId) {
        return canExecuteAssignment(caseId);
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
    
    //thangtv: kiểm tra assignment đã Completed / đóng
    private static Boolean isClosedAssignmentStatus(String status) {
        return !String.isBlank(status) && CLOSED_STATUSES.contains(status);
    }
    
    //thangtv: user còn assignment liên quan chưa Completed thì mới hiện nút Execute
    private static Boolean hasPendingRoutingAssignmentForUser(Id caseId, Id userId) {
        List<FEC_Assignment__c> assignments = [
            SELECT Id,
                FEC_Assignment_Owner__c,
                FEC_OwnerID__c,
                FEC_Assignment_Status__c
            FROM FEC_Assignment__c
            WHERE FEC_Case__c = :caseId
        ];
        
        if (assignments.isEmpty()) {
            return false;
        }
        
        User currentUser = [
            SELECT Id, UserRoleId
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        
        Map<String, Group> queueByName = loadQueuesByOwnerReferences(assignments);
        
        for (FEC_Assignment__c assignment : assignments) {
            if (!isAssignmentRelevantToUser(assignment, userId, currentUser, queueByName)) {
                continue;
            }
            if (!isClosedAssignmentStatus(assignment.FEC_Assignment_Status__c)) {
                return true;
            }
        }
        
        return false;
    }
    
    //thangtv: load queue theo FEC_OwnerID__c để xác định assignment liên quan user
    private static Map<String, Group> loadQueuesByOwnerReferences(
        List<FEC_Assignment__c> assignments
    ) {
        Set<String> queueNames = new Set<String>();
        for (FEC_Assignment__c assignment : assignments) {
            if (String.isBlank(assignment.FEC_OwnerID__c)) {
                continue;
            }
            String ownerRef = assignment.FEC_OwnerID__c.trim();
            if (!isUserId(ownerRef)) {
                queueNames.add(ownerRef);
            }
        }
        
        Map<String, Group> queueByName = new Map<String, Group>();
        if (!queueNames.isEmpty()) {
            for (Group g : [
                SELECT Id, Name
                FROM Group
                WHERE Type = 'Queue' AND Name IN :queueNames
            ]) {
                queueByName.put(g.Name, g);
            }
        }
        return queueByName;
    }
    
    //thangtv: assignment thuộc owner user hoặc queue/user trong FEC_OwnerID__c
    private static Boolean isAssignmentRelevantToUser(
        FEC_Assignment__c assignment,
    Id userId,
    User currentUser,
    Map<String, Group> queueByName
    ) {
        if (assignment.FEC_Assignment_Owner__c == userId) {
            return true;
        }
        
        if (String.isBlank(assignment.FEC_OwnerID__c)) {
            return false;
        }
        
        String ownerRef = assignment.FEC_OwnerID__c.trim();
        
        if (isUserId(ownerRef)) {
            try {
                return (Id) ownerRef == userId;
            } catch (Exception ex) {
                return false;
            }
        }
        
        Group queueGroup = queueByName.get(ownerRef);
        if (queueGroup == null) {
            return false;
        }
        
        Set<Id> queueIds = new Set<Id>{ queueGroup.Id };
        return isUserInQueues(userId, queueIds)
            || isUserRoleInQueues(userId, queueIds);
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
        if (assignmentValues.contains(currentUser.Id)) {
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
    
    private static final QueueMembershipAccess QUEUE_MEMBERSHIP_ACCESS =
        new QueueMembershipAccess();
    
    private static Boolean isUserInQueues(Id userId, Set<Id> queueIds) {
        return QUEUE_MEMBERSHIP_ACCESS.isUserInQueues(userId, queueIds);
    }
    
    private static Boolean isUserRoleInQueues(Id userId, Set<Id> queueIds) {
        return QUEUE_MEMBERSHIP_ACCESS.isUserRoleInQueues(userId, queueIds);
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
                
                //thangtv: SYSTEM_MODE — CS user có thể không có FLS edit trên Case
                Database.update(
                    new Case(
                    Id = caseRecord.Id,
                FEC_Can_Execute_Assignment__c = canExecute
                    ),
                AccessLevel.SYSTEM_MODE
                    );
                
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
    
    private static Boolean isQueueId(String value) {
        return !String.isBlank(value)
            && value.startsWith('00G')
            && value.length() >= 15;
    }
    
    //thangtv: FEC_OwnerID__c lưu User Id
    private static Boolean isUserId(String value) {
        return !String.isBlank(value)
            && value.startsWith('005')
            && value.length() >= 15;
    }
    //----------------------------//
    
    @AuraEnabled
    public static ExecuteAssignmentResult executeAssignment(Id caseId) {
        Id userId = UserInfo.getUserId();
        ExecuteAssignmentResult executeResult = new ExecuteAssignmentResult();
        executeResult.claimedCount = 0;
        
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
    SELECT Id, Name, FEC_Case__c, FEC_Assignment_Name__c, FEC_OwnerID__c,
    FEC_Assignment_Owner__c,FEC_Assignment_Owner_Text__c,
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
            && !String.isBlank(assignment.FEC_OwnerID__c)) {
                String ownerRef = assignment.FEC_OwnerID__c.trim();
                if (queueByName.containsKey(ownerRef)) {
                    Group queueGroup = queueByName.get(ownerRef);
                    System.debug('CHECK QUEUE => ' + queueGroup.Name);
                    //thangtv: without sharing — with sharing không đọc được GroupMember role trong queue
                    matched = QUEUE_MEMBERSHIP_ACCESS.canUserClaimFromQueue(
                        userId,
                    currentUser.UserRoleId,
                    queueGroup.Id
                        );
                    if (matched) {
                        System.debug('MATCH QUEUE MEMBERSHIP');
                    }
                }
            }
            
            /*
             * TAKE OWNERSHIP
             */
            if (matched) {
                
                
                /*
                 * Skip if owner unchanged
                 */
                if (assignment.FEC_Assignment_Owner__c == userId) {
                    System.debug('SKIP SAME OWNER => ' + assignment.Id);
                    continue;
                }
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
                
                //thangtv: SYSTEM_MODE — claim owner khi user chưa có share edit trên Assignment
                Database.update(assignmentsToUpdate, AccessLevel.SYSTEM_MODE);
                FEC_AssignmentCaseShareService.shareCasesForAssignments(assignmentsToUpdate);
                
                System.debug('Assignments updated successfully');
                executeResult.claimedCount = assignmentsToUpdate.size();
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
        
        return executeResult;
    }
    
    //thangtv: truy vấn GroupMember phải without sharing (CS user không thấy role member của queue)
    private without sharing class QueueMembershipAccess {
        Boolean canUserClaimFromQueue(
            Id userId,
        Id userRoleId,
        Id queueId
        ) {
            if (userId == null || queueId == null) {
                return false;
            }
            
            if ([
                    SELECT COUNT()
                    FROM GroupMember
                    WHERE GroupId = :queueId AND UserOrGroupId = :userId
                ] > 0) {
                return true;
            }
            
            if (userRoleId == null) {
                return false;
            }
            
            return [
                    SELECT COUNT()
                    FROM GroupMember
                    WHERE GroupId = :queueId
                    AND UserOrGroupId IN (
                        SELECT Id
                        FROM Group
                        WHERE Type IN (
                            'Role',
                            'RoleAndSubordinates',
                            'RoleAndSubordinatesInternal'
                        )
                        AND RelatedId = :userRoleId
                    )
                ] > 0;
        }
        
        Boolean isUserInQueues(Id userId, Set<Id> queueIds) {
            if (userId == null || queueIds == null || queueIds.isEmpty()) {
                return false;
            }
            
            List<Group> queueGroups = [
                SELECT Id
                FROM Group
                WHERE Id IN :queueIds AND Type = 'Queue'
            ];
            
            if (queueGroups.isEmpty()) {
                return false;
            }
            
            Set<Id> validQueueIds = new Set<Id>();
            for (Group g : queueGroups) {
                validQueueIds.add(g.Id);
            }
            
            Set<Id> visitedGroupIds = new Set<Id>();
            Set<Id> groupsToProcess = new Set<Id>(validQueueIds);
            
            while (!groupsToProcess.isEmpty()) {
                Set<Id> currentBatch = new Set<Id>(groupsToProcess);
                groupsToProcess.clear();
                visitedGroupIds.addAll(currentBatch);
                
                for (GroupMember gm : [
                    SELECT GroupId, UserOrGroupId
                    FROM GroupMember
                    WHERE GroupId IN :currentBatch
                ]) {
                    Id memberId = gm.UserOrGroupId;
                    if (memberId == userId) {
                        return true;
                    }
                    if (memberId.getSObjectType() == Group.SObjectType
                        && !visitedGroupIds.contains(memberId)
                    && !groupsToProcess.contains(memberId)) {
                        groupsToProcess.add(memberId);
                    }
                }
            }
            
            return false;
        }
        
        Boolean isUserRoleInQueues(Id userId, Set<Id> queueIds) {
            if (userId == null || queueIds == null || queueIds.isEmpty()) {
                return false;
            }
            
            User userRecord = [
                SELECT Id, UserRoleId
                FROM User
                WHERE Id = :userId
                LIMIT 1
            ];
            
            if (userRecord.UserRoleId == null) {
                return false;
            }
            
            Set<Id> queueRoleIds = new Set<Id>();
            for (Group g : [
                SELECT RelatedId
                FROM Group
                WHERE Id IN (
                    SELECT UserOrGroupId
                    FROM GroupMember
                    WHERE GroupId IN :queueIds
                )
                AND Type IN ('Role', 'RoleAndSubordinates', 'RoleAndSubordinatesInternal')
            ]) {
                if (g.RelatedId != null) {
                    queueRoleIds.add(g.RelatedId);
                }
            }
            
            return queueRoleIds.contains(userRecord.UserRoleId);
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
            history.FEC_Original_User_Queue__c = assignment.FEC_Assignment_Owner_Text__c;
            
            /*
             * Updated owner email
             */
            if (updatedOwner != null) {
                history.FEC_Updated_User_Queue__c = emailLocalPart(updatedOwner.Email);
            }
            
            /*
             * Execute user
             */
            history.FEC_User__c = emailLocalPart(currentUser.Email);
            
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
            //thangtv: không chặn claim nếu user thiếu FLS trên Routing Action History
            Database.insert(histories, AccessLevel.SYSTEM_MODE);
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
        
        FEC_CaseTriggerHandler.isSystemUpdate = true;
        try {
            Database.update(
                new Case(Id = recordId, FEC_Assigment_Mode__c = viewMode),
            AccessLevel.SYSTEM_MODE
                );
            return viewMode;
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = false;
        }
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
            
            Database.update(
                new Case(Id = caseId, FEC_Can_Execute_Assignment__c = true),
            AccessLevel.SYSTEM_MODE
                );
            
            System.debug('FEC_Can_Execute_Assignment__c = true');
            
        } catch (Exception e) {
            System.debug('forceShowExecuteAssignment ERROR = ' + e.getMessage());
            
            throw new AuraHandledException(e.getMessage());
            
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = false;
        }
    }
    
    private static String emailLocalPart(String email) {
        
        if (String.isBlank(email)) {
            return null;
        }
        
        List<String> parts = email.split(FEC_ConstantCommon.EMAIL_SEPARATOR_AT);
        
        return parts.isEmpty()
            ? email.trim()
            : parts[0].trim();
    }
}

///HieuTT Update