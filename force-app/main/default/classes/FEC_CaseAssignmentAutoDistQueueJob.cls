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
            enqueueChainContinuation(tail);
        }
    }

    /**
     * Một Queueable chỉ được enqueue thêm tối đa một job. Nếu executeImmediately đã tiêu slot
     * (trigger Case / routing history), lên lịch one-shot để tiếp tục phần còn lại.
     */
    public static void enqueueChainContinuation(List<Id> tail) {
        if (tail == null || tail.isEmpty()) {
            return;
        }
        if (Limits.getQueueableJobs() < 1) {
            System.enqueueJob(new FEC_CaseAssignmentAutoDistQueueJob(tail));
            return;
        }
        scheduleChainContinuation(tail);
    }

    private static void scheduleChainContinuation(List<Id> tail) {
        DateTime runAt = System.now().addSeconds(5);
        String uniqueName = 'FEC_CaseAsgDistTail:' + String.valueOf(runAt.getTime());
        String cronExpression = String.format(
            '{0} {1} {2} {3} {4} ? {5}',
            new List<String>{
                String.valueOf(runAt.second()),
                String.valueOf(runAt.minute()),
                String.valueOf(runAt.hour()),
                String.valueOf(runAt.day()),
                String.valueOf(runAt.month()),
                String.valueOf(runAt.year())
            }
        );
        System.schedule(
            uniqueName,
            cronExpression,
            new FEC_CaseAssignmentAutoDistTailSched(tail)
        );
    }
}