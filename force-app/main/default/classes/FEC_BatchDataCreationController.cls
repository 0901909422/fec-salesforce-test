public with sharing class FEC_BatchDataCreationController {
    private static final String OBJECT_API_NAME = 'FEC_Batch_Data_Creation__c';
    private static final String ABSENCE_OBJECT_API_NAME = 'FEC_Service_Resource_Absence__c';
    private static final String TEMPLATE_OBJECT_API_NAME = 'FEC_Template_Import__c';
    private static final String TEMPLATE_APPLICABLE_VALUE = 'Batch Data Creation';
    private static final Integer MAX_ROWS = 200;

    public class BatchRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String fileName;
        @AuraEnabled public String fileDownloadUrl;
        @AuraEnabled public Datetime uploadedOn;
        @AuraEnabled public String uploadedBy;
        @AuraEnabled public Decimal totalRecordsCount;
        @AuraEnabled public Decimal totalSuccessRecords;
        @AuraEnabled public Decimal totalFailedRecords;
        @AuraEnabled public String status;
        @AuraEnabled public String failureReason;
        @AuraEnabled public String result;
        @AuraEnabled public String resultDownloadUrl;
    }

    public class ImportResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id batchRecordId;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String status;
        @AuraEnabled public String resultRowsJson;
    }

    public class RowResult {
        @AuraEnabled public String serviceResource;
        @AuraEnabled public String startDate;
        @AuraEnabled public String endDate;
        @AuraEnabled public String note;
        @AuraEnabled public String recordId;
        @AuraEnabled public String status;
        @AuraEnabled public String errors;
    }

    /** Kết quả validate kèm danh sách record chuẩn bị insert (parallel với rowResults — null cho dòng fail). */
    private class ValidationOutput {
        public List<RowResult> rowResults;
        public List<FEC_Service_Resource_Absence__c> absencesByIndex;
    }

    public class TemplateOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Id templateId;
        @AuraEnabled public String downloadUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<TemplateOption> getTemplateOptions() {
        List<TemplateOption> output = new List<TemplateOption>();
        Schema.SObjectType templateType = Schema.getGlobalDescribe().get(TEMPLATE_OBJECT_API_NAME);
        if (templateType == null) {
            return output;
        }

        Map<String, Schema.SObjectField> templateFields = templateType.getDescribe().fields.getMap();
        if (!templateFields.containsKey('Name')) {
            return output;
        }

        String whereClause = ' WHERE Name != null';
        if (templateFields.containsKey('FEC_Active__c')) {
            whereClause += ' AND FEC_Active__c = true';
        }
        if (templateFields.containsKey('FEC_Applicable_for__c')) {
            whereClause += ' AND FEC_Applicable_for__c = :TEMPLATE_APPLICABLE_VALUE';
        }

        String queryText =
            'SELECT Id, Name' +
            ' FROM ' + TEMPLATE_OBJECT_API_NAME +
            whereClause +
            ' ORDER BY Name ASC';
        List<SObject> rows = Database.query(queryText);
        Map<Id, TemplateOption> optionsByTemplateId = new Map<Id, TemplateOption>();
        for (SObject row : rows) {
            String nameValue = FEC_BatchImportCommon.asString(row.get('Name'));
            if (String.isBlank(nameValue)) {
                continue;
            }
            TemplateOption item = new TemplateOption();
            item.label = nameValue;
            item.value = nameValue;
            item.templateId = (Id) row.get('Id');
            output.add(item);
            if (item.templateId != null) {
                optionsByTemplateId.put(item.templateId, item);
            }
        }

        if (!optionsByTemplateId.isEmpty()) {
            for (ContentDocumentLink link : [
                SELECT LinkedEntityId, ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :optionsByTemplateId.keySet()
                ORDER BY LinkedEntityId, SystemModstamp DESC
            ]) {
                TemplateOption option = optionsByTemplateId.get(link.LinkedEntityId);
                if (option == null || String.isNotBlank(option.downloadUrl)) {
                    continue;
                }
                String latestVersionId =
                    link.ContentDocument == null
                        ? null
                        : String.valueOf(link.ContentDocument.LatestPublishedVersionId);
                if (String.isNotBlank(latestVersionId)) {
                    option.downloadUrl = FEC_ConstantCommon.CONTENT_VERSION_DOWNLOAD_URL_PREFIX + latestVersionId;
                }
            }
        }
        return output;
    }

    @AuraEnabled
    public static List<BatchRow> getRecentRows() {
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(OBJECT_API_NAME);
        if (sObjType == null) {
            return new List<BatchRow>();
        }

        Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();
        String fileField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_File_Name__c', 'Name' });
        String fileContentDocumentIdField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_File_Content_Document_Id__c' });
        String uploadedOnField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_Uploaded_On__c', 'CreatedDate' });
        String totalRecordsField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' });
        String totalSuccessField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_Total_Success_Records__c' });
        String totalFailedField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_Total_Failed_Records__c' });
        String statusField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_Status__c' });
        String failureReasonField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_Failure_Reason__c' });
        String resultField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_Result__c' });

        List<String> selectParts = new List<String>{ 'Id', 'CreatedBy.Email' };
FEC_BatchImportCommon.addIfNotBlank(selectParts, fileField);
FEC_BatchImportCommon.addIfNotBlank(selectParts, fileContentDocumentIdField);
FEC_BatchImportCommon.addIfNotBlank(selectParts, uploadedOnField);
FEC_BatchImportCommon.addIfNotBlank(selectParts, totalRecordsField);
FEC_BatchImportCommon.addIfNotBlank(selectParts, totalSuccessField);
FEC_BatchImportCommon.addIfNotBlank(selectParts, totalFailedField);
FEC_BatchImportCommon.addIfNotBlank(selectParts, statusField);
FEC_BatchImportCommon.addIfNotBlank(selectParts, failureReasonField);
FEC_BatchImportCommon.addIfNotBlank(selectParts, resultField);

        String queryText =
            'SELECT ' + String.join(selectParts, ', ') +
            ' FROM ' + OBJECT_API_NAME +
            ' ORDER BY CreatedDate DESC' +
            ' LIMIT ' + MAX_ROWS;

        List<SObject> rows = Database.query(queryText);
        List<BatchRow> output = new List<BatchRow>();
        Map<Id, String> resultUrlByBatchId = new Map<Id, String>();
        Map<Id, String> sourceUrlByBatchId = new Map<Id, String>();
        Set<Id> batchIds = new Set<Id>();
        Map<Id, Id> sourceDocIdByBatchId = new Map<Id, Id>();
        for (SObject row : rows) {
            Id batchId = (Id) row.get('Id');
            batchIds.add(batchId);
            if (String.isNotBlank(fileContentDocumentIdField)) {
                String docIdStr = FEC_BatchImportCommon.asString(
FEC_BatchImportCommon.getFieldValue(row, fileContentDocumentIdField)
                );
                if (String.isNotBlank(docIdStr)) {
                    try {
                        sourceDocIdByBatchId.put(batchId, (Id) docIdStr);
                    } catch (Exception ignore) {
                        // bỏ qua giá trị không phải Id
                    }
                }
            }
        }
        if (!batchIds.isEmpty()) {
            // Source được link TRƯỚC result trong importBatchData → ASC theo thời gian
            // ContentDocument.CreatedDate là thời điểm upload thật, đáng tin cậy hơn SystemModstamp của link.
            for (ContentDocumentLink link : [
                SELECT LinkedEntityId, ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId, ContentDocument.CreatedDate
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :batchIds
                ORDER BY LinkedEntityId, ContentDocument.CreatedDate ASC
            ]) {
                String title = link.ContentDocument == null ? null : link.ContentDocument.Title;
                String versionId =
                    link.ContentDocument == null
                        ? null
                        : String.valueOf(link.ContentDocument.LatestPublishedVersionId);
                if (String.isBlank(versionId) || String.isBlank(title)) {
                    continue;
                }
                Id sourceDocId = sourceDocIdByBatchId.get(link.LinkedEntityId);
                String url = FEC_ConstantCommon.CONTENT_VERSION_DOWNLOAD_URL_PREFIX + versionId;
                if (sourceDocId != null) {
                    // Có FEC_File_Content_Document_Id__c → match đúng id mới là source.
                    if (link.ContentDocumentId == sourceDocId) {
                        if (!sourceUrlByBatchId.containsKey(link.LinkedEntityId)) {
                            sourceUrlByBatchId.put(link.LinkedEntityId, url);
                        }
                    } else if (!resultUrlByBatchId.containsKey(link.LinkedEntityId)) {
                        resultUrlByBatchId.put(link.LinkedEntityId, url);
                    }
                } else {
                    // Không có field id → file đầu tiên (theo CreatedDate ASC) là source, các file sau là result.
                    if (!sourceUrlByBatchId.containsKey(link.LinkedEntityId)) {
                        sourceUrlByBatchId.put(link.LinkedEntityId, url);
                    } else if (!resultUrlByBatchId.containsKey(link.LinkedEntityId)) {
                        resultUrlByBatchId.put(link.LinkedEntityId, url);
                    }
                }
            }
        }

        for (SObject row : rows) {
            BatchRow dto = new BatchRow();
            dto.id = (Id) row.get('Id');
            dto.fileName = FEC_BatchImportCommon.asString(
FEC_BatchImportCommon.getFieldValue(row, fileField)
            );
            String sourceDocumentId = String.isBlank(fileContentDocumentIdField)
                ? null
                : FEC_BatchImportCommon.asString(
FEC_BatchImportCommon.getFieldValue(row, fileContentDocumentIdField)
                );
            // Luôn ưu tiên ContentDocumentId đã lưu trên batch = file gốc import (ổn định hơn heuristic theo Title).
            if (String.isNotBlank(sourceDocumentId)) {
                dto.fileDownloadUrl = FEC_ConstantCommon.CONTENT_DOCUMENT_DOWNLOAD_URL_PREFIX + sourceDocumentId;
            } else {
                dto.fileDownloadUrl = sourceUrlByBatchId.get(dto.id);
            }
            dto.uploadedOn = FEC_BatchImportCommon.asDatetime(
FEC_BatchImportCommon.getFieldValue(row, uploadedOnField)
            );
            SObject createdBy = row.getSObject('CreatedBy');
            dto.uploadedBy = createdBy == null ? null : (String) createdBy.get('Email');
            dto.totalRecordsCount = FEC_BatchImportCommon.asDecimal(
FEC_BatchImportCommon.getFieldValue(row, totalRecordsField)
            );
            dto.totalSuccessRecords = FEC_BatchImportCommon.asDecimal(
FEC_BatchImportCommon.getFieldValue(row, totalSuccessField)
            );
            dto.totalFailedRecords = FEC_BatchImportCommon.asDecimal(
FEC_BatchImportCommon.getFieldValue(row, totalFailedField)
            );
            dto.status = FEC_BatchImportCommon.asString(
FEC_BatchImportCommon.getFieldValue(row, statusField)
            );
            dto.failureReason = FEC_BatchImportCommon.asString(
FEC_BatchImportCommon.getFieldValue(row, failureReasonField)
            );
            dto.result = FEC_BatchImportCommon.asString(
FEC_BatchImportCommon.getFieldValue(row, resultField)
            );
            dto.resultDownloadUrl = resultUrlByBatchId.get(dto.id);
            output.add(dto);
        }
        return output;
    }

    @AuraEnabled
    public static ImportResult importBatchData(String fileName, String fileBodyBase64, String templateName, String rowsJson) {
        ImportResult out = new ImportResult();
        out.success = false;

        if (String.isBlank(fileName) || String.isBlank(fileBodyBase64) || String.isBlank(rowsJson)) {
            out.message = System.Label.FEC_Batch_Import_Select_File;
            upsertFailedBatch(fileName, templateName, out.message);
            return out;
        }

        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(OBJECT_API_NAME);
        if (sObjType == null) {
            out.message = String.format(System.Label.FEC_Batch_Import_Object_Not_Available, new List<String>{ OBJECT_API_NAME });
            upsertSystemFailureBatch(fileName, templateName, out.message);
            return out;
        }

        Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();
        SObject batchRow;
        try {
            List<Object> inputRows = (List<Object>) JSON.deserializeUntyped(rowsJson);
            if (inputRows == null || inputRows.isEmpty()) {
                ContentVersion cvEmpty = new ContentVersion();
                cvEmpty.Title = FEC_BatchImportCommon.removeFileExtension(fileName);
                cvEmpty.PathOnClient = '/' + fileName;
                cvEmpty.VersionData = EncodingUtil.base64Decode(fileBodyBase64);
                insert cvEmpty;

                ContentVersion insertedCvEmpty = [
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :cvEmpty.Id
                    LIMIT 1
                ];

                batchRow = sObjType.newSObject();
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'Name', 'FEC_File_Name__c' }, fileName);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processed');
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Template__c', 'FEC_Template_Name__c' }, templateName);
FEC_BatchImportCommon.putIfFieldExists(
                    fieldMap,
                    batchRow,
                    new List<String>{ 'FEC_File_Content_Document_Id__c' },
                    String.valueOf(insertedCvEmpty.ContentDocumentId)
                );
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, 0);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
FEC_BatchImportCommon.putIfFieldExists(
                    fieldMap,
                    batchRow,
                    new List<String>{ 'FEC_Failure_Reason__c' },
                    System.Label.FEC_BCH_RequireFile
                );
                insert batchRow;
