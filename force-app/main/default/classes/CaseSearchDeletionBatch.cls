public class CaseSearchDeletionBatch implements Database.Batchable<sObject> {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date targetDate = Date.today().addDays(-7);
        return Database.getQueryLocator([
            SELECT Id FROM Case 
            WHERE RecordType.Name = 'Search Interaction' 
            AND DAY_ONLY(CreatedDate) <= :targetDate
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Case> scope) {
        if (!scope.isEmpty()) {
            delete scope;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Đã hoàn thành dọn dẹp Case dựa trên ngày tạo.');
    }
}