public with sharing class FEC_ConstantArchive {

    // ── API Auth & Headers ───────────────────────────────────────────────────
    public static final String API_CONTENT_TYPE_MULTIPART = 'multipart/form-data; boundary=';

    // ── API Base URL (Named Credential: FEC_API) ─────────────────────────────
    public static final String API_BASE_URL = 'callout:FEC_API';


    // ── API Endpoint Paths ───────────────────────────────────────────────────
    public static final String PATH_CASES_INGEST_ARCHIVAL = '/api/v1/cases/ingest_archival';
    public static final String PATH_CASES_ARCHIVE_STATUS  = '/api/v1/cases/archive-status';
    public static final String PATH_ATTACHMENTS_UPLOAD    = '/api/v1/attachments/upload';
    public static final String PATH_ATTACHMENTS_BATCH     = '/api/v1/attachments/batch';
}
