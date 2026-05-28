public without sharing class FEC_BatchCaseHandlingImportService {

    private static final Integer REMARK_MAX_LEN = 32768;
    private static final String USER_GROUP_OM = 'OM';
    private static final String BUSINESS_PROCESS_PHONE_UPDATE = 'Phone Update';
    private static final String LABEL_CS_D2C_ASSESSMENT = 'CS D2C đánh giá yêu cầu';
    private static final String LABEL_CS_SUPPORT_ASSESSMENT = 'CS Support đánh giá yêu cầu';
    private static final String LABEL_RISK_LEVEL = 'Mức độ rủi ro';
    private static final String LABEL_REQUIRED_ACTION = 'Hành động cần thiết';
    private static final String RESULT_COL_STATUS = '__Status';
    private static final String RESULT_COL_ERRORS = '__Errors';
    private static final String IMPORT_ERROR_SEPARATOR = ',\n';
    private static final String ERR_NOT_OWNER = 'Người dùng không phải chủ sở hữu Case';
    private static final String ERR_FIELD_NOT_CONFIGURED = 'Trường dữ liệu chưa được thiết lập trong Master Data Setting';
    private static final String ERR_MISSING_CS_D2C_ASSESSMENT = 'Thiếu giá trị CS D2C đánh giá yêu cầu';
    private static final String ERR_MISSING_RISK_LEVEL = 'Thiếu giá trị Mức độ rủi ro';
    private static final String ERR_MISSING_REQUIRED_ACTION = 'Thiếu giá trị Hành động cần thiết';
    private static final String ERR_INVALID_CS_D2C_ASSESSMENT = 'Giá trị CS D2C đánh giá yêu cầu không tồn tại trong Datagroup.';
    private static final String ERR_INVALID_RISK_LEVEL = 'Giá trị Mức độ rủi ro không tồn tại trong Datagroup.';
    private static final String ERR_INVALID_REQUIRED_ACTION = 'Giá trị Hành động cần thiết không tồn tại trong Datagroup.';
    private static final String ERR_IMPORT_PROCESSING_TIMEOUT = 'Import quá thời gian xử lý (quá 1 giờ). Vui lòng thử lại.';
    private static final String ERR_ROUTING_CONFLICT = 'Cùng Case ID có nhiều Routing Action khác nhau trong file import.';
    private static final String ERR_TEMPLATE_FILE_MISMATCH = 'Tên file không khớp template Bulk Actions của quy trình và nhóm người dùng.';
    private static final String LABEL_PAYMENT_CONTRACT_ASSESSMENT = 'Payment đánh giá yêu cầu đóng hợp đồng';
    private static final String LABEL_CP_ASSESSMENT = 'CP đánh giá yêu cầu';
    private static final String ERR_MISSING_PAYMENT_ASSESSMENT = 'Thiếu giá trị Payment đánh giá yêu cầu đóng hợp đồng';
    private static final String ERR_INVALID_PAYMENT_ASSESSMENT = 'Giá trị Payment đánh giá yêu cầu đóng hợp đồng không tồn tại trong Datagroup.';
    private static final String ERR_MISSING_CP_ASSESSMENT = 'Thiếu giá trị CP đánh giá yêu cầu';
    private static final String ERR_INVALID_CP_ASSESSMENT = 'Giá trị CP đánh giá yêu cầu không tồn tại trong Datagroup.';
    private class RoutingParseResult {
        public String methodKey;
        public String decision;
        public String routeTeamHint;
        public String routeQueueHint;
    }

    private static final String BATCH_OBJECT_API_NAME = 'FEC_Batch_Case_Handling__c';
    @TestVisible
    private static final Integer IMPORT_PROCESSING_TIMEOUT_HOURS = 1;
    // 27/05/2026 22:15 linhdev - import nhỏ (vd. Card Replacement 1 case) xử lý sync thay vì queueable để tránh Processing timeout 1 giờ
    @TestVisible
    private static final Integer SYNC_IMPORT_MAX_APPLICABLE_ROWS = 10;
    private static Map<String, Map<String, String>> routeParamsCacheByKey = new Map<String, Map<String, String>>();
    private static Map<String, String> revertActionIdCacheByStage = new Map<String, String>();
    private static Map<String, String> queueIdCacheByToken = new Map<String, String>();
    @TestVisible
    private static Boolean batchImportApplyInProgress = false;

    public static Boolean isBatchImportApplyInProgress() {
        return batchImportApplyInProgress == true;
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
        Integer applicableCount = countApplicableImportRows(rows);
        return applicableCount > 0 && applicableCount <= SYNC_IMPORT_MAX_APPLICABLE_ROWS;
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
            applyCaseHandlingUpdates(applicableRows, cofOrGsr == true);
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
        Integer failedCount = countFailedImportRows(rowResults);
        Integer totalCount = rowResults == null ? 0 : rowResults.size();
        String failureReason = FEC_ConstantCommon.STR_EMPTY;
        String finalStatus = 'Processed';
        if (totalCount == 0) {
            finalStatus = 'Failure';
            failureReason = System.Label.FEC_BCH_RequireFile;
        } else if (failedCount == totalCount) {
            finalStatus = 'Failure';
            failureReason = System.Label.FEC_BCH_Import_Rows_Invalid;
        }
        putBatchStatusAndResult(fieldMap, batchRow, finalStatus);
        putBatchCountFields(
            fieldMap,
            batchRow,
            totalCount,
            totalCount - failedCount < 0 ? 0 : totalCount - failedCount,
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
        Datetime cutoff = Datetime.now().addHours(-IMPORT_PROCESSING_TIMEOUT_HOURS);
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
            failBatchImportRecord((Id) staleRow.get('Id'), timeoutReason, null);
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
        List<String> selectParts = new List<String>{ 'Id', statusField, 'CreatedDate' };
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, uploadedOnField);
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
        return startedOn < Datetime.now().addHours(-IMPORT_PROCESSING_TIMEOUT_HOURS);
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
        String failureReason = String.isBlank(reason) ? System.Label.FEC_BCH_ImportFailed : reason;
        putBatchStatusAndResult(fieldMap, batchRow, 'Failure');
        Integer totalCount = rowResults == null ? 0 : rowResults.size();
        if (totalCount > 0) {
            putBatchCountFields(fieldMap, batchRow, totalCount, 0, totalCount);
        } else {
            applyExistingBatchFailCounts(fieldMap, batchRow, batchRecordId);
        }
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(
            fieldMap,
            batchRow,
            new List<String>{ 'FEC_Failure_Reason__c' },
            failureReason
        );
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
        if (batchRecordId == null) {
            return;
        }
        try {
            String fileName = resolveBatchResultFileName(batchRecordId);
            List<List<String>> sheetRows = buildBatchResultSheetRows(
                rowResults,
                batchFailureReason,
                isCofOrGsrImportRows(rowResults)
            );
            Blob workbookBlob = FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(sheetRows);
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

    private static List<List<String>> buildBatchResultSheetRows(
        List<FEC_BatchCaseHandlingImportRow> rowResults,
        String batchFailureReason,
        Boolean cofOrGsr
    ) {
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
                cols.add(rowValue(row.errors));
                sheetRows.add(cols);
            }
        } else if (String.isNotBlank(batchFailureReason)) {
            Integer totalCols = cofOrGsr ? 7 : 5;
            List<String> failureRow = new List<String>{ rowValue(batchFailureReason) };
            for (Integer i = 1; i < totalCols; i++) {
                failureRow.add(FEC_ConstantCommon.STR_EMPTY);
            }
            sheetRows.add(failureRow);
        } else {
            return null;
        }
        return sheetRows;
    }

    private static String rowValue(String value) {
        return value == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(value);
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

    public static List<FEC_BatchCaseHandlingImportRow> validateCaseHandlingImportRows(List<Object> inputRows, Boolean cofOrGsr) {
        List<FEC_BatchCaseHandlingImportRow> output = new List<FEC_BatchCaseHandlingImportRow>();
        List<String> searchKeys = new List<String>();
        for (Object rowObj : inputRows) {
            if (!(rowObj instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> row = (Map<String, Object>) rowObj;
            FEC_BatchCaseHandlingImportRow rr = new FEC_BatchCaseHandlingImportRow();
            rr.caseIdSearch = pickRowString(row, new List<String>{ 'caseidsearch', 'caseid' });
            rr.routingAction = pickRowString(row, new List<String>{ 'routingaction' });
            rr.inputtedRemarks = pickRowString(row, new List<String>{ 'inputtedremarks', 'remark', 'remarks' });
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
            Boolean rowEmpty =
                String.isBlank(rr.caseIdSearch) &&
                String.isBlank(rr.routingAction) &&
                String.isBlank(rr.inputtedRemarks) &&
                String.isBlank(rr.assignmentId) &&
                String.isBlank(rr.assignmentRoutingAction) &&
                String.isBlank(rr.csD2CAssessmentType) &&
                String.isBlank(rr.csSupportAssessment) &&
                String.isBlank(rr.riskLevel) &&
                String.isBlank(rr.requiredAction) &&
                String.isBlank(rr.classificationByCS) &&
                String.isBlank(rr.evaluationByCS) &&
                String.isBlank(rr.finalProduct) &&
                String.isBlank(rr.paymentContractAssessment) &&
                String.isBlank(rr.cpAssessment);
            if (rowEmpty) {
                continue;
            }
            rr.recordId = FEC_ConstantCommon.STR_EMPTY;
            rr.status = System.Label.FEC_Operation_Success;
            rr.errors = FEC_ConstantCommon.STR_EMPTY;
            output.add(rr);
            if (String.isNotBlank(rr.caseIdSearch)) {
                searchKeys.add(rr.caseIdSearch);
            }
        }

        Map<String, Case> caseBySearch = new Map<String, Case>();
        if (!searchKeys.isEmpty()) {
            for (Case c : [
                SELECT Id, IsClosed, FEC_ID_Search__c, OwnerId, FEC_Current_Case_Stage__c, FEC_Business_Process__r.FEC_Code__c, FEC_Current_Case_Stage__r.FEC_Business_Process__r.FEC_Code__c
                FROM Case
                WHERE FEC_ID_Search__c IN :searchKeys
                LIMIT 5000
            ]) {
                if (c.FEC_ID_Search__c != null) {
                    caseBySearch.put(c.FEC_ID_Search__c, c);
                }
            }
        }

        Set<String> assignmentNames = new Set<String>();
        Set<Id> assignmentRecordIds = new Set<Id>();
        for (FEC_BatchCaseHandlingImportRow rr : output) {
            if (!cofOrGsr || String.isBlank(rr.assignmentId)) {
                continue;
            }
            collectAssignmentLookupKeys(rr.assignmentId, assignmentNames, assignmentRecordIds);
        }
        Map<String, FEC_Assignment__c> assignmentByName = loadAssignmentsByName(assignmentNames);
        Map<Id, FEC_Assignment__c> assignmentByRecordId = loadAssignmentsByRecordId(assignmentRecordIds);

        Id currentUserId = UserInfo.getUserId();
        String currentUserGroup = null;
        List<User> importUsers = [
            SELECT FEC_User_Group__c
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ];
        if (!importUsers.isEmpty()) {
            currentUserGroup = importUsers[0].FEC_User_Group__c;
        }
        Set<Id> stageIds = new Set<Id>();
        for (Case c : caseBySearch.values()) {
            if (c != null && c.FEC_Current_Case_Stage__c != null) {
                stageIds.add(c.FEC_Current_Case_Stage__c);
            }
        }
        Map<Id, Set<String>> configuredLabelsByStage = loadConfiguredLabelsByStage(stageIds);
        FEC_BatchCaseHandlingPicklistResolver.clearCache();
        FEC_BCH_ImportRoutingResolver.clearCache();
        FEC_BCH_ImportRoutingResolver.preloadStageScreens(stageIds, currentUserGroup);
        Map<String, Map<String, String>> picklistValueByNormByField =
            FEC_BatchCaseHandlingPicklistResolver.buildNormalizedToApiValueByField(
                importPicklistFieldApis()
            );

        Set<String> seenCaseSearch = new Set<String>();
        Map<String, String> routingSignatureByCaseSearch = new Map<String, String>();
        for (FEC_BatchCaseHandlingImportRow rr : output) {
            List<String> errs = new List<String>();
            Case matched = null;
            try {
            if (String.isBlank(rr.caseIdSearch)) {
                addImportError(errs, System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Case_Id);
            }
            matched = String.isNotBlank(rr.caseIdSearch) ? caseBySearch.get(rr.caseIdSearch) : null;
            if (String.isNotBlank(rr.caseIdSearch) && matched == null) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Case_Id_Not_Found);
            } else if (matched != null && matched.IsClosed) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Case_Closed);
            } else if (matched != null && matched.OwnerId != currentUserId) {
                errs.add(ERR_NOT_OWNER);
            }
            if (String.isNotBlank(rr.caseIdSearch)) {
                if (seenCaseSearch.contains(rr.caseIdSearch)) {
                    errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Duplicate_Case_Id);
                } else {
                    seenCaseSearch.add(rr.caseIdSearch);
                }
                String routingSig = buildRoutingSignature(rr, cofOrGsr);
                if (routingSignatureByCaseSearch.containsKey(rr.caseIdSearch)) {
                    if (routingSignatureByCaseSearch.get(rr.caseIdSearch) != routingSig) {
                        errs.add(ERR_ROUTING_CONFLICT);
                    }
                } else if (String.isNotBlank(routingSig)) {
                    routingSignatureByCaseSearch.put(rr.caseIdSearch, routingSig);
                }
            }

            if (matched != null && cofOrGsr != true) {
                FEC_BatchCaseHandlingImportProfile.ImportScope importScope =
                    FEC_BatchCaseHandlingImportProfile.resolveForCase(
                        resolveCaseBusinessProcessCode(matched),
                        currentUserGroup
                    );
                if (importScope != null && importScope.allowed == false) {
                    addImportError(errs, importScope.errorMessage);
                } else if (importScope != null) {
                    errs.addAll(
                        validateScopeFieldsForCase(
                            rr,
                            matched,
                            importScope,
                            configuredLabelsByStage,
                            picklistValueByNormByField
                        )
                    );
                }
            }

            errs.addAll(validateResolvedRoutingForRow(rr, matched, cofOrGsr));

            if (cofOrGsr) {
                Boolean hasAssignment = String.isNotBlank(rr.assignmentId);
                if (hasAssignment) {
                    FEC_Assignment__c asg = resolveAssignmentForImport(
                        rr.assignmentId,
                        assignmentByName,
                        assignmentByRecordId
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
                        if (caseMethod == null) {
                            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid);
                        } else if (!isResolvedOrRejectCaseRouting(caseMethod)) {
                            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Resolve_Only);
                        }
                    }
                    if (String.isNotBlank(rr.assignmentRoutingAction) && String.isBlank(rr.actionButtonId)) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Invalid);
                    }
                } else {
                    if (String.isBlank(rr.routingAction) && String.isBlank(rr.assignmentRoutingAction)) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Action);
                    } else if (String.isNotBlank(rr.routingAction) && String.isBlank(rr.actionButtonId)) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid);
                    } else if (
                        String.isBlank(rr.routingAction) &&
                        String.isNotBlank(rr.assignmentRoutingAction) &&
                        String.isBlank(rr.actionButtonId)
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
                if (String.isBlank(rr.routingAction)) {
                    errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Action);
                } else if (String.isBlank(rr.actionButtonId)) {
                    errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid);
                }
            }

            if (String.isBlank(rr.inputtedRemarks)) {
                addImportError(errs, System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Remark);
            } else if (rr.inputtedRemarks.length() > REMARK_MAX_LEN) {
                addImportError(errs, System.Label.FEC_Batch_Case_Handling_Import_Err_Remark_Too_Long);
            }
            } catch (Exception rowEx) {
                addImportError(
                    errs,
                    String.isNotBlank(rowEx.getMessage())
                        ? rowEx.getMessage()
                        : System.Label.FEC_BCH_ImportFailed
                );
            }

            if (!errs.isEmpty()) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = joinImportErrors(errs);
            } else {
                rr.recordId = matched == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(matched.Id);
            }
        }
        return output;
    }

    public static void applyCaseHandlingUpdates(List<FEC_BatchCaseHandlingImportRow> rows, Boolean cofOrGsr) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        batchImportApplyInProgress = true;
        try {
            applyCaseHandlingUpdatesCore(rows, cofOrGsr);
        } finally {
            batchImportApplyInProgress = false;
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
                SELECT Id, FEC_Current_Case_Stage__c
                FROM Case
                WHERE Id IN :caseIds
            ]);
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
            String actionLabel = rr.routingAction;
            if (cofOrGsr && String.isBlank(actionLabel)) {
                actionLabel = rr.assignmentRoutingAction;
            }
            Id stageIdForRow = caseLiteById.get(caseId) == null
                ? null
                : caseLiteById.get(caseId).FEC_Current_Case_Stage__c;
            FEC_BCH_ImportRoutingResolver.ResolvedRouting resolvedRouting =
                FEC_BCH_ImportRoutingResolver.resolve(stageIdForRow, actionLabel);
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
            if (routingParsed != null && routingActionRequiresExtraParams(methodKey, routingParsed.decision)) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(
                    rr.errors,
                    System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Requires_Params
                );
                continue;
            }
            try {
                Map<String, String> runParams = new Map<String, String>{ 'caseId' => String.valueOf(caseId) };
                if (routingParsed != null && methodKey == FEC_CaseBusinessService.UPDATEACTION && String.isNotBlank(routingParsed.decision)) {
                    runParams.put('decision', routingParsed.decision);
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
                    if (routeParams == null || String.isBlank(routeParams.get('actionId')) || String.isBlank(routeParams.get('queueId'))) {
                        rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                        rr.errors = appendError(
                            rr.errors,
                            System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Requires_Params
                        );
                        continue;
                    }
                    runParams.put('actionId', routeParams.get('actionId'));
                    runParams.put('queueId', routeParams.get('queueId'));
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
                    if (String.isBlank(revertActionId)) {
                        rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                        rr.errors = appendError(
                            rr.errors,
                            System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Requires_Params
                        );
                        continue;
                    }
                    runParams.put('actionId', revertActionId);
                }
                if (methodKey == FEC_CaseBusinessService.REVERT && String.isNotBlank(rr.routingActionValue)) {
                    runParams.put('routingActionValue', rr.routingActionValue);
                }
                FEC_CaseBusinessService.run(methodKey, runParams);
            } catch (Exception ex) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(rr.errors, ex.getMessage());
                continue;
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
                item.assignmentId = parseAssignmentId(rr.assignmentId, assignmentByName, assignmentByRecordId);
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
        applyDraftRemarksBulk(validRemarkItems, cofOrGsr);
    }

    private static void collectAssignmentLookupKeys(
        String assignmentIdRaw,
        Set<String> assignmentNames,
        Set<Id> assignmentRecordIds
    ) {
        if (String.isBlank(assignmentIdRaw)) {
            return;
        }
        String trimmed = assignmentIdRaw.trim();
        Id recordId = tryParseAssignmentRecordId(trimmed);
        if (recordId != null) {
            assignmentRecordIds.add(recordId);
        } else if (assignmentNames != null) {
            assignmentNames.add(trimmed);
        }
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
        if (String.isBlank(assignmentIdRaw)) {
            return null;
        }
        String trimmed = assignmentIdRaw.trim();
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
        FEC_Assignment__c asg = resolveAssignmentForImport(assignmentIdRaw, assignmentByName, assignmentByRecordId);
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
            'queueId' => queueId
        };
        routeParamsCacheByKey.put(cacheKey, resolved);
        return resolved;
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
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return System.Label.FEC_Operation_Success;
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
        for (FEC_Master_Data_Setting__c row : [
            SELECT FEC_Stage_Name__c, FEC_Field_Label_Name__c
            FROM FEC_Master_Data_Setting__c
            WHERE FEC_Stage_Name__c IN :stageIds
            AND FEC_Field_Label_Name__c IN :new List<String>{
                LABEL_CS_D2C_ASSESSMENT,
                LABEL_CS_SUPPORT_ASSESSMENT,
                LABEL_RISK_LEVEL,
                LABEL_REQUIRED_ACTION,
                LABEL_PAYMENT_CONTRACT_ASSESSMENT,
                LABEL_CP_ASSESSMENT
            }
        ]) {
            if (row.FEC_Stage_Name__c == null || String.isBlank(row.FEC_Field_Label_Name__c)) {
                continue;
            }
            if (!out.containsKey(row.FEC_Stage_Name__c)) {
                out.put(row.FEC_Stage_Name__c, new Set<String>());
            }
            out.get(row.FEC_Stage_Name__c).add(normalizeToken(row.FEC_Field_Label_Name__c));
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
        Id stageId = matched == null ? null : matched.FEC_Current_Case_Stage__c;
        FEC_BCH_ImportRoutingResolver.ResolvedRouting resolved =
            FEC_BCH_ImportRoutingResolver.resolve(stageId, primaryLabel);
        if (resolved == null || String.isBlank(resolved.methodKey)) {
            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid);
            return errs;
        }
        if (resolved.methodKey == FEC_CaseBusinessService.TRANSFER) {
            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid);
            return errs;
        }
        if (FEC_BCH_ImportRoutingResolver.requiresStageScreenMatch(resolved.methodKey) &&
            stageId != null &&
            resolved.matchedStageScreen != true) {
            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid);
            return errs;
        }
        applyResolvedRoutingToRow(rr, resolved);
        if (cofOrGsr == true && String.isNotBlank(rr.routingAction) && String.isNotBlank(rr.assignmentRoutingAction)) {
            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Both_Routing_Actions);
        }
        if (cofOrGsr == true && String.isNotBlank(rr.routingAction)) {
            FEC_BCH_ImportRoutingResolver.ResolvedRouting caseResolved =
                FEC_BCH_ImportRoutingResolver.resolve(stageId, rr.routingAction);
            if (caseResolved == null || String.isBlank(caseResolved.methodKey) ||
                !isResolvedOrRejectCaseRouting(caseResolved.methodKey)) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Resolve_Only);
            }
        }
        if (cofOrGsr == true &&
            String.isNotBlank(rr.assignmentRoutingAction) &&
            String.isBlank(rr.routingAction)) {
            FEC_BCH_ImportRoutingResolver.ResolvedRouting asgResolved =
                FEC_BCH_ImportRoutingResolver.resolve(stageId, rr.assignmentRoutingAction);
            if (asgResolved == null || String.isBlank(asgResolved.methodKey)) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Invalid);
            } else {
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
            validateD2CField(
                rr,
                rr.paymentContractAssessment,
                LABEL_PAYMENT_CONTRACT_ASSESSMENT,
                ERR_MISSING_PAYMENT_ASSESSMENT,
                ERR_INVALID_PAYMENT_ASSESSMENT,
                'FEC_RD_Payment_Contract_Assessment__c',
                configuredLabels,
                picklistValueByNormByField,
                errs,
                true
            );
            return errs;
        }
        if (profile == FEC_BatchCaseHandlingImportProfile.FIELD_PROFILE_CP_ASSESSMENT) {
            validateD2CField(
                rr,
                rr.cpAssessment,
                LABEL_CP_ASSESSMENT,
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
            validateD2CField(
                rr,
                rr.csSupportAssessment,
                LABEL_CS_SUPPORT_ASSESSMENT,
                'Thiếu giá trị CS Support đánh giá yêu cầu',
                'Giá trị CS Support đánh giá yêu cầu không tồn tại trong Datagroup.',
                'FEC_CS_Support_Assessment_Type__c',
                configuredLabels,
                picklistValueByNormByField,
                errs,
                true
            );
            validateD2CField(
                rr,
                rr.classificationByCS,
                LABEL_CS_SUPPORT_ASSESSMENT,
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

    private static void validateD2CField(
        FEC_BatchCaseHandlingImportRow rr,
        String inputValue,
        String fieldLabel,
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
        if (configuredLabels == null || !configuredLabels.contains(normalizeToken(fieldLabel))) {
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

    private static void addImportError(List<String> errs, String message) {
        if (errs == null || String.isBlank(message)) {
            return;
        }
        errs.add(message);
    }

    private static String joinImportErrors(List<String> errs) {
        if (errs == null || errs.isEmpty()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        List<String> parts = new List<String>();
        for (String err : errs) {
            if (String.isNotBlank(err)) {
                parts.add(err);
            }
        }
        return parts.isEmpty() ? FEC_ConstantCommon.STR_EMPTY : String.join(parts, IMPORT_ERROR_SEPARATOR);
    }

    private static String appendError(String current, String incoming) {
        if (String.isBlank(incoming)) {
            return current;
        }
        if (String.isBlank(current)) {
            return incoming;
        }
        return current + IMPORT_ERROR_SEPARATOR + incoming;
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
}