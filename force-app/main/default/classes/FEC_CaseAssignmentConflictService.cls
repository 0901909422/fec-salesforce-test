public without sharing class FEC_CaseAssignmentConflictService {
    private static final String DUPLICATE_NOC_ERROR =
        'Queue đang chọn đã có 1 quy tắc phân bổ đối với Nature of Case này.';

    public static void validateNocConflicts(
        List<FEC_Case_Assignment_NOC__c> newList,
        Map<Id, FEC_Case_Assignment_NOC__c> oldMap
    ) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        Set<Id> assignmentIds = new Set<Id>();
        for (FEC_Case_Assignment_NOC__c noc : newList) {
            if (noc.FEC_Case_Assignment_Name__c != null && isRelevantChange(noc, oldMap)) {
                assignmentIds.add(noc.FEC_Case_Assignment_Name__c);
            }
        }
        if (assignmentIds.isEmpty()) {
            return;
        }

        Map<Id, FEC_Case_Assignment__c> currentAssignments = new Map<Id, FEC_Case_Assignment__c>([
            SELECT Id, FEC_Select_Queues__c
            FROM FEC_Case_Assignment__c
            WHERE Id IN :assignmentIds
        ]);
        if (currentAssignments.isEmpty()) {
            return;
        }

        // Overlap check only considers NOC rows whose parent Case Assignment is Active (not Draft/Archived).
        Map<String, List<ActiveNocInfo>> activeNocByKey = queryActiveNocByKey(currentAssignments.keySet());
        if (activeNocByKey.isEmpty()) {
            return;
        }

        for (FEC_Case_Assignment_NOC__c noc : newList) {
            FEC_Case_Assignment__c currentAssignment = currentAssignments.get(noc.FEC_Case_Assignment_Name__c);
            if (currentAssignment == null || !isRelevantChange(noc, oldMap)) {
                continue;
            }

            Set<String> currentQueues = extractQueues(currentAssignment.FEC_Select_Queues__c);
            if (currentQueues.isEmpty()) {
                continue;
            }

            String nocKey = buildNocKey(noc);
            List<ActiveNocInfo> activeNocs = activeNocByKey.get(nocKey);
            if (activeNocs == null || activeNocs.isEmpty()) {
                continue;
            }

            for (ActiveNocInfo activeNoc : activeNocs) {
                if (hasQueueOverlap(currentQueues, activeNoc.queues)) {
                    noc.addError(DUPLICATE_NOC_ERROR);
                    break;
                }
            }
        }
    }

    private static Boolean isRelevantChange(
        FEC_Case_Assignment_NOC__c noc,
        Map<Id, FEC_Case_Assignment_NOC__c> oldMap
    ) {
        if (oldMap == null || !oldMap.containsKey(noc.Id)) {
            return true;
        }
        FEC_Case_Assignment_NOC__c oldNoc = oldMap.get(noc.Id);
        return noc.FEC_Case_Assignment_Name__c != oldNoc.FEC_Case_Assignment_Name__c ||
            noc.FEC_Product_Type__c != oldNoc.FEC_Product_Type__c ||
            noc.FEC_Category__c != oldNoc.FEC_Category__c ||
            noc.FEC_Sub_Category__c != oldNoc.FEC_Sub_Category__c ||
            noc.FEC_Sub_Code__c != oldNoc.FEC_Sub_Code__c;
    }

    private static Map<String, List<ActiveNocInfo>> queryActiveNocByKey(Set<Id> excludedAssignmentIds) {
        Map<String, List<ActiveNocInfo>> activeNocByKey = new Map<String, List<ActiveNocInfo>>();
        String statusActive = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;

        for (FEC_Case_Assignment_NOC__c noc : [
            SELECT
                Id,
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_Sub_Category__c,
                FEC_Sub_Code__c,
                FEC_Case_Assignment_Name__c,
                FEC_Case_Assignment_Name__r.FEC_Select_Queues__c
            FROM FEC_Case_Assignment_NOC__c
            WHERE
                FEC_Case_Assignment_Name__c != null
                AND FEC_Case_Assignment_Name__r.FEC_Status__c = :statusActive
                AND FEC_Case_Assignment_Name__c NOT IN :excludedAssignmentIds
        ]) {
            Set<String> queues = extractQueues(noc.FEC_Case_Assignment_Name__r.FEC_Select_Queues__c);
            if (queues.isEmpty()) {
                continue;
            }

            String nocKey = buildNocKey(noc);
            if (!activeNocByKey.containsKey(nocKey)) {
                activeNocByKey.put(nocKey, new List<ActiveNocInfo>());
            }
            activeNocByKey.get(nocKey).add(new ActiveNocInfo(queues));
        }
        return activeNocByKey;
    }

    private static String buildNocKey(FEC_Case_Assignment_NOC__c noc) {
        return String.valueOf(noc.FEC_Product_Type__c) + '|' +
            String.valueOf(noc.FEC_Category__c) + '|' +
            String.valueOf(noc.FEC_Sub_Category__c) + '|' +
            String.valueOf(noc.FEC_Sub_Code__c);
    }

    private static Set<String> extractQueues(String queueRawValue) {
        Set<String> queues = new Set<String>();
        if (String.isBlank(queueRawValue)) {
            return queues;
        }
        for (String item : queueRawValue.split('[;,\\n]')) {
            String normalized = item == null ? null : item.trim().toLowerCase();
            if (String.isNotBlank(normalized)) {
                queues.add(normalized);
            }
        }
        return queues;
    }

    private static Boolean hasQueueOverlap(Set<String> left, Set<String> right) {
        for (String item : left) {
            if (right.contains(item)) {
                return true;
            }
        }
        return false;
    }

    private class ActiveNocInfo {
        public Set<String> queues;

        public ActiveNocInfo(Set<String> queueSet) {
            this.queues = queueSet;
        }
    }
}