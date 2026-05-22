/**
 * Kích hoạt phân bổ Case Assignment ngay khi Status chuyển sang Active
 * (insert Active hoặc update từ trạng thái khác → Active).
 */
public without sharing class FEC_CaseAssignmentTriggerHandler {
    private static Boolean isDispatching = false;

    public static void handleAfterInsert(List<FEC_Case_Assignment__c> newList) {
        if (newList == null || newList.isEmpty()) {
            return;
        }
        Set<Id> assignmentIds = new Set<Id>();
        String active = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        for (FEC_Case_Assignment__c row : newList) {
            if (row.Id != null && row.FEC_Status__c == active) {
                assignmentIds.add(row.Id);
            }
        }
        enqueueImmediateDistribution(assignmentIds);
    }

    public static void handleAfterUpdate(
        List<FEC_Case_Assignment__c> newList,
        Map<Id, FEC_Case_Assignment__c> oldMap
    ) {
        if (newList == null || newList.isEmpty() || oldMap == null || oldMap.isEmpty()) {
            return;
        }
        Set<Id> assignmentIds = new Set<Id>();
        String active = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        for (FEC_Case_Assignment__c row : newList) {
            FEC_Case_Assignment__c oldRow = oldMap.get(row.Id);
            if (oldRow == null || row.Id == null) {
                continue;
            }
            String oldStatus = oldRow.FEC_Status__c;
            String newStatus = row.FEC_Status__c;
            if (newStatus == active && oldStatus != active) {
                assignmentIds.add(row.Id);
            }
        }
        enqueueImmediateDistribution(assignmentIds);
    }

    private static void enqueueImmediateDistribution(Set<Id> assignmentIds) {
        if (assignmentIds == null || assignmentIds.isEmpty() || isDispatching) {
            return;
        }
        isDispatching = true;
        try {
            List<Id> idList = new List<Id>(assignmentIds);
            if (FEC_BatchCaseHandlingImportService.isBatchImportApplyInProgress()) {
                for (Id assignmentId : idList) {
                    FEC_CaseAssignmentAutoDistributeService.executeImmediatelyForAssignmentId(assignmentId);
                }
                return;
            }
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                System.enqueueJob(new FEC_CaseAssignmentAutoDistQueueJob(idList));
            } else {
                FEC_CaseAssignmentAutoDistributeService.executeImmediatelyForAssignmentId(idList[0]);
            }
        } finally {
            isDispatching = false;
        }
    }
}
