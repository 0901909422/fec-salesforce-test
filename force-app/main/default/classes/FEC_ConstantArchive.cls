public with sharing class FEC_ConstantArchive {

    // ── API Auth & Headers ───────────────────────────────────────────────────
    public static final String API_CONTENT_TYPE_MULTIPART = 'multipart/form-data; boundary=';

    // ── API Base URL (Named Credential: FEC_API) ─────────────────────────────
    public static final String API_BASE_URL = 'callout:FEC_API';


    // ── Attachment upload ────────────────────────────────────────────────────
    // Số file gửi mỗi lần callout upload. Giữ nhỏ (1-2) để peak heap chỉ bằng
    // kích thước vài file thay vì toàn bộ file của case.
    public static final Integer ATTACHMENT_UPLOAD_CHUNK_SIZE = 1;

    // ── API Endpoint Paths ───────────────────────────────────────────────────
    public static final String PATH_CASES_INGEST_ARCHIVAL = '/dispatcher/api/v1/cases/ingest_archival';
    public static final String PATH_CASES_ARCHIVE_STATUS  = '/dispatcher/api/v1/cases/archive-status';
    public static final String PATH_ATTACHMENTS_UPLOAD    = '/dispatcher/api/v1/attachments/upload';
    public static final String PATH_ATTACHMENTS_BATCH     = '/dispatcher/api/v1/attachments/batch';
}
