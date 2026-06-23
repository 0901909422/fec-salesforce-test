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

        // ── Build multipart body (binary-safe base64 merge) ───────────────
        // Kỹ thuật: pad header text cho đến khi base64 encode KHÔNG có '='
        // → đảm bảo align 3-byte boundary trước khi nối binary data.
        //
        // Heap-safe: gom các phần base64 (đã align 3-byte) vào 1 String rồi
        // decode DUY NHẤT 1 lần ở cuối.
        //
        // QUAN TRỌNG (fix multi-file): TUYỆT ĐỐI không được encode phần phân
        // cách (\r\n) thành 1 base64 segment riêng rồi nối vào giữa chuỗi —
        // vì base64('\r\n')='DQo=' / base64('\n')='Cg==' có ký tự '=' nằm
        // GIỮA chuỗi → base64Decode 1 lần ở cuối sẽ hỏng → body multipart sai
        // → Java báo "Failed to parse multipart servlet request".
        //
        // Giải pháp: phần phân cách cần thiết được đẩy vào HEADER của part kế
        // tiếp (header luôn được pad space → 3-byte aligned). Trick 0K/N chỉ
        // lo việc nhúng CRLF ngay sau binary để giữ alignment.

        String bodyEncodedAll = '';
        String pendingPrefix  = '';  // phân cách phải đứng trước header part kế tiếp

        for (Integer i = 0; i < attachments.size(); i++) {
            Map<String, Object> att = attachments[i];
            String filename    = String.valueOf(att.get('filename'));
            String contentType = String.valueOf(att.get('contentType'));
            Blob   fileBlob    = (Blob) att.get('blobData');

            // ── Header: pendingPrefix + caseId part (chỉ lần đầu) + file part header ──
            String header = pendingPrefix;
            if (i == 0) {
                header += '--' + boundary + '\r\n'
                    + 'Content-Disposition: form-data; name="caseId"\r\n\r\n'
                    + caseId + '\r\n';
            }
            header += '--' + boundary + '\r\n'
                + 'Content-Disposition: form-data; name="files"; filename="' + filename + '"\r\n'
                + 'Content-Type: ' + contentType;

            // Pad header cho đến khi base64 không có '=' padding (3-byte aligned)
            String headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header + '\r\n\r\n'));
            while (headerEncoded.endsWith('=')) {
                header += ' ';
                headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header + '\r\n\r\n'));
            }

            // Encode file binary
            String bodyEncoded = EncodingUtil.base64Encode(fileBlob);

            // ── Trick 0K/N: nhúng CRLF sau binary + giữ alignment; phần phân
            //    cách còn thiếu được giao cho header part kế tiếp (pendingPrefix) ──
            String last4Bytes = bodyEncoded.substring(bodyEncoded.length() - 4, bodyEncoded.length());
            if (last4Bytes.endsWith('==')) {
                // last group 1 byte: '0K' nhúng nguyên '\r\n' → không cần thêm
                bodyEncoded = bodyEncoded.substring(0, bodyEncoded.length() - 4)
                    + last4Bytes.substring(0, 2) + '0K';
                pendingPrefix = '';
            } else if (last4Bytes.endsWith('=')) {
                // last group 2 byte: 'N' nhúng '\r' → còn thiếu '\n'
                bodyEncoded = bodyEncoded.substring(0, bodyEncoded.length() - 4)
                    + last4Bytes.substring(0, 3) + 'N';
                pendingPrefix = '\n';
            } else {
                // last group đủ 3 byte: không nhúng gì → cần cả '\r\n'
                pendingPrefix = '\r\n';
            }

            bodyEncodedAll += headerEncoded + bodyEncoded;
        }

        // Đóng body: pendingPrefix (phần CRLF còn thiếu của file cuối) + boundary kết thúc.
        // Đoạn này nằm ở CUỐI chuỗi nên '=' padding (nếu có) là hợp lệ.
        String footer = pendingPrefix + '--' + boundary + '--';
        bodyEncodedAll += EncodingUtil.base64Encode(Blob.valueOf(footer));

        // Decode toàn bộ base64 đã gom (đã align 3-byte) thành body 1 lần duy nhất
        Blob bodyBlob = EncodingUtil.base64Decode(bodyEncodedAll);

        // ── Send request với retry ────────────────────────────────────────
        String endpoint = FEC_ConstantArchive.API_BASE_URL + FEC_ConstantArchive.PATH_ATTACHMENTS_UPLOAD;

        // Gom thông tin file đã gửi để log khi lỗi (filename + size)
        List<String> fileInfoForLog = new List<String>();
        for (Map<String, Object> att : attachments) {
            fileInfoForLog.add(String.valueOf(att.get('filename'))
                + ' (' + String.valueOf(att.get('fileSize')) + ' bytes)');
        }

        Integer attempt = 0;
        Integer lastStatus;
        String  lastBody;
        while (attempt <= MAX_RETRY) {
            attempt++;
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(endpoint);
                req.setMethod(FEC_ConstantCommon.API_METHOD_POST);
                req.setHeader('Content-Type', FEC_ConstantArchive.API_CONTENT_TYPE_MULTIPART + boundary);
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
                    System.debug(LoggingLevel.WARN, '── Thông tin API đã gọi (postAttachmentFiles) ──');
                    System.debug(LoggingLevel.WARN, '  Endpoint    : ' + FEC_ConstantCommon.API_METHOD_POST + ' ' + endpoint);
                    System.debug(LoggingLevel.WARN, '  Content-Type: ' + FEC_ConstantArchive.API_CONTENT_TYPE_MULTIPART + boundary);
                    System.debug(LoggingLevel.WARN, '  Timeout(ms) : ' + TIMEOUT_MS);
                    System.debug(LoggingLevel.WARN, '  Attempt     : ' + attempt + '/' + (MAX_RETRY + 1));
                    System.debug(LoggingLevel.WARN, '  caseId      : ' + caseId);
                    System.debug(LoggingLevel.WARN, '  So file     : ' + attachments.size());
                    System.debug(LoggingLevel.WARN, '  Body size   : ' + bodyBlob.size() + ' bytes');
                    System.debug(LoggingLevel.WARN, '  HTTP status : ' + lastStatus);
                    debugLongText('  Response', lastBody);
                    for (String fi : fileInfoForLog) {
                        System.debug(LoggingLevel.WARN, '  File        : ' + fi);
                    }
                } else {
                    throw new AttachmentCalloutException('HTTP ' + lastStatus + ': ' + lastBody);
                }
            } catch (Exception ex) {
                if (attempt > MAX_RETRY) throw ex;
            }
        }
        throw new AttachmentCalloutException('Thất bại sau ' + MAX_RETRY + ' retry. HTTP ' + lastStatus
            + ', endpoint=' + endpoint + ', caseId=' + caseId + ', response=' + lastBody);
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
        String endpoint = FEC_ConstantArchive.API_BASE_URL + FEC_ConstantArchive.PATH_ATTACHMENTS_BATCH;
        Integer attempt = 0;
        Integer lastStatus;
        String  lastBody;

        while (attempt <= MAX_RETRY) {
            attempt++;
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(endpoint);
                req.setMethod(FEC_ConstantCommon.API_METHOD_POST);
                req.setHeader('Content-Type', FEC_ConstantCommon.API_CONTENT_TYPE_JSON);
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
                    System.debug(LoggingLevel.WARN, '── Thông tin API đã gọi (postAttachments /batch) ──');
                    System.debug(LoggingLevel.WARN, '  Endpoint    : ' + FEC_ConstantCommon.API_METHOD_POST + ' ' + endpoint);
                    System.debug(LoggingLevel.WARN, '  Content-Type: ' + FEC_ConstantCommon.API_CONTENT_TYPE_JSON);
                    System.debug(LoggingLevel.WARN, '  Timeout(ms) : ' + TIMEOUT_MS);
                    System.debug(LoggingLevel.WARN, '  Attempt     : ' + attempt + '/' + (MAX_RETRY + 1));
                    System.debug(LoggingLevel.WARN, '  So case     : ' + batchPayload.size());
                    System.debug(LoggingLevel.WARN, '  Payload size: ' + jsonPayload.length() + ' chars');
                    System.debug(LoggingLevel.WARN, '  HTTP status : ' + lastStatus);
                    debugLongText('  Response', lastBody);
                    // Payload có thể dài → tách thành nhiều dòng để Dev Console hiển thị đủ
                    debugLongText('  Payload', jsonPayload);
                } else {
                    throw new AttachmentCalloutException('HTTP ' + lastStatus + ': ' + lastBody);
                }

            } catch (Exception ex) {
                if (attempt > MAX_RETRY) throw ex;
            }
        }
        throw new AttachmentCalloutException('Thất bại sau ' + MAX_RETRY + ' retry. HTTP ' + lastStatus
            + ', endpoint=' + endpoint + ', response=' + lastBody);
    }

    /**
     * Lấy DANH SÁCH METADATA file của Case (KHÔNG load VersionData/blob).
     * Trả về mỗi item gồm: cvId, filename, contentType, fileSize.
     * Blob sẽ được load riêng theo từng chunk qua loadBlobs() để tránh giữ
     * toàn bộ file của case trong heap cùng lúc.
     *
     * QUAN TRỌNG: Tuyệt đối KHÔNG chứa bất kỳ lệnh DML nào trong hàm này.
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

        // 2. Chỉ lấy metadata (KHÔNG SELECT VersionData) để heap nhẹ
        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, ContentSize, CreatedDate, CreatedBy.Email 
            FROM ContentVersion 
            WHERE ContentDocumentId IN :docIds AND IsLatest = true
        ];

        for (ContentVersion cv : versions) {
            String ext = String.isNotBlank(cv.FileExtension) ? cv.FileExtension.toLowerCase() : '';
            String fileName = cv.Title + (String.isNotBlank(ext) ? '.' + ext : '');
            
            attachmentsMetadata.add(new Map<String, Object>{
                'cvId'        => cv.Id,
                'filename'    => fileName,
                'contentType' => getContentType(ext),
                'fileSize'    => cv.ContentSize
            });
        }
        return attachmentsMetadata;
    }

    /**
     * Load VersionData (blob) cho 1 chunk file nhỏ và gắn key 'blobData' vào
     * từng metadata map. Chỉ query đúng các cvId trong chunk → heap chỉ giữ
     * blob của vài file tại một thời điểm.
     *
     * @param chunk List metadata (mỗi item có 'cvId') của 1 lần gửi
     * @return Cùng list, mỗi item được bổ sung 'blobData'
     */
    public static List<Map<String, Object>> loadBlobs(List<Map<String, Object>> chunk) {
        Set<Id> cvIds = new Set<Id>();
        for (Map<String, Object> m : chunk) {
            cvIds.add((Id) m.get('cvId'));
        }

        Map<Id, Blob> blobById = new Map<Id, Blob>();
        for (ContentVersion cv : [
            SELECT Id, VersionData
            FROM ContentVersion
            WHERE Id IN :cvIds
        ]) {
            blobById.put(cv.Id, cv.VersionData);
        }

        for (Map<String, Object> m : chunk) {
            m.put('blobData', blobById.get((Id) m.get('cvId')));
        }
        return chunk;
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

    /**
     * Helper: in chuỗi dài thành nhiều dòng (~500 ký tự/dòng) kèm số thứ tự
     * để Developer Console hiển thị đầy đủ, tránh bị cắt ở các dòng quá dài.
     */
    private static void debugLongText(String label, String text) {
        if (String.isBlank(text)) {
            System.debug(LoggingLevel.WARN, label + ' : (empty)');
            return;
        }
        Integer chunkLen = 500;
        Integer total = (text.length() + chunkLen - 1) / chunkLen;
        for (Integer i = 0; i < text.length(); i += chunkLen) {
            Integer endIdx = Math.min(i + chunkLen, text.length());
            Integer part = (i / chunkLen) + 1;
            System.debug(LoggingLevel.WARN,
                label + ' [' + part + '/' + total + '] : ' + text.substring(i, endIdx));
        }
    }

    public class AttachmentCalloutException extends Exception {}
}