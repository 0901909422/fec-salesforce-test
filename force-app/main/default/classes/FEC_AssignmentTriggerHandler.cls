// tungnm37: Handler sync Case.FEC_Assignment_Users__c khi FEC_Assignment_Owner__c thay đổi
// tungnm37 fix: chỉ cập nhật FEC_Assignment_Users__c cho Routing assignment (assignment mới tự động)
// tungnm37 fix: để null cho General assignment (thủ công) và khi submit ở stage 1
public without sharing class FEC_AssignmentTriggerHandler {

    public static void handleAfterUpdate(List<FEC_Assignment__c> newList, Map<Id, FEC_Assignment__c> oldMap) {
        Set<Id> caseIds = new Set<Id>();
        for (FEC_Assignment__c assignment : newList) {
            FEC_Assignment__c oldAssignment = oldMap.get(assignment.Id);
            // tungnm37 fix: chỉ trigger khi Routing assignment (auto) thay đổi owner
            // tungnm37 fix: bỏ qua manual assignment (FEC_Manual__c = true)
            if (assignment.FEC_Assignment_Owner__c != oldAssignment.FEC_Assignment_Owner__c 
                && assignment.FEC_Case__c != null
                && assignment.FEC_Assignment_Type__c == FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING
                && assignment.FEC_Manual__c != true) {
                caseIds.add(assignment.FEC_Case__c);
            }
        }

        if (caseIds.isEmpty()) return;

        // tungnm37 fix: query thêm FEC_Assignment_Type__c và FEC_Manual__c để filter
        Map<Id, List<FEC_Assignment__c>> caseToAssignments = new Map<Id, List<FEC_Assignment__c>>();
        for (FEC_Assignment__c assignment : [
            SELECT Id, FEC_Case__c, FEC_Assignment_Owner__c, FEC_OwnerID__c, 
                   FEC_Assignment_Type__c, FEC_Manual__c
            FROM FEC_Assignment__c
            WHERE FEC_Case__c IN :caseIds
        ]) {
            if (!caseToAssignments.containsKey(assignment.FEC_Case__c)) {
                caseToAssignments.put(assignment.FEC_Case__c, new List<FEC_Assignment__c>());
            }
            caseToAssignments.get(assignment.FEC_Case__c).add(assignment);
        }

        // tungnm37 fix: chỉ query queues cho auto Routing assignments (không phải manual)
        Set<String> queueNamesNeeded = new Set<String>();
        for (List<FEC_Assignment__c> aList : caseToAssignments.values()) {
            for (FEC_Assignment__c a : aList) {
                // tungnm37 fix: chỉ xử lý auto Routing assignment (không phải manual)
                if (a.FEC_Assignment_Type__c == FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING 
                    && a.FEC_Manual__c != true
                    && String.isNotBlank(a.FEC_OwnerID__c) 
                    && a.FEC_Assignment_Owner__c == null) {
                    queueNamesNeeded.add(a.FEC_OwnerID__c);
                }
            }
        }
        Map<String, Id> queueNameToId = new Map<String, Id>();
        if (!queueNamesNeeded.isEmpty()) {
            for (Group g : [SELECT Id, Name FROM Group WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE AND Name IN :queueNamesNeeded]) {
                queueNameToId.put(g.Name, g.Id);
            }
        }

        List<Case> casesToUpdate = new List<Case>();
        for (Id caseId : caseToAssignments.keySet()) {
            Set<String> assignmentUserSet = new Set<String>();
            Boolean hasRoutingAssignment = false;
            
            for (FEC_Assignment__c assignment : caseToAssignments.get(caseId)) {
                // tungnm37 fix: chỉ xử lý auto Routing assignment (không phải manual)
                if (assignment.FEC_Assignment_Type__c == FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING
                    && assignment.FEC_Manual__c != true) {
                    hasRoutingAssignment = true;
                    if (assignment.FEC_Assignment_Owner__c != null) {
                        assignmentUserSet.add(String.valueOf(assignment.FEC_Assignment_Owner__c));
                    } else if (String.isNotBlank(assignment.FEC_OwnerID__c) && queueNameToId.containsKey(assignment.FEC_OwnerID__c)) {
                        assignmentUserSet.add(String.valueOf(queueNameToId.get(assignment.FEC_OwnerID__c)));
                    }
                }
            }
            
            // tungnm37 fix: nếu có Routing assignment thì set value, nếu không có (chỉ có General) thì set null
            if (hasRoutingAssignment && !assignmentUserSet.isEmpty()) {
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
