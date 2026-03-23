/**
 * FEC_AttachmentExportBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Batch 2 — chạy sau FEC_CaseExportBatch.
 * Pick up những Case đã Archive_Status = 'Processing' (Case đã gửi xong)
 * nhưng Attachment_Status còn null (chưa xử lý attachment).
 *
 * Per case:
 *   1. Query ContentDocumentLink → ContentVersion
 *   2. Presign → Upload từng file lên S3
 *   3. POST metadata lên Java /attachments/batch
 *   4. Update FEC_Attachment_Status__c = 'Completed'
 *
 * Batch size = 1 bắt buộc:
 *   Mỗi case có N file → N×2 callout (presign + PUT) + 1 POST
 *   Giới hạn 100 callout/transaction → size=1 an toàn cho ~49 file/case
 * ─────────────────────────────────────────────────────────────────────────────
 */
public class FEC_AttachmentExportBatch
        implements Database.Batchable<SObject>,
                   Database.AllowsCallouts,
                   Database.Stateful {

    private Integer success = 0;
    private Integer failed  = 0;

    @TestVisible private static final String STATUS_COMPLETED = 'Completed';
    @TestVisible private static final String STATUS_FAILED    = 'Failed';

    // Chỉ query Case đã gửi xong (Processing) nhưng attachment chưa xử lý
    private static final String QUERY =
        'SELECT Id, CaseNumber ' +
        'FROM Case ' +
        'WHERE FEC_Archive_Status__c = \'Processing\' ' +
        '  AND FEC_Attachment_Status__c = NULL ' +
        'ORDER BY LastModifiedDate ASC';

    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('[FEC_AttachmentExportBatch] start() jobId=' + bc.getJobId());
        return Database.getQueryLocator(QUERY);
    }

    // Size = 1: mỗi execute xử lý đúng 1 case để không vượt callout limit
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Case> cases = (List<Case>) scope;
        
        // List chứa payload gom chung để bắn API /batch
        List<Map<String, Object>> batchPayload = new List<Map<String, Object>>();
        
        // Phân loại Case nào thành công upload S3, Case nào lỗi
        List<Case> casesToMarkCompleted = new List<Case>();
        List<Case> casesToMarkFailed    = new List<Case>();

        // ── [1] Upload file lên S3 cho từng Case ─────────────────────────────
        for (Case c : cases) {
            try {
                // Sẽ tiêu tốn callout tại đây (2 callout / 1 file)
                List<Map<String, Object>> attachments = FEC_CaseAttachmentService.processAttachments(c.Id);
                
                // Gom metadata lại chờ bắn API sau
                batchPayload.add(new Map<String, Object>{
                    'caseId'      => String.valueOf(c.Id),
                    'caseNumber'  => c.CaseNumber,
                    'attachments' => attachments
                });

                casesToMarkCompleted.add(new Case(
                    Id                        = c.Id,
                    FEC_Attachment_Status__c  = STATUS_COMPLETED,
                    FEC_Attachment_Sent_At__c = System.now()
                ));
            } catch (Exception ex) {
                failed++;
                System.debug(LoggingLevel.ERROR, '[AttachmentExportBatch] Lỗi Upload S3 Case ' + c.CaseNumber + ': ' + ex.getMessage());
                casesToMarkFailed.add(new Case(
                    Id                       = c.Id,
                    FEC_Attachment_Status__c = STATUS_FAILED,
                    FEC_Attachment_Error__c  = ex.getMessage().abbreviate(255)
                ));
            }
        }

        // ── [2] POST list metadata lên Java (Chỉ tốn 1 Callout) ────────────────
        if (!batchPayload.isEmpty()) {
            try {
                FEC_AttachmentExportHttpService.postAttachments(batchPayload);
                
                // Chỉ update Cờ Completed trên Salesforce NẾU gọi Java Bulk POST thành công
                update casesToMarkCompleted;
                success += casesToMarkCompleted.size();
                
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, '[AttachmentExportBatch] Lỗi POST Bulk Metadata: ' + ex.getMessage());
                // Chú ý: Không update `casesToMarkCompleted` để các Case này chạy lại vào lần batch sau
            }
        }

        // ── [3] Cập nhật cờ cho các Case bị lỗi Upload S3 ────────────────────
        if (!casesToMarkFailed.isEmpty()) {
            // Dùng Database.update với allOrNone = false để không hỏng cả mẻ
            Database.update(casesToMarkFailed, false); 
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('[FEC_AttachmentExportBatch] ═══ KẾT QUẢ ═══');
        System.debug('  OK     : ' + success);
        System.debug('  FAILED : ' + failed);
    }

    public static void run() {
        Database.executeBatch(new FEC_AttachmentExportBatch(), 1);
    }
}