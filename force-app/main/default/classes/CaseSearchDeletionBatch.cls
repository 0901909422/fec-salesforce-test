public class CaseSearchDeletionBatch implements Database.Batchable<sObject> {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id FROM Case 
            WHERE RecordType.DeveloperName = :FEC_ConstantCommon.CASE_SEARCH_RECORD_TYPE_DEV_NAME
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