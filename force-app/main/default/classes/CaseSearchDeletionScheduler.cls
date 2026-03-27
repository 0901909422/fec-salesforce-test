public class CaseSearchDeletionScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        // Khởi tạo và chạy Batch với size mặc định là 200 bản ghi/lượt
        CaseSearchDeletionBatch batch = new CaseSearchDeletionBatch();
        Database.executeBatch(batch);
    }
}