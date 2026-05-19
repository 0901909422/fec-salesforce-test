/**
 * Scheduled path: mỗi assignment chạy trong transaction Queueable riêng để không cộng SOQL governor
 * khi executeNow() có nhiều bản FEC_Case_Assignment__c Active cùng lúc.
 * Gọi lại luồng tương đương chạy tay (Active + tính runNumber từ log).
 *
 * Chuỗi: execute() xử lý assignment đầu list, enqueue tối đa **một** job với phần còn lại —
 * tránh "Too many queueable jobs" khi Scheduler gom nhiều assignment due trong một tick.
 */
public without sharing class FEC_CaseAssignmentAutoDistQueueJob implements Queueable {
    private final List<Id> assignmentIds;

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

        Id head = assignmentIds[0];
        // Không có SOQL ở đây — chỉ tách list (tránh enqueue >50/job); tail = bản clone bỏ phần tử đầu.
        List<Id> tail = assignmentIds.clone();
        if (!tail.isEmpty()) {
            tail.remove(0);
        }

        FEC_CaseAssignmentAutoDistributeService.executeImmediatelyForAssignmentId(head);

        if (!tail.isEmpty()) {
            System.enqueueJob(new FEC_CaseAssignmentAutoDistQueueJob(tail));
        }
    }
}
