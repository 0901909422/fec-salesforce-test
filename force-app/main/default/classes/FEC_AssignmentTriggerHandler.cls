// tungnm37: Handler sync Case.FEC_Assignment_Users__c khi FEC_Assignment_Owner__c thay đổi
// tungnm37 fix: cập nhật FEC_Assignment_Users__c cho tất cả Routing assignment (cả auto và manual)
// tungnm37 fix: để null cho General assignment (thủ công) và khi submit ở stage 1
public without sharing class FEC_AssignmentTriggerHandler {

    private static Boolean isSyncingAssignmentManagerList = false;

    public static void handleAfterInsert(List<FEC_Assignment__c> newList) {
        if (isSyncingAssignmentManagerList || newList == null || newList.isEmpty()) {
            return;
        }
        if (FEC_BatchCaseHandlingImportService.isBatchHandlingTriggerBypass()) {
            return;
        }

        Set<Id> caseIds = new Set<Id>();
        Map<Id, Id> caseIdToNewOwnerUserId = new Map<Id, Id>();
        for (FEC_Assignment__c assignment : newList) {
            if (assignment.FEC_Case__c != null) {
                caseIds.add(assignment.FEC_Case__c);
                if (assignment.FEC_Assignment_Owner__c != null) {
                    caseIdToNewOwnerUserId.put(assignment.FEC_Case__c, assignment.FEC_Assignment_Owner__c);
                }
            }
        }

        syncCaseAssignmentData(caseIds);
        syncCaseParticipants(caseIdToNewOwnerUserId);
    }

    public static void handleAfterUpdate(List<FEC_Assignment__c> newList, Map<Id, FEC_Assignment__c> oldMap) {
        if (isSyncingAssignmentManagerList || newList == null || newList.isEmpty() || oldMap == null) {
            return;
        }
        if (FEC_BatchCaseHandlingImportService.isBatchHandlingTriggerBypass()) {
            return;
        }

        Set<Id> caseIds = new Set<Id>();
        Map<Id, Id> caseIdToNewOwnerUserId = new Map<Id, Id>();
        for (FEC_Assignment__c assignment : newList) {
            FEC_Assignment__c oldAssignment = oldMap.get(assignment.Id);
            if (oldAssignment == null) {
                continue;
            }
            //tungnm37 recalc thêm khi đổi status, type hoặc chuyển case
            if (assignment.FEC_Case__c != oldAssignment.FEC_Case__c) {
                if (oldAssignment.FEC_Case__c != null) {
                    caseIds.add(oldAssignment.FEC_Case__c);
                }
                if (assignment.FEC_Case__c != null) {
                    caseIds.add(assignment.FEC_Case__c);
                }
                continue;
            }
            // tungnm37 fix: trigger khi Assignment Owner thay đổi (cả auto và manual)
            if ((assignment.FEC_Assignment_Owner__c != oldAssignment.FEC_Assignment_Owner__c 
                || assignment.FEC_Assignment_Status__c != oldAssignment.FEC_Assignment_Status__c
                || assignment.FEC_Assignment_Type__c != oldAssignment.FEC_Assignment_Type__c)
                && assignment.FEC_Case__c != null) {
                caseIds.add(assignment.FEC_Case__c);
            }
            if (assignment.FEC_Assignment_Owner__c != oldAssignment.FEC_Assignment_Owner__c
                    && assignment.FEC_Assignment_Owner__c != null
                    && assignment.FEC_Case__c != null) {
                caseIdToNewOwnerUserId.put(assignment.FEC_Case__c, assignment.FEC_Assignment_Owner__c);
            }
        }

        syncCaseAssignmentData(caseIds);
        syncCaseParticipants(caseIdToNewOwnerUserId);
    }

    //tungnm37 sync thêm assignment manager list lên case nhưng giữ nguyên logic cũ của assignment users
    private static void syncCaseAssignmentData(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }

        isSyncingAssignmentManagerList = true;
        try {
            syncAssignmentUsers(caseIds);
            FEC_CaseManagerListService.syncAssignmentManagerListByCaseIds(caseIds);
        } finally {
            isSyncingAssignmentManagerList = false;
        }
    }

    private static void syncAssignmentUsers(Set<Id> caseIds) {
        // tungnm37 fix: query thêm FEC_Assignment_Owner_Text__c để lấy tên owner
        Map<Id, List<FEC_Assignment__c>> caseToAssignments = new Map<Id, List<FEC_Assignment__c>>();
        
        for (FEC_Assignment__c assignment : [
            SELECT Id, FEC_Case__c, FEC_Assignment_Owner__c, FEC_OwnerID__c, 
                   FEC_Assignment_Type__c, FEC_Manual__c, FEC_Assignment_Owner_Text__c
            FROM FEC_Assignment__c
            WHERE FEC_Case__c IN :caseIds
        ]) {
            if (!caseToAssignments.containsKey(assignment.FEC_Case__c)) {
                caseToAssignments.put(assignment.FEC_Case__c, new List<FEC_Assignment__c>());
            }
            caseToAssignments.get(assignment.FEC_Case__c).add(assignment);
        }

        List<Case> casesToUpdate = new List<Case>();
        for (Id caseId : caseToAssignments.keySet()) {
            Set<String> assignmentUserSet = new Set<String>();
            Boolean hasRoutingAssignment = false;
            
            for (FEC_Assignment__c assignment : caseToAssignments.get(caseId)) {
                // tungnm37 fix: xử lý tất cả Routing assignment (cả auto và manual)
                if (assignment.FEC_Assignment_Type__c == FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING) {
                    hasRoutingAssignment = true;
                    // tungnm37 fix: User → lưu User ID; Queue → lưu Queue Name (FEC_OwnerID__c)
                    if (assignment.FEC_Assignment_Owner__c != null) {
                        assignmentUserSet.add(String.valueOf(assignment.FEC_Assignment_Owner__c));
                    } else if (String.isNotBlank(assignment.FEC_OwnerID__c)) {
                        assignmentUserSet.add(assignment.FEC_OwnerID__c);
                    }
                }
            }
            
            // tungnm37 fix: nếu có Routing assignment thì set value, nếu không có (chỉ có General) thì set null
            if (hasRoutingAssignment && !assignmentUserSet.isEmpty()) {
                // tungnm37 fix: dùng ',' thống nhất với FEC_CofGsrAssignmentService và parseAssignmentUsers
                casesToUpdate.add(new Case(Id = caseId, FEC_Assignment_Users__c = String.join(new List<String>(assignmentUserSet), ',')));
            } else if (!hasRoutingAssignment) {
                // tungnm37 fix: set null khi không có Routing assignment (chỉ có General/thủ công)
                casesToUpdate.add(new Case(Id = caseId, FEC_Assignment_Users__c = null));
            }
        }

        if (!casesToUpdate.isEmpty()) {
            Database.update(casesToUpdate, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * Cập nhật FEC_Case_Participants__c trên Case khi Assignment Owner đổi sang User mới.
     * Chỉ áp dụng cho Record Type Customer Case và Internal Case.
     */
    private static void syncCaseParticipants(Map<Id, Id> caseIdToNewOwnerUserId) {
        if (caseIdToNewOwnerUserId == null || caseIdToNewOwnerUserId.isEmpty()) {
            return;
        }

        Set<String> allowedRecordTypes = new Set<String>{
            FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME,
            FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME
        };

        List<Case> casesToUpdate = new List<Case>();
        for (Case c : [
            SELECT Id, RecordType.DeveloperName, FEC_Case_Participants__c
            FROM Case
            WHERE Id IN :caseIdToNewOwnerUserId.keySet()
        ]) {
            if (!allowedRecordTypes.contains(c.RecordType.DeveloperName)) {
                continue;
            }
            Id newUserId = caseIdToNewOwnerUserId.get(c.Id);
            String updatedParticipants = addParticipant(c.FEC_Case_Participants__c, newUserId);
            if (updatedParticipants != c.FEC_Case_Participants__c) {
                casesToUpdate.add(new Case(Id = c.Id, FEC_Case_Participants__c = updatedParticipants));
            }
        }

        if (!casesToUpdate.isEmpty()) {
            Database.update(casesToUpdate, AccessLevel.SYSTEM_MODE);
        }
    }

    private static String addParticipant(String currentParticipants, Id newUserId) {
        if (newUserId == null) {
            return currentParticipants;
        }

        String userIdStr = String.valueOf(newUserId);
        if (String.isBlank(currentParticipants)) {
            return userIdStr;
        }

        Set<String> trimmedIds = new Set<String>();
        for (String id : currentParticipants.split(',')) {
            trimmedIds.add(id.trim());
        }

        if (trimmedIds.contains(userIdStr)) {
            return currentParticipants;
        }

        return currentParticipants + ',' + userIdStr;
    }
}