FEC_BatchImportCommon.linkFileToBatch((Id) batchRow.get('Id'), insertedCvEmpty.ContentDocumentId);

                out.success = true;
                out.message = System.Label.FEC_Batch_Import_Submitted;
                out.batchRecordId = (Id) batchRow.get('Id');
                out.contentDocumentId = insertedCvEmpty.ContentDocumentId;
                out.status = 'Processed';
                out.resultRowsJson = '[]';
                return out;
            }
            ContentVersion cv = new ContentVersion();
            cv.Title = FEC_BatchImportCommon.removeFileExtension(fileName);
            cv.PathOnClient = '/' + fileName;
            cv.VersionData = EncodingUtil.base64Decode(fileBodyBase64);
            insert cv;

            ContentVersion insertedCv = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            batchRow = sObjType.newSObject();
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'Name', 'FEC_File_Name__c' }, fileName);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Uploaded');
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, '');
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Template__c', 'FEC_Template_Name__c' }, templateName);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_File_Content_Document_Id__c' }, String.valueOf(insertedCv.ContentDocumentId));
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, inputRows.size());
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, '');
            insert batchRow;
FEC_BatchImportCommon.linkFileToBatch((Id) batchRow.get('Id'), insertedCv.ContentDocumentId);

FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processing');
            update batchRow;

            ValidationOutput vo = validateAndBuildAbsences(inputRows);
            List<RowResult> rowResults = vo.rowResults;
            Integer totalCount = rowResults.size();
            Integer failedCount = countFailedRowResults(rowResults);
            String batchFailureReason = failedCount > 0
                ? String.format(System.Label.FEC_Batch_Import_Invalid_Row_Count, new List<String>{ String.valueOf(failedCount) })
                : '';

            // Có bất kỳ dòng lỗi validation → không import cả file.
            if (failedCount > 0) {
                markAllRowResultsFailedForBatchNoImport(rowResults);
                applyBatchImportFailureOutcome(fieldMap, batchRow, totalCount, failedCount, batchFailureReason);
                out.success = false;
                out.message = batchFailureReason;
                out.batchRecordId = (Id) batchRow.get('Id');
                out.contentDocumentId = insertedCv.ContentDocumentId;
                out.status = 'Failure';
                out.resultRowsJson = JSON.serialize(rowResults);
                return out;
            }

            List<FEC_Service_Resource_Absence__c> toInsert = new List<FEC_Service_Resource_Absence__c>();
            List<Integer> originalIdxByInsertIdx = new List<Integer>();
            for (Integer i = 0; i < vo.absencesByIndex.size(); i += 1) {
                FEC_Service_Resource_Absence__c rec = vo.absencesByIndex[i];
                if (rec != null) {
                    toInsert.add(rec);
                    originalIdxByInsertIdx.add(i);
                }
            }

            Savepoint importSavepoint = Database.setSavepoint();
            Boolean anyDmlFailed = false;
            if (!toInsert.isEmpty()) {
                Database.SaveResult[] saveResults = Database.insert(toInsert, false);
                Set<Id> insertedIds = new Set<Id>();
                for (Integer k = 0; k < saveResults.size(); k += 1) {
                    Database.SaveResult srRes = saveResults[k];
                    Integer originalIdx = originalIdxByInsertIdx[k];
                    if (srRes.isSuccess()) {
                        insertedIds.add(srRes.getId());
                    } else {
                        anyDmlFailed = true;
                        List<String> dmlErrs = new List<String>();
                        for (Database.Error err : srRes.getErrors()) {
                            dmlErrs.add(err.getMessage());
                        }
                        rowResults[originalIdx].status = 'Failed';
                        rowResults[originalIdx].errors = FEC_BatchImportCommon.joinRowErrors(dmlErrs);
                        rowResults[originalIdx].recordId = '';
                    }
                }

                if (!anyDmlFailed && !insertedIds.isEmpty()) {
                    Map<Id, FEC_Service_Resource_Absence__c> nameById = new Map<Id, FEC_Service_Resource_Absence__c>([
                        SELECT Id, Name FROM FEC_Service_Resource_Absence__c WHERE Id IN :insertedIds
                    ]);
                    for (Integer k = 0; k < saveResults.size(); k += 1) {
                        Database.SaveResult srRes = saveResults[k];
                        if (!srRes.isSuccess()) {
                            continue;
                        }
                        Integer originalIdx = originalIdxByInsertIdx[k];
                        FEC_Service_Resource_Absence__c queried = nameById.get(srRes.getId());
                        rowResults[originalIdx].recordId = queried != null && String.isNotBlank(queried.Name)
                            ? queried.Name
                            : String.valueOf(srRes.getId());
                    }
                }
            }

            if (anyDmlFailed) {
                Database.rollback(importSavepoint);
                markAllRowResultsFailedForBatchNoImport(rowResults);
                failedCount = countFailedRowResults(rowResults);
                batchFailureReason = String.format(
                    System.Label.FEC_Batch_Import_Invalid_Row_Count,
                    new List<String>{ String.valueOf(failedCount) }
                );
                applyBatchImportFailureOutcome(fieldMap, batchRow, totalCount, failedCount, batchFailureReason);
                out.success = false;
                out.message = batchFailureReason;
                out.batchRecordId = (Id) batchRow.get('Id');
                out.contentDocumentId = insertedCv.ContentDocumentId;
                out.status = 'Failure';
                out.resultRowsJson = JSON.serialize(rowResults);
                return out;
            }

FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processed');
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, totalCount);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, totalCount);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, '');
            update batchRow;

            out.success = true;
            out.message = System.Label.FEC_Batch_Import_Submitted;
            out.batchRecordId = (Id) batchRow.get('Id');
            out.contentDocumentId = insertedCv.ContentDocumentId;
            out.status = 'Processed';
            out.resultRowsJson = JSON.serialize(rowResults);
            return out;
        } catch (Exception ex) {
            if (batchRow != null && batchRow.get('Id') != null) {
                try {
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Failure');
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, ex.getMessage());
                    update batchRow;
                } catch (Exception e) {
                    upsertSystemFailureBatch(fileName, templateName, ex.getMessage());
                }
            } else {
                upsertSystemFailureBatch(fileName, templateName, ex.getMessage());
            }
            out.message = ex.getMessage();
            return out;
        }
    }

    @AuraEnabled
    public static void logFailedImport(String fileName, String templateName, String reason) {
        upsertFailedBatch(fileName, templateName, reason);
    }

    /**
     * Lưu batch + file gốc khi validate client fail; status Processed (đã xử lý yêu cầu import).
     */
    @AuraEnabled
    public static Id logFailedImportWithFile(
        String fileName,
        String fileBodyBase64,
        String templateName,
        String reason
    ) {
        try {
            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(OBJECT_API_NAME);
            if (sObjType == null) {
                return null;
            }
            Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();

            Id contentDocumentId = null;
            if (String.isNotBlank(fileBodyBase64) && String.isNotBlank(fileName)) {
                ContentVersion cv = new ContentVersion();
                cv.Title = FEC_BatchImportCommon.removeFileExtension(fileName);
                cv.PathOnClient = '/' + fileName;
                cv.VersionData = EncodingUtil.base64Decode(fileBodyBase64);
                insert cv;
                ContentVersion insertedCv = [
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :cv.Id
                    LIMIT 1
                ];
                contentDocumentId = insertedCv.ContentDocumentId;
            }

            SObject failedRow = sObjType.newSObject();
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'Name', 'FEC_File_Name__c' }, fileName);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Status__c' }, 'Processed');
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Result__c' }, 'Result');
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Failure_Reason__c' }, reason);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Template__c', 'FEC_Template_Name__c' }, templateName);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, 0);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
            if (contentDocumentId != null) {
FEC_BatchImportCommon.putIfFieldExists(
                    fieldMap,
                    failedRow,
                    new List<String>{ 'FEC_File_Content_Document_Id__c' },
                    String.valueOf(contentDocumentId)
                );
            }
            insert failedRow;

            if (contentDocumentId != null) {
FEC_BatchImportCommon.linkFileToBatch((Id) failedRow.get('Id'), contentDocumentId);
            }
            return (Id) failedRow.get('Id');
        } catch (Exception ex) {
            return null;
        }
    }

    @AuraEnabled
    public static void saveResultFile(Id batchRecordId, String resultFileName, String fileBodyBase64) {
        if (batchRecordId == null || String.isBlank(resultFileName) || String.isBlank(fileBodyBase64)) {
            return;
        }
        ContentVersion cv = new ContentVersion();
        cv.Title = FEC_BatchImportCommon.removeFileExtension(resultFileName);
        cv.PathOnClient = '/' + resultFileName;
        cv.VersionData = EncodingUtil.base64Decode(fileBodyBase64);
        cv.FirstPublishLocationId = batchRecordId;
        insert cv;
    }

    /**
     * Validate từng dòng VÀ build sẵn record chuẩn bị insert cho các dòng hợp lệ.
     * Các dòng fail vẫn xuất hiện trong rowResults với status='Failed' và errors,
     * absencesByIndex tại vị trí đó = null.
     */
    private static ValidationOutput validateAndBuildAbsences(List<Object> inputRows) {
        Set<String> rawValues = new Set<String>();
        List<RowResult> output = new List<RowResult>();
        for (Object rowObj : inputRows) {
            Map<String, Object> row = (Map<String, Object>) rowObj;
            RowResult rr = new RowResult();
            rr.serviceResource = FEC_BatchImportCommon.normalizeText(row.get('serviceResource'));
            rr.startDate = FEC_BatchImportCommon.normalizeText(row.get('startDate'));
            rr.endDate = FEC_BatchImportCommon.normalizeText(row.get('endDate'));
            rr.note = FEC_BatchImportCommon.normalizeText(row.get('note'));
            rr.recordId = '';
            rr.status = 'Succeeded';
            rr.errors = '';
            output.add(rr);
            if (String.isNotBlank(rr.serviceResource)) {
                rawValues.add(rr.serviceResource);
            }
        }

        Map<String, Id> serviceResourceByKey = resolveServiceResourceIds(rawValues);

        // Tải trước các Absence đã tồn tại trong DB cho các Service Resource sẽ import.
        // Build set key 'srId|startMs|endMs' để check trùng nhanh trong vòng validate.
        Set<String> dbExistingKeys = loadExistingAbsenceKeys(serviceResourceByKey.values());

        List<FEC_Service_Resource_Absence__c> absencesByIndex = new List<FEC_Service_Resource_Absence__c>();
        for (Integer i = 0; i < output.size(); i += 1) {
            absencesByIndex.add(null);
        }
        Set<String> uniqueKeys = new Set<String>();
        for (Integer idx = 0; idx < output.size(); idx += 1) {
            Integer rowNumber = idx + 2;
            RowResult rr = output[idx];
            List<String> errs = new List<String>();

            if (String.isBlank(rr.serviceResource)) {
                errs.add(System.Label.FEC_Batch_Import_Data_Missing_Service_Resource);
            }
            if (String.isBlank(rr.startDate)) {
                errs.add(System.Label.FEC_Batch_Import_Data_Missing_Start_Date);
            }
            if (String.isBlank(rr.endDate)) {
                errs.add(System.Label.FEC_Batch_Import_Data_Missing_End_Date);
            }
            if (String.isNotBlank(rr.note) && rr.note.length() > 255) {
                errs.add(System.Label.FEC_Batch_Import_Data_Note_Too_Long);
            }

            Boolean isEmailFormat = String.isNotBlank(rr.serviceResource)
                && Pattern.matches(FEC_ConstantCommon.PATTERN_EMAIL, rr.serviceResource);
            if (String.isNotBlank(rr.serviceResource) && !isEmailFormat) {
                errs.add(System.Label.FEC_Batch_Import_Data_Invalid_Service_Resource_Format);
            }

            Id srId = null;
            if (isEmailFormat) {
                srId = serviceResourceByKey.get(rr.serviceResource.toLowerCase());
                if (srId == null) {
                    srId = serviceResourceByKey.get(rr.serviceResource);
                }
                if (srId == null) {
                    errs.add(System.Label.FEC_Batch_Import_Data_Service_Resource_Not_Found);
                }
            }

            Datetime startDt;
            Datetime endDt;
            if (String.isNotBlank(rr.startDate)) {
                try {
                    startDt = parseDateTimeStrict(rr.startDate, rowNumber, 'Start Date');
                } catch (Exception e) {
                    errs.add(System.Label.FEC_Batch_Import_Data_Invalid_Start_Date_Format);
                }
            }
            if (String.isNotBlank(rr.endDate)) {
                try {
                    endDt = parseDateTimeStrict(rr.endDate, rowNumber, 'End Date');
                } catch (Exception e) {
                    errs.add(System.Label.FEC_Batch_Import_Data_Invalid_End_Date_Format);
                }
            }

            if (startDt != null && endDt != null && endDt < startDt) {
                errs.add(System.Label.FEC_Batch_Import_Data_End_Before_Start);
            }
            Datetime nowGmt = System.now();
            if (startDt != null && startDt < nowGmt) {
                errs.add(System.Label.FEC_Batch_Import_Data_Start_In_Past);
            }
            if (endDt != null && endDt < nowGmt) {
                errs.add(System.Label.FEC_Batch_Import_Data_End_In_Past);
            }
            if (srId != null && startDt != null && endDt != null) {
                String uniqueKey = String.valueOf(srId) + '|' + String.valueOf(startDt.getTime()) + '|' + String.valueOf(endDt.getTime());
                if (dbExistingKeys.contains(uniqueKey)) {
                    errs.add(System.Label.FEC_Batch_Import_Data_Absence_Duplicate_In_System);
                } else if (uniqueKeys.contains(uniqueKey)) {
                    errs.add(System.Label.FEC_Batch_Import_Data_Absence_Duplicate_In_File);
                } else {
                    uniqueKeys.add(uniqueKey);
                }
            }

            if (!errs.isEmpty()) {
                rr.status = 'Failed';
                rr.errors = FEC_BatchImportCommon.joinRowErrors(errs);
            } else {
                FEC_Service_Resource_Absence__c rec = new FEC_Service_Resource_Absence__c();
                rec.FEC_Service_Resource__c = srId;
                rec.FEC_Start_Date__c = startDt;
                rec.FEC_End_Date__c = endDt;
                rec.FEC_Note__c = rr.note;
                absencesByIndex[idx] = rec;
            }
        }

        ValidationOutput vo = new ValidationOutput();
        vo.rowResults = output;
        vo.absencesByIndex = absencesByIndex;
        return vo;
    }

    /**
     * Trả về set key 'srId|startMs|endMs' của các Absence ĐÃ tồn tại trong DB
     * cho danh sách Service Resource Id truyền vào — phục vụ check trùng với obj.
     */
    private static Set<String> loadExistingAbsenceKeys(List<Id> serviceResourceIds) {
        Set<String> keys = new Set<String>();
        if (serviceResourceIds == null || serviceResourceIds.isEmpty()) {
            return keys;
        }
        Set<Id> uniqueSrIds = new Set<Id>(serviceResourceIds);
        for (FEC_Service_Resource_Absence__c a : [
            SELECT FEC_Service_Resource__c, FEC_Start_Date__c, FEC_End_Date__c
            FROM FEC_Service_Resource_Absence__c
            WHERE FEC_Service_Resource__c IN :uniqueSrIds
        ]) {
            if (a.FEC_Service_Resource__c == null || a.FEC_Start_Date__c == null || a.FEC_End_Date__c == null) {
                continue;
            }
            keys.add(
                String.valueOf(a.FEC_Service_Resource__c)
                + '|' + String.valueOf(a.FEC_Start_Date__c.getTime())
                + '|' + String.valueOf(a.FEC_End_Date__c.getTime())
            );
        }
        return keys;
    }

    private static Map<String, Id> resolveServiceResourceIds(Set<String> rawValues) {
        Map<String, Id> resolved = new Map<String, Id>();
        if (rawValues == null || rawValues.isEmpty()) {
            return resolved;
        }

        Set<Id> candidateIds = new Set<Id>();
        Set<String> names = new Set<String>();
        Set<String> emails = new Set<String>();
        for (String value : rawValues) {
            String v = FEC_BatchImportCommon.normalizeText(value);
            if (String.isBlank(v)) {
                continue;
            }
            if (isLikelySalesforceId(v)) {
                candidateIds.add((Id) v);
            } else {
                names.add(v);
                if (v.contains('@')) {
                    emails.add(v.toLowerCase());
                }
            }
        }

        for (ServiceResource sr : [
            SELECT Id, Name, RelatedRecordId
            FROM ServiceResource
            WHERE Id IN :candidateIds OR Name IN :names
        ]) {
            resolved.put(String.valueOf(sr.Id), sr.Id);
            if (String.isNotBlank(sr.Name)) {
                resolved.put(sr.Name.toLowerCase(), sr.Id);
            }
        }

        if (!emails.isEmpty()) {
            Map<String, Id> userByEmail = new Map<String, Id>();
            for (User u : [SELECT Id, Email FROM User WHERE Email IN :emails]) {
                if (String.isNotBlank(u.Email)) {
                    userByEmail.put(u.Email.toLowerCase(), u.Id);
                }
            }
            if (!userByEmail.isEmpty()) {
                for (ServiceResource srByUser : [
                    SELECT Id, RelatedRecordId
                    FROM ServiceResource
                    WHERE RelatedRecordId IN :userByEmail.values()
                ]) {
                    for (String email : userByEmail.keySet()) {
                        if (userByEmail.get(email) == srByUser.RelatedRecordId) {
                            resolved.put(email, srByUser.Id);
                        }
                    }
                }
            }
        }
        return resolved;
    }

    private static Datetime parseDateTimeStrict(String raw, Integer rowNumber, String label) {
        if (String.isBlank(raw)) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_Batch_Import_Field_Required, new List<String>{ String.valueOf(rowNumber), label })
            );
        }
        // Spec: yyyy-mm-ddThh:mm:ss.msmmsms+0700
        if (!Pattern.matches(FEC_ConstantCommon.PATTERN_BATCH_DATETIME_OFFSET, raw)) {
            throw new AuraHandledException(
                String.format(
                    System.Label.FEC_Batch_Import_Invalid_Datetime_Format,
                    new List<String>{ String.valueOf(rowNumber), label }
                )
            );
        }
        try {
            Integer tzPos = Math.max(raw.lastIndexOf('+'), raw.lastIndexOf('-'));
            String dateTimePart = raw.substring(0, tzPos); // yyyy-MM-ddTHH:mm:ss.SSS
            String offsetPart = raw.substring(tzPos); // +0700 / -0500
            String corePart = dateTimePart.substring(0, dateTimePart.indexOf('.')).replace('T', ' ');
            List<String> dateAndTime = corePart.split(' ');
            List<String> dateParts = dateAndTime[0].split('-');
            List<String> timeParts = dateAndTime[1].split(':');
            // Parse wall-clock components as GMT first — Datetime.valueOf() applies the
            // running user's timezone and would double-shift when offset is also applied.
            Datetime wallClockAsGmt = Datetime.newInstanceGmt(
                Integer.valueOf(dateParts[0]),
                Integer.valueOf(dateParts[1]),
                Integer.valueOf(dateParts[2]),
                Integer.valueOf(timeParts[0]),
                Integer.valueOf(timeParts[1]),
                Integer.valueOf(timeParts[2])
            );
            Integer sign = offsetPart.startsWith('-') ? -1 : 1;
            Integer tzHour = Integer.valueOf(offsetPart.substring(1, 3));
            Integer tzMin = Integer.valueOf(offsetPart.substring(3, 5));
            Integer offsetMinutes = sign * (tzHour * 60 + tzMin);

            // Convert input local time with explicit offset to UTC datetime.
            return wallClockAsGmt.addMinutes(-offsetMinutes);
        } catch (Exception e) {
            throw new AuraHandledException(
                String.format(
                    System.Label.FEC_Batch_Import_Invalid_Datetime_Format,
                    new List<String>{ String.valueOf(rowNumber), label }
                )
            );
        }
    }

    private static Boolean isLikelySalesforceId(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        Integer len = value.length();
        if (len != 15 && len != 18) {
            return false;
        }
        return Pattern.matches(FEC_ConstantCommon.PATTERN_ALPHANUMERIC, value);
    }

    private static Integer countFailedRowResults(List<RowResult> rowResults) {
        Integer failedCount = 0;
        if (rowResults == null) {
            return failedCount;
        }
        for (RowResult rr : rowResults) {
            if ('Failed'.equals(rr.status)) {
                failedCount += 1;
            }
        }
        return failedCount;
    }

    private static void markAllRowResultsFailedForBatchNoImport(List<RowResult> rowResults) {
        if (rowResults == null) {
            return;
        }
        for (RowResult rr : rowResults) {
            rr.status = 'Failed';
            rr.recordId = '';
        }
    }

    private static void applyBatchImportFailureOutcome(
        Map<String, Schema.SObjectField> fieldMap,
        SObject batchRow,
        Integer totalCount,
        Integer failedCount,
        String batchFailureReason
    ) {
        FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Failure');
        FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
        FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, totalCount);
        FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
        FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, failedCount);
        FEC_BatchImportCommon.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, batchFailureReason);
        update batchRow;
    }

    /** Ghi log khi không có file đính kèm / không parse được — trạng thái Processed (đã tiếp nhận yêu cầu). */
    private static void upsertFailedBatch(String fileName, String templateName, String reason) {
        insertFailureRow(fileName, templateName, reason, 'Processed');
    }

    /** Lỗi cấu hình / exception khi xử lý — Failure. */
    private static void upsertSystemFailureBatch(String fileName, String templateName, String reason) {
        insertFailureRow(fileName, templateName, reason, 'Failure');
    }

    private static void insertFailureRow(String fileName, String templateName, String reason, String statusValue) {
        try {
            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(OBJECT_API_NAME);
            if (sObjType == null) {
                return;
            }
            Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();
            SObject failedRow = sObjType.newSObject();
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'Name', 'FEC_File_Name__c' }, fileName);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Status__c' }, statusValue);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Result__c' }, 'Result');
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Failure_Reason__c' }, reason);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Template__c', 'FEC_Template_Name__c' }, templateName);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, 0);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
            insert failedRow;
        } catch (Exception ex) {
            // avoid masking original error
        }
    }

}