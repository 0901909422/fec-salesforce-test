public without sharing class FEC_BatchCaseHandlingImportService {

    // 30/05/2026 21:00 linhdev - giới hạn Inputted Remarks khớp Excel (32,767 ký tự/ô)
    private static final Integer REMARK_MAX_LEN = 32767;
    private static final String USER_GROUP_OM = 'OM';
    private static final String BUSINESS_PROCESS_PHONE_UPDATE = 'Phone Update';
    private static final String LABEL_CS_D2C_ASSESSMENT = 'CS D2C đánh giá yêu cầu';
    private static final String LABEL_CS_SUPPORT_ASSESSMENT = 'CS Support đánh giá yêu cầu';
    private static final String API_CS_SUPPORT_ASSESSMENT = 'FEC_CS_Support_Assessment_Type__c';
    private static final String API_RD_PAYMENT_CONTRACT_ASSESSMENT = 'FEC_RD_Payment_Contract_Assessment__c';
    private static final String LABEL_RISK_LEVEL = 'Mức độ rủi ro';
    private static final String LABEL_REQUIRED_ACTION = 'Hành động cần thiết';
    private static final String RESULT_COL_STATUS = '__Status';
    private static final String RESULT_COL_ERRORS = '__Errors';
    private static final String IMPORT_ERROR_SEPARATOR = ',\n';
    private static final String QUEUE_OWNER_ID_PREFIX = '00G';
    private static final String ERR_FIELD_NOT_CONFIGURED = 'Trường dữ liệu chưa được thiết lập trong Master Data Setting';
    private static final String ERR_MISSING_CS_D2C_ASSESSMENT = 'Thiếu giá trị CS D2C đánh giá yêu cầu';
    private static final String ERR_MISSING_RISK_LEVEL = 'Thiếu giá trị Mức độ rủi ro';
    private static final String ERR_MISSING_REQUIRED_ACTION = 'Thiếu giá trị Hành động cần thiết';
    private static final String ERR_INVALID_CS_D2C_ASSESSMENT = 'Giá trị CS D2C đánh giá yêu cầu không tồn tại trong Datagroup.';
    private static final String ERR_INVALID_RISK_LEVEL = 'Giá trị Mức độ rủi ro không tồn tại trong Datagroup.';
    private static final String ERR_INVALID_REQUIRED_ACTION = 'Giá trị Hành động cần thiết không tồn tại trong Datagroup.';
    private static final String ERR_IMPORT_PROCESSING_TIMEOUT = 'Import quá thời gian xử lý (quá 1 giờ). Vui lòng thử lại.';
    private static final String ERR_IMPORT_ROW_NOT_COMPLETED = 'Dòng chưa được xử lý apply (import chưa hoàn tất).';
    private static final String ERR_IMPORT_QUEUE_LIMIT_EXCEEDED =
        'Không thể tiếp tục xử lý import do vượt giới hạn tài nguyên hệ thống. Vui lòng chia nhỏ file hoặc thử lại sau.';
    private static final Integer BATCH_FAILURE_REASON_MAX_UNIQUE_ERRORS = 5;
    private static final String ERR_IMPORT_ROW_REF_EMPTY = '[Dòng import]';
    private static final String ERR_IMPORT_ROW_REF_EXCEL_PREFIX = 'dòng Excel ';
    private static final String ERR_IMPORT_ROW_REF_CASE_ID_PREFIX = 'Case ID ';
    private static final String ERR_IMPORT_ROW_REF_CASE_PREFIX = 'Case ';
    private static final String ERR_IMPORT_VALIDATE_EXCEPTION_SUFFIX = ' Lỗi kiểm tra dữ liệu import: ';
    private static final String ERR_IMPORT_EXCEPTION_NO_DETAIL = 'hệ thống không trả về mô tả lỗi.';
    private static final String ERR_IMPORT_EXCEPTION_TYPE_PREFIX = 'loại lỗi ';
    private static final String ERR_IMPORT_EXCEPTION_TYPE_NO_MESSAGE = ' (không có message chi tiết).';
    private static final String ERR_IMPORT_APPLY_FAILURE_SUFFIX =
        ' Import thất bại khi cập nhật Case/Routing — hệ thống không ghi nhận được nguyên nhân chi tiết. ';
    private static final String ERR_IMPORT_APPLY_FAILURE_HINT =
        'Vui lòng kiểm tra Case ID, Routing Action, Assignment ID và quyền xử lý Case.';
    private static final String ERR_IMPORT_APPLY_FAILURE_HINT_CHECK_PREFIX = 'Vui lòng kiểm tra ';
    private static final String ERR_IMPORT_APPLY_FAILURE_HINT_CHECK_SUFFIX = ', Assignment ID và quyền xử lý Case.';
    private static final String ERR_IMPORT_ROUTING_ACTION_LABEL_PREFIX = 'Routing Action "';
    private static final String ERR_IMPORT_ASSIGNMENT_ROUTING_ACTION_LABEL_PREFIX = 'Assignment Routing Action "';
    private static final String ERR_IMPORT_ROUTING_ACTION_LABEL_SUFFIX = '"';
    private static final String ERR_ROUTING_CONFLICT = 'Cùng Case ID có nhiều Routing Action khác nhau trong file import.';
    private static final String ERR_TEMPLATE_FILE_MISMATCH = 'Tên file không khớp template Bulk Actions của quy trình và nhóm người dùng.';
    private static final String LABEL_PAYMENT_CONTRACT_ASSESSMENT = 'Payment đánh giá yêu cầu đóng hợp đồng';
    //tungnm37 - hỗ trợ alias label master data PM đang tồn tại ở sb03 để không fail vì lệch tên hiển thị
    private static final String LABEL_PAYMENT_CONTRACT_ASSESSMENT_ALIAS = 'Đánh giá của RD Payment cho yêu cầu đóng HĐ';
    // FECuat/UAT: FEC_Field_Label_Name__c trên MDS = label metadata EN của field Case
    private static final String LABEL_PAYMENT_CONTRACT_ASSESSMENT_MDM_EN = 'RD Payment Contract Assessment';
    private static final String LABEL_CP_ASSESSMENT = 'CP đánh giá yêu cầu';
    private static final String LABEL_INPUTTED_REMARKS = 'Inputted Remarks';
    private static final String LABEL_ROUTING_ACTION = 'Routing Action';
    private static final String LABEL_ASSIGNMENT_ROUTING_ACTION = 'Assignment Routing Action';
    private static final String ERR_MISSING_PAYMENT_ASSESSMENT = 'Thiếu giá trị Payment đánh giá yêu cầu đóng hợp đồng';
    private static final String ERR_INVALID_PAYMENT_ASSESSMENT = 'Giá trị Payment đánh giá yêu cầu đóng hợp đồng không tồn tại trong Datagroup.';
    private static final String ERR_MISSING_CP_ASSESSMENT = 'Thiếu giá trị CP đánh giá yêu cầu';
    private static final String ERR_INVALID_CP_ASSESSMENT = 'Giá trị CP đánh giá yêu cầu không tồn tại trong Datagroup.';
    // 05/06/2026 16:00 linhdev - __Errors Export Result luôn hiển thị tiếng Việt
    private static final String ERR_GENERIC_APPLY = 'Xử lý dữ liệu thất bại.';
    private static final String ERR_GENERIC_APPLY_REASON_PREFIX = 'Xử lý dữ liệu thất bại. Nguyên nhân: ';
    private static final Integer IMPORT_RESULT_UNKNOWN_REASON_MAX_LEN = 300;
    private static final String ERR_IMPORT_RESULT_QUEUE_NOT_FOUND = 'Không tìm thấy Queue.';
    private static final String ERR_IMPORT_RESULT_CANT_FIND_NEXT_STAGE = 'Không tìm thấy stage tiếp theo.';
    private static final String ERR_IMPORT_RESULT_CANNOT_FIND_STAGE_CHANGE = 'Không tìm thấy Stage Change.';
    private static final String ERR_IMPORT_RESULT_ASSIGNMENT_NOT_FOUND = 'Không tìm thấy Assignment.';
    private static final String ERR_IMPORT_RESULT_DECISION_REQUIRED = 'Thiếu giá trị decision.';
    private static final String ERR_IMPORT_RESULT_INVALID_INPUT = 'Dữ liệu nhập không hợp lệ.';
    private static final String ERR_IMPORT_RESULT_TEAM_REQUIRED = 'Thiếu giá trị Team.';
    private static final String ERR_IMPORT_RESULT_ESCALATE_NO_MANAGER =
        'Escalate thất bại: Owner hiện tại không có manager. Vui lòng cập nhật dữ liệu user.';
    private static final String ERR_IMPORT_RESULT_ESCALATE_NO_OWNER = 'Escalate thất bại: Assignment không có owner.';
    private static final String ERR_IMPORT_RESULT_MANAGER_NOT_FOUND = 'Không tìm thấy manager của User owner hiện tại.';
    private static final String ERR_IMPORT_RESULT_INSUFFICIENT_ACCESS = 'Không đủ quyền truy cập để cập nhật dữ liệu.';
    private static final String ERR_IMPORT_RESULT_UNABLE_TO_LOCK = 'Không thể khóa bản ghi để cập nhật. Vui lòng thử lại.';
    private static final String ERR_IMPORT_RESULT_ENTITY_DELETED = 'Bản ghi đã bị xóa.';
    private static final String ERR_IMPORT_RESULT_VALIDATION_FAILED = 'Dữ liệu không thỏa điều kiện kiểm tra hệ thống.';
    private static final String ERR_IMPORT_RESULT_SUFFIX_INVALID = ' không hợp lệ.';
    private static final String ERR_IMPORT_RESULT_PREFIX_NOT_FOUND = 'Không tìm thấy ';
    private static final String ERR_IMPORT_RESULT_SUFFIX_NOT_FOUND = '.';
    private static final String IMPORT_RESULT_EN_SUFFIX_INVALID = ' is invalid.';
    private static final String IMPORT_RESULT_EN_SUFFIX_NOT_FOUND = ' not found.';
    private static final List<String> IMPORT_RESULT_TECHNICAL_ERROR_KEYWORDS = new List<String>{
        'apex cpu time limit exceeded',
        'too many soql queries',
        'too many dml statements',
        'too many dml rows',
        'heap size too large',
        'uncommitted work pending',
        'nullpointerexception',
        'list index out of bounds',
        'internal salesforce.com error'
    };
    // 05/06/2026 17:30 linhdev - lỗi resolve queue Assignment Route To khi import
    private static final String ERR_ASSIGNMENT_ROUTE_TO_QUEUE_UNKNOWN =
        'Không xác định được queue đích để cập nhật Assignment Route To.';
    private static final Map<String, String> IMPORT_RESULT_ERROR_EN_TO_VI = new Map<String, String>{
        'queue not found' => ERR_IMPORT_RESULT_QUEUE_NOT_FOUND,
        'can\'t find next stage' => ERR_IMPORT_RESULT_CANT_FIND_NEXT_STAGE,
        'cannot find stage change.' => ERR_IMPORT_RESULT_CANNOT_FIND_STAGE_CHANGE,
        'assignment not found.' => ERR_IMPORT_RESULT_ASSIGNMENT_NOT_FOUND,
        'decision is required' => ERR_IMPORT_RESULT_DECISION_REQUIRED,
        'invalid input' => ERR_IMPORT_RESULT_INVALID_INPUT,
        'team is required' => ERR_IMPORT_RESULT_TEAM_REQUIRED,
        'escalate failed: current owner has no manager. please update user data.' => ERR_IMPORT_RESULT_ESCALATE_NO_MANAGER,
        'escalate failed: assignment has no owner.' => ERR_IMPORT_RESULT_ESCALATE_NO_OWNER,
        'manager not found for the current user owner.' => ERR_IMPORT_RESULT_MANAGER_NOT_FOUND,
        // 05/06/2026 17:00 linhdev - 1 key template mismatch (TEMPLATE_MISMATCH / template_mismatch) → ERR_TEMPLATE_FILE_MISMATCH
        'template mismatch' => ERR_TEMPLATE_FILE_MISMATCH
    };
    private class RoutingParseResult {
        public String methodKey;
        public String decision;
        public String routeTeamHint;
        public String routeQueueHint;
    }

    private class ImportCaseValidateSnap {
        public String searchKey;
        public Id caseId;
        public Boolean isClosed;
        public Id ownerId;
        public Id currentStageId;
        public Decimal assignmentCount;
        public String businessProcessCode;
    }

    private class ImportAssignmentValidateSnap {
        public String assignmentLookupName;
        public Id assignmentId;
        public Id caseId;
        public String assignmentStatus;
    }

    public class ImportValidateChunkContext {
        public Boolean cofOrGsr;
        public Id currentUserId;
        public String currentUserGroup;
        public Set<Id> currentUserQueueIds;
        public Map<String, Case> caseBySearch;
        public Map<Id, String> businessProcessCodeByCaseId;
        public Map<String, FEC_Assignment__c> assignmentByName;
        public Map<Id, FEC_Assignment__c> assignmentByRecordId;
        public Map<Id, Set<String>> configuredLabelsByStage;
        public Map<String, Map<String, String>> picklistValueByNormByField;
        public Set<String> seenCaseSearch;
        public Map<String, String> routingSignatureByCaseSearch;
    }

    public class ImportValidateChunkStatePayload {
        public Boolean cofOrGsr;
        public String currentUserGroup;
        public List<String> seenCaseSearch;
        public Map<String, String> routingSignatureByCaseSearch;
        public List<ImportCaseValidateSnap> caseSnaps;
        public List<ImportAssignmentValidateSnap> assignmentSnapsByName;
        public List<ImportAssignmentValidateSnap> assignmentSnapsByRecordId;
        public Map<String, List<String>> configuredLabelsByStage;
        public List<String> currentUserQueueIds;
        public Boolean prepared;
    }

    private static final String BATCH_OBJECT_API_NAME = 'FEC_Batch_Case_Handling__c';
    @TestVisible
    private static final Integer IMPORT_PROCESSING_TIMEOUT_BASE_HOURS = 1;
    @TestVisible
    private static final Integer IMPORT_PROCESSING_TIMEOUT_HOURS_PER_500_ROWS = 1;
    @TestVisible
    private static final Integer IMPORT_PROCESSING_TIMEOUT_MAX_HOURS = 24;
    // 28/05/2026 11:20 linhdev - tối đa 5 case/transaction apply (FEC_CaseBusinessService.run ~8-12 SOQL/row) tránh 101
    @TestVisible
    public static final Integer IMPORT_APPLY_MAX_ROWS_PER_CHUNK = 5;
    // 28/05/2026 11:20 linhdev - import sync chỉ khi ≤5 applicable row; lớn hơn dùng queueable chain
    @TestVisible
    private static final Integer SYNC_IMPORT_MAX_APPLICABLE_ROWS = 5;
    // 28/05/2026 11:20 linhdev - dừng apply sớm trước 101 SOQL (mỗi row run + trigger tốn thêm query)
    @TestVisible
    private static final Integer IMPORT_SOQL_SAFE_THRESHOLD_PERCENT = 72;
    // 08/06/2026 linhdev - file >5000 row: validate async theo chunk Queueable (tránh CPU/heap sync)
    @TestVisible
    public static final Integer IMPORT_ASYNC_VALIDATE_MIN_ROWS = 5000;
    @TestVisible
    public static final Integer IMPORT_VALIDATE_MAX_ROWS_PER_CHUNK = 400;
    // 25/06/2026 linhdev - import lớn dùng staging + batch apply để giảm queueable-chain 1 row/job
    @TestVisible
    public static final Integer IMPORT_BATCH_APPLY_MIN_ROWS = 300;
    @TestVisible
    public static final Integer IMPORT_BATCH_APPLY_SCOPE_SIZE = 5;
    @TestVisible
    public static final Integer IMPORT_RESULT_ARTIFACT_CHUNK_SIZE = 5000;
    @TestVisible
    public static final Integer IMPORT_RESULT_ARTIFACT_QUEUEABLE_CHUNK_SIZE = 2000;
    // 25/06/2026 finalize theo summary khi volume lớn để tránh heap/CPU blow ở Batch.finish
    @TestVisible
    public static final Integer IMPORT_BATCH_APPLY_SUMMARY_ONLY_MIN_ROWS = 10000;
    // 08/06/2026 linhdev - ~8-12 SOQL/row runInternal; 2 row/transaction an toàn dưới ngưỡng 72%
    // 24/06/2026 phong - giảm xuống 1 row/transaction: resolve gọi thêm resolveAllAssignments (3-4 SOQL)
    // + trigger after-update (5-10 SOQL) → tổng thực tế 20-25 SOQL/row, 2 rows có thể vượt ngưỡng 72%
    // dẫn đến shouldYieldImportGovernorLimits() = true cho row thứ 2, row đó bị Failed dù case hợp lệ
    @TestVisible
    public static final Integer IMPORT_QUEUEABLE_MAX_ROWS_PER_EXECUTE = 1;
    private static Map<String, Map<String, String>> routeParamsCacheByKey = new Map<String, Map<String, String>>();
    private static Map<String, String> revertActionIdCacheByStage = new Map<String, String>();
    private static Map<String, String> queueIdCacheByToken = new Map<String, String>();
    @TestVisible
    private static Boolean batchImportApplyInProgress = false;
    @TestVisible
    private static Boolean batchHandlingTriggerBypass = false;

    public static Boolean isBatchImportApplyInProgress() {
        return batchImportApplyInProgress == true;
    }

    public static Boolean isBatchHandlingTriggerBypass() {
        return batchHandlingTriggerBypass == true;
    }

    public static Boolean shouldApplyImportRow(FEC_BatchCaseHandlingImportRow row) {
        return row != null &&
            row.status != System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed &&
            String.isNotBlank(row.recordId);
    }

    public static Boolean hasApplicableImportRows(List<FEC_BatchCaseHandlingImportRow> rows) {
        return countApplicableImportRows(rows) > 0;
    }

    public static Integer countApplicableImportRows(List<FEC_BatchCaseHandlingImportRow> rows) {
        if (rows == null || rows.isEmpty()) {
            return 0;
        }
        Integer applicableCount = 0;
        for (FEC_BatchCaseHandlingImportRow row : rows) {
            if (shouldApplyImportRow(row)) {
                applicableCount++;
            }
        }
        return applicableCount;
    }

    public static Boolean shouldProcessImportSynchronously(List<FEC_BatchCaseHandlingImportRow> rows) {
        // 28/05/2026 15:24 linhdev - production safety: always process via queueable to avoid sync SOQL 101
        return false;
    }

    public static Boolean shouldValidateImportAsynchronously(Integer rowCount) {
        return rowCount != null && rowCount > IMPORT_ASYNC_VALIDATE_MIN_ROWS;
    }

    public static Boolean shouldApplyImportWithBatch(Integer applicableRowCount) {
        return applicableRowCount != null &&
            applicableRowCount >= IMPORT_BATCH_APPLY_MIN_ROWS &&
            FEC_BCH_ImportWorkItemService.isWorkItemObjectAvailable();
    }

    @TestVisible
    private static Integer testSummaryOnlyMinRowsOverride;

    public static Boolean shouldFinalizeImportWithSummaryOnly(Integer totalRowCount) {
        Integer minRows = testSummaryOnlyMinRowsOverride != null
            ? testSummaryOnlyMinRowsOverride
            : IMPORT_BATCH_APPLY_SUMMARY_ONLY_MIN_ROWS;
        return totalRowCount != null && totalRowCount >= minRows;
    }

    public static void finalizeBatchImportRecordFromSummary(
        Id batchRecordId,
        Integer totalCount,
        Integer successCount,
        Integer failedCount,
        String failureReason
    ) {
        if (batchRecordId == null) {
            return;
        }
        Integer total = totalCount == null ? 0 : totalCount;
        Integer success = successCount == null ? 0 : successCount;
        Integer failed = failedCount == null ? 0 : failedCount;
        String resolvedFailureReason = String.isBlank(failureReason)
            ? FEC_ConstantCommon.STR_EMPTY
            : failureReason;

        String finalStatus = 'Processed';
        if (total == 0) {
            finalStatus = 'Failure';
            resolvedFailureReason = System.Label.FEC_BCH_RequireFile;
        } else if (failed >= total) {
            finalStatus = 'Failure';
            if (String.isBlank(resolvedFailureReason)) {
                resolvedFailureReason = System.Label.FEC_BCH_Import_Rows_Invalid;
            }
        } else if (success == 0) {
            finalStatus = 'Failure';
            if (String.isBlank(resolvedFailureReason)) {
                resolvedFailureReason = ERR_IMPORT_ROW_NOT_COMPLETED;
            }
        }

        Map<String, Schema.SObjectField> fieldMap = batchFieldMap();
        SObject batchRow = newBatchRow(batchRecordId);
        if (batchRow == null) {
            return;
        }
        putBatchStatusAndResult(fieldMap, batchRow, finalStatus);
        putBatchCountFields(fieldMap, batchRow, total, success, failed);
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(
            fieldMap,
            batchRow,
            new List<String>{ 'FEC_Failure_Reason__c' },
            resolvedFailureReason
        );
        update batchRow;
    }

    @TestVisible
    public static Boolean shouldYieldImportGovernorLimits() {
        return Limits.getQueries() >= (Limits.getLimitQueries() * IMPORT_SOQL_SAFE_THRESHOLD_PERCENT / 100)
            || Limits.getCpuTime() >= (Limits.getLimitCpuTime() * IMPORT_SOQL_SAFE_THRESHOLD_PERCENT / 100)
            || Limits.getDMLRows() >= (Limits.getLimitDMLRows() * IMPORT_SOQL_SAFE_THRESHOLD_PERCENT / 100)
            || Limits.getHeapSize() >= (Limits.getLimitHeapSize() * IMPORT_SOQL_SAFE_THRESHOLD_PERCENT / 100);
    }

    public static Boolean hasRemainingApplicableImportRows(
        List<FEC_BatchCaseHandlingImportRow> rows,
        Integer startIndex
    ) {
        if (rows == null || startIndex == null || startIndex < 0 || startIndex >= rows.size()) {
            return false;
        }
        for (Integer idx = startIndex; idx < rows.size(); idx++) {
            if (shouldApplyImportRow(rows[idx])) {
                return true;
            }
        }
        return false;
    }

    public static void processApplicableImportRowsSync(
        Id batchRecordId,
        List<FEC_BatchCaseHandlingImportRow> rows,
        Boolean cofOrGsr
    ) {
        if (rows == null || rows.isEmpty()) {
            finalizeBatchImportRecord(batchRecordId, rows);
            return;
        }
        List<FEC_BatchCaseHandlingImportRow> applicableRows = new List<FEC_BatchCaseHandlingImportRow>();
        for (FEC_BatchCaseHandlingImportRow row : rows) {
            if (shouldApplyImportRow(row)) {
                applicableRows.add(row);
            }
        }
        if (!applicableRows.isEmpty()) {
            // 28/05/2026 11:20 linhdev - sync apply theo chunk 5 row để không vượt governor khi nhiều case
            for (Integer startIdx = 0; startIdx < applicableRows.size(); startIdx += IMPORT_APPLY_MAX_ROWS_PER_CHUNK) {
                Integer endIdx = Math.min(startIdx + IMPORT_APPLY_MAX_ROWS_PER_CHUNK, applicableRows.size());
                List<FEC_BatchCaseHandlingImportRow> chunk = new List<FEC_BatchCaseHandlingImportRow>();
                for (Integer idx = startIdx; idx < endIdx; idx++) {
                    chunk.add(applicableRows[idx]);
                }
                applyCaseHandlingUpdates(chunk, cofOrGsr == true);
                if (shouldYieldImportGovernorLimits() && endIdx < applicableRows.size()) {
                    break;
                }
            }
        }
        finalizeBatchImportRecord(batchRecordId, rows);
    }

    public static void finalizeBatchImportRecord(
        Id batchRecordId,
        List<FEC_BatchCaseHandlingImportRow> rowResults
    ) {
        if (batchRecordId == null) {
            return;
        }
        Map<String, Schema.SObjectField> fieldMap = batchFieldMap();
        SObject batchRow = newBatchRow(batchRecordId);
        if (batchRow == null) {
            return;
        }
        Integer totalCount = rowResults == null ? 0 : rowResults.size();
        Integer unprocessedCount = countUnprocessedImportRows(rowResults);
        markUnprocessedImportRows(rowResults, ERR_IMPORT_ROW_NOT_COMPLETED);
        ensureFailedImportRowsHaveDetailErrors(rowResults);
        Integer failedCount = countFailedImportRows(rowResults);
        Integer successCount = countSuccessImportRows(rowResults);
        String failureReason = FEC_ConstantCommon.STR_EMPTY;
        String finalStatus = 'Processed';
        if (totalCount == 0) {
            finalStatus = 'Failure';
            failureReason = System.Label.FEC_BCH_RequireFile;
        } else if (failedCount == totalCount) {
            finalStatus = 'Failure';
            failureReason = resolveBatchFailureReasonFromRows(
                rowResults,
                System.Label.FEC_BCH_Import_Rows_Invalid
            );
        } else if (successCount == 0) {
            finalStatus = 'Failure';
            failureReason = resolveBatchFailureReasonFromRows(
                rowResults,
                ERR_IMPORT_ROW_NOT_COMPLETED
            );
        } else if (unprocessedCount > 0) {
            failureReason = ERR_IMPORT_ROW_NOT_COMPLETED;
        }
        putBatchStatusAndResult(fieldMap, batchRow, finalStatus);
        putBatchCountFields(
            fieldMap,
            batchRow,
            totalCount,
            successCount,
            failedCount
        );
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(
            fieldMap,
            batchRow,
            new List<String>{ 'FEC_Failure_Reason__c' },
            failureReason
        );
        update batchRow;
        persistBatchResultArtifact(batchRecordId, rowResults, failureReason);
    }

    public static void failBatchImportRecord(Id batchRecordId, String reason) {
        failBatchImportRecord(batchRecordId, reason, null);
    }

    public static void expireStaleProcessingBatchImports(Id scopeUserId) {
        if (scopeUserId == null) {
            return;
        }
        Map<String, Schema.SObjectField> fieldMap = batchFieldMap();
        String statusField = FEC_BatchCaseHandlingSObjectUtil.pickField(
            fieldMap,
            new List<String>{ 'FEC_Status__c' }
        );
        if (String.isBlank(statusField)) {
            return;
        }
        String uploadedOnField = FEC_BatchCaseHandlingSObjectUtil.pickField(
            fieldMap,
            new List<String>{ 'FEC_Uploaded_On__c' }
        );
        Datetime cutoff = Datetime.now().addHours(-IMPORT_PROCESSING_TIMEOUT_MAX_HOURS);
        List<String> whereParts = new List<String>{
            statusField + ' = \'Processing\'',
            'CreatedById = :scopeUserId'
        };
        if (String.isNotBlank(uploadedOnField)) {
            whereParts.add(
                '(' +
                    uploadedOnField +
                    ' < :cutoff OR (' +
                    uploadedOnField +
                    ' = null AND CreatedDate < :cutoff))'
            );
        } else {
            whereParts.add('CreatedDate < :cutoff');
        }
        List<SObject> staleRows = Database.query(
            'SELECT Id FROM ' +
                BATCH_OBJECT_API_NAME +
                ' WHERE ' +
                String.join(whereParts, ' AND ')
        );
        if (staleRows.isEmpty()) {
            return;
        }
        String timeoutReason = resolveImportProcessingTimeoutReason();
        for (SObject staleRow : staleRows) {
            Id batchId = (Id) staleRow.get('Id');
            if (!isBatchImportProcessingExpired(batchId)) {
                continue;
            }
            failBatchImportRecord(batchId, timeoutReason, null);
        }
    }

    public static Boolean isBatchImportProcessingExpired(Id batchRecordId) {
        if (batchRecordId == null) {
            return false;
        }
        Map<String, Schema.SObjectField> fieldMap = batchFieldMap();
        String statusField = FEC_BatchCaseHandlingSObjectUtil.pickField(
            fieldMap,
            new List<String>{ 'FEC_Status__c' }
        );
        if (String.isBlank(statusField)) {
            return false;
        }
        String uploadedOnField = FEC_BatchCaseHandlingSObjectUtil.pickField(
            fieldMap,
            new List<String>{ 'FEC_Uploaded_On__c' }
        );
        String totalRecordsField = FEC_BatchCaseHandlingSObjectUtil.pickField(
            fieldMap,
            new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }
        );
        List<String> selectParts = new List<String>{ 'Id', statusField, 'CreatedDate' };
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, uploadedOnField);
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, totalRecordsField);
        List<SObject> rows = Database.query(
            'SELECT ' +
                String.join(selectParts, ', ') +
                ' FROM ' +
                BATCH_OBJECT_API_NAME +
                ' WHERE Id = :batchRecordId LIMIT 1'
        );
        if (rows.isEmpty()) {
            return false;
        }
        SObject row = rows[0];
        String status = FEC_BatchCaseHandlingSObjectUtil.asString(row.get(statusField));
        if (status != 'Processing') {
            return false;
        }
        Datetime startedOn = FEC_BatchCaseHandlingSObjectUtil.asDatetime(row.get('CreatedDate'));
        if (String.isNotBlank(uploadedOnField)) {
            Datetime uploadedOn = FEC_BatchCaseHandlingSObjectUtil.asDatetime(row.get(uploadedOnField));
            if (uploadedOn != null) {
                startedOn = uploadedOn;
            }
        }
        if (startedOn == null) {
            return false;
        }
        Integer totalRowCount = resolveBatchImportTotalRowCount(row, fieldMap);
        Integer timeoutHours = resolveImportProcessingTimeoutHours(totalRowCount);
        return startedOn < Datetime.now().addHours(-timeoutHours);
    }

    public static Integer resolveImportProcessingTimeoutHours(Integer totalRowCount) {
        if (totalRowCount == null || totalRowCount <= 0) {
            return IMPORT_PROCESSING_TIMEOUT_BASE_HOURS;
        }
        Integer extraHours = Math.max(
            0,
            ((totalRowCount + 499) / 500) - 1
        ) * IMPORT_PROCESSING_TIMEOUT_HOURS_PER_500_ROWS;
        return Math.min(
            IMPORT_PROCESSING_TIMEOUT_MAX_HOURS,
            IMPORT_PROCESSING_TIMEOUT_BASE_HOURS + extraHours
        );
    }

    private static Integer resolveBatchImportTotalRowCount(
        SObject batchRow,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        if (batchRow == null || fieldMap == null || fieldMap.isEmpty()) {
            return 0;
        }
        String totalField = FEC_BatchCaseHandlingSObjectUtil.pickField(
            fieldMap,
            new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }
        );
        if (String.isBlank(totalField)) {
            return 0;
        }
        Object totalVal = batchRow.get(totalField);
        if (totalVal == null) {
            return 0;
        }
        try {
            return Integer.valueOf(String.valueOf(totalVal));
        } catch (Exception ex) {
            return 0;
        }
    }

    public static void failBatchImportRecord(
        Id batchRecordId,
        String reason,
        List<FEC_BatchCaseHandlingImportRow> rowResults
    ) {
        if (batchRecordId == null) {
            return;
        }
        Map<String, Schema.SObjectField> fieldMap = batchFieldMap();
        SObject batchRow = newBatchRow(batchRecordId);
        if (batchRow == null) {
            return;
        }
        String failureReason = resolveImportFailureReason(reason, rowResults);
        Integer totalCount = rowResults == null ? 0 : rowResults.size();
        if (totalCount > 0) {
            markUnprocessedImportRows(rowResults, failureReason);
            ensureFailedImportRowsHaveDetailErrors(rowResults);
            // 28/05/2026 16:35 linhdev - nếu còn ít nhất 1 row success thì batch status phải là Processed để đồng bộ đúng với file Result
            Integer failedCount = countFailedImportRows(rowResults);
            Integer successCount = countSuccessImportRows(rowResults);
            String finalStatus = successCount > 0 ? 'Processed' : 'Failure';
            String finalFailureReason = finalStatus == 'Failure' ? failureReason : FEC_ConstantCommon.STR_EMPTY;
            putBatchStatusAndResult(fieldMap, batchRow, finalStatus);
            putBatchCountFields(fieldMap, batchRow, totalCount, successCount, failedCount);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(
                fieldMap,
                batchRow,
                new List<String>{ 'FEC_Failure_Reason__c' },
                finalFailureReason
            );
        } else {
            putBatchStatusAndResult(fieldMap, batchRow, 'Failure');
            applyExistingBatchFailCounts(fieldMap, batchRow, batchRecordId);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(
                fieldMap,
                batchRow,
                new List<String>{ 'FEC_Failure_Reason__c' },
                failureReason
            );
        }
        update batchRow;
        persistBatchResultArtifact(batchRecordId, rowResults, failureReason);
    }

    public static String resolveImportProcessingTimeoutReason() {
        try {
            String labelVal = System.Label.FEC_BCH_RequestTimeout;
            if (String.isNotBlank(labelVal)) {
                return labelVal;
            }
        } catch (Exception ex) {
        }
        return ERR_IMPORT_PROCESSING_TIMEOUT;
    }

    private static Map<String, Schema.SObjectField> batchFieldMap() {
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get(BATCH_OBJECT_API_NAME);
        if (batchType == null) {
            return new Map<String, Schema.SObjectField>();
        }
        return batchType.getDescribe().fields.getMap();
    }

    private static SObject newBatchRow(Id batchRecordId) {
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get(BATCH_OBJECT_API_NAME);
        if (batchType == null) {
            return null;
        }
        return batchType.newSObject(batchRecordId);
    }

    private static void putBatchStatusAndResult(
        Map<String, Schema.SObjectField> fieldMap,
        SObject batchRow,
        String status
    ) {
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(
            fieldMap,
            batchRow,
            new List<String>{ 'FEC_Status__c' },
            status
        );
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(
            fieldMap,
            batchRow,
            new List<String>{ 'FEC_Result__c' },
            'Result'
        );
    }

    private static void putBatchCountFields(
        Map<String, Schema.SObjectField> fieldMap,
        SObject batchRow,
        Integer totalCount,
        Integer successCount,
        Integer failedCount
    ) {
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(
            fieldMap,
            batchRow,
            new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' },
            totalCount
        );
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(
            fieldMap,
            batchRow,
            new List<String>{ 'FEC_Total_Success_Records__c' },
            successCount
        );
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(
            fieldMap,
            batchRow,
            new List<String>{ 'FEC_Total_Failed_Records__c' },
            failedCount
        );
    }

    private static void applyExistingBatchFailCounts(
        Map<String, Schema.SObjectField> fieldMap,
        SObject batchRow,
        Id batchRecordId
    ) {
        String totalField = FEC_BatchCaseHandlingSObjectUtil.pickField(
            fieldMap,
            new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }
        );
        if (String.isBlank(totalField) || batchRecordId == null) {
            return;
        }
        List<SObject> existing = Database.query(
            'SELECT ' + totalField + ' FROM ' + BATCH_OBJECT_API_NAME + ' WHERE Id = :batchRecordId LIMIT 1'
        );
        if (existing.isEmpty()) {
            return;
        }
        Decimal totalVal = FEC_BatchCaseHandlingSObjectUtil.asDecimal(existing[0].get(totalField));
        Integer totalCount = totalVal == null ? 0 : totalVal.intValue();
        if (totalCount > 0) {
            putBatchCountFields(fieldMap, batchRow, totalCount, 0, totalCount);
        }
    }

    private static Boolean isCofOrGsrImportRows(List<FEC_BatchCaseHandlingImportRow> rowResults) {
        if (rowResults == null) {
            return false;
        }
        for (FEC_BatchCaseHandlingImportRow row : rowResults) {
            if (row != null && (String.isNotBlank(row.assignmentId) || String.isNotBlank(row.assignmentRoutingAction))) {
                return true;
            }
        }
        return false;
    }

    public static void persistBatchResultArtifact(
        Id batchRecordId,
        List<FEC_BatchCaseHandlingImportRow> rowResults,
        String batchFailureReason
    ) {
        persistBatchResultArtifactInternal(
            batchRecordId,
            rowResults,
            batchFailureReason,
            resolveBatchResultFileName(batchRecordId)
        );
    }

    public static void persistBatchResultArtifactChunkedFromWorkItems(
        Id batchRecordId,
        String batchFailureReason,
        Integer chunkSize
    ) {
        if (batchRecordId == null) {
            return;
        }
        Integer safeChunkSize = chunkSize == null || chunkSize < 1
            ? IMPORT_RESULT_ARTIFACT_CHUNK_SIZE
            : Math.min(chunkSize, IMPORT_RESULT_ARTIFACT_CHUNK_SIZE);
        Integer afterRowIndex = -1;
        Integer partNumber = 1;
        String baseFileName = resolveBatchResultFileName(batchRecordId);
        while (true) {
            FEC_BCH_ImportWorkItemService.WorkItemChunkResult chunk =
                FEC_BCH_ImportWorkItemService.loadRowsByBatchChunk(
                    batchRecordId,
                    afterRowIndex,
                    safeChunkSize
                );
            if (chunk == null || chunk.rows == null || chunk.rows.isEmpty()) {
                break;
            }
            persistBatchResultArtifactInternal(
                batchRecordId,
                chunk.rows,
                batchFailureReason,
                buildChunkResultFileName(baseFileName, partNumber)
            );
            if (chunk.hasMore != true) {
                break;
            }
            if (chunk.lastRowIndex == null || chunk.lastRowIndex <= afterRowIndex) {
                break;
            }
            afterRowIndex = chunk.lastRowIndex;
            partNumber++;
        }
    }

    public static void enqueueChunkedResultArtifactFromWorkItems(
        Id batchRecordId,
        String batchFailureReason,
        Integer chunkSize
    ) {
        if (batchRecordId == null) {
            return;
        }
        Integer safeChunkSize = chunkSize == null || chunkSize < 1
            ? IMPORT_RESULT_ARTIFACT_QUEUEABLE_CHUNK_SIZE
            : Math.min(chunkSize, IMPORT_RESULT_ARTIFACT_CHUNK_SIZE);
        System.enqueueJob(
            new FEC_BCH_ResultArtifactQueueable(
                batchRecordId,
                batchFailureReason,
                -1,
                1,
                safeChunkSize
            )
        );
    }

    public static String resolveChunkResultFileName(
        Id batchRecordId,
        Integer partNumber
    ) {
        return buildChunkResultFileName(resolveBatchResultFileName(batchRecordId), partNumber);
    }

    public static void persistBatchResultArtifactWithFileName(
        Id batchRecordId,
        List<FEC_BatchCaseHandlingImportRow> rowResults,
        String batchFailureReason,
        String resultFileName
    ) {
        persistBatchResultArtifactInternal(
            batchRecordId,
            rowResults,
            batchFailureReason,
            resultFileName
        );
    }

    private static String buildChunkResultFileName(String baseFileName, Integer partNumber) {
        String normalizedBase = String.isBlank(baseFileName) ? 'Import_Result.xlsx' : baseFileName;
        Integer safePart = partNumber == null || partNumber < 1 ? 1 : partNumber;
        String baseNoExt = FEC_BatchCaseHandlingSObjectUtil.removeFileExtension(normalizedBase);
        if (String.isBlank(baseNoExt)) {
            baseNoExt = 'Import_Result';
        }
        return baseNoExt + '_Part' + String.valueOf(safePart) + '.xlsx';
    }

    private static void persistBatchResultArtifactInternal(
        Id batchRecordId,
        List<FEC_BatchCaseHandlingImportRow> rowResults,
        String batchFailureReason,
        String resultFileName
    ) {
        if (batchRecordId == null) {
            return;
        }
        try {
            Id sourceContentVersionId = querySourceImportContentVersionId(batchRecordId);
            if (sourceContentVersionId == null) {
                sourceContentVersionId = querySourceContentVersionFromBatchFileLinks(batchRecordId);
            }
            if (sourceContentVersionId != null && rowResults != null && !rowResults.isEmpty()) {
                rowResults = enrichImportRowsLayoutFromSourceFile(sourceContentVersionId, rowResults);
            }
            String fileName = String.isBlank(resultFileName)
                ? resolveBatchResultFileName(batchRecordId)
                : resultFileName;
            Boolean cofOrGsr = isCofOrGsrImportRows(rowResults);
            List<List<String>> sheetRows = null;
            try {
                sheetRows = buildBatchResultSheetRows(
                    rowResults,
                    batchFailureReason,
                    cofOrGsr
                );
            } catch (Exception sheetRowsEx) {
                // 29/05/2026 14:21 linhdev - if normal result rows fail, continue with emergency result workbook
                sheetRows = null;
            }
            Blob workbookBlob = null;
            try {
                workbookBlob = buildBatchResultWorkbookFromOriginalTemplate(
                    batchRecordId,
                    rowResults,
                    batchFailureReason
                );
            } catch (Exception templateEx) {
                // 29/05/2026 14:07 linhdev - fallback to basic result workbook if original-layout patching fails
                workbookBlob = null;
            }
            if (workbookBlob == null && sheetRows != null && !sheetRows.isEmpty()) {
                workbookBlob = FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(sheetRows);
            }
            if (workbookBlob == null) {
                workbookBlob = FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(
                    buildEmergencyBatchResultSheetRows(batchFailureReason, cofOrGsr)
                );
            }
            if (workbookBlob == null) {
                return;
            }
            ContentVersion cv = new ContentVersion();
            cv.Title = ensureResultContentTitle(fileName);
            cv.PathOnClient = '/' + fileName;
            cv.VersionData = workbookBlob;
            cv.FirstPublishLocationId = batchRecordId;
            insert cv;
        } catch (Exception ex) {
        }
    }

    // 28/05/2026 17:45 linhdev - Result .xlsx = file import gốc + patch __Status/__Errors (FEC_BCH_TemplateExportService)
    private static Blob buildBatchResultWorkbookFromOriginalTemplate(
        Id batchRecordId,
        List<FEC_BatchCaseHandlingImportRow> rowResults,
        String batchFailureReason
    ) {
        if (batchRecordId == null) {
            return null;
        }
        // 02/06/2026 16:00 linhdev - khi fail batch (vd CPU limit) nhưng còn file import gốc, hydrate rowResults để vẫn export Result giữ format template
        if (rowResults == null || rowResults.isEmpty()) {
            rowResults = hydrateFailureRowsFromSourceImport(batchRecordId, batchFailureReason);
        }
        if (rowResults == null || rowResults.isEmpty()) {
            return null;
        }
        List<String> sourceHeaders = null;
        Integer sourceHeaderRowIndex = null;
        String sourceSheetName = null;
        for (FEC_BatchCaseHandlingImportRow row : rowResults) {
            if (row == null) {
                continue;
            }
            if (sourceHeaders == null && row.originalHeaders != null && !row.originalHeaders.isEmpty()) {
                sourceHeaders = row.originalHeaders;
            }
            if (sourceHeaderRowIndex == null && row.originalHeaderRowIndex != null && row.originalHeaderRowIndex >= 0) {
                sourceHeaderRowIndex = row.originalHeaderRowIndex;
            }
            if (String.isBlank(sourceSheetName) && String.isNotBlank(row.originalSheetName)) {
                sourceSheetName = row.originalSheetName;
            }
            if (sourceHeaders != null && sourceHeaderRowIndex != null && String.isNotBlank(sourceSheetName)) {
                break;
            }
        }
        if (sourceHeaders == null || sourceHeaders.isEmpty()) {
            return null;
        }
        Id sourceContentVersionId = querySourceImportContentVersionId(batchRecordId);
        // 28/05/2026 17:45 linhdev - fallback file import gốc từ ContentDocumentLink khi field batch trống
        if (sourceContentVersionId == null) {
            sourceContentVersionId = querySourceContentVersionFromBatchFileLinks(batchRecordId);
        }
        if (sourceContentVersionId == null) {
            return null;
        }
        // 01/06/2026 20:30 linhdev - layout Result đọc từ file import trên server (parse Apex), không dùng originalCells LWC lệch cột
        rowResults = enrichImportRowsLayoutFromSourceFile(sourceContentVersionId, rowResults);
        // 01/06/2026 16:30 linhdev - alias remark header; tránh lệch cột khi export Result
        Integer inputtedRemarksIndex = findRemarkHeaderIndex(sourceHeaders);
        if (inputtedRemarksIndex < 0) {
            inputtedRemarksIndex = findHeaderIndex(sourceHeaders, LABEL_INPUTTED_REMARKS);
        }
        Integer routingActionIndex = findHeaderIndex(sourceHeaders, LABEL_ROUTING_ACTION);
        Integer assignmentRoutingActionIndex = findAssignmentRoutingHeaderIndex(sourceHeaders);
        if (assignmentRoutingActionIndex < 0) {
            assignmentRoutingActionIndex = findHeaderIndex(
                sourceHeaders,
                LABEL_ASSIGNMENT_ROUTING_ACTION
            );
        }
        Integer cpAssessmentIndex = findHeaderIndex(sourceHeaders, LABEL_CP_ASSESSMENT);
        List<Integer> mappedColumnIndexes = buildResultMappedColumnIndexes(
            sourceContentVersionId,
            sourceHeaderRowIndex,
            sourceSheetName,
            sourceHeaders,
            rowResults
        );
        Integer resultInsertIndex = resolveResultInsertIndex(
            sourceHeaders,
            inputtedRemarksIndex,
            cpAssessmentIndex
        );
        List<List<String>> dataRows = new List<List<String>>();
        List<List<String>> insertValues = new List<List<String>>();
        for (FEC_BatchCaseHandlingImportRow row : rowResults) {
            if (row == null) {
                continue;
            }
            List<String> cells = new List<String>();
            // 01/06/2026 21:00 linhdev - đọc từng ô từ file gốc theo mappedColumnIndexes (không tin originalCells LWC)
            if (
                sourceContentVersionId != null &&
                row.originalDataRowIndex != null &&
                mappedColumnIndexes != null &&
                !mappedColumnIndexes.isEmpty()
            ) {
                cells = rebuildExportCellsFromSourceFile(
                    sourceContentVersionId,
                    sourceSheetName,
                    row.originalDataRowIndex,
                    mappedColumnIndexes,
                    sourceHeaders.size()
                );
            } else if (row.originalCells != null && !row.originalCells.isEmpty()) {
                for (String cell : row.originalCells) {
                    cells.add(rowValue(cell));
                }
            }
            while (cells.size() < sourceHeaders.size()) {
                cells.add(FEC_ConstantCommon.STR_EMPTY);
            }
            if (cells.size() > sourceHeaders.size()) {
                List<String> normalizedCells = new List<String>();
                for (Integer idx = 0; idx < sourceHeaders.size(); idx++) {
                    normalizedCells.add(cells[idx]);
                }
                cells = normalizedCells;
            }
            // 30/05/2026 19:15 linhdev - giữ lại remark gốc trong Result khi payload validate bị rỗng do vượt giới hạn
            String remarkForResult = FEC_ConstantCommon.STR_EMPTY;
            if (inputtedRemarksIndex >= 0 && inputtedRemarksIndex < cells.size()) {
                remarkForResult = rowValue(row.inputtedRemarks);
                if (String.isBlank(remarkForResult)) {
                    remarkForResult = rowValue(cells[inputtedRemarksIndex]);
                }
                if (
                    String.isBlank(remarkForResult) &&
                    row.originalDataRowIndex != null &&
                    inputtedRemarksIndex < mappedColumnIndexes.size()
                ) {
                    remarkForResult = FEC_BCH_TemplateExportService.readImportCellText(
                        sourceContentVersionId,
                        sourceSheetName,
                        row.originalDataRowIndex,
                        mappedColumnIndexes[inputtedRemarksIndex]
                    );
                }
                if (String.isNotBlank(remarkForResult)) {
                    cells[inputtedRemarksIndex] = remarkForResult;
                }
            }
            // 01/06/2026 16:30 linhdev - không copy remark sang Routing Action trên file Result
            clearRoutingCellIfRemarkBleed(
                cells,
                routingActionIndex,
                inputtedRemarksIndex,
                remarkForResult,
                row.inputtedRemarksCharLength
            );
            clearRoutingCellIfRemarkBleed(
                cells,
                assignmentRoutingActionIndex,
                inputtedRemarksIndex,
                remarkForResult,
                row.inputtedRemarksCharLength
            );
            // 01/06/2026 19:00 linhdev - Result dùng routing đã validate (originalCells có thể còn remark dính từ LWC aoa)
            applyValidatedRoutingToResultCells(
                cells,
                routingActionIndex,
                assignmentRoutingActionIndex,
                row
            );
            clearRoutingCellIfRemarkBleed(
                cells,
                routingActionIndex,
                inputtedRemarksIndex,
                remarkForResult,
                row.inputtedRemarksCharLength
            );
            // 01/06/2026 18:00 linhdev - Case ID đúng cột header; xóa bản sao lệch cột khi originalCells/map lệch
            syncCaseIdIntoExportCells(cells, sourceHeaders, rowValue(row.caseIdSearch));
            dataRows.add(cells);
            insertValues.add(
                new List<String>{
                    rowValue(resolveImportResultStatusLabel(row.status)),
                    // 05/06/2026 16:00 linhdev - __Errors Export Result luôn tiếng Việt
                    rowValue(resolveImportRowResultErrors(row))
                }
            );
        }
        if (dataRows.isEmpty()) {
            return null;
        }
        FEC_BCH_TemplateExportService.ExportRequest req = new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = sourceContentVersionId;
        req.headerRowIndex = sourceHeaderRowIndex == null ? 0 : sourceHeaderRowIndex;
        req.mappedColumnIndexes = mappedColumnIndexes;
        req.dataRows = dataRows;
        req.insertColumnsBeforeIndex = resultInsertIndex;
        req.insertColumnHeaders = new List<String>{ RESULT_COL_STATUS, RESULT_COL_ERRORS };
        req.insertColumnValues = insertValues;
        req.templateSheetName = sourceSheetName;
        // 01/06/2026 16:30 linhdev - copy cell remark gốc đúng cột worksheet Inputted Remarks (không sang Routing Action)
        if (inputtedRemarksIndex >= 0 && inputtedRemarksIndex < mappedColumnIndexes.size()) {
            Integer preserveCol = mappedColumnIndexes[inputtedRemarksIndex];
            if (
                assignmentRoutingActionIndex >= 0 &&
                assignmentRoutingActionIndex < mappedColumnIndexes.size() &&
                assignmentRoutingActionIndex != inputtedRemarksIndex &&
                preserveCol == mappedColumnIndexes[assignmentRoutingActionIndex]
            ) {
                preserveCol = null;
            }
            req.preserveSourceWorksheetColIndex = preserveCol;
        }
        List<Integer> sourceDataRowIndexes = new List<Integer>();
        for (FEC_BatchCaseHandlingImportRow row : rowResults) {
            sourceDataRowIndexes.add(row == null ? null : row.originalDataRowIndex);
        }
        req.sourceDataRowIndexes = sourceDataRowIndexes;
        String outBase64 = FEC_BCH_TemplateExportService.exportWorkbookBase64(JSON.serialize(req));
        if (String.isBlank(outBase64)) {
            return null;
        }
        try {
            return EncodingUtil.base64Decode(outBase64);
        } catch (Exception ex) {
            return null;
        }
    }

    @TestVisible
    private static List<FEC_BatchCaseHandlingImportRow> hydrateFailureRowsFromSourceImport(
        Id batchRecordId,
        String batchFailureReason
    ) {
        if (batchRecordId == null) {
            return new List<FEC_BatchCaseHandlingImportRow>();
        }
        Id sourceContentVersionId = querySourceImportContentVersionId(batchRecordId);
        if (sourceContentVersionId == null) {
            sourceContentVersionId = querySourceContentVersionFromBatchFileLinks(batchRecordId);
        }
        if (sourceContentVersionId == null) {
            return new List<FEC_BatchCaseHandlingImportRow>();
        }
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult parsed =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(sourceContentVersionId);
        if (parsed == null || parsed.parseSuccess != true || parsed.inputRows == null || parsed.inputRows.isEmpty()) {
            return new List<FEC_BatchCaseHandlingImportRow>();
        }
        List<FEC_BatchCaseHandlingImportRow> parsedRows;
        try {
            parsedRows = (List<FEC_BatchCaseHandlingImportRow>) JSON.deserialize(
                JSON.serialize(parsed.inputRows),
                List<FEC_BatchCaseHandlingImportRow>.class
            );
        } catch (Exception ex) {
            return new List<FEC_BatchCaseHandlingImportRow>();
        }
        if (parsedRows == null || parsedRows.isEmpty()) {
            return new List<FEC_BatchCaseHandlingImportRow>();
        }
        String failureError = resolveImportFailureReason(batchFailureReason, null);
        for (FEC_BatchCaseHandlingImportRow row : parsedRows) {
            if (row == null) {
                continue;
            }
            row.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
            // 05/06/2026 16:00 linhdev - __Errors Export Result luôn tiếng Việt
            if (String.isBlank(row.errors)) {
                row.errors = localizeImportResultErrors(failureError);
            }
            row.recordId = FEC_ConstantCommon.STR_EMPTY;
        }
        return parsedRows;
    }

    private static String resolveBatchResultFileName(Id batchRecordId) {
        return FEC_BatchCaseHandlingSObjectUtil.removeFileExtension(queryBatchFileName(batchRecordId)) + '_Result.xlsx';
    }

    private static String queryBatchFileName(Id batchRecordId) {
        Map<String, Schema.SObjectField> fieldMap = batchFieldMap();
        String fileField = FEC_BatchCaseHandlingSObjectUtil.pickField(fieldMap, new List<String>{ 'FEC_File_Name__c' });
        String nameField = fieldMap.containsKey('Name') ? 'Name' : null;
        List<String> selectParts = new List<String>{ 'Id' };
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, fileField);
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, nameField);
        List<SObject> rows = Database.query(
            'SELECT ' + String.join(selectParts, ', ') + ' FROM ' + BATCH_OBJECT_API_NAME + ' WHERE Id = :batchRecordId LIMIT 1'
        );
        if (rows.isEmpty()) {
            return 'Import';
        }
        SObject row = rows[0];
        String sourceName = FEC_BatchCaseHandlingSObjectUtil.asString(row.get(fileField));
        if (String.isBlank(sourceName) && String.isNotBlank(nameField)) {
            sourceName = FEC_BatchCaseHandlingSObjectUtil.asString(row.get(nameField));
        }
        return String.isBlank(sourceName) ? 'Import' : sourceName;
    }

    private static Id querySourceImportContentVersionId(Id batchRecordId) {
        if (batchRecordId == null) {
            return null;
        }
        Map<String, Schema.SObjectField> fieldMap = batchFieldMap();
        String fileDocField = FEC_BatchCaseHandlingSObjectUtil.pickField(
            fieldMap,
            new List<String>{ 'FEC_File_Content_Document_Id__c' }
        );
        if (String.isBlank(fileDocField)) {
            return null;
        }
        List<SObject> batchRows = Database.query(
            'SELECT ' + fileDocField + ' FROM ' + BATCH_OBJECT_API_NAME + ' WHERE Id = :batchRecordId LIMIT 1'
        );
        if (batchRows.isEmpty()) {
            return null;
        }
        String contentDocumentId = FEC_BatchCaseHandlingSObjectUtil.asString(batchRows[0].get(fileDocField));
        if (String.isBlank(contentDocumentId)) {
            return null;
        }
        return queryLatestContentVersionIdForDocument(contentDocumentId);
    }

    // 28/05/2026 17:45 linhdev - lấy ContentVersion file upload gốc (bỏ qua title *_Result), ASC = file link trước Result
    private static Id querySourceContentVersionFromBatchFileLinks(Id batchRecordId) {
        if (batchRecordId == null) {
            return null;
        }
        for (ContentDocumentLink link : [
            SELECT ContentDocument.Title, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :batchRecordId
            ORDER BY SystemModstamp ASC
        ]) {
            if (link.ContentDocument == null) {
                continue;
            }
            String title = link.ContentDocument.Title;
            if (isBatchCaseHandlingResultContentTitle(title)) {
                continue;
            }
            Id versionId = link.ContentDocument.LatestPublishedVersionId;
            if (versionId != null) {
                return versionId;
            }
        }
        return null;
    }

    private static Id queryLatestContentVersionIdForDocument(String contentDocumentId) {
        if (String.isBlank(contentDocumentId)) {
            return null;
        }
        List<ContentVersion> versions = [
            SELECT Id
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            ORDER BY VersionNumber DESC
            LIMIT 1
        ];
        return versions.isEmpty() ? null : versions[0].Id;
    }

    // 02/06/2026 15:45 linhdev - Batch Case Handling: nhận diện Result cả khi ContentDocument.Title có đuôi .xlsx
    private static Boolean isBatchCaseHandlingResultContentTitle(String title) {
        if (String.isBlank(title)) {
            return false;
        }
        String normalizedTitle = FEC_BatchCaseHandlingSObjectUtil.removeFileExtension(title.trim());
        if (String.isBlank(normalizedTitle)) {
            normalizedTitle = title.trim();
        }
        String lower = normalizedTitle.toLowerCase();
        return lower.endsWith('_importresult') || lower.endsWith('_result');
    }

    private static List<List<String>> buildBatchResultSheetRows(
        List<FEC_BatchCaseHandlingImportRow> rowResults,
        String batchFailureReason,
        Boolean cofOrGsr
    ) {
        // 28/05/2026 16:20 linhdev - ưu tiên xuất theo layout file import gốc + append __Status/__Errors
        List<List<String>> originalLayoutRows = buildBatchResultFromOriginalLayout(rowResults);
        if (originalLayoutRows != null) {
            return originalLayoutRows;
        }
        List<List<String>> sheetRows = new List<List<String>>();
        if (cofOrGsr) {
            sheetRows.add(
                new List<String>{
                    'Case ID Search',
                    'Routing Action',
                    'Inputted Remarks',
                    'Assignment ID',
                    'Assignment Routing Action',
                    RESULT_COL_STATUS,
                    RESULT_COL_ERRORS
                }
            );
        } else {
            sheetRows.add(
                new List<String>{
                    'Case ID Search',
                    'Routing Action',
                    'Inputted Remarks',
                    RESULT_COL_STATUS,
                    RESULT_COL_ERRORS
                }
            );
        }
        if (rowResults != null && !rowResults.isEmpty()) {
            for (FEC_BatchCaseHandlingImportRow row : rowResults) {
                if (row == null) {
                    continue;
                }
                List<String> cols = new List<String>{
                    rowValue(row.caseIdSearch),
                    rowValue(row.routingAction),
                    rowValue(row.inputtedRemarks)
                };
                if (cofOrGsr) {
                    cols.add(rowValue(row.assignmentId));
                    cols.add(rowValue(row.assignmentRoutingAction));
                }
                cols.add(rowValue(resolveImportResultStatusLabel(row.status)));
                // 05/06/2026 16:00 linhdev - __Errors Export Result luôn tiếng Việt
                cols.add(rowValue(resolveImportRowResultErrors(row)));
                sheetRows.add(cols);
            }
        } else if (String.isNotBlank(batchFailureReason)) {
            // 02/06/2026 15:50 linhdev - fallback row phải ghi lỗi vào __Status/__Errors, không đẩy message sang cột Case ID Search
            Integer totalCols = cofOrGsr ? 7 : 5;
            List<String> failureRow = new List<String>();
            for (Integer i = 0; i < totalCols - 2; i++) {
                failureRow.add(FEC_ConstantCommon.STR_EMPTY);
            }
            failureRow.add('Failed');
            // 05/06/2026 16:00 linhdev - __Errors Export Result luôn tiếng Việt
            failureRow.add(
                rowValue(
                    localizeImportResultErrors(
                        resolveImportFailureReason(batchFailureReason, null)
                    )
                )
            );
            sheetRows.add(failureRow);
        } else {
            return null;
        }
        return sheetRows;
    }

    private static List<List<String>> buildEmergencyBatchResultSheetRows(
        String batchFailureReason,
        Boolean cofOrGsr
    ) {
        List<List<String>> sheetRows = new List<List<String>>();
        List<String> headers = new List<String>{ 'Case ID Search', 'Routing Action', 'Inputted Remarks' };
        if (cofOrGsr) {
            headers.add('Assignment ID');
            headers.add('Assignment Routing Action');
        }
        headers.add(RESULT_COL_STATUS);
        headers.add(RESULT_COL_ERRORS);
        sheetRows.add(headers);

        List<String> failureRow = new List<String>();
        for (Integer i = 0; i < headers.size() - 2; i++) {
            failureRow.add(FEC_ConstantCommon.STR_EMPTY);
        }
        failureRow.add('Failed');
        // 05/06/2026 16:00 linhdev - __Errors Export Result luôn tiếng Việt
        failureRow.add(
            localizeImportResultErrors(
                resolveImportFailureReason(batchFailureReason, null)
            )
        );
        sheetRows.add(failureRow);
        return sheetRows;
    }

    private static List<List<String>> buildBatchResultFromOriginalLayout(
        List<FEC_BatchCaseHandlingImportRow> rowResults
    ) {
        if (rowResults == null || rowResults.isEmpty()) {
            return null;
        }
        List<String> sourceHeaders = null;
        for (FEC_BatchCaseHandlingImportRow row : rowResults) {
            if (row != null && row.originalHeaders != null && !row.originalHeaders.isEmpty()) {
                sourceHeaders = row.originalHeaders;
                break;
            }
        }
        if (sourceHeaders == null || sourceHeaders.isEmpty()) {
            return null;
        }
        Integer inputtedRemarksIndex = findRemarkHeaderIndex(sourceHeaders);
        if (inputtedRemarksIndex < 0) {
            inputtedRemarksIndex = findHeaderIndex(sourceHeaders, LABEL_INPUTTED_REMARKS);
        }
        Integer routingActionIndex = findHeaderIndex(sourceHeaders, LABEL_ROUTING_ACTION);
        Integer assignmentRoutingActionIndex = findAssignmentRoutingHeaderIndex(sourceHeaders);
        if (assignmentRoutingActionIndex < 0) {
            assignmentRoutingActionIndex = findHeaderIndex(
                sourceHeaders,
                LABEL_ASSIGNMENT_ROUTING_ACTION
            );
        }
        Integer cpAssessmentIndex = findHeaderIndex(sourceHeaders, LABEL_CP_ASSESSMENT);
        Integer resultInsertIndex = resolveResultInsertIndex(
            sourceHeaders,
            inputtedRemarksIndex,
            cpAssessmentIndex
        );
        List<List<String>> sheetRows = new List<List<String>>();
        List<String> headers = new List<String>();
        for (Integer idx = 0; idx < sourceHeaders.size(); idx++) {
            headers.add(rowValue(sourceHeaders[idx]));
        }
        Integer headerSize = headers.size();
        insertResultColumns(headers, resultInsertIndex);
        sheetRows.add(headers);
        for (FEC_BatchCaseHandlingImportRow row : rowResults) {
            if (row == null) {
                continue;
            }
            List<String> cells = new List<String>();
            if (row.originalCells != null && !row.originalCells.isEmpty()) {
                for (String cell : row.originalCells) {
                    cells.add(rowValue(cell));
                }
            }
            while (cells.size() < headerSize) {
                cells.add(FEC_ConstantCommon.STR_EMPTY);
            }
            if (cells.size() > sourceHeaders.size()) {
                List<String> normalizedCells = new List<String>();
                for (Integer idx = 0; idx < sourceHeaders.size(); idx++) {
                    normalizedCells.add(cells[idx]);
                }
                cells = normalizedCells;
            }
            while (cells.size() < headerSize) {
                cells.add(FEC_ConstantCommon.STR_EMPTY);
            }
            String remarkForResult = FEC_ConstantCommon.STR_EMPTY;
            if (inputtedRemarksIndex >= 0 && inputtedRemarksIndex < cells.size()) {
                remarkForResult = rowValue(row.inputtedRemarks);
                if (String.isNotBlank(remarkForResult)) {
                    cells[inputtedRemarksIndex] = remarkForResult;
                }
            }
            clearRoutingCellIfRemarkBleed(
                cells,
                routingActionIndex,
                inputtedRemarksIndex,
                remarkForResult,
                row.inputtedRemarksCharLength
            );
            clearRoutingCellIfRemarkBleed(
                cells,
                assignmentRoutingActionIndex,
                inputtedRemarksIndex,
                remarkForResult,
                row.inputtedRemarksCharLength
            );
            applyValidatedRoutingToResultCells(
                cells,
                routingActionIndex,
                assignmentRoutingActionIndex,
                row
            );
            insertResultColumns(
                cells,
                resultInsertIndex,
                rowValue(resolveImportResultStatusLabel(row.status)),
                rowValue(resolveImportRowResultErrors(row))
            );
            sheetRows.add(cells);
        }
        return sheetRows;
    }

    private static String rowValue(String value) {
        return value == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(value);
    }

    // 01/06/2026 20:30 linhdev - thay layout row bằng parse server từ ContentVersion; giữ status/errors từ validate LWC
    @TestVisible
    private static List<FEC_BatchCaseHandlingImportRow> enrichImportRowsLayoutFromSourceFile(
        Id sourceContentVersionId,
        List<FEC_BatchCaseHandlingImportRow> rowResults
    ) {
        if (sourceContentVersionId == null || rowResults == null || rowResults.isEmpty()) {
            return rowResults;
        }
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult parsed =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(sourceContentVersionId);
        if (parsed == null || parsed.parseSuccess != true || parsed.inputRows == null || parsed.inputRows.isEmpty()) {
            return rowResults;
        }
        List<FEC_BatchCaseHandlingImportRow> parsedRows;
        try {
            parsedRows = (List<FEC_BatchCaseHandlingImportRow>) JSON.deserialize(
                JSON.serialize(parsed.inputRows),
                List<FEC_BatchCaseHandlingImportRow>.class
            );
        } catch (Exception ex) {
            return rowResults;
        }
        if (parsedRows == null || parsedRows.isEmpty()) {
            return rowResults;
        }
        Map<Integer, FEC_BatchCaseHandlingImportRow> lwcByDataRow = new Map<Integer, FEC_BatchCaseHandlingImportRow>();
        Map<String, FEC_BatchCaseHandlingImportRow> lwcByCaseId = new Map<String, FEC_BatchCaseHandlingImportRow>();
        for (FEC_BatchCaseHandlingImportRow lwcRow : rowResults) {
            if (lwcRow == null) {
                continue;
            }
            if (lwcRow.originalDataRowIndex != null) {
                lwcByDataRow.put(lwcRow.originalDataRowIndex, lwcRow);
            }
            String caseKey = rowValue(lwcRow.caseIdSearch);
            if (String.isNotBlank(caseKey)) {
                lwcByCaseId.put(caseKey, lwcRow);
            }
        }
        List<FEC_BatchCaseHandlingImportRow> merged = new List<FEC_BatchCaseHandlingImportRow>();
        for (FEC_BatchCaseHandlingImportRow parsedRow : parsedRows) {
            if (parsedRow == null) {
                continue;
            }
            FEC_BatchCaseHandlingImportRow lwcMatch = null;
            if (parsedRow.originalDataRowIndex != null) {
                lwcMatch = lwcByDataRow.get(parsedRow.originalDataRowIndex);
            }
            if (lwcMatch == null) {
                String caseKey = rowValue(parsedRow.caseIdSearch);
                if (String.isNotBlank(caseKey)) {
                    lwcMatch = lwcByCaseId.get(caseKey);
                }
            }
            if (lwcMatch != null) {
                mergeImportRowValidationFields(parsedRow, lwcMatch);
            }
            merged.add(parsedRow);
        }
        return merged.isEmpty() ? rowResults : merged;
    }

    @TestVisible
    private static List<String> rebuildExportCellsFromSourceFile(
        Id sourceContentVersionId,
        String sourceSheetName,
        Integer dataRowIndex0,
        List<Integer> mappedColumnIndexes,
        Integer headerSize
    ) {
        List<String> cells = new List<String>();
        Integer safeHeaderSize = headerSize == null || headerSize < 0 ? 0 : headerSize;
        for (Integer idx = 0; idx < safeHeaderSize; idx++) {
            Integer wsCol = idx;
            if (mappedColumnIndexes != null && idx < mappedColumnIndexes.size() && mappedColumnIndexes[idx] != null) {
                wsCol = mappedColumnIndexes[idx];
            }
            cells.add(
                FEC_BCH_TemplateExportService.readImportCellText(
                    sourceContentVersionId,
                    sourceSheetName,
                    dataRowIndex0,
                    wsCol
                )
            );
        }
        return cells;
    }

    private static void mergeImportRowValidationFields(
        FEC_BatchCaseHandlingImportRow target,
        FEC_BatchCaseHandlingImportRow source
    ) {
        if (target == null || source == null) {
            return;
        }
        target.status = source.status;
        target.errors = source.errors;
        // 05/06/2026 17:00 linhdev - giữ routing đã parse từ file gốc; LWC có thể lệch cột assignment sang routing case
        if (String.isBlank(target.routingAction)) {
            target.routingAction = source.routingAction;
        }
        target.inputtedRemarks = source.inputtedRemarks;
        target.inputtedRemarksCharLength = source.inputtedRemarksCharLength;
        target.assignmentId = source.assignmentId;
        if (String.isBlank(target.assignmentRoutingAction)) {
            target.assignmentRoutingAction = source.assignmentRoutingAction;
        }
        target.csD2CAssessmentType = source.csD2CAssessmentType;
        target.csSupportAssessment = source.csSupportAssessment;
        target.riskLevel = source.riskLevel;
        target.requiredAction = source.requiredAction;
        target.classificationByCS = source.classificationByCS;
        target.evaluationByCS = source.evaluationByCS;
        target.finalProduct = source.finalProduct;
        target.paymentContractAssessment = source.paymentContractAssessment;
        target.cpAssessment = source.cpAssessment;
        target.actionButtonId = source.actionButtonId;
        target.routingActionValue = source.routingActionValue;
        target.routeViaRevertButton = source.routeViaRevertButton;
        target.revertPreferRevertedChange = source.revertPreferRevertedChange;
        target.csD2CAssessmentTypeApiValue = source.csD2CAssessmentTypeApiValue;
        target.csSupportAssessmentApiValue = source.csSupportAssessmentApiValue;
        target.riskLevelApiValue = source.riskLevelApiValue;
        target.requiredActionApiValue = source.requiredActionApiValue;
        target.classificationByCSApiValue = source.classificationByCSApiValue;
        target.evaluationByCSApiValue = source.evaluationByCSApiValue;
        target.finalProductApiValue = source.finalProductApiValue;
        target.paymentContractAssessmentApiValue = source.paymentContractAssessmentApiValue;
        target.cpAssessmentApiValue = source.cpAssessmentApiValue;
        target.recordId = source.recordId;
        if (String.isNotBlank(source.caseIdSearch)) {
            target.caseIdSearch = source.caseIdSearch;
        }
    }

    private static List<Integer> buildResultMappedColumnIndexes(
        Id sourceContentVersionId,
        Integer sourceHeaderRowIndex,
        String sourceSheetName,
        List<String> sourceHeaders,
        List<FEC_BatchCaseHandlingImportRow> rowResults
    ) {
        List<Integer> mapped = new List<Integer>();
        if (sourceHeaders == null || sourceHeaders.isEmpty()) {
            return mapped;
        }
        // 01/06/2026 20:30 linhdev - map cột từ file Excel gốc (đúng Case ID cột T); LWC originalColumnIndexes hay lệch
        if (sourceContentVersionId != null) {
            mapped = FEC_BCH_TemplateExportService.resolveMappedColumnIndexesForHeaders(
                sourceContentVersionId,
                sourceHeaderRowIndex == null ? 0 : sourceHeaderRowIndex,
                sourceSheetName,
                sourceHeaders
            );
        }
        if (!mapped.isEmpty() && mapped.size() == sourceHeaders.size()) {
            return mapped;
        }
        List<Integer> worksheetCols = null;
        if (rowResults != null) {
            for (FEC_BatchCaseHandlingImportRow row : rowResults) {
                if (
                    row != null &&
                    row.originalColumnIndexes != null &&
                    !row.originalColumnIndexes.isEmpty()
                ) {
                    worksheetCols = row.originalColumnIndexes;
                    break;
                }
            }
        }
        if (worksheetCols != null && worksheetCols.size() == sourceHeaders.size()) {
            for (Integer colIdx : worksheetCols) {
                mapped.add(colIdx);
            }
            return mapped;
        }
        mapped = new List<Integer>();
        for (Integer idx = 0; idx < sourceHeaders.size(); idx++) {
            mapped.add(idx);
        }
        return mapped;
    }

    private static Integer resolveResultInsertIndex(
        List<String> sourceHeaders,
        Integer inputtedRemarksIndex,
        Integer cpAssessmentIndex
    ) {
        if (sourceHeaders == null || sourceHeaders.isEmpty()) {
            return 0;
        }
        // 29/05/2026 19:15 linhdev - gợi ý vị trí chèn; FEC_BCH_TemplateExportService căn theo cột cuối trên file Excel
        return sourceHeaders.size();
    }

    private static void insertResultColumns(List<String> cells, Integer insertIndex) {
        insertResultColumns(cells, insertIndex, RESULT_COL_STATUS, RESULT_COL_ERRORS);
    }

    private static void insertResultColumns(List<String> cells, Integer insertIndex, String statusValue, String errorsValue) {
        if (cells == null) {
            return;
        }
        Integer safeInsertIndex = insertIndex == null ? cells.size() : insertIndex;
        if (safeInsertIndex < 0) {
            safeInsertIndex = 0;
        }
        if (safeInsertIndex > cells.size()) {
            safeInsertIndex = cells.size();
        }
        cells.add(safeInsertIndex, rowValue(statusValue));
        cells.add(safeInsertIndex + 1, rowValue(errorsValue));
    }

    private static Integer findHeaderIndex(List<String> headers, String targetHeader) {
        if (headers == null || headers.isEmpty() || String.isBlank(targetHeader)) {
            return -1;
        }
        String normalizedTarget = normalizeHeaderKey(targetHeader);
        for (Integer idx = 0; idx < headers.size(); idx++) {
            if (normalizeHeaderKey(headers[idx]) == normalizedTarget) {
                return idx;
            }
        }
        return -1;
    }

    // 01/06/2026 12:30 linhdev - alias header remark khớp parse import (Input Remark / Inputted Remarks)
    private static Integer findRemarkHeaderIndex(List<String> headers) {
        if (headers == null || headers.isEmpty()) {
            return -1;
        }
        List<String> aliases = new List<String>{
            'inputtedremarks',
            'inputtedremark',
            'inputremarks',
            'inputremark'
        };
        for (Integer idx = 0; idx < headers.size(); idx++) {
            String norm = normalizeHeaderKey(headers[idx]);
            if (String.isBlank(norm)) {
                continue;
            }
            for (String alias : aliases) {
                if (norm == alias) {
                    return idx;
                }
            }
        }
        return -1;
    }

    // 01/06/2026 18:00 linhdev - ghi Case ID đúng cột Case ID trên Result; gỡ giá trị dính sai cột (vd. Plastic ID / cột I)
    @TestVisible
    private static void syncCaseIdIntoExportCells(
        List<String> cells,
        List<String> headers,
        String caseIdSearch
    ) {
        if (cells == null || headers == null || String.isBlank(caseIdSearch)) {
            return;
        }
        Integer caseHeaderIdx = findCaseIdHeaderIndex(headers);
        if (caseHeaderIdx < 0 || caseHeaderIdx >= cells.size()) {
            return;
        }
        for (Integer idx = 0; idx < cells.size(); idx++) {
            if (idx != caseHeaderIdx && caseIdSearch.equals(rowValue(cells[idx]))) {
                cells[idx] = FEC_ConstantCommon.STR_EMPTY;
            }
        }
        cells[caseHeaderIdx] = caseIdSearch;
    }

    private static Integer findCaseIdHeaderIndex(List<String> headers) {
        if (headers == null || headers.isEmpty()) {
            return -1;
        }
        List<String> aliases = new List<String>{
            'caseid',
            'caseidsearch'
        };
        for (Integer idx = 0; idx < headers.size(); idx++) {
            String norm = normalizeHeaderKey(headers[idx]);
            if (String.isBlank(norm)) {
                continue;
            }
            for (String alias : aliases) {
                if (norm == alias) {
                    return idx;
                }
            }
        }
        return -1;
    }

    private static Integer findAssignmentRoutingHeaderIndex(List<String> headers) {
        if (headers == null || headers.isEmpty()) {
            return -1;
        }
        List<String> aliases = new List<String>{ 'assignmentroutingaction' };
        for (Integer idx = 0; idx < headers.size(); idx++) {
            String norm = normalizeHeaderKey(headers[idx]);
            if (String.isBlank(norm)) {
                continue;
            }
            for (String alias : aliases) {
                if (norm == alias) {
                    return idx;
                }
            }
        }
        return -1;
    }

    // 01/06/2026 19:00 linhdev - ghi đè routing trên Result từ giá trị đã validate (không dùng originalCells bleed)
    @TestVisible
    private static void applyValidatedRoutingToResultCells(
        List<String> cells,
        Integer routingActionIndex,
        Integer assignmentRoutingActionIndex,
        FEC_BatchCaseHandlingImportRow row
    ) {
        if (cells == null || row == null) {
            return;
        }
        String assignmentRouting = rowValue(row.assignmentRoutingAction);
        if (routingActionIndex >= 0 && routingActionIndex < cells.size()) {
            String sourceRouting = rowValue(cells[routingActionIndex]);
            String validatedRouting = rowValue(row.routingAction);
            // 05/06/2026 17:00 linhdev - Result giữ Routing Action gốc từ file; không copy Assignment Routing Action sang cột case
            if (String.isNotBlank(sourceRouting)) {
                cells[routingActionIndex] = sourceRouting;
            } else if (
                String.isNotBlank(validatedRouting) &&
                validatedRouting != assignmentRouting
            ) {
                cells[routingActionIndex] = validatedRouting;
            } else {
                cells[routingActionIndex] = FEC_ConstantCommon.STR_EMPTY;
            }
        }
        if (assignmentRoutingActionIndex >= 0 && assignmentRoutingActionIndex < cells.size()) {
            if (String.isNotBlank(assignmentRouting)) {
                cells[assignmentRoutingActionIndex] = assignmentRouting;
            }
        }
    }

    // 01/06/2026 18:00 linhdev - remark bị đọc nhầm sang cột routing (LWC aoa lệch worksheet) → coi như trống
    @TestVisible
    private static String clearFieldValueIfRemarkBleed(
        String fieldVal,
        String remarkVal,
        Integer remarkCharLength
    ) {
        if (String.isBlank(fieldVal) || String.isBlank(remarkVal)) {
            return fieldVal;
        }
        if (fieldVal == remarkVal) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Integer remarkLen = remarkVal.length();
        if (remarkCharLength != null && remarkCharLength > remarkLen) {
            remarkLen = remarkCharLength;
        }
        if (remarkLen >= REMARK_MAX_LEN - 1 && fieldVal.length() == remarkLen) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return fieldVal;
    }

    // 01/06/2026 16:30 linhdev - xóa nội dung remark bị dính sang cột Routing Action khi build Result
    @TestVisible
    private static void clearRoutingCellIfRemarkBleed(
        List<String> cells,
        Integer routingActionIndex,
        Integer inputtedRemarksIndex
    ) {
        clearRoutingCellIfRemarkBleed(cells, routingActionIndex, inputtedRemarksIndex, null, null);
    }

    @TestVisible
    private static void clearRoutingCellIfRemarkBleed(
        List<String> cells,
        Integer routingActionIndex,
        Integer inputtedRemarksIndex,
        String remarkForResult,
        Integer remarkCharLength
    ) {
        if (
            cells == null ||
            routingActionIndex < 0 ||
            inputtedRemarksIndex < 0 ||
            routingActionIndex >= cells.size() ||
            inputtedRemarksIndex >= cells.size() ||
            routingActionIndex == inputtedRemarksIndex
        ) {
            return;
        }
        String remarkVal = rowValue(remarkForResult);
        if (String.isBlank(remarkVal)) {
            remarkVal = rowValue(cells[inputtedRemarksIndex]);
        }
        cells[routingActionIndex] = clearFieldValueIfRemarkBleed(
            rowValue(cells[routingActionIndex]),
            remarkVal,
            remarkCharLength
        );
    }

    private static String normalizeHeaderKey(String value) {
        if (String.isBlank(value)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String normalized = value.replaceAll('\\s+', FEC_ConstantCommon.STR_EMPTY).toLowerCase();
        normalized = normalized.replace('(', FEC_ConstantCommon.STR_EMPTY);
        normalized = normalized.replace(')', FEC_ConstantCommon.STR_EMPTY);
        normalized = normalized.replace('.', FEC_ConstantCommon.STR_EMPTY);
        normalized = normalized.replace('-', FEC_ConstantCommon.STR_EMPTY);
        normalized = normalized.replace('/', FEC_ConstantCommon.STR_EMPTY);
        return normalized;
    }

    public static Integer countFailedImportRows(List<FEC_BatchCaseHandlingImportRow> rows) {
        Integer n = 0;
        for (FEC_BatchCaseHandlingImportRow r : rows) {
            if (r != null && r.status == System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed) {
                n += 1;
            }
        }
        return n;
    }

    public static Integer countSuccessImportRows(List<FEC_BatchCaseHandlingImportRow> rows) {
        Integer n = 0;
        if (rows == null || rows.isEmpty()) {
            return n;
        }
        for (FEC_BatchCaseHandlingImportRow r : rows) {
            if (r != null && isImportRowAppliedSuccessStatus(r.status)) {
                n += 1;
            }
        }
        return n;
    }

    public static Integer countUnprocessedImportRows(List<FEC_BatchCaseHandlingImportRow> rows) {
        Integer n = 0;
        if (rows == null || rows.isEmpty()) {
            return n;
        }
        for (FEC_BatchCaseHandlingImportRow r : rows) {
            if (isImportRowUnprocessed(r)) {
                n += 1;
            }
        }
        return n;
    }

    public static void markUnprocessedImportRows(
        List<FEC_BatchCaseHandlingImportRow> rows,
        String reason
    ) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        String failureReason = String.isBlank(reason) ? ERR_IMPORT_ROW_NOT_COMPLETED : reason;
        for (FEC_BatchCaseHandlingImportRow row : rows) {
            if (!isImportRowUnprocessed(row)) {
                continue;
            }
            row.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
            if (String.isBlank(row.errors)) {
                row.errors = failureReason;
            }
        }
    }

    public static String resolveImportQueueLimitExceededReason() {
        return ERR_IMPORT_QUEUE_LIMIT_EXCEEDED;
    }

    public static String resolveBatchFailureReasonFromRows(
        List<FEC_BatchCaseHandlingImportRow> rows,
        String fallbackReason
    ) {
        String fromRows = summarizeUniqueImportRowErrors(rows, BATCH_FAILURE_REASON_MAX_UNIQUE_ERRORS);
        if (String.isNotBlank(fromRows)) {
            return fromRows;
        }
        if (String.isNotBlank(fallbackReason) && !isGenericBatchImportFailureMessage(fallbackReason)) {
            return fallbackReason;
        }
        return String.isBlank(fallbackReason) ? FEC_ConstantCommon.STR_EMPTY : fallbackReason;
    }

    public static String resolveImportRowResultErrors(FEC_BatchCaseHandlingImportRow row) {
        if (row == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (String.isNotBlank(row.errors)) {
            String resolved = resolveImportRowErrorsFromStoredValue(row);
            if (String.isNotBlank(resolved)) {
                return resolved;
            }
        }
        if (row.status == System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed) {
            return formatImportRowApplyFailureWithoutDetail(row);
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    public static void ensureFailedImportRowsHaveDetailErrors(List<FEC_BatchCaseHandlingImportRow> rows) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        for (FEC_BatchCaseHandlingImportRow row : rows) {
            if (row == null) {
                continue;
            }
            if (row.status == System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed &&
                String.isBlank(row.errors)) {
                row.errors = formatImportRowApplyFailureWithoutDetail(row);
            }
        }
    }

    private static String resolveImportRowErrorsFromStoredValue(FEC_BatchCaseHandlingImportRow row) {
        if (row == null || String.isBlank(row.errors)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (!row.errors.contains(IMPORT_ERROR_SEPARATOR)) {
            return resolveSingleImportRowStoredError(row, row.errors.trim());
        }
        List<String> parts = row.errors.split(IMPORT_ERROR_SEPARATOR);
        List<String> resolvedParts = new List<String>();
        Integer genericCount = 0;
        Integer storedCount = 0;
        for (String part : parts) {
            String trimmed = part == null ? FEC_ConstantCommon.STR_EMPTY : part.trim();
            if (String.isBlank(trimmed)) {
                continue;
            }
            storedCount++;
            if (isGenericBatchImportFailureMessage(trimmed)) {
                genericCount++;
                continue;
            }
            String resolved = localizeImportResultError(trimmed);
            if (String.isNotBlank(resolved)) {
                resolvedParts.add(resolved);
            }
        }
        if (!resolvedParts.isEmpty()) {
            return appendImportRowReferenceIfMissing(row, String.join(resolvedParts, IMPORT_ERROR_SEPARATOR));
        }
        if (storedCount > 0 && genericCount == storedCount) {
            return formatImportRowApplyFailureWithoutDetail(row);
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static String resolveSingleImportRowStoredError(
        FEC_BatchCaseHandlingImportRow row,
        String storedError
    ) {
        if (String.isBlank(storedError)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (isGenericBatchImportFailureMessage(storedError)) {
            return formatImportRowApplyFailureWithoutDetail(row);
        }
        return appendImportRowReferenceIfMissing(row, localizeImportResultError(storedError));
    }

    private static String appendImportRowReferenceIfMissing(
        FEC_BatchCaseHandlingImportRow row,
        String message
    ) {
        if (String.isBlank(message)) {
            return message;
        }
        String trimmed = message.trim();
        if (trimmed.startsWith('[')) {
            return trimmed;
        }
        return buildImportRowReference(row) + ' ' + trimmed;
    }

    private static String resolveImportFailureReason(
        String reason,
        List<FEC_BatchCaseHandlingImportRow> rows
    ) {
        String resolved = String.isBlank(reason)
            ? resolveBatchFailureReasonFromRows(rows, ERR_IMPORT_ROW_NOT_COMPLETED)
            : reason;
        if (isGenericBatchImportFailureMessage(resolved)) {
            resolved = resolveBatchFailureReasonFromRows(rows, resolved);
        }
        return resolved;
    }

    @TestVisible
    private static Boolean isGenericBatchImportFailureMessage(String message) {
        if (String.isBlank(message)) {
            return true;
        }
        return message == System.Label.FEC_BCH_ImportFailed
            || message == System.Label.FEC_BCH_Import_Rows_Invalid;
    }

    private static String summarizeUniqueImportRowErrors(
        List<FEC_BatchCaseHandlingImportRow> rows,
        Integer maxUnique
    ) {
        if (rows == null || rows.isEmpty() || maxUnique == null || maxUnique <= 0) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Set<String> seen = new Set<String>();
        List<String> ordered = new List<String>();
        for (FEC_BatchCaseHandlingImportRow row : rows) {
            if (row == null || String.isBlank(row.errors)) {
                continue;
            }
            List<String> parts = row.errors.contains(IMPORT_ERROR_SEPARATOR)
                ? row.errors.split(IMPORT_ERROR_SEPARATOR)
                : new List<String>{ row.errors };
            for (String part : parts) {
                String trimmed = part == null ? FEC_ConstantCommon.STR_EMPTY : part.trim();
                if (String.isBlank(trimmed) || seen.contains(trimmed)) {
                    continue;
                }
                seen.add(trimmed);
                ordered.add(trimmed);
                if (ordered.size() >= maxUnique) {
                    break;
                }
            }
            if (ordered.size() >= maxUnique) {
                break;
            }
        }
        if (ordered.isEmpty()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Integer totalFailed = countFailedImportRows(rows);
        String summary = String.join(ordered, IMPORT_ERROR_SEPARATOR);
        if (totalFailed > ordered.size()) {
            summary += IMPORT_ERROR_SEPARATOR +
                '(và ' +
                String.valueOf(totalFailed - ordered.size()) +
                ' lỗi khác trên các dòng import)';
        }
        return summary;
    }

    public static List<FEC_BatchCaseHandlingImportRow> prepareImportRowsForApplyChain(
        List<FEC_BatchCaseHandlingImportRow> rows
    ) {
        if (rows == null || rows.isEmpty()) {
            return rows;
        }
        for (FEC_BatchCaseHandlingImportRow row : rows) {
            if (row == null) {
                continue;
            }
            row.originalHeaders = null;
            row.originalCells = null;
            row.originalColumnIndexes = null;
        }
        return rows;
    }

    public static String serializeImportRowsForApplyChain(List<FEC_BatchCaseHandlingImportRow> rows) {
        return JSON.serialize(prepareImportRowsForApplyChain(rows));
    }

    private static Boolean isImportRowUnprocessed(FEC_BatchCaseHandlingImportRow row) {
        return row != null &&
            shouldApplyImportRow(row) &&
            !isImportRowAppliedSuccessStatus(row.status) &&
            row.status != System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
    }

    private static Boolean isImportRowAppliedSuccessStatus(String rowStatus) {
        return rowStatus == System.Label.FEC_Batch_Case_Handling_Success;
    }

    // 30/05/2026 18:30 linhdev - đọc remark từ file upload gốc trước validate (LWC/JSON có thể thiếu chuỗi dài)
    public static void enrichInputtedRemarksFromImportFile(Id contentVersionId, List<Object> inputRows) {
        enrichImportRowValidateFieldsFromImportFile(contentVersionId, inputRows);
    }

    // 01/06/2026 22:00 linhdev - đọc Case ID/Routing/Remark/D2C từ file Excel trước validate (LWC aoa hay lệch cột)
    public static void enrichImportRowValidateFieldsFromImportFile(Id contentVersionId, List<Object> inputRows) {
        if (contentVersionId == null || inputRows == null || inputRows.isEmpty()) {
            return;
        }
        for (Object rowObj : inputRows) {
            if (!(rowObj instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> row = (Map<String, Object>) rowObj;
            Integer dataRowIndex = pickRowInteger(row, 'originalDataRowIndex');
            List<String> headers = pickRowStringList(row, 'originalHeaders');
            List<Integer> columnIndexes = pickRowIntegerList(row, 'originalColumnIndexes');
            if (dataRowIndex == null || headers == null || headers.isEmpty()) {
                continue;
            }
            String sheetName = pickRowString(row, new List<String>{ 'originalsheetname' });
            Integer headerRowIndex = pickRowInteger(row, 'originalHeaderRowIndex');
            Boolean isCofGsrTemplate = findAssignmentRoutingHeaderIndex(headers) >= 0;
            Integer routingHeaderIdx = findHeaderIndex(headers, LABEL_ROUTING_ACTION);
            Integer assignmentRoutingHeaderIdx = findAssignmentRoutingHeaderIndex(headers);
            putImportFieldIfBlank(
                row,
                new List<String>{ 'caseidsearch', 'caseid' },
                readImportValidateCell(contentVersionId, sheetName, dataRowIndex, headers, columnIndexes, findCaseIdHeaderIndex(headers))
            );
            if (isCofGsrTemplate && routingHeaderIdx >= 0) {
                // 05/06/2026 20:00 linhdev - COF/GSR: Routing Action (case) luôn lấy từ file server (ghi đè LWC lệch cột)
                putImportFieldFromFile(
                    row,
                    new List<String>{ 'routingaction' },
                    readImportValidateCellFromServerMap(
                        contentVersionId,
                        sheetName,
                        dataRowIndex,
                        headers,
                        headerRowIndex,
                        routingHeaderIdx
                    )
                );
            } else {
                putImportFieldIfBlank(
                    row,
                    new List<String>{ 'routingaction' },
                    readImportValidateCell(contentVersionId, sheetName, dataRowIndex, headers, columnIndexes, routingHeaderIdx)
                );
            }
            if (isCofGsrTemplate && assignmentRoutingHeaderIdx >= 0) {
                // 05/06/2026 20:00 linhdev - COF/GSR: Assignment Routing Action luôn lấy từ file server
                putImportFieldFromFile(
                    row,
                    new List<String>{ 'assignmentroutingaction' },
                    readImportValidateCellFromServerMap(
                        contentVersionId,
                        sheetName,
                        dataRowIndex,
                        headers,
                        headerRowIndex,
                        assignmentRoutingHeaderIdx
                    )
                );
            } else {
                putImportFieldIfBlank(
                    row,
                    new List<String>{ 'assignmentroutingaction' },
                    readImportValidateCell(
                        contentVersionId,
                        sheetName,
                        dataRowIndex,
                        headers,
                        columnIndexes,
                        assignmentRoutingHeaderIdx
                    )
                );
            }
            putImportFieldIfBlank(
                row,
                new List<String>{ 'assignmentid' },
                readImportValidateCell(contentVersionId, sheetName, dataRowIndex, headers, columnIndexes, findHeaderIndex(headers, 'Assignment ID'))
            );
            Integer remarkHeaderIdx = findRemarkHeaderIndex(headers);
            if (remarkHeaderIdx >= 0) {
                Integer worksheetCol = remarkHeaderIdx;
                if (columnIndexes != null && remarkHeaderIdx < columnIndexes.size() && columnIndexes[remarkHeaderIdx] != null) {
                    worksheetCol = columnIndexes[remarkHeaderIdx];
                }
                String fileRemark = FEC_BCH_TemplateExportService.readImportCellText(
                    contentVersionId,
                    sheetName,
                    dataRowIndex,
                    worksheetCol
                );
                if (String.isNotBlank(fileRemark)) {
                    String currentRemark = pickRowString(
                        row,
                        new List<String>{ 'inputtedremarks', 'inputtedremark', 'inputremarks', 'inputremark' }
                    );
                    Integer currentCharLength = pickRowInteger(row, 'inputtedRemarksCharLength');
                    Integer fileLen = FEC_BCH_TemplateExportService.readImportCellTextLength(
                        contentVersionId,
                        sheetName,
                        dataRowIndex,
                        worksheetCol
                    );
                    if (String.isBlank(currentRemark) || fileRemark.length() > currentRemark.length()) {
                        row.put('inputtedRemarks', fileRemark);
                    }
                    if (currentCharLength == null || fileLen > currentCharLength) {
                        row.put('inputtedRemarksCharLength', fileLen);
                    }
                }
            }
            putImportFieldIfBlank(
                row,
                new List<String>{ 'csd2cassessment', 'csd2cassessmenttype', 'csd2cdanhgiayeucau', 'csd2cđánhgiáyêucầu' },
                readImportValidateCell(contentVersionId, sheetName, dataRowIndex, headers, columnIndexes, findHeaderIndex(headers, LABEL_CS_D2C_ASSESSMENT))
            );
            putImportFieldIfBlank(
                row,
                new List<String>{ 'risklevel', 'mucdoruiro', 'mứcđộrủiro' },
                readImportValidateCell(contentVersionId, sheetName, dataRowIndex, headers, columnIndexes, findHeaderIndex(headers, LABEL_RISK_LEVEL))
            );
            putImportFieldIfBlank(
                row,
                new List<String>{ 'requiredaction', 'hanhdongcanthiet', 'hànhđộngcầnthiết', 'requiredcorrectiveaction' },
                readImportValidateCell(contentVersionId, sheetName, dataRowIndex, headers, columnIndexes, findHeaderIndex(headers, LABEL_REQUIRED_ACTION))
            );
            putImportFieldIfBlank(
                row,
                new List<String>{ 'cssupportassessment', 'cssupportassessmenttype', 'cssupportdanhgiayeucau', 'cssupportđánhgiáyêucầu' },
                readImportValidateCell(contentVersionId, sheetName, dataRowIndex, headers, columnIndexes, findHeaderIndex(headers, LABEL_CS_SUPPORT_ASSESSMENT))
            );
            putImportFieldIfBlank(
                row,
                new List<String>{ 'cpassessment', 'cpdanhgiayeucau', 'cpđánhgiáyêucầu' },
                readImportValidateCell(contentVersionId, sheetName, dataRowIndex, headers, columnIndexes, findHeaderIndex(headers, LABEL_CP_ASSESSMENT))
            );
        }
    }

    private static String readImportValidateCell(
        Id contentVersionId,
        String sheetName,
        Integer dataRowIndex,
        List<String> headers,
        List<Integer> columnIndexes,
        Integer headerIdx
    ) {
        if (contentVersionId == null || dataRowIndex == null || headers == null || headerIdx == null || headerIdx < 0) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Integer worksheetCol = headerIdx;
        if (columnIndexes != null && headerIdx < columnIndexes.size() && columnIndexes[headerIdx] != null) {
            worksheetCol = columnIndexes[headerIdx];
        }
        return FEC_BCH_TemplateExportService.readImportCellText(
            contentVersionId,
            sheetName,
            dataRowIndex,
            worksheetCol
        );
    }

    // 05/06/2026 20:00 linhdev - map cột từ file Excel server (không tin originalColumnIndexes LWC)
    @TestVisible
    private static String readImportValidateCellFromServerMap(
        Id contentVersionId,
        String sheetName,
        Integer dataRowIndex,
        List<String> headers,
        Integer headerRowIndex,
        Integer headerIdx
    ) {
        if (contentVersionId == null || dataRowIndex == null || headers == null || headerIdx == null || headerIdx < 0) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        List<Integer> mapped = FEC_BCH_TemplateExportService.resolveMappedColumnIndexesForHeaders(
            contentVersionId,
            headerRowIndex == null || headerRowIndex < 0 ? 0 : headerRowIndex,
            sheetName,
            headers
        );
        Integer worksheetCol = headerIdx;
        if (mapped != null && headerIdx < mapped.size() && mapped[headerIdx] != null) {
            worksheetCol = mapped[headerIdx];
        }
        return FEC_BCH_TemplateExportService.readImportCellText(
            contentVersionId,
            sheetName,
            dataRowIndex,
            worksheetCol
        );
    }

    // 05/06/2026 20:00 linhdev - ghi đè field từ file (kể cả blank) để xóa bleed LWC
    private static void putImportFieldFromFile(Map<String, Object> row, List<String> keys, String fileValue) {
        if (row == null || keys == null || keys.isEmpty()) {
            return;
        }
        row.put(keys[0], fileValue == null ? FEC_ConstantCommon.STR_EMPTY : fileValue);
    }

    private static void putImportFieldIfBlank(Map<String, Object> row, List<String> keys, String fileValue) {
        if (row == null || keys == null || keys.isEmpty() || String.isBlank(fileValue)) {
            return;
        }
        String current = pickRowString(row, keys);
        if (String.isNotBlank(current)) {
            return;
        }
        row.put(keys[0], fileValue);
    }

    // 05/06/2026 18:30 linhdev - file gốc trống Routing Action (case) nhưng JSON/LWC dính Assignment Routing → xóa trước validate
    @TestVisible
    private static void sanitizeCofGsrCaseRoutingBleedFromAssignment(FEC_BatchCaseHandlingImportRow rr) {
        if (rr == null || findAssignmentRoutingHeaderIndex(rr.originalHeaders) < 0) {
            return;
        }
        // 05/06/2026 20:00 linhdev - originalCells LWC lệch cột: routingAction trùng assignment → coi như chỉ nhập assignment
        if (
            String.isNotBlank(rr.routingAction) &&
            String.isNotBlank(rr.assignmentRoutingAction) &&
            rr.routingAction == rr.assignmentRoutingAction
        ) {
            rr.routingAction = FEC_ConstantCommon.STR_EMPTY;
            return;
        }
        if (String.isBlank(rr.routingAction) || String.isBlank(rr.assignmentRoutingAction)) {
            return;
        }
        String sourceRouting = cellTextAtOriginalLayout(rr, findHeaderIndex(rr.originalHeaders, LABEL_ROUTING_ACTION));
        if (String.isBlank(sourceRouting)) {
            rr.routingAction = FEC_ConstantCommon.STR_EMPTY;
        }
    }

    // 01/06/2026 22:00 linhdev - bù field validate từ originalCells khi LWC gửi JSON trống/lệch cột
    @TestVisible
    private static void enrichImportRowValidateFieldsFromOriginalLayout(FEC_BatchCaseHandlingImportRow rr) {
        if (rr == null || rr.originalHeaders == null || rr.originalCells == null || rr.originalCells.isEmpty()) {
            return;
        }
        if (String.isBlank(rr.caseIdSearch)) {
            Integer caseIdx = findCaseIdHeaderIndex(rr.originalHeaders);
            rr.caseIdSearch = cellTextAtOriginalLayout(rr, caseIdx);
        }
        if (String.isBlank(rr.routingAction)) {
            rr.routingAction = cellTextAtOriginalLayout(rr, findHeaderIndex(rr.originalHeaders, LABEL_ROUTING_ACTION));
        }
        if (String.isBlank(rr.inputtedRemarks)) {
            rr.inputtedRemarks = cellTextAtOriginalLayout(rr, findRemarkHeaderIndex(rr.originalHeaders));
        }
        if (String.isBlank(rr.assignmentRoutingAction)) {
            rr.assignmentRoutingAction = cellTextAtOriginalLayout(rr, findAssignmentRoutingHeaderIndex(rr.originalHeaders));
        }
        if (String.isBlank(rr.assignmentId)) {
            rr.assignmentId = cellTextAtOriginalLayout(rr, findHeaderIndex(rr.originalHeaders, 'Assignment ID'));
        }
        if (String.isBlank(rr.csD2CAssessmentType)) {
            rr.csD2CAssessmentType = cellTextAtOriginalLayout(rr, findHeaderIndex(rr.originalHeaders, LABEL_CS_D2C_ASSESSMENT));
        }
        if (String.isBlank(rr.csSupportAssessment)) {
            rr.csSupportAssessment = cellTextAtOriginalLayout(rr, findHeaderIndex(rr.originalHeaders, LABEL_CS_SUPPORT_ASSESSMENT));
        }
        if (String.isBlank(rr.riskLevel)) {
            rr.riskLevel = cellTextAtOriginalLayout(rr, findHeaderIndex(rr.originalHeaders, LABEL_RISK_LEVEL));
        }
        if (String.isBlank(rr.requiredAction)) {
            rr.requiredAction = cellTextAtOriginalLayout(rr, findHeaderIndex(rr.originalHeaders, LABEL_REQUIRED_ACTION));
        }
        if (String.isBlank(rr.cpAssessment)) {
            rr.cpAssessment = cellTextAtOriginalLayout(rr, findHeaderIndex(rr.originalHeaders, LABEL_CP_ASSESSMENT));
        }
        if (String.isBlank(rr.paymentContractAssessment)) {
            rr.paymentContractAssessment = cellTextAtOriginalLayout(
                rr,
                findHeaderIndex(rr.originalHeaders, LABEL_PAYMENT_CONTRACT_ASSESSMENT)
            );
        }
    }

    private static String cellTextAtOriginalLayout(FEC_BatchCaseHandlingImportRow rr, Integer headerIdx) {
        if (rr == null || headerIdx == null || headerIdx < 0 || rr.originalCells == null || headerIdx >= rr.originalCells.size()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String val = rr.originalCells[headerIdx];
        return val == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(val).trim();
    }

    public static List<FEC_BatchCaseHandlingImportRow> validateCaseHandlingImportRows(List<Object> inputRows, Boolean cofOrGsr) {
        List<FEC_BatchCaseHandlingImportRow> output = buildImportRowsFromInputObjects(inputRows);
        ImportValidateChunkContext ctx = prepareImportValidateChunkContext(output, cofOrGsr);
        validateImportRowsChunk(output, ctx, 0, output.size());
        return output;
    }

    public static List<FEC_BatchCaseHandlingImportRow> buildImportRowsFromInputObjects(List<Object> inputRows) {
        List<FEC_BatchCaseHandlingImportRow> output = new List<FEC_BatchCaseHandlingImportRow>();
        if (inputRows == null || inputRows.isEmpty()) {
            return output;
        }
        for (Object rowObj : inputRows) {
            if (!(rowObj instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> row = (Map<String, Object>) rowObj;
            FEC_BatchCaseHandlingImportRow rr = new FEC_BatchCaseHandlingImportRow();
            rr.caseIdSearch = pickRowString(row, new List<String>{ 'caseidsearch', 'caseid' });
            rr.routingAction = pickRowString(row, new List<String>{ 'routingaction' });
            rr.inputtedRemarks = pickRowString(
                row,
                new List<String>{ 'inputtedremarks', 'inputtedremark', 'inputremarks', 'inputremark' }
            );
            rr.assignmentId = pickRowString(row, new List<String>{ 'assignmentid' });
            rr.assignmentRoutingAction = pickRowString(row, new List<String>{ 'assignmentroutingaction' });
            rr.csD2CAssessmentType = pickRowString(
                row,
                new List<String>{ 'csd2cđánhgiáyêucầu', 'csd2cdanhgiayeucau', 'csd2cassessment', 'csd2cassessmenttype' }
            );
            rr.csSupportAssessment = pickRowString(
                row,
                new List<String>{
                    'cssupportđánhgiáyêucầu',
                    'cssupportdanhgiayeucau',
                    'cssupportassessment',
                    'cssupportassessmenttype',
                    'cssupportevaluation'
                }
            );
            rr.riskLevel = pickRowString(
                row,
                new List<String>{ 'mứcđộrủiro', 'mucdoruiro', 'risklevel' }
            );
            rr.requiredAction = pickRowString(
                row,
                new List<String>{ 'hànhđộngcầnthiết', 'hanhdongcanthiet', 'requiredaction', 'requiredcorrectiveaction' }
            );
            rr.classificationByCS = pickRowString(
                row,
                new List<String>{ 'classificationbycs' }
            );
            rr.evaluationByCS = pickRowString(
                row,
                new List<String>{ 'evaluationbycs' }
            );
            rr.finalProduct = pickRowString(
                row,
                new List<String>{ 'finalproduct' }
            );
            rr.paymentContractAssessment = pickRowString(
                row,
                new List<String>{
                    'paymentđánhgiáyêucầuđónghợpđồng',
                    'paymentdanhgiayeucaudonghopdong',
                    'paymentcontractassessment',
                    'rdpaymentcontractassessment'
                }
            );
            rr.cpAssessment = pickRowString(
                row,
                new List<String>{
                    'cpđánhgiáyêucầu',
                    'cpdanhgiayeucau',
                    'cpassessment',
                    'contractprocessingassessment'
                }
            );
            // 28/05/2026 16:20 linhdev - giữ nguyên header/cell gốc để server tự xuất Result đúng file user import
            rr.originalHeaders = pickRowStringList(row, 'originalHeaders');
            rr.originalCells = pickRowStringList(row, 'originalCells');
            rr.originalColumnIndexes = pickRowIntegerList(row, 'originalColumnIndexes');
            rr.originalHeaderRowIndex = pickRowInteger(row, 'originalHeaderRowIndex');
            rr.originalDataRowIndex = pickRowInteger(row, 'originalDataRowIndex');
            rr.originalSheetName = pickRowString(row, new List<String>{ 'originalsheetname' });
            // 01/06/2026 22:00 linhdev - bù Case ID/Routing/Remark/D2C từ originalCells khi JSON LWC trống
            enrichImportRowValidateFieldsFromOriginalLayout(rr);
            // 30/05/2026 18:30 linhdev - đồng bộ remark từ field/originalCells/charLength (tránh truncate 32,768 che lỗi quá dài)
            rr.inputtedRemarks = resolveInputtedRemarksValue(row, rr);
            rr.inputtedRemarksCharLength = resolveInputtedRemarksCharLength(row, rr);
            // 01/06/2026 18:00 linhdev - LWC aoa có thể gửi remark vào assignmentRoutingAction; xóa trước validate
            rr.assignmentRoutingAction = clearFieldValueIfRemarkBleed(
                rr.assignmentRoutingAction,
                rr.inputtedRemarks,
                rr.inputtedRemarksCharLength
            );
            rr.routingAction = clearFieldValueIfRemarkBleed(
                rr.routingAction,
                rr.inputtedRemarks,
                rr.inputtedRemarksCharLength
            );
            // 05/06/2026 18:30 linhdev - tránh __Errors báo nhập cả 2 routing khi user chỉ nhập Assignment Routing Action
            sanitizeCofGsrCaseRoutingBleedFromAssignment(rr);
            rr.recordId = FEC_ConstantCommon.STR_EMPTY;
            // 24/06/2026 phong - không set Success tại validate time; chỉ set sau khi apply thực sự thành công
            // để tránh file result hiện "Success" cho rows chưa được xử lý (queueable chain bị cắt / exception)
            rr.status = null;
            rr.errors = FEC_ConstantCommon.STR_EMPTY;
            output.add(rr);
        }
        return output;
    }

    public static ImportValidateChunkContext prepareImportValidateChunkContext(
        List<FEC_BatchCaseHandlingImportRow> output,
        Boolean cofOrGsr
    ) {
        ImportValidateChunkContext ctx = new ImportValidateChunkContext();
        ctx.cofOrGsr = cofOrGsr == true;
        ctx.caseBySearch = new Map<String, Case>();
        ctx.businessProcessCodeByCaseId = new Map<Id, String>();
        ctx.seenCaseSearch = new Set<String>();
        ctx.routingSignatureByCaseSearch = new Map<String, String>();
        if (output == null || output.isEmpty()) {
            return ctx;
        }
        Set<String> searchKeys = new Set<String>();
        for (FEC_BatchCaseHandlingImportRow rr : output) {
            if (rr != null && String.isNotBlank(rr.caseIdSearch)) {
                searchKeys.add(rr.caseIdSearch);
            }
        }
        if (!searchKeys.isEmpty()) {
            List<String> searchKeyList = new List<String>(searchKeys);
            for (Integer startIdx = 0; startIdx < searchKeyList.size(); startIdx += 5000) {
                Integer endIdx = Math.min(startIdx + 5000, searchKeyList.size());
                List<String> keyChunk = new List<String>();
                for (Integer idx = startIdx; idx < endIdx; idx++) {
                    keyChunk.add(searchKeyList[idx]);
                }
                for (Case c : [
                    SELECT Id, IsClosed, FEC_ID_Search__c, OwnerId, FEC_Current_Case_Stage__c,
                        FEC_Assignment_Count__c,
                        FEC_Business_Process__r.FEC_Code__c, FEC_Current_Case_Stage__r.FEC_Business_Process__r.FEC_Code__c
                    FROM Case
                    WHERE FEC_ID_Search__c IN :keyChunk
                ]) {
                    if (c.FEC_ID_Search__c != null) {
                        ctx.caseBySearch.put(c.FEC_ID_Search__c, c);
                        ctx.businessProcessCodeByCaseId.put(c.Id, resolveCaseBusinessProcessCode(c));
                    }
                }
            }
        }
        Set<String> assignmentNames = new Set<String>();
        Set<Id> assignmentRecordIds = new Set<Id>();
        for (FEC_BatchCaseHandlingImportRow rr : output) {
            if (ctx.cofOrGsr != true || rr == null || String.isBlank(rr.assignmentId)) {
                continue;
            }
            collectAssignmentLookupKeys(rr.assignmentId, assignmentNames, assignmentRecordIds);
        }
        ctx.assignmentByName = loadAssignmentsByName(assignmentNames);
        ctx.assignmentByRecordId = loadAssignmentsByRecordId(assignmentRecordIds);
        ctx.currentUserId = UserInfo.getUserId();
        ctx.currentUserGroup = null;
        List<User> importUsers = [
            SELECT FEC_User_Group__c
            FROM User
            WHERE Id = :ctx.currentUserId
            LIMIT 1
        ];
        if (!importUsers.isEmpty()) {
            ctx.currentUserGroup = importUsers[0].FEC_User_Group__c;
        }
        Set<Id> stageIds = new Set<Id>();
        for (Case c : ctx.caseBySearch.values()) {
            if (c != null && c.FEC_Current_Case_Stage__c != null) {
                stageIds.add(c.FEC_Current_Case_Stage__c);
            }
        }
        ctx.configuredLabelsByStage = loadConfiguredLabelsByStage(stageIds);
        FEC_BatchCaseHandlingPicklistResolver.clearCache();
        FEC_BCH_ImportRoutingResolver.clearCache();
        FEC_BCH_ImportRoutingResolver.preloadStageScreens(stageIds, ctx.currentUserGroup);
        ctx.picklistValueByNormByField =
            FEC_BatchCaseHandlingPicklistResolver.buildNormalizedToApiValueByField(
                importPicklistFieldApis()
            );
        ctx.currentUserQueueIds = FEC_AssignmentListHandler.getCurrentUserQueueIds(ctx.currentUserId);
        return ctx;
    }

    public static void validateImportRowsChunk(
        List<FEC_BatchCaseHandlingImportRow> output,
        ImportValidateChunkContext ctx,
        Integer startIdx,
        Integer endIdx
    ) {
        if (output == null || output.isEmpty() || ctx == null || startIdx == null || endIdx == null) {
            return;
        }
        Integer safeStart = startIdx < 0 ? 0 : startIdx;
        Integer safeEnd = endIdx > output.size() ? output.size() : endIdx;
        if (safeStart >= safeEnd) {
            return;
        }
        for (Integer rowIdx = safeStart; rowIdx < safeEnd; rowIdx++) {
            FEC_BatchCaseHandlingImportRow rr = output[rowIdx];
            if (rr == null) {
                continue;
            }
            List<String> errs = new List<String>();
            Case matched = null;
            try {
            // 29/05/2026 19:30 linhdev - validate Inputted Remarks trước routing/scope (đúng message; remark > 32,768 không làm vỡ validate sau)
            addInputtedRemarksValidationErrors(errs, rr.inputtedRemarks, rr.inputtedRemarksCharLength);
            // 30/05/2026 16:15 linhdev - remark > 32,768: chỉ giữ lỗi remark + Case ID (tránh exception/heap che mất message)
            Integer effectiveRemarkLen = resolveEffectiveInputtedRemarksLength(
                rr.inputtedRemarks,
                rr.inputtedRemarksCharLength
            );
            Boolean remarkOverMax = isInputtedRemarksOverMaxLength(effectiveRemarkLen);
            if (String.isBlank(rr.caseIdSearch)) {
                addImportError(errs, System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Case_Id);
            }
            matched = String.isNotBlank(rr.caseIdSearch) ? ctx.caseBySearch.get(rr.caseIdSearch) : null;
            if (String.isNotBlank(rr.caseIdSearch) && matched == null) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Case_Id_Not_Found);
            } else if (matched != null && matched.IsClosed) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Case_Closed);
            }
            if (!remarkOverMax) {
            if (String.isNotBlank(rr.caseIdSearch)) {
                if (ctx.seenCaseSearch.contains(rr.caseIdSearch)) {
                    errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Duplicate_Case_Id);
                } else {
                    ctx.seenCaseSearch.add(rr.caseIdSearch);
                }
                String routingSig = buildRoutingSignature(rr, ctx.cofOrGsr);
                if (ctx.routingSignatureByCaseSearch.containsKey(rr.caseIdSearch)) {
                    if (ctx.routingSignatureByCaseSearch.get(rr.caseIdSearch) != routingSig) {
                        errs.add(ERR_ROUTING_CONFLICT);
                    }
                } else if (String.isNotBlank(routingSig)) {
                    ctx.routingSignatureByCaseSearch.put(rr.caseIdSearch, routingSig);
                }
            }

            if (matched != null && ctx.cofOrGsr != true) {
                String ownerAccessErr = validateNonCofGsrCaseImportOwnerAccess(matched, ctx);
                if (String.isNotBlank(ownerAccessErr)) {
                    errs.add(ownerAccessErr);
                }
                FEC_BatchCaseHandlingImportProfile.ImportScope importScope =
                    FEC_BatchCaseHandlingImportProfile.resolveForCase(
                        resolveImportValidateBusinessProcessCode(matched, ctx),
                        ctx.currentUserGroup
                    );
                if (importScope != null && importScope.allowed == false) {
                    addImportError(errs, importScope.errorMessage);
                } else if (importScope != null) {
                    errs.addAll(
                        validateScopeFieldsForCase(
                            rr,
                            matched,
                            importScope,
                            ctx.configuredLabelsByStage,
                            ctx.picklistValueByNormByField
                        )
                    );
                }
            }

            // 28/05/2026 14:30 linhdev - resolve Routing Action vs Datagroup (tránh duplicate với block bên dưới)
            List<String> resolvedRoutingErrs = validateResolvedRoutingForRow(rr, matched, ctx.cofOrGsr);
            errs.addAll(resolvedRoutingErrs);

            //PhongBT 29/05/26: COF/GSR — Routing Action (case) Revert/Update/Escalate khi Case có Assignment.
            if (ctx.cofOrGsr == true && matched != null) {
                String routingBlockedByAssignment = validateCaseRoutingActionBlockedByAssignmentCount(rr, matched);
                if (String.isNotBlank(routingBlockedByAssignment)) {
                    errs.add(routingBlockedByAssignment);
                }
            }

            if (ctx.cofOrGsr) {
                Boolean hasAssignment = String.isNotBlank(rr.assignmentId);
                if (hasAssignment) {
                    FEC_Assignment__c asg = resolveAssignmentForImport(
                        rr.assignmentId,
                        ctx.assignmentByName,
                        ctx.assignmentByRecordId,
                        matched == null ? null : matched.Id
                    );
                    if (asg == null) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Id_Not_Found);
                    } else if (matched != null && asg.FEC_Case__c != matched.Id) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Id_Not_Found);
                    } else if (String.isNotBlank(asg.FEC_Assignment_Status__c) && asg.FEC_Assignment_Status__c.startsWith('Resolved-')) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Closed);
                    }
                    if (String.isBlank(rr.routingAction) && String.isBlank(rr.assignmentRoutingAction)) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Or_Assignment_Routing);
                    }
                    if (String.isNotBlank(rr.routingAction) && String.isBlank(rr.actionButtonId)) {
                        RoutingParseResult routingParsed = parseRoutingPattern(rr.routingAction);
                        String caseMethod = routingParsed == null ? null : routingParsed.methodKey;
                        // 28/05/2026 14:30 linhdev - không add lại lỗi Datagroup nếu validateResolvedRoutingForRow đã báo
                        if (caseMethod == null) {
                            if (!resolvedRoutingErrs.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid)) {
                                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid);
                            }
                        //PhongBT 29/05/26: thêm update vào datagroup cho Assignment Routing Action
                        } else if (
                            !isResolvedOrRejectCaseRouting(caseMethod) &&
                            !isCofGsrImportUpdateAction(true, rr.routingAction)
                        ) {
                            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Resolve_Only);
                        }
                    }
                    //PhongBT 29/05/26: thêm update vào datagroup cho Assignment Routing Action
                    if (String.isNotBlank(rr.assignmentRoutingAction) && String.isBlank(rr.actionButtonId)) {
                        if (!isCofGsrImportAllowedAssignmentRoutingAction(true, rr.assignmentRoutingAction)) {
                            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Invalid);
                        }
                    }
                } else {
                    if (String.isBlank(rr.routingAction) && String.isBlank(rr.assignmentRoutingAction)) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Action);
                    //PhongBT 29/05/26: thêm update vào datagroup cho Assignment Routing Action
                    } else if (
                        String.isBlank(rr.routingAction) &&
                        String.isNotBlank(rr.assignmentRoutingAction) &&
                        String.isBlank(rr.actionButtonId) &&
                        !isCofGsrImportAllowedAssignmentRoutingAction(true, rr.assignmentRoutingAction)
                    ) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Invalid);
                    }
                    if (String.isNotBlank(rr.assignmentRoutingAction)) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Without_Assignment_Id);
                    }
                }
            } else {
                if (String.isNotBlank(rr.assignmentRoutingAction)) {
                    errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_No_Assignment_Routing_For_Process);
                }
                if (String.isNotBlank(rr.assignmentId)) {
                    errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_No_Assignment_Id_For_Process);
                }
                // 28/05/2026 14:30 linhdev - thiếu Routing Action; lỗi Datagroup chỉ từ validateResolvedRoutingForRow (tránh double message)
                if (String.isBlank(rr.routingAction)) {
                    errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Action);
                }
            }

            }

            } catch (Exception rowEx) {
                addImportError(errs, formatImportRowValidateException(rr, rowEx));
            }

            if (!errs.isEmpty()) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = joinImportErrors(errs);
            } else {
                rr.recordId = matched == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(matched.Id);
            }
        }
    }

    public static String serializeImportValidateChunkContext(ImportValidateChunkContext ctx) {
        ImportValidateChunkStatePayload payload = new ImportValidateChunkStatePayload();
        if (ctx == null) {
            payload.prepared = false;
            return JSON.serialize(payload);
        }
        payload.prepared = true;
        payload.cofOrGsr = ctx.cofOrGsr == true;
        payload.currentUserGroup = ctx.currentUserGroup;
        payload.seenCaseSearch = ctx.seenCaseSearch == null
            ? new List<String>()
            : new List<String>(ctx.seenCaseSearch);
        payload.routingSignatureByCaseSearch = ctx.routingSignatureByCaseSearch == null
            ? new Map<String, String>()
            : new Map<String, String>(ctx.routingSignatureByCaseSearch);
        payload.caseSnaps = new List<ImportCaseValidateSnap>();
        if (ctx.caseBySearch != null) {
            for (String searchKey : ctx.caseBySearch.keySet()) {
                Case matched = ctx.caseBySearch.get(searchKey);
                if (matched == null) {
                    continue;
                }
                ImportCaseValidateSnap snap = new ImportCaseValidateSnap();
                snap.searchKey = searchKey;
                snap.caseId = matched.Id;
                snap.isClosed = matched.IsClosed;
                snap.ownerId = matched.OwnerId;
                snap.currentStageId = matched.FEC_Current_Case_Stage__c;
                snap.assignmentCount = matched.FEC_Assignment_Count__c;
                snap.businessProcessCode = ctx.businessProcessCodeByCaseId == null
                    ? resolveCaseBusinessProcessCode(matched)
                    : ctx.businessProcessCodeByCaseId.get(matched.Id);
                payload.caseSnaps.add(snap);
            }
        }
        payload.assignmentSnapsByName = new List<ImportAssignmentValidateSnap>();
        if (ctx.assignmentByName != null) {
            for (String nameKey : ctx.assignmentByName.keySet()) {
                FEC_Assignment__c asg = ctx.assignmentByName.get(nameKey);
                ImportAssignmentValidateSnap snap = toImportAssignmentValidateSnap(asg);
                if (snap != null) {
                    snap.assignmentLookupName = nameKey;
                    payload.assignmentSnapsByName.add(snap);
                }
            }
        }
        payload.assignmentSnapsByRecordId = new List<ImportAssignmentValidateSnap>();
        if (ctx.assignmentByRecordId != null) {
            for (Id asgId : ctx.assignmentByRecordId.keySet()) {
                FEC_Assignment__c asg = ctx.assignmentByRecordId.get(asgId);
                ImportAssignmentValidateSnap snap = toImportAssignmentValidateSnap(asg);
                if (snap != null) {
                    payload.assignmentSnapsByRecordId.add(snap);
                }
            }
        }
        payload.configuredLabelsByStage = new Map<String, List<String>>();
        if (ctx.configuredLabelsByStage != null) {
            for (Id stageId : ctx.configuredLabelsByStage.keySet()) {
                Set<String> labels = ctx.configuredLabelsByStage.get(stageId);
                payload.configuredLabelsByStage.put(
                    String.valueOf(stageId),
                    labels == null ? new List<String>() : new List<String>(labels)
                );
            }
        }
        payload.currentUserQueueIds = new List<String>();
        if (ctx.currentUserQueueIds != null) {
            for (Id queueId : ctx.currentUserQueueIds) {
                payload.currentUserQueueIds.add(String.valueOf(queueId));
            }
        }
        return JSON.serialize(payload);
    }

    public static ImportValidateChunkContext deserializeImportValidateChunkContext(String jsonPayload) {
        ImportValidateChunkContext ctx = new ImportValidateChunkContext();
        ctx.caseBySearch = new Map<String, Case>();
        ctx.businessProcessCodeByCaseId = new Map<Id, String>();
        ctx.assignmentByName = new Map<String, FEC_Assignment__c>();
        ctx.assignmentByRecordId = new Map<Id, FEC_Assignment__c>();
        ctx.seenCaseSearch = new Set<String>();
        ctx.routingSignatureByCaseSearch = new Map<String, String>();
        ctx.configuredLabelsByStage = new Map<Id, Set<String>>();
        ctx.currentUserQueueIds = new Set<Id>();
        if (String.isBlank(jsonPayload)) {
            return ctx;
        }
        ImportValidateChunkStatePayload payload = (ImportValidateChunkStatePayload) JSON.deserialize(
            jsonPayload,
            ImportValidateChunkStatePayload.class
        );
        if (payload == null || payload.prepared != true) {
            return ctx;
        }
        ctx.cofOrGsr = payload.cofOrGsr == true;
        ctx.currentUserGroup = payload.currentUserGroup;
        ctx.currentUserId = UserInfo.getUserId();
        if (payload.seenCaseSearch != null) {
            ctx.seenCaseSearch.addAll(payload.seenCaseSearch);
        }
        if (payload.routingSignatureByCaseSearch != null) {
            ctx.routingSignatureByCaseSearch.putAll(payload.routingSignatureByCaseSearch);
        }
        if (payload.caseSnaps != null) {
            for (ImportCaseValidateSnap snap : payload.caseSnaps) {
                if (snap == null || String.isBlank(snap.searchKey) || snap.caseId == null) {
                    continue;
                }
                Case matched = new Case(Id = snap.caseId);
                matched.put('IsClosed', snap.isClosed);
                matched.put('OwnerId', snap.ownerId);
                matched.put('FEC_Current_Case_Stage__c', snap.currentStageId);
                matched.put('FEC_Assignment_Count__c', snap.assignmentCount);
                ctx.caseBySearch.put(snap.searchKey, matched);
                if (String.isNotBlank(snap.businessProcessCode)) {
                    ctx.businessProcessCodeByCaseId.put(snap.caseId, snap.businessProcessCode);
                }
            }
        }
        if (payload.assignmentSnapsByName != null) {
            for (ImportAssignmentValidateSnap snap : payload.assignmentSnapsByName) {
                FEC_Assignment__c asg = fromImportAssignmentValidateSnap(snap);
                if (asg != null && String.isNotBlank(snap.assignmentLookupName)) {
                    ctx.assignmentByName.put(snap.assignmentLookupName, asg);
                }
            }
        }
        if (payload.assignmentSnapsByRecordId != null) {
            for (ImportAssignmentValidateSnap snap : payload.assignmentSnapsByRecordId) {
                FEC_Assignment__c asg = fromImportAssignmentValidateSnap(snap);
                if (asg != null && asg.Id != null) {
                    ctx.assignmentByRecordId.put(asg.Id, asg);
                }
            }
        }
        if (payload.configuredLabelsByStage != null) {
            for (String stageIdKey : payload.configuredLabelsByStage.keySet()) {
                try {
                    Id stageId = Id.valueOf(stageIdKey);
                    List<String> labels = payload.configuredLabelsByStage.get(stageIdKey);
                    ctx.configuredLabelsByStage.put(
                        stageId,
                        labels == null ? new Set<String>() : new Set<String>(labels)
                    );
                } catch (Exception ex) {
                }
            }
        }
        if (payload.currentUserQueueIds != null) {
            for (String queueIdKey : payload.currentUserQueueIds) {
                try {
                    ctx.currentUserQueueIds.add(Id.valueOf(queueIdKey));
                } catch (Exception ex) {
                }
            }
        }
        Set<Id> stageIds = new Set<Id>();
        for (Case matched : ctx.caseBySearch.values()) {
            if (matched != null && matched.FEC_Current_Case_Stage__c != null) {
                stageIds.add(matched.FEC_Current_Case_Stage__c);
            }
        }
        FEC_BatchCaseHandlingPicklistResolver.clearCache();
        FEC_BCH_ImportRoutingResolver.clearCache();
        FEC_BCH_ImportRoutingResolver.preloadStageScreens(stageIds, ctx.currentUserGroup);
        ctx.picklistValueByNormByField =
            FEC_BatchCaseHandlingPicklistResolver.buildNormalizedToApiValueByField(
                importPicklistFieldApis()
            );
        return ctx;
    }

    private static ImportAssignmentValidateSnap toImportAssignmentValidateSnap(FEC_Assignment__c asg) {
        if (asg == null || asg.Id == null) {
            return null;
        }
        ImportAssignmentValidateSnap snap = new ImportAssignmentValidateSnap();
        snap.assignmentId = asg.Id;
        snap.caseId = asg.FEC_Case__c;
        snap.assignmentStatus = asg.FEC_Assignment_Status__c;
        return snap;
    }

    private static FEC_Assignment__c fromImportAssignmentValidateSnap(ImportAssignmentValidateSnap snap) {
        if (snap == null || snap.assignmentId == null) {
            return null;
        }
        return new FEC_Assignment__c(
            Id = snap.assignmentId,
            FEC_Case__c = snap.caseId,
            FEC_Assignment_Status__c = snap.assignmentStatus
        );
    }

    private static String resolveImportValidateBusinessProcessCode(
        Case matched,
        ImportValidateChunkContext ctx
    ) {
        if (matched == null || matched.Id == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (ctx != null && ctx.businessProcessCodeByCaseId != null && ctx.businessProcessCodeByCaseId.containsKey(matched.Id)) {
            return ctx.businessProcessCodeByCaseId.get(matched.Id);
        }
        return resolveCaseBusinessProcessCode(matched);
    }

    public static void applyCaseHandlingUpdates(List<FEC_BatchCaseHandlingImportRow> rows, Boolean cofOrGsr) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        batchImportApplyInProgress = true;
        batchHandlingTriggerBypass = true;
        try {
            applyCaseHandlingUpdatesCore(rows, cofOrGsr);
        } finally {
            batchImportApplyInProgress = false;
            batchHandlingTriggerBypass = false;
        }
    }

    private static void applyCaseHandlingUpdatesCore(List<FEC_BatchCaseHandlingImportRow> rows, Boolean cofOrGsr) {
        routeParamsCacheByKey.clear();
        revertActionIdCacheByStage.clear();
        queueIdCacheByToken.clear();
        FEC_BCH_ImportRoutingResolver.clearCache();
        Set<Id> caseIds = new Set<Id>();
        for (FEC_BatchCaseHandlingImportRow rr : rows) {
            if (rr == null || rr.status == System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed || String.isBlank(rr.recordId)) {
                continue;
            }
            try {
                caseIds.add(Id.valueOf(rr.recordId));
            } catch (Exception ex) {
            }
        }
        Map<Id, Case> caseLiteById = caseIds.isEmpty()
            ? new Map<Id, Case>()
            : new Map<Id, Case>([
                SELECT
                    Id,
                    OwnerId,
                    FEC_Current_Case_Stage__c,
                    FEC_Assignment_Count__c,
                    FEC_Assignment_Users__c,
                    FEC_Final_Status__c,
                    FEC_Current_Case_Stage__r.FEC_Code__c,
                    FEC_Business_Process__r.FEC_Code__c,
                    FEC_Current_Case_Stage__r.FEC_Business_Process__r.FEC_Code__c
                FROM Case
                WHERE Id IN :caseIds
            ]);
        // 28/05/2026 11:20 linhdev - preload stage screen sau clearCache để resolve routing không query lặp / Route To
        preloadImportStageScreensForApply(caseLiteById);
        // 25/06/2026 PhongBT: preload login user info cho ownership check COF/GSR (tránh query lặp trong loop)
        Id loginUserId = UserInfo.getUserId();
        Set<Id> loginUserQueueIds = cofOrGsr == true
            ? FEC_AssignmentListHandler.getCurrentUserQueueIds(loginUserId)
            : new Set<Id>();
        Set<String> loginUserQueueNames = cofOrGsr == true
            ? FEC_AssignmentListHandler.getCurrentUserQueues(loginUserId)
            : new Set<String>();
        Map<String, Schema.SObjectField> caseFieldMap = Case.SObjectType.getDescribe().fields.getMap();
        Map<String, Map<String, String>> picklistValueByNormByField =
            FEC_BatchCaseHandlingPicklistResolver.buildNormalizedToApiValueByField(
                importPicklistFieldApis()
            );
        Set<String> assignmentNames = new Set<String>();
        Set<Id> assignmentRecordIds = new Set<Id>();
        if (cofOrGsr == true) {
            for (FEC_BatchCaseHandlingImportRow rr : rows) {
                if (rr == null || String.isBlank(rr.assignmentId)) {
                    continue;
                }
                collectAssignmentLookupKeys(rr.assignmentId, assignmentNames, assignmentRecordIds);
            }
        }
        Map<String, FEC_Assignment__c> assignmentByName = loadAssignmentsByName(assignmentNames);
        Map<Id, FEC_Assignment__c> assignmentByRecordId = loadAssignmentsByRecordId(assignmentRecordIds);
        List<RemarkDraftUpdateItem> remarkDraftItems = new List<RemarkDraftUpdateItem>();
        //PhongBT 28/05/26: Hàng COF/GSR Route To + assignmentId — gom để cập nhật FEC_Assignment__c sau khi route Case.
        List<AssignmentRouteToUpdateItem> assignmentRouteToItems = new List<AssignmentRouteToUpdateItem>();
        List<FEC_BCH_AssignmentUpdateService.ImportUpdateItem> assignmentUpdateItems =
            new List<FEC_BCH_AssignmentUpdateService.ImportUpdateItem>();
        List<FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem> assignmentResolveRejectItems =
            new List<FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem>();
        List<FEC_BCH_AssignmentRevertService.ImportRevertItem> assignmentRevertItems =
            new List<FEC_BCH_AssignmentRevertService.ImportRevertItem>();
        List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem> importHistoryItems =
            new List<FEC_BCH_ImportRoutingHistoryService.ImportHistoryItem>();
        //08/06/2026 dungLTdev: Gom payload Routing Action History cho Case-level Resolve import.
        List<FEC_BCC_ImportResolveHistService.ImportResolveHistoryItem> resolveHistoryItems =
            new List<FEC_BCC_ImportResolveHistService.ImportResolveHistoryItem>();
        //PhongBT 02/06/26: Sửa routing action cho cof/gsr — Route To level Case tạo Assignment mới.
        List<FEC_BCH_CofGsrImportRouteToService.CreateContext> cofGsrRouteToCreateItems =
            new List<FEC_BCH_CofGsrImportRouteToService.CreateContext>();
        Map<Id, Case> pendingCaseFieldUpdatesById = new Map<Id, Case>();
        Map<Id, List<FEC_BatchCaseHandlingImportRow>> rowsByCaseForFieldUpdate = new Map<Id, List<FEC_BatchCaseHandlingImportRow>>();
        for (FEC_BatchCaseHandlingImportRow rr : rows) {
            if (rr == null || rr.status == System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed || String.isBlank(rr.recordId)) {
                continue;
            }
            Id caseId;
            try {
                caseId = Id.valueOf(rr.recordId);
            } catch (Exception e) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(rr.errors, System.Label.FEC_Batch_Case_Handling_Import_Err_Record_Id_Invalid);
                continue;
            }
            if (cofOrGsr == true && String.isNotBlank(rr.routingAction)) {
                Case caseForRoutingRule = caseLiteById.get(caseId);
                // 25/06/2026 PhongBT: Check ownership cho COF/GSR trước khi xử lý
                String ownershipError = validateCofGsrImportRowOwnership(caseForRoutingRule, loginUserQueueIds, loginUserId, loginUserQueueNames);
                if (String.isNotBlank(ownershipError)) {
                    rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                    rr.errors = appendError(rr.errors, ownershipError);
                    continue;
                }
                String routingBlockedByAssignment = validateCaseRoutingActionBlockedByAssignmentCount(
                    rr,
                    caseForRoutingRule
                );
                if (String.isNotBlank(routingBlockedByAssignment)) {
                    rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                    rr.errors = appendError(rr.errors, routingBlockedByAssignment);
                    continue;
                }
            }
            String actionLabel = rr.routingAction;
            if (cofOrGsr && String.isBlank(actionLabel)) {
                actionLabel = rr.assignmentRoutingAction;
            }
            Boolean assignmentOnly = isAssignmentRoutingOnly(rr, cofOrGsr);
            Id stageIdForRow = caseLiteById.get(caseId) == null
                ? null
                : caseLiteById.get(caseId).FEC_Current_Case_Stage__c;
            FEC_BCH_ImportRoutingResolver.ResolvedRouting resolvedRouting =
                FEC_BCH_ImportRoutingResolver.resolve(stageIdForRow, actionLabel, assignmentOnly == true);
            if (resolvedRouting != null && String.isBlank(rr.actionButtonId) && resolvedRouting.actionButtonId != null) {
                applyResolvedRoutingToRow(rr, resolvedRouting);
            }
            RoutingParseResult routingParsed = parseRoutingPattern(actionLabel);
            String methodKey = resolvedRouting != null && String.isNotBlank(resolvedRouting.methodKey)
                ? resolvedRouting.methodKey
                : (routingParsed == null ? null : routingParsed.methodKey);
            if (routingParsed != null && resolvedRouting != null) {
                if (String.isBlank(routingParsed.decision) && String.isNotBlank(resolvedRouting.decision)) {
                    routingParsed.decision = resolvedRouting.decision;
                }
                if (String.isBlank(routingParsed.routeTeamHint) && String.isNotBlank(resolvedRouting.routeTeamHint)) {
                    routingParsed.routeTeamHint = resolvedRouting.routeTeamHint;
                }
                if (String.isBlank(routingParsed.routeQueueHint) && String.isNotBlank(resolvedRouting.routeQueueHint)) {
                    routingParsed.routeQueueHint = resolvedRouting.routeQueueHint;
                }
            }
            if (String.isBlank(methodKey)) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(
                    rr.errors,
                    cofOrGsr
                        ? System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Invalid
                        : System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid
                );
                continue;
            }
            //PhongBT 02/06/26: Sửa routing action cho cof/gsr — không trả lỗi Requires_Params.
            if (cofOrGsr != true &&
                assignmentOnly != true &&
                routingParsed != null &&
                routingActionRequiresExtraParams(methodKey, routingParsed.decision)) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(
                    rr.errors,
                    System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Requires_Params
                );
                continue;
            }
            try {
                //PhongBT 02/06/26: Sửa routing action cho cof/gsr
                Boolean cofGsrCaseRouteToCreate = cofOrGsr == true &&
                    assignmentOnly != true &&
                    String.isNotBlank(rr.routingAction) &&
                    FEC_BCH_CofGsrImportRouteToService.isCofGsrRouteToImportLabel(rr.routingAction);
                Map<String, String> runParams = new Map<String, String>{ 'caseId' => String.valueOf(caseId) };
                if (routingParsed != null && methodKey == FEC_CaseBusinessService.UPDATEACTION && String.isNotBlank(routingParsed.decision)) {
                    runParams.put('decision', routingParsed.decision);
                }
                if (cofOrGsr == true && String.isNotBlank(rr.assignmentId)) {
                    Id assignmentRecordIdForUpdate = parseAssignmentId(
                        rr.assignmentId,
                        assignmentByName,
                        assignmentByRecordId,
                        caseId
                    );
                    FEC_BCH_AssignmentUpdateService.collectFromImportRow(
                        rr,
                        cofOrGsr,
                        caseId,
                        stageIdForRow,
                        assignmentRecordIdForUpdate,
                        assignmentUpdateItems
                    );
                    if (assignmentOnly == true &&
                        methodKey == FEC_CaseBusinessService.UPDATEACTION &&
                        assignmentRecordIdForUpdate != null &&
                        isCofGsrImportUpdateAction(true, rr.assignmentRoutingAction)) {
                        Case caseLiteForHistory = caseLiteById.get(caseId);
                        FEC_BCH_ImportRoutingHistoryService.collectItem(
                            importHistoryItems,
                            rr,
                            caseId,
                            assignmentRecordIdForUpdate,
                            methodKey,
                            routingParsed == null ? null : routingParsed.decision,
                            stageIdForRow,
                            caseLiteForHistory == null ? null : caseLiteForHistory.FEC_Current_Case_Stage__r?.FEC_Code__c,
                            caseLiteForHistory == null ? null : caseLiteForHistory.FEC_Final_Status__c,
                            routingParsed == null ? null : routingParsed.routeTeamHint,
                            routingParsed == null ? null : routingParsed.routeQueueHint,
                            null,
                            rr.routeViaRevertButton == true
                        );
                    }
                    FEC_BCH_AssignmentResolveRejectService.collectFromImportRow(
                        rr,
                        cofOrGsr,
                        assignmentOnly,
                        caseId,
                        assignmentRecordIdForUpdate,
                        methodKey,
                        assignmentResolveRejectItems
                    );
                    if (assignmentOnly == true &&
                        assignmentRecordIdForUpdate != null &&
                        FEC_BCH_AssignmentResolveRejectService.isResolveOrRejectMethodKey(methodKey)) {
                        Case caseLiteForHistory = caseLiteById.get(caseId);
                        FEC_BCH_ImportRoutingHistoryService.collectItem(
                            importHistoryItems,
                            rr,
                            caseId,
                            assignmentRecordIdForUpdate,
                            methodKey,
                            null,
                            stageIdForRow,
                            caseLiteForHistory == null ? null : caseLiteForHistory.FEC_Current_Case_Stage__r?.FEC_Code__c,
                            caseLiteForHistory == null ? null : caseLiteForHistory.FEC_Final_Status__c,
                            null,
                            null,
                            null,
                            rr.routeViaRevertButton == true
                        );
                    }
                    FEC_BCH_AssignmentRevertService.collectFromImportRow(
                        rr,
                        cofOrGsr,
                        assignmentOnly,
                        caseId,
                        assignmentRecordIdForUpdate,
                        methodKey,
                        assignmentRevertItems
                    );
                }
                if (routingParsed != null && methodKey == FEC_CaseBusinessService.ROUTE_TO) {
                    Case caseLite = caseLiteById.get(caseId);
                    Map<String, String> routeParams = caseLite == null
                        ? null
                        : resolveRouteToParams(
                            caseLite.FEC_Current_Case_Stage__c,
                            routingParsed,
                            rr.actionButtonId,
                            rr.routeViaRevertButton == true
                        );
                    Boolean routeParamsValid = routeParams != null &&
                        String.isNotBlank(routeParams.get('actionId')) &&
                        String.isNotBlank(routeParams.get('queueId'));
                    if (cofGsrCaseRouteToCreate == true) {
                        FEC_BCH_CofGsrImportRouteToService.collectCreateContext(
                            rr,
                            caseId,
                            rr.routingAction,
                            cofGsrRouteToCreateItems
                        );
                    }
                    //PhongBT 02/06/26: Sửa routing action cho cof/gsr — không trả lỗi Requires_Params.
                    if (cofOrGsr != true && assignmentOnly != true && !routeParamsValid) {
                        rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                        rr.errors = appendError(
                            rr.errors,
                            System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Requires_Params
                        );
                        continue;
                    }
                    if (routeParamsValid) {
                        runParams.put('actionId', routeParams.get('actionId'));
                        runParams.put('queueId', routeParams.get('queueId'));
                    }
                    //PhongBT 28/05/26: COF/GSR có assignmentId — queue team/queue từ Stage Change hoặc hint Excel.
                    //PhongBT 02/06/26: Sửa routing action cho cof/gsr — Route To Case tạo Assignment mới, không update Assignment ID.
                    if (cofOrGsr == true && String.isNotBlank(rr.assignmentId) && cofGsrCaseRouteToCreate != true) {
                        Id assignmentRecordId = parseAssignmentId(
                            rr.assignmentId,
                            assignmentByName,
                            assignmentByRecordId,
                            caseId
                        );
                        if (assignmentRecordId != null) {
                            AssignmentRouteToUpdateItem routeToItem = new AssignmentRouteToUpdateItem();
                            routeToItem.row = rr;
                            routeToItem.assignmentId = assignmentRecordId;
                            routeToItem.queueToken = routeParamsValid ? routeParams.get('queueToken') : null;
                            routeToItem.routeTeamHint = routingParsed == null ? null : routingParsed.routeTeamHint;
                            routeToItem.routeQueueHint = routingParsed == null ? null : routingParsed.routeQueueHint;
                            routeToItem.submittedOn = System.now();
                            assignmentRouteToItems.add(routeToItem);
                            if (assignmentOnly == true) {
                                Case caseLiteForHistory = caseLiteById.get(caseId);
                                FEC_BCH_ImportRoutingHistoryService.collectItem(
                                    importHistoryItems,
                                    rr,
                                    caseId,
                                    assignmentRecordId,
                                    methodKey,
                                    null,
                                    stageIdForRow,
                                    caseLiteForHistory == null ? null : caseLiteForHistory.FEC_Current_Case_Stage__r?.FEC_Code__c,
                                    caseLiteForHistory == null ? null : caseLiteForHistory.FEC_Final_Status__c,
                                    routingParsed == null ? null : routingParsed.routeTeamHint,
                                    routingParsed == null ? null : routingParsed.routeQueueHint,
                                    routeParamsValid ? routeParams.get('queueToken') : null,
                                    rr.routeViaRevertButton == true
                                );
                            }
                        }
                    }
                }
                if (methodKey == FEC_CaseBusinessService.REVERT) {
                    Case caseLite = caseLiteById.get(caseId);
                    String revertActionId = caseLite == null
                        ? null
                        : resolveRevertActionId(
                            caseLite.FEC_Current_Case_Stage__c,
                            rr.actionButtonId,
                            rr.revertPreferRevertedChange == true
                        );
                    //PhongBT 02/06/26: Sửa routing action cho cof/gsr — không trả lỗi Requires_Params.
                    if (cofOrGsr != true && assignmentOnly != true && String.isBlank(revertActionId)) {
                        rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                        rr.errors = appendError(
                            rr.errors,
                            System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Requires_Params
                        );
                        continue;
                    }
                    if (String.isNotBlank(revertActionId)) {
                        runParams.put('actionId', revertActionId);
                    }
                }
                if (methodKey == FEC_CaseBusinessService.REVERT && String.isNotBlank(rr.routingActionValue)) {
                    runParams.put('routingActionValue', rr.routingActionValue);
                }
                // 04/06/2026 16:45 linhdev - bulk Revert: truyền cờ FEC_IsReverted__c khớp resolver (tránh query Stage Change sai nhánh)
                if (methodKey == FEC_CaseBusinessService.REVERT) {
                    runParams.put(
                        'revertPreferRevertedChange',
                        rr.revertPreferRevertedChange == true ? 'true' : 'false'
                    );
                }
                Boolean skipCaseRun = false;
                //PhongBT 02/06/26: Sửa routing action cho cof/gsr — Route To Case đã xử lý tạo Assignment.
                if (cofGsrCaseRouteToCreate == true) {
                    skipCaseRun = true;
                }
                if (assignmentOnly == true) {
                    if (methodKey == FEC_CaseBusinessService.ROUTE_TO && !runParams.containsKey('queueId')) {
                        skipCaseRun = true;
                    } else if (methodKey == FEC_CaseBusinessService.REVERT &&
                        FEC_BCH_AssignmentRevertService.resolveRevertDecisionFromLabel(rr.assignmentRoutingAction) != null) {
                        skipCaseRun = true;
                    } else if (methodKey == FEC_CaseBusinessService.REVERT && !runParams.containsKey('actionId')) {
                        skipCaseRun = true;
                    } else if (methodKey == FEC_CaseBusinessService.UPDATEACTION) {
                        skipCaseRun = true;
                    } else if (FEC_BCH_AssignmentResolveRejectService.isResolveOrRejectMethodKey(methodKey)) {
                        skipCaseRun = true;
                    }
                }
                // 28/05/2026 11:20 linhdev - sync multi-chunk: defer row khi gần 101 SOQL (chunk sau xử lý tiếp)
                // 25/06/2026 linhdev - queueable 1 row/hop: không đánh Failed ảo; vẫn runInternal (tránh chỉ 1 dòng Success)
                if (shouldYieldImportGovernorLimits() && !System.isQueueable()) {
                    if (System.isBatch()) {
                        rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                        rr.errors = appendError(
                            rr.errors,
                            resolveImportQueueLimitExceededReason()
                        );
                    }
                    continue;
                }
                if (!skipCaseRun) {
                    // 05/06/2026 14:00 linhdev - quy trình không GSR/COF: Resolve/Reject/Update + owner Queue → gán Login User
                    transferQueueOwnedCaseToLoginUserForNonCofGsrProcess(
                        caseId,
                        methodKey,
                        caseLiteById
                    );
                    // 09/06/2026 18:00 linhdev - import Escalate: Owner = ManagerId của user đang import (không dùng Owner.ManagerId)
                    if (methodKey == FEC_CaseBusinessService.ESCALATE) {
                        runParams.put(
                            FEC_CaseBusinessService.PARAM_ESCALATE_TO_ACTING_USER_MANAGER,
                            'true'
                        );
                    }
                    // 04/06/2026 16:45 linhdev - queueable gọi runInternal; tránh AuraHandledException crash import Processing
                    FEC_CaseBusinessService.runInternal(methodKey, runParams);
                    // 24/06/2026 phong - xác nhận apply thành công; tránh nhầm với status=null (chưa xử lý) khi export Result
                    rr.status = System.Label.FEC_Batch_Case_Handling_Success;
                    //08/06/2026 dungLTdev: Excel Routing Action = Resolve — tạo FEC_Routing_Action_History__c sau run thành công.
                    if (assignmentOnly != true &&
                        methodKey == FEC_CaseBusinessService.RESOLVE) {
                        Case caseLiteForResolve = caseLiteById.get(caseId);
                        FEC_BCC_ImportResolveHistService.collectItem(
                            resolveHistoryItems,
                            rr,
                            caseId,
                            stageIdForRow,
                            caseLiteForResolve == null ? null : caseLiteForResolve.FEC_Current_Case_Stage__r?.FEC_Code__c,
                            caseLiteForResolve == null ? null : caseLiteForResolve.FEC_Final_Status__c
                        );
                    }
                }
            } catch (Exception ex) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(rr.errors, ex.getMessage());
                continue;
            }
            // 24/06/2026 phong - skipCaseRun path (COF/GSR assignment-only) không đi qua runInternal
            // nên cần set Success ở đây; !skipCaseRun path đã set ngay sau runInternal thành công
            if (String.isBlank(rr.status)) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Success;
            }
            Case d2cUpdate = buildD2CCaseUpdate(caseId, rr, caseFieldMap, picklistValueByNormByField);
            if (d2cUpdate != null) {
                pendingCaseFieldUpdatesById.put(caseId, d2cUpdate);
                if (!rowsByCaseForFieldUpdate.containsKey(caseId)) {
                    rowsByCaseForFieldUpdate.put(caseId, new List<FEC_BatchCaseHandlingImportRow>());
                }
                rowsByCaseForFieldUpdate.get(caseId).add(rr);
            }
            if (String.isNotBlank(rr.inputtedRemarks)) {
                RemarkDraftUpdateItem item = new RemarkDraftUpdateItem();
                item.row = rr;
                item.caseId = caseId;
                item.inputtedRemarks = rr.inputtedRemarks;
                item.assignmentId = parseAssignmentId(
                    rr.assignmentId,
                    assignmentByName,
                    assignmentByRecordId,
                    caseId
                );
                remarkDraftItems.add(item);
            }
        }
        applyD2CFieldUpdatesBulk(pendingCaseFieldUpdatesById, rowsByCaseForFieldUpdate);
        List<RemarkDraftUpdateItem> validRemarkItems = new List<RemarkDraftUpdateItem>();
        for (RemarkDraftUpdateItem item : remarkDraftItems) {
            if (item != null &&
                item.row != null &&
                item.row.status != System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed) {
                validRemarkItems.add(item);
            }
        }
        //PhongBT 28/05/26: Chỉ apply update Assignment cho dòng import chưa fail (sau FEC_CaseBusinessService.run Route To).
        List<AssignmentRouteToUpdateItem> validAssignmentRouteToItems = new List<AssignmentRouteToUpdateItem>();
        for (AssignmentRouteToUpdateItem item : assignmentRouteToItems) {
            if (item != null &&
                item.row != null &&
                item.row.status != System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed) {
                validAssignmentRouteToItems.add(item);
            }
        }
        applyAssignmentRouteToBulk(validAssignmentRouteToItems);
        //PhongBT 02/06/26: Sửa routing action cho cof/gsr — bulk tạo Assignment Route To level Case.
        FEC_BCH_CofGsrImportRouteToService.applyCreateRoutingAssignmentsBulk(
            cofGsrRouteToCreateItems,
            caseLiteById
        );
        List<FEC_BCH_AssignmentUpdateService.ImportUpdateItem> validAssignmentUpdateItems =
            new List<FEC_BCH_AssignmentUpdateService.ImportUpdateItem>();
        for (FEC_BCH_AssignmentUpdateService.ImportUpdateItem item : assignmentUpdateItems) {
            if (item != null &&
                item.row != null &&
                item.row.status != System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed) {
                validAssignmentUpdateItems.add(item);
            }
        }
        FEC_BCH_AssignmentUpdateService.applyImportBulk(validAssignmentUpdateItems);
        List<FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem> validAssignmentResolveRejectItems =
            new List<FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem>();
        for (FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem item : assignmentResolveRejectItems) {
            if (item != null &&
                item.row != null &&
                item.row.status != System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed) {
                validAssignmentResolveRejectItems.add(item);
            }
        }
        FEC_BCH_AssignmentResolveRejectService.applyImportBulk(validAssignmentResolveRejectItems);
        List<FEC_BCH_AssignmentRevertService.ImportRevertItem> validAssignmentRevertItems =
            new List<FEC_BCH_AssignmentRevertService.ImportRevertItem>();
        for (FEC_BCH_AssignmentRevertService.ImportRevertItem item : assignmentRevertItems) {
            if (item != null &&
                item.row != null &&
                item.row.status != System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed) {
                validAssignmentRevertItems.add(item);
            }
        }
        FEC_BCH_AssignmentRevertService.applyImportBulk(validAssignmentRevertItems);
        FEC_BCH_ImportRoutingHistoryService.applyAfterAssignmentBulk(importHistoryItems);
        //08/06/2026 dungLTdev: Insert Routing Action History cho các dòng Excel Routing Action = Resolve.
        FEC_BCC_ImportResolveHistService.applyAfterCaseRunBulk(resolveHistoryItems);
        applyDraftRemarksBulk(validRemarkItems, cofOrGsr);
    }

    private static void preloadImportStageScreensForApply(Map<Id, Case> caseLiteById) {
        if (caseLiteById == null || caseLiteById.isEmpty()) {
            return;
        }
        Set<Id> stageIds = new Set<Id>();
        for (Case caseLite : caseLiteById.values()) {
            if (caseLite != null && caseLite.FEC_Current_Case_Stage__c != null) {
                stageIds.add(caseLite.FEC_Current_Case_Stage__c);
            }
        }
        if (stageIds.isEmpty()) {
            return;
        }
        FEC_BCH_ImportRoutingResolver.preloadStageScreens(stageIds, resolveImportUserGroup());
    }

    private static String resolveImportUserGroup() {
        List<User> importUsers = [
            SELECT FEC_User_Group__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (importUsers.isEmpty() || String.isBlank(importUsers[0].FEC_User_Group__c)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return importUsers[0].FEC_User_Group__c;
    }

    private static void collectAssignmentLookupKeys(
        String assignmentIdRaw,
        Set<String> assignmentNames,
        Set<Id> assignmentRecordIds
    ) {
        if (String.isBlank(assignmentIdRaw)) {
            return;
        }
        for (String token : extractAssignmentLookupTokens(assignmentIdRaw)) {
            Id recordId = tryParseAssignmentRecordId(token);
            if (recordId != null) {
                assignmentRecordIds.add(recordId);
            } else if (assignmentNames != null) {
                assignmentNames.add(token);
            }
        }
    }

    // 05/06/2026 - parse Assignment ID từ export remark (#1: A-000329) hoặc nhiều dòng trong một ô
    @TestVisible
    private static List<String> extractAssignmentLookupTokens(String assignmentIdRaw) {
        List<String> tokens = new List<String>();
        if (String.isBlank(assignmentIdRaw)) {
            return tokens;
        }
        Set<String> seen = new Set<String>();
        String normalized = assignmentIdRaw.replace('\r\n', '\n').replace('\r', '\n');
        if (normalized.contains('\n')) {
            for (String line : normalized.split('\n')) {
                addAssignmentLookupToken(tokens, seen, stripAssignmentExportLinePrefix(line));
            }
        } else {
            addAssignmentLookupToken(tokens, seen, stripAssignmentExportLinePrefix(normalized));
            addAssignmentLookupToken(tokens, seen, normalized.trim());
        }
        return tokens;
    }

    @TestVisible
    private static String stripAssignmentExportLinePrefix(String line) {
        if (String.isBlank(line)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String trimmed = line.trim();
        if (!trimmed.startsWith('#')) {
            return trimmed;
        }
        Integer colonPos = trimmed.indexOf(':');
        if (colonPos < 0) {
            return trimmed;
        }
        return trimmed.substring(colonPos + 1).trim();
    }

    private static void addAssignmentLookupToken(
        List<String> tokens,
        Set<String> seen,
        String candidate
    ) {
        if (String.isBlank(candidate)) {
            return;
        }
        String trimmed = candidate.trim();
        if (String.isBlank(trimmed) || seen.contains(trimmed)) {
            return;
        }
        seen.add(trimmed);
        tokens.add(trimmed);
    }

    private static Id tryParseAssignmentRecordId(String trimmed) {
        if (String.isBlank(trimmed)) {
            return null;
        }
        try {
            Id recordId = Id.valueOf(trimmed);
            if (recordId.getSobjectType() != FEC_Assignment__c.SObjectType) {
                return null;
            }
            return recordId;
        } catch (Exception ex) {
            return null;
        }
    }

    private static Map<String, FEC_Assignment__c> loadAssignmentsByName(Set<String> assignmentNames) {
        Map<String, FEC_Assignment__c> out = new Map<String, FEC_Assignment__c>();
        if (assignmentNames == null || assignmentNames.isEmpty()) {
            return out;
        }
        for (FEC_Assignment__c asg : [
            SELECT Id, Name, FEC_Case__c, FEC_Assignment_Status__c
            FROM FEC_Assignment__c
            WHERE Name IN :assignmentNames
        ]) {
            if (String.isNotBlank(asg.Name)) {
                out.put(asg.Name, asg);
            }
        }
        return out;
    }

    private static Map<Id, FEC_Assignment__c> loadAssignmentsByRecordId(Set<Id> assignmentRecordIds) {
        Map<Id, FEC_Assignment__c> out = new Map<Id, FEC_Assignment__c>();
        if (assignmentRecordIds == null || assignmentRecordIds.isEmpty()) {
            return out;
        }
        return new Map<Id, FEC_Assignment__c>([
            SELECT Id, Name, FEC_Case__c, FEC_Assignment_Status__c
            FROM FEC_Assignment__c
            WHERE Id IN :assignmentRecordIds
        ]);
    }

    private static FEC_Assignment__c resolveAssignmentForImport(
        String assignmentIdRaw,
        Map<String, FEC_Assignment__c> assignmentByName,
        Map<Id, FEC_Assignment__c> assignmentByRecordId
    ) {
        return resolveAssignmentForImport(
            assignmentIdRaw,
            assignmentByName,
            assignmentByRecordId,
            null
        );
    }

    private static FEC_Assignment__c resolveAssignmentForImport(
        String assignmentIdRaw,
        Map<String, FEC_Assignment__c> assignmentByName,
        Map<Id, FEC_Assignment__c> assignmentByRecordId,
        Id caseId
    ) {
        List<String> tokens = extractAssignmentLookupTokens(assignmentIdRaw);
        if (tokens.isEmpty()) {
            return null;
        }
        FEC_Assignment__c caseMatch = null;
        FEC_Assignment__c lastResolved = null;
        for (String token : tokens) {
            FEC_Assignment__c asg = resolveAssignmentLookupToken(
                token,
                assignmentByName,
                assignmentByRecordId
            );
            if (asg == null) {
                continue;
            }
            lastResolved = asg;
            if (caseId != null && asg.FEC_Case__c == caseId) {
                caseMatch = asg;
            }
        }
        if (caseId != null) {
            return caseMatch;
        }
        return lastResolved;
    }

    private static FEC_Assignment__c resolveAssignmentLookupToken(
        String token,
        Map<String, FEC_Assignment__c> assignmentByName,
        Map<Id, FEC_Assignment__c> assignmentByRecordId
    ) {
        if (String.isBlank(token)) {
            return null;
        }
        String trimmed = token.trim();
        if (assignmentByName != null && assignmentByName.containsKey(trimmed)) {
            return assignmentByName.get(trimmed);
        }
        Id recordId = tryParseAssignmentRecordId(trimmed);
        if (recordId != null && assignmentByRecordId != null) {
            return assignmentByRecordId.get(recordId);
        }
        return null;
    }

    private static Id parseAssignmentId(
        String assignmentIdRaw,
        Map<String, FEC_Assignment__c> assignmentByName,
        Map<Id, FEC_Assignment__c> assignmentByRecordId
    ) {
        return parseAssignmentId(assignmentIdRaw, assignmentByName, assignmentByRecordId, null);
    }

    private static Id parseAssignmentId(
        String assignmentIdRaw,
        Map<String, FEC_Assignment__c> assignmentByName,
        Map<Id, FEC_Assignment__c> assignmentByRecordId,
        Id caseId
    ) {
        FEC_Assignment__c asg = resolveAssignmentForImport(
            assignmentIdRaw,
            assignmentByName,
            assignmentByRecordId,
            caseId
        );
        return asg == null ? null : asg.Id;
    }

    private static void applyDraftRemarksBulk(List<RemarkDraftUpdateItem> remarkDraftItems, Boolean cofOrGsr) {
        if (remarkDraftItems == null || remarkDraftItems.isEmpty()) {
            return;
        }
        try {
            List<User> userlst = [
                SELECT Id, Email, UserRole.Name
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            if (userlst.isEmpty()) {
                return;
            }
            String emailId = String.isNotBlank(userlst[0].Email) ? userlst[0].Email.substringBefore('@') : null;
            String roleName = userlst[0].UserRole?.Name;

            Set<Id> caseIds = new Set<Id>();
            for (RemarkDraftUpdateItem item : remarkDraftItems) {
                if (item != null && item.caseId != null) {
                    caseIds.add(item.caseId);
                }
            }
            if (caseIds.isEmpty()) {
                return;
            }

            Map<Id, Case> caseById = new Map<Id, Case>([
                SELECT Id, FEC_Stage_Name__c, FEC_Draft_Remarks__c
                FROM Case
                WHERE Id IN :caseIds
            ]);

            Map<Id, List<FEC_BatchCaseHandlingImportRow>> rowsByCaseId = new Map<Id, List<FEC_BatchCaseHandlingImportRow>>();
            Map<Id, List<FEC_Case_Remarks__c>> remarksByCaseId = new Map<Id, List<FEC_Case_Remarks__c>>();
            List<Case> caseRowsToUpdate = new List<Case>();
            List<FEC_Case_Remarks__c> caseRemarksToInsert = new List<FEC_Case_Remarks__c>();
            List<FEC_BatchCaseHandlingImportRow> caseRemarkRows = new List<FEC_BatchCaseHandlingImportRow>();

            for (RemarkDraftUpdateItem item : remarkDraftItems) {
                if (item == null || item.caseId == null || item.row == null || String.isBlank(item.inputtedRemarks)) {
                    continue;
                }
                Case c = caseById.get(item.caseId);
                if (c == null) {
                    continue;
                }
                if (!rowsByCaseId.containsKey(item.caseId)) {
                    rowsByCaseId.put(item.caseId, new List<FEC_BatchCaseHandlingImportRow>());
                }
                rowsByCaseId.get(item.caseId).add(item.row);

                List<FEC_Case_Remarks__c> existingRemarks = remarksByCaseId.get(item.caseId);
                if (existingRemarks == null) {
                    existingRemarks = jsonToCaseRemarks(c.FEC_Draft_Remarks__c);
                    remarksByCaseId.put(item.caseId, existingRemarks);
                    caseRowsToUpdate.add(c);
                }

                FEC_Case_Remarks__c caseRemark = new FEC_Case_Remarks__c();
                caseRemark.FEC_Case_Remarks__c = item.inputtedRemarks;
                caseRemark.FEC_User__c = emailId;
                caseRemark.FEC_User_Role__c = roleName;
                caseRemark.FEC_Stage_Name__c = c.FEC_Stage_Name__c;
                caseRemark.FEC_Case__c = item.caseId;
                existingRemarks.add(caseRemark);
                // 27/05/2026 10:00 linhdev - Import Input Remark: tạo Case Remarks History record khi import
                caseRemarksToInsert.add(new FEC_Case_Remarks__c(
                    FEC_Case_Remarks__c = item.inputtedRemarks,
                    FEC_User__c = emailId,
                    FEC_User_Role__c = roleName,
                    FEC_Stage_Name__c = c.FEC_Stage_Name__c,
                    FEC_Case__c = item.caseId
                ));
                caseRemarkRows.add(item.row);
            }

            if (!caseRemarksToInsert.isEmpty()) {
                Database.SaveResult[] caseRemarkResults = Database.insert(caseRemarksToInsert, false);
                for (Integer i = 0; i < caseRemarkResults.size(); i++) {
                    if (caseRemarkResults[i].isSuccess()) {
                        continue;
                    }
                    String message = caseRemarkResults[i].getErrors().isEmpty() ? null : caseRemarkResults[i].getErrors()[0].getMessage();
                    FEC_BatchCaseHandlingImportRow rr = i < caseRemarkRows.size() ? caseRemarkRows[i] : null;
                    if (rr != null) {
                        rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                        rr.errors = appendError(rr.errors, message);
                    }
                }
            }

            //PhongBT 01/06/26: Không update draft remark trên case do import không dùng đến
            /*
            for (Case c : caseRowsToUpdate) {
                c.FEC_Draft_Remarks__c = remarksToJson(remarksByCaseId.get(c.Id));
            }
            if (caseRowsToUpdate.isEmpty()) {
                return;
            }

            Database.SaveResult[] saveResults = Database.update(caseRowsToUpdate, false);
            for (Integer i = 0; i < saveResults.size(); i++) {
                if (saveResults[i].isSuccess()) {
                    continue;
                }
                Id caseId = caseRowsToUpdate[i].Id;
                String message = saveResults[i].getErrors().isEmpty() ? null : saveResults[i].getErrors()[0].getMessage();
                if (rowsByCaseId.containsKey(caseId)) {
                    for (FEC_BatchCaseHandlingImportRow rr : rowsByCaseId.get(caseId)) {
                    rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                        rr.errors = appendError(rr.errors, message);
                    }
                }
            }
            */
            if (cofOrGsr == true) {
                applyAssignmentRemarksBulk(remarkDraftItems);
            }
        } catch (Exception ex) {
            for (RemarkDraftUpdateItem item : remarkDraftItems) {
                if (item == null || item.row == null) {
                    continue;
                }
                item.row.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                item.row.errors = appendError(item.row.errors, ex.getMessage());
            }
        }
    }

    public static Boolean isCofOrGsrTemplate(String templateName) {
        if (String.isBlank(templateName)) {
            return false;
        }
        String t = templateName.toLowerCase();
        return t.contains('cof') || t.contains('gsr');
    }

    private static String resolveRoutingMethodKey(String raw) {
        if (String.isBlank(raw) || FEC_CaseBusinessService.METHOD_MAP == null) {
            return null;
        }
        String trimmed = raw.trim();
        if (FEC_CaseBusinessService.METHOD_MAP.containsKey(trimmed)) {
            return trimmed;
        }
        for (String k : FEC_CaseBusinessService.METHOD_MAP.keySet()) {
            if (k != null && k.equalsIgnoreCase(trimmed)) {
                return k;
            }
        }
        return null;
    }

    private static RoutingParseResult parseRoutingPattern(String raw) {
        RoutingParseResult out = new RoutingParseResult();
        out.methodKey = resolveRoutingMethodKey(raw);
        out.decision = null;
        out.routeTeamHint = null;
        out.routeQueueHint = null;
        if (out.methodKey != null || String.isBlank(raw)) {
            return out;
        }
        String normalized = raw.trim().toLowerCase();
        if (normalized.startsWith('resolve')) {
            out.methodKey = FEC_CaseBusinessService.RESOLVE;
            return out;
        }
        if (normalized.startsWith('reject')) {
            out.methodKey = FEC_CaseBusinessService.REJECT;
            return out;
        }
        if (normalized.startsWith('cancel')) {
            out.methodKey = FEC_CaseBusinessService.CANCEL;
            return out;
        }
        if (normalized.startsWith('reopen')) {
            out.methodKey = FEC_CaseBusinessService.REOPEN;
            return out;
        }
        if (normalized.startsWith('recall')) {
            out.methodKey = FEC_CaseBusinessService.RECALL;
            return out;
        }
        if (normalized.startsWith('escalate')) {
            out.methodKey = FEC_CaseBusinessService.ESCALATE;
            return out;
        }
        if (normalized.startsWith('transfer')) {
            out.methodKey = FEC_CaseBusinessService.TRANSFER;
            return out;
        }
        if (normalized.startsWith('revert')) {
            out.methodKey = FEC_CaseBusinessService.REVERT;
            return out;
        }
        if (normalized.startsWith('update')) {
            out.methodKey = FEC_CaseBusinessService.UPDATEACTION;
            Integer pos = normalized.indexOf('to ');
            if (pos >= 0 && pos + 3 < raw.length()) {
                out.decision = raw.substring(pos + 3).trim();
            }
            return out;
        }
        if (normalized.startsWith('route to')) {
            out.methodKey = FEC_CaseBusinessService.ROUTE_TO;
            String tail = raw.substring(Math.min(raw.length(), 'Route to'.length())).trim();
            Integer dashPos = tail.indexOf('-');
            if (dashPos > -1) {
                String team = tail.substring(0, dashPos).trim();
                String queue = tail.substring(dashPos + 1).trim();
                out.routeTeamHint = String.isBlank(team) ? null : team;
                out.routeQueueHint = String.isBlank(queue) ? null : queue;
            } else if (String.isNotBlank(tail)) {
                out.routeQueueHint = tail;
            }
            return out;
        }
        return out;
    }

    private static Boolean routingActionRequiresExtraParams(String methodKey, String decision) {
        if (String.isBlank(methodKey)) {
            return true;
        }
        if (methodKey == FEC_CaseBusinessService.UPDATEACTION) {
            return String.isBlank(decision);
        }
        return false;
    }

    private static void applyAssignmentRemarksBulk(List<RemarkDraftUpdateItem> remarkDraftItems) {
        if (remarkDraftItems == null || remarkDraftItems.isEmpty()) {
            return;
        }
        Map<Id, FEC_Assignment__c> assignmentUpdatesById = new Map<Id, FEC_Assignment__c>();
        Map<Id, List<FEC_BatchCaseHandlingImportRow>> rowsByAssignmentId = new Map<Id, List<FEC_BatchCaseHandlingImportRow>>();
        for (RemarkDraftUpdateItem item : remarkDraftItems) {
            if (item == null || item.assignmentId == null || item.row == null || String.isBlank(item.inputtedRemarks)) {
                continue;
            }
            if (!assignmentUpdatesById.containsKey(item.assignmentId)) {
                assignmentUpdatesById.put(
                    item.assignmentId,
                    new FEC_Assignment__c(
                        Id = item.assignmentId,
                        FEC_Assignment_Remark__c = item.inputtedRemarks
                    )
                );
                rowsByAssignmentId.put(item.assignmentId, new List<FEC_BatchCaseHandlingImportRow>());
            }
            rowsByAssignmentId.get(item.assignmentId).add(item.row);
        }
        if (assignmentUpdatesById.isEmpty()) {
            return;
        }
        Database.SaveResult[] saveResults = Database.update(assignmentUpdatesById.values(), false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            if (saveResults[i].isSuccess()) {
                continue;
            }
            Id failedAssignmentId = assignmentUpdatesById.values()[i].Id;
            String message = saveResults[i].getErrors().isEmpty() ? null : saveResults[i].getErrors()[0].getMessage();
            if (rowsByAssignmentId.containsKey(failedAssignmentId)) {
                for (FEC_BatchCaseHandlingImportRow rr : rowsByAssignmentId.get(failedAssignmentId)) {
                    rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                    rr.errors = appendError(rr.errors, message);
                }
            }
        }
    }

    private static Boolean isResolvedOrRejectCaseRouting(String methodKey) {
        if (String.isBlank(methodKey)) {
            return false;
        }
        return methodKey == FEC_CaseBusinessService.RESOLVE || methodKey == FEC_CaseBusinessService.REJECT;
    }

    // 05/06/2026 14:00 linhdev - OwnerId Queue (prefix 00G) vs User (design import không GSR/COF)
    private static Boolean isQueueCaseOwnerId(Id ownerId) {
        if (ownerId == null) {
            return false;
        }
        return String.valueOf(ownerId).startsWith(QUEUE_OWNER_ID_PREFIX);
    }

    // 25/06/2026 linhdev - TH1: quy trình khác GSR/COF chỉ import khi user là Case Owner hoặc member Queue owner
    @TestVisible
    private static String validateNonCofGsrCaseImportOwnerAccess(
        Case matched,
        ImportValidateChunkContext ctx
    ) {
        if (matched == null || ctx == null || ctx.cofOrGsr == true || isCofOrGsrBusinessProcess(matched)) {
            return null;
        }
        Id currentUserId = ctx.currentUserId;
        Id caseOwnerId = matched.OwnerId;
        if (currentUserId == null || caseOwnerId == null) {
            return System.Label.FEC_Batch_Case_Handling_Import_Err_Case_Owner_Or_Queue_Member;
        }
        if (caseOwnerId == currentUserId) {
            return null;
        }
        if (isQueueCaseOwnerId(caseOwnerId) &&
            ctx.currentUserQueueIds != null &&
            ctx.currentUserQueueIds.contains(caseOwnerId)) {
            return null;
        }
        return System.Label.FEC_Batch_Case_Handling_Import_Err_Case_Owner_Or_Queue_Member;
    }

    // 05/06/2026 14:00 linhdev - check Business Process COF/GSR theo từng Case (không chỉ cờ import batch)
    private static Boolean isCofOrGsrBusinessProcess(Case matched) {
        String bpCode = resolveCaseBusinessProcessCode(matched);
        if (String.isBlank(bpCode)) {
            return false;
        }
        String prefix = FEC_BatchCaseHandlingTemplateHelper.mapBusinessProcessToTemplatePrefix(bpCode);
        return prefix == 'COF' || prefix == 'GSR';
    }

    private static Boolean isResolveRejectUpdateImportAction(String methodKey) {
        if (String.isBlank(methodKey)) {
            return false;
        }
        return methodKey == FEC_CaseBusinessService.RESOLVE
            || methodKey == FEC_CaseBusinessService.REJECT
            || methodKey == FEC_CaseBusinessService.UPDATEACTION;
    }

    // 05/06/2026 14:00 linhdev - quy trình không GSR/COF Resolve/Reject/Update: owner Queue → chuyển OwnerId sang Login User
    // 24/06/2026 - COF/GSR giữ owner Queue; FEC_CaseBusinessService bỏ qua owner check khi batch import + owner Queue
    private static void transferQueueOwnedCaseToLoginUserForNonCofGsrProcess(
        Id caseId,
        String methodKey,
        Map<Id, Case> caseLiteById
    ) {
        if (caseId == null || !isResolveRejectUpdateImportAction(methodKey)) {
            return;
        }
        Case caseLite = caseLiteById == null ? null : caseLiteById.get(caseId);
        if (caseLite == null || isCofOrGsrBusinessProcess(caseLite) || !isQueueCaseOwnerId(caseLite.OwnerId)) {
            return;
        }
        Id loginUserId = UserInfo.getUserId();
        update new Case(Id = caseId, OwnerId = loginUserId);
        caseLite.OwnerId = loginUserId;
        caseLiteById.put(caseId, caseLite);
    }

    //PhongBT 28/05/26: COF/GSR — chỉ cột Assignment Routing Action (routingAction trống).
    private static Boolean isAssignmentRoutingOnly(
        FEC_BatchCaseHandlingImportRow rr,
        Boolean cofOrGsr
    ) {
        return cofOrGsr == true
            && rr != null
            && String.isNotBlank(rr.assignmentRoutingAction)
            && String.isBlank(rr.routingAction);
    }

    // 25/06/2026 PhongBT: Validate ownership cho COF/GSR import theo rule:
    // TH1 (FEC_Assignment_Count__c = 0): Case Owner = login user hoặc Queue mà user là thành viên
    // TH2 (FEC_Assignment_Count__c > 0): FEC_Assignment_Users__c chứa User ID hoặc exact match tên Queue của user
    @TestVisible
    private static String validateCofGsrImportRowOwnership(
        Case caseLite,
        Set<Id> loginUserQueueIds,
        Id loginUserId,
        Set<String> loginUserQueueNames
    ) {
        if (caseLite == null) {
            return null;
        }
        Decimal assignmentCount = caseLite.FEC_Assignment_Count__c;
        boolean hasAssignment = assignmentCount != null && assignmentCount > 0;

        if (!hasAssignment) {
            // TH1: FEC_Assignment_Count__c = 0
            // Case Owner phải là login user HOẶC là Queue mà login user là thành viên
            Id ownerId = caseLite.OwnerId;
            if (ownerId == loginUserId) {
                return null;
            }
            if (loginUserQueueIds != null && loginUserQueueIds.contains(ownerId)) {
                return null;
            }
            return System.Label.FEC_BCH_Import_Err_Not_Case_Owner_Or_Queue_Member;
        }

        // TH2: FEC_Assignment_Count__c > 0
        // FEC_Assignment_Users__c chứa User ID HOẶC exact match tên Queue mà user là thành viên
        String assignmentUsers = caseLite.FEC_Assignment_Users__c;
        if (String.isBlank(assignmentUsers)) {
            return System.Label.FEC_BCH_Import_Err_Not_Assignment_Owner_Or_Queue_Member;
        }
        String normalized = assignmentUsers.replace(';', ',');
        Set<String> assignmentUserSet = new Set<String>();
        for (String val : normalized.split(',')) {
            String trimmed = val == null ? null : val.trim();
            if (String.isNotBlank(trimmed)) {
                assignmentUserSet.add(trimmed);
            }
        }
        // Check User ID
        if (loginUserId != null) {
            String userIdStr = String.valueOf(loginUserId);
            if (assignmentUserSet.contains(userIdStr)) {
                return null;
            }
            // Salesforce ID 15 vs 18 ký tự
            if (userIdStr.length() > 15 && assignmentUserSet.contains(userIdStr.substring(0, 15))) {
                return null;
            }
        }
        // Check exact match Queue name
        if (loginUserQueueNames != null) {
            for (String queueName : loginUserQueueNames) {
                if (String.isNotBlank(queueName) && assignmentUserSet.contains(queueName)) {
                    return null;
                }
            }
        }
        return System.Label.FEC_BCH_Import_Err_Not_Assignment_Owner_Or_Queue_Member;
    }

    //PhongBT 29/05/26: COF/GSR — Revert/Update/Escalate ở Routing Action (case) không được khi Case có Assignment.
    private static String validateCaseRoutingActionBlockedByAssignmentCount(
        FEC_BatchCaseHandlingImportRow rr,
        Case matched
    ) {
        if (rr == null || matched == null || String.isBlank(rr.routingAction)) {
            return null;
        }
        Decimal assignmentCount = matched.FEC_Assignment_Count__c;
        if (assignmentCount == null || assignmentCount <= 0) {
            return null;
        }
        RoutingParseResult parsed = parseRoutingPattern(rr.routingAction.trim());
        String methodKey = parsed == null ? null : parsed.methodKey;
        if (!isCaseRoutingActionBlockedWhenAssignmentsExist(methodKey)) {
            return null;
        }
        return System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Unavailable_Assignment;
    }

    private static Boolean isCaseRoutingActionBlockedWhenAssignmentsExist(String methodKey) {
        if (String.isBlank(methodKey)) {
            return false;
        }
        return methodKey == FEC_CaseBusinessService.REVERT
            || methodKey == FEC_CaseBusinessService.UPDATEACTION
            || methodKey == FEC_CaseBusinessService.ESCALATE;
    }

    //PhongBT 29/05/26: thêm update vào datagroup cho Assignment Routing Action
    private static Boolean isCofGsrImportUpdateAction(Boolean cofOrGsr, String routingLabel) {
        if (cofOrGsr != true || String.isBlank(routingLabel)) {
            return false;
        }
        RoutingParseResult parsed = parseRoutingPattern(routingLabel.trim());
        return parsed != null && parsed.methodKey == FEC_CaseBusinessService.UPDATEACTION;
    }

    private static Boolean isCofGsrImportResolveRejectAction(Boolean cofOrGsr, String routingLabel) {
        if (cofOrGsr != true || String.isBlank(routingLabel)) {
            return false;
        }
        RoutingParseResult parsed = parseRoutingPattern(routingLabel.trim());
        return parsed != null
            && FEC_BCH_AssignmentResolveRejectService.isResolveOrRejectMethodKey(parsed.methodKey);
    }

    private static Boolean isCofGsrImportAssignmentRevertAction(Boolean cofOrGsr, String routingLabel) {
        if (cofOrGsr != true || String.isBlank(routingLabel)) {
            return false;
        }
        return String.isNotBlank(FEC_BCH_AssignmentRevertService.resolveRevertDecisionFromLabel(routingLabel));
    }

    private static Boolean isCofGsrImportAllowedAssignmentRoutingAction(Boolean cofOrGsr, String routingLabel) {
        return isCofGsrImportUpdateAction(cofOrGsr, routingLabel)
            || isCofGsrImportResolveRejectAction(cofOrGsr, routingLabel)
            || isCofGsrImportAssignmentRevertAction(cofOrGsr, routingLabel);
    }

    private static Map<String, String> resolveRouteToParams(
        Id currentStageId,
        RoutingParseResult parsed,
        String actionButtonIdOverride,
        Boolean routeViaRevertButton
    ) {
        if (currentStageId == null || parsed == null) {
            return null;
        }
        String cacheKey = buildRouteParamsCacheKey(currentStageId, parsed) +
            '|' +
            String.valueOf(actionButtonIdOverride) +
            '|' +
            String.valueOf(routeViaRevertButton == true);
        if (routeParamsCacheByKey.containsKey(cacheKey)) {
            return routeParamsCacheByKey.get(cacheKey);
        }
        Id routeToButtonId = null;
        try {
            if (String.isNotBlank(actionButtonIdOverride)) {
                routeToButtonId = Id.valueOf(actionButtonIdOverride);
            }
        } catch (Exception ex) {
        }
        String routeButtonCode = routeViaRevertButton == true
            ? FEC_CaseBusinessService.REVERT
            : FEC_CaseBusinessService.ROUTE_TO;
        List<FEC_Stage_Change__c> candidates;
        if (routeToButtonId != null) {
            candidates = [
                SELECT FEC_Action_Button__c, FEC_Next_Queue__c, FEC_Team_User_Group__c, FEC_IsReverted__c
                FROM FEC_Stage_Change__c
                WHERE FEC_Previous_Stage__c = :currentStageId
                AND FEC_Active__c = TRUE
                AND FEC_Action_Button__c = :routeToButtonId
                ORDER BY FEC_IsReverted__c DESC, CreatedDate DESC
            ];
        } else {
            candidates = [
                SELECT FEC_Action_Button__c, FEC_Next_Queue__c, FEC_Team_User_Group__c, FEC_IsReverted__c
                FROM FEC_Stage_Change__c
                WHERE FEC_Previous_Stage__c = :currentStageId
                AND FEC_Active__c = TRUE
                AND FEC_Action_Button__r.FEC_Code__c = :routeButtonCode
                ORDER BY CreatedDate DESC
            ];
        }
        if (candidates.isEmpty()) {
            routeParamsCacheByKey.put(cacheKey, null);
            return null;
        }
        String mappedTeam = FEC_BatchCaseHandlingImportProfile.mapExcelRouteTeamToStageChangeGroup(
            parsed.routeTeamHint
        );
        String teamHintNorm = normalizeToken(
            String.isNotBlank(mappedTeam) ? mappedTeam : parsed.routeTeamHint
        );
        String queueHintNorm = normalizeToken(parsed.routeQueueHint);
        Set<String> stageChangeQueueTokens = new Set<String>();
        for (FEC_Stage_Change__c item : candidates) {
            if (item != null && String.isNotBlank(item.FEC_Next_Queue__c)) {
                stageChangeQueueTokens.add(item.FEC_Next_Queue__c.trim());
            }
        }
        Map<String, Group> queueByToken = new Map<String, Group>();
        if (!stageChangeQueueTokens.isEmpty()) {
            for (Group q : [
                SELECT Id, Name, DeveloperName
                FROM Group
                WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
                AND (DeveloperName IN :stageChangeQueueTokens OR Name IN :stageChangeQueueTokens)
            ]) {
                if (String.isNotBlank(q.DeveloperName)) {
                    queueByToken.put(q.DeveloperName, q);
                }
                if (String.isNotBlank(q.Name)) {
                    queueByToken.put(q.Name, q);
                }
            }
        }
        FEC_Stage_Change__c selected;
        for (FEC_Stage_Change__c item : candidates) {
            if (item == null) {
                continue;
            }
            if (String.isNotBlank(teamHintNorm) && normalizeToken(item.FEC_Team_User_Group__c) != teamHintNorm) {
                continue;
            }
            if (String.isNotBlank(queueHintNorm)) {
                Group queueMeta = String.isBlank(item.FEC_Next_Queue__c) ? null : queueByToken.get(item.FEC_Next_Queue__c.trim());
                String queueTokenNorm = normalizeToken(item.FEC_Next_Queue__c);
                String queueNameNorm = queueMeta == null ? null : normalizeToken(queueMeta.Name);
                String queueDevNorm = queueMeta == null ? null : normalizeToken(queueMeta.DeveloperName);
                if (queueHintNorm != queueTokenNorm && queueHintNorm != queueNameNorm && queueHintNorm != queueDevNorm) {
                    continue;
                }
            }
            selected = item;
            break;
        }
        if (selected == null) {
            selected = candidates[0];
        }
        String queueId = resolveQueueIdFromToken(selected.FEC_Next_Queue__c);
        if (selected.FEC_Action_Button__c == null || String.isBlank(queueId)) {
            routeParamsCacheByKey.put(cacheKey, null);
            return null;
        }
        Map<String, String> resolved = new Map<String, String>{
            'actionId' => String.valueOf(selected.FEC_Action_Button__c),
            'queueId' => queueId,
            //PhongBT 28/05/26: Developer name queue (FEC_Next_Queue__c) — dùng lookup FEC_Team_Queue__c khi update Assignment.
            'queueToken' => selected.FEC_Next_Queue__c
        };
        routeParamsCacheByKey.put(cacheKey, resolved);
        return resolved;
    }

    //PhongBT 28/05/26: Delegate bulk cập nhật Assignment Route To sang FEC_BCH_AssignmentRouteToService (4 rule spec).
    private static void applyAssignmentRouteToBulk(List<AssignmentRouteToUpdateItem> routeToItems) {
        if (routeToItems == null || routeToItems.isEmpty()) {
            return;
        }
        List<FEC_BCH_AssignmentRouteToService.RouteToContext> contexts =
            new List<FEC_BCH_AssignmentRouteToService.RouteToContext>();
        Map<Id, List<AssignmentRouteToUpdateItem>> rowsByAssignmentId =
            new Map<Id, List<AssignmentRouteToUpdateItem>>();
        for (AssignmentRouteToUpdateItem item : routeToItems) {
            if (item == null || item.assignmentId == null || item.row == null) {
                continue;
            }
            //PhongBT 28/05/26: Resolve queue developer name từ Stage Change token hoặc hint Excel.
            String queueDevName = FEC_BCH_AssignmentRouteToService.resolveQueueDeveloperName(
                item.queueToken,
                item.routeTeamHint,
                item.routeQueueHint
            );
            if (String.isBlank(queueDevName)) {
                item.row.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                item.row.errors = appendError(
                    item.row.errors,
                    ERR_ASSIGNMENT_ROUTE_TO_QUEUE_UNKNOWN
                );
                continue;
            }
            FEC_BCH_AssignmentRouteToService.RouteToContext ctx =
                new FEC_BCH_AssignmentRouteToService.RouteToContext();
            ctx.assignmentId = item.assignmentId;
            ctx.queueDeveloperName = queueDevName;
            ctx.submittedOn = item.submittedOn == null ? System.now() : item.submittedOn;
            contexts.add(ctx);
            if (!rowsByAssignmentId.containsKey(item.assignmentId)) {
                rowsByAssignmentId.put(item.assignmentId, new List<AssignmentRouteToUpdateItem>());
            }
            rowsByAssignmentId.get(item.assignmentId).add(item);
        }
        if (contexts.isEmpty()) {
            return;
        }
        List<FEC_BCH_AssignmentRouteToService.ApplyResult> results =
            FEC_BCH_AssignmentRouteToService.applyRouteToAssignmentsBulk(contexts);
        //PhongBT 28/05/26: Gán lỗi update Assignment lên dòng import result.
        for (FEC_BCH_AssignmentRouteToService.ApplyResult result : results) {
            if (result == null || result.success == true || result.assignmentId == null) {
                continue;
            }
            if (!rowsByAssignmentId.containsKey(result.assignmentId)) {
                continue;
            }
            for (AssignmentRouteToUpdateItem item : rowsByAssignmentId.get(result.assignmentId)) {
                if (item == null || item.row == null) {
                    continue;
                }
                item.row.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                item.row.errors = appendError(item.row.errors, result.errorMessage);
            }
        }
    }

    private static String resolveRevertActionId(
        Id currentStageId,
        String actionButtonIdOverride,
        Boolean preferRevertedChange
    ) {
        if (currentStageId == null) {
            return null;
        }
        String cacheKey =
            String.valueOf(currentStageId) +
            '|' +
            String.valueOf(actionButtonIdOverride) +
            '|' +
            String.valueOf(preferRevertedChange == true);
        if (revertActionIdCacheByStage.containsKey(cacheKey)) {
            return revertActionIdCacheByStage.get(cacheKey);
        }
        if (String.isNotBlank(actionButtonIdOverride)) {
            revertActionIdCacheByStage.put(cacheKey, actionButtonIdOverride);
            return actionButtonIdOverride;
        }
        List<FEC_Stage_Change__c> changes = [
            SELECT FEC_Action_Button__c
            FROM FEC_Stage_Change__c
            WHERE FEC_Previous_Stage__c = :currentStageId
            AND FEC_Active__c = TRUE
            AND FEC_Action_Button__r.FEC_Code__c = :FEC_CaseBusinessService.REVERT
            AND FEC_IsReverted__c = :preferRevertedChange
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!changes.isEmpty() && changes[0].FEC_Action_Button__c != null) {
            String actionId = String.valueOf(changes[0].FEC_Action_Button__c);
            revertActionIdCacheByStage.put(cacheKey, actionId);
            return actionId;
        }
        List<FEC_Stage_Change__c> fallbackChanges = [
            SELECT FEC_Action_Button__c
            FROM FEC_Stage_Change__c
            WHERE FEC_Previous_Stage__c = :currentStageId
            AND FEC_Active__c = TRUE
            AND FEC_Action_Button__r.FEC_Code__c = :FEC_CaseBusinessService.REVERT
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!fallbackChanges.isEmpty() && fallbackChanges[0].FEC_Action_Button__c != null) {
            String actionId = String.valueOf(fallbackChanges[0].FEC_Action_Button__c);
            revertActionIdCacheByStage.put(cacheKey, actionId);
            return actionId;
        }
        List<FEC_Stage_Screen__c> screens = [
            SELECT FEC_Action_Button__c
            FROM FEC_Stage_Screen__c
            WHERE FEC_Case_Stage__c = :currentStageId
            AND FEC_Active__c = TRUE
            AND FEC_Action_Button__r.FEC_Code__c = :FEC_CaseBusinessService.REVERT
            LIMIT 1
        ];
        String resolved = screens.isEmpty() || screens[0].FEC_Action_Button__c == null
            ? null
            : String.valueOf(screens[0].FEC_Action_Button__c);
        revertActionIdCacheByStage.put(cacheKey, resolved);
        return resolved;
    }

    private static String resolveImportResultStatusLabel(String rowStatus) {
        if (rowStatus == System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed) {
            return System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        }
        if (String.isBlank(rowStatus)) {
            return System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        }
        return System.Label.FEC_Batch_Case_Handling_Success;
    }

    private static String buildRouteParamsCacheKey(Id currentStageId, RoutingParseResult parsed) {
        String teamHint = parsed == null ? FEC_ConstantCommon.STR_EMPTY : normalizeToken(parsed.routeTeamHint);
        String queueHint = parsed == null ? FEC_ConstantCommon.STR_EMPTY : normalizeToken(parsed.routeQueueHint);
        return String.valueOf(currentStageId) + '|' + teamHint + '|' + queueHint;
    }

    private static String resolveQueueIdFromToken(String queueToken) {
        if (String.isBlank(queueToken)) {
            return null;
        }
        String token = queueToken.trim();
        if (queueIdCacheByToken.containsKey(token)) {
            return queueIdCacheByToken.get(token);
        }
        try {
            Id queueId = Id.valueOf(token);
            List<Group> byId = [
                SELECT Id
                FROM Group
                WHERE Id = :queueId
                AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
                LIMIT 1
            ];
            if (!byId.isEmpty()) {
                String resolvedId = String.valueOf(byId[0].Id);
                queueIdCacheByToken.put(token, resolvedId);
                return resolvedId;
            }
        } catch (Exception ex) {
        }
        List<Group> byName = [
            SELECT Id
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND (DeveloperName = :token OR Name = :token)
            LIMIT 1
        ];
        String resolvedId = byName.isEmpty() ? null : String.valueOf(byName[0].Id);
        queueIdCacheByToken.put(token, resolvedId);
        return resolvedId;
    }

    private static String resolveCaseBusinessProcessCode(Case matched) {
        if (matched == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (
            matched.FEC_Business_Process__r != null &&
            String.isNotBlank(matched.FEC_Business_Process__r.FEC_Code__c)
        ) {
            return matched.FEC_Business_Process__r.FEC_Code__c.trim();
        }
        SObject stage = matched.getSObject('FEC_Current_Case_Stage__r');
        if (stage == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        SObject bp = stage.getSObject('FEC_Business_Process__r');
        if (bp == null || bp.get('FEC_Code__c') == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return String.valueOf(bp.get('FEC_Code__c')).trim();
    }

    private static Map<Id, Set<String>> loadConfiguredLabelsByStage(Set<Id> stageIds) {
        Map<Id, Set<String>> out = new Map<Id, Set<String>>();
        if (stageIds == null || stageIds.isEmpty()) {
            return out;
        }
        List<String> importFieldLabels = new List<String>{
            LABEL_CS_D2C_ASSESSMENT,
            LABEL_CS_SUPPORT_ASSESSMENT,
            LABEL_RISK_LEVEL,
            LABEL_REQUIRED_ACTION,
            LABEL_PAYMENT_CONTRACT_ASSESSMENT,
            LABEL_PAYMENT_CONTRACT_ASSESSMENT_ALIAS,
            LABEL_PAYMENT_CONTRACT_ASSESSMENT_MDM_EN,
            LABEL_CP_ASSESSMENT
        };
        for (FEC_Master_Data_Setting__c row : [
            SELECT FEC_Stage_Name__c, FEC_Field_Label_Name__c, FEC_Field_API_Name__c
            FROM FEC_Master_Data_Setting__c
            WHERE FEC_Stage_Name__c IN :stageIds
            AND (
                FEC_Field_Label_Name__c IN :importFieldLabels
                OR FEC_Field_API_Name__c IN :new List<String>{
                    API_CS_SUPPORT_ASSESSMENT,
                    API_RD_PAYMENT_CONTRACT_ASSESSMENT
                }
            )
        ]) {
            if (row.FEC_Stage_Name__c == null) {
                continue;
            }
            Boolean isCsSupportByApi =
                API_CS_SUPPORT_ASSESSMENT.equalsIgnoreCase(row.FEC_Field_API_Name__c);
            Boolean isPaymentByApi =
                API_RD_PAYMENT_CONTRACT_ASSESSMENT.equalsIgnoreCase(row.FEC_Field_API_Name__c);
            if (String.isBlank(row.FEC_Field_Label_Name__c) &&
                isCsSupportByApi != true &&
                isPaymentByApi != true) {
                continue;
            }
            if (!out.containsKey(row.FEC_Stage_Name__c)) {
                out.put(row.FEC_Stage_Name__c, new Set<String>());
            }
            if (String.isNotBlank(row.FEC_Field_Label_Name__c)) {
                out.get(row.FEC_Stage_Name__c).add(normalizeToken(row.FEC_Field_Label_Name__c));
            }
            // MDM label EN (CS Support Assessment Type) vs template VN (CS Support đánh giá yêu cầu)
            if (isCsSupportByApi) {
                out.get(row.FEC_Stage_Name__c).add(normalizeToken(LABEL_CS_SUPPORT_ASSESSMENT));
            }
            // PM import template label vs MDM alias (Đánh giá của RD Payment cho yêu cầu đóng HĐ)
            if (isPaymentByApi) {
                out.get(row.FEC_Stage_Name__c).add(normalizeToken(LABEL_PAYMENT_CONTRACT_ASSESSMENT));
                out.get(row.FEC_Stage_Name__c).add(normalizeToken(LABEL_PAYMENT_CONTRACT_ASSESSMENT_ALIAS));
                out.get(row.FEC_Stage_Name__c).add(normalizeToken(LABEL_PAYMENT_CONTRACT_ASSESSMENT_MDM_EN));
            }
        }
        return out;
    }

    private static List<String> importPicklistFieldApis() {
        return new List<String>{
            'FEC_CS_D2C_Assessment_Type__c',
            'FEC_CS_Support_Assessment_Type__c',
            'FEC_CS_D2C_Required_Corrective_Action__c',
            'FEC_CS_D2C_Risk_Level__c',
            'FEC_CS_Check_Classification_by_CS__c',
            'FEC_CS_Check_Evaluation_by_CS__c',
            'FEC_CS_Check_Final_product__c',
            'FEC_RD_Payment_Contract_Assessment__c',
            'FEC_Contract_Processing_MRC_Assessment__c'
        };
    }

    private static List<String> validateResolvedRoutingForRow(
        FEC_BatchCaseHandlingImportRow rr,
        Case matched,
        Boolean cofOrGsr
    ) {
        List<String> errs = new List<String>();
        if (rr == null) {
            return errs;
        }
        String primaryLabel = rr.routingAction;
        if (cofOrGsr == true && String.isBlank(primaryLabel)) {
            primaryLabel = rr.assignmentRoutingAction;
        }
        if (String.isBlank(primaryLabel)) {
            return errs;
        }
        Boolean assignmentOnly = isAssignmentRoutingOnly(rr, cofOrGsr);
        Id stageId = matched == null ? null : matched.FEC_Current_Case_Stage__c;
        FEC_BCH_ImportRoutingResolver.ResolvedRouting resolved =
            FEC_BCH_ImportRoutingResolver.resolve(stageId, primaryLabel, assignmentOnly == true);
        String routingInvalidLabel = assignmentOnly == true
            ? System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Invalid
            : System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid;
        //PhongBT 02/06/26: Sửa routing action cho cof/gsr — Route To Excel không cần khớp Datagroup.
        Boolean cofGsrRouteToImportLabel = cofOrGsr == true &&
            FEC_BCH_CofGsrImportRouteToService.isCofGsrRouteToImportLabel(primaryLabel);
        Boolean cofGsrCaseRouteToLabel = cofGsrRouteToImportLabel == true && assignmentOnly != true;
        if (resolved == null || String.isBlank(resolved.methodKey)) {
            if (cofGsrRouteToImportLabel == true) {
                if (!FEC_BCH_CofGsrImportRouteToService.isRouteToLabelResolvable(primaryLabel)) {
                    errs.add(routingInvalidLabel);
                }
                return errs;
            }
            errs.add(routingInvalidLabel);
            return errs;
        }
        if (resolved.methodKey == FEC_CaseBusinessService.TRANSFER) {
            errs.add(routingInvalidLabel);
            return errs;
        }
        //PhongBT 29/05/26: thêm update vào datagroup cho Assignment Routing Action
        Boolean skipDatagroupForUpdate = isCofGsrImportAllowedAssignmentRoutingAction(cofOrGsr, primaryLabel);
        if (!skipDatagroupForUpdate &&
            cofGsrRouteToImportLabel != true &&
            FEC_BCH_ImportRoutingResolver.requiresStageScreenMatch(resolved.methodKey) &&
            stageId != null &&
            resolved.matchedStageScreen != true) {
            errs.add(routingInvalidLabel);
            return errs;
        }
        if (cofGsrRouteToImportLabel == true &&
            !FEC_BCH_CofGsrImportRouteToService.isRouteToLabelResolvable(primaryLabel)) {
            errs.add(routingInvalidLabel);
            return errs;
        }
        applyResolvedRoutingToRow(rr, resolved);
        if (cofOrGsr == true && String.isNotBlank(rr.routingAction) && String.isNotBlank(rr.assignmentRoutingAction)) {
            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Both_Routing_Actions);
        }
        if (cofOrGsr == true && String.isNotBlank(rr.routingAction) && String.isNotBlank(rr.assignmentId)) {
            FEC_BCH_ImportRoutingResolver.ResolvedRouting caseResolved =
                FEC_BCH_ImportRoutingResolver.resolve(stageId, rr.routingAction);
            //PhongBT 29/05/26: thêm update vào datagroup cho Assignment Routing Action
            if (caseResolved == null || String.isBlank(caseResolved.methodKey)) {
                if (!isCofGsrImportUpdateAction(cofOrGsr, rr.routingAction)) {
                    errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid);
                }
            } else if (
                !isResolvedOrRejectCaseRouting(caseResolved.methodKey) &&
                !isCofGsrImportUpdateAction(cofOrGsr, rr.routingAction)
            ) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Resolve_Only);
            }
        }
        if (cofOrGsr == true &&
            String.isNotBlank(rr.assignmentRoutingAction) &&
            String.isBlank(rr.routingAction)) {
            FEC_BCH_ImportRoutingResolver.ResolvedRouting asgResolved =
                FEC_BCH_ImportRoutingResolver.resolve(stageId, rr.assignmentRoutingAction, true);
            //PhongBT 29/05/26: thêm update vào datagroup cho Assignment Routing Action
            if ((asgResolved == null || String.isBlank(asgResolved.methodKey)) &&
                !isCofGsrImportAllowedAssignmentRoutingAction(cofOrGsr, rr.assignmentRoutingAction)) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Invalid);
            } else if (asgResolved != null) {
                applyResolvedRoutingToRow(rr, asgResolved);
            }
        }
        return errs;
    }

    private static void applyResolvedRoutingToRow(
        FEC_BatchCaseHandlingImportRow rr,
        FEC_BCH_ImportRoutingResolver.ResolvedRouting resolved
    ) {
        if (rr == null || resolved == null) {
            return;
        }
        if (resolved.actionButtonId != null) {
            rr.actionButtonId = String.valueOf(resolved.actionButtonId);
        }
        rr.routingActionValue = resolved.routingActionValue;
        rr.routeViaRevertButton = resolved.routeViaRevertButton == true;
        rr.revertPreferRevertedChange = resolved.revertPreferRevertedChange == true;
    }

    private static String buildRoutingSignature(FEC_BatchCaseHandlingImportRow rr, Boolean cofOrGsr) {
        if (rr == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String caseRouting = String.isBlank(rr.routingAction) ? FEC_ConstantCommon.STR_EMPTY : rr.routingAction.trim();
        String asgRouting = String.isBlank(rr.assignmentRoutingAction)
            ? FEC_ConstantCommon.STR_EMPTY
            : rr.assignmentRoutingAction.trim();
        if (cofOrGsr != true) {
            return normalizeToken(caseRouting);
        }
        return normalizeToken(caseRouting) + '|' + normalizeToken(asgRouting);
    }

    private static List<String> validateScopeFieldsForCase(
        FEC_BatchCaseHandlingImportRow rr,
        Case matched,
        FEC_BatchCaseHandlingImportProfile.ImportScope importScope,
        Map<Id, Set<String>> configuredLabelsByStage,
        Map<String, Map<String, String>> picklistValueByNormByField
    ) {
        List<String> errs = new List<String>();
        if (rr == null || matched == null || importScope == null) {
            return errs;
        }
        if (matched.FEC_Current_Case_Stage__c == null) {
            errs.add(ERR_FIELD_NOT_CONFIGURED);
            return errs;
        }
        Set<String> configuredLabels = configuredLabelsByStage.get(matched.FEC_Current_Case_Stage__c);
        if (configuredLabels == null) {
            configuredLabels = new Set<String>();
        }
        String profile = importScope.fieldProfile;
        if (profile == FEC_BatchCaseHandlingImportProfile.FIELD_PROFILE_D2C) {
            validateD2CField(
                rr,
                rr.csD2CAssessmentType,
                LABEL_CS_D2C_ASSESSMENT,
                null,
                ERR_MISSING_CS_D2C_ASSESSMENT,
                ERR_INVALID_CS_D2C_ASSESSMENT,
                'FEC_CS_D2C_Assessment_Type__c',
                configuredLabels,
                picklistValueByNormByField,
                errs,
                true
            );
            validateD2CField(
                rr,
                rr.riskLevel,
                LABEL_RISK_LEVEL,
                null,
                ERR_MISSING_RISK_LEVEL,
                ERR_INVALID_RISK_LEVEL,
                'FEC_CS_D2C_Risk_Level__c',
                configuredLabels,
                picklistValueByNormByField,
                errs,
                true
            );
            validateD2CField(
                rr,
                rr.requiredAction,
                LABEL_REQUIRED_ACTION,
                null,
                ERR_MISSING_REQUIRED_ACTION,
                ERR_INVALID_REQUIRED_ACTION,
                'FEC_CS_D2C_Required_Corrective_Action__c',
                configuredLabels,
                picklistValueByNormByField,
                errs,
                true
            );
            return errs;
        }
        if (profile == FEC_BatchCaseHandlingImportProfile.FIELD_PROFILE_PM_PAYMENT) {
            //tungnm37 - chỉ validate Payment assessment khi file import thực sự có cột này.
            if (hasAnyImportHeader(rr, new Set<String>{
                normalizeToken(LABEL_PAYMENT_CONTRACT_ASSESSMENT),
                normalizeToken(LABEL_PAYMENT_CONTRACT_ASSESSMENT_ALIAS),
                normalizeToken(LABEL_PAYMENT_CONTRACT_ASSESSMENT_MDM_EN),
                'paymentcontractassessment',
                'rdpaymentcontractassessment',
                'paymentdanhgiayeucaudonghopdong'
            })) {
                validateD2CField(
                    rr,
                    rr.paymentContractAssessment,
                    LABEL_PAYMENT_CONTRACT_ASSESSMENT,
                    new Set<String>{
                        normalizeToken(LABEL_PAYMENT_CONTRACT_ASSESSMENT),
                        normalizeToken(LABEL_PAYMENT_CONTRACT_ASSESSMENT_ALIAS),
                        normalizeToken(LABEL_PAYMENT_CONTRACT_ASSESSMENT_MDM_EN)
                    },
                    ERR_MISSING_PAYMENT_ASSESSMENT,
                    ERR_INVALID_PAYMENT_ASSESSMENT,
                    'FEC_RD_Payment_Contract_Assessment__c',
                    configuredLabels,
                    picklistValueByNormByField,
                    errs,
                    true
                );
            }
            return errs;
        }
        if (profile == FEC_BatchCaseHandlingImportProfile.FIELD_PROFILE_CP_ASSESSMENT) {
            validateD2CField(
                rr,
                rr.cpAssessment,
                LABEL_CP_ASSESSMENT,
                null,
                ERR_MISSING_CP_ASSESSMENT,
                ERR_INVALID_CP_ASSESSMENT,
                'FEC_Contract_Processing_MRC_Assessment__c',
                configuredLabels,
                picklistValueByNormByField,
                errs,
                true
            );
            return errs;
        }
        if (profile == FEC_BatchCaseHandlingImportProfile.FIELD_PROFILE_CS_SUPPORT) {
            // 28/05/2026 14:37 linhdev - CS Support Assessment không bắt buộc cho row chỉ nhập bộ D2C (theo template import thực tế).
            validateD2CField(
                rr,
                rr.csSupportAssessment,
                LABEL_CS_SUPPORT_ASSESSMENT,
                null,
                'Thiếu giá trị CS Support đánh giá yêu cầu',
                'Giá trị CS Support đánh giá yêu cầu không tồn tại trong Datagroup.',
                'FEC_CS_Support_Assessment_Type__c',
                configuredLabels,
                picklistValueByNormByField,
                errs,
                false
            );
            validateD2CField(
                rr,
                rr.classificationByCS,
                LABEL_CS_SUPPORT_ASSESSMENT,
                null,
                'Thiếu giá trị Classification by CS',
                'Giá trị Classification by CS không tồn tại trong Datagroup.',
                'FEC_CS_Check_Classification_by_CS__c',
                configuredLabels,
                picklistValueByNormByField,
                errs,
                false
            );
            validateD2CField(
                rr,
                rr.evaluationByCS,
                LABEL_CS_SUPPORT_ASSESSMENT,
                null,
                'Thiếu giá trị Evaluation by CS',
                'Giá trị Evaluation by CS không tồn tại trong Datagroup.',
                'FEC_CS_Check_Evaluation_by_CS__c',
                configuredLabels,
                picklistValueByNormByField,
                errs,
                false
            );
            validateD2CField(
                rr,
                rr.finalProduct,
                LABEL_CS_SUPPORT_ASSESSMENT,
                null,
                'Thiếu giá trị Final Product',
                'Giá trị Final Product không tồn tại trong Datagroup.',
                'FEC_CS_Check_Final_product__c',
                configuredLabels,
                picklistValueByNormByField,
                errs,
                false
            );
            return errs;
        }
        Boolean hasAnyD2CInput =
            String.isNotBlank(rr.csD2CAssessmentType) ||
            String.isNotBlank(rr.riskLevel) ||
            String.isNotBlank(rr.requiredAction);
        if (hasAnyD2CInput) {
            validateD2CField(
                rr,
                rr.csD2CAssessmentType,
                LABEL_CS_D2C_ASSESSMENT,
                null,
                ERR_MISSING_CS_D2C_ASSESSMENT,
                ERR_INVALID_CS_D2C_ASSESSMENT,
                'FEC_CS_D2C_Assessment_Type__c',
                configuredLabels,
                picklistValueByNormByField,
                errs,
                false
            );
            validateD2CField(
                rr,
                rr.riskLevel,
                LABEL_RISK_LEVEL,
                null,
                ERR_MISSING_RISK_LEVEL,
                ERR_INVALID_RISK_LEVEL,
                'FEC_CS_D2C_Risk_Level__c',
                configuredLabels,
                picklistValueByNormByField,
                errs,
                false
            );
            validateD2CField(
                rr,
                rr.requiredAction,
                LABEL_REQUIRED_ACTION,
                null,
                ERR_MISSING_REQUIRED_ACTION,
                ERR_INVALID_REQUIRED_ACTION,
                'FEC_CS_D2C_Required_Corrective_Action__c',
                configuredLabels,
                picklistValueByNormByField,
                errs,
                false
            );
        }
        return errs;
    }

    //tungnm37 03/06/26: thêm hàm kiểm tra xem có bất kỳ header nào trong file import thực sự có trong Set<String> normalizedHeaderTokens không.
    private static Boolean hasAnyImportHeader(FEC_BatchCaseHandlingImportRow rr, Set<String> normalizedHeaderTokens) {
        if (rr == null || rr.originalHeaders == null || rr.originalHeaders.isEmpty() || normalizedHeaderTokens == null || normalizedHeaderTokens.isEmpty()) {
            return false;
        }
        for (String header : rr.originalHeaders) {
            String normalized = normalizeToken(header);
            if (normalizedHeaderTokens.contains(normalized)) {
                return true;
            }
        }
        return false;
    }
    private static void validateD2CField(
        FEC_BatchCaseHandlingImportRow rr,
        String inputValue,
        String fieldLabel,
        Set<String> acceptedConfiguredLabelTokens,
        String missingError,
        String invalidError,
        String caseFieldApi,
        Set<String> configuredLabels,
        Map<String, Map<String, String>> picklistValueByNormByField,
        List<String> errs,
        Boolean required
    ) {
        if (String.isBlank(inputValue)) {
            if (required) {
                errs.add(missingError);
            }
            return;
        }
        Set<String> acceptedTokens = acceptedConfiguredLabelTokens;
        if (acceptedTokens == null || acceptedTokens.isEmpty()) {
            acceptedTokens = new Set<String>{ normalizeToken(fieldLabel) };
        }
        Boolean isConfigured = false;
        if (configuredLabels != null) {
            for (String acceptedToken : acceptedTokens) {
                if (configuredLabels.contains(acceptedToken)) {
                    isConfigured = true;
                    break;
                }
            }
        }
        if (!isConfigured) {
            errs.add(ERR_FIELD_NOT_CONFIGURED);
            return;
        }
        String resolvedValue = resolvePicklistValue(caseFieldApi, inputValue, picklistValueByNormByField);
        if (String.isBlank(resolvedValue)) {
            errs.add(invalidError);
            return;
        }
        storeResolvedPicklistApiValue(rr, caseFieldApi, resolvedValue);
    }

    private static void storeResolvedPicklistApiValue(
        FEC_BatchCaseHandlingImportRow rr,
        String caseFieldApi,
        String apiValue
    ) {
        if (rr == null || String.isBlank(caseFieldApi) || String.isBlank(apiValue)) {
            return;
        }
        if (caseFieldApi == 'FEC_CS_D2C_Assessment_Type__c') {
            rr.csD2CAssessmentTypeApiValue = apiValue;
        } else if (caseFieldApi == 'FEC_CS_Support_Assessment_Type__c') {
            rr.csSupportAssessmentApiValue = apiValue;
        } else if (caseFieldApi == 'FEC_CS_D2C_Required_Corrective_Action__c') {
            rr.requiredActionApiValue = apiValue;
        } else if (caseFieldApi == 'FEC_CS_D2C_Risk_Level__c') {
            rr.riskLevelApiValue = apiValue;
        } else if (caseFieldApi == 'FEC_CS_Check_Classification_by_CS__c') {
            rr.classificationByCSApiValue = apiValue;
        } else if (caseFieldApi == 'FEC_CS_Check_Evaluation_by_CS__c') {
            rr.evaluationByCSApiValue = apiValue;
        } else if (caseFieldApi == 'FEC_CS_Check_Final_product__c') {
            rr.finalProductApiValue = apiValue;
        } else if (caseFieldApi == 'FEC_RD_Payment_Contract_Assessment__c') {
            rr.paymentContractAssessmentApiValue = apiValue;
        } else if (caseFieldApi == 'FEC_Contract_Processing_MRC_Assessment__c') {
            rr.cpAssessmentApiValue = apiValue;
        }
    }

    private static String readResolvedPicklistApiValue(
        FEC_BatchCaseHandlingImportRow rr,
        String caseFieldApi
    ) {
        if (rr == null || String.isBlank(caseFieldApi)) {
            return null;
        }
        if (caseFieldApi == 'FEC_CS_D2C_Assessment_Type__c') {
            return rr.csD2CAssessmentTypeApiValue;
        }
        if (caseFieldApi == 'FEC_CS_Support_Assessment_Type__c') {
            return rr.csSupportAssessmentApiValue;
        }
        if (caseFieldApi == 'FEC_CS_D2C_Required_Corrective_Action__c') {
            return rr.requiredActionApiValue;
        }
        if (caseFieldApi == 'FEC_CS_D2C_Risk_Level__c') {
            return rr.riskLevelApiValue;
        }
        if (caseFieldApi == 'FEC_CS_Check_Classification_by_CS__c') {
            return rr.classificationByCSApiValue;
        }
        if (caseFieldApi == 'FEC_CS_Check_Evaluation_by_CS__c') {
            return rr.evaluationByCSApiValue;
        }
        if (caseFieldApi == 'FEC_CS_Check_Final_product__c') {
            return rr.finalProductApiValue;
        }
        if (caseFieldApi == 'FEC_RD_Payment_Contract_Assessment__c') {
            return rr.paymentContractAssessmentApiValue;
        }
        if (caseFieldApi == 'FEC_Contract_Processing_MRC_Assessment__c') {
            return rr.cpAssessmentApiValue;
        }
        return null;
    }

    private static Case buildD2CCaseUpdate(
        Id caseId,
        FEC_BatchCaseHandlingImportRow rr,
        Map<String, Schema.SObjectField> caseFieldMap,
        Map<String, Map<String, String>> picklistValueByNormByField
    ) {
        if (caseId == null || rr == null) {
            return null;
        }
        Case c = new Case(Id = caseId);
        Boolean hasAny = false;
        String assessmentValue = resolvePicklistValueForApply(
            rr,
            'FEC_CS_D2C_Assessment_Type__c',
            rr.csD2CAssessmentType,
            picklistValueByNormByField
        );
        String riskValue = resolvePicklistValueForApply(
            rr,
            'FEC_CS_D2C_Risk_Level__c',
            rr.riskLevel,
            picklistValueByNormByField
        );
        String requiredActionValue = resolvePicklistValueForApply(
            rr,
            'FEC_CS_D2C_Required_Corrective_Action__c',
            rr.requiredAction,
            picklistValueByNormByField
        );
        String csSupportAssessmentValue = resolvePicklistValueForApply(
            rr,
            'FEC_CS_Support_Assessment_Type__c',
            rr.csSupportAssessment,
            picklistValueByNormByField
        );
        String classificationByCSValue = resolvePicklistValueForApply(
            rr,
            'FEC_CS_Check_Classification_by_CS__c',
            rr.classificationByCS,
            picklistValueByNormByField
        );
        String evaluationByCSValue = resolvePicklistValueForApply(
            rr,
            'FEC_CS_Check_Evaluation_by_CS__c',
            rr.evaluationByCS,
            picklistValueByNormByField
        );
        String finalProductValue = resolvePicklistValueForApply(
            rr,
            'FEC_CS_Check_Final_product__c',
            rr.finalProduct,
            picklistValueByNormByField
        );
        if (String.isNotBlank(assessmentValue) && caseFieldMap.containsKey('FEC_CS_D2C_Assessment_Type__c')) {
            c.put('FEC_CS_D2C_Assessment_Type__c', assessmentValue);
            hasAny = true;
        }
        if (String.isNotBlank(csSupportAssessmentValue) && caseFieldMap.containsKey('FEC_CS_Support_Assessment_Type__c')) {
            c.put('FEC_CS_Support_Assessment_Type__c', csSupportAssessmentValue);
            hasAny = true;
        }
        if (String.isNotBlank(riskValue) && caseFieldMap.containsKey('FEC_CS_D2C_Risk_Level__c')) {
            c.put('FEC_CS_D2C_Risk_Level__c', riskValue);
            hasAny = true;
        }
        if (String.isNotBlank(requiredActionValue) && caseFieldMap.containsKey('FEC_CS_D2C_Required_Corrective_Action__c')) {
            c.put('FEC_CS_D2C_Required_Corrective_Action__c', requiredActionValue);
            hasAny = true;
        }
        if (String.isNotBlank(classificationByCSValue) && caseFieldMap.containsKey('FEC_CS_Check_Classification_by_CS__c')) {
            c.put('FEC_CS_Check_Classification_by_CS__c', classificationByCSValue);
            hasAny = true;
        }
        if (String.isNotBlank(evaluationByCSValue) && caseFieldMap.containsKey('FEC_CS_Check_Evaluation_by_CS__c')) {
            c.put('FEC_CS_Check_Evaluation_by_CS__c', evaluationByCSValue);
            hasAny = true;
        }
        if (String.isNotBlank(finalProductValue) && caseFieldMap.containsKey('FEC_CS_Check_Final_product__c')) {
            c.put('FEC_CS_Check_Final_product__c', finalProductValue);
            hasAny = true;
        }
        String paymentValue = resolvePicklistValueForApply(
            rr,
            'FEC_RD_Payment_Contract_Assessment__c',
            rr.paymentContractAssessment,
            picklistValueByNormByField
        );
        String cpValue = resolvePicklistValueForApply(
            rr,
            'FEC_Contract_Processing_MRC_Assessment__c',
            rr.cpAssessment,
            picklistValueByNormByField
        );
        if (String.isNotBlank(paymentValue) && caseFieldMap.containsKey('FEC_RD_Payment_Contract_Assessment__c')) {
            c.put('FEC_RD_Payment_Contract_Assessment__c', paymentValue);
            hasAny = true;
        }
        if (String.isNotBlank(cpValue) && caseFieldMap.containsKey('FEC_Contract_Processing_MRC_Assessment__c')) {
            c.put('FEC_Contract_Processing_MRC_Assessment__c', cpValue);
            hasAny = true;
        }
        return hasAny ? c : null;
    }

    private static void applyD2CFieldUpdatesBulk(
        Map<Id, Case> pendingCaseFieldUpdatesById,
        Map<Id, List<FEC_BatchCaseHandlingImportRow>> rowsByCaseForFieldUpdate
    ) {
        if (pendingCaseFieldUpdatesById == null || pendingCaseFieldUpdatesById.isEmpty()) {
            return;
        }
        List<Case> toUpdate = new List<Case>(pendingCaseFieldUpdatesById.values());
        Database.SaveResult[] saveResults = Database.update(toUpdate, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            if (saveResults[i].isSuccess()) {
                continue;
            }
            Id failedCaseId = toUpdate[i].Id;
            String message = saveResults[i].getErrors().isEmpty() ? null : saveResults[i].getErrors()[0].getMessage();
            if (rowsByCaseForFieldUpdate != null && rowsByCaseForFieldUpdate.containsKey(failedCaseId)) {
                for (FEC_BatchCaseHandlingImportRow rr : rowsByCaseForFieldUpdate.get(failedCaseId)) {
                    rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                    rr.errors = appendError(rr.errors, message);
                }
            }
        }
    }

    private static String resolvePicklistValue(
        String caseFieldApi,
        String userInput,
        Map<String, Map<String, String>> picklistValueByNormByField
    ) {
        return FEC_BatchCaseHandlingPicklistResolver.resolveApiValue(
            caseFieldApi,
            userInput,
            picklistValueByNormByField
        );
    }

    private static String resolvePicklistValueForApply(
        FEC_BatchCaseHandlingImportRow rr,
        String caseFieldApi,
        String userInput,
        Map<String, Map<String, String>> picklistValueByNormByField
    ) {
        String cached = readResolvedPicklistApiValue(rr, caseFieldApi);
        if (String.isNotBlank(cached)) {
            return cached;
        }
        return resolvePicklistValue(caseFieldApi, userInput, picklistValueByNormByField);
    }

    private static String normalizeToken(String value) {
        return FEC_BatchCaseHandlingPicklistResolver.normalizeToken(value);
    }

    private static String pickRowString(Map<String, Object> row, List<String> normalizedKeys) {
        Map<String, String> flat = new Map<String, String>();
        for (String k : row.keySet()) {
            String nk = k == null ? FEC_ConstantCommon.STR_EMPTY : k.replaceAll('\\s+', '').toLowerCase();
            if (String.isNotBlank(nk)) {
                Object v = row.get(k);
                flat.put(nk, v == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(v).trim());
            }
        }
        for (String want : normalizedKeys) {
            if (flat.containsKey(want)) {
                return flat.get(want);
            }
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static List<String> pickRowStringList(Map<String, Object> row, String keyName) {
        List<String> out = new List<String>();
        if (row == null || String.isBlank(keyName)) {
            return out;
        }
        Object raw = row.get(keyName);
        // 28/05/2026 17:45 linhdev - đọc originalHeaders/originalCells không phân biệt hoa thường key JSON
        if (raw == null) {
            String want = keyName.replaceAll('\\s+', '').toLowerCase();
            for (String k : row.keySet()) {
                String nk = k == null ? FEC_ConstantCommon.STR_EMPTY : k.replaceAll('\\s+', '').toLowerCase();
                if (want.equals(nk)) {
                    raw = row.get(k);
                    break;
                }
            }
        }
        if (raw == null || !(raw instanceof List<Object>)) {
            return out;
        }
        for (Object val : (List<Object>) raw) {
            out.add(val == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(val));
        }
        return out;
    }

    private static List<Integer> pickRowIntegerList(Map<String, Object> row, String keyName) {
        List<Integer> out = new List<Integer>();
        if (row == null || String.isBlank(keyName)) {
            return out;
        }
        Object raw = row.get(keyName);
        if (raw == null) {
            String want = keyName.replaceAll('\\s+', '').toLowerCase();
            for (String k : row.keySet()) {
                String nk = k == null ? FEC_ConstantCommon.STR_EMPTY : k.replaceAll('\\s+', '').toLowerCase();
                if (want.equals(nk)) {
                    raw = row.get(k);
                    break;
                }
            }
        }
        if (raw == null || !(raw instanceof List<Object>)) {
            return out;
        }
        for (Object val : (List<Object>) raw) {
            if (val == null) {
                out.add(null);
                continue;
            }
            try {
                out.add(Integer.valueOf(String.valueOf(val).trim()));
            } catch (Exception ex) {
                out.add(null);
            }
        }
        return out;
    }

    private static Integer pickRowInteger(Map<String, Object> row, String keyName) {
        if (row == null || String.isBlank(keyName)) {
            return null;
        }
        Object raw = row.get(keyName);
        // 28/05/2026 17:45 linhdev - đọc originalHeaderRowIndex không phân biệt hoa thường key JSON
        if (raw == null) {
            String want = keyName.replaceAll('\\s+', '').toLowerCase();
            for (String k : row.keySet()) {
                String nk = k == null ? FEC_ConstantCommon.STR_EMPTY : k.replaceAll('\\s+', '').toLowerCase();
                if (want.equals(nk)) {
                    raw = row.get(k);
                    break;
                }
            }
        }
        if (raw == null) {
            return null;
        }
        String text = String.valueOf(raw).trim();
        if (String.isBlank(text)) {
            return null;
        }
        try {
            return Integer.valueOf(text);
        } catch (Exception ex) {
            return null;
        }
    }

    private static String remarksToJson(List<FEC_Case_Remarks__c> remarks) {
        if (remarks == null || remarks.isEmpty()) {
            return null;
        }
        return JSON.serialize(remarks);
    }

    private static List<FEC_Case_Remarks__c> jsonToCaseRemarks(String jsonStr) {
        if (String.isBlank(jsonStr)) {
            return new List<FEC_Case_Remarks__c>();
        }
        return (List<FEC_Case_Remarks__c>) JSON.deserialize(
            jsonStr,
            List<FEC_Case_Remarks__c>.class
        );
    }

    // 30/05/2026 21:00 linhdev - Thiếu / vượt quá 32,767 ký tự Inputted Remarks (giới hạn ô Excel)
    @TestVisible
    private static void addInputtedRemarksValidationErrors(
        List<String> errs,
        String inputtedRemarks,
        Integer charLength
    ) {
        if (errs == null) {
            return;
        }
        Integer effectiveLen = resolveEffectiveInputtedRemarksLength(inputtedRemarks, charLength);
        if (isInputtedRemarksOverMaxLength(effectiveLen)) {
            addImportError(errs, System.Label.FEC_Batch_Case_Handling_Import_Err_Remark_Too_Long);
            return;
        }
        if (String.isBlank(inputtedRemarks) && (effectiveLen == null || effectiveLen == 0)) {
            addImportError(errs, System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Remark);
        }
    }

    // 30/05/2026 18:30 linhdev - đồng bộ remark từ field JSON + originalCells (payload LWC có thể thiếu chuỗi dài)
    @TestVisible
    private static String resolveInputtedRemarksValue(Map<String, Object> row, FEC_BatchCaseHandlingImportRow rr) {
        String fromField = pickRowString(
            row,
            new List<String>{ 'inputtedremarks', 'inputtedremark', 'inputremarks', 'inputremark' }
        );
        String fromOriginal = extractRemarkFromOriginalCells(rr);
        return pickLongerRemarkText(fromField, fromOriginal);
    }

    @TestVisible
    private static Integer resolveInputtedRemarksCharLength(
        Map<String, Object> row,
        FEC_BatchCaseHandlingImportRow rr
    ) {
        Integer reportedLen = pickRowInteger(row, 'inputtedRemarksCharLength');
        String fromField = pickRowString(
            row,
            new List<String>{ 'inputtedremarks', 'inputtedremark', 'inputremarks', 'inputremark' }
        );
        String fromOriginal = extractRemarkFromOriginalCells(rr);
        Integer maxLen = String.isBlank(fromField) ? 0 : fromField.length();
        Integer originalLen = String.isBlank(fromOriginal) ? 0 : fromOriginal.length();
        if (originalLen > maxLen) {
            maxLen = originalLen;
        }
        if (reportedLen != null && reportedLen > maxLen) {
            maxLen = reportedLen;
        }
        return maxLen == 0 ? null : maxLen;
    }

    @TestVisible
    private static String extractRemarkFromOriginalCells(FEC_BatchCaseHandlingImportRow rr) {
        if (rr == null || rr.originalHeaders == null || rr.originalCells == null || rr.originalCells.isEmpty()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Integer remarkIdx = findRemarkHeaderIndex(rr.originalHeaders);
        if (remarkIdx < 0 || remarkIdx >= rr.originalCells.size()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String cell = rr.originalCells[remarkIdx];
        return cell == null ? FEC_ConstantCommon.STR_EMPTY : cell;
    }

    private static String pickLongerRemarkText(String first, String second) {
        String a = first == null ? FEC_ConstantCommon.STR_EMPTY : first;
        String b = second == null ? FEC_ConstantCommon.STR_EMPTY : second;
        if (String.isBlank(a)) {
            return b;
        }
        if (String.isBlank(b)) {
            return a;
        }
        return b.length() > a.length() ? b : a;
    }

    private static Integer resolveEffectiveInputtedRemarksLength(String inputtedRemarks, Integer charLength) {
        Integer textLen = String.isBlank(inputtedRemarks) ? 0 : inputtedRemarks.length();
        if (charLength == null || charLength < textLen) {
            return textLen == 0 ? charLength : textLen;
        }
        return charLength;
    }

    // 30/05/2026 21:00 linhdev - giới hạn Inputted Remarks 32,767 ký tự (giới hạn ô Excel)
    @TestVisible
    private static Boolean isInputtedRemarksOverMaxLength(String inputtedRemarks) {
        return isInputtedRemarksOverMaxLength(
            String.isBlank(inputtedRemarks) ? null : inputtedRemarks.length()
        );
    }

    // 01/06/2026 14:00 linhdev - >= 32,767: Excel cắt ngầm nội dung dài hơn; ô đạt max = không hợp lệ
    @TestVisible
    private static Boolean isInputtedRemarksOverMaxLength(Integer charLength) {
        return charLength != null && charLength >= REMARK_MAX_LEN;
    }

    private static void addImportError(List<String> errs, String message) {
        if (errs == null || String.isBlank(message)) {
            return;
        }
        errs.add(localizeImportResultError(message));
    }

    private static String joinImportErrors(List<String> errs) {
        if (errs == null || errs.isEmpty()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        List<String> parts = new List<String>();
        for (String err : errs) {
            if (String.isNotBlank(err)) {
                parts.add(localizeImportResultError(err));
            }
        }
        return parts.isEmpty() ? FEC_ConstantCommon.STR_EMPTY : String.join(parts, IMPORT_ERROR_SEPARATOR);
    }

    private static String appendError(String current, String incoming) {
        if (String.isBlank(incoming)) {
            return current;
        }
        String localizedIncoming = localizeImportResultError(incoming);
        if (String.isBlank(current)) {
            return localizedIncoming;
        }
        return current + IMPORT_ERROR_SEPARATOR + localizedIncoming;
    }

    // 05/06/2026 16:00 linhdev - chuẩn hóa __Errors Export Result sang tiếng Việt
    public static String localizeImportResultErrors(String combinedErrors) {
        if (String.isBlank(combinedErrors)) {
            return combinedErrors;
        }
        if (!combinedErrors.contains(IMPORT_ERROR_SEPARATOR)) {
            return localizeImportResultError(combinedErrors);
        }
        List<String> parts = combinedErrors.split(IMPORT_ERROR_SEPARATOR);
        List<String> localizedParts = new List<String>();
        for (String part : parts) {
            if (String.isNotBlank(part)) {
                localizedParts.add(localizeImportResultError(part));
            }
        }
        return localizedParts.isEmpty() ? FEC_ConstantCommon.STR_EMPTY : String.join(localizedParts, IMPORT_ERROR_SEPARATOR);
    }

    public static String localizeImportResultError(String message) {
        if (String.isBlank(message)) {
            return message;
        }
        String trimmed = message.trim();
        if (isGenericBatchImportFailureMessage(trimmed)) {
            return trimmed;
        }
        String mapped = mapKnownEnglishImportResultError(trimmed);
        if (String.isNotBlank(mapped)) {
            return mapped;
        }
        if (isLikelyVietnameseImportResultMessage(trimmed)) {
            return trimmed;
        }
        return formatGenericImportFailureWithReason(trimmed);
    }

    private static String formatGenericImportFailureWithReason(String rawReason) {
        String reason = normalizeUnknownImportReason(rawReason);
        if (String.isBlank(reason)) {
            return ERR_GENERIC_APPLY;
        }
        return ERR_GENERIC_APPLY_REASON_PREFIX + reason;
    }

    private static String normalizeUnknownImportReason(String rawReason) {
        if (String.isBlank(rawReason)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String normalized = rawReason.trim().replace('\r\n', ' ').replace('\n', ' ').replace('\r', ' ');
        normalized = normalized.replaceAll('\\s+', ' ');
        if (normalized.length() <= IMPORT_RESULT_UNKNOWN_REASON_MAX_LEN) {
            return normalized;
        }
        return normalized.substring(0, IMPORT_RESULT_UNKNOWN_REASON_MAX_LEN) + '...';
    }

    private static String buildImportRowReference(FEC_BatchCaseHandlingImportRow row) {
        if (row == null) {
            return ERR_IMPORT_ROW_REF_EMPTY;
        }
        List<String> parts = new List<String>();
        if (row.originalDataRowIndex != null && row.originalDataRowIndex >= 0) {
            parts.add(ERR_IMPORT_ROW_REF_EXCEL_PREFIX + String.valueOf(row.originalDataRowIndex + 1));
        }
        String caseIdToken = resolveBusinessCaseIdTokenForReference(row);
        if (String.isNotBlank(caseIdToken)) {
            parts.add(ERR_IMPORT_ROW_REF_CASE_ID_PREFIX + caseIdToken);
        }
        if (parts.isEmpty()) {
            return ERR_IMPORT_ROW_REF_EMPTY;
        }
        return '[' + String.join(parts, ', ') + ']';
    }

    private static String resolveBusinessCaseIdTokenForReference(FEC_BatchCaseHandlingImportRow row) {
        if (row == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (String.isNotBlank(row.caseIdSearch)) {
            return row.caseIdSearch.trim();
        }
        String originalCaseId = cellTextAtOriginalLayout(row, findCaseIdHeaderIndex(row.originalHeaders));
        if (String.isNotBlank(originalCaseId)) {
            return originalCaseId.trim();
        }
        if (isLikelyBusinessCaseIdToken(row.recordId)) {
            return row.recordId.trim();
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static Boolean isLikelyBusinessCaseIdToken(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        String trimmed = value.trim();
        if (trimmed.startsWith('500')) {
            return false;
        }
        return Pattern.matches('^[A-Za-z]-.+$', trimmed);
    }

    private static String resolveExceptionDetail(Exception ex) {
        if (ex == null) {
            return ERR_IMPORT_EXCEPTION_NO_DETAIL;
        }
        if (String.isNotBlank(ex.getMessage())) {
            return sanitizeImportExceptionMessage(ex.getMessage().trim());
        }
        String typeName = ex.getTypeName();
        if (String.isNotBlank(typeName)) {
            return ERR_IMPORT_EXCEPTION_TYPE_PREFIX + typeName + ERR_IMPORT_EXCEPTION_TYPE_NO_MESSAGE;
        }
        return ERR_IMPORT_EXCEPTION_NO_DETAIL;
    }

    private static String sanitizeImportExceptionMessage(String message) {
        if (String.isBlank(message)) {
            return ERR_IMPORT_EXCEPTION_NO_DETAIL;
        }
        String candidate = stripTechnicalExceptionPrefix(message);
        return localizeImportResultError(candidate);
    }

    private static String stripTechnicalExceptionPrefix(String message) {
        if (String.isBlank(message)) {
            return message;
        }
        Integer splitPos = message.indexOf(':');
        if (splitPos <= 0 || splitPos >= message.length() - 1) {
            return message;
        }
        String prefix = message.substring(0, splitPos).trim();
        if (!isTechnicalExceptionPrefix(prefix)) {
            return message;
        }
        String suffix = message.substring(splitPos + 1).trim();
        return String.isBlank(suffix) ? message : suffix;
    }

    private static Boolean isTechnicalExceptionPrefix(String prefix) {
        if (String.isBlank(prefix)) {
            return false;
        }
        String normalized = prefix.toLowerCase();
        return normalized.contains('exception')
            || normalized.contains('error')
            || normalized.contains('field_custom_validation_exception')
            || normalized.contains('system.')
            || normalized.contains('dml')
            || normalized.contains('query');
    }

    @TestVisible
    private static String formatImportRowValidateException(
        FEC_BatchCaseHandlingImportRow row,
        Exception ex
    ) {
        return buildImportRowReference(row) +
            ERR_IMPORT_VALIDATE_EXCEPTION_SUFFIX +
            resolveExceptionDetail(ex);
    }

    private static String formatImportRowApplyFailureWithoutDetail(FEC_BatchCaseHandlingImportRow row) {
        String rowRef = buildImportRowReference(row);
        List<String> hints = new List<String>();
        if (String.isNotBlank(row == null ? null : row.routingAction)) {
            hints.add(
                ERR_IMPORT_ROUTING_ACTION_LABEL_PREFIX +
                    row.routingAction.trim() +
                    ERR_IMPORT_ROUTING_ACTION_LABEL_SUFFIX
            );
        } else if (row != null && String.isNotBlank(row.assignmentRoutingAction)) {
            hints.add(
                ERR_IMPORT_ASSIGNMENT_ROUTING_ACTION_LABEL_PREFIX +
                    row.assignmentRoutingAction.trim() +
                    ERR_IMPORT_ROUTING_ACTION_LABEL_SUFFIX
            );
        }
        String hintSuffix = hints.isEmpty()
            ? ERR_IMPORT_APPLY_FAILURE_HINT
            : ERR_IMPORT_APPLY_FAILURE_HINT_CHECK_PREFIX +
                String.join(hints, ', ') +
                ERR_IMPORT_APPLY_FAILURE_HINT_CHECK_SUFFIX;
        return rowRef + ERR_IMPORT_APPLY_FAILURE_SUFFIX + hintSuffix;
    }

    private static String mapKnownEnglishImportResultError(String trimmed) {
        String norm = trimmed.toLowerCase();
        if (IMPORT_RESULT_ERROR_EN_TO_VI.containsKey(norm)) {
            return IMPORT_RESULT_ERROR_EN_TO_VI.get(norm);
        }
        // 05/06/2026 17:00 linhdev - TEMPLATE_MISMATCH → template mismatch (1 map key duy nhất)
        String normSpaced = norm.replace('_', ' ');
        if (normSpaced != norm && IMPORT_RESULT_ERROR_EN_TO_VI.containsKey(normSpaced)) {
            return IMPORT_RESULT_ERROR_EN_TO_VI.get(normSpaced);
        }
        if (norm.endsWith(IMPORT_RESULT_EN_SUFFIX_INVALID)) {
            String token = trimmed.substring(0, trimmed.length() - IMPORT_RESULT_EN_SUFFIX_INVALID.length()).trim();
            return String.isBlank(token) ? ERR_GENERIC_APPLY : token + ERR_IMPORT_RESULT_SUFFIX_INVALID;
        }
        if (norm.endsWith(IMPORT_RESULT_EN_SUFFIX_NOT_FOUND)) {
            String token = trimmed.substring(0, trimmed.length() - IMPORT_RESULT_EN_SUFFIX_NOT_FOUND.length()).trim();
            return String.isBlank(token)
                ? ERR_GENERIC_APPLY
                : ERR_IMPORT_RESULT_PREFIX_NOT_FOUND + token + ERR_IMPORT_RESULT_SUFFIX_NOT_FOUND;
        }
        if (norm.contains('insufficient access')) {
            return ERR_IMPORT_RESULT_INSUFFICIENT_ACCESS;
        }
        if (norm.contains('unable to lock') || norm.contains('unable_to_lock_row')) {
            return ERR_IMPORT_RESULT_UNABLE_TO_LOCK;
        }
        if (norm.contains('entity is deleted')) {
            return ERR_IMPORT_RESULT_ENTITY_DELETED;
        }
        if (norm.contains('field_custom_validation_exception')) {
            return ERR_IMPORT_RESULT_VALIDATION_FAILED;
        }
        if (isTechnicalImportResultMessage(norm)) {
            return ERR_IMPORT_QUEUE_LIMIT_EXCEEDED;
        }
        return null;
    }

    private static Boolean isTechnicalImportResultMessage(String normalizedMessage) {
        if (String.isBlank(normalizedMessage)) {
            return false;
        }
        for (String keyword : IMPORT_RESULT_TECHNICAL_ERROR_KEYWORDS) {
            if (normalizedMessage.contains(keyword)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean isLikelyVietnameseImportResultMessage(String trimmed) {
        if (containsVietnameseDiacritic(trimmed)) {
            return true;
        }
        String norm = trimmed.toLowerCase();
        List<String> vietnamesePrefixes = new List<String>{
            'thiếu ',
            'không ',
            'giá trị ',
            'người dùng ',
            'cùng ',
            'đã ',
            'trường ',
            'record id ',
            'case id ',
            'assignment id ',
            'routing ',
            'import ',
            'template ',
            'tên file ',
            'vui lòng ',
            'một hoặc ',
            'bạn ',
            'chỉ ',
            'cập nhật ',
            'quy trình ',
            'tệp đính kèm ',
            'dữ liệu '
        };
        for (String prefix : vietnamesePrefixes) {
            if (norm.startsWith(prefix)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean containsVietnameseDiacritic(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        String vietnameseChars = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
        String lower = value.toLowerCase();
        for (Integer i = 0; i < vietnameseChars.length(); i++) {
            if (lower.contains(vietnameseChars.substring(i, i + 1))) {
                return true;
            }
        }
        return false;
    }

    private static String ensureResultContentTitle(String fileName) {
        String title = FEC_BatchCaseHandlingSObjectUtil.removeFileExtension(fileName);
        if (String.isBlank(title) || title.toLowerCase().endsWith('_result')) {
            return title;
        }
        return title + '_Result';
    }

    private class RemarkDraftUpdateItem {
        public FEC_BatchCaseHandlingImportRow row;
        public Id caseId;
        public Id assignmentId;
        public String inputtedRemarks;
    }

    //PhongBT 29/05/26: Payload 1 dòng import — Assignment Route To (vd Route to CS QC - Quality Control Mailbox).
    private class AssignmentRouteToUpdateItem {
        public FEC_BatchCaseHandlingImportRow row;
        public Id assignmentId;
        public String queueToken;
        public String routeTeamHint;
        public String routeQueueHint;
        public Datetime submittedOn;
    }
}