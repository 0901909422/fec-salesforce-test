public without sharing class FEC_AssignmentListHandler {
    
    @AuraEnabled
    public static String getUserDepartment() {
        
        if(isCSSupport() || isCSCustomerCare() ){
            return FEC_ConstantCommon.TEAM_CODE_CS;
        }else{
            return FEC_ConstantCommon.TEAM_OTHER;
        }
    }
    
    // @AuraEnabled
    // public static List<FEC_Assignment__c> getAssignments(String caseId) {
        
        //     if (caseId == null) {
            //         throw new AuraHandledException(System.Label.LBL_CaseIdRequired);
        //     }
        
        //     try {
            
            //         if (!Schema.sObjectType.FEC_Assignment__c.isAccessible()) {
                //             throw new AuraHandledException(
                //                 System.Label.FEC_MSG_NO_ACCESS_ASSIGNMENT
                //                 );
            //         }
            
            //         List<FEC_Assignment__c> records = [
            //         SELECT
            //             Id,
            //             Name,
            //             FEC_Assignment_Owner__c,
            //             FEC_Assignment_Owner__r.Name,
            //             FEC_Assignment_Owner__r.Email,
            //             FEC_Assignment_Status__c,
            //             FEC_OwnerID__c, // tungnm37 thêm: Queue Id để LWC resolve queue name
            //             FEC_Assignment_Type__c, // tungnm37 thêm: để phân biệt COF/GSR vs thường
            //             FEC_Assignment_Owner_Text__c // tungnm37 thêm: formula field hiện đúng owner/queue/Unassigned
            //         FROM FEC_Assignment__c
            //         WHERE FEC_Case__c = :caseId
            //     ];
            
            //         return records;
            
        //     } catch (Exception e) {
            
            //         System.debug(
            //             LoggingLevel.ERROR,
            //         'getAssignments error: ' + e.getMessage()
            //             );
            
            //         throw new AuraHandledException(
            //             System.Label.FEC_MSG_LOAD_ASSIGNMENT_FAILED
            //             );
        //     }
    // }
    
    //HieuTT74: [Update: 22/5/2026] -Update Hiển thị Assignment List với các user thuộc bộ phận khác nhau
    @AuraEnabled
    public static List<FEC_Assignment__c> getAssignmentsNEW(
        String caseId
    ) {
        
        if (String.isBlank(caseId)) {
            
            throw new AuraHandledException(
                System.Label.LBL_CaseIdRequired
                );
        }
        
        try {
            
            // =====================================================
            // OBJECT ACCESS
            // =====================================================
            if (!Schema.sObjectType.FEC_Assignment__c.isAccessible()) {
                
                throw new AuraHandledException(
                    System.Label.FEC_MSG_NO_ACCESS_ASSIGNMENT
                    );
            }
            
            // =====================================================
            // CURRENT USER
            // =====================================================
            User currentUser = [

            SELECT
                Id,
                Profile.Name

            FROM User

            WHERE Id = :UserInfo.getUserId()

            LIMIT 1
        ];
            
            String profileName =
                currentUser.Profile.Name;
            
            System.debug(
                '===== CURRENT USER ===== ' +
                currentUser.Id
                );
            
            System.debug(
                '===== PROFILE ===== ' +
                profileName
                );
            
            // =====================================================
            // LOAD ASSIGNMENTS
            // =====================================================
            List<FEC_Assignment__c> allAssignments = [

            SELECT
                Id,
                Name,
                FEC_Assignment_Owner__c,
                FEC_Assignment_Owner__r.Name,
                FEC_Assignment_Owner__r.Email,
                FEC_Assignment_Status__c,
                FEC_OwnerID__c,
                FEC_Assignment_Type__c,
                FEC_Assignment_Owner_Text__c,
                FEC_Draft_Assignment_Remark__c
            FROM FEC_Assignment__c

            WHERE FEC_Case__c = :caseId

            ORDER BY CreatedDate ASC
        ];
            
            System.debug(
                '===== TOTAL ASSIGNMENTS ===== ' +
                allAssignments.size()
                );
            
            // =====================================================
            // CS USERS
            // => SEE ALL ASSIGNMENTS
            // =====================================================
            if (
                profileName == FEC_ConstantCommon.PROFILE_CS_BO ||
                profileName == FEC_ConstantCommon.PROFILE_CS_FL
            ) {
                
                System.debug(
                    '===== CS USER => RETURN ALL ====='
                    );
                
                return allAssignments;
            }
            
            // =====================================================
            // RELEVANT DEPTS
            // =====================================================
            if (profileName == FEC_ConstantCommon.PROFILE_RELEVANT_DEPTS) {
                
                // =================================================
                // GET CURRENT USER QUEUES
                // =================================================
                Set<String> userQueueNames =
                    getCurrentUserQueues(currentUser.Id);
                
                System.debug(
                    '===== USER QUEUE NAMES ===== ' +
                    userQueueNames
                    );
                
                // =================================================
                // FILTER ASSIGNMENTS
                // =================================================
                List<FEC_Assignment__c> visibleAssignments =
                    new List<FEC_Assignment__c>();
                
                for (FEC_Assignment__c ass : allAssignments) {
                    
                    Boolean canView = false;
                    
                    // =============================================
                    // PRIORITY 1
                    // ASSIGNED TO USER
                    // =============================================
                    if (
                        ass.FEC_Assignment_Owner__c != null
                    ) {
                        
                        if (
                            ass.FEC_Assignment_Owner__c ==
                            currentUser.Id
                        ) {
                            
                            canView = true;
                        }
                    }
                    
                    // =============================================
                    // PRIORITY 2
                    // ASSIGNED TO QUEUE
                    // ONLY WHEN OWNER USER IS NULL
                    // =============================================
                    else if (
                        ass.FEC_OwnerID__c != null &&
                        userQueueNames.contains(
                        ass.FEC_OwnerID__c
                        )
                    ) {
                        
                        canView = true;
                    }
                    
                    // =============================================
                    // DEBUG
                    // =============================================
                    System.debug(
                        '===== CHECK ASSIGNMENT ====='
                        );
                    
                    System.debug(
                        'Assignment: ' + ass.Name
                        );
                    
                    System.debug(
                        'Assignment Owner User: ' +
                        ass.FEC_Assignment_Owner__c
                        );
                    
                    System.debug(
                        'Assignment Queue: ' +
                        ass.FEC_OwnerID__c
                        );
                    
                    System.debug(
                        'Can View: ' + canView
                        );
                    
                    if (canView) {
                        
                        visibleAssignments.add(ass);
                        
                        System.debug(
                            '===== ADD VISIBLE ASSIGNMENT ===== ' +
                            ass.Name
                            );
                    }
                }
                
                System.debug(
                    '===== FINAL RESULT SIZE ===== ' +
                    visibleAssignments.size()
                    );
                
                return visibleAssignments;
            }
            
            // =====================================================
            // DEFAULT
            // =====================================================
            return new List<FEC_Assignment__c>();
            
        } catch (Exception e) {
            
            System.debug(
                LoggingLevel.ERROR,
            'getAssignmentsNEW error: ' +
                e.getMessage()
                );
            
            System.debug(
                LoggingLevel.ERROR,
            e.getStackTraceString()
                );
            
            throw new AuraHandledException(
                System.Label.FEC_MSG_LOAD_ASSIGNMENT_FAILED
                );
        }
    }
    
    public static Set<String> getCurrentUserQueues(Id userId) {
        
        Set<String> queueNames = new Set<String>();
        
        User u = [
        SELECT
            Id,
            UserRoleId
        FROM User
        WHERE Id = :userId
        LIMIT 1
    ];
        
        // =====================================================
        // ROLE GROUP IDS
        // =====================================================
        Set<Id> accessibleMemberIds = new Set<Id>();
        
        accessibleMemberIds.add(userId);
        
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
                
                accessibleMemberIds.add(g.Id);
            }
        }
        
        System.debug(
            '===== ACCESSIBLE MEMBER IDS ===== ' +
            accessibleMemberIds
            );
        
        // =====================================================
        // GET QUEUES
        // =====================================================
        List<GroupMember> queueMembers = [

        SELECT
            Group.Name,
            Group.DeveloperName,
            Group.Type,
            UserOrGroupId

        FROM GroupMember

        WHERE
            Group.Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND UserOrGroupId IN :accessibleMemberIds
    ];
        
        for (GroupMember gm : queueMembers) {
            
            queueNames.add(gm.Group.Name);
            
            System.debug(
                '===== FOUND QUEUE ===== ' +
                gm.Group.Name
                );
        }
        
        return queueNames;
    }
    
    
    //HieuTT Update  [23/5/2026]-----------------------------------------//
    public static Set<Id> getCurrentUserQueueIds(Id userId) {
        
        Set<Id> queueIds = new Set<Id>();
        
        User u = [
        SELECT Id, UserRoleId
        FROM User
        WHERE Id = :userId
        LIMIT 1
    ];
        
        Set<Id> accessibleMemberIds = new Set<Id>();
        accessibleMemberIds.add(userId);
        
        if (u.UserRoleId != null) {
            
            List<Group> roleGroups = [
            SELECT Id
            FROM Group
            WHERE
                RelatedId = :u.UserRoleId
                AND Type IN (
                    :FEC_ConstantCommon.ROLE_STR,
                    :FEC_ConstantCommon.ROLE_SUBORDINATE_STR
                )
        ];
            
            for (Group g : roleGroups) {
                accessibleMemberIds.add(g.Id);
            }
        }
        
        List<GroupMember> queueMembers = [
        SELECT GroupId
        FROM GroupMember
        WHERE
            Group.Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND UserOrGroupId IN :accessibleMemberIds
    ];
        
        for (GroupMember gm : queueMembers) {
            queueIds.add(gm.GroupId);
        }
        
        return queueIds;
    }
    
    
    
    //------------------------------------------------------------------//
    
    @AuraEnabled(cacheable=true)
    public static AssignmentViewResponse getAssignmentsForViewNEW(
        String caseId,
    Integer pageSize,
    Integer pageNumber
    ) {
        
        if (String.isBlank(caseId)) {
            
            throw new AuraHandledException(
                System.Label.LBL_CaseIdRequired
                );
        }
        
        try {
            
            // =====================================================
            // CURRENT USER
            // =====================================================
            User currentUser = [

            SELECT
                Id,
                Profile.Name

            FROM User

            WHERE Id = :UserInfo.getUserId()

            LIMIT 1
        ];
            
            String profileName =
                currentUser.Profile.Name;
            
            System.debug(
                '===== CURRENT USER ===== ' +
                currentUser.Id
                );
            
            System.debug(
                '===== PROFILE ===== ' +
                profileName
                );
            
            // =====================================================
            // DEFAULT VALUES
            // =====================================================
            pageSize =
                (pageSize == null || pageSize <= 0)
                ? 10
                : pageSize;
            
            pageNumber =
                (pageNumber == null || pageNumber <= 0)
                ? 1
                : pageNumber;
            
            Integer offsetValue =
                (pageNumber - 1) * pageSize;
            
            AssignmentViewResponse response =
                new AssignmentViewResponse();
            
            // =====================================================
            // LOAD ALL ASSIGNMENTS
            // =====================================================
            List<FEC_Assignment__c> allAssignments = [

            SELECT
                Id,
                Name,
                FEC_Assignment_Name__c,
                CreatedDate,
                CreatedBy.Email,
                CreatedBy.UserRole.Name,
                FEC_Assignment_Status__c,
                FEC_OwnerID__c,
                FEC_Assignment_Type__c,
                FEC_Assignment_Owner__c

            FROM FEC_Assignment__c

            WHERE FEC_Case__c = :caseId

            ORDER BY CreatedDate DESC
        ];
            
            System.debug(
                '===== TOTAL ASSIGNMENTS ===== ' +
                allAssignments.size()
                );
            
            // =====================================================
            // FILTER ASSIGNMENTS
            // =====================================================
            List<FEC_Assignment__c> visibleAssignments =
                new List<FEC_Assignment__c>();
            
            // =====================================================
            // CS USERS
            // => SEE ALL ASSIGNMENTS
            // =====================================================
            if (
                profileName == FEC_ConstantCommon.PROFILE_CS_BO ||
                profileName == FEC_ConstantCommon.PROFILE_CS_FL
            ) {
                
                visibleAssignments = allAssignments;
            }
            
            // =====================================================
            // RELEVANT DEPTS
            // =====================================================
            else if (
                profileName == FEC_ConstantCommon.PROFILE_RELEVANT_DEPTS
            ) {
                
                Set<String> userQueueNames =
                    getCurrentUserQueues(
                    currentUser.Id
                    );
                
                System.debug(
                    '===== USER QUEUE NAMES ===== ' +
                    userQueueNames
                    );
                
                for (
                    FEC_Assignment__c ass :
                    allAssignments
                ) {
                    
                    Boolean canView = false;
                    
                    // =============================================
                    // ASSIGNED TO USER
                    // =============================================
                    if (
                        ass.FEC_Assignment_Owner__c != null
                    ) {
                        
                        if (
                            ass.FEC_Assignment_Owner__c ==
                            currentUser.Id
                        ) {
                            
                            canView = true;
                        }
                    }
                    
                    // =============================================
                    // ASSIGNED TO QUEUE
                    // =============================================
                    else if (
                        ass.FEC_OwnerID__c != null &&
                        userQueueNames.contains(
                        ass.FEC_OwnerID__c
                        )
                    ) {
                        
                        canView = true;
                    }
                    
                    System.debug(
                        '===== CHECK ASSIGNMENT ====='
                        );
                    
                    System.debug(
                        'Assignment: ' + ass.Name
                        );
                    
                    System.debug(
                        'Assignment Queue: ' +
                        ass.FEC_OwnerID__c
                        );
                    
                    System.debug(
                        'Assignment Owner: ' +
                        ass.FEC_Assignment_Owner__c
                        );
                    
                    System.debug(
                        'Can View: ' + canView
                        );
                    
                    if (canView) {
                        
                        visibleAssignments.add(ass);
                    }
                }
            }
            
            // =====================================================
            // OTHER USERS
            // =====================================================
            else {
                
                visibleAssignments =
                    new List<FEC_Assignment__c>();
            }
            
            // =====================================================
            // TOTAL COUNT AFTER FILTER
            // =====================================================
            response.totalCount =
                visibleAssignments.size();
            
            // =====================================================
            // MANUAL PAGINATION
            // =====================================================
            Integer startIndex =
                offsetValue;
            
            Integer endIndex =
                Math.min(
                startIndex + pageSize,
            visibleAssignments.size()
                );
            
            List<FEC_Assignment__c> pagedAssignments =
                new List<FEC_Assignment__c>();
            
            if (
                startIndex <
                visibleAssignments.size()
            ) {
                
                for (
                    Integer i = startIndex;
                i < endIndex;
                i++
                ) {
                    
                    pagedAssignments.add(
                        visibleAssignments[i]
                        );
                }
            }
            
            // =====================================================
            // GET ASSIGNMENT IDS
            // =====================================================
            Set<Id> assignmentIds =
                new Set<Id>();
            
            for (
                FEC_Assignment__c item :
                pagedAssignments
            ) {
                
                assignmentIds.add(item.Id);
            }
            
            // =====================================================
            // GET LATEST REMARKS
            // =====================================================
            Map<Id, FEC_Case_Remarks__c>
                latestRemarkMap =
                new Map<
                Id,
            FEC_Case_Remarks__c
                >();
            
            if (!assignmentIds.isEmpty()) {
                
                List<FEC_Case_Remarks__c> remarks = [

                SELECT
                    Id,
                    FEC_Assignment__c,
                    FEC_Stage_Name__c,
                    LastModifiedDate

                FROM FEC_Case_Remarks__c

                WHERE
                    FEC_Remark_Type__c =
                        :FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT

                    AND FEC_Case__c = :caseId

                    AND FEC_Assignment__c
                        IN :assignmentIds

                ORDER BY LastModifiedDate DESC
            ];
                
                for (
                    FEC_Case_Remarks__c remark :
                    remarks
                ) {
                    
                    if (
                        !latestRemarkMap.containsKey(
                        remark.FEC_Assignment__c
                        )
                    ) {
                        
                        latestRemarkMap.put(
                            remark.FEC_Assignment__c,
                        remark
                            );
                    }
                }
            }
            
            // =====================================================
            // BUILD RESPONSE
            // =====================================================
            response.assignments =
                new List<AssignmentViewWrapper>();
            
            for (
                FEC_Assignment__c assignment :
                pagedAssignments
            ) {
                
                AssignmentViewWrapper wrapper =
                    new AssignmentViewWrapper();
                
                wrapper.id =
                    assignment.Id;
                
                wrapper.assignmentId =
                    assignment.Name;
                
                wrapper.assignmentType =
                    assignment.FEC_Assignment_Type__c;
                
                wrapper.assignmentName =
                    assignment.FEC_Assignment_Name__c;
                
                wrapper.assignmentStatus =
                    assignment
                    .FEC_Assignment_Status__c;
                
                wrapper.user =
                    assignment.CreatedBy != null
                    ? assignment.CreatedBy.Email
                    : '';
                
                wrapper.userRole =
                    assignment.CreatedBy != null &&
                    assignment.CreatedBy.UserRole != null
                    ? assignment.CreatedBy.UserRole.Name
                    : 'No Role Assigned';
                
                wrapper.latestModifiedDateTime =
                    assignment.CreatedDate;
                
                if (
                    latestRemarkMap.containsKey(
                    assignment.Id
                    )
                ) {
                    
                    wrapper.stageName =
                        latestRemarkMap.get(
                        assignment.Id
                        ).FEC_Stage_Name__c;
                }
                
                response.assignments.add(
                    wrapper
                    );
            }
            
            return response;
            
        } catch (Exception e) {
            
            System.debug(
                LoggingLevel.ERROR,
            'getAssignmentsForView error: ' +
                e.getMessage()
                );
            
            System.debug(
                LoggingLevel.ERROR,
            e.getStackTraceString()
                );
            
            throw new AuraHandledException(
                System.Label.FEC_MSG_LOAD_ASSIGNMENT_FAILED
                );
        }
    }
    
    
    
    @AuraEnabled
    public static List<SelectOptionWrapper> getAction(String caseId)
    {
        Case caseRecord = [
                SELECT Id,
                FEC_Business_Process__c,
                FEC_Stage_Name__c,
                OwnerId
                FROM Case
                WHERE Id = : caseId
                LIMIT 1
            ];
        
        // =====================================================
        // DETECT USER DEPARTMENT
        // =====================================================
        String userDepart;
        
        if (isCSSupport()) {
            
            userDepart = FEC_ConstantCommon.TEAM_CS_SUPPORT;
        } else if (isCSCustomerCare()) {
            
            userDepart = FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE;
        } else {
            
            userDepart = FEC_ConstantCommon.TEAM_OTHER;
        }
        
        System.debug('=== User department: ' + userDepart);
        
        // =====================================================
        // OTHER DEPT
        // =====================================================
        if (userDepart == FEC_ConstantCommon.TEAM_OTHER) {
            return buildOptions(
                FEC_ConstantCommon.ACTION_OPTIONS_OTHER
                );
        }
        // =====================================================
        // CS SUPPORT / CS CUSTOMER CARE
        // =====================================================
        if (userDepart == FEC_ConstantCommon.TEAM_CS_SUPPORT || userDepart == FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE) {
            // =================================================
            // CURRENT USER QUEUES
            // =================================================
            Set<String> currentUserQueues = getCurrentUserQueues(UserInfo.getUserId());
            System.debug('currentUserQueues = ' +
                JSON.serializePretty(currentUserQueues));
            // =================================================
            // CASE OWNER QUEUES
            // =================================================
            Set<String> caseOwnerQueues = new Set<String>();
            
            // =============================================
            // CASE OWNER = QUEUE
            // =============================================
            if (String.valueOf(caseRecord.OwnerId)
            .startsWith(FEC_ConstantCommon.QUEUE_ID_START)) {
                
                Group g = [
                SELECT Id,
                Name
                FROM Group
                WHERE Id = : caseRecord.OwnerId
                LIMIT 1
                ];
                
                caseOwnerQueues.add(g.Name);
            }else {
                
                caseOwnerQueues = getCurrentUserQueues(caseRecord.OwnerId);
            }
            
            System.debug('caseOwnerQueues = ' + JSON.serializePretty(caseOwnerQueues));
            
            Boolean sameQueue = false;
            
            for (String q : currentUserQueues) {
                
                if (caseOwnerQueues.contains(q)) {
                    
                    sameQueue = true;
                    break;
                }
            }
            
            if (!sameQueue) {
                
                return buildOptions(
                    FEC_ConstantCommon.ACTION_OPTIONS_OTHER
                    );
            }
            
            return buildOptions(
                FEC_ConstantCommon.ACTION_OPTIONS_CS_SUPPORT
                );
        }
        
        return new List<SelectOptionWrapper>();
    }
    
    private static List<SelectOptionWrapper> buildOptions(
        List<Map<String, String>> configs
    ) {
        
        List<SelectOptionWrapper> results =
            new List<SelectOptionWrapper>();
        
        for (Map<String, String> item : configs) {
            
            results.add(
                new SelectOptionWrapper(
                item.get('value'),
            item.get('label')
                )
                );
        }
        
        return results;
    }
    
    //--------------------------[END]-----------------------------------------------------------------------
    
    @AuraEnabled(cacheable=true)
    public static List<FEC_Case_Remarks__c> getAssignmentRemarks(String caseId, String assignmentId) {
        
        if (caseId == null) {
            throw new AuraHandledException(System.Label.LBL_CaseIdRequired);
        }
        if (assignmentId == null) {
            throw new AuraHandledException(System.Label.FEC_MSG_ASSIGNMENT_ID_REQUIRED);
        }
        try {
            
            if (!Schema.sObjectType.FEC_Case_Remarks__c.isAccessible()) {
                throw new AuraHandledException(System.Label.FEC_MSG_NO_ACCESS_REMARK);
            }
            
            List<FEC_Case_Remarks__c> records = [
            SELECT
                 Id, FEC_Case_Remarks__c, FEC_Stage_Name__c, FEC_User__c, FEC_User_Role__c,  CreatedDate
            FROM FEC_Case_Remarks__c
            WHERE FEC_Remark_Type__c = :FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT
              AND FEC_Case__c = :caseId AND FEC_Assignment__c = :assignmentId
            ORDER BY CreatedDate DESC
        ];
            
            return records;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'getCaseRemarks error: ' + e.getMessage());
            
            throw new AuraHandledException(System.Label.FEC_MSG_LOAD_REMARK_FAILED);
        }
    }
    
    
    public class SelectOptionWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public SelectOptionWrapper(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<SelectOptionWrapper> getUsersInGroup() {
        
        User currentUser = [
        SELECT FEC_User_Group__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
    ];
        
        List<User> users = [
        SELECT Id, Name
        FROM User
        WHERE FEC_User_Group__c = :currentUser.FEC_User_Group__c AND Id != :UserInfo.getUserId()
        AND IsActive = true
    ];
        
        List<SelectOptionWrapper> result = new List<SelectOptionWrapper>();
        
        for (User u : users) {
            result.add(new SelectOptionWrapper(u.Id, u.Name));
        }
        
        return result;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<SelectOptionWrapper>
    getQueuesForUser() {
        
        Id userId = UserInfo.getUserId();
        
        User u = [
        SELECT UserRoleId
        FROM User
        WHERE Id = :userId
        LIMIT 1
    ];
        
        Set<Id> memberIds = new Set<Id>{
            userId
        };
        
        // Direct/Public Groups
        for (GroupMember gm : [
        SELECT GroupId
        FROM GroupMember
        WHERE UserOrGroupId = :userId
    ]) {
            memberIds.add(gm.GroupId);
        }
        
        // Role Groups
        if (u.UserRoleId != null) {
            
            for (Group g : [
            SELECT Id
            FROM Group
            WHERE Type IN (
                :FEC_ConstantCommon.ROLE_STR,
                :FEC_ConstantCommon.ROLE_SUBORDINATE_STR
            )
            AND RelatedId = :u.UserRoleId
        ]) {
                memberIds.add(g.Id);
            }
        }
        
        // Queue Membership
        Set<Id> queueIds = new Set<Id>();
        
        for (GroupMember gm : [
        SELECT GroupId
        FROM GroupMember
        WHERE UserOrGroupId IN :memberIds
    ]) {
            queueIds.add(gm.GroupId);
        }
        
        List<SelectOptionWrapper> result =
            new List<SelectOptionWrapper>();
        
        for (Group q : [
        SELECT Id, Name
        FROM Group
        WHERE Id IN :queueIds
        AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
        ORDER BY Name
    ]) {
            
            result.add(
                new SelectOptionWrapper(
                q.Id,
            q.Name
                )
                );
        }
        
        return result;
    }
    
    // tungnm37 thêm: lấy queue name từ danh sách Queue Ids
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getQueueNames(List<String> queueIds) {
        Map<String, String> result = new Map<String, String>();
        if (queueIds == null || queueIds.isEmpty()) return result;
        Set<Id> ids = new Set<Id>();
        for (String qid : queueIds) {
            try { ids.add(Id.valueOf(qid)); } catch(Exception e) {}
        }
        for (Group g : [SELECT Id, Name FROM Group WHERE Id IN :ids AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE]) {
            result.put(String.valueOf(g.Id), g.Name);
        }
        return result;
    }
    
    
    public class AssignmentViewResponse {
        
        @AuraEnabled public Integer totalCount;
        
        @AuraEnabled public List<AssignmentViewWrapper> assignments;
        
    }
    
    public class AssignmentViewWrapper {
        
        @AuraEnabled public Id id;
        @AuraEnabled public String assignmentId;
        @AuraEnabled public String assignmentName;
        @AuraEnabled public String stageName;
        @AuraEnabled public String assignmentType;
        @AuraEnabled public String assignmentStatus;
        @AuraEnabled public String user;
        @AuraEnabled public String userRole;
        @AuraEnabled public Datetime latestModifiedDateTime;
        
    }
    
    // @AuraEnabled(cacheable=true)
    // public static AssignmentViewResponse getAssignmentsForView(
    //     String caseId,
    // Integer pageSize,
    // Integer pageNumber
    // ) {
        
        //     if (String.isBlank(caseId)) {
            
            //         throw new AuraHandledException(
            //             System.Label.LBL_CaseIdRequired
            //             );
        //     }
        
        //     try {
            
            //         // DEFAULT VALUES
            //         pageSize =
            //             (pageSize == null || pageSize <= 0)
            //             ? 10
            //             : pageSize;
            
            //         pageNumber =
            //             (pageNumber == null || pageNumber <= 0)
            //             ? 1
            //             : pageNumber;
            
            //         Integer offsetValue =
            //             (pageNumber - 1) * pageSize;
            
            //         AssignmentViewResponse response =
            //             new AssignmentViewResponse();
            
            //         // TOTAL COUNT
            //         response.totalCount = [
            
            //         SELECT COUNT()
            
            //         FROM FEC_Assignment__c
            
            //         WHERE FEC_Case__c = :caseId
            //     ];
            
            //         // PAGING QUERY
            //         List<FEC_Assignment__c> assignments = [
            
            //         SELECT
            //             Id,
            //             Name,
            //             FEC_Assignment_Name__c,
            //             CreatedDate,
            //             CreatedBy.Email,
            //             CreatedBy.UserRole.Name,
            //             FEC_Assignment_Status__c,
            //             FEC_OwnerID__c,
            //             FEC_Assignment_Type__c
            
            //         FROM FEC_Assignment__c
            
            //         WHERE FEC_Case__c = :caseId
            
            //         ORDER BY CreatedDate DESC
            
            //         LIMIT :pageSize
            //         OFFSET :offsetValue
            //     ];
            
            //         Set<Id> assignmentIds =
            //             new Set<Id>();
            
            //         for (FEC_Assignment__c item : assignments) {
                
                //             assignmentIds.add(item.Id);
            //         }
            
            //         Map<Id, FEC_Case_Remarks__c> latestRemarkMap =
            //             new Map<Id, FEC_Case_Remarks__c>();
            
            //         // QUERY REMARKS ONLY WHEN HAVE ASSIGNMENTS
            //         if (!assignmentIds.isEmpty()) {
                
                //             List<FEC_Case_Remarks__c> remarks = [
                
                //             SELECT
                //                 Id,
                //                 FEC_Assignment__c,
                //                 FEC_Stage_Name__c,
                //                 LastModifiedDate
                
                //             FROM FEC_Case_Remarks__c
                
                //             WHERE FEC_Remark_Type__c =
                //                 :FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT
                
                //             AND FEC_Case__c = :caseId
                
                //             AND FEC_Assignment__c IN :assignmentIds
                
                //             ORDER BY LastModifiedDate DESC
                //         ];
                
                //             for (FEC_Case_Remarks__c remark : remarks) {
                    
                    //                 // FIRST = LATEST
                    //                 if (!latestRemarkMap.containsKey(
                    //                     remark.FEC_Assignment__c
                    //                 )) {
                        
                        //                     latestRemarkMap.put(
                        //                         remark.FEC_Assignment__c,
                        //                     remark
                        //                         );
                    //                 }
                //             }
            //         }
            
            //         response.assignments =
            //             new List<AssignmentViewWrapper>();
            
            //         for (FEC_Assignment__c assignment : assignments) {
                
                //             AssignmentViewWrapper wrapper =
                //                 new AssignmentViewWrapper();
                
                //             wrapper.id =
                //                 assignment.Id;
                
                //             wrapper.assignmentId =
                //                 assignment.Name;
                
                //             wrapper.assignmentType =
                //                 assignment.FEC_Assignment_Type__c;
                
                //             wrapper.assignmentName =
                //                 assignment.FEC_Assignment_Name__c;
                
                //             wrapper.assignmentStatus =
                //                 assignment.FEC_Assignment_Status__c;
                
                //             wrapper.user =
                //                 assignment.CreatedBy != null
                //                 ? assignment.CreatedBy.Email
                //                 : '';
                
                //             wrapper.userRole =
                //                 assignment.CreatedBy != null &&
                //                 assignment.CreatedBy.UserRole != null
                //                 ? assignment.CreatedBy.UserRole.Name
                //                 : 'No Role Assigned';
                
                //             wrapper.latestModifiedDateTime =
                //                 assignment.CreatedDate;
                
                //             if (latestRemarkMap.containsKey(
                //                 assignment.Id
                //             )) {
                    
                    //                 wrapper.stageName =
                    //                     latestRemarkMap.get(
                    //                     assignment.Id
                    //                     ).FEC_Stage_Name__c;
                //             }
                
                //             response.assignments.add(wrapper);
            //         }
            
            //         return response;
            
        //     } catch (Exception e) {
            
            //         System.debug(
            //             LoggingLevel.ERROR,
            //         'getAssignmentsForView error: ' +
            //             e.getMessage()
            //             );
            
            //         throw new AuraHandledException(
            //             System.Label.FEC_MSG_LOAD_ASSIGNMENT_FAILED
            //             );
        //     }
    // }
    
    @AuraEnabled
    public static Integer countAssignments(String caseId) {
        
        return [
        SELECT COUNT()
        FROM FEC_Assignment__c
        WHERE FEC_Case__c = :caseId
    ];
    }
    
    // public class SelectOptionWrapper {
        //     @AuraEnabled public String label;
        //     @AuraEnabled public String value;
        
        //     public SelectOptionWrapper(String value, String label) {
            //         this.value = value;
            //         this.label = label;
        //     }
    // }
    
    
    @AuraEnabled
    public static List<SelectOptionWrapper> getTeamForRouteToAction(
    String caseId, String assignmentId) {
        List<SelectOptionWrapper> teamOptions = new List<SelectOptionWrapper>();
        
        List<Case> cases = [
            SELECT Id, FEC_Business_Process__c, FEC_Stage_Name__c FROM Case WHERE Id = : caseId LIMIT 1
        ];
        
        Case caseRecord = cases.isEmpty() ? null : cases[0];
        
        if (caseRecord == null) {
            return teamOptions;
        }
        /*
         * Detect user department
         */
        String userDepart;
        
        if (isCSSupport()) {
            userDepart = FEC_ConstantCommon.TEAM_CS_SUPPORT;
            
        } else if (isCSCustomerCare()) {
            userDepart = FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE;
            
        } else {
            userDepart = FEC_ConstantCommon.TEAM_OTHER;
        }
        
        System.debug('=== User department: ' + userDepart);
        
        /*
         * OTHER DEPT
         */
        if (userDepart == FEC_ConstantCommon.TEAM_OTHER) {
            if (caseRecord != null
            && String.isNotBlank(caseRecord.FEC_Stage_Name__c)) {
                /*
                 * GSR
                 * Route về CS Support
                 */
                if (caseRecord.FEC_Stage_Name__c.contains(
                FEC_ConstantCommon.BP_GSR)) {
                    TeamWrapper team = getTeamByName(FEC_ConstantCommon.TEAM_CODE_SP);
                    
                    if (team != null) {
                        teamOptions.add(new SelectOptionWrapper(team.teamId, team.teamName));
                    }
                }
                
                /*
                 * COF
                 * Route về CS Customer Care
                 */
                else if (caseRecord.FEC_Stage_Name__c.contains(
                FEC_ConstantCommon.BP_COF)) {
                    TeamWrapper team = getTeamByName(FEC_ConstantCommon.TEAM_CODE_CC);
                    
                    if (team != null) {
                        teamOptions.add(new SelectOptionWrapper(team.teamId, team.teamName));
                    }
                }
            }
        }
        
        /*
         * CS Support / CS Customer Care
         */
        else if (userDepart == FEC_ConstantCommon.TEAM_CS_SUPPORT || userDepart == FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE) {
            /*
             * Case owner
             */
            Case currentCase = [SELECT Id, OwnerId FROM Case WHERE Id = : caseId LIMIT 1];
            
            /*
             * Current login user queues
             */
            Set<Id> currentUserQueueIds =
                getCurrentUserQueueIds(UserInfo.getUserId());
            
            System.debug(
                'currentUserQueueIds = ' +
                JSON.serializePretty(currentUserQueueIds)
                );
            
            Set<Id> caseOwnerQueueIds = new Set<Id>();
            
            /*
             * Case owner = Queue
             */
            if (
                String.valueOf(currentCase.OwnerId)
                .startsWith(FEC_ConstantCommon.QUEUE_ID_START)
            ) {
                
                caseOwnerQueueIds.add(currentCase.OwnerId);
            }
            
            /*
             * Case owner = User
             */
            else {
                
                caseOwnerQueueIds =
                    getCurrentUserQueueIds(currentCase.OwnerId);
            }
            
            System.debug(
                'caseOwnerQueueIds = ' +
                JSON.serializePretty(caseOwnerQueueIds)
                );
            
            /*
             * Check same queue
             */
            Boolean sameQueue = false;
            
            for (Id qId : currentUserQueueIds) {
                
                if (caseOwnerQueueIds.contains(qId)) {
                    
                    sameQueue = true;
                    break;
                }
            }
            
            System.debug('sameQueue = ' + sameQueue);
            
            /*
             * Different queue
             * => Cross routing
             */
            if (!sameQueue) {
                /*
                 * Current user = CC
                 * => route to SP
                 */
                if (userDepart == FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE) {
                    TeamWrapper team = getTeamByName(FEC_ConstantCommon.TEAM_CODE_SP);
                    
                    if (team != null) {
                        teamOptions.add(new SelectOptionWrapper(team.teamId, team.teamName));
                    }
                }
                
                /*
                 * Current user = SP
                 * => route to CC
                 */
                else if (userDepart == FEC_ConstantCommon.TEAM_CS_SUPPORT) {
                    TeamWrapper team = getTeamByName(FEC_ConstantCommon.TEAM_CODE_CC);
                    
                    if (team != null) {
                        teamOptions.add(new SelectOptionWrapper(team.teamId, team.teamName));
                    }
                }
            }
            /*
             * Same queue
             * => Original processing team
             */
            else {
                TeamWrapper team = getFirstTeamProcessOfAssignment(assignmentId);
                
                if (team != null) {
                    teamOptions.add(new SelectOptionWrapper(team.teamId, team.teamName));
                }
            }
        }
        
        return teamOptions;
    }
    
    
    
    
    
    @AuraEnabled
    public static List<SelectOptionWrapper> getQueueForRouteToAction(
    String caseId, String assignmentId) {
        List<SelectOptionWrapper> queueOptions = new List<SelectOptionWrapper>();
        
        List<Case> cases = [
    SELECT Id, FEC_Business_Process__c, FEC_Stage_Name__c,
    OwnerId FROM Case WHERE Id = : caseId LIMIT 1
  ];
        
        Case caseRecord = cases.isEmpty() ? null : cases[0];
        if (caseRecord == null) {
            return queueOptions;
        }
        /*
         * Detect user department
         */
        String userDepart;
        
        if (isCSSupport()) {
            userDepart = FEC_ConstantCommon.TEAM_CS_SUPPORT;
            
        } else if (isCSCustomerCare()) {
            userDepart = FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE;
            
        } else {
            userDepart = FEC_ConstantCommon.TEAM_OTHER;
        }
        
        System.debug('=== User department: ' + userDepart);
        
        /*
         * OTHER DEPT
         */
        if (userDepart == FEC_ConstantCommon.TEAM_OTHER) {
            if (caseRecord != null && String.isNotBlank(caseRecord.FEC_Stage_Name__c)) {
                /*
                 * GSR
                 * Route về CS Support
                 */
                if (caseRecord.FEC_Stage_Name__c.contains(FEC_ConstantCommon.BP_GSR)) {
                    queueOptions = getQueueByName(FEC_ConstantCommon.QUEUE_CS_SUPPORT_W_SPACE);
                }
                
                /*
                 * COF
                 * Route về CS Customer Care
                 */
                else if (caseRecord.FEC_Stage_Name__c.contains(
                FEC_ConstantCommon.BP_COF)) {
                    queueOptions = getQueueByName(FEC_ConstantCommon.QUEUE_CS_CUSTOMER_CARE_W_SPACE);
                }
            }
        }
        
        /*
         * CS Support / CS Customer Care
         */
        else if (userDepart == FEC_ConstantCommon.TEAM_CS_SUPPORT || userDepart == FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE) {
            
            /*
             * Case owner
             */
            Case currentCase = [SELECT Id, OwnerId FROM Case WHERE Id = : caseId LIMIT 1];
            /*
             * Current login user queues
             */
            Set<Id> currentUserQueueIds =
                getCurrentUserQueueIds(UserInfo.getUserId());
            
            System.debug(
                'currentUserQueueIds = ' +
                JSON.serializePretty(currentUserQueueIds)
                );
            
            Set<Id> caseOwnerQueueIds = new Set<Id>();
            
            /*
             * Case owner = Queue
             */
            if (
                String.valueOf(currentCase.OwnerId)
                .startsWith(FEC_ConstantCommon.QUEUE_ID_START)
            ) {
                
                caseOwnerQueueIds.add(currentCase.OwnerId);
            }
            
            /*
             * Case owner = User
             */
            else {
                
                caseOwnerQueueIds =
                    getCurrentUserQueueIds(currentCase.OwnerId);
            }
            
            System.debug(
                'caseOwnerQueueIds = ' +
                JSON.serializePretty(caseOwnerQueueIds)
                );
            
            /*
             * Check same queue
             */
            Boolean sameQueue = false;
            
            for (Id qId : currentUserQueueIds) {
                
                if (caseOwnerQueueIds.contains(qId)) {
                    
                    sameQueue = true;
                    break;
                }
            }
            
            System.debug('sameQueue = ' + sameQueue);
            
            /*
             * Different queue
             * => Cross routing
             */
            if (!sameQueue) {
                /*
                 * Current user = CC
                 * => fixed queue:
                 * DQ - CS Support
                 */
                if (userDepart == FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE) {
                    queueOptions = getQueueByName(FEC_ConstantCommon.QUEUE_CS_SUPPORT_W_SPACE);
                }
                
                /*
                 * Current user = SP
                 * => fixed queue:
                 * DQ - CS Customer Care
                 */
                else if (userDepart == FEC_ConstantCommon.TEAM_CS_SUPPORT) {
                    queueOptions = getQueueByName(FEC_ConstantCommon.QUEUE_CS_CUSTOMER_CARE_W_SPACE);
                }
            }
            
            /*
             * Same queue
             * => Original processing team
             */
            else {
                TeamWrapper team = getFirstTeamProcessOfAssignment(assignmentId);
                
                if (team != null) {
                    queueOptions = getQueueBelongToTeam(team.teamName);
                }
            }
        }
        
        return queueOptions;
    }
    //Hieutt74: [Update 20/5/2026]
    
    
    private static TeamWrapper getFirstTeamProcessOfAssignment(
        String assignmentId
    ) {
        
        System.debug('test get first team hieutt');
        
        List<FEC_Routing_Action_History__c> assignmentRoutingHistory = [
            SELECT
                Id,
                FEC_Assignment__c,
                FEC_Assignment__r.Name,
                FEC_Original_User_Queue__c,
                FEC_Original_User_Queue_ID__c,
                CreatedDate,
                FEC_Routing_Action_Type__c
            FROM FEC_Routing_Action_History__c
            WHERE
                FEC_Assignment__r.Name = :assignmentId
                AND FEC_Routing_Action_Type__c = 'Assignment'
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        
        if (assignmentRoutingHistory.isEmpty()) {
            return null;
        }
        
        FEC_Routing_Action_History__c firstAction =
            assignmentRoutingHistory[0];
        
        String originalUserQueueName =
            firstAction.FEC_Original_User_Queue__c;
        
        TeamWrapper team;
        
        if (
            String.isNotBlank(originalUserQueueName)
        ) {
            
            team = getTeamByQueueName(
                originalUserQueueName
                );
            
            System.debug(
                '=== Team from Queue === ' +
                JSON.serialize(team)
                );
        }
        
        return team;
    }
    
    /*
     * Get business queue names theo:
     * - Direct User
     * - User Role
     */
    private static List<String>
        getQueueNamesByUserOrRoleId(
        String userId
    ) {
        
        /*
         * User
         */
        User u = [
        SELECT
            Id,
            UserRoleId
        FROM User
        WHERE Id = :userId
        LIMIT 1
    ];
        
        /*
         * Member ids:
         * - User Id
         * - Role Group Ids
         */
        Set<Id> memberIds = new Set<Id>();
        
        /*
         * Direct user
         */
        memberIds.add(u.Id);
        
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
                memberIds.add(g.Id);
            }
        }
        
        /*
         * Find queues
         */
        List<GroupMember> groupMembers = [
        SELECT
            Group.Id,
            Group.Name,
            Group.DeveloperName,
            Group.Type,
            UserOrGroupId
        FROM GroupMember
        WHERE
            UserOrGroupId IN :memberIds
            AND Group.Type =:FEC_ConstantCommon.GROUP_TYPE_QUEUE
    ];
        
        /*
         * Queue names
         */
        List<String> queueNames =
            new List<String>();
        
        for (GroupMember gm : groupMembers) {
            
            /*
             * Only business queues
             */
            if (
                gm.Group.DeveloperName != null
                &&
                (
                gm.Group.DeveloperName
                .startsWith(FEC_ConstantCommon.QUEUE_DEVELOPER_PREFIX_FEC_DQ)
                ||
                gm.Group.DeveloperName
                .contains(FEC_ConstantCommon.QUEUE_DEVELOPER_CONTAINS_CS)
                )
            ) {
                
                queueNames.add(
                    gm.Group.Name
                    );
            }
        }
        
        System.debug(
            '=== queueNames === ' +
            JSON.serializePretty(queueNames)
            );
        
        return queueNames;
    }
    
    private static Boolean
        isUserInQueue(
        List<String> queueNames,
    String targetQueue
    ) {
        
        return
            queueNames != null
            &&
            queueNames.contains(
            targetQueue
            );
    }
    
    public class TeamWrapper {
        
        @AuraEnabled
        public String teamId;
        
        @AuraEnabled
        public String teamName;
        
        public TeamWrapper(String teamId, String teamName) {
            this.teamId = teamId;
            this.teamName = teamName;
        }
    }
    
    private static TeamWrapper getTeamByQueueName(String queueName) {
        List<Group> groups = [
            SELECT Id, Name, DeveloperName,
            Type FROM Group WHERE Name = : queueName AND Group.Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
        ];
        
        String queueDevName = null;
        if (!groups.isEmpty()) {
            queueDevName = groups[0].DeveloperName;
        }
        
        // Get team by queue name
        List<FEC_Team_Queue__c> teamQueues = [
            SELECT Id, FEC_Select_Team__r.Id,
            FEC_Select_Team__r.Name FROM FEC_Team_Queue__c 
            WHERE FEC_Queue_Name__c = : queueDevName LIMIT 1
        ];
        
        if (!teamQueues.isEmpty()) {
            FEC_Team_Queue__c teamQueue = teamQueues[0];
            
            return new TeamWrapper(String.valueOf(teamQueue.FEC_Select_Team__r.Id),
            teamQueue.FEC_Select_Team__r.Name);
        }
        
        return null;
    }
    
    private static TeamWrapper getTeamByName(String  teamName) {
        
        // Get team by queue name
        List<FEC_Team__c> teams= [
            SELECT Id,  Name  FROM FEC_Team__c  WHERE Name = :teamName
        ];
        
        if (!teams.isEmpty()) {
            
            FEC_Team__c team = teams[0];
            
            return new TeamWrapper(
                String.valueOf(team.Id),
            team.Name
                );
        }
        
        return null;
    }
    
    
    public static Boolean isCurrentUserInQueue(
        Set<String> queueDeveloperNames
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
        List<Group> queueGroup = [
        SELECT
            Id,
            Name
        FROM Group
        WHERE
            Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND DeveloperName IN :queueDeveloperNames
        ];
        
        Set<Id> queueGroupIds = new Set<Id>();
        
        for (Group g : queueGroup) {
            queueGroupIds.add(g.Id);
        }
        
        
        /*
         * Queue members
         */
        List<GroupMember> members = [
        SELECT
            UserOrGroupId
        FROM GroupMember
        WHERE GroupId IN :queueGroupIds
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
    @AuraEnabled(cacheable=true)
    public static Boolean isCSSupport() {
        
        return isCurrentUserInQueue(
        new Set<String>{
            FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME
        }
        );
    }
    
    @AuraEnabled(cacheable=true)
    public static Boolean isCSCustomerCare() {
        
        return isCurrentUserInQueue(
        new Set<String>{
            FEC_ConstantCommon.QUEUE_DQ_CS_CUSTOMER_CARE_NAME,  FEC_ConstantCommon.QUEUE_DQ_CS_CUSTOMER_CARE_DEPT_NAME
        }
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
                &&
                devName != FEC_ConstantCommon.QUEUE_DQ_CS_CUSTOMER_CARE_DEPT_NAME
                
            ) {
                
                return true;
            }
        }
        
        return false;
    }
    
    public static List<SelectOptionWrapper> getQueueBelongToTeam(String teamName) {
        List<SelectOptionWrapper> queueOptions = new List<SelectOptionWrapper>();
        
        // Get team by queue name
        List<FEC_Team_Queue__c> teamQueues = [
            SELECT
                Id,
                FEC_Select_Team__r.Id,
                FEC_Select_Team__r.Name,
                FEC_Queue_Name__c  
            FROM FEC_Team_Queue__c
            WHERE FEC_Select_Team__r.Name = :teamName
        ];
        
        List<String> queueNames = new List<String>();
        for (FEC_Team_Queue__c teamQueue : teamQueues) {
            queueNames.add(teamQueue.FEC_Queue_Name__c);
        }
        
        if (!queueNames.isEmpty()) {
            List<Group> groups = [
                SELECT Id, Name
                FROM Group
                WHERE DeveloperName IN :queueNames
                AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            ];
            
            for (Group g : groups) {
                queueOptions.add(new SelectOptionWrapper(String.valueOf(g.Id), g.Name));
            }
        }
        
        return queueOptions;
    }
    
    
    public static List<SelectOptionWrapper> getQueueByName(String queueName) {
        List<SelectOptionWrapper> queueOptions = new List<SelectOptionWrapper>();
        
        List<Group> groups = [
                SELECT Id, Name
                FROM Group
                WHERE Name = :queueName
                AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            ];
        
        for (Group g : groups) {
            queueOptions.add(new SelectOptionWrapper(String.valueOf(g.Id), g.Name));
        }
        
        return queueOptions;
    }
    
    
    @AuraEnabled
    public static void saveAssignmentDraft(
        Id assignmentId,
        String remark
    ) {
        if (assignmentId == null) {
            return;
        }
        
        FEC_Assignment__c assignmentRecord = [
        SELECT Id,
               FEC_Draft_Assignment_Remark__c
        FROM FEC_Assignment__c
        WHERE Id = :assignmentId
        LIMIT 1
    ];
        
        assignmentRecord.FEC_Draft_Assignment_Remark__c = remark;
        
        update assignmentRecord;
    }
}