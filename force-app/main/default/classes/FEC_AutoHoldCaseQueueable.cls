public class FEC_AutoHoldCaseQueueable implements Queueable, Database.AllowsCallouts {
    private final Id routingHistoryId;

    public FEC_AutoHoldCaseQueueable(Id routingHistoryId) {
        this.routingHistoryId = routingHistoryId;
    }

    public void execute(QueueableContext context) {
        FEC_AutoHoldCaseService.processAutoHoldCase(routingHistoryId);
    }
}
