/**
 * One-shot Schedulable: tiếp tục xích FEC_CaseAssignmentAutoDistQueueJob khi transaction
 * hiện tại đã dùng hết quota enqueue queueable (ví dụ trigger Case enqueue notification).
 */
public without sharing class FEC_CaseAssignmentAutoDistTailSched implements Schedulable {
    private final List<Id> assignmentIds;

    public FEC_CaseAssignmentAutoDistTailSched(List<Id> assignmentIds) {
        this.assignmentIds =
            assignmentIds == null ? new List<Id>() : new List<Id>(assignmentIds);
    }

    public void execute(SchedulableContext context) {
        if (!assignmentIds.isEmpty()) {
            System.enqueueJob(new FEC_CaseAssignmentAutoDistQueueJob(assignmentIds));
        }
        if (context != null && context.getTriggerId() != null) {
            System.abortJob(context.getTriggerId());
        }
    }
}
