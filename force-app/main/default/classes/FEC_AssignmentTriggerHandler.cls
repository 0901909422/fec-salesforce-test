// tungnm37: Handler sync Case.FEC_Assignment_Users__c khi FEC_Assignment_Owner__c thay đổi
// tungnm37 fix: cập nhật FEC_Assignment_Users__c cho tất cả Routing assignment (cả auto và manual)
// tungnm37 fix: để null cho General assignment (thủ công) và khi submit ở stage 1
public without sharing class FEC_AssignmentTriggerHandler {

    public static void handleAfterUpdate(List<FEC_Assignment__c> newList, Map<Id, FEC_Assignment__c> oldMap) {
        Set<Id> caseIds = new Set<Id>();
        for (FEC_Assignment__c assignment : newList) {
            FEC_Assignment__c oldAssignment = oldMap.get(assignment.Id);
            // tungnm37 fix: trigger khi Assignment Owner thay đổi (cả auto và manual)
            if (assignment.FEC_Assignment_Owner__c != oldAssignment.FEC_Assignment_Owner__c 
                && assignment.FEC_Case__c != null) {
                caseIds.add(assignment.FEC_Case__c);
            }
        }

        if (caseIds.isEmpty()) return;

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
                    // tungnm37 fix: lưu FEC_Assignment_Owner_Text__c (formula field đã tính sẵn)
                    if (String.isNotBlank(assignment.FEC_Assignment_Owner_Text__c)) {
                        assignmentUserSet.add(assignment.FEC_Assignment_Owner_Text__c);
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
}
