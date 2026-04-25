/****************************************************************************************
 * File Name    : FEC_AssignmentController.Apex
 * Author       : Quangdv7
 * Date         : 2026-03-22
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-03-22     Quangdv7             Create
 
****************************************************************************************/

public without sharing class FEC_AssignmentController {

    public static void handle(List<FEC_Routing_Action_History__c> histories) {

        if (histories == null || histories.isEmpty()) return;

        List<FEC_Routing_Action_History__c> assignmentHistories = new List<FEC_Routing_Action_History__c>();
        List<FEC_Routing_Action_History__c> caseHistories = new List<FEC_Routing_Action_History__c>();

        for (FEC_Routing_Action_History__c h : histories) {
            if (h.FEC_Assignment__c != null) {
                if (h.FEC_Routing_Action_Type__c == FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT) {
                    assignmentHistories.add(h);
                } else if (h.FEC_Routing_Action_Type__c == 'Case') {
                    caseHistories.add(h);
                }
            }
        }

        handleCaseRouting(caseHistories);
        handleAssignmentRouting(assignmentHistories);
    }

    // =========================================================
    // CASE FLOW
    // =========================================================
    private static void handleCaseRouting(List<FEC_Routing_Action_History__c> histories) {

        if (histories.isEmpty()) return;

        Map<Id, Case> caseMap = new Map<Id, Case>(
            [SELECT Id, FEC_Team__c, FEC_Assignment_Count__c
             FROM Case WHERE Id IN :getCaseIds(histories)]
        );

        Map<Id, FEC_Assignment__c> assignmentMap = new Map<Id, FEC_Assignment__c>(
            [SELECT Id, FEC_Team__c FROM FEC_Assignment__c
             WHERE Id IN :getAssignmentIds(histories)]
        );

        Map<Id, String> teamMap = buildTeamMap(histories);

        for (FEC_Routing_Action_History__c h : histories) {

            if (h.FEC_Routing_Action__c != FEC_ConstantCommon.CASE_ROUTING_ACTION) continue;

            Case c = caseMap.get(h.FEC_Case__c);
            FEC_Assignment__c a = assignmentMap.get(h.FEC_Assignment__c);

            if (c == null || a == null) continue;

            String team = null;

            if (String.isNotBlank(h.FEC_Updated_User_Queue_ID__c)) {
                try {
                    Id ownerId = Id.valueOf(h.FEC_Updated_User_Queue_ID__c);
                    team = teamMap.get(ownerId);
                } catch (Exception e) {
                    team = null;
                }
            }

            if (c.FEC_Assignment_Count__c == 1) {
                c.FEC_Team__c = null;
            }

            addTeam(c, team);

            a.FEC_Team__c = team;
        }

        if (!caseMap.isEmpty()) update caseMap.values();
        if (!assignmentMap.isEmpty()) update assignmentMap.values();
    }

    // =========================================================
    // ASSIGNMENT FLOW
    // =========================================================
    private static void handleAssignmentRouting(List<FEC_Routing_Action_History__c> histories) {

        if (histories.isEmpty()) return;

        Map<Id, FEC_Assignment__c> assignmentMap = new Map<Id, FEC_Assignment__c>(
            [SELECT Id, FEC_Case__c, FEC_Team__c, FEC_Assignment_Status__c
             FROM FEC_Assignment__c
             WHERE Id IN :getAssignmentIds(histories)]
        );

        Map<Id, Case> caseMap = new Map<Id, Case>(
            [SELECT Id, FEC_Team__c, Status
             FROM Case
             WHERE Id IN :getCaseIdsFromAssignments(assignmentMap)]
        );

        Map<Id, List<FEC_Assignment__c>> caseAssignments = getAllAssignments(caseMap.keySet());

        Map<Id, String> teamMap = buildTeamMap(histories);

        List<FEC_Assignment__c> assignmentsToUpdate = new List<FEC_Assignment__c>();
        Map<Id, Case> caseUpdateMap = new Map<Id, Case>();
        List<FEC_Routing_Action_History__c> historiesToInsert = new List<FEC_Routing_Action_History__c>();

        for (FEC_Routing_Action_History__c h : histories) {

            FEC_Assignment__c current = assignmentMap.get(h.FEC_Assignment__c);
            if (current == null) continue;

            Case c = caseMap.get(current.FEC_Case__c);
            if (c == null) continue;

            Integer activeCount = countActiveAssignments(caseAssignments.get(c.Id), current.Id);
            String currentTeam = current.FEC_Team__c;
            String action = h.FEC_Routing_Action__c;

            // ===== ROUTE / TRANSFER / ESCALATE =====
            if (action == FEC_ConstantCommon.CASE_ROUTING_ACTION
                || action == FEC_ConstantCommon.CASE_TRANSFER_ACTION
                || action == FEC_ConstantCommon.CASE_ESCALATE_ACTION) {

                String targetTeam = null;

                 if (String.isNotBlank(h.FEC_Updated_User_Queue_ID__c)) {
                    try {
                        Id ownerId = Id.valueOf(h.FEC_Updated_User_Queue_ID__c);
                        targetTeam = teamMap.get(ownerId);
                    } catch (Exception e) {
                        targetTeam = null;
                    }
                }

                removeTeam(c, currentTeam);
                addTeam(c, targetTeam);

                assignmentsToUpdate.add(new FEC_Assignment__c(
                    Id = current.Id,
                    FEC_Team__c = targetTeam
                ));
            }

            // ===== REVERT =====
            else if (action == FEC_ConstantCommon.CASE_REVERT_ACTION) {

            String targetTeam = FEC_ConstantCommon.CASE_REVERTING_CREATOR;

            removeTeam(c, currentTeam);

            if (!isTeamExist(c, targetTeam)) {
                addTeam(c, targetTeam);
            }

            assignmentsToUpdate.add(new FEC_Assignment__c(
                Id = current.Id,
                FEC_Team__c = targetTeam
            ));
        }

            // ===== UPDATE =====
            else if (action == FEC_ConstantCommon.CASE_UPDATE_VALUE && h.FEC_Decision__c != null) {

                String decision = h.FEC_Decision__c;

                // =========================
                // TH1: KHÁC Cannot Contact Customer
                // =========================
                if (decision != FEC_ConstantCommon.CASE_DECISION_VALUE) {

                    String targetTeam = mapDecisionToTeam(decision);

                    // a. remove team hiện tại
                    removeTeam(c, currentTeam);

                    // b. update Assignment
                    assignmentsToUpdate.add(new FEC_Assignment__c(
                        Id = current.Id,
                        FEC_Team__c = targetTeam
                    ));

                    // c. add vào Case nếu chưa tồn tại
                    if (!isTeamExist(c, targetTeam)) {
                        addTeam(c, targetTeam);
                    }
                }

                // =========================
                // TH2: Cannot Contact Customer
                // =========================
                else {

                    if (activeCount == 0) {

                        // a. clear Case
                        c.FEC_Team__c = null;
                        c.Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANNOT_CONTACT_CUSTOMER;

                        // b. clear Assignment
                        assignmentsToUpdate.add(new FEC_Assignment__c(
                            Id = current.Id,
                            FEC_Team__c = null
                        ));

                        // c. tạo history
                        historiesToInsert.add(new FEC_Routing_Action_History__c(
                            FEC_Routing_Action__c = FEC_ConstantCommon.CASE_RESOLVE_ACTION,
                            FEC_Routing_Action_Type__c = 'Case',
                            FEC_Case__c = c.Id
                        ));
                    }
                    else {

                        String targetTeam = FEC_ConstantCommon.TEAM_VALUE;

                        // a. remove team hiện tại
                        removeTeam(c, currentTeam);

                        // b. add nếu chưa có
                        if (!isTeamExist(c, targetTeam)) {
                            addTeam(c, targetTeam);
                        }

                        // c. update Assignment
                        assignmentsToUpdate.add(new FEC_Assignment__c(
                            Id = current.Id,
                            FEC_Team__c = targetTeam
                        ));
                    }
                }
            }

            // ===== REJECT / RESOLVE =====
            else if (action == FEC_ConstantCommon.CASE_REJECT_ACTION
                  || action == FEC_ConstantCommon.CASE_RESOLVE_ACTION) {

                if (activeCount == 0) {

                    c.FEC_Team__c = null;
                    c.Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED;

                    assignmentsToUpdate.add(new FEC_Assignment__c(
                        Id = current.Id,
                        FEC_Team__c = null
                    ));

                    historiesToInsert.add(new FEC_Routing_Action_History__c(
                        FEC_Routing_Action__c = FEC_ConstantCommon.CASE_RESOLVE_ACTION,
                        FEC_Routing_Action_Type__c = 'Case',
                        FEC_Case__c = c.Id
                    ));
                }
                else {

                    removeTeam(c, currentTeam);

                    assignmentsToUpdate.add(new FEC_Assignment__c(
                        Id = current.Id,
                        FEC_Team__c = null
                    ));
                }
            }

            caseUpdateMap.put(c.Id, c);
        }

        if (!caseUpdateMap.isEmpty()) update caseUpdateMap.values();
        if (!assignmentsToUpdate.isEmpty()) update assignmentsToUpdate;
        if (!historiesToInsert.isEmpty()) insert historiesToInsert;
    }

    // =========================================================
    // HELPER
    // =========================================================

    private static Set<Id> getCaseIds(List<FEC_Routing_Action_History__c> listData) {
        Set<Id> ids = new Set<Id>();
        for (FEC_Routing_Action_History__c h : listData) {
            if (h.FEC_Case__c != null) ids.add(h.FEC_Case__c);
        }
        return ids;
    }

    private static Set<Id> getAssignmentIds(List<FEC_Routing_Action_History__c> listData) {
        Set<Id> ids = new Set<Id>();
        for (FEC_Routing_Action_History__c h : listData) {
            if (h.FEC_Assignment__c != null) ids.add(h.FEC_Assignment__c);
        }
        return ids;
    }

    private static Set<Id> getCaseIdsFromAssignments(Map<Id, FEC_Assignment__c> mapData) {
        Set<Id> ids = new Set<Id>();
        for (FEC_Assignment__c a : mapData.values()) {
            if (a.FEC_Case__c != null) ids.add(a.FEC_Case__c);
        }
        return ids;
    }

    private static Map<Id, List<FEC_Assignment__c>> getAllAssignments(Set<Id> caseIds) {
        Map<Id, List<FEC_Assignment__c>> result = new Map<Id, List<FEC_Assignment__c>>();

        for (FEC_Assignment__c a : [
            SELECT Id, FEC_Case__c, FEC_Assignment_Status__c
            FROM FEC_Assignment__c
            WHERE FEC_Case__c IN :caseIds
        ]) {
            if (!result.containsKey(a.FEC_Case__c)) {
                result.put(a.FEC_Case__c, new List<FEC_Assignment__c>());
            }
            result.get(a.FEC_Case__c).add(a);
        }

        return result;
    }

    private static Integer countActiveAssignments(List<FEC_Assignment__c> listA, Id currentId) {
        Integer count = 0;
        if (listA == null) return 0;

        for (FEC_Assignment__c a : listA) {
            if (a.Id != currentId &&
                a.FEC_Assignment_Status__c != FEC_ConstantCommon.STATUS_COMPLETED) {
                count++;
            }
        }
        return count;
    }

    // ===== REMOVE TEAM =====
    private static void removeTeam(Case c, String team) {
        if (String.isBlank(c.FEC_Team__c) || String.isBlank(team)) return;

        Set<String> setTeam = new Set<String>(c.FEC_Team__c.split('_'));

        if (setTeam.contains(team)) {
            setTeam.remove(team);
        }

        c.FEC_Team__c = setTeam.isEmpty()
            ? null
            : String.join(new List<String>(setTeam), '_');
    }

    // ===== ADD TEAM =====
    private static void addTeam(Case c, String team) {
        if (String.isBlank(team)) return;

        Set<String> setTeam = new Set<String>();

        if (String.isNotBlank(c.FEC_Team__c)) {
            setTeam.addAll(c.FEC_Team__c.split('_'));
        }

        if (!setTeam.contains(team)) {
            setTeam.add(team);
        }

        c.FEC_Team__c = setTeam.isEmpty()
            ? null
            : String.join(new List<String>(setTeam), '_');
    }

    private static Boolean isTeamExist(Case c, String team) {
        if (String.isBlank(c.FEC_Team__c) || String.isBlank(team)) return false;

        Set<String> setTeam = new Set<String>(c.FEC_Team__c.split('_'));
        return setTeam.contains(team);
    }

    private static String mapDecisionToTeam(String decision) {
        return FEC_ConstantCommon.decisionToTeamMap.get(decision);
    }

    private static Map<Id, String> buildTeamMap(List<FEC_Routing_Action_History__c> histories) {

        Set<Id> ownerIds = new Set<Id>();

        for (FEC_Routing_Action_History__c h : histories) {
            if (String.isNotBlank(h.FEC_Updated_User_Queue_ID__c)) {
                try {
                    ownerIds.add(Id.valueOf(h.FEC_Updated_User_Queue_ID__c));
                } catch (Exception e) {
                    System.debug(System.label.FEC_Invalid_OwnerId + h.FEC_Updated_User_Queue_ID__c);
                }
            }
        }

        if (ownerIds.isEmpty()) {
            return new Map<Id, String>();
        }

        return FEC_RoutingActionHistoryTriggerHandler.getTeamsFromIds(ownerIds);
    }
}