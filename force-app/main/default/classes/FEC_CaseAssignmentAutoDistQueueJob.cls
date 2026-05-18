/**
 * Scheduled path: mỗi assignment chạy trong transaction Queueable riêng để không cộng SOQL governor
 * khi executeNow() có nhiều bản FEC_Case_Assignment__c Active cùng lúc.
 * Gọi lại luồng tương đương chạy tay (Active + tính runNumber từ log).
 */
public without sharing class FEC_CaseAssignmentAutoDistQueueJob implements Queueable {
    private final Id assignmentId;

    public FEC_CaseAssignmentAutoDistQueueJob(Id assignmentId) {
        this.assignmentId = assignmentId;
    }

    public void execute(QueueableContext qc) {
        FEC_CaseAssignmentAutoDistributeService.executeImmediatelyForAssignmentId(assignmentId);
    }
}
