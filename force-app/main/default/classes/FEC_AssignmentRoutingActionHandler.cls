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
            claimAssignmentIfQueueOwner(caseId, assignmentId);
            
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
                handleRouteTo(caseId, assignmentId, remark, decision, subDecision);
                
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
        
        update a;
        syncAssignmentUsersToCase(caseId, assignmentId);
        
        insertHistory(caseId, assignmentId, FEC_ConstantCommon.ACTION_ESCALATE, remark);
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
        
        // ===== INSERT HISTORY =====
        insertHistory(caseId, assignmentId, FEC_ConstantCommon.ACTION_REJECT, remark);
    }
    
    private static void handleResolve(
        Id caseId,
    Id assignmentId,
    String remark
    ) {
        
        // ===== UPDATE ASSIGNMENT =====
        update new FEC_Assignment__c(
            Id = assignmentId,
        FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_COMPLETED,
        FEC_Assignment_Owner__c = null
            );
        
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
            
        } else if (decision == FEC_ConstantCommon.DECISION_USER_QUEUE) {
            
            Id queueId = getMainQueueId(c.CreatedById);
            
            if (queueId == null) {
                throw new AuraHandledException(System.Label.FEC_ERR_QUEUE_NOT_FOUND);
            }
            
            assignment.FEC_Assignment_Owner__c = null;
            assignment.FEC_OwnerID__c = queueId;
            
        } else {
            throw new AuraHandledException(System.Label.FEC_ERR_INVALID_INPUT);
        }
        
        update assignment;
        syncAssignmentUsersToCase(caseId, assignmentId);
        
        insertHistory(caseId, assignmentId, FEC_ConstantCommon.ACTION_REVERT, remark);
    }
    
    
    private static void handleRouteTo(
        Id caseId,
    Id assignmentId,
    String remark,
    String decision,
    String subDecision
    ) {
        if (String.isBlank(decision)) {
            throw new AuraHandledException(System.Label.FEC_ERR_TEAM_REQUIRED);
        }
        
        // ===== GET CASE =====
        Case c = [
        SELECT Id,
               RecordType.DeveloperName,
               FEC_Business_Process__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
    ];
        
        // ===== DETERMINE TEAM + QUEUE =====
        String team;
        Id targetQueueId;
        
        // ===== CASE TYPE LOGIC =====
        if (c.FEC_Business_Process__c == FEC_ConstantCommon.BP_GENERAL_SERVICE) {
            team = FEC_ConstantCommon.TEAM_CS_SUPPORT;
            targetQueueId = getQueueIdByName(FEC_ConstantCommon.QUEUE_CS_SUPPORT);
            
        } else if (c.FEC_Business_Process__c == FEC_ConstantCommon.BP_COMPLAINT || c.FEC_Business_Process__c == FEC_ConstantCommon.BP_FEEDBACK) {
            team = FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE;
            targetQueueId = getQueueIdByName(FEC_ConstantCommon.QUEUE_CS_CUSTOMER_CARE);
            
        } else {
            // fallback: dùng subDecision (team user chọn)
            team = subDecision;
            targetQueueId = getQueueIdByTeam(team);
        }
        
        if (targetQueueId == null) {
            throw new AuraHandledException(System.Label.FEC_ERR_QUEUE_NOT_FOUND + ': ' + team);
        }
        
        // ===== CHECK HISTORY =====
        Id lastUser = getLastUserOfTeam(caseId, team);
        
        FEC_Assignment__c assignment = new FEC_Assignment__c(
            Id = assignmentId
            );
        
        // ===== FIRST TIME → QUEUE =====
        if (lastUser == null) {
            assignment.FEC_Assignment_Owner__c = null;
            assignment.FEC_OwnerID__c = targetQueueId;
            
            // ===== RETURN → USER =====
        } else {
            assignment.FEC_Assignment_Owner__c = lastUser;
            assignment.FEC_OwnerID__c = lastUser;
        }
        
        // ===== STATUS =====
        assignment.FEC_Assignment_Status__c = getRouteToStatus(team);
        
        update assignment;
        syncAssignmentUsersToCase(caseId, assignmentId);
        
        insertHistory(caseId, assignmentId, FEC_ConstantCommon.ACTION_ROUTE_TO_DISPLAY, remark);
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
        
        // ===== USER =====
        if (decision ==  FEC_ConstantCommon.DECISION_USER) {
            assignment.FEC_Assignment_Owner__c = subDecision;
            assignment.FEC_OwnerID__c = subDecision;
            
            // ===== QUEUE =====
        } else if (decision ==  FEC_ConstantCommon.DECISION_QUEUE ) {
            assignment.FEC_Assignment_Owner__c = null;
            assignment.FEC_OwnerID__c = subDecision;
            
        } else {
            throw new AuraHandledException(System.Label.FEC_ERR_INVALID_INPUT);
        }
        
        update assignment;
        syncAssignmentUsersToCase(caseId, assignmentId);
        
        insertHistory(caseId, assignmentId, 'Transfer', remark);
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
        
        update assignment;
        syncAssignmentUsersToCase(caseId, assignmentId);
        update caseUpdate;
        
        insertHistory(
            caseId,
        assignmentId,
        FEC_ConstantCommon.ACTION_UPDATE,
        remark
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
        SELECT Id, FEC_Assignment_Owner__c
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
        
        FEC_Original_User_Queue__c = ass.FEC_Assignment_Owner__c,
        FEC_Original_User_Queue_ID__c = ass.FEC_Assignment_Owner__c,
        FEC_Updated_User_Queue__c = ass.FEC_Assignment_Owner__c,
        FEC_Updated_User_Queue_ID__c = ass.FEC_Assignment_Owner__c,
        
        FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,
        
        FEC_User__c = u.Id,
        FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null
            ));
        
        // --- Case Remark ---
        records.add(new FEC_Case_Remarks__c(
            FEC_Remark_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
        FEC_Case_Remarks__c = remark,
        FEC_Case__c = caseId,
        FEC_Assignment__c = assignmentId,
        FEC_User__c = u.Email,
        FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null
            ));
        
        insert records;
    }
    
    
    private static Id getMainQueueId(Id userId) {
        User u = [
        SELECT FEC_Main_Queue__c 
        FROM User
        WHERE Id = :userId
    ];
        return u.FEC_Main_Queue__c;
    }
    
    private static Id getQueueIdByName(String queueName) {
        Group g = [
        SELECT Id
        FROM Group
        WHERE Type = 'Queue'
        AND Name = :queueName
        LIMIT 1
    ];
        return g?.Id;
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
        WHERE Type = 'Queue'
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
    private static void syncAssignmentUsersToCase(Id caseId, Id assignmentId) {
        try {
            List<FEC_Assignment__c> assignments = [
                SELECT Id, FEC_Assignment_Owner__c, FEC_OwnerID__c
                FROM FEC_Assignment__c
                WHERE Id = :assignmentId
                LIMIT 1
            ];
            if (assignments.isEmpty()) return;
            
            FEC_Assignment__c a = assignments[0];
            String userValue;
            if (a.FEC_Assignment_Owner__c != null) {
                // tungnm37: Owner là User → lưu User ID
                userValue = String.valueOf(a.FEC_Assignment_Owner__c);
            } else if (String.isNotBlank(a.FEC_OwnerID__c)) {
                // tungnm37: Owner là Queue → FEC_OwnerID__c lưu Queue Name → dùng trực tiếp
                // Nếu là Salesforce Id (bắt đầu 00G) thì lookup Name
                String ownerIdStr = a.FEC_OwnerID__c.trim();
                Boolean looksLikeId = ownerIdStr.length() >= 15 && ownerIdStr.startsWith('00G');
                if (looksLikeId) {
                    try {
                        Id queueId = (Id) ownerIdStr;
                        List<Group> groups = [SELECT Name FROM Group WHERE Id = :queueId AND Type = 'Queue' LIMIT 1];
                        userValue = groups.isEmpty() ? ownerIdStr : groups[0].Name;
                    } catch (Exception ex) {
                        userValue = ownerIdStr;
                    }
                } else {
                    // Đã là Queue Name
                    userValue = ownerIdStr;
                }
            }
            
            if (String.isNotBlank(userValue)) {
                Database.update(
                    new Case(Id = caseId, FEC_Assignment_Users__c = userValue),
                AccessLevel.SYSTEM_MODE
                    );
                // tungnm37: nếu Owner là User → share Case với quyền Edit
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
        
        List<String> parts = email.split('@');
        
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
                  AND RowCause = 'Manual'
                LIMIT 1
            ];
            if (!existing.isEmpty()) return;

            CaseShare share = new CaseShare(
                CaseId = caseId,
                UserOrGroupId = userId,
                CaseAccessLevel = 'Edit',
                RowCause = 'Manual'
            );
            Database.insert(share, false); // false = không throw nếu đã tồn tại
        } catch (Exception e) {
            System.debug('FEC_DEBUG shareCaseToUser error: ' + e.getMessage());
        }
    }
}