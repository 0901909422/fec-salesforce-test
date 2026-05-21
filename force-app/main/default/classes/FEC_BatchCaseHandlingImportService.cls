public without sharing class FEC_BatchCaseHandlingImportService {

    private static final Integer REMARK_MAX_LEN = 32768;
    private static final String USER_GROUP_OM = 'OM';
    private static final String BUSINESS_PROCESS_PHONE_UPDATE = 'Phone Update';
    private static final String LABEL_CS_D2C_ASSESSMENT = 'CS D2C đánh giá yêu cầu';
    private static final String LABEL_RISK_LEVEL = 'Mức độ rủi ro';
    private static final String LABEL_REQUIRED_ACTION = 'Hành động cần thiết';
    private static final String ERR_NOT_OWNER = 'Người dùng không phải chủ sở hữu Case';
    private static final String ERR_FIELD_NOT_CONFIGURED = 'Trường dữ liệu chưa được thiết lập trong Master Data Setting';
    private static final String ERR_NOT_OM_OR_PHONE_UPDATE = 'Case không thuộc phạm vi Phone Update cho nhóm OM';
    private static final String ERR_MISSING_CS_D2C_ASSESSMENT = 'Thiếu giá trị CS D2C đánh giá yêu cầu';
    private static final String ERR_MISSING_RISK_LEVEL = 'Thiếu giá trị Mức độ rủi ro';
    private static final String ERR_MISSING_REQUIRED_ACTION = 'Thiếu giá trị Hành động cần thiết';
    private static final String ERR_INVALID_CS_D2C_ASSESSMENT = 'Giá trị CS D2C đánh giá yêu cầu không tồn tại trong Datagroup.';
    private static final String ERR_INVALID_RISK_LEVEL = 'Giá trị Mức độ rủi ro không tồn tại trong Datagroup.';
    private static final String ERR_INVALID_REQUIRED_ACTION = 'Giá trị Hành động cần thiết không tồn tại trong Datagroup.';
    private class RoutingParseResult {
        public String methodKey;
        public String decision;
        public String routeTeamHint;
        public String routeQueueHint;
    }

    private static final String BATCH_OBJECT_API_NAME = 'FEC_Batch_Case_Handling__c';
    private static Map<String, Map<String, String>> routeParamsCacheByKey = new Map<String, Map<String, String>>();
    private static Map<String, String> queueIdCacheByToken = new Map<String, String>();

    public static Boolean shouldApplyImportRow(FEC_BatchCaseHandlingImportRow row) {
        return row != null &&
            row.status != System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed &&
            String.isNotBlank(row.recordId);
    }

    public static Boolean hasApplicableImportRows(List<FEC_BatchCaseHandlingImportRow> rows) {
        if (rows == null || rows.isEmpty()) {
            return false;
        }
        for (FEC_BatchCaseHandlingImportRow row : rows) {
            if (shouldApplyImportRow(row)) {
                return true;
            }
        }
        return false;
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

    private static Map<String, Schema.SObjectField> batchFieldMap() {
        return Schema.getGlobalDescribe().get(BATCH_OBJECT_API_NAME).getDescribe().fields.getMap();
    }

    private static SObject newBatchRow(Id batchRecordId) {
        return Schema.getGlobalDescribe().get(BATCH_OBJECT_API_NAME).newSObject(batchRecordId);
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
            String csvBody = buildBatchResultCsv(rowResults, batchFailureReason, isCofOrGsrImportRows(rowResults));
            if (String.isBlank(csvBody)) {
                return;
            }
            ContentVersion cv = new ContentVersion();
            cv.Title = ensureResultContentTitle(fileName);
            cv.PathOnClient = '/' + fileName;
            cv.VersionData = Blob.valueOf(csvBody);
            cv.FirstPublishLocationId = batchRecordId;
            insert cv;
        } catch (Exception ex) {
        }
    }

    private static String resolveBatchResultFileName(Id batchRecordId) {
        return FEC_BatchCaseHandlingSObjectUtil.removeFileExtension(queryBatchFileName(batchRecordId)) + '_Result.csv';
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

    private static String buildBatchResultCsv(
        List<FEC_BatchCaseHandlingImportRow> rowResults,
        String batchFailureReason,
        Boolean cofOrGsr
    ) {
        List<String> lines = new List<String>();
        if (cofOrGsr) {
            lines.add('Case ID Search,Routing Action,Inputted Remarks,Assignment ID,Assignment Routing Action,Status,Errors');
        } else {
            lines.add('Case ID Search,Routing Action,Inputted Remarks,Status,Errors');
        }
        if (rowResults != null && !rowResults.isEmpty()) {
            for (FEC_BatchCaseHandlingImportRow row : rowResults) {
                if (row == null) {
                    continue;
                }
                List<String> cols = new List<String>{
                    csvEscape(row.caseIdSearch),
                    csvEscape(row.routingAction),
                    csvEscape(row.inputtedRemarks)
                };
                if (cofOrGsr) {
                    cols.add(csvEscape(row.assignmentId));
                    cols.add(csvEscape(row.assignmentRoutingAction));
                }
                cols.add(csvEscape(row.status));
                cols.add(csvEscape(row.errors));
                lines.add(String.join(cols, ','));
            }
        } else if (String.isNotBlank(batchFailureReason)) {
            List<String> emptyCols = new List<String>();
            for (Integer i = 0; i < (cofOrGsr ? 6 : 3); i++) {
                emptyCols.add('');
            }
            lines.add(csvEscape(batchFailureReason) + ',' + String.join(emptyCols, ','));
        } else {
            return null;
        }
        return String.join(lines, '\n');
    }

    private static String csvEscape(String value) {
        String v = value == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(value);
        if (v.contains('"') || v.contains(',') || v.contains('\n') || v.contains('\r')) {
            return '"' + v.replace('"', '""') + '"';
        }
        return v;
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
            Boolean rowEmpty =
                String.isBlank(rr.caseIdSearch) &&
                String.isBlank(rr.routingAction) &&
                String.isBlank(rr.inputtedRemarks) &&
                String.isBlank(rr.assignmentId) &&
                String.isBlank(rr.assignmentRoutingAction) &&
                String.isBlank(rr.csD2CAssessmentType) &&
                String.isBlank(rr.riskLevel) &&
                String.isBlank(rr.requiredAction) &&
                String.isBlank(rr.classificationByCS) &&
                String.isBlank(rr.evaluationByCS) &&
                String.isBlank(rr.finalProduct);
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
                SELECT Id, IsClosed, FEC_ID_Search__c, OwnerId, FEC_Current_Case_Stage__c, FEC_Business_Process__r.FEC_Code__c
                FROM Case
                WHERE FEC_ID_Search__c IN :searchKeys
                LIMIT 5000
            ]) {
                if (c.FEC_ID_Search__c != null) {
                    caseBySearch.put(c.FEC_ID_Search__c, c);
                }
            }
        }

        Set<Id> assignmentIdSet = new Set<Id>();
        for (FEC_BatchCaseHandlingImportRow rr : output) {
            if (!cofOrGsr || String.isBlank(rr.assignmentId)) {
                continue;
            }
            try {
                assignmentIdSet.add(Id.valueOf(rr.assignmentId.trim()));
            } catch (Exception e) {
            }
        }
        Map<Id, FEC_Assignment__c> assignmentById = new Map<Id, FEC_Assignment__c>();
        if (!assignmentIdSet.isEmpty()) {
            assignmentById.putAll([
                SELECT Id, FEC_Case__c, FEC_Assignment_Status__c
                FROM FEC_Assignment__c
                WHERE Id IN :assignmentIdSet
            ]);
        }

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
        Map<String, Map<String, String>> picklistValueByNormByField = buildPicklistValueByNormalizedInputByField(
            new List<String>{
                'FEC_CS_D2C_Assessment_Type__c',
                'FEC_CS_D2C_Required_Corrective_Action__c',
                'FEC_CS_D2C_Risk_Level__c',
                'FEC_CS_Check_Classification_by_CS__c',
                'FEC_CS_Check_Evaluation_by_CS__c',
                'FEC_CS_Check_Final_product__c'
            }
        );

        Set<String> seenCaseSearch = new Set<String>();
        for (FEC_BatchCaseHandlingImportRow rr : output) {
            List<String> errs = new List<String>();
            if (String.isBlank(rr.caseIdSearch)) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Case_Id);
            }
            Case matched = String.isNotBlank(rr.caseIdSearch) ? caseBySearch.get(rr.caseIdSearch) : null;
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
            }

            if (matched != null) {
                errs.addAll(
                    validateD2CFieldsForCase(
                        rr,
                        matched,
                        configuredLabelsByStage,
                        picklistValueByNormByField
                    )
                );
            }

            if (cofOrGsr) {
                Boolean hasAssignment = String.isNotBlank(rr.assignmentId);
                if (hasAssignment) {
                    Id asgId;
                    try {
                        asgId = Id.valueOf(rr.assignmentId.trim());
                    } catch (Exception e) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Id_Not_Found);
                        asgId = null;
                    }
                    if (asgId != null) {
                        FEC_Assignment__c asg = assignmentById.get(asgId);
                        if (asg == null) {
                            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Id_Not_Found);
                        } else if (matched != null && asg.FEC_Case__c != matched.Id) {
                            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Id_Not_Found);
                        } else if (String.isNotBlank(asg.FEC_Assignment_Status__c) && asg.FEC_Assignment_Status__c.startsWith('Resolved-')) {
                            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Closed);
                        }
                    }
                    if (String.isNotBlank(rr.routingAction) && String.isNotBlank(rr.assignmentRoutingAction)) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Both_Routing_Actions);
                    }
                    if (String.isBlank(rr.routingAction) && String.isBlank(rr.assignmentRoutingAction)) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Or_Assignment_Routing);
                    }
                    if (String.isNotBlank(rr.routingAction)) {
                        RoutingParseResult routingParsed = parseRoutingPattern(rr.routingAction);
                        String caseMethod = routingParsed.methodKey;
                        if (caseMethod == null) {
                            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid);
                        } else if (!isResolvedOrRejectCaseRouting(caseMethod)) {
                            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Resolve_Only);
                        }
                    }
                    if (String.isNotBlank(rr.assignmentRoutingAction) &&
                        parseRoutingPattern(rr.assignmentRoutingAction).methodKey == null) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Invalid);
                    }
                } else {
                    if (String.isBlank(rr.routingAction)) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Action);
                    } else if (parseRoutingPattern(rr.routingAction).methodKey == null) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid);
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
                } else if (parseRoutingPattern(rr.routingAction).methodKey == null) {
                    errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid);
                }
            }

            if (String.isBlank(rr.inputtedRemarks)) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Remark);
            } else if (rr.inputtedRemarks.length() > REMARK_MAX_LEN) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Remark_Too_Long);
            }

            if (!errs.isEmpty()) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = String.join(errs, ' ');
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
        routeParamsCacheByKey.clear();
        queueIdCacheByToken.clear();
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
        Map<String, Map<String, String>> picklistValueByNormByField = buildPicklistValueByNormalizedInputByField(
            new List<String>{
                'FEC_CS_D2C_Assessment_Type__c',
                'FEC_CS_D2C_Required_Corrective_Action__c',
                'FEC_CS_D2C_Risk_Level__c',
                'FEC_CS_Check_Classification_by_CS__c',
                'FEC_CS_Check_Evaluation_by_CS__c',
                'FEC_CS_Check_Final_product__c'
            }
        );
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
            RoutingParseResult routingParsed = parseRoutingPattern(actionLabel);
            String methodKey = routingParsed.methodKey;
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
            if (routingActionRequiresExtraParams(methodKey, routingParsed.decision)) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(
                    rr.errors,
                    System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Requires_Params
                );
                continue;
            }
            try {
                Map<String, String> runParams = new Map<String, String>{ 'caseId' => String.valueOf(caseId) };
                if (methodKey == FEC_CaseBusinessService.UPDATEACTION && String.isNotBlank(routingParsed.decision)) {
                    runParams.put('decision', routingParsed.decision);
                }
                if (methodKey == FEC_CaseBusinessService.ROUTE_TO) {
                    Case caseLite = caseLiteById.get(caseId);
                    Map<String, String> routeParams = caseLite == null
                        ? null
                        : resolveRouteToParams(caseLite.FEC_Current_Case_Stage__c, routingParsed);
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
        applyDraftRemarksBulk(validRemarkItems);
    }

    private static void applyDraftRemarksBulk(List<RemarkDraftUpdateItem> remarkDraftItems) {
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
        if (String.isBlank(raw)) {
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
        return methodKey == FEC_CaseBusinessService.TRANSFER ||
            methodKey == FEC_CaseBusinessService.REVERT;
    }

    private static Boolean isResolvedOrRejectCaseRouting(String methodKey) {
        if (String.isBlank(methodKey)) {
            return false;
        }
        return methodKey == FEC_CaseBusinessService.RESOLVE || methodKey == FEC_CaseBusinessService.REJECT;
    }

    private static Map<String, String> resolveRouteToParams(Id currentStageId, RoutingParseResult parsed) {
        if (currentStageId == null || parsed == null) {
            return null;
        }
        String cacheKey = buildRouteParamsCacheKey(currentStageId, parsed);
        if (routeParamsCacheByKey.containsKey(cacheKey)) {
            return routeParamsCacheByKey.get(cacheKey);
        }
        List<FEC_Stage_Change__c> candidates = [
            SELECT FEC_Action_Button__c, FEC_Next_Queue__c, FEC_Team_User_Group__c
            FROM FEC_Stage_Change__c
            WHERE FEC_Previous_Stage__c = :currentStageId
            AND FEC_Active__c = TRUE
            AND FEC_Action_Button__r.FEC_Code__c = :FEC_CaseBusinessService.ROUTE_TO
            ORDER BY CreatedDate DESC
        ];
        if (candidates.isEmpty()) {
            routeParamsCacheByKey.put(cacheKey, null);
            return null;
        }
        String teamHintNorm = normalizeToken(parsed.routeTeamHint);
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

    private static Map<Id, Set<String>> loadConfiguredLabelsByStage(Set<Id> stageIds) {
        Map<Id, Set<String>> out = new Map<Id, Set<String>>();
        if (stageIds == null || stageIds.isEmpty()) {
            return out;
        }
        for (FEC_Master_Data_Setting__c row : [
            SELECT FEC_Stage_Name__c, FEC_Field_Label_Name__c
            FROM FEC_Master_Data_Setting__c
            WHERE FEC_Stage_Name__c IN :stageIds
            AND FEC_Field_Label_Name__c IN :new List<String>{ LABEL_CS_D2C_ASSESSMENT, LABEL_RISK_LEVEL, LABEL_REQUIRED_ACTION }
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

    private static Map<String, Map<String, String>> buildPicklistValueByNormalizedInputByField(List<String> caseFieldApis) {
        Map<String, Map<String, String>> out = new Map<String, Map<String, String>>();
        if (caseFieldApis == null || caseFieldApis.isEmpty()) {
            return out;
        }
        Map<String, Schema.SObjectField> fieldMap = Case.SObjectType.getDescribe().fields.getMap();
        for (String apiName : caseFieldApis) {
            if (String.isBlank(apiName) || !fieldMap.containsKey(apiName)) {
                continue;
            }
            Schema.DescribeFieldResult dfr = fieldMap.get(apiName).getDescribe();
            if (dfr.getType() != Schema.DisplayType.PICKLIST && dfr.getType() != Schema.DisplayType.MULTIPICKLIST) {
                continue;
            }
            Map<String, String> normalizedToValue = new Map<String, String>();
            for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
                if (entry == null || !entry.isActive()) {
                    continue;
                }
                String value = entry.getValue();
                if (String.isBlank(value)) {
                    continue;
                }
                normalizedToValue.put(normalizeToken(value), value);
                normalizedToValue.put(normalizeToken(entry.getLabel()), value);
            }
            out.put(apiName, normalizedToValue);
        }
        return out;
    }

    private static List<String> validateD2CFieldsForCase(
        FEC_BatchCaseHandlingImportRow rr,
        Case matched,
        Map<Id, Set<String>> configuredLabelsByStage,
        Map<String, Map<String, String>> picklistValueByNormByField
    ) {
        List<String> errs = new List<String>();
        if (rr == null || matched == null) {
            return errs;
        }
        Boolean hasAnyD2CInput =
            String.isNotBlank(rr.csD2CAssessmentType) ||
            String.isNotBlank(rr.riskLevel) ||
            String.isNotBlank(rr.requiredAction);
        if (!hasAnyD2CInput) {
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

        validateD2CField(
            rr.csD2CAssessmentType,
            LABEL_CS_D2C_ASSESSMENT,
            ERR_MISSING_CS_D2C_ASSESSMENT,
            ERR_INVALID_CS_D2C_ASSESSMENT,
            'FEC_CS_D2C_Assessment_Type__c',
            configuredLabels,
            picklistValueByNormByField,
            errs
        );
        validateD2CField(
            rr.riskLevel,
            LABEL_RISK_LEVEL,
            ERR_MISSING_RISK_LEVEL,
            ERR_INVALID_RISK_LEVEL,
            'FEC_CS_D2C_Required_Corrective_Action__c',
            configuredLabels,
            picklistValueByNormByField,
            errs
        );
        validateD2CField(
            rr.requiredAction,
            LABEL_REQUIRED_ACTION,
            ERR_MISSING_REQUIRED_ACTION,
            ERR_INVALID_REQUIRED_ACTION,
            'FEC_CS_D2C_Risk_Level__c',
            configuredLabels,
            picklistValueByNormByField,
            errs
        );
        return errs;
    }

    private static void validateD2CField(
        String inputValue,
        String fieldLabel,
        String missingError,
        String invalidError,
        String caseFieldApi,
        Set<String> configuredLabels,
        Map<String, Map<String, String>> picklistValueByNormByField,
        List<String> errs
    ) {
        if (String.isBlank(inputValue)) {
            return;
        }
        if (configuredLabels == null || !configuredLabels.contains(normalizeToken(fieldLabel))) {
            errs.add(ERR_FIELD_NOT_CONFIGURED);
            return;
        }
        String resolvedValue = resolvePicklistValue(caseFieldApi, inputValue, picklistValueByNormByField);
        if (String.isBlank(resolvedValue)) {
            errs.add(invalidError);
        }
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
        String assessmentValue = resolvePicklistValue('FEC_CS_D2C_Assessment_Type__c', rr.csD2CAssessmentType, picklistValueByNormByField);
        String riskValue = resolvePicklistValue('FEC_CS_D2C_Required_Corrective_Action__c', rr.riskLevel, picklistValueByNormByField);
        String requiredActionValue = resolvePicklistValue('FEC_CS_D2C_Risk_Level__c', rr.requiredAction, picklistValueByNormByField);
        String classificationByCSValue = resolvePicklistValue(
            'FEC_CS_Check_Classification_by_CS__c',
            rr.classificationByCS,
            picklistValueByNormByField
        );
        String evaluationByCSValue = resolvePicklistValue(
            'FEC_CS_Check_Evaluation_by_CS__c',
            rr.evaluationByCS,
            picklistValueByNormByField
        );
        String finalProductValue = resolvePicklistValue(
            'FEC_CS_Check_Final_product__c',
            rr.finalProduct,
            picklistValueByNormByField
        );
        if (String.isNotBlank(assessmentValue) && caseFieldMap.containsKey('FEC_CS_D2C_Assessment_Type__c')) {
            c.put('FEC_CS_D2C_Assessment_Type__c', assessmentValue);
            hasAny = true;
        }
        if (String.isNotBlank(riskValue) && caseFieldMap.containsKey('FEC_CS_D2C_Required_Corrective_Action__c')) {
            c.put('FEC_CS_D2C_Required_Corrective_Action__c', riskValue);
            hasAny = true;
        }
        if (String.isNotBlank(requiredActionValue) && caseFieldMap.containsKey('FEC_CS_D2C_Risk_Level__c')) {
            c.put('FEC_CS_D2C_Risk_Level__c', requiredActionValue);
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
        if (String.isBlank(caseFieldApi) || String.isBlank(userInput) || picklistValueByNormByField == null) {
            return null;
        }
        Map<String, String> normalizedToValue = picklistValueByNormByField.get(caseFieldApi);
        if (normalizedToValue == null || normalizedToValue.isEmpty()) {
            return null;
        }
        return normalizedToValue.get(normalizeToken(userInput));
    }

    private static String normalizeToken(String value) {
        if (String.isBlank(value)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return value.trim().toLowerCase().replaceAll('\\s+', FEC_ConstantCommon.STR_EMPTY);
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

    private static String appendError(String current, String incoming) {
        if (String.isBlank(incoming)) {
            return current;
        }
        if (String.isBlank(current)) {
            return incoming;
        }
        return current + ' ' + incoming;
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
        public String inputtedRemarks;
    }
}