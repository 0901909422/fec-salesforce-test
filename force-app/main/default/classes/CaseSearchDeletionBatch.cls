public class CaseSearchDeletionBatch implements Database.Batchable<sObject> {
    
    // Default: delete Case Search records older than 7 days
    private static final Integer RETENTION_DAYS = 7;
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        DateTime cutoffDate = DateTime.now().addDays(-RETENTION_DAYS);
        return Database.getQueryLocator([
            SELECT Id FROM Case 
            WHERE RecordType.DeveloperName = :FEC_ConstantCommon.CASE_SEARCH_RECORD_TYPE_DEV_NAME
            AND CreatedDate < :cutoffDate
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Case> scope) {
        if (!scope.isEmpty()) {
            delete scope;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Đã hoàn thành dọn dẹp Case Search records cũ hơn ' + RETENTION_DAYS + ' ngày.');
    }
}