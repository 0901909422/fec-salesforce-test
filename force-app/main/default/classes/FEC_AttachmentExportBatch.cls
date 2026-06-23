/**
 * FEC_AttachmentExportBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Batch 2 — chạy sau FEC_CaseExportBatch.
 * Pick up những Case đã Archive_Status = 'Processing' (Case đã gửi xong)
 * nhưng Attachment_Status còn null (chưa xử lý attachment).
 *
 * Per case:
 *   1. Query ContentDocumentLink → ContentVersion (chỉ metadata)
 *   2. Upload file lên Java theo từng chunk nhỏ (1-2 file/lần) → 1 case nhiều lần upload
 *   3. POST metadata lên Java /attachments/batch
 *   4. Update FEC_Attachment_Status__c = 'Completed'
 *
 * Batch size = 1 bắt buộc:
 *   Mỗi case có N file → ceil(N/chunkSize) callout upload + 1 POST
 *   Với chunkSize=2, ~49 file/case → ~25 upload + 1 POST = 26 callout (< 100)
 *   Chunk nhỏ giúp peak heap chỉ bằng vài file thay vì toàn bộ file của case.
 * ─────────────────────────────────────────────────────────────────────────────
 */
public class FEC_AttachmentExportBatch
        implements Database.Batchable<SObject>,
                   Database.AllowsCallouts,
                   Database.Stateful {

    private static final Integer CLOSED_DAYS_THRESHOLD = 90;
    private Integer success = 0;
    private Integer failed  = 0;

    @TestVisible private static final String STATUS_COMPLETED = 'Completed';
    @TestVisible private static final String STATUS_FAILED    = 'Failed';

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime threshold = System.now().addDays(-CLOSED_DAYS_THRESHOLD);
        System.debug('[FEC_AttachmentExportBatch] start() jobId=' + bc.getJobId()
            + ', threshold: ' + threshold);
        return Database.getQueryLocator([
            SELECT Id, CaseNumber, FEC_ID_Search__c
            FROM Case
            WHERE Status = :FEC_ConstantCommon.STATUS_CLOSED
            AND ClosedDate <= :threshold
            AND FEC_Archive_Status__c = :FEC_ConstantCommon.PROCESSING_STATUS
            AND FEC_Attachment_Status__c = NULL
            ORDER BY ClosedDate ASC
        ]);
        
    }

    // Size = 1: mỗi execute xử lý đúng 1 case để không vượt callout limit
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Case> cases = (List<Case>) scope;
        
        // List chứa payload gom chung để bắn API /batch
        List<Map<String, Object>> batchPayload = new List<Map<String, Object>>();
        
        // Phân loại Case nào thành công upload S3, Case nào lỗi
        List<Case> casesToMarkCompleted = new List<Case>();
        List<Case> casesToMarkFailed    = new List<Case>();
        // ── [1] Upload files lên Java API cho từng Case ───processAttachments ────────────────
        for (Case c : cases) {
            try {
                // Reset cho mỗi case
                List<Map<String, Object>> tempAttachmentResponses = new List<Map<String, Object>>();

                // Chỉ lấy METADATA (không load blob) để heap nhẹ
                List<Map<String, Object>> attachments = FEC_AttachmentExportHttpService.processAttachments(c.Id);

                // Gửi theo từng chunk nhỏ (1-2 file/lần) → mỗi lần chỉ giữ blob
                // của vài file trong heap. 1 case có thể có nhiều lần upload.
                Integer chunkSize = FEC_ConstantArchive.ATTACHMENT_UPLOAD_CHUNK_SIZE;
                for (Integer i = 0; i < attachments.size(); i += chunkSize) {
                    Integer endIdx = Math.min(i + chunkSize, attachments.size());
                    List<Map<String, Object>> chunk = new List<Map<String, Object>>();
                    for (Integer j = i; j < endIdx; j++) {
                        chunk.add(attachments[j]);
                    }

                    // Load blob cho riêng chunk này rồi upload
                    FEC_AttachmentExportHttpService.loadBlobs(chunk);
                    String uploadResponse = FEC_AttachmentExportHttpService.postAttachmentFiles(
                        String.valueOf(c.FEC_ID_Search__c),
                        chunk
                    );

                    // Parse response để lấy uploadedFiles metadata
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(uploadResponse);
                    Map<String, Object> data = (Map<String, Object>) responseMap.get('data');
                    List<Object> uploadedFiles = (List<Object>) data.get('uploadedFiles');

                    for (Object uf : uploadedFiles) {
                        Map<String, Object> fileInfo = (Map<String, Object>) uf;
                        tempAttachmentResponses.add(new Map<String, Object>{
                            'filename' => fileInfo.get('filename'),
                            's3Key'    => fileInfo.get('s3Key'),
                            'fileSize' => fileInfo.get('fileSize')
                        });
                    }

                    // QUAN TRỌNG (fix heap): chunk chứa THAM CHIẾU tới chính map
                    // trong `attachments`, nên blobData vừa load vẫn bị `attachments`
                    // giữ lại sau khi upload xong → blob của mọi chunk cộng dồn trong
                    // heap. Gỡ blobData ra để GC thu hồi ngay sau mỗi lần upload.
                    for (Map<String, Object> m : chunk) {
                        m.remove('blobData');
                    }
                }

                // Luôn add vào batchPayload — nếu không có file thì attachments = rỗng
                batchPayload.add(new Map<String, Object>{
                    'caseId'      => String.valueOf(c.FEC_ID_Search__c),
                    'caseNumber'  => c.CaseNumber,
                    'attachments' => tempAttachmentResponses
                });
                casesToMarkCompleted.add(new Case(
                    Id                        = c.Id,
                    FEC_Attachment_Status__c  = STATUS_COMPLETED
                ));
            } catch (Exception ex) {
                failed++;
                System.debug(LoggingLevel.ERROR, '[AttachmentExportBatch] Lỗi Upload Case ' + c.CaseNumber + ': ' + ex.getMessage());
                casesToMarkFailed.add(new Case(
                    Id                       = c.Id,
                    FEC_Attachment_Status__c = STATUS_FAILED
                ));
            }
        }

        // ── [2] POST metadata (s3Key, filename, fileSize) lên Java /batch ──
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