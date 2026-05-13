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

    private static final String API_CREDENTIAL = 'callout:FECredit_Service';
    private static final String UPLOAD_PATH    = '/archival/dispatcher/api/v1/attachments/upload';
    private static final String BATCH_PATH     = '/archival/dispatcher/api/v1/attachments/batch';
    private static final Integer TIMEOUT_MS    = 120000;
    private static final Integer MAX_RETRY     = 2;

    /**
     * POST multipart/form-data lên Java API — giống Postman:
     *   caseId  (Text)   → field "caseId"
     *   files   (File[]) → field "files" (nhiều file cùng tên field)
     *
     * @param caseId      Salesforce Case Id
     * @param attachments List từ processAttachments(), mỗi item chứa: filename, contentType, blobData
     * @return Response body từ Java API (JSON chứa uploadedFiles)
     */
    public static String postAttachmentFiles(String caseId, List<Map<String, Object>> attachments) {
        String boundary = '----------------------------' + String.valueOf(DateTime.now().getTime());
        String footer = '--' + boundary + '--';

        // ── Build multipart body (binary-safe base64 merge) ───────────────
        // Kỹ thuật: pad header text cho đến khi base64 encode KHÔNG có '='
        // → đảm bảo align 3-byte boundary trước khi nối binary data.

        Blob bodyBlob = null;

        for (Integer i = 0; i < attachments.size(); i++) {
            Map<String, Object> att = attachments[i];
            String filename    = String.valueOf(att.get('filename'));
            String contentType = String.valueOf(att.get('contentType'));
            Blob   fileBlob    = (Blob) att.get('blobData');

            // ── Header: caseId part (chỉ lần đầu) + file part header ──
            String header = '';
            if (i == 0) {
                header += '--' + boundary + '\r\n'
                    + 'Content-Disposition: form-data; name="caseId"\r\n\r\n'
                    + caseId + '\r\n';
            }
            header += '--' + boundary + '\r\n'
                + 'Content-Disposition: form-data; name="files"; filename="' + filename + '"\r\n'
                + 'Content-Type: ' + contentType;

            // Pad header cho đến khi base64 không có '=' padding
            String headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header + '\r\n\r\n'));
            while (headerEncoded.endsWith('=')) {
                header += ' ';
                headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header + '\r\n\r\n'));
            }

            // Encode file binary
            String bodyEncoded = EncodingUtil.base64Encode(fileBlob);

            // ── Xử lý base64 padding của file body để merge với phần tiếp theo ──
            String last4Bytes = bodyEncoded.substring(bodyEncoded.length() - 4, bodyEncoded.length());
            Boolean isLastFile = (i == attachments.size() - 1);
            String tailText = isLastFile ? footer : '';  // file cuối → đóng boundary

            if (last4Bytes.endsWith('==')) {
                last4Bytes = last4Bytes.substring(0, 2) + '0K';
                bodyEncoded = bodyEncoded.substring(0, bodyEncoded.length() - 4) + last4Bytes;
                String tailEncoded = EncodingUtil.base64Encode(Blob.valueOf(tailText));
                Blob partBlob = EncodingUtil.base64Decode(headerEncoded + bodyEncoded + tailEncoded);
                bodyBlob = combineBlobs(bodyBlob, partBlob);
            } else if (last4Bytes.endsWith('=')) {
                last4Bytes = last4Bytes.substring(0, 3) + 'N';
                bodyEncoded = bodyEncoded.substring(0, bodyEncoded.length() - 4) + last4Bytes;
                tailText = '\n' + tailText;
                String tailEncoded = EncodingUtil.base64Encode(Blob.valueOf(tailText));
                Blob partBlob = EncodingUtil.base64Decode(headerEncoded + bodyEncoded + tailEncoded);
                bodyBlob = combineBlobs(bodyBlob, partBlob);
            } else {
                tailText = '\r\n' + tailText;
                String tailEncoded = EncodingUtil.base64Encode(Blob.valueOf(tailText));
                Blob partBlob = EncodingUtil.base64Decode(headerEncoded + bodyEncoded + tailEncoded);
                bodyBlob = combineBlobs(bodyBlob, partBlob);
            }
        }

        // ── Send request với retry ────────────────────────────────────────
        Integer attempt = 0;
        Integer lastStatus;
        String  lastBody;
        while (attempt <= MAX_RETRY) {
            attempt++;
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(API_CREDENTIAL + UPLOAD_PATH);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
                req.setHeader('X-API-KEY', 'RkVDX1NBTEVTRk9SQ0U=');
                req.setTimeout(TIMEOUT_MS);
                req.setBodyAsBlob(bodyBlob);

                HttpResponse res = new Http().send(req);
                lastStatus = res.getStatusCode();
                lastBody   = res.getBody();
                if (lastStatus >= 200 && lastStatus < 300) {
                    System.debug('[FEC_AttachmentExportHttpService] Upload OK caseId=' + caseId + ', HTTP ' + lastStatus);
                    return lastBody;
                }
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

    /**
     * Nối 2 Blob lại với nhau. Nếu existing == null thì trả về newPart.
     */
    private static Blob combineBlobs(Blob existing, Blob newPart) {
        if (existing == null) return newPart;
        // Nối qua hex string — an toàn cho binary
        String hexExisting = EncodingUtil.convertToHex(existing);
        String hexNew      = EncodingUtil.convertToHex(newPart);
        return EncodingUtil.convertFromHex(hexExisting + hexNew);
    }

    /**
     * POST metadata (s3Key, filename, fileSize) lên Java /batch endpoint.
     * 
     * Expected payload format:
     * [
     *   {
     *     "caseId": "500Az000...",
     *     "caseNumber": "00006390",
     *     "attachments": [
     *       { "s3Key": "case-files/21123/abc_file.png", "filename": "file.png", "fileSize": 137038 },
     *       ...
     *     ]
     *   }
     * ]
     */
    public static void postAttachments(List<Map<String, Object>> batchPayload) {

        String jsonPayload = JSON.serialize(batchPayload);
        Integer attempt = 0;
        Integer lastStatus;
        String  lastBody;

        while (attempt <= MAX_RETRY) {
            attempt++;
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(API_CREDENTIAL + BATCH_PATH);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setBody(jsonPayload);
                req.setTimeout(TIMEOUT_MS);
                req.setHeader('X-API-KEY', 'RkVDX1NBTEVTRk9SQ0U=');

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

    /**
     * Lấy danh sách file của Case, đẩy lên S3 và trả về Metadata
     * QUAN TRỌNG: Tuyệt đối KHÔNG chứa bất kỳ lệnh DML (insert, update, delete) nào trong hàm này.
     */
    public static List<Map<String, Object>> processAttachments(Id caseId) {
        List<Map<String, Object>> attachmentsMetadata = new List<Map<String, Object>>();

        // 1. Query các file đính kèm với Case thông qua ContentDocumentLink
        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :caseId
        ];

        // Nếu Case không có file nào, trả về list rỗng luôn
        if (cdls.isEmpty()) {
            return attachmentsMetadata; 
        }

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : cdls) {
            docIds.add(cdl.ContentDocumentId);
        }

        // 2. Lấy nội dung file (VersionData) và thông tin cơ bản
        // Lưu ý: VersionData chính là Blob data của file để bắn lên S3
        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, VersionData, ContentSize, CreatedDate, CreatedBy.Email 
            FROM ContentVersion 
            WHERE ContentDocumentId IN :docIds AND IsLatest = true
        ];

        for (ContentVersion cv : versions) {
            String ext = String.isNotBlank(cv.FileExtension) ? cv.FileExtension.toLowerCase() : '';
            String fileName = cv.Title + (String.isNotBlank(ext) ? '.' + ext : '');
            
            Map<String, Object> fileMeta = new Map<String, Object>{
                'filename'    => fileName,
                'contentType' => getContentType(ext),
                'fileSize'    => cv.ContentSize,
                'blobData'    => cv.VersionData // Lưu trực tiếp Blob ở đây
            };
            attachmentsMetadata.add(fileMeta);
        }
        return attachmentsMetadata;
    }

    /**
     * Hàm Helper: Ánh xạ File Extension sang Content-Type chuẩn
     */
    private static String getContentType(String ext) {
        if (String.isBlank(ext)) return 'application/octet-stream';
        
        switch on ext {
            when 'pdf'  { return 'application/pdf'; }
            when 'jpg', 'jpeg' { return 'image/jpeg'; }
            when 'png'  { return 'image/png'; }
            when 'gif'  { return 'image/gif'; }
            when 'doc'  { return 'application/msword'; }
            when 'docx' { return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'; }
            when 'xls'  { return 'application/vnd.ms-excel'; }
            when 'xlsx' { return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'; }
            when 'csv'  { return 'text/csv'; }
            when 'txt'  { return 'text/plain'; }
            when else   { return 'application/octet-stream'; }
        }
    }

    public class AttachmentCalloutException extends Exception {}
}