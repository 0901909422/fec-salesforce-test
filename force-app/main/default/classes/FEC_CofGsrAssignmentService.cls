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
        List<Map<String, String>> result = new List<Map<String, String>>();
        for (FEC_Team_Queue__c r : records) {
            result.add(new Map<String, String>{
                'teamName' => r.FEC_Select_Team__r?.Name,
                'queueName' => r.FEC_Queue_Name__c
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
                SELECT Id, OwnerId, Owner.Name, Owner.Type, FEC_Final_Status__c
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
                    FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
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

            // tungnm37: lưu Queue Ids vào Case.FEC_Assignment_Users__c để list view dùng
            List<String> queueIdList = new List<String>();
            for (FEC_Routing_Assignment__c ra : routingAssignments) {
                if (queueNameToId.containsKey(ra.FEC_Queue__c)) {
                    queueIdList.add(String.valueOf(queueNameToId.get(ra.FEC_Queue__c)));
                }
            }
            if (!queueIdList.isEmpty()) {
                try {
                    Database.update(new Case(Id = caseId, FEC_Assignment_Users__c = String.join(queueIdList, ',')), AccessLevel.SYSTEM_MODE);
                } catch (Exception eu) {
                    System.debug('FEC_DEBUG update FEC_Assignment_Users__c error: ' + eu.getMessage());
                }
            }

            List<FEC_Case_Remarks__c> remarksToInsert = new List<FEC_Case_Remarks__c>();
            for (FEC_Assignment__c a : assignments) {
                remarksToInsert.add(new FEC_Case_Remarks__c(
                    FEC_Case__c = caseId,
                    FEC_Remark_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
                    FEC_Case_Remarks__c = remarkContent,
                    FEC_User__c = emailLocalPart(remarkUserEmail), // tungnm37 sửa: lấy phần trước @
                    FEC_Assignment__c = a.Id,
                    FEC_Stage_Name__c = stageName
                ));
            }
            if (!remarksToInsert.isEmpty()) insert remarksToInsert;

            List<FEC_Routing_Action_History__c> histories = new List<FEC_Routing_Action_History__c>();
            // tungnm37: build reverse map Id->Name để tránh lỗi so sánh String vs Id
            Map<String, String> queueIdToName = new Map<String, String>();
            for (String qn : queueNameToId.keySet()) {
                if (queueNameToId.get(qn) != null) {
                    queueIdToName.put(String.valueOf(queueNameToId.get(qn)), qn);
                }
            }
            for (FEC_Assignment__c a : assignments) {
                String queueId = a.FEC_OwnerID__c;
                String queueName = queueIdToName.get(queueId);
                histories.add(new FEC_Routing_Action_History__c(
                    FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
                    FEC_Case__c = caseId,
                    FEC_Assignment__c = a.Id,
                    FEC_Perform_User__c = currentUser.Id,
                    FEC_User__c = emailLocalPart(currentUser.Email),
                    FEC_User_Role__c = userRoleName,
                    FEC_Stage_Name__c = stageName,
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
            for (Group g : [SELECT Id, Name, DeveloperName FROM Group WHERE DeveloperName IN :queueNames AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE]) {
                queueNameToId.put(g.DeveloperName, g.Id);
                queueDevNameToDisplayName.put(g.DeveloperName, g.Name); // tungnm37: map DeveloperName → display name
            }

            String userRoleName = currentUser.UserRole?.Name;
            Case currentCase = [SELECT Id, OwnerId, Owner.Name, FEC_Final_Status__c FROM Case WHERE Id = :caseId LIMIT 1];
            String originalOwnerLabel = resolveRoutingHistoryOwnerLabel(
                currentCase.OwnerId, currentCase.Owner?.Name
            );

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
                    FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
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

            // tungnm37: lưu Queue Ids vào Case.FEC_Assignment_Users__c
            List<String> queueIdListM = new List<String>();
            for (String qn : queueNames) {
                if (queueNameToId.containsKey(qn)) {
                    queueIdListM.add(String.valueOf(queueNameToId.get(qn)));
                }
            }
            if (!queueIdListM.isEmpty()) {
                try {
                    Database.update(new Case(Id = caseId, FEC_Assignment_Users__c = String.join(queueIdListM, ',')), AccessLevel.SYSTEM_MODE);
                } catch (Exception eu) {
                    System.debug('FEC_DEBUG update FEC_Assignment_Users__c (manual) error: ' + eu.getMessage());
                }
            }

            List<FEC_Case_Remarks__c> remarks = new List<FEC_Case_Remarks__c>();
            for (Integer i = 0; i < assignments.size(); i++) {
                remarks.add(new FEC_Case_Remarks__c(
                    FEC_Case__c = caseId,
                    FEC_Remark_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
                    FEC_Case_Remarks__c = remarkList[i],
                    FEC_User__c = emailLocalPart(currentUser.Email), // tungnm37 sửa: lấy phần trước @
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
                    FEC_Original_User_Queue__c = originalOwnerLabel,
                    FEC_Original_User_Queue_ID__c = currentCase.OwnerId != null ? String.valueOf(currentCase.OwnerId) : null,
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
        if (isCcSpTeam) {
            String targetQueueName = 'CC'.equals(firstTeam)
                ? System.Label.FEC_CC_Queue_Name
                : System.Label.FEC_CS_Support_Queue_Name;
            List<Group> targetQueues = [SELECT Id FROM Group WHERE Name = :targetQueueName AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE LIMIT 1];
            if (!targetQueues.isEmpty()) {
                FEC_CaseBusinessService.registerSkipOwnerChangeRoutingHistory(caseId);
                Database.update(new Case(Id = caseId, OwnerId = targetQueues[0].Id), AccessLevel.SYSTEM_MODE);

                // tungnm37: tạo Routing Action History cho luồng CC/SP
                try {
                    Case currentCase = [SELECT Id, OwnerId, Owner.Name, Owner.Type, FEC_Final_Status__c FROM Case WHERE Id = :caseId LIMIT 1];
                    String originalOwnerLabel = resolveRoutingHistoryOwnerLabel(currentCase.OwnerId, currentCase.Owner?.Name);
                    String userRoleName = currentUser.UserRole?.Name;
                    Database.insert(new FEC_Routing_Action_History__c(
                        FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
                        FEC_Case__c = caseId,
                        FEC_Perform_User__c = currentUser.Id,
                        FEC_User__c = emailLocalPart(currentUser.Email),
                        FEC_User_Role__c = userRoleName,
                        FEC_Stage_Name__c = stageName,
                        FEC_Original_User_Queue__c = originalOwnerLabel,
                        FEC_Original_User_Queue_ID__c = currentCase.OwnerId != null ? String.valueOf(currentCase.OwnerId) : null,
                        FEC_Updated_User_Queue__c = targetQueueName,
                        FEC_Updated_User_Queue_ID__c = String.valueOf(targetQueues[0].Id),
                        FEC_Current_Status__c = currentCase.FEC_Final_Status__c,
                        FEC_Submitted_On__c = DateTime.now()
                    ));
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
        } else {
            createAssignmentsOnRoute(caseId, nocIds, currentUser, null, stageName, remarkContent);
        }
        return null;
    }
}
