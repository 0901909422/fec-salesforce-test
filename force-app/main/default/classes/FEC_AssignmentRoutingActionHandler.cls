public without sharing class FEC_AssignmentRoutingActionHandler {
    
    @AuraEnabled
    public static void execute(
        Id caseId,
    Id assignmentId,
    String action,
    String remark,
    String decision,
    String subDecision
    ) {
        try {
            // claimAssignmentIfQueueOwner(caseId, assignmentId);
            
            if (action == FEC_ConstantCommon.ACTION_ESCALATE) {
                handleEscalate(caseId, assignmentId, remark);
                
            } else if (action == FEC_ConstantCommon.ACTION_REJECT) {
                handleReject(caseId, assignmentId, remark);
                
            } else if (action == FEC_ConstantCommon.ACTION_RESOLVE) {
                handleResolve(caseId, assignmentId, remark);
                
            } else if (action == FEC_ConstantCommon.ACTION_REVERT) {
                handleRevert(caseId, assignmentId, remark, decision);
                
            } else if (action == FEC_ConstantCommon.ACTION_TRANSFER) {
                handleTransfer(caseId, assignmentId, remark, decision, subDecision);
                
            } else if (action == FEC_ConstantCommon.ACTION_ROUTE_TO) {
                handleRouteTo(caseId, assignmentId, remark, subDecision);
                
            } else if (action == FEC_ConstantCommon.ACTION_UPDATE) {
                handleUpdate(caseId, assignmentId, remark, decision);
                
            } else {
                throw new AuraHandledException(System.Label.FEC_ERR_INVALID_INPUT);
            }
            
        } catch (Exception e) {
            
            System.debug(LoggingLevel.ERROR, 'EXECUTE ERROR: ' + e);
            
            // giữ nguyên message business
            String msg = e.getMessage();
            if (String.isBlank(msg)) {
                msg = System.Label.FEC_MSG_Exception;
            }
            
            throw new AuraHandledException(msg);
        }
    }
    private class BusinessException extends Exception {}
    
    private static void handleEscalate(Id caseId, Id assignmentId, String remark) {
        
        List<FEC_Assignment__c> lst = [
        SELECT Id,
               FEC_Assignment_Owner__c,
               FEC_Assignment_Owner__r.ManagerId,
               FEC_OwnerID__c
        FROM FEC_Assignment__c
        WHERE Id = :assignmentId
        LIMIT 1
    ];
        
        if (lst.isEmpty()) {
            throw new BusinessException(System.Label.FEC_ERR_ASSIGNMENT_NOT_FOUND);
        }
        
        FEC_Assignment__c a = lst[0];
        
        if (a.FEC_Assignment_Owner__c == null) {
            throw new BusinessException(System.Label.FEC_ERR_ESCALATE_NO_OWNER);
        }
        
        if (a.FEC_Assignment_Owner__r.ManagerId == null) {
            throw new BusinessException(System.Label.FEC_ERR_ESCALATE_NO_MANAGER);
        }
        
        Id managerId = a.FEC_Assignment_Owner__r.ManagerId;
        
        a.FEC_Assignment_Owner__c = managerId;
        a.FEC_OwnerID__c = managerId;
        
        a.FEC_Assignment_Status__c = FEC_ConstantCommon.STATUS_CS_REVIEW;
        
        update a;
        syncAssignmentUsersToCase(caseId, assignmentId);
        
        insertHistoryEscalate(caseId, assignmentId, FEC_ConstantCommon.ACTION_ESCALATE, remark );
    }
    
    
    private static void handleReject(
        Id caseId,
    Id assignmentId,
    String remark
    ) {
        
        // ===== UPDATE ASSIGNMENT =====
        //Chưa có trường FEC_Assignment_Owner__c(formular)
        FEC_Assignment__c assignmentToUpdate = new FEC_Assignment__c(
            Id = assignmentId,
        FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_COMPLETED,
        FEC_OwnerID__c = null // unassigned
            );
        
        update assignmentToUpdate;
        syncAssignmentUsersToCase(caseId, assignmentId);
        // ===== INSERT HISTORY =====
        insertHistory(caseId, assignmentId, FEC_ConstantCommon.ACTION_REJECT, remark);
    }
    
    private static void handleResolve(
        Id caseId,
    Id assignmentId,
    String remark
    ) {
        
        // ===== UPDATE ASSIGNMENT =====
        // tungnm37: clear cả FEC_OwnerID__c để syncAssignmentUsersToCase không đọc nhầm User cũ
        update new FEC_Assignment__c(
            Id = assignmentId,
        FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_COMPLETED,
        FEC_Assignment_Owner__c = null,
        FEC_OwnerID__c = null
            );
        
        // tungnm37: sync lại Case.FEC_Assignment_Users__c → clear về null sau khi resolve
        syncAssignmentUsersToCase(caseId, assignmentId);
        
        // ===== HISTORY =====
        insertHistory(caseId, assignmentId, FEC_ConstantCommon.ACTION_RESOLVE, remark);
    }
    
    
    private static void handleRevert(
        Id caseId,
    Id assignmentId,
    String remark,
    String decision
    ) {
        
        if (caseId == null || assignmentId == null) {
            throw new AuraHandledException(System.Label.FEC_ERR_INVALID_INPUT);
        }
        
        if (String.isBlank(decision)) {
            throw new AuraHandledException(System.Label.FEC_ERR_DECISION_REQUIRED);
        }
        
        Case c = [
        SELECT CreatedById
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
    ];
        
        FEC_Assignment__c assignment = new FEC_Assignment__c(
            Id = assignmentId,
        FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_REVERTING_CREATOR
            );
        
        if (decision == FEC_ConstantCommon.DECISION_USER) {
            
            assignment.FEC_Assignment_Owner__c = c.CreatedById;
            assignment.FEC_OwnerID__c = c.CreatedById;
            
        } else if (decision == FEC_ConstantCommon.DECISION_USER_TEAM_QUEUE) {
            
            QueueResult queueResult = getMainQueueId(c.CreatedById);
            
            if (queueResult == null) {
                throw new AuraHandledException(System.Label.FEC_ERR_QUEUE_NOT_FOUND);
            }
            
            assignment.FEC_Assignment_Owner__c =  null;
            assignment.FEC_OwnerID__c = queueResult.queueName;
            
        } else {
            throw new AuraHandledException(System.Label.FEC_ERR_INVALID_INPUT);
        }
        
        update assignment;
        syncAssignmentUsersToCase(caseId, assignmentId);
        
        insertHistoryRevert(caseId, assignmentId, FEC_ConstantCommon.ACTION_REVERT, remark,decision);
    }
    
    
    private static void handleRouteTo(
        Id caseId,
    Id assignmentId,
    String remark,
    String subDecision
    ) {
        
        // ===== GET CASE =====
        List<Case> cases = [
            SELECT Id,
                RecordType.DeveloperName,
                FEC_Stage_Name__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        
        Case caseRecord = cases.isEmpty() ? null : cases[0];
        
        List<FEC_Assignment__c> assignmentsList = [
           SELECT Id, FEC_OwnerID__c,  FEC_Assignment_Status__c, FEC_Case__r.FEC_Current_Case_Stage__r.FEC_Code__c FROM FEC_Assignment__c WHERE  Id = :assignmentId 
        ];
        
        FEC_Assignment__c assignment = assignmentsList.isEmpty() ? null : assignmentsList[0];
        
        String queueId = subDecision;
        List<Group> groups = [
            SELECT Id, Name
            FROM
            GROUP
            WHERE Id = :queueId
            AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
        ];
        
        Group queue = groups.isEmpty() ? null : groups[0];
        
        Id userId = UserInfo.getUserId();
        String userDepart;
        
        
        if (isCSSupport()) {
            userDepart = FEC_ConstantCommon.TEAM_CS_SUPPORT;
            
        } else if (isCSCustomerCare()) {
            userDepart = FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE;
            
        } else if (isOtherCS(userId)){
            userDepart = FEC_ConstantCommon.TEAM_CS_OTHER;
        }
        else {
            userDepart = FEC_ConstantCommon.TEAM_OTHER;
        }
        
        System.debug('=== User department: ' + userDepart);
        
        /*
         * OTHER DEPT
         */
        if (userDepart == FEC_ConstantCommon.TEAM_OTHER) {
            if (assignment != null
            && String.isNotBlank(assignment.FEC_Case__r.FEC_Current_Case_Stage__r.FEC_Code__c)) {
                /*
                 * GSR
                 * Route về CS Support
                 */
                if (assignment.FEC_Case__r.FEC_Current_Case_Stage__r.FEC_Code__c.contains(
                FEC_ConstantCommon.BP_GSR)) {
                    assignment.FEC_OwnerID__c = queue.Name;
                    assignment.FEC_Assignment_Status__c = FEC_ConstantCommon.STATUS_CS_BACKOFFICE;
                }
                
                /*
                 * COF
                 * Route về CS Customer Care
                 */
                else if (assignment.FEC_Case__r.FEC_Current_Case_Stage__r.FEC_Code__c.contains(
                FEC_ConstantCommon.BP_COF)) {
                    assignment.FEC_OwnerID__c = queue.Name;
                    assignment.FEC_Assignment_Status__c = FEC_ConstantCommon.STATUS_CS_BACKOFFICE;
                }
            }
        }
        
        /*
         * CS Support / CS Customer Care
         */
        else if (userDepart == FEC_ConstantCommon.TEAM_CS_SUPPORT || userDepart == FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE) {
            System.debug('Test routing CS');
            assignment.FEC_OwnerID__c = queue.Name;
            assignment.FEC_Assignment_Status__c = FEC_ConstantCommon.STATUS_CS_REVIEW;
        }else if(userDepart == FEC_ConstantCommon.TEAM_CS_OTHER){
            assignment.FEC_OwnerID__c = queue.Name;
            assignment.FEC_Assignment_Status__c = FEC_ConstantCommon.STATUS_CS_BACKOFFICE;
        }
        
        
        assignment.FEC_Assignment_Owner__c = null;
        update assignment;
        syncAssignmentUsersToCase(caseRecord.Id, assignmentId);
        insertHistoryRouteTo(caseRecord.Id, assignmentId, FEC_ConstantCommon.ACTION_ROUTE_TO_DISPLAY, remark);
        
        
    }
    
    private static void handleTransfer(
        Id caseId,
    Id assignmentId,
    String remark,
    String decision,
    String subDecision
    ) {
        if (String.isBlank(decision)) {
            throw new AuraHandledException(System.Label.FEC_ERR_DECISION_REQUIRED);
        }
        
        if (String.isBlank(subDecision)) {
            throw new AuraHandledException(System.Label.FEC_ERR_INVALID_INPUT);
        }
        
        FEC_Assignment__c assignment = new FEC_Assignment__c(
            Id = assignmentId
            );
        
        Id userId = UserInfo.getUserId();
        String userDepart;
        
        
        if (isCSSupport()) {
            userDepart = FEC_ConstantCommon.TEAM_CS_SUPPORT;
            
        } else if (isCSCustomerCare()) {
            userDepart = FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE;
            
        } else if (isOtherCS(userId)){
            userDepart = FEC_ConstantCommon.TEAM_CS_OTHER;
        }
        else {
            userDepart = FEC_ConstantCommon.TEAM_OTHER;
        }
        
        System.debug('=== User department: ' + userDepart);
        
        // ===== USER =====
        if (decision ==  FEC_ConstantCommon.DECISION_USER) {
            assignment.FEC_Assignment_Owner__c = subDecision;
            assignment.FEC_OwnerID__c = subDecision;
            // ===== QUEUE =====
        } else if (decision ==  FEC_ConstantCommon.DECISION_QUEUE ) {
            assignment.FEC_Assignment_Owner__c = null;
            String queueName = getQueueNameById(subDecision);
            System.debug('queueName: ');
            System.debug(queueName);
            assignment.FEC_OwnerID__c = queueName;
        } else {
            throw new AuraHandledException(System.Label.FEC_ERR_INVALID_INPUT);
        }
        
        update assignment;
        syncAssignmentUsersToCase(caseId, assignmentId);
        
        insertHistoryTransfer(caseId, assignmentId, FEC_ConstantCommon.ACTION_TRANSFER, remark, decision);
    }
    
    
    private static void handleUpdate(
        Id caseId,
    Id assignmentId,
    String remark,
    String decision
    ) {
        if (String.isBlank(decision)) {
            throw new AuraHandledException(System.Label.FEC_ERR_DECISION_REQUIRED);
        }
        
        Id currentUserId = UserInfo.getUserId();
        
        // ===== ASSIGNMENT =====
        FEC_Assignment__c assignment = new FEC_Assignment__c(
            Id = assignmentId
            );
        
        // ===== CASE =====
        Case caseUpdate = new Case(Id = caseId);
        
        // ===== LOGIC =====
        
        // 1. Cannot Contact Customer → COMPLETE
        if (decision == FEC_ConstantCommon.DECISION_CANNOT_CONTACT) {
            assignment.FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_COMPLETED;
        }
        // 2. Queue routing
        else if (isQueueDecision(decision)) {
            
            Id queueId = getQueueForUpdateDecision(decision);
            
            if (queueId == null) {
                throw new AuraHandledException(System.Label.FEC_ERR_QUEUE_NOT_FOUND);
            }
            
            assignment.FEC_Assignment_Owner__c = null;
            assignment.FEC_OwnerID__c = queueId;
        }
        // 3. User routing (default)
        else {
            assignment.FEC_Assignment_Owner__c = currentUserId;
            assignment.FEC_OwnerID__c = currentUserId;
        }
        
        // ===== CASE STATUS =====
        String status = FEC_ConstantCommon.CASE_STATUS_MAP.get(decision);
        if (status != null) {
            caseUpdate.Status = status;
        }
        
        // assignment.FEC_Assignment_Status__c = FEC_ConstantCommon.STATUS_CS_BACKOFFICE;
        update assignment;
        syncAssignmentUsersToCase(caseId, assignmentId);
        update caseUpdate;
        
        insertHistoryForUpdate(
            caseId,
        assignmentId,
        FEC_ConstantCommon.ACTION_UPDATE,
        remark,
        decision
            );
    }
    //----------------------------------------------
    private static void insertHistory(
        Id caseId,
    Id assignmentId,
    String action,
    String remark
    ) {
        
        System.debug(caseId);
        System.debug(assignmentId);
        System.debug(action);
        System.debug(remark);
        
        // ===== GET DATA =====
        User u = [
            SELECT Id, Email, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        
        FEC_Assignment__c ass = [
            SELECT Id, FEC_Assignment_Owner__c, FEC_Assignment_Owner_Text__c
            FROM FEC_Assignment__c
            WHERE Id = :assignmentId
        ];
        
        Case c = [
            SELECT FEC_Current_Case_Stage__r.FEC_Code__c
            FROM Case
            WHERE Id = :caseId
        ];
        // ===== BUILD RECORDS =====
        List<SObject> records = new List<SObject>();
        
        // --- Routing History ---
        records.add(new FEC_Routing_Action_History__c(
            FEC_Routing_Action_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
        FEC_Case__c = caseId,
        FEC_Assignment__c = assignmentId,
        FEC_Routing_Action__c = action,
        
        FEC_Original_User_Queue__c = emailLocalPart(u.Email),
        FEC_Original_User_Queue_ID__c = u.Id,
        FEC_Updated_User_Queue__c = ass.FEC_Assignment_Owner_Text__c,
        FEC_Updated_User_Queue_ID__c =  ass.FEC_Assignment_Owner__c,
        
        FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,
        
        FEC_User__c = emailLocalPart(u.Email),
        FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null
            ));
        
        // --- Case Remark ---
        records.add(new FEC_Case_Remarks__c(
            FEC_Remark_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
        FEC_Case_Remarks__c = remark,
        FEC_Case__c = caseId,
        FEC_Assignment__c = assignmentId,
        FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,
        FEC_User__c = emailLocalPart(u.Email),
        FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null
            ));
        
        insert records;
    }
    
    private static void insertHistoryRouteTo(
        Id caseId,
    Id assignmentId,
    String action,
    String remark
    ) {
        
        System.debug(caseId);
        System.debug(assignmentId);
        System.debug(action);
        System.debug(remark);
        
        // ===== GET DATA =====
        User u = [
        SELECT Id, Email, UserRole.Name
        FROM User
        WHERE Id = :UserInfo.getUserId()
    ];
        
        FEC_Assignment__c ass = [
        SELECT Id, FEC_Assignment_Owner_Text__c ,FEC_OwnerID__c 
        FROM FEC_Assignment__c
        WHERE Id = :assignmentId
    ];
        
        
        
        Case c = [
        SELECT FEC_Current_Case_Stage__r.FEC_Code__c
        FROM Case
        WHERE Id = :caseId
        ];
        
        // ===== BUILD RECORDS =====
        List<SObject> records = new List<SObject>();
        
        // --- Routing History ---
        records.add(new FEC_Routing_Action_History__c(
            FEC_Routing_Action_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
        FEC_Case__c = caseId,
        FEC_Assignment__c = assignmentId,
        FEC_Routing_Action__c = action,
        
        FEC_Original_User_Queue__c = emailLocalPart(u.Email),
        FEC_Original_User_Queue_ID__c = emailLocalPart(u.Email),
        FEC_Updated_User_Queue__c = ass.FEC_Assignment_Owner_Text__c,
        FEC_Updated_User_Queue_ID__c =  ass.FEC_Assignment_Owner_Text__c,
        
        FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,
        
        FEC_User__c = emailLocalPart(u.Email),
        FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null
            ));
        
        // --- Case Remark ---
        records.add(new FEC_Case_Remarks__c(
            FEC_Remark_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
        FEC_Case_Remarks__c = remark,
        FEC_Case__c = caseId,
        FEC_Assignment__c = assignmentId,
        FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,
        FEC_User__c = emailLocalPart(u.Email),
        FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null
            ));
        
        insert records;
    }
    
    private static void insertHistoryForUpdate(
        Id caseId,
    Id assignmentId,
    String action,
    String remark,
    String decision
    ) {
        
        System.debug(caseId);
        System.debug(assignmentId);
        System.debug(action);
        System.debug(remark);
        
        // ===== GET DATA =====
        User u = [
        SELECT Id, Email, UserRole.Name
        FROM User
        WHERE Id = :UserInfo.getUserId()
    ];
        
        FEC_Assignment__c ass = [
        SELECT Id, FEC_Assignment_Owner__c
        FROM FEC_Assignment__c
        WHERE Id = :assignmentId
    ];
        
        Case c = [
        SELECT FEC_Current_Case_Stage__r.FEC_Code__c
        FROM Case
        WHERE Id = :caseId
    ];
        
        
        /*
         * Resolve owner value
         */
        String ownerValue =
            String.valueOf(
            ass.FEC_Assignment_Owner__c
            );
        
        String ownerIdValue =
            String.valueOf(
            ass.FEC_Assignment_Owner__c
            );
        
        String ownerStr =
            String.valueOf(
            ass.FEC_Assignment_Owner__c
            );
        /*
        
        /*
         * Only query when value is User Id
         */
        if (String.isNotBlank(ass.FEC_Assignment_Owner__c)
        && ownerStr.startsWith(FEC_ConstantCommon.USER_ID_START)) {
            User ownerUser = [
                SELECT Id, Name, Email FROM User WHERE Id = : ass.FEC_Assignment_Owner__c LIMIT 1
            ];
            
            ownerValue = emailLocalPart(ownerUser.Email);
            
            ownerIdValue = ownerUser.Id;
        }
        
        // ===== BUILD RECORDS =====
        List<SObject> records = new List<SObject>();
        
        // --- Routing History ---
        records.add(new FEC_Routing_Action_History__c(
            FEC_Routing_Action_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
        FEC_Case__c = caseId,
        FEC_Assignment__c = assignmentId,
        FEC_Routing_Action__c = action,
        
        FEC_Original_User_Queue__c = ownerValue,
        FEC_Original_User_Queue_ID__c = ownerValue,
        FEC_Updated_User_Queue__c = ownerValue,
        FEC_Updated_User_Queue_ID__c = ownerValue,
        
        FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,
        
        FEC_User__c = emailLocalPart(u.Email),
        FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null,
        FEC_Decision__c  = decision
            ));
        
        // --- Case Remark ---
        records.add(new FEC_Case_Remarks__c(
            FEC_Remark_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
        FEC_Case_Remarks__c = remark,
        FEC_Case__c = caseId,
        FEC_Assignment__c = assignmentId,
        FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,
        FEC_User__c = emailLocalPart(u.Email),
        FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null
            ));
        
        insert records;
    }
    
    
    private static void insertHistoryEscalate(
        Id caseId,
    Id assignmentId,
    String action,
    String remark
    ) {
        
        System.debug(caseId);
        System.debug(assignmentId);
        System.debug(action);
        System.debug(remark);
        // ===== GET DATA =====
        User u = [
            SELECT Id, Email, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        
        FEC_Assignment__c ass = [
            SELECT Id, FEC_Assignment_Owner__c, FEC_Assignment_Owner_Text__c
            FROM FEC_Assignment__c
            WHERE Id = :assignmentId
        ];
        Case c = [
            SELECT FEC_Current_Case_Stage__r.FEC_Code__c
            FROM Case
            WHERE Id = :caseId
        ];
        // ===== BUILD RECORDS =====
        List<SObject> records = new List<SObject>();
        
        // --- Routing History ---
        records.add(new FEC_Routing_Action_History__c(
            FEC_Routing_Action_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
        FEC_Case__c = caseId,
        FEC_Assignment__c = assignmentId,
        FEC_Routing_Action__c = action,
        FEC_Original_User_Queue__c = emailLocalPart(u.Email),
        FEC_Original_User_Queue_ID__c = u.Id,
        FEC_Updated_User_Queue__c = ass.FEC_Assignment_Owner_Text__c,
        FEC_Updated_User_Queue_ID__c =  ass.FEC_Assignment_Owner__c,
        
        FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,
        
        FEC_User__c = emailLocalPart(u.Email),
        FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null
            ));
        
        // --- Case Remark ---
        records.add(new FEC_Case_Remarks__c(
            FEC_Remark_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
        FEC_Case_Remarks__c = remark,
        FEC_Case__c = caseId,
        FEC_Assignment__c = assignmentId,
        FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,
        FEC_User__c = emailLocalPart(u.Email),
        FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null
            ));
        
        insert records;
    }
    
    
    private static void insertHistoryTransfer(
        Id caseId,
    Id assignmentId,
    String action,
    String remark,
    String decision
    ) {
        
        System.debug(caseId);
        System.debug(assignmentId);
        System.debug(action);
        System.debug(remark);
        System.debug(decision);
        
        // ===== GET DATA =====
        User u = [
            SELECT Id, Email, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        
        FEC_Assignment__c ass = [
            SELECT Id, FEC_Assignment_Owner__c,FEC_Assignment_Owner_Text__c, FEC_OwnerID__c
            FROM FEC_Assignment__c
            WHERE Id = :assignmentId
        ];
        
        Case c = [
            SELECT FEC_Current_Case_Stage__r.FEC_Code__c
            FROM Case
            WHERE Id = :caseId
        ];
        
        String updatedUserQueueId = '';
        String updatedUserQueue = '';
        if (decision ==  FEC_ConstantCommon.DECISION_USER) {
            updatedUserQueueId = ass.FEC_Assignment_Owner__c;
            updatedUserQueue = ass.FEC_Assignment_Owner_Text__c ;
            // ===== QUEUE =====
        } else if (decision ==  FEC_ConstantCommon.DECISION_QUEUE ) {
            updatedUserQueueId = ass.FEC_OwnerID__c;
            updatedUserQueue = ass.FEC_Assignment_Owner_Text__c ;
        }
        // ===== BUILD RECORDS =====
        List<SObject> records = new List<SObject>();
        
        // --- Routing History ---
        records.add(new FEC_Routing_Action_History__c(
            FEC_Routing_Action_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
        FEC_Case__c = caseId,
        FEC_Assignment__c = assignmentId,
        FEC_Routing_Action__c = action,
        
        FEC_Original_User_Queue__c = emailLocalPart(u.Email),
        FEC_Original_User_Queue_ID__c = u.Id,
        FEC_Updated_User_Queue__c = updatedUserQueue,
        FEC_Updated_User_Queue_ID__c = updatedUserQueueId,
        
        FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,
        
        FEC_User__c = emailLocalPart(u.Email),
        FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null
            ));
        
        // --- Case Remark ---
        records.add(new FEC_Case_Remarks__c(
            FEC_Remark_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
        FEC_Case_Remarks__c = remark,
        FEC_Case__c = caseId,
        FEC_Assignment__c = assignmentId,
        FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,
        FEC_User__c = emailLocalPart(u.Email),
        FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null
            ));
        
        insert records;
    }
    
    
    private static void insertHistoryRevert(
        Id caseId,
    Id assignmentId,
    String action,
    String remark,
    String decision
    ) {
        
        System.debug(caseId);
        System.debug(assignmentId);
        System.debug(action);
        System.debug(remark);
        
        // ===== GET DATA =====
        User u = [
            SELECT Id, Email, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        
        FEC_Assignment__c ass = [
            SELECT Id, FEC_Assignment_Owner__c,FEC_Assignment_Owner_Text__c, FEC_OwnerID__c
            FROM FEC_Assignment__c
            WHERE Id = :assignmentId
        ];
        
        Case c = [
            SELECT FEC_Current_Case_Stage__r.FEC_Code__c
            FROM Case
            WHERE Id = :caseId
        ];
        
        String updatedUserQueueId = '';
        String updatedUserQueue = '';
        if (decision ==  FEC_ConstantCommon.DECISION_USER) {
            updatedUserQueueId = ass.FEC_Assignment_Owner__c;
            updatedUserQueue = ass.FEC_Assignment_Owner_Text__c ;
            // ===== QUEUE =====
        } else if (decision ==  FEC_ConstantCommon.DECISION_QUEUE ) {
            updatedUserQueueId = ass.FEC_OwnerID__c;
            updatedUserQueue = ass.FEC_Assignment_Owner_Text__c ;
        }
        // ===== BUILD RECORDS =====
        List<SObject> records = new List<SObject>();
        
        // --- Routing History ---
        records.add(new FEC_Routing_Action_History__c(
            FEC_Routing_Action_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
        FEC_Case__c = caseId,
        FEC_Assignment__c = assignmentId,
        FEC_Routing_Action__c = action,
        
        FEC_Original_User_Queue__c =  emailLocalPart(u.Email),
        FEC_Original_User_Queue_ID__c =  emailLocalPart(u.Email),
        FEC_Updated_User_Queue__c = updatedUserQueue,
        FEC_Updated_User_Queue_ID__c =  updatedUserQueueId,
        
        FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,
        
        FEC_User__c = emailLocalPart(u.Email),
        FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null
            ));
        
        // --- Case Remark ---
        records.add(new FEC_Case_Remarks__c(
            FEC_Remark_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
        FEC_Case_Remarks__c = remark,
        FEC_Case__c = caseId,
        FEC_Assignment__c = assignmentId,
        FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,
        FEC_User__c = emailLocalPart(u.Email),
        FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null
            ));
        
        insert records;
    }
    
    public class QueueResult {
        @AuraEnabled public String queueId;
        @AuraEnabled public String queueName;
        
        public QueueResult(String queueId, String queueName) {
            this.queueId = queueId;
            this.queueName = queueName;
        }
    }
    
    private static QueueResult getMainQueueId(Id userId) {
        List<User> u = [
        SELECT FEC_Main_Queue__c 
        FROM User
        WHERE Id = :userId
    ];
        if (u.isEmpty() || String.isBlank(u[0].FEC_Main_Queue__c)) {
            return null;
        }
        
        String queueName = u[0].FEC_Main_Queue__c;
        
        List<Group> queue = [
            SELECT Id, Name
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND DeveloperName = :queueName
            LIMIT 1
        ];
        
        return !queue.isEmpty()
            ? new QueueResult(
            queue[0].Id,
        queue[0].Name
            )
            : null;
    }
    
    
    private static String getQueueNameById(Id queueId) {
        
        if (queueId == null) {
            return null;
        }
        
        List<Group> queues = [
        SELECT Name
        FROM Group
        WHERE Id = :queueId
        AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
        LIMIT 1
    ];
        
        return queues.isEmpty()
            ? null
            : queues[0].Name;
    }
    
    private static Id getQueueIdByName(String queueName) {
        List<Group> g = [
        SELECT Id
        FROM Group
        WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
        AND Name = :queueName
        LIMIT 1
    ];
        return g != null && !g.isEmpty() ? g.get(0).Id : null;
    }
    
    
    private static Id getQueueIdByTeam(String team) {
        String queueName = FEC_ConstantCommon.TEAM_QUEUE_MAP.get(team);
        return queueName != null ? getQueueIdByName(queueName) : null;
    }
    
    
    private static Id getLastUserOfTeam(Id caseId, String team) {
        List<FEC_Routing_Action_History__c> histories = [
        SELECT FEC_User__c
        FROM FEC_Routing_Action_History__c
        WHERE FEC_Case__c = :caseId
        AND FEC_Routing_Action__c = :FEC_ConstantCommon.ACTION_ROUTE_TO_DISPLAY
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];
        
        return histories.isEmpty() ? null : histories[0].FEC_User__c;
    }
    
    
    private static String getRouteToStatus(String team) {
        if (team == FEC_ConstantCommon.TEAM_CS_SUPPORT ||
        team == FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE) {
            return FEC_ConstantCommon.STATUS_CS_BACKOFFICE;
        }
        return FEC_ConstantCommon.STATUS_OTHER_DEPT;
    }
    
    
    public class SelectOptionWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public SelectOptionWrapper(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }
    @AuraEnabled
    public static List<SelectOptionWrapper> getTeams(){
        return new List<SelectOptionWrapper>{
            new SelectOptionWrapper(
                FEC_ConstantCommon.TEAM_CS_SUPPORT,
            FEC_ConstantCommon.TEAM_CS_SUPPORT
                ),
            new SelectOptionWrapper(
                FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE,
            FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE
                )
        };
    }
    
    
    @AuraEnabled
    public static List<SelectOptionWrapper> getQueuesByTeam(String team){
        if (String.isBlank(team)) {
            throw new AuraHandledException(System.Label.FEC_ERR_TEAM_REQUIRED);
        }
        
        String queueName = FEC_ConstantCommon.TEAM_QUEUE_MAP.get(team);
        if (queueName == null) {
            return new List<SelectOptionWrapper>();
        }
        
        Group q = [
        SELECT Id, Name
        FROM Group
        WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
        AND Name = :queueName
        LIMIT 1
    ];
        
        if (q == null) {
            throw new AuraHandledException(System.Label.FEC_ERR_QUEUE_NOT_FOUND);
        }
        
        return new List<SelectOptionWrapper>{
            new SelectOptionWrapper(q.Id, q.Name)
        };
    }
    
    private static final Set<String> QUEUE_DECISIONS = new Set<String>{
        FEC_ConstantCommon.DECISION_OUT_OF_PROCESS,
        FEC_ConstantCommon.DECISION_CIC_RELATED,
        FEC_ConstantCommon.DECISION_DOCUMENT_PREP,
        FEC_ConstantCommon.DECISION_TASK_UNDER_REVIEW
    };
    
    private static Boolean isQueueDecision(String decision) {
        return QUEUE_DECISIONS.contains(decision);
    }
    
    private static Id getQueueForUpdateDecision(String decision) {
        String queueName = FEC_ConstantCommon.DECISION_QUEUE_MAP.get(decision);
        return queueName != null ? getQueueIdByName(queueName) : null;
    }
    
    /**
     * tungnm37: Đồng bộ Case.FEC_Assignment_Users__c theo rule:
     * - Nếu FEC_Assignment_Owner__c != null → lưu User ID
     * - Nếu FEC_Assignment_Owner__c == null → lưu Queue Name từ FEC_OwnerID__c
     */
    //tungnm37: Re-query TAT CA assignments con active cua Case de rebuild FEC_Assignment_Users__c chinh xac
    //tungnm37: Tranh truong hop resolve 1 assignment nhung clear het ca field
    private static void syncAssignmentUsersToCase(Id caseId, Id assignmentId) {
        try {
            List<FEC_Assignment__c> activeAssignments = [
                SELECT Id, FEC_Assignment_Owner__c, FEC_OwnerID__c
                FROM FEC_Assignment__c
                WHERE FEC_Case__c = :caseId
                  AND FEC_Assignment_Status__c NOT IN :FEC_ConstantCommon.CLOSED_ASSIGNMENT_STATUSES
            ];
            
            List<String> userValues = new List<String>();
            for (FEC_Assignment__c a : activeAssignments) {
                String userValue;
                if (a.FEC_Assignment_Owner__c != null) {
                    userValue = String.valueOf(a.FEC_Assignment_Owner__c);
                } else if (String.isNotBlank(a.FEC_OwnerID__c)) {
                    String ownerIdStr = a.FEC_OwnerID__c.trim();
                    Boolean looksLikeId = ownerIdStr.length() >= 15 && ownerIdStr.startsWith(FEC_ConstantCommon.QUEUE_ID_START);
                    if (looksLikeId) {
                        try {
                            Id queueId = (Id) ownerIdStr;
                            List<Group> groups = [SELECT Name FROM Group WHERE Id = :queueId AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE LIMIT 1];
                            userValue = groups.isEmpty() ? ownerIdStr : groups[0].Name;
                        } catch (Exception ex) {
                            userValue = ownerIdStr;
                        }
                    } else {
                        userValue = ownerIdStr;
                    }
                }
                if (String.isNotBlank(userValue)) {
                    userValues.add(userValue);
                }
            }
            
            String newFieldValue = userValues.isEmpty() ? null : String.join(userValues, ',');
            Database.update(
                new Case(Id = caseId, FEC_Assignment_Users__c = newFieldValue),
            AccessLevel.SYSTEM_MODE
                );
            
            for (FEC_Assignment__c a : activeAssignments) {
                if (a.FEC_Assignment_Owner__c != null) {
                    shareCaseToUser(caseId, a.FEC_Assignment_Owner__c);
                }
            }
        } catch (Exception e) {
            System.debug('FEC_DEBUG syncAssignmentUsersToCase error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
        }
    }
    
    private static void claimAssignmentIfQueueOwner(
        Id caseId,
    Id assignmentId
    ) {
        
        Id currentUserId = UserInfo.getUserId();
        
        User currentUser = [
        SELECT
            Id,
            Email,
            UserRole.Name
        FROM User
        WHERE Id = :currentUserId
        LIMIT 1
    ];
        
        FEC_Assignment__c ass = [
        SELECT
            Id,
            FEC_Assignment_Owner__c,
            FEC_OwnerID__c
        FROM FEC_Assignment__c
        WHERE Id = :assignmentId
        LIMIT 1
    ];
        
        // chỉ xử lý khi owner là Queue
        if (
            ass.FEC_Assignment_Owner__c != null ||
            String.isBlank(ass.FEC_OwnerID__c)
        ) {
            return;
        }
        
        String oldQueueId = ass.FEC_OwnerID__c;
        
        // claim assignment
        update new FEC_Assignment__c(
            Id = assignmentId,
        FEC_Assignment_Owner__c = currentUserId,
        FEC_OwnerID__c = currentUserId
            );
        
        syncAssignmentUsersToCase(caseId, assignmentId);
        
        Case c = [
        SELECT
            FEC_Current_Case_Stage__r.FEC_Code__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
    ];
        
        insert new FEC_Routing_Action_History__c(
            
        FEC_Routing_Action__c =
            'Change Owner',
        
        FEC_Routing_Action_Type__c =
            FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
        
        FEC_Original_User_Queue__c =
            oldQueueId,
        
        FEC_Original_User_Queue_ID__c =
            oldQueueId,
        
        FEC_Updated_User_Queue__c =
            emailLocalPart(currentUser.Email),
        
        FEC_Updated_User_Queue_ID__c =
            currentUserId,
        
        FEC_User__c =
            emailLocalPart(currentUser.Email),
        
        FEC_User_Role__c =
            currentUser.UserRole != null
            ? currentUser.UserRole.Name
            : null,
        
        FEC_Stage_Name__c =
            c.FEC_Current_Case_Stage__r.FEC_Code__c,
        
        FEC_Assignment__c =
            assignmentId,
        
        FEC_Case__c =
            caseId
            );
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
    
    // tungnm37: Share Case với User khi assign Assignment Owner → User (quyền Edit)
    private static void shareCaseToUser(Id caseId, Id userId) {
        try {
            // Kiểm tra đã share chưa để tránh duplicate
            List<CaseShare> existing = [
                SELECT Id FROM CaseShare
                WHERE CaseId = :caseId
                  AND UserOrGroupId = :userId
                  AND RowCause = :FEC_ConstantCommon.CASE_SHARE_ROW_CAUSE_MANUAL
                LIMIT 1
            ];
            if (!existing.isEmpty()) return;
            
            CaseShare share = new CaseShare(
                CaseId = caseId,
            UserOrGroupId = userId,
            CaseAccessLevel = FEC_ConstantCommon.CASE_SHARE_ACCESS_LEVEL_EDIT,
            RowCause = FEC_ConstantCommon.CASE_SHARE_ROW_CAUSE_MANUAL
                );
            Database.insert(share, false); // false = không throw nếu đã tồn tại
        } catch (Exception e) {
            System.debug('FEC_DEBUG shareCaseToUser error: ' + e.getMessage());
        }
    }
    
    
    
    public static Boolean isCurrentUserInQueue(
        String queueDeveloperName
    ) {
        
        Id userId = UserInfo.getUserId();
        
        User u = [
        SELECT
            Id,
            UserRoleId
        FROM User
        WHERE Id = :userId
        LIMIT 1
    ];
        
        /*
         * Queue
         */
        Group queueGroup = [
        SELECT
            Id,
            Name
        FROM Group
        WHERE
            Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND DeveloperName = :queueDeveloperName
        LIMIT 1
    ];
        
        /*
         * Queue members
         */
        List<GroupMember> members = [
        SELECT
            UserOrGroupId
        FROM GroupMember
        WHERE GroupId = :queueGroup.Id
    ];
        
        Set<Id> memberIds = new Set<Id>();
        
        for (GroupMember gm : members) {
            memberIds.add(gm.UserOrGroupId);
        }
        
        /*
         * Direct user
         */
        if (memberIds.contains(userId)) {
            return true;
        }
        
        /*
         * Resolve Role Groups
         */
        if (u.UserRoleId != null) {
            
            List<Group> roleGroups = [
            SELECT
                Id,
                Type,
                RelatedId
            FROM Group
            WHERE
                RelatedId = :u.UserRoleId
                AND Type IN (
                    :FEC_ConstantCommon.ROLE_STR,
                    :FEC_ConstantCommon.ROLE_SUBORDINATE_STR
                )
        ];
            
            for (Group g : roleGroups) {
                
                if (memberIds.contains(g.Id)) {
                    return true;
                }
            }
        }
        
        return false;
    }
    private static Boolean isUserInNestedGroups(
        Id userId,
    Set<Id> groupIds
    ) {
        
        if (groupIds.isEmpty()) {
            return false;
        }
        
        List<GroupMember> nested = [
            SELECT GroupId, UserOrGroupId
            FROM GroupMember
            WHERE GroupId IN :groupIds
        ];
        
        for (GroupMember gm :nested) {
            
            if (gm.UserOrGroupId == userId) {
                return true;
            }
        }
        
        return false;
    }
    
    public static Boolean isCSSupport() {
        return isCurrentUserInQueue(
            FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME
            );
    }
    
    public static Boolean isCSCustomerCare() {
        return isCurrentUserInQueue(
            FEC_ConstantCommon.QUEUE_DQ_CS_CUSTOMER_CARE_NAME
            );
    }
    
    public static Boolean isOtherCS(Id userID) {
        
        // Id userId = UserInfo.getUserId();
        
        User u = [
        SELECT
            Id,
            UserRoleId
        FROM User
        WHERE Id = :userID
        LIMIT 1
    ];
        
        Set<Id> memberIds = new Set<Id>();
        
        /*
         * Direct user
         */
        memberIds.add(userId);
        
        /*
         * Role Groups
         */
        if (u.UserRoleId != null) {
            
            List<Group> roleGroups = [
            SELECT
                Id
            FROM Group
            WHERE
                RelatedId = :u.UserRoleId
                AND Type IN (
                    :FEC_ConstantCommon.ROLE_STR,
                    :FEC_ConstantCommon.ROLE_SUBORDINATE_STR
                )
        ];
            
            for (Group g : roleGroups) {
                memberIds.add(g.Id);
            }
        }
        
        /*
         * Find CS queues
         */
        List<GroupMember> groupMembers = [
        SELECT
            Group.Id,
            Group.Name,
            Group.DeveloperName
        FROM GroupMember
        WHERE
            UserOrGroupId IN :memberIds
            AND Group.Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND Group.DeveloperName LIKE :FEC_ConstantCommon.QUEUE_DEVELOPER_PREFIX_FEC_DQ_CS_LIKE
    ];
        
        if (groupMembers.isEmpty()) {
            return false;
        }
        
        /*
         * Exclude:
         * - CS Support
         * - CS Customer Care
         */
        for (GroupMember gm : groupMembers) {
            
            String devName =
                gm.Group.DeveloperName;
            
            if (
                devName != FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME
                &&
                devName !=
                FEC_ConstantCommon.QUEUE_DQ_CS_CUSTOMER_CARE_NAME
            ) {
                
                return true;
            }
        }
        
        return false;
    }
    
    public static void resolveAllAssignments(Id caseId) {
        System.debug('=== START resolveAllAssignments ===');
        System.debug('caseId = ' + caseId);
        
        try {
            /*
             * Get assignments
             */
            List<FEC_Assignment__c> assignments = [
                SELECT Id, Name, FEC_Assignment_Status__c, FEC_Assignment_Owner__c,
                FEC_OwnerID__c FROM FEC_Assignment__c WHERE FEC_Case__c = : caseId
            ];
            
            System.debug('=== assignments size === ' + assignments.size());
            
            if (assignments.isEmpty()) {
                System.debug('=== NO ASSIGNMENTS FOUND ===');
                
                return;
            }
            
            /*
             * Current User
             */
            User currentUser = [
                SELECT Id, Email,
                UserRole.Name FROM User WHERE Id = : UserInfo.getUserId()
            ];
            
            /*
             * Case
             */
            Case c = [
                SELECT Id,
                FEC_Current_Case_Stage__r.FEC_Code__c FROM Case WHERE Id = : caseId
            ];
            
            
            System.debug('FEC_Current_Case_Stage');
            System.debug(c.FEC_Current_Case_Stage__r.FEC_Code__c);
            /*
             * Collect queue ids
             */
            Set<Id> queueIds = new Set<Id>();
            
            for (FEC_Assignment__c ass : assignments) {
                if (String.isNotBlank(ass.FEC_OwnerID__c)
                && ass.FEC_OwnerID__c.startsWith(FEC_ConstantCommon.QUEUE_ID_START)) {
                    try {
                        queueIds.add((Id) ass.FEC_OwnerID__c);
                        
                    } catch (Exception ex) {
                        System.debug('Invalid Queue Id: ' + ass.FEC_OwnerID__c);
                    }
                }
            }
            
            /*
             * Query queues ONCE
             */
            Map<Id, Group> queueMap = new Map<Id, Group>();
            
            if (!queueIds.isEmpty()) {
                queueMap = new Map<Id, Group>([
                    SELECT Id, Name FROM Group WHERE Id IN : queueIds AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
                ]);
            }
            
            /*
             * Build records
             */
            List<FEC_Routing_Action_History__c> histories = new List<FEC_Routing_Action_History__c>();
            
            List<FEC_Case_Remarks__c> remarks = new List<FEC_Case_Remarks__c>();
            
            /*
             * Process assignments
             */
            for (FEC_Assignment__c ass : assignments) {
                System.debug('=== PROCESS ASSIGNMENT === ' + ass.Id);
                
                System.debug('OLD STATUS = ' + ass.FEC_Assignment_Status__c);
                
                /*
                 * Resolve owner display
                 */
                String ownerValue;
                
                /*
                 * User owner
                 */
                if (ass.FEC_Assignment_Owner__c != null) {
                    ownerValue = String.valueOf(ass.FEC_Assignment_Owner__c);
                }
                
                /*
                 * Queue owner
                 */
                else if (String.isNotBlank(ass.FEC_OwnerID__c)) {
                    if (ass.FEC_OwnerID__c.startsWith(FEC_ConstantCommon.QUEUE_ID_START)) {
                        Group q = queueMap.get((Id) ass.FEC_OwnerID__c);
                        
                        ownerValue = q != null ? q.Name : ass.FEC_OwnerID__c;
                        
                    } else {
                        ownerValue = ass.FEC_OwnerID__c;
                    }
                }
                
                System.debug('ownerValue = ' + ownerValue);
                
                /*
                 * Status mapping
                 */
                if (ass.FEC_Assignment_Status__c
                == FEC_ConstantCommon.STATUS_CS_BACKOFFICE) {
                    ass.FEC_Assignment_Status__c =
                        FEC_ConstantCommon.ASSIGNMENT_AUTOCOMPLETE_STATUS;
                    
                } else {
                    ass.FEC_Assignment_Status__c =
                        FEC_ConstantCommon.ASSIGNMENT_AUTORECALLED_STATUS;
                }
                
                System.debug('NEW STATUS = ' + ass.FEC_Assignment_Status__c);
                
                /*
                 * Routing History
                 */
                histories.add(new FEC_Routing_Action_History__c(
                    
                FEC_Routing_Action_Type__c =
                    FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
                
                FEC_Case__c = caseId,
                
                FEC_Assignment__c = ass.Id,
                
                FEC_Routing_Action__c = FEC_ConstantCommon.ACTION_RESOLVE,
                
                FEC_Original_User_Queue__c = ownerValue,
                
                FEC_Original_User_Queue_ID__c = ass.FEC_OwnerID__c,
                
                FEC_Updated_User_Queue__c = ownerValue,
                
                FEC_Updated_User_Queue_ID__c = ass.FEC_OwnerID__c,
                
                FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,
                
                FEC_User__c = currentUser.Id,
                
                FEC_User_Role__c = currentUser.UserRole != null
                    ? currentUser.UserRole.Name
                    : null));
                
                /*
                 * Case Remark
                 */
                remarks.add(new FEC_Case_Remarks__c(
                    
                FEC_Remark_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
                
                FEC_Case_Remarks__c = FEC_ConstantCommon.ASSIGNMENT_AUTO_COMPLETED_REMARK,
                FEC_Stage_Name__c   = c.FEC_Current_Case_Stage__r.FEC_Code__c,
                FEC_Case__c = caseId,
                
                FEC_Assignment__c = ass.Id,
                
                FEC_User__c = emailLocalPart(currentUser.Email),
                
                FEC_User_Role__c = currentUser.UserRole != null
                    ? currentUser.UserRole.Name
                    : null));
            }
            
            /*
             * UPDATE assignments
             */
            System.debug('=== BEFORE UPDATE ===');
            
            update assignments;
            
            System.debug('=== UPDATE SUCCESS ===');
            
            /*
             * INSERT histories + remarks
             */
            System.debug(
                '=== HISTORIES SIZE === ' +
                histories.size()
                );
            
            if (!histories.isEmpty()) {
                
                insert histories;
                
                System.debug(
                    '=== HISTORIES INSERTED ==='
                    );
            }
            
            System.debug(
                '=== REMARKS SIZE === ' +
                remarks.size()
                );
            
            if (!remarks.isEmpty()) {
                
                insert remarks;
                
                System.debug(
                    '=== REMARKS INSERTED ==='
                    );
            }
            
            System.debug('=== INSERT SUCCESS ===');
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '=== ERROR MESSAGE === ' + e.getMessage());
            
            System.debug(LoggingLevel.ERROR,
            '=== STACK TRACE === ' + e.getStackTraceString());
            
            throw e;
        }
        
        System.debug('=== END resolveAllAssignments ===');
    }
}