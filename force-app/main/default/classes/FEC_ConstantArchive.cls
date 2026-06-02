public with sharing class FEC_ConstantArchive {

    // ── API Auth & Headers ───────────────────────────────────────────────────
    public static final String X_API_KEY_ARCHIVE = 'RkVDX1NBTEVTRk9SQ0U=';
    public static final String API_CONTENT_TYPE_MULTIPART = 'multipart/form-data; boundary=';

    // ── API Base URL ─────────────────────────────────────────────────────────
    public static final String API_BASE_URL = 'https://sf-csm-service-dev.fecredit.cloud';

    // ── API Path Prefix ──────────────────────────────────────────────────────
    public static final String API_PATH_PREFIX = '/dispatcher/api/v1';

    // ── API Endpoint Paths ───────────────────────────────────────────────────
    public static final String PATH_CASES_INGEST_ARCHIVAL = API_PATH_PREFIX + '/cases/ingest_archival';
    public static final String PATH_CASES_ARCHIVE_STATUS  = API_PATH_PREFIX + '/cases/archive-status';
    public static final String PATH_ATTACHMENTS_UPLOAD    = API_PATH_PREFIX + '/attachments/upload';
    public static final String PATH_ATTACHMENTS_BATCH     = API_PATH_PREFIX + '/attachments/batch';
}
