public class FEC_CaseExportHttpService {

    private static final String EXTERNAL_API_CREDENTIAL = 'https://sf-csm-service-dev.fecredit.cloud';
    private static final String CASES_PATH               = '/archival/dispatcher/api/v1/cases/ingest_archival';
    private static final Integer TIMEOUT_MS              = 60000;

    // Số lần retry khi gặp lỗi 5xx hoặc timeout
    private static final Integer MAX_RETRY = 2;

    /**
     * POST batch cases lên external API.
     * @param jsonPayload  JSON array: [ {case1}, {case2}, ... ]
     */
    public static void postCases(String jsonPayload) {
        Integer attempt = 0;
        Integer lastStatusCode;
        String  lastBody;

        while (attempt <= MAX_RETRY) {
            attempt++;
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(EXTERNAL_API_CREDENTIAL + CASES_PATH);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json; charset=UTF-8');
                req.setHeader('Accept',       'application/json');
                req.setHeader('X-API-KEY', 'RkVDX1NBTEVTRk9SQ0U=');
                req.setBody(jsonPayload);
                req.setTimeout(TIMEOUT_MS);

                HttpResponse res = new Http().send(req);
                lastStatusCode = res.getStatusCode();
                lastBody       = res.getBody();

                if (lastStatusCode >= 200 && lastStatusCode < 300) {
                    System.debug('[CaseExportHttpService] POST OK — HTTP '
                        + lastStatusCode + ' (attempt #' + attempt + ')');
                    return; // Thành công
                }

                if (lastStatusCode >= 500) {
                    // Lỗi server → retry
                    System.debug(LoggingLevel.WARN,
                        '[CaseExportHttpService] Server error ' + lastStatusCode
                        + ', attempt ' + attempt + '/' + MAX_RETRY);
                } else {
                    // Lỗi 4xx → không retry, throw ngay
                    throw new ExportCalloutException(
                        'HTTP ' + lastStatusCode + ' (không retry): ' + lastBody);
                }

            } catch (ExportCalloutException ex) {
                System.debug('[CaseExportHttpService] Callout exception: ' + ex.getMessage());
                throw ex;
            } catch (System.CalloutException ex) {
                System.debug(LoggingLevel.WARN,
                    '[CaseExportHttpService] Network error attempt '
                    + attempt + ': ' + ex.getMessage());
                if (attempt > MAX_RETRY) {
                    throw new ExportCalloutException(
                        'Callout lỗi sau ' + MAX_RETRY + ' lần retry: '
                        + ex.getMessage(), ex);
                }
            }
        }

        throw new ExportCalloutException(
            'POST thất bại sau ' + MAX_RETRY + ' lần retry. '
            + 'Last HTTP: ' + lastStatusCode + '. Body: ' + lastBody);
    }

    public class ExportCalloutException extends Exception {}
}