/**
 * FEC_AttachmentExportHttpService
 * ─────────────────────────────────────────────────────────────────────────────
 * POST attachment metadata của 1 case lên Java endpoint.
 *
 * Payload:
 * {
 *   "caseId":      "500Az000...",
 *   "caseNumber":  "00006390",
 *   "attachments": [
 *     {
 *       "s3Key":       "cases/500Az.../attachments/uuid_contract.pdf",
 *       "filename":    "contract.pdf",
 *       "contentType": "application/pdf",
 *       "fileSize":    25600,
 *       "uploadedAt":  "2026-03-16T02:00:00Z",
 *       "uploadedBy":  "agent@fecredit.com.vn"
 *     }
 *   ]
 * }
 * ─────────────────────────────────────────────────────────────────────────────
 */
public class FEC_AttachmentExportHttpService {

    private static final String API_CREDENTIAL = 'callout:FEC_CaseExport_API';
    private static final String PATH           = '/api/v1/attachments/batch';
    private static final Integer TIMEOUT_MS    = 30000;
    private static final Integer MAX_RETRY     = 2;

    // Đổi tham số nhận vào thành 1 List
    public static void postAttachments(List<Map<String, Object>> batchPayload) {
        
        String jsonPayload = JSON.serialize(batchPayload);
        Integer attempt = 0;
        Integer lastStatus;
        String  lastBody;

        while (attempt <= MAX_RETRY) {
            attempt++;
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(API_CREDENTIAL + PATH);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setBody(jsonPayload);
                req.setTimeout(TIMEOUT_MS);

                HttpResponse res = new Http().send(req);
                lastStatus = res.getStatusCode();
                lastBody   = res.getBody();

                if (lastStatus >= 200 && lastStatus < 300) {
                    System.debug('[FEC_AttachmentExportHttpService] POST Bulk OK, HTTP ' + lastStatus);
                    return;
                }
                // (Phần catch/retry giữ nguyên như cũ của bạn)
                if (lastStatus >= 500) {
                    System.debug(LoggingLevel.WARN, '[FEC_AttachmentExportHttpService] Server error ' + lastStatus);
                } else {
                    throw new AttachmentCalloutException('HTTP ' + lastStatus + ': ' + lastBody);
                }

            } catch (Exception ex) {
                if (attempt > MAX_RETRY) throw ex;
            }
        }
        throw new AttachmentCalloutException('Thất bại sau ' + MAX_RETRY + ' retry. HTTP ' + lastStatus);
    }

    public class AttachmentCalloutException extends Exception {}
}