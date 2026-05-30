/** tungnm37: Service xu ly COF/GSR Assignment, Routing Action History, Case Remarks. Tach ra tu FEC_CaseBusinessService theo yeu cau review */
public without sharing class FEC_CofGsrAssignmentService {

    // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
    private static Map<Id, String> txnTeamByQueueIdCache = new Map<Id, String>();
    private static Map<Id, String> txnTeamByUserIdCache = new Map<Id, String>();
    private static Set<String> txnCreatedAssignmentKeys = new Set<String>();

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

    private static String normalizeAssignmentKeyPart(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }

    private static String buildAssignmentDedupKey(
        String caseId,
        String teamName,
        String queueName,
        String stageName,
        Boolean isManual
    ) {
        return String.join(new List<String>{
            normalizeAssignmentKeyPart(caseId),
            normalizeAssignmentKeyPart(teamName),
            normalizeAssignmentKeyPart(queueName),
            normalizeAssignmentKeyPart(stageName),
            String.valueOf(isManual == true)
        }, '|');
    }

    private static Set<String> loadExistingAssignmentDedupKeys(String caseId) {
        Set<String> keys = new Set<String>();
        if (String.isBlank(caseId)) {
            return keys;
        }
        for (FEC_Assignment__c row : [
            SELECT FEC_Case__c, FEC_Team__c, FEC_OwnerID__c, FEC_Assignment_Routing_Action__c, FEC_Manual__c
            FROM FEC_Assignment__c
            WHERE FEC_Case__c = :caseId
        ]) {
            keys.add(buildAssignmentDedupKey(
                String.valueOf(row.FEC_Case__c),
                row.FEC_Team__c,
                row.FEC_OwnerID__c,
                row.FEC_Assignment_Routing_Action__c,
                row.FEC_Manual__c
            ));
        }
        return keys;
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

            //tungnm37 start: resolve team cua Service Case Owner (Queue hoac User) de check cross-team SP<->CC
            String caseOwnerTeam = null;
            if (currentCase.OwnerId != null) {
                if (currentCase.OwnerId.getSObjectType() == Group.SObjectType) {
                    caseOwnerTeam = resolveTeamFromQueueId(currentCase.OwnerId);
                } else if (currentCase.OwnerId.getSObjectType() == User.SObjectType) {
                    caseOwnerTeam = resolveTeamFromUserId(currentCase.OwnerId);
                }
            }
            //tungnm37 end

            Set<String> existingAssignmentKeys = loadExistingAssignmentDedupKeys(caseId);
            List<FEC_Assignment__c> assignments = new List<FEC_Assignment__c>();
            for (FEC_Routing_Assignment__c ra : routingAssignments) {
                String dedupKey = buildAssignmentDedupKey(caseId, ra.FEC_Team__c, ra.FEC_Queue__c, stageName, false);
                if (existingAssignmentKeys.contains(dedupKey) || txnCreatedAssignmentKeys.contains(dedupKey)) {
                    System.debug('FEC_DEBUG skip duplicate auto assignment key=' + dedupKey);
                    continue;
                }
                assignments.add(new FEC_Assignment__c(
                    FEC_Case__c = caseId,
                    FEC_Assignment_Name__c = FEC_ConstantCommon.ASSIGNMENT_NAME_ROUTING,
                    FEC_Assignment_Type__c = FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING,
                    //tungnm37: set status theo team + caseOwnerTeam (tu Case Owner Queue)
                    FEC_Assignment_Status__c = resolveAssignmentStatusWithOwner(ra.FEC_Team__c, caseOwnerTeam),
                    FEC_OwnerID__c = ra.FEC_Queue__c, // tungnm37 sửa: lưu Queue Name để formula FEC_Assignment_Owner_Text__c hiện đúng
                    FEC_Assignment_Owner__c = null,
                    FEC_Team__c = ra.FEC_Team__c,
                    FEC_Assignment_Remark__c = remarkContent,
                    FEC_User_Role__c = userRoleName,
                    FEC_Assignment_Routing_Action__c = stageName,
                    FEC_Manual__c = false
                ));
                existingAssignmentKeys.add(dedupKey);
                txnCreatedAssignmentKeys.add(dedupKey);
            }
            if (assignments.isEmpty()) return;
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

            rebuildAssignmentUsersForCase(caseId);

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

            if (historyId == null) {
                Boolean isStage1Auto = stageName != null && Pattern.matches('(?i).*stage\\s*1.*', stageName);
                List<FEC_Routing_Action_History__c> histories = new List<FEC_Routing_Action_History__c>();
                for (FEC_Assignment__c a : assignments) {
                    // Stage 1 COF/GSR auto cho CC/SP đã có case-level Route to history ở luồng owner change,
                    // nên không tạo thêm assignment-level Route to history cho đúng kỳ vọng chỉ còn 2 dòng history.
                    if (isStage1Auto && ('CC'.equals(a.FEC_Team__c) || 'SP'.equals(a.FEC_Team__c))) {
                        continue;
                    }
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
                        FEC_Original_User_Queue__c = emailLocalPart(currentUser.Email),
                        FEC_Original_User_Queue_ID__c = String.valueOf(currentUser.Id),
                        FEC_Updated_User_Queue__c = queueName,
                        FEC_Updated_User_Queue_ID__c = queueId,
                        FEC_Current_Status__c = currentCase.FEC_Final_Status__c,
                        FEC_Submitted_On__c = DateTime.now()
                    ));
                }
                if (!histories.isEmpty()) {
                    Database.insert(histories, AccessLevel.SYSTEM_MODE);
                }
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

            //tungnm37 start: resolve team cua Service Case Owner (Queue hoac User)
            String caseOwnerTeamManual = null;
            if (currentCase.OwnerId != null) {
                if (currentCase.OwnerId.getSObjectType() == Group.SObjectType) {
                    caseOwnerTeamManual = resolveTeamFromQueueId(currentCase.OwnerId);
                } else if (currentCase.OwnerId.getSObjectType() == User.SObjectType) {
                    caseOwnerTeamManual = resolveTeamFromUserId(currentCase.OwnerId);
                }
            }
            //tungnm37 end

            Set<String> existingAssignmentKeys = loadExistingAssignmentDedupKeys(caseId);
            List<FEC_Assignment__c> assignments = new List<FEC_Assignment__c>();
            List<String> remarkList = new List<String>();
            List<String> queueNameList = new List<String>(); // tungnm37: lưu queueName để dùng cho history
            for (Object raw : rawItems) {
                Map<String, Object> item = (Map<String, Object>) raw;
                String teamName = (String) item.get('teamName');
                String queueName = (String) item.get('queueName');
                String remark = (String) item.get('remark');
                String displayQueueName = queueDevNameToDisplayName.containsKey(queueName) ? queueDevNameToDisplayName.get(queueName) : queueName;
                String dedupKey = buildAssignmentDedupKey(caseId, teamName, displayQueueName, stageName, true);
                if (existingAssignmentKeys.contains(dedupKey) || txnCreatedAssignmentKeys.contains(dedupKey)) {
                    System.debug('FEC_DEBUG skip duplicate manual assignment key=' + dedupKey);
                    continue;
                }
                assignments.add(new FEC_Assignment__c(
                    FEC_Case__c = caseId,
                    FEC_Assignment_Name__c = FEC_ConstantCommon.ASSIGNMENT_NAME_ROUTING,
                    FEC_Assignment_Type__c = FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING,
                    //tungnm37: set status theo team + caseOwnerTeam (tu Case Owner Queue)
                    FEC_Assignment_Status__c = resolveAssignmentStatusWithOwner(teamName, caseOwnerTeamManual),
                    FEC_OwnerID__c = displayQueueName, // tungnm37 sửa: lưu Queue Name
                    FEC_Assignment_Owner__c = null,
                    FEC_Team__c = teamName,
                    FEC_Assignment_Remark__c = remark,
                    FEC_User_Role__c = userRoleName,
                    FEC_Assignment_Routing_Action__c = stageName,
                    FEC_Manual__c = true
                ));
                remarkList.add(remark);
                queueNameList.add(displayQueueName); // tungnm37: lưu display name cho history
                existingAssignmentKeys.add(dedupKey);
                txnCreatedAssignmentKeys.add(dedupKey);
            }
            if (assignments.isEmpty()) return;
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

            // tungnm37: Chỉ set FEC_Assignment_Users__c từ Stage 2 trở đi (không set ở Stage 1 để Service Case Owner vẫn hiển thị)
            Boolean isStage1 = stageName != null && Pattern.matches('(?i).*stage\\s*1.*', stageName);
            if (!isStage1) {
                rebuildAssignmentUsersForCase(caseId);
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
                Database.insert(histories, AccessLevel.SYSTEM_MODE);
            }
        } catch (Exception e) {
            System.debug('createAssignmentsFromManualItems error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            FEC_CommonUltils.logException('tungnm37', 'createAssignmentsFromManualItems', e.getMessage(), e.getStackTraceString());
        }
    }

    //tungnm37: Resolve Assignment Status theo team code
    //tungnm37: SP/CC → CSBackOfficeReview; nhung neu cross-team (CC→SP hoac SP→CC) → CSReview
    //tungnm37: CS khac (IB/EC/OB/QC/OM/F2F/CX) → CSReview
    //tungnm37: Other Dept (CO/CL/CP/PM/DS/TS/CA/IA/IT) → OtherDeptReview; con lai → Open
    private static String resolveAssignmentStatus(String teamCode) {
        return resolveAssignmentStatusWithOwner(teamCode, null);
    }

    //tungnm37: Overload voi caseOwnerTeam de xu ly cross-team SP<->CC
    //tungnm37: caseOwnerTeam = team cua Queue dang giu Case (khong phai FEC_User_Group__c)
    public static String resolveAssignmentStatusWithOwner(String teamCode, String caseOwnerTeam) {
        if (String.isBlank(teamCode)) return FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN;
        if (FEC_ConstantCommon.CS_BACKOFFICE_TEAMS.contains(teamCode)) {
            //tungnm37: cross-team trong CS BackOffice (CC→SP hoac SP→CC) → CSReview
            if (String.isNotBlank(caseOwnerTeam)
                && FEC_ConstantCommon.CS_BACKOFFICE_TEAMS.contains(caseOwnerTeam)
                && caseOwnerTeam != teamCode) {
                return FEC_ConstantCommon.STATUS_CS_REVIEW;
            }
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

    //tungnm37: Resolve team code tu Queue ID (Case Owner) bang cach lookup FEC_Team_Queue__c
    @TestVisible
    private static String resolveTeamFromQueueId(Id queueId) {
        if (queueId == null) return null;
        // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
        if (txnTeamByQueueIdCache.containsKey(queueId)) {
            return txnTeamByQueueIdCache.get(queueId);
        }
        // Lay DeveloperName cua Queue
        List<Group> groups = [SELECT DeveloperName FROM Group WHERE Id = :queueId AND Type = 'Queue' LIMIT 1];
        if (groups.isEmpty()) {
            txnTeamByQueueIdCache.put(queueId, null);
            return null;
        }
        String devName = groups[0].DeveloperName;
        // Lookup team tu FEC_Team_Queue__c
        List<FEC_Team_Queue__c> tqs = [
            SELECT FEC_Select_Team__r.Name
            FROM FEC_Team_Queue__c
            WHERE FEC_Queue_Name__c = :devName
            LIMIT 1
        ];
        String team = tqs.isEmpty() ? null : tqs[0].FEC_Select_Team__r?.Name;
        txnTeamByQueueIdCache.put(queueId, team);
        return team;
    }

    //tungnm37: Resolve team code tu User ID (Case Owner) bang cach lookup FEC_Team_Queue__c qua FEC_Main_Queue__c
    @TestVisible
    private static String resolveTeamFromUserId(Id userId) {
        if (userId == null) return null;
        // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
        if (txnTeamByUserIdCache.containsKey(userId)) {
            return txnTeamByUserIdCache.get(userId);
        }
        List<User> users = [SELECT FEC_Main_Queue__c, UserRoleId FROM User WHERE Id = :userId LIMIT 1];
        if (users.isEmpty()) {
            txnTeamByUserIdCache.put(userId, null);
            return null;
        }
        
        String mainQueue = users[0].FEC_Main_Queue__c;
        if (String.isNotBlank(mainQueue) && mainQueue != 'default value') {
            List<FEC_Team_Queue__c> tqs = [
                SELECT FEC_Select_Team__r.Name
                FROM FEC_Team_Queue__c
                WHERE FEC_Queue_Name__c = :mainQueue
                LIMIT 1
            ];
            if (!tqs.isEmpty()) {
                String team = tqs[0].FEC_Select_Team__r?.Name;
                txnTeamByUserIdCache.put(userId, team);
                return team;
            }
        }
        
        // Fallback: GroupMember
        Set<Id> memberIds = new Set<Id>{ userId };
        if (users[0].UserRoleId != null) {
            for (Group grp : [
                SELECT Id 
                FROM Group 
                WHERE RelatedId = :users[0].UserRoleId 
                  AND Type IN ('Role', 'RoleAndSubordinates')
            ]) {
                memberIds.add(grp.Id);
            }
        }
        
        Set<String> queueDevNames = new Set<String>();
        for (GroupMember gm : [
            SELECT Group.DeveloperName 
            FROM GroupMember 
            WHERE UserOrGroupId IN :memberIds 
              AND Group.Type = 'Queue'
        ]) {
            queueDevNames.add(gm.Group.DeveloperName);
        }
        
        if (!queueDevNames.isEmpty()) {
            List<FEC_Team_Queue__c> tqs = [
                SELECT FEC_Select_Team__r.Name
                FROM FEC_Team_Queue__c
                WHERE FEC_Queue_Name__c IN :queueDevNames
            ];
            for (FEC_Team_Queue__c tq : tqs) {
                String teamName = tq.FEC_Select_Team__r?.Name;
                if (String.isNotBlank(teamName) && FEC_ConstantCommon.CS_BACKOFFICE_TEAMS.contains(teamName)) {
                    txnTeamByUserIdCache.put(userId, teamName);
                    return teamName;
                }
            }
            if (!tqs.isEmpty()) {
                String team = tqs[0].FEC_Select_Team__r?.Name;
                txnTeamByUserIdCache.put(userId, team);
                return team;
            }
        }
        txnTeamByUserIdCache.put(userId, null);
        return null;
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

    @TestVisible
    private static void rebuildAssignmentUsersForCase(String caseId) {
        if (String.isBlank(caseId)) {
            return;
        }

        List<FEC_Assignment__c> routingAssignments = [
            SELECT FEC_Assignment_Owner__c, FEC_OwnerID__c
            FROM FEC_Assignment__c
            WHERE FEC_Case__c = :caseId
              AND FEC_Assignment_Type__c = :FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING
        ];

        List<String> assignmentUsers = resolveAssignmentUsers(
            routingAssignments,
            new Map<String, Id>()
        );
        String assignmentUsersValue = assignmentUsers.isEmpty()
            ? null
            : String.join(assignmentUsers, ',');

        try {
            FEC_CaseTriggerHandler.isSystemUpdate = true;
            Database.SaveResult sr = Database.update(
                new Case(
                    Id = caseId,
                    FEC_Assignment_Users__c = assignmentUsersValue
                ),
                AccessLevel.SYSTEM_MODE
            );
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug(
                        'FEC_DEBUG rebuild FEC_Assignment_Users__c error: ' +
                        err.getStatusCode() +
                        ' - ' +
                        err.getMessage() +
                        ' - Fields: ' +
                        err.getFields()
                    );
                }
            } else {
                System.debug(
                    'FEC_DEBUG rebuild FEC_Assignment_Users__c success: ' +
                    assignmentUsersValue
                );
            }
        } catch (Exception eu) {
            System.debug(
                'FEC_DEBUG rebuild FEC_Assignment_Users__c exception: ' +
                eu.getMessage()
            );
            System.debug('FEC_DEBUG Stack trace: ' + eu.getStackTraceString());
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = false;
        }
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

        String currentStatusBeforeSubmit = FEC_CaseBusinessService.readRoutingHistoryCurrentStatus(
            caseId
        );

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
                    SELECT Id, OwnerId, Owner.Name, Owner.Type, FEC_Current_Case_Stage__c
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
                Boolean priorSystemOwner = FEC_CaseTriggerHandler.isSystemUpdate;
                FEC_CaseTriggerHandler.isSystemUpdate = true;
                try {
                    Database.update(new Case(Id = caseId, OwnerId = targetQueues[0].Id), AccessLevel.SYSTEM_MODE);
                } finally {
                    FEC_CaseTriggerHandler.isSystemUpdate = priorSystemOwner;
                }

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
                        FEC_Current_Status__c = currentStatusBeforeSubmit,
                        FEC_Submitted_On__c = DateTime.now()
                    );
                    Database.insert(gsrHistory, AccessLevel.SYSTEM_MODE);
                    gsrRoutingHistoryId = gsrHistory.Id;
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
                    Boolean priorSystemStage = FEC_CaseTriggerHandler.isSystemUpdate;
                    FEC_CaseTriggerHandler.isSystemUpdate = true;
                    try {
                        Database.update(new Case(Id = caseId, FEC_Current_Case_Stage__c = nextStages[0].Id), AccessLevel.SYSTEM_MODE);
                    } finally {
                        FEC_CaseTriggerHandler.isSystemUpdate = priorSystemStage;
                    }
                }
            }

            // Chỉ tạo thêm assignment/history tự động cho các team KHÁC CC/SP.
            // Nếu truyền toàn bộ nocIds vào đây thì team CC/SP sẽ bị tạo thêm 1 Route to history ngoài history owner-change ở trên.
            if (hasNonCcSpTeam(nocIds)) {
                Set<Id> nonCcSpNocIds = new Set<Id>();
                for (FEC_Routing_Assignment__c ra : [
                    SELECT FEC_Nature_of_Cases__c, FEC_Team__c
                    FROM FEC_Routing_Assignment__c
                    WHERE FEC_Nature_of_Cases__c IN :nocIds
                      AND FEC_Team__c != null
                      AND FEC_Active__c = true
                ]) {
                    if (ra.FEC_Team__c != 'CC' && ra.FEC_Team__c != 'SP') {
                        nonCcSpNocIds.add(ra.FEC_Nature_of_Cases__c);
                    }
                }
                if (!nonCcSpNocIds.isEmpty()) {
                    createAssignmentsOnRoute(caseId, nonCcSpNocIds, currentUser, null, stageName, remarkContent);
                }
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