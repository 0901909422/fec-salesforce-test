/**
 * tungnm37: Service xá»­ lÃ½ COF/GSR Assignment, Routing Action History, Case Remarks
 * TÃ¡ch ra tá»« FEC_CaseBusinessService theo yÃªu cáº§u review
 */
public without sharing class FEC_CofGsrAssignmentService {

    // â”€â”€â”€ Private helpers (duplicate tá»« FEC_CaseBusinessService Ä‘á»ƒ trÃ¡nh circular dependency) â”€â”€â”€

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

    // â”€â”€â”€ Public API â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /** Láº¥y danh sÃ¡ch Team/Queue tá»« FEC_Team_Queue__c cho Manual Assignment */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getTeamQueueOptions() {
        List<FEC_Team_Queue__c> records = [
            SELECT FEC_Name__c, FEC_Queue_Name__c
            FROM FEC_Team_Queue__c
            ORDER BY FEC_Name__c, FEC_Queue_Name__c
        ];
        List<Map<String, String>> result = new List<Map<String, String>>();
        for (FEC_Team_Queue__c r : records) {
            result.add(new Map<String, String>{
                'teamName' => r.FEC_Name__c,
                'queueName' => r.FEC_Queue_Name__c
            });
        }
        return result;
    }

    /**
     * Query FEC_Routing_Assignment__c theo NOC + CustomerType
     * natureOfCaseId cÃ³ thá»ƒ lÃ  ID cá»§a FEC_Nature_of_Case__c hoáº·c FEC_Actual_Nature_of_Case__c
     */
    @AuraEnabled
    public static List<Map<String, String>> getRoutingAssignments(String natureOfCaseId, String customerType) {
        if (String.isBlank(natureOfCaseId)) return new List<Map<String, String>>();

        List<FEC_Routing_Assignment__c> records = [
            SELECT FEC_Team__c, FEC_Queue__c, FEC_Customer_Type__c
            FROM FEC_Routing_Assignment__c
            WHERE FEC_Nature_of_Cases__c = :natureOfCaseId
              AND FEC_Team__c != null
              AND FEC_Queue__c != null
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
                    Set<Id> siblingIds = new Set<Id>();
                    for (FEC_Nature_of_Case__c n : siblingNocs) siblingIds.add(n.Id);
                    records = [
                        SELECT FEC_Team__c, FEC_Queue__c, FEC_Customer_Type__c
                        FROM FEC_Routing_Assignment__c
                        WHERE FEC_Nature_of_Cases__c IN :siblingIds
                          AND FEC_Team__c != null AND FEC_Queue__c != null
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
                    Set<Id> nocIds = new Set<Id>();
                    for (FEC_Nature_of_Case__c n : matchNocs) nocIds.add(n.Id);
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

    /**
     * Táº¡o FEC_Assignment__c + FEC_Case_Remarks__c + FEC_Routing_Action_History__c
     * khi Route to COF/GSR (Stage 1, khÃ´ng pháº£i CC/SP)
     */
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
                ORDER BY FEC_Team__c ASC
            ];
            if (routingAssignments.isEmpty()) return;

            Set<String> queueNames = new Set<String>();
            for (FEC_Routing_Assignment__c ra : routingAssignments) {
                if (String.isNotBlank(ra.FEC_Queue__c)) queueNames.add(ra.FEC_Queue__c);
            }
            Map<String, Id> queueNameToId = new Map<String, Id>();
            for (Group g : [SELECT Id, Name FROM Group WHERE Name IN :queueNames AND Type = 'Queue']) {
                queueNameToId.put(g.Name, g.Id);
            }

            String remarkContent = remarkContentParam;
            String remarkUserEmail = currentUser.Email;
            if (String.isBlank(remarkContent)) {
                List<FEC_Case_Remarks__c> latestRemarks = [
                    SELECT Id, FEC_Case_Remarks__c, FEC_User__c
                    FROM FEC_Case_Remarks__c
                    WHERE FEC_Case__c = :caseId AND FEC_Remark_Type__c != 'Assignment'
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
                    FEC_Assignment_Name__c = 'Call',
                    FEC_Assignment_Type__c = 'Routing',
                    FEC_Assignment_Status__c = 'Open',
                    FEC_OwnerID__c = queueId,
                    FEC_Assignment_Owner__c = currentUser.Id,
                    FEC_Team__c = ra.FEC_Team__c,
                    FEC_Assignment_Remark__c = remarkContent,
                    FEC_User_Role__c = userRoleName,
                    FEC_Assignment_Routing_Action__c = stageName
                ));
            }
            insert assignments;

            List<FEC_Case_Remarks__c> remarksToInsert = new List<FEC_Case_Remarks__c>();
            for (FEC_Assignment__c a : assignments) {
                remarksToInsert.add(new FEC_Case_Remarks__c(
                    FEC_Case__c = caseId,
                    FEC_Remark_Type__c = 'Assignment',
                    FEC_Case_Remarks__c = remarkContent,
                    FEC_User__c = remarkUserEmail,
                    FEC_Assignment__c = a.Id,
                    FEC_Stage_Name__c = stageName
                ));
            }
            if (!remarksToInsert.isEmpty()) insert remarksToInsert;

            List<FEC_Routing_Action_History__c> histories = new List<FEC_Routing_Action_History__c>();
            for (FEC_Assignment__c a : assignments) {
                String queueId = a.FEC_OwnerID__c;
                String queueName = null;
                for (String qn : queueNameToId.keySet()) {
                    if (queueNameToId.get(qn) != null && String.valueOf(queueNameToId.get(qn)) == queueId) {
                        queueName = qn; break;
                    }
                }
                histories.add(new FEC_Routing_Action_History__c(
                    FEC_Routing_Action__c = 'Route to',
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
                    FEC_Current_Status__c = currentCase.FEC_Final_Status__c
                ));
            }
            if (!histories.isEmpty()) {
                Database.insert(histories);
            }
        } catch (Exception e) {
            System.debug('FEC_DEBUG createAssignmentsOnRoute error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            try {
                insert new FEC_Log__c(
                    FEC_Function_Name__c = 'createAssignmentsOnRoute',
                    FEC_Error_Message__c = e.getMessage(),
                    FEC_Stack_Trace_String__c = e.getStackTraceString()
                );
            } catch (Exception logEx) {}
        }
    }

    /**
     * Táº¡o Assignment tá»« manual items (Stage 2 - Add Item)
     * manualItemsJson: JSON array [{teamName, queueName, remark}]
     */
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
            for (Group g : [SELECT Id, Name FROM Group WHERE Name IN :queueNames AND Type = 'Queue']) {
                queueNameToId.put(g.Name, g.Id);
            }

            String userRoleName = currentUser.UserRole?.Name;
            Case currentCase = [SELECT Id, OwnerId, Owner.Name, FEC_Final_Status__c FROM Case WHERE Id = :caseId LIMIT 1];
            String originalOwnerLabel = resolveRoutingHistoryOwnerLabel(
                currentCase.OwnerId, currentCase.Owner?.Name
            );

            List<FEC_Assignment__c> assignments = new List<FEC_Assignment__c>();
            List<String> remarkList = new List<String>();
            for (Object raw : rawItems) {
                Map<String, Object> item = (Map<String, Object>) raw;
                String teamName = (String) item.get('teamName');
                String queueName = (String) item.get('queueName');
                String remark = (String) item.get('remark');
                String queueId = queueNameToId.containsKey(queueName)
                    ? String.valueOf(queueNameToId.get(queueName)) : null;
                assignments.add(new FEC_Assignment__c(
                    FEC_Case__c = caseId,
                    FEC_Assignment_Name__c = 'Call',
                    FEC_Assignment_Type__c = 'Routing',
                    FEC_Assignment_Status__c = 'Open',
                    FEC_OwnerID__c = queueId,
                    FEC_Assignment_Owner__c = currentUser.Id,
                    FEC_Team__c = teamName,
                    FEC_Assignment_Remark__c = remark,
                    FEC_User_Role__c = userRoleName,
                    FEC_Assignment_Routing_Action__c = stageName
                ));
                remarkList.add(remark);
            }
            insert assignments;

            List<FEC_Case_Remarks__c> remarks = new List<FEC_Case_Remarks__c>();
            for (Integer i = 0; i < assignments.size(); i++) {
                remarks.add(new FEC_Case_Remarks__c(
                    FEC_Case__c = caseId,
                    FEC_Remark_Type__c = 'Assignment',
                    FEC_Case_Remarks__c = remarkList[i],
                    FEC_User__c = currentUser.Email,
                    FEC_Assignment__c = assignments[i].Id,
                    FEC_Stage_Name__c = stageName
                ));
            }
            if (!remarks.isEmpty()) insert remarks;

            List<FEC_Routing_Action_History__c> histories = new List<FEC_Routing_Action_History__c>();
            for (Integer i = 0; i < assignments.size(); i++) {
                FEC_Assignment__c a = assignments[i];
                String queueName = null;
                for (String qn : queueNameToId.keySet()) {
                    if (queueNameToId.get(qn) != null && String.valueOf(queueNameToId.get(qn)) == a.FEC_OwnerID__c) {
                        queueName = qn; break;
                    }
                }
                histories.add(new FEC_Routing_Action_History__c(
                    FEC_Routing_Action__c = 'Route to',
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
                    FEC_Current_Status__c = currentCase.FEC_Final_Status__c
                ));
            }
            if (!histories.isEmpty()) {
                Database.insert(histories);
            }
        } catch (Exception e) {
            System.debug('createAssignmentsFromManualItems error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            try {
                insert new FEC_Log__c(
                    FEC_Function_Name__c = 'createAssignmentsFromManualItems',
                    FEC_Error_Message__c = e.getMessage(),
                    FEC_Stack_Trace_String__c = e.getStackTraceString()
                );
            } catch (Exception logEx) {}
        }
    }

    /**
     * Resolve natureOfCaseId (FEC_Actual_Nature_of_Case__c hoáº·c FEC_Nature_of_Case__c)
     * â†’ tráº£ vá» Set<Id> táº¥t cáº£ FEC_Nature_of_Case__c IDs cÃ³ Routing Assignment cÃ¹ng Sub_Code
     */
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

            Set<Id> allNocIds = new Set<Id>();
            for (FEC_Nature_of_Case__c n : matchNocs) allNocIds.add(n.Id);

            for (AggregateResult ar : [
                SELECT FEC_Nature_of_Cases__c nocId
                FROM FEC_Routing_Assignment__c
                WHERE FEC_Nature_of_Cases__c IN :allNocIds
                  AND FEC_Team__c != null AND FEC_Queue__c != null
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
}
