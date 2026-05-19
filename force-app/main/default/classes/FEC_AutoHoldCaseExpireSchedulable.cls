public inherited sharing class FEC_AutoHoldCaseExpireSchedulable implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new FEC_AutoHoldCaseExpireBatch(), 50);
    }
}
