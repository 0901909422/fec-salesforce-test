/**
 * Scheduled path: mỗi assignment chạy trong transaction Queueable riêng để không cộng SOQL governor
 * khi executeNow() có nhiều bản FEC_Case_Assignment__c Active cùng lúc.
 * Gọi lại luồng tương đương chạy tay (Active + tính runNumber từ log).
 *
 * Chuỗi: execute() xử lý assignment đầu list, enqueue tối đa **một** job với phần còn lại.
 * Trong lúc xử lý head, suppress enqueue phụ từ Case trigger / handleQueueCasesAfterSave
 * để giữ slot chain (tránh "Too many queueable jobs: 2").
 */
public without sharing class FEC_CaseAssignmentAutoDistQueueJob implements Queueable {
    private final List<Id> assignmentIds;

    /** Cho phép test cover nhánh production chain (Test.isRunningTest() mặc định đi nhánh sync). */
    @TestVisible
    private static Boolean runProductionChainInTest = false;

    @TestVisible
    static void setRunProductionChainInTest(Boolean runProductionChain) {
        runProductionChainInTest = runProductionChain == true;
    }

    public FEC_CaseAssignmentAutoDistQueueJob(Id assignmentId) {
        this.assignmentIds = assignmentId != null ? new List<Id>{ assignmentId } : new List<Id>();
    }

    public FEC_CaseAssignmentAutoDistQueueJob(List<Id> assignmentIds) {
        this.assignmentIds =
            assignmentIds == null ? new List<Id>() : new List<Id>(assignmentIds);
    }

    public void execute(QueueableContext qc) {
        if (assignmentIds == null || assignmentIds.isEmpty()) {
            return;
        }

        // Test context: max chain depth = 1 — không enqueue tail; xử lý toàn bộ list trong một job.
        if (Test.isRunningTest() && !runProductionChainInTest) {
            FEC_CaseAssignmentAutoDistributeService.setSuppressAutoDistQueueEnqueue(true);
            try {
                for (Id assignmentId : assignmentIds) {
                    if (assignmentId != null) {
                        FEC_CaseAssignmentAutoDistributeService.executeImmediatelyForAssignmentId(
                            assignmentId
                        );
                    }
                }
            } finally {
                FEC_CaseAssignmentAutoDistributeService.setSuppressAutoDistQueueEnqueue(false);
            }
            return;
        }

        Id head = assignmentIds[0];
        // Không có SOQL ở đây — chỉ tách list (tránh enqueue >50/job); tail = bản clone bỏ phần tử đầu.
        List<Id> tail = assignmentIds.clone();
        if (!tail.isEmpty()) {
            tail.remove(0);
        }

        FEC_CaseAssignmentAutoDistributeService.setSuppressAutoDistQueueEnqueue(true);
        try {
            FEC_CaseAssignmentAutoDistributeService.executeImmediatelyForAssignmentId(head);
        } finally {
            FEC_CaseAssignmentAutoDistributeService.setSuppressAutoDistQueueEnqueue(false);
        }

        if (!tail.isEmpty() && FEC_CaseAssignmentAutoDistributeService.canEnqueueAutoDistQueueJob()) {
            System.enqueueJob(new FEC_CaseAssignmentAutoDistQueueJob(tail));
        }
    }
}