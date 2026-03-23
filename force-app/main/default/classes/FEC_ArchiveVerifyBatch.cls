/**
 * FEC_ArchiveVerifyBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Batch 3 — check Outbox SENT trên Java, nếu xong thì xóa Case + related.
 *
 * Điều kiện pick up:
 *   - Archive_Status  = 'Processing'     → Batch 1 đã gửi xong
 *   - Attachment_Status = 'Completed'
 *     OR Attachment_Status = NULL        → Batch 2 đã xong (hoặc không có file)
 *
 * Xóa theo thứ tự tránh constraint:
 *   1. FEC_Case_Remarks__c
 *   2. Case  (ContentDocumentLink tự unlink)
 *   3. ContentDocument orphan (không còn link ở đâu khác)
 * ─────────────────────────────────────────────────────────────────────────────
 */
public class FEC_ArchiveVerifyBatch
        implements Database.Batchable<SObject>,
                   Database.AllowsCallouts,
                   Database.Stateful {

    private Integer totalChecked = 0;
    private Integer totalDeleted = 0;
    private Integer totalPending = 0;
    private Integer totalError   = 0;

    public static final Integer DEFAULT_BATCH_SIZE = 50;

    private static final String QUERY =
        'SELECT Id, CaseNumber ' +
        'FROM Case ' +
        'WHERE FEC_Archive_Status__c = \'Processing\' ' +
        '  AND (FEC_Attachment_Status__c = \'Completed\' ' +
        '       OR FEC_Attachment_Status__c =  \'Completed\') ' +
        'ORDER BY FEC_Archive_Sent_At__c ASC';

    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('[FEC_ArchiveVerifyBatch] start() jobId=' + bc.getJobId());
        return Database.getQueryLocator(QUERY);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Case> cases = (List<Case>) scope;
        totalChecked += cases.size();

        // ── [1] Gom caseIds ───────────────────────────────────────────────────
        List<String> caseIds = new List<String>();
        Map<String, Case> caseById = new Map<String, Case>();
        for (Case c : cases) {
            caseIds.add(c.Id);
            caseById.put(c.Id, c);
        }

        // ── [2] Gọi Java check Outbox status ─────────────────────────────────
        Map<String, String> statusMap;
        try {
            statusMap = FEC_ArchiveVerifyHttpService.checkArchiveStatus(caseIds);
        } catch (Exception ex) {
            totalError += cases.size();
            System.debug(LoggingLevel.ERROR,
                '[FEC_ArchiveVerifyBatch] Callout failed, skip batch: '
                + ex.getMessage());
            return;
        }

        // ── [3] Partition SENT vs PENDING ─────────────────────────────────────
        Set<Id> toDelete     = new Set<Id>();
        Set<Id> pendingDocIds = new Set<Id>();

        for (String caseId : statusMap.keySet()) {
            if ('SENT'.equals(statusMap.get(caseId))) {
                toDelete.add((Id) caseId);
            } else {
                totalPending++;
                System.debug('[FEC_ArchiveVerifyBatch] Still PENDING: '
                    + caseById.get(caseId).CaseNumber);
            }
        }

        // ── [4] Xóa các case đã SENT ──────────────────────────────────────────
        if (!toDelete.isEmpty()) {
            deleteCasesAndRelated(toDelete);
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('[FEC_ArchiveVerifyBatch] ═══ KẾT QUẢ ═══');
        System.debug('  Tổng check  : ' + totalChecked);
        System.debug('  Đã xóa      : ' + totalDeleted);
        System.debug('  Chờ tiếp    : ' + totalPending);
        System.debug('  Lỗi callout : ' + totalError);
    }

    // ── Xóa theo đúng thứ tự tránh lỗi constraint ────────────────────────────
    @TestVisible
    private void deleteCasesAndRelated(Set<Id> caseIds) {
        try {
            // Lưu lại docIds trước khi xóa Case
            List<ContentDocumentLink> cdLinks = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :caseIds
            ];
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink cdl : cdLinks) {
                docIds.add(cdl.ContentDocumentId);
            }

            // Bước 1: Xóa FEC_Case_Remarks__c
            List<FEC_Case_Remarks__c> remarks = [
                SELECT Id FROM FEC_Case_Remarks__c
                WHERE FEC_Case__c IN :caseIds
            ];
            if (!remarks.isEmpty()) {
                delete remarks;
                System.debug('[FEC_ArchiveVerifyBatch] Deleted '
                    + remarks.size() + ' remarks');
            }

            // Bước 2: Xóa Case (ContentDocumentLink tự unlink)
            List<Case> casesToDelete = [
                SELECT Id FROM Case WHERE Id IN :caseIds
            ];
            delete casesToDelete;
            totalDeleted += casesToDelete.size();
            System.debug('[FEC_ArchiveVerifyBatch] Deleted '
                + casesToDelete.size() + ' cases');

            // Bước 3: Xóa ContentDocument không còn link ở đâu khác
            if (!docIds.isEmpty()) {
                List<ContentDocumentLink> remaining = [
                    SELECT ContentDocumentId
                    FROM ContentDocumentLink
                    WHERE ContentDocumentId IN :docIds
                ];
                Set<Id> stillLinked = new Set<Id>();
                for (ContentDocumentLink cdl : remaining) {
                    stillLinked.add(cdl.ContentDocumentId);
                }

                Set<Id> orphans = new Set<Id>(docIds);
                orphans.removeAll(stillLinked);

                if (!orphans.isEmpty()) {
                    List<ContentDocument> docs = [
                        SELECT Id FROM ContentDocument WHERE Id IN :orphans
                    ];
                    delete docs;
                    System.debug('[FEC_ArchiveVerifyBatch] Deleted '
                        + docs.size() + ' ContentDocuments');
                }
            }

        } catch (DmlException ex) {
            totalError++;
            System.debug(LoggingLevel.ERROR,
                '[FEC_ArchiveVerifyBatch] DML error: ' + ex.getMessage());
        }
    }

    public static void run() {
        Database.executeBatch(new FEC_ArchiveVerifyBatch(), DEFAULT_BATCH_SIZE);
    }

    public static void run(Integer batchSize) {
        Database.executeBatch(new FEC_ArchiveVerifyBatch(), batchSize);
    }
} 