/** tungnm37: Service xu ly COF/GSR Assignment, Routing Action History, Case Remarks. Tach ra tu FEC_CaseBusinessService theo yeu cau review */
public without sharing class FEC_CofGsrAssignmentService {


    private static String emailLocalPart(String email) {
        if (String.isBlank(email)) return null;
        List<String> parts = email.split('@');
        return parts.isEmpty() ? email.trim() : parts[0].trim();
    }

    private static String resolveRoutingHistoryOwnerLabel(Id ownerId, String fallbackName) {
        if (ownerId == null) return fallbackName;
        if (ownerId.getSObjectType() == User.SObjectType) {
            List<User> users = [SELECT Email, Name FROM User WHERE Id = :ownerId LIMIT 1];
            if (users.isEmpty()) return fallbackName;
            String local = emailLocalPart(users[0].Email);
            return String.isNotBlank(local) ? local
                : (String.isNotBlank(users[0].Name) ? users[0].Name : fallbackName);
        }
        return fallbackName;
    }


    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getTeamQueueOptions() {
        // tungnm37 thêm: dùng FEC_Select_Team__r.Name (lookup đến FEC_Team__c)
        List<FEC_Team_Queue__c> records = [
            SELECT FEC_Select_Team__r.Name, FEC_Queue_Name__c
            FROM FEC_Team_Queue__c
            ORDER BY FEC_Select_Team__r.Name, FEC_Queue_Name__c
        ];
        
        Set<String> queueDevNames = new Set<String>();
        for (FEC_Team_Queue__c r : records) {
            if (String.isNotBlank(r.FEC_Queue_Name__c)) {
                queueDevNames.add(r.FEC_Queue_Name__c);
            }
        }
        
        Map<String, String> devNameToLabel = new Map<String, String>();
        for (Group g : [SELECT Name, DeveloperName FROM Group WHERE DeveloperName IN :queueDevNames AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE]) {
            devNameToLabel.put(g.DeveloperName, g.Name);
        }
        
        List<Map<String, String>> result = new List<Map<String, String>>();
        for (FEC_Team_Queue__c r : records) {
            String queueLabel = devNameToLabel.containsKey(r.FEC_Queue_Name__c) 
                ? devNameToLabel.get(r.FEC_Queue_Name__c) 
                : r.FEC_Queue_Name__c;
            result.add(new Map<String, String>{
                'teamName' => r.FEC_Select_Team__r?.Name,
                'queueName' => queueLabel
            });
        }
        return result;
    }

    @AuraEnabled
    public static List<Map<String, String>> getRoutingAssignments(String natureOfCaseId, String customerType) {
        if (String.isBlank(natureOfCaseId)) return new List<Map<String, String>>();

        List<FEC_Routing_Assignment__c> records = [
            SELECT FEC_Team__c, FEC_Queue__c, FEC_Customer_Type__c
            FROM FEC_Routing_Assignment__c
            WHERE FEC_Nature_of_Cases__c = :natureOfCaseId
              AND FEC_Team__c != null
              AND FEC_Queue__c != null
              AND FEC_Active__c = true
            ORDER BY FEC_Team__c ASC
        ];

        if (records.isEmpty()) {
            List<FEC_Nature_of_Case__c> srcNoc = [
                SELECT FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
                FROM FEC_Nature_of_Case__c WHERE Id = :natureOfCaseId LIMIT 1
            ];
            if (!srcNoc.isEmpty()) {
                FEC_Nature_of_Case__c src = srcNoc[0];
                List<FEC_Nature_of_Case__c> siblingNocs = [
                    SELECT Id FROM FEC_Nature_of_Case__c
                    WHERE FEC_Business_Process__c = :src.FEC_Business_Process__c
                      AND FEC_Category__c = :src.FEC_Category__c
                      AND FEC_Sub_Category__c = :src.FEC_Sub_Category__c
                      AND FEC_Sub_Code__c = :src.FEC_Sub_Code__c
                      AND Id != :natureOfCaseId
                    LIMIT 20
                ];
                if (!siblingNocs.isEmpty()) {
                    Set<Id> siblingIds = new Map<Id, FEC_Nature_of_Case__c>(siblingNocs).keySet();
                    records = [
                        SELECT FEC_Team__c, FEC_Queue__c, FEC_Customer_Type__c
                        FROM FEC_Routing_Assignment__c
                        WHERE FEC_Nature_of_Cases__c IN :siblingIds
                          AND FEC_Team__c != null AND FEC_Queue__c != null
                          AND FEC_Active__c = true
                        ORDER BY FEC_Team__c ASC
                    ];
                }
            }
        }

        if (records.isEmpty()) {
            List<FEC_Actual_Nature_of_Case__c> actualNocs = [
                SELECT FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
                FROM FEC_Actual_Nature_of_Case__c WHERE Id = :natureOfCaseId LIMIT 1
            ];
            if (!actualNocs.isEmpty()) {
                FEC_Actual_Nature_of_Case__c an = actualNocs[0];
                List<FEC_Nature_of_Case__c> matchNocs = [
                    SELECT Id FROM FEC_Nature_of_Case__c
                    WHERE FEC_Business_Process__c = :an.FEC_Business_Process__c
                      AND FEC_Category__c = :an.FEC_Category__c
                      AND FEC_Sub_Category__c = :an.FEC_Sub_Category__c
                      AND FEC_Sub_Code__c = :an.FEC_Sub_Code__c
                      AND FEC_Active__c = true
                    LIMIT 10
                ];
                if (!matchNocs.isEmpty()) {
                    Set<Id> nocIds = new Map<Id, FEC_Nature_of_Case__c>(matchNocs).keySet();
                    records = [
                        SELECT FEC_Team__c, FEC_Queue__c, FEC_Customer_Type__c
                        FROM FEC_Routing_Assignment__c
                        WHERE FEC_Nature_of_Cases__c IN :nocIds
                          AND FEC_Active__c = true
                          AND FEC_Team__c != null AND FEC_Queue__c != null
                        ORDER BY FEC_Team__c ASC
                    ];
                }
            }
        }

        List<Map<String, String>> result = new List<Map<String, String>>();
        for (FEC_Routing_Assignment__c r : records) {
            result.add(new Map<String, String>{
                'team' => r.FEC_Team__c,
                'queue' => r.FEC_Queue__c
            });
        }
        return result;
    }

    // tungnm37 fix: check xem NOC có team nào khác CC/SP không
    // true → có team khác → luồng tự động; false → chỉ CC/SP → luồng thủ công
    public static Boolean hasNonCcSpTeam(Set<Id> nocIds) {
        if (nocIds == null || nocIds.isEmpty()) return false;
        List<FEC_Routing_Assignment__c> teams = [
            SELECT FEC_Team__c FROM FEC_Routing_Assignment__c
            WHERE FEC_Nature_of_Cases__c IN :nocIds
              AND FEC_Team__c != null
              AND FEC_Active__c = true
        ];
        for (FEC_Routing_Assignment__c ra : teams) {
            if (!'CC'.equals(ra.FEC_Team__c) && !'SP'.equals(ra.FEC_Team__c)) {
                return true;
            }
        }
        return false;
    }

    public static void createAssignmentsOnRoute(
        String caseId, Set<Id> nocIds, User currentUser, Id historyId,
        String stageName, String remarkContentParam
    ) {
        try {
            System.debug('FEC_DEBUG createAssignmentsOnRoute caseId=' + caseId + ' nocIds=' + nocIds);
            if (nocIds == null || nocIds.isEmpty() || String.isBlank(caseId)) return;

            List<FEC_Routing_Assignment__c> routingAssignments = [
                SELECT FEC_Team__c, FEC_Queue__c
                FROM FEC_Routing_Assignment__c
                WHERE FEC_Nature_of_Cases__c IN :nocIds
                  AND FEC_Team__c != null AND FEC_Queue__c != null
                  AND FEC_Active__c = true
                ORDER BY FEC_Team__c ASC
            ];
            if (routingAssignments.isEmpty()) return;

            Set<String> queueNames = new Set<String>();
            for (FEC_Routing_Assignment__c ra : routingAssignments) {
                if (String.isNotBlank(ra.FEC_Queue__c)) queueNames.add(ra.FEC_Queue__c);
            }
            Map<String, Id> queueNameToId = new Map<String, Id>();
            for (Group g : [SELECT Id, Name FROM Group WHERE Name IN :queueNames AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE]) {
                queueNameToId.put(g.Name, g.Id);
            }

            String remarkContent = remarkContentParam;
            String remarkUserEmail = currentUser.Email;
            if (String.isBlank(remarkContent)) {
                List<FEC_Case_Remarks__c> latestRemarks = [
                    SELECT Id, FEC_Case_Remarks__c, FEC_User__c
                    FROM FEC_Case_Remarks__c
                    WHERE FEC_Case__c = :caseId AND FEC_Remark_Type__c != :FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT
                    ORDER BY CreatedDate DESC LIMIT 1
                ];
                remarkContent = latestRemarks.isEmpty() ? '' : latestRemarks[0].FEC_Case_Remarks__c;
                remarkUserEmail = latestRemarks.isEmpty() ? currentUser.Email : latestRemarks[0].FEC_User__c;
            }

            Case currentCase = [
                SELECT Id, OwnerId, Owner.Name, Owner.Type, FEC_Final_Status__c, FEC_Current_Case_Stage__c
                FROM Case WHERE Id = :caseId LIMIT 1
            ];
            String originalOwnerLabel = resolveRoutingHistoryOwnerLabel(
                currentCase.OwnerId, currentCase.Owner?.Name
            );
            String userRoleName = currentUser.UserRole?.Name;

            List<FEC_Assignment__c> assignments = new List<FEC_Assignment__c>();
            for (FEC_Routing_Assignment__c ra : routingAssignments) {
                String queueId = queueNameToId.containsKey(ra.FEC_Queue__c)
                    ? String.valueOf(queueNameToId.get(ra.FEC_Queue__c)) : null;
                assignments.add(new FEC_Assignment__c(
                    FEC_Case__c = caseId,
                    FEC_Assignment_Name__c = FEC_ConstantCommon.ASSIGNMENT_NAME_ROUTING,
                    FEC_Assignment_Type__c = FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING,
                    //tungnm37: set status theo team thay vi hardcode Open
                    FEC_Assignment_Status__c = resolveAssignmentStatus(ra.FEC_Team__c),
                    FEC_OwnerID__c = ra.FEC_Queue__c, // tungnm37 sửa: lưu Queue Name để formula FEC_Assignment_Owner_Text__c hiện đúng
                    FEC_Assignment_Owner__c = null,
                    FEC_Team__c = ra.FEC_Team__c,
                    FEC_Assignment_Remark__c = remarkContent,
                    FEC_User_Role__c = userRoleName,
                    FEC_Assignment_Routing_Action__c = stageName,
                    FEC_Manual__c = false
                ));
            }
            insert assignments;

            Datetime assignmentSubmitTs = System.now();
            List<FEC_Assignment__c> submitStamp = new List<FEC_Assignment__c>();
            for (FEC_Assignment__c a : assignments) {
                submitStamp.add(new FEC_Assignment__c(
                    Id = a.Id,
                    FEC_Submitted_On__c = assignmentSubmitTs
                ));
            }
            if (!submitStamp.isEmpty()) {
                update submitStamp;
            }

            // tungnm37: lưu Queue Id vào Case.FEC_Assignment_Users__c để FEC_AssignmentExecuteService check quyền
            // tungnm37: User → lưu User Id; Queue → lưu Queue Id (lookup từ queueNameToId)
            List<String> assignmentUsers = resolveAssignmentUsers(assignments, queueNameToId);
            if (!assignmentUsers.isEmpty()) {
                try {
                    FEC_CaseTriggerHandler.isSystemUpdate = true; // tungnm37: đánh dấu đây là system update
                    Database.SaveResult sr = Database.update(new Case(
                        Id = caseId, 
                        FEC_Assignment_Users__c = String.join(assignmentUsers, ',')
                    ), AccessLevel.SYSTEM_MODE);
                    if (!sr.isSuccess()) {
                        for (Database.Error err : sr.getErrors()) {
                            System.debug('FEC_DEBUG update Case error: ' + err.getStatusCode() + ' - ' + err.getMessage() + ' - Fields: ' + err.getFields());
                        }
                    } else {
                        System.debug('FEC_DEBUG update Case success: FEC_Assignment_Users__c = ' + String.join(assignmentUsers, ','));
                    }
                } catch (Exception eu) {
                    System.debug('FEC_DEBUG update FEC_Assignment_Users__c error: ' + eu.getMessage());
                    System.debug('FEC_DEBUG Stack trace: ' + eu.getStackTraceString());
                } finally {
                    FEC_CaseTriggerHandler.isSystemUpdate = false;
                }
            }

            List<FEC_Case_Remarks__c> remarksToInsert = new List<FEC_Case_Remarks__c>();
            for (FEC_Assignment__c a : assignments) {
                remarksToInsert.add(new FEC_Case_Remarks__c(
                    FEC_Case__c = caseId,
                    FEC_Remark_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
                    FEC_Case_Remarks__c = remarkContent,
                    FEC_User__c = emailLocalPart(remarkUserEmail), // tungnm37 sửa: lấy phần trước @
                    FEC_User_Role__c = userRoleName, // tungnm37 fix: thêm User Role
                    FEC_Assignment__c = a.Id,
                    FEC_Stage_Name__c = stageName
                ));
            }
            if (!remarksToInsert.isEmpty()) insert remarksToInsert;

            List<FEC_Routing_Action_History__c> histories = new List<FEC_Routing_Action_History__c>();
            for (FEC_Assignment__c a : assignments) {
                // tungnm37 fix: FEC_OwnerID__c lưu Queue Name, cần lookup trực tiếp từ queueNameToId
                String queueName = a.FEC_OwnerID__c; // đây là Queue Name
                String queueId = queueNameToId.containsKey(queueName) 
                    ? String.valueOf(queueNameToId.get(queueName)) : null;
                histories.add(new FEC_Routing_Action_History__c(
                    FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
                    FEC_Case__c = caseId,
                    FEC_Assignment__c = a.Id,
                    FEC_Perform_User__c = currentUser.Id,
                    FEC_User__c = emailLocalPart(currentUser.Email),
                    FEC_User_Role__c = userRoleName,
                    FEC_Stage_Name__c = stageName,
                    FEC_Previous_Stage__c = currentCase.FEC_Current_Case_Stage__c,
                    FEC_Original_User_Queue__c = originalOwnerLabel,
                    FEC_Original_User_Queue_ID__c = currentCase.OwnerId != null ? String.valueOf(currentCase.OwnerId) : null,
                    FEC_Updated_User_Queue__c = queueName,
                    FEC_Updated_User_Queue_ID__c = queueId,
                    FEC_Current_Status__c = currentCase.FEC_Final_Status__c,
                    FEC_Submitted_On__c = DateTime.now()
                ));
            }
            if (!histories.isEmpty()) {
                Database.insert(histories);
            }
        } catch (Exception e) {
            System.debug('FEC_DEBUG createAssignmentsOnRoute error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            FEC_CommonUltils.logException('tungnm37', 'createAssignmentsOnRoute', e.getMessage(), e.getStackTraceString());
        }
    }

    public static void createAssignmentsFromManualItems(
        String caseId, String manualItemsJson, User currentUser, String stageName
    ) {
        try {
            List<Object> rawItems = (List<Object>) JSON.deserializeUntyped(manualItemsJson);
            if (rawItems == null || rawItems.isEmpty()) return;

            Set<String> queueNames = new Set<String>();
            for (Object raw : rawItems) {
                Map<String, Object> item = (Map<String, Object>) raw;
                String qn = (String) item.get('queueName');
                if (String.isNotBlank(qn)) queueNames.add(qn);
            }
            Map<String, Id> queueNameToId = new Map<String, Id>();
            Map<String, String> queueDevNameToDisplayName = new Map<String, String>(); // tungnm37: DeveloperName → display name
            // tungnm37 fix: query theo cả Name và DeveloperName để tìm được Queue Id
            for (Group g : [SELECT Id, Name, DeveloperName FROM Group WHERE (Name IN :queueNames OR DeveloperName IN :queueNames) AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE]) {
                queueNameToId.put(g.DeveloperName, g.Id);
                queueNameToId.put(g.Name, g.Id); // tungnm37: thêm map Name → Id để resolveAssignmentUsers tìm được ID
                queueDevNameToDisplayName.put(g.DeveloperName, g.Name); 
                queueDevNameToDisplayName.put(g.Name, g.Name);
            }

            String userRoleName = currentUser.UserRole?.Name;
            Case currentCase = [
                SELECT Id, OwnerId, Owner.Name, Owner.Type, FEC_Final_Status__c, FEC_Current_Case_Stage__c
                FROM Case WHERE Id = :caseId LIMIT 1
            ];
            // tungnm37 fix: Stage 1 manual → Original = currentUser (người đang submit), không phải Case owner
            // Stage 2 manual → Original = Case owner hiện tại (queue/user đang giữ case)
            Boolean isStage1Check = stageName != null && Pattern.matches('(?i).*stage\\s*1.*', stageName);
            String originalOwnerLabel = isStage1Check
                ? emailLocalPart(currentUser.Email)
                : resolveRoutingHistoryOwnerLabel(currentCase.OwnerId, currentCase.Owner?.Name);
            String originalOwnerIdStr = isStage1Check
                ? String.valueOf(currentUser.Id)
                : (currentCase.OwnerId != null ? String.valueOf(currentCase.OwnerId) : null);

            List<FEC_Assignment__c> assignments = new List<FEC_Assignment__c>();
            List<String> remarkList = new List<String>();
            List<String> queueNameList = new List<String>(); // tungnm37: lưu queueName để dùng cho history
            for (Object raw : rawItems) {
                Map<String, Object> item = (Map<String, Object>) raw;
                String teamName = (String) item.get('teamName');
                String queueName = (String) item.get('queueName');
                String remark = (String) item.get('remark');
                String queueId = queueNameToId.containsKey(queueName)
                    ? String.valueOf(queueNameToId.get(queueName)) : null;
                assignments.add(new FEC_Assignment__c(
                    FEC_Case__c = caseId,
                    FEC_Assignment_Name__c = FEC_ConstantCommon.ASSIGNMENT_NAME_ROUTING,
                    FEC_Assignment_Type__c = FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING,
                    //tungnm37: set status theo team thay vi hardcode Open
                    FEC_Assignment_Status__c = resolveAssignmentStatus(teamName),
                    FEC_OwnerID__c = queueDevNameToDisplayName.containsKey(queueName) ? queueDevNameToDisplayName.get(queueName) : queueName, // tungnm37 sửa: lưu Queue Name
                    FEC_Assignment_Owner__c = null,
                    FEC_Team__c = teamName,
                    FEC_Assignment_Remark__c = remark,
                    FEC_User_Role__c = userRoleName,
                    FEC_Assignment_Routing_Action__c = stageName,
                    FEC_Manual__c = true
                ));
                remarkList.add(remark);
                queueNameList.add(queueDevNameToDisplayName.containsKey(queueName) ? queueDevNameToDisplayName.get(queueName) : queueName); // tungnm37: lưu display name cho history
            }
            insert assignments;

            Datetime manualSubmitTs = System.now();
            List<FEC_Assignment__c> manualSubmitStamp = new List<FEC_Assignment__c>();
            for (FEC_Assignment__c a : assignments) {
                manualSubmitStamp.add(new FEC_Assignment__c(
                    Id = a.Id,
                    FEC_Submitted_On__c = manualSubmitTs
                ));
            }
            if (!manualSubmitStamp.isEmpty()) {
                update manualSubmitStamp;
            }

            // tungnm37: lưu owner ids vào Case.FEC_Assignment_Users__c, queue thì lưu Queue Id, user thì lưu User Id
            // tungnm37: KHÔNG set OwnerId = null vì Salesforce không cho phép (INVALID_CROSS_REFERENCE_KEY)
            // tungnm37: Chỉ dùng FEC_Assignment_Users__c để track assignments
            // tungnm37: FEC_Service_Case_Owner__c sẽ tự động ẩn giá trị khi có assignment (formula field)
            // tungnm37: Chỉ set FEC_Assignment_Users__c từ Stage 2 trở đi (không set ở Stage 1 để Service Case Owner vẫn hiển thị)
            Boolean isStage1 = stageName != null && Pattern.matches('(?i).*stage\\s*1.*', stageName);
            List<String> assignmentUsers = resolveAssignmentUsers(assignments, queueNameToId);
            if (!assignmentUsers.isEmpty() && !isStage1) {
                try {
                    FEC_CaseTriggerHandler.isSystemUpdate = true; // tungnm37: đánh dấu đây là system update
                    Database.SaveResult sr = Database.update(new Case(
                        Id = caseId, 
                        FEC_Assignment_Users__c = String.join(assignmentUsers, ',')
                    ), AccessLevel.SYSTEM_MODE);
                    if (!sr.isSuccess()) {
                        for (Database.Error err : sr.getErrors()) {
                            System.debug('FEC_DEBUG update Case (manual) error: ' + err.getStatusCode() + ' - ' + err.getMessage() + ' - Fields: ' + err.getFields());
                        }
                    } else {
                        System.debug('FEC_DEBUG update Case (manual) success: FEC_Assignment_Users__c = ' + String.join(assignmentUsers, ','));
                    }
                } catch (Exception eu) {
                    System.debug('FEC_DEBUG update FEC_Assignment_Users__c (manual) error: ' + eu.getMessage());
                    System.debug('FEC_DEBUG Stack trace: ' + eu.getStackTraceString());
                } finally {
                    FEC_CaseTriggerHandler.isSystemUpdate = false;
                }
            }

            List<FEC_Case_Remarks__c> remarks = new List<FEC_Case_Remarks__c>();
            for (Integer i = 0; i < assignments.size(); i++) {
                remarks.add(new FEC_Case_Remarks__c(
                    FEC_Case__c = caseId,
                    FEC_Remark_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
                    FEC_Case_Remarks__c = remarkList[i],
                    FEC_User__c = emailLocalPart(currentUser.Email), // tungnm37 sửa: lấy phần trước @
                    FEC_User_Role__c = userRoleName, // tungnm37 fix: thêm User Role
                    FEC_Assignment__c = assignments[i].Id,
                    FEC_Stage_Name__c = stageName
                ));
            }
            if (!remarks.isEmpty()) insert remarks;

            List<FEC_Routing_Action_History__c> histories = new List<FEC_Routing_Action_History__c>();
            for (Integer i = 0; i < assignments.size(); i++) {
                FEC_Assignment__c a = assignments[i];
                String queueName = queueNameList[i]; // tungnm37: lấy trực tiếp từ list, không reverse lookup
                histories.add(new FEC_Routing_Action_History__c(
                    FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
                    FEC_Case__c = caseId,
                    FEC_Assignment__c = a.Id,
                    FEC_Perform_User__c = currentUser.Id,
                    FEC_User__c = emailLocalPart(currentUser.Email),
                    FEC_User_Role__c = userRoleName,
                    FEC_Stage_Name__c = stageName,
                    FEC_Previous_Stage__c = currentCase.FEC_Current_Case_Stage__c,
                    FEC_Original_User_Queue__c = originalOwnerLabel,
                    FEC_Original_User_Queue_ID__c = originalOwnerIdStr,
                    FEC_Updated_User_Queue__c = queueName,
                    FEC_Updated_User_Queue_ID__c = a.FEC_OwnerID__c,
                    FEC_Current_Status__c = currentCase.FEC_Final_Status__c,
                    FEC_Submitted_On__c = DateTime.now()
                ));
            }
            if (!histories.isEmpty()) {
                Database.insert(histories);
            }
        } catch (Exception e) {
            System.debug('createAssignmentsFromManualItems error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            FEC_CommonUltils.logException('tungnm37', 'createAssignmentsFromManualItems', e.getMessage(), e.getStackTraceString());
        }
    }

    //tungnm37: Resolve Assignment Status theo team code
    //tungnm37: SP/CC → CSBackOfficeReview; CS khac (IB/EC/OB/QC/OM/F2F/CA/CL/CX) → CSReview
    //tungnm37: Other Dept (CO/PM/CP/DS/IA/IT/TS) → OtherDeptReview; con lai → Open
    private static String resolveAssignmentStatus(String teamCode) {
        if (String.isBlank(teamCode)) return FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN;
        if (FEC_ConstantCommon.CS_BACKOFFICE_TEAMS.contains(teamCode)) {
            return FEC_ConstantCommon.STATUS_CS_BACKOFFICE;
        }
        if (FEC_ConstantCommon.CS_REVIEW_TEAMS.contains(teamCode)) {
            return FEC_ConstantCommon.STATUS_CS_REVIEW;
        }
        if (FEC_ConstantCommon.OTHER_DEPT_TEAMS.contains(teamCode)) {
            return FEC_ConstantCommon.STATUS_OTHER_DEPT;
        }
        return FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN;
    }

    // tungnm37 fix: lưu Queue Name cho queue (để hiển thị listview), User Id cho user
    // FEC_AssignmentExecuteService đã được update để hỗ trợ cả Queue Name lẫn Queue Id
    private static List<String> resolveAssignmentUsers(List<FEC_Assignment__c> assignments, Map<String, Id> queueNameToId) {
        List<String> assignmentUsers = new List<String>();
        for (FEC_Assignment__c assignmentItem : assignments) {
            if (assignmentItem.FEC_Assignment_Owner__c != null) {
                // User → lưu User Id
                assignmentUsers.add(String.valueOf(assignmentItem.FEC_Assignment_Owner__c));
                continue;
            }

            if (String.isNotBlank(assignmentItem.FEC_OwnerID__c)) {
                // Queue → lưu Queue Name (FEC_OwnerID__c đang lưu Queue Name)
                assignmentUsers.add(assignmentItem.FEC_OwnerID__c);
            }
        }
        return assignmentUsers;
    }

    public static Set<Id> resolveToNocIds(String inputId) {
        Set<Id> result = new Set<Id>();
        if (String.isBlank(inputId)) return result;
        try {
            Id recordId = inputId;
            String objName = recordId.getSObjectType().getDescribe().getName();

            Id bpId; Id catId; Id subCatId; Id subCodeId;

            if (objName == 'FEC_Nature_of_Case__c') {
                List<FEC_Nature_of_Case__c> nocs = [
                    SELECT FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
                    FROM FEC_Nature_of_Case__c WHERE Id = :inputId LIMIT 1
                ];
                if (nocs.isEmpty()) { result.add(recordId); return result; }
                bpId = nocs[0].FEC_Business_Process__c;
                catId = nocs[0].FEC_Category__c;
                subCatId = nocs[0].FEC_Sub_Category__c;
                subCodeId = nocs[0].FEC_Sub_Code__c;
            } else if (objName == 'FEC_Actual_Nature_of_Case__c') {
                List<FEC_Actual_Nature_of_Case__c> actualNocs = [
                    SELECT FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
                    FROM FEC_Actual_Nature_of_Case__c WHERE Id = :inputId LIMIT 1
                ];
                if (actualNocs.isEmpty()) return result;
                bpId = actualNocs[0].FEC_Business_Process__c;
                catId = actualNocs[0].FEC_Category__c;
                subCatId = actualNocs[0].FEC_Sub_Category__c;
                subCodeId = actualNocs[0].FEC_Sub_Code__c;
            } else {
                return result;
            }

            List<FEC_Nature_of_Case__c> matchNocs = [
                SELECT Id FROM FEC_Nature_of_Case__c
                WHERE FEC_Business_Process__c = :bpId
                  AND FEC_Category__c = :catId
                  AND FEC_Sub_Category__c = :subCatId
                  AND FEC_Sub_Code__c = :subCodeId
            ];
            if (matchNocs.isEmpty()) return result;

            Set<Id> allNocIds = new Map<Id, FEC_Nature_of_Case__c>(matchNocs).keySet();

            for (AggregateResult ar : [
                SELECT FEC_Nature_of_Cases__c nocId
                FROM FEC_Routing_Assignment__c
                WHERE FEC_Nature_of_Cases__c IN :allNocIds
                  AND FEC_Team__c != null AND FEC_Queue__c != null
                  AND FEC_Active__c = true
                GROUP BY FEC_Nature_of_Cases__c
            ]) {
                result.add((Id) ar.get('nocId'));
            }

            if (result.isEmpty()) result = allNocIds;
        } catch (Exception e) {
            System.debug('FEC_DEBUG resolveToNocIds error: ' + e.getMessage());
        }
        return result;
    }

    public static Object handleRouteToCofGsr(String caseId, Map<String, Object> params, String stageName) {
        String natureOfCaseId = (String) params.get('natureOfCaseId');
        String manualItemsJson = (String) params.get('manualItemsJson');
        String remarkContent = (String) params.get('remarkContent');

        try { FEC_CaseBusinessService.markCaseSubmittedAndClearDrafts(caseId); } catch (Exception e1) {
            System.debug('markCaseSubmitted error: ' + e1.getMessage());
        }
        if (String.isNotBlank(natureOfCaseId)) {
            try { FEC_CaseBusinessService.saveCaseNOC(caseId, natureOfCaseId); } catch (Exception e2) {
                System.debug('saveCaseNOC error: ' + e2.getMessage());
            }
        }

        User currentUser = [SELECT Email, UserRole.Name, Id, FEC_User_Group__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        if (String.isNotBlank(manualItemsJson)) {
            createAssignmentsFromManualItems(caseId, manualItemsJson, currentUser, stageName);
            return null;
        }

        Set<Id> nocIds = resolveToNocIds(natureOfCaseId);
        String firstTeam = null;
        if (!nocIds.isEmpty()) {
            List<FEC_Routing_Assignment__c> teamCheck = [
                SELECT FEC_Team__c FROM FEC_Routing_Assignment__c
                WHERE FEC_Nature_of_Cases__c IN :nocIds AND FEC_Team__c != null AND FEC_Active__c = true LIMIT 1
            ];
            if (!teamCheck.isEmpty()) firstTeam = teamCheck[0].FEC_Team__c;
        }

        Boolean isCcSpTeam = 'CC'.equals(firstTeam) || 'SP'.equals(firstTeam);
        Id gsrRoutingHistoryId = null;
        if (isCcSpTeam) {
            String targetQueueName = 'CC'.equals(firstTeam)
                ? System.Label.FEC_CC_Queue_Name
                : System.Label.FEC_CS_Support_Queue_Name;
            List<Group> targetQueues = [SELECT Id FROM Group WHERE Name = :targetQueueName AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE LIMIT 1];
            if (!targetQueues.isEmpty()) {
                // tungnm37 fix: query Case TRƯỚC khi đổi owner để lấy đúng originalOwner
                Case caseBeforeUpdate = [
                    SELECT Id, OwnerId, Owner.Name, Owner.Type, FEC_Final_Status__c, FEC_Current_Case_Stage__c
                    FROM Case WHERE Id = :caseId LIMIT 1
                ];
                // tungnm37 fix: Stage 1 → Original = currentUser (người submit), không phải Case owner
                Boolean isStage1ForHistory = stageName != null && Pattern.matches('(?i).*stage\\s*1.*', stageName);
                String originalOwnerLabel = isStage1ForHistory
                    ? emailLocalPart(currentUser.Email)
                    : resolveRoutingHistoryOwnerLabel(caseBeforeUpdate.OwnerId, caseBeforeUpdate.Owner?.Name);
                String originalOwnerIdStr = isStage1ForHistory
                    ? String.valueOf(currentUser.Id)
                    : (caseBeforeUpdate.OwnerId != null ? String.valueOf(caseBeforeUpdate.OwnerId) : null);

                FEC_CaseBusinessService.registerSkipOwnerChangeRoutingHistory(caseId);
                // tungnm37 fix: không set FEC_Assignment_Users__c cho CC/SP team để Service Case Owner vẫn hiển thị
                Database.update(new Case(Id = caseId, OwnerId = targetQueues[0].Id), AccessLevel.SYSTEM_MODE);

                // tungnm37: tạo Routing Action History cho luồng CC/SP
                try {
                    String userRoleName = currentUser.UserRole?.Name;
                    FEC_Routing_Action_History__c gsrHistory = new FEC_Routing_Action_History__c(
                        FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
                        FEC_Case__c = caseId,
                        FEC_Perform_User__c = currentUser.Id,
                        FEC_User__c = emailLocalPart(currentUser.Email),
                        FEC_User_Role__c = userRoleName,
                        FEC_Stage_Name__c = stageName,
                        FEC_Previous_Stage__c = caseBeforeUpdate.FEC_Current_Case_Stage__c,
                        FEC_Original_User_Queue__c = originalOwnerLabel,
                        FEC_Original_User_Queue_ID__c = originalOwnerIdStr,
                        FEC_Updated_User_Queue__c = targetQueueName,
                        FEC_Updated_User_Queue_ID__c = String.valueOf(targetQueues[0].Id),
                        FEC_Current_Status__c = caseBeforeUpdate.FEC_Final_Status__c,
                        FEC_Submitted_On__c = DateTime.now()
                    );
                    Database.insert(gsrHistory, AccessLevel.SYSTEM_MODE);
                    gsrRoutingHistoryId = gsrHistory.Id;
                    // tungnm37 fix: tạo Case Remark cho CC/SP team path
                    if (String.isNotBlank(remarkContent)) {
                        try {
                            insert new FEC_Case_Remarks__c(
                                FEC_Case__c = caseId,
                                FEC_Remark_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
                                FEC_Case_Remarks__c = remarkContent,
                                FEC_User__c = emailLocalPart(currentUser.Email),
                                FEC_Stage_Name__c = stageName
                            );
                        } catch (Exception er) {
                            System.debug('FEC_DEBUG createRemark CC/SP error: ' + er.getMessage());
                        }
                    }
                } catch (Exception eh) {
                    System.debug('FEC_DEBUG createRoutingHistory CC/SP error: ' + eh.getMessage());
                }
            }
            if (!nocIds.isEmpty()) {
                List<FEC_Case_Stage__c> nextStages = [
                    SELECT Id FROM FEC_Case_Stage__c
                    WHERE FEC_Nature_of_Cases__c IN :nocIds
                      AND FEC_Default_Stage__c = false
                      AND FEC_Active__c = true
                    ORDER BY Name ASC LIMIT 1
                ];
                if (!nextStages.isEmpty()) {
                    Database.update(new Case(Id = caseId, FEC_Current_Case_Stage__c = nextStages[0].Id), AccessLevel.SYSTEM_MODE);
                }
            }

            // tungnm37 fix: nếu có team khác CC/SP → tạo assignment tự động cho tất cả team
            if (hasNonCcSpTeam(nocIds)) {
                createAssignmentsOnRoute(caseId, nocIds, currentUser, null, stageName, remarkContent);
                // tungnm37 15/05/2026: chuyển sang stage tiếp theo sau khi tạo assignment tự động
                moveToNextStage(caseId, nocIds);
            }
        } else {
            createAssignmentsOnRoute(caseId, nocIds, currentUser, null, stageName, remarkContent);
            // tungnm37 15/05/2026: chuyển sang stage tiếp theo sau khi tạo assignment tự động
            moveToNextStage(caseId, nocIds);
        }
        if (gsrRoutingHistoryId != null) {
            FEC_AutoHoldCaseService.syncChangedStatusAndEnqueue(gsrRoutingHistoryId);
        } else if (!nocIds.isEmpty()) {
            FEC_AutoHoldCaseService.syncChangedStatusAndEnqueueForCase(caseId);
        }
        return null;
    }

    // tungnm37 15/05/2026: chuyển Case sang stage tiếp theo
    private static void moveToNextStage(String caseId, Set<Id> nocIds) {
        try {
            if (nocIds == null || nocIds.isEmpty()) return;
            List<Case> cases = [SELECT Id, FEC_Current_Case_Stage__c FROM Case WHERE Id = :caseId LIMIT 1];
            if (cases.isEmpty()) return;
            Id currentStageId = cases[0].FEC_Current_Case_Stage__c;

            // tungnm37: lấy stage không phải default (stage 2+) theo NOC
            List<FEC_Case_Stage__c> nextStages = [
                SELECT Id FROM FEC_Case_Stage__c
                WHERE FEC_Nature_of_Cases__c IN :nocIds
                  AND FEC_Default_Stage__c = false
                  AND FEC_Active__c = true
                ORDER BY Name ASC LIMIT 1
            ];
            if (!nextStages.isEmpty() && nextStages[0].Id != currentStageId) {
                FEC_CaseTriggerHandler.isSystemUpdate = true;
                try {
                    Database.update(new Case(Id = caseId, FEC_Current_Case_Stage__c = nextStages[0].Id), AccessLevel.SYSTEM_MODE);
                } finally {
                    FEC_CaseTriggerHandler.isSystemUpdate = false;
                }
            }
        } catch (Exception e) {
            System.debug('FEC_DEBUG moveToNextStage error: ' + e.getMessage());
        }
    }
}