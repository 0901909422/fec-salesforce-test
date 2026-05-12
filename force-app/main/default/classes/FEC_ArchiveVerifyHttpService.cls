/**
 * FEC_ArchiveVerifyHttpService
 * ─────────────────────────────────────────────────────────────────────────────
 * Gọi Java API để check trạng thái archive của nhiều Case cùng lúc.
 *
 * Request:  POST /api/v1/dispatcher/cases/archive-status
 *           { "caseIds": ["500A...", "500B...", ...] }
 *
 * Response: { "results": [ {"caseId": "500A...", "status": "ARCHIVED"},
 *                          {"caseId": "500B...", "status": "PENDING"} ] }
 * ─────────────────────────────────────────────────────────────────────────────
 */
public class FEC_ArchiveVerifyHttpService {

    private static final String API_CREDENTIAL = 'callout:FECredit_Service';
    private static final String PATH           = '/archival/dispatcher/api/v1/cases/archive-status';
    private static final Integer TIMEOUT_MS    = 30000;

    /**
     * @param caseIds  List Salesforce Case Id cần check
     * @return Map<CaseId, Status>  — status: "ARCHIVED" | "PENDING" | "FAILED"
     */
    public static Map<String, String> checkArchiveStatus(List<String> caseIds) {
        Map<String, Object> body = new Map<String, Object>{
            'caseIds' => caseIds
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(API_CREDENTIAL + PATH);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-API-KEY', 'RkVDX1NBTEVTRk9SQ0U=');
        req.setBody(JSON.serialize(body));
        req.setTimeout(TIMEOUT_MS);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new VerifyCalloutException(
                'Archive status API lỗi HTTP '
                + res.getStatusCode() + ': ' + res.getBody());
        }

        // Parse: { "code": 200, "data": { "results": [...] }, "message": "OK" }
        Map<String, Object> parsed =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Map<String, Object> data = (Map<String, Object>) parsed.get('data');
        List<Object> results = (List<Object>) data.get('results');
        
        Map<String, String> statusMap = new Map<String, String>();
        for (Object item : results) {
            Map<String, Object> entry = (Map<String, Object>) item;
            statusMap.put(
                (String) entry.get('caseId'),
                (String) entry.get('status')
            );
        }
        return statusMap;
    }

    public class VerifyCalloutException extends Exception {}
}