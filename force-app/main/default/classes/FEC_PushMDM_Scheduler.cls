public class FEC_PushMDM_Scheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new FEC_PushMDMToLiveBatch(), 1);
    }
}