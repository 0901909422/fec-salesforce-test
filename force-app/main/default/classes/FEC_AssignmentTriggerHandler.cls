// tungnm37: Handler sync Case.FEC_Assignment_Users__c khi FEC_Assignment_Owner__c thay đổi
public without sharing class FEC_AssignmentTriggerHandler {

    public static void handleAfterUpdate(List<FEC_Assignment__c> newList, Map<Id, FEC_Assignment__c> oldMap) {
        Set<Id> caseIds = new Set<Id>();
        for (FEC_Assignment__c assignment : newList) {
            FEC_Assignment__c oldAssignment = oldMap.get(assignment.Id);
            if (assignment.FEC_Assignment_Owner__c != oldAssignment.FEC_Assignment_Owner__c && assignment.FEC_Case__c != null) {
                caseIds.add(assignment.FEC_Case__c);
            }
        }

        if (caseIds.isEmpty()) return;

        Map<Id, List<FEC_Assignment__c>> caseToAssignments = new Map<Id, List<FEC_Assignment__c>>();
        for (FEC_Assignment__c assignment : [
            SELECT Id, FEC_Case__c, FEC_Assignment_Owner__c, FEC_OwnerID__c
            FROM FEC_Assignment__c
            WHERE FEC_Case__c IN :caseIds
        ]) {
            if (!caseToAssignments.containsKey(assignment.FEC_Case__c)) {
                caseToAssignments.put(assignment.FEC_Case__c, new List<FEC_Assignment__c>());
            }
            caseToAssignments.get(assignment.FEC_Case__c).add(assignment);
        }

        List<Group> queues = [SELECT Id, Name FROM Group WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE];
        Map<String, Id> queueNameToId = new Map<String, Id>();
        for (Group g : queues) {
            queueNameToId.put(g.Name, g.Id);
        }

        List<Case> casesToUpdate = new List<Case>();
        for (Id caseId : caseToAssignments.keySet()) {
            Set<String> assignmentUserSet = new Set<String>();
            for (FEC_Assignment__c assignment : caseToAssignments.get(caseId)) {
                if (assignment.FEC_Assignment_Owner__c != null) {
                    assignmentUserSet.add(String.valueOf(assignment.FEC_Assignment_Owner__c));
                } else if (String.isNotBlank(assignment.FEC_OwnerID__c) && queueNameToId.containsKey(assignment.FEC_OwnerID__c)) {
                    assignmentUserSet.add(String.valueOf(queueNameToId.get(assignment.FEC_OwnerID__c)));
                }
            }
            if (!assignmentUserSet.isEmpty()) {
                casesToUpdate.add(new Case(Id = caseId, FEC_Assignment_Users__c = String.join(new List<String>(assignmentUserSet), ',')));
            }
        }

        if (!casesToUpdate.isEmpty()) {
            Database.update(casesToUpdate, AccessLevel.SYSTEM_MODE);
        }
    }
}
