/**
 * RL05.02 — hủy case trùng sau Route To (chạy ngoài transaction Submit để tránh SOQL 101).
 */
public class FEC_MrcDupCancelOnSubmitQueueJob implements Queueable {
    private final Id caseId;
    private final String customerConfirmation;
    private final String handlingOption;

    public FEC_MrcDupCancelOnSubmitQueueJob(Id caseId) {
        this(caseId, null, null);
    }

    public FEC_MrcDupCancelOnSubmitQueueJob(
        Id caseId,
        String customerConfirmation,
        String handlingOption
    ) {
        this.caseId = caseId;
        this.customerConfirmation = customerConfirmation;
        this.handlingOption = handlingOption;
    }

    public void execute(QueueableContext context) {
        FEC_MrcDuplicateCaseService.applyNotReceivedHandlingOptionOnSubmitNow(
            caseId,
            customerConfirmation,
            handlingOption
        );
        FEC_MrcDuplicateCaseService.applyReceivedConfirmationDuplicateCancelOnSubmit(
            caseId,
            customerConfirmation
        );
    }
}