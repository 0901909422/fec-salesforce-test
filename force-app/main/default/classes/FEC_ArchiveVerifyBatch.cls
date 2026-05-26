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
 * Xóa theo thứ tự:
 *   1. Tất cả custom child objects trong WHITELIST (dynamic scan)
 *   2. Case (ContentDocumentLink tự unlink)
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

    public static final Integer DEFAULT_BATCH_SIZE = 100;
    private static final Integer CLOSED_DAYS_THRESHOLD = 90;

    /**
     * WHITELIST — chỉ xóa các custom child objects được liệt kê ở đây.
     * Khi org thêm object mới cần archive, chỉ cần thêm vào set này.
     */
    @TestVisible
    private static final Set<String> CHILD_OBJECTS_WHITELIST = new Set<String>{
        'FEC_Case_Remarks__c',
        'FEC_ChatHistory__c'
        // Thêm objects khác khi cần, ví dụ:
        // 'FEC_Payment__c',
        // 'FEC_Document__c'
    };

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime threshold = System.now().addDays(-CLOSED_DAYS_THRESHOLD);
        System.debug('[FEC_ArchiveVerifyBatch] start() jobId=' + bc.getJobId()
            + ', threshold: ' + threshold);
        return Database.getQueryLocator([
            SELECT Id, CaseNumber, FEC_ID_Search__c
            FROM Case
            WHERE FEC_Archive_Status__c = :FEC_ConstantCommon.PROCESSING_STATUS
            AND (FEC_Attachment_Status__c = :FEC_ConstantCommon.STATUS_COMPLETED OR FEC_Attachment_Status__c = NULL)
            AND Status = :FEC_ConstantCommon.STATUS_CLOSED
            AND ClosedDate <= :threshold
            ORDER BY FEC_Archive_Sent_At__c ASC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Case> cases = (List<Case>) scope;
        totalChecked += cases.size();

        // ── [1] Gom caseIds ───────────────────────────────────────────────────
        List<String> caseIds = new List<String>();
        List<String> caseIdSearchs = new List<String>();
        Map<String, Case> caseById = new Map<String, Case>();
        for (Case c : cases) {
            caseIds.add(c.Id);
            caseById.put(c.Id, c);
            caseIdSearchs.add(c.FEC_ID_Search__c);
        }

        // ── [2] Gọi Java check Outbox status (gửi FEC_ID_Search__c) ────────
        Map<String, Id> searchIdToCaseId = new Map<String, Id>();
        for (Case c : cases) {
            searchIdToCaseId.put(c.FEC_ID_Search__c, c.Id);
        }

        Map<String, String> statusMap;
        try {
            statusMap = FEC_ArchiveVerifyHttpService.checkArchiveStatus(caseIdSearchs);
        } catch (Exception ex) {
            totalError += cases.size();
            System.debug(LoggingLevel.ERROR,
                '[FEC_ArchiveVerifyBatch] Callout failed, skip batch: '
                + ex.getMessage());
            return;
        }

        // ── [3] Partition ARCHIVED vs PENDING ─────────────────────────────────
        Set<Id> toDelete = new Set<Id>();

        for (String searchId : statusMap.keySet()) {
            Id sfCaseId = searchIdToCaseId.get(searchId);
            if (sfCaseId == null) {
                System.debug(LoggingLevel.WARN,
                    '[FEC_ArchiveVerifyBatch] Unknown searchId from API: ' + searchId);
                continue;
            }
            if ('ARCHIVED'.equals(statusMap.get(searchId))) {
                toDelete.add(sfCaseId);
            } else {
                totalPending++;
                System.debug('[FEC_ArchiveVerifyBatch] Still PENDING: '
                    + caseById.get(sfCaseId).CaseNumber);
            }
        }

        // ── [4] Xóa các case đã ARCHIVED ─────────────────────────────────────
        if (!toDelete.isEmpty()) {
            deleteCasesAndRelated(toDelete);
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('[FEC_ArchiveVerifyBatch] ═══ KẾT QUẢ ═══');
        System.debug('  Tổng check  : ' + totalChecked);
        System.debug('  Đã xóa      : ' + totalDeleted);
        System.debug('  Chờ tiếp    : ' + totalPending);
        System.debug('  Lỗi         : ' + totalError);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DYNAMIC DELETE — scan child relationships, chỉ xóa objects trong whitelist
    // ═══════════════════════════════════════════════════════════════════════════

    @TestVisible
    private void deleteCasesAndRelated(Set<Id> caseIds) {
        try {
            // ── Lưu docIds trước khi xóa Case ────────────────────────────────
            List<ContentDocumentLink> cdLinks = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :caseIds
            ];
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink cdl : cdLinks) {
                docIds.add(cdl.ContentDocumentId);
            }

            // ── Bước 1: Dynamic xóa tất cả child objects trong WHITELIST ─────
            deleteWhitelistedChildren(caseIds);

            // ── Bước 2: Xóa Case ─────────────────────────────────────────────
            List<Case> casesToDelete = [SELECT Id FROM Case WHERE Id IN :caseIds];
            delete casesToDelete;
            totalDeleted += casesToDelete.size();
            System.debug('[FEC_ArchiveVerifyBatch] Deleted '
                + casesToDelete.size() + ' cases');

            // ── Bước 3: Xóa orphan ContentDocument ───────────────────────────
            deleteOrphanContentDocuments(docIds);

        } catch (DmlException ex) {
            totalError++;
            System.debug(LoggingLevel.ERROR,
                '[FEC_ArchiveVerifyBatch] DML error: ' + ex.getMessage());
        }
    }

    /**
     * Scan tất cả child relationships của Case.
     * Chỉ xóa records thuộc objects có trong WHITELIST.
     * Dùng dynamic SOQL để không cần hardcode từng query.
     */
    private void deleteWhitelistedChildren(Set<Id> caseIds) {
        List<Schema.ChildRelationship> childRels = Schema.SObjectType.Case.getChildRelationships();

        for (Schema.ChildRelationship childRel : childRels) {
            Schema.SObjectType childType = childRel.getChildSObject();
            String childObjectName = childType.getDescribe().getName();

            // Chỉ xóa objects trong whitelist
            if (!CHILD_OBJECTS_WHITELIST.contains(childObjectName)) {
                continue;
            }

            // Skip nếu không có quyền xóa
            if (!childType.getDescribe().isDeletable()) {
                System.debug(LoggingLevel.WARN,
                    '[FEC_ArchiveVerifyBatch] No delete permission: ' + childObjectName);
                continue;
            }

            String childFieldName = childRel.getField().getDescribe().getName();

            try {
                String q = 'SELECT Id FROM ' + childObjectName
                    + ' WHERE ' + childFieldName + ' IN :caseIds';
                List<SObject> records = Database.query(q);

                if (!records.isEmpty()) {
                    List<Database.DeleteResult> results = Database.delete(records, false);
                    Integer deleteCount = 0;
                    for (Database.DeleteResult dr : results) {
                        if (dr.isSuccess()) {
                            deleteCount++;
                        } else {
                            System.debug(LoggingLevel.WARN,
                                '[FEC_ArchiveVerifyBatch] Failed to delete '
                                + childObjectName + ' record: '
                                + dr.getErrors()[0].getMessage());
                        }
                    }
                    System.debug('[FEC_ArchiveVerifyBatch] Deleted '
                        + deleteCount + '/' + records.size() + ' ' + childObjectName);
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN,
                    '[FEC_ArchiveVerifyBatch] Cannot delete ' + childObjectName
                    + ': ' + ex.getMessage());
            }
        }
    }

    /**
     * Xóa ContentDocument không còn link ở đâu khác (orphan).
     */
    private void deleteOrphanContentDocuments(Set<Id> docIds) {
        if (docIds.isEmpty()) {
            return;
        }

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
                + docs.size() + ' orphan ContentDocuments');
        }
    }

    // ── Static helpers ───────────────────────────────────────────────────────
    public static void run() {
        Database.executeBatch(new FEC_ArchiveVerifyBatch(), DEFAULT_BATCH_SIZE);
    }

    public static void run(Integer batchSize) {
        Database.executeBatch(new FEC_ArchiveVerifyBatch(), batchSize);
    }
}