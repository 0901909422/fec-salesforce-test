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
            String nameValue = asString(row.get('Name'));
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
                String latestVersionId = String.valueOf(link.ContentDocument.LatestPublishedVersionId);
                if (String.isNotBlank(latestVersionId)) {
                    option.downloadUrl = '/sfc/servlet.shepherd/version/download/' + latestVersionId;
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
        String fileField = pickField(fieldMap, new List<String>{ 'FEC_File_Name__c', 'Name' });
        String fileContentDocumentIdField = pickField(fieldMap, new List<String>{ 'FEC_File_Content_Document_Id__c' });
        String uploadedOnField = pickField(fieldMap, new List<String>{ 'FEC_Uploaded_On__c', 'CreatedDate' });
        String totalRecordsField = pickField(fieldMap, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' });
        String totalSuccessField = pickField(fieldMap, new List<String>{ 'FEC_Total_Success_Records__c' });
        String totalFailedField = pickField(fieldMap, new List<String>{ 'FEC_Total_Failed_Records__c' });
        String statusField = pickField(fieldMap, new List<String>{ 'FEC_Status__c' });
        String failureReasonField = pickField(fieldMap, new List<String>{ 'FEC_Failure_Reason__c' });
        String resultField = pickField(fieldMap, new List<String>{ 'FEC_Result__c' });

        List<String> selectParts = new List<String>{ 'Id', 'CreatedBy.Email' };
        addIfNotBlank(selectParts, fileField);
        addIfNotBlank(selectParts, fileContentDocumentIdField);
        addIfNotBlank(selectParts, uploadedOnField);
        addIfNotBlank(selectParts, totalRecordsField);
        addIfNotBlank(selectParts, totalSuccessField);
        addIfNotBlank(selectParts, totalFailedField);
        addIfNotBlank(selectParts, statusField);
        addIfNotBlank(selectParts, failureReasonField);
        addIfNotBlank(selectParts, resultField);

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
                String docIdStr = asString(row.get(fileContentDocumentIdField));
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
                String versionId = String.valueOf(link.ContentDocument.LatestPublishedVersionId);
                if (String.isBlank(versionId) || String.isBlank(title)) {
                    continue;
                }
                Id sourceDocId = sourceDocIdByBatchId.get(link.LinkedEntityId);
                String url = '/sfc/servlet.shepherd/version/download/' + versionId;
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
            dto.fileName = asString(row.get(fileField));
            String sourceDocumentId = String.isBlank(fileContentDocumentIdField)
                ? null
                : asString(row.get(fileContentDocumentIdField));
            // Luôn ưu tiên ContentDocumentId đã lưu trên batch = file gốc import (ổn định hơn heuristic theo Title).
            if (String.isNotBlank(sourceDocumentId)) {
                dto.fileDownloadUrl = '/sfc/servlet.shepherd/document/download/' + sourceDocumentId;
            } else {
                dto.fileDownloadUrl = sourceUrlByBatchId.get(dto.id);
            }
            dto.uploadedOn = asDatetime(row.get(uploadedOnField));
            SObject createdBy = row.getSObject('CreatedBy');
            dto.uploadedBy = createdBy == null ? null : (String) createdBy.get('Email');
            dto.totalRecordsCount = asDecimal(row.get(totalRecordsField));
            dto.totalSuccessRecords = asDecimal(row.get(totalSuccessField));
            dto.totalFailedRecords = asDecimal(row.get(totalFailedField));
            dto.status = asString(row.get(statusField));
            dto.failureReason = asString(row.get(failureReasonField));
            dto.result = asString(row.get(resultField));
            dto.resultDownloadUrl = resultUrlByBatchId.get(dto.id);
            output.add(dto);
        }
        return output;
    }

    private static void linkFileToBatch(Id batchId, Id contentDocumentId) {
        if (batchId == null || contentDocumentId == null) {
            return;
        }
        try {
            ContentDocumentLink link = new ContentDocumentLink();
            link.LinkedEntityId = batchId;
            link.ContentDocumentId = contentDocumentId;
            link.ShareType = 'V';
            link.Visibility = 'AllUsers';
            insert link;
        } catch (DmlException ex) {
            // continue without blocking import if file is already linked
        }
    }

    @AuraEnabled
    public static ImportResult importBatchData(String fileName, String fileBodyBase64, String templateName, String rowsJson) {
        ImportResult out = new ImportResult();
        out.success = false;

        if (String.isBlank(fileName) || String.isBlank(fileBodyBase64) || String.isBlank(rowsJson)) {
            out.message = 'Please select a file before importing.';
            upsertFailedBatch(fileName, templateName, out.message);
            return out;
        }

        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(OBJECT_API_NAME);
        if (sObjType == null) {
            out.message = OBJECT_API_NAME + ' is not available in this org.';
            upsertSystemFailureBatch(fileName, templateName, out.message);
            return out;
        }

        Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();
        SObject batchRow;
        try {
            List<Object> inputRows = (List<Object>) JSON.deserializeUntyped(rowsJson);
            if (inputRows == null || inputRows.isEmpty()) {
                ContentVersion cvEmpty = new ContentVersion();
                cvEmpty.Title = removeFileExtension(fileName);
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
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'Name', 'FEC_File_Name__c' }, fileName);
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processed');
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Template__c', 'FEC_Template_Name__c' }, templateName);
                putIfFieldExists(
                    fieldMap,
                    batchRow,
                    new List<String>{ 'FEC_File_Content_Document_Id__c' },
                    String.valueOf(insertedCvEmpty.ContentDocumentId)
                );
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, 0);
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
                putIfFieldExists(
                    fieldMap,
                    batchRow,
                    new List<String>{ 'FEC_Failure_Reason__c' },
                    'Vui lòng đính kèm tệp dữ liệu'
                );
                insert batchRow;
                linkFileToBatch((Id) batchRow.get('Id'), insertedCvEmpty.ContentDocumentId);

                out.success = true;
                out.message = 'Import request has been submitted.';
                out.batchRecordId = (Id) batchRow.get('Id');
                out.contentDocumentId = insertedCvEmpty.ContentDocumentId;
                out.status = 'Processed';
                out.resultRowsJson = '[]';
                return out;
            }
            System.debug(((Map<String, Object>) inputRows[0]).get('note'));
            ContentVersion cv = new ContentVersion();
            cv.Title = removeFileExtension(fileName);
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
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'Name', 'FEC_File_Name__c' }, fileName);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Uploaded');
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, '');
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Template__c', 'FEC_Template_Name__c' }, templateName);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_File_Content_Document_Id__c' }, String.valueOf(insertedCv.ContentDocumentId));
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, inputRows.size());
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, '');
            insert batchRow;
            linkFileToBatch((Id) batchRow.get('Id'), insertedCv.ContentDocumentId);

            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processing');
            update batchRow;

            ValidationOutput vo = validateAndBuildAbsences(inputRows);
            List<RowResult> rowResults = vo.rowResults;
            Integer totalCount = rowResults.size();

            // Tách các record sẵn sàng insert + ghi nhớ index gốc để map ngược recordId.
            List<FEC_Service_Resource_Absence__c> toInsert = new List<FEC_Service_Resource_Absence__c>();
            List<Integer> originalIdxByInsertIdx = new List<Integer>();
            for (Integer i = 0; i < vo.absencesByIndex.size(); i += 1) {
                FEC_Service_Resource_Absence__c rec = vo.absencesByIndex[i];
                if (rec != null) {
                    toInsert.add(rec);
                    originalIdxByInsertIdx.add(i);
                }
            }

            Set<Id> insertedIds = new Set<Id>();
            if (!toInsert.isEmpty()) {
                Database.SaveResult[] saveResults = Database.insert(toInsert, false);
                for (Integer k = 0; k < saveResults.size(); k += 1) {
                    Database.SaveResult srRes = saveResults[k];
                    Integer originalIdx = originalIdxByInsertIdx[k];
                    if (srRes.isSuccess()) {
                        insertedIds.add(srRes.getId());
                    } else {
                        // DML lỗi → đánh dấu Failed cho dòng đó (giữ các dòng khác đã insert thành công).
                        List<String> dmlErrs = new List<String>();
                        for (Database.Error err : srRes.getErrors()) {
                            dmlErrs.add(err.getMessage());
                        }
                        rowResults[originalIdx].status = 'Failed';
                        rowResults[originalIdx].errors = String.join(dmlErrs, ' ');
                        rowResults[originalIdx].recordId = '';
                    }
                }

                // Query Name (Auto Number) cho các record vừa insert.
                Map<Id, FEC_Service_Resource_Absence__c> nameById = insertedIds.isEmpty()
                    ? new Map<Id, FEC_Service_Resource_Absence__c>()
                    : new Map<Id, FEC_Service_Resource_Absence__c>([
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

            Integer successCount = 0;
            Integer failedCount = 0;
            for (RowResult rr : rowResults) {
                if (rr.status == 'Succeeded') {
                    successCount += 1;
                } else if (rr.status == 'Failed') {
                    failedCount += 1;
                }
            }

            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processed');
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, totalCount);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, successCount);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, failedCount);
            putIfFieldExists(
                fieldMap,
                batchRow,
                new List<String>{ 'FEC_Failure_Reason__c' },
                failedCount > 0 ? 'Có ' + failedCount + ' dòng dữ liệu không hợp lệ.' : ''
            );
            update batchRow;

            out.success = true;
            out.message = 'Import request has been submitted.';
            out.batchRecordId = (Id) batchRow.get('Id');
            out.contentDocumentId = insertedCv.ContentDocumentId;
            out.status = 'Processed';
            out.resultRowsJson = JSON.serialize(rowResults);
            return out;
        } catch (Exception ex) {
            if (batchRow != null && batchRow.get('Id') != null) {
                try {
                    putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Failure');
                    putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
                    putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, ex.getMessage());
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
                cv.Title = removeFileExtension(fileName);
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
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'Name', 'FEC_File_Name__c' }, fileName);
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Status__c' }, 'Processed');
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Result__c' }, 'Result');
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Failure_Reason__c' }, reason);
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Template__c', 'FEC_Template_Name__c' }, templateName);
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, 0);
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
            if (contentDocumentId != null) {
                putIfFieldExists(
                    fieldMap,
                    failedRow,
                    new List<String>{ 'FEC_File_Content_Document_Id__c' },
                    String.valueOf(contentDocumentId)
                );
            }
            insert failedRow;

            if (contentDocumentId != null) {
                linkFileToBatch((Id) failedRow.get('Id'), contentDocumentId);
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
        cv.Title = removeFileExtension(resultFileName);
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
            rr.serviceResource = normalizeText(row.get('serviceResource'));
            rr.startDate = normalizeText(row.get('startDate'));
            rr.endDate = normalizeText(row.get('endDate'));
            rr.note = normalizeText(row.get('note'));
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
                errs.add('Thiếu giá trị Service Resource.');
            }
            if (String.isBlank(rr.startDate)) {
                errs.add('Thiếu giá trị Start Date.');
            }
            if (String.isBlank(rr.endDate)) {
                errs.add('Thiếu giá trị End Date.');
            }
            if (String.isNotBlank(rr.note) && rr.note.length() > 255) {
                errs.add('Note vượt quá số ký tự cho phép (255 ký tự).');
            }

            Boolean isEmailFormat = String.isNotBlank(rr.serviceResource)
                && Pattern.matches('^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$', rr.serviceResource);
            if (String.isNotBlank(rr.serviceResource) && !isEmailFormat) {
                errs.add('Service Resource không đúng định dạng (thiếu @ hoặc .).');
            }

            Id srId = null;
            if (isEmailFormat) {
                srId = serviceResourceByKey.get(rr.serviceResource.toLowerCase());
                if (srId == null) {
                    srId = serviceResourceByKey.get(rr.serviceResource);
                }
                if (srId == null) {
                    errs.add('Service Resource không tồn tại.');
                }
            }

            Datetime startDt;
            Datetime endDt;
            if (String.isNotBlank(rr.startDate)) {
                try {
                    startDt = parseDateTimeStrict(rr.startDate, rowNumber, 'Start Date');
                } catch (Exception e) {
                    errs.add('Start Date không đúng định dạng.');
                }
            }
            if (String.isNotBlank(rr.endDate)) {
                try {
                    endDt = parseDateTimeStrict(rr.endDate, rowNumber, 'End Date');
                } catch (Exception e) {
                    errs.add('End Date không đúng định dạng.');
                }
            }

            if (startDt != null && endDt != null && endDt < startDt) {
                errs.add('End Date nhỏ hơn Start Date.');
            }
            Datetime nowGmt = System.now();
            if (startDt != null && startDt < nowGmt) {
                errs.add('Start Date là thời điểm trong quá khứ.');
            }
            if (endDt != null && endDt < nowGmt) {
                errs.add('End Date là thời điểm trong quá khứ.');
            }
            if (srId != null && startDt != null && endDt != null) {
                String uniqueKey = String.valueOf(srId) + '|' + String.valueOf(startDt.getTime()) + '|' + String.valueOf(endDt.getTime());
                if (dbExistingKeys.contains(uniqueKey)) {
                    errs.add('Service Resource đã có Absence trùng giá trị trong hệ thống.');
                } else if (uniqueKeys.contains(uniqueKey)) {
                    errs.add('Trùng giá trị Service Resource và Start Date và End Date.');
                } else {
                    uniqueKeys.add(uniqueKey);
                }
            }

            if (!errs.isEmpty()) {
                rr.status = 'Failed';
                rr.errors = String.join(errs, ' ');
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
            String v = normalizeText(value);
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
            throw new AuraHandledException('Dòng ' + rowNumber + ': ' + label + ' không được để trống.');
        }
        // Spec: yyyy-mm-ddThh:mm:ss.msmmsms+0700
        if (!Pattern.matches('^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}[+-]\\d{4}$', raw)) {
            throw new AuraHandledException(
                'Dòng ' + rowNumber + ': ' + label + ' không đúng định dạng yyyy-mm-ddThh:mm:ss.msmmsms+0700.'
            );
        }
        try {
            Integer tzPos = Math.max(raw.lastIndexOf('+'), raw.lastIndexOf('-'));
            String dateTimePart = raw.substring(0, tzPos); // yyyy-MM-ddTHH:mm:ss.SSS
            String offsetPart = raw.substring(tzPos); // +0700 / -0500
            String corePart = dateTimePart.substring(0, dateTimePart.indexOf('.')).replace('T', ' ');

            Datetime localDt = Datetime.valueOf(corePart);
            Integer sign = offsetPart.startsWith('-') ? -1 : 1;
            Integer tzHour = Integer.valueOf(offsetPart.substring(1, 3));
            Integer tzMin = Integer.valueOf(offsetPart.substring(3, 5));
            Integer offsetMinutes = sign * (tzHour * 60 + tzMin);

            // Convert input local time with explicit offset to UTC datetime.
            return localDt.addMinutes(-offsetMinutes);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Dòng ' + rowNumber + ': ' + label + ' không đúng định dạng yyyy-mm-ddThh:mm:ss.msmmsms+0700.'
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
        return Pattern.matches('[a-zA-Z0-9]+', value);
    }

    private static String normalizeText(Object value) {
        if (value == null) {
            return '';
        }
        return String.valueOf(value).trim();
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
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'Name', 'FEC_File_Name__c' }, fileName);
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Status__c' }, statusValue);
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Result__c' }, 'Result');
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Failure_Reason__c' }, reason);
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Template__c', 'FEC_Template_Name__c' }, templateName);
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, 0);
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
            insert failedRow;
        } catch (Exception ex) {
            // avoid masking original error
        }
    }

    private static void addIfNotBlank(List<String> selectParts, String fieldApiName) {
        if (String.isNotBlank(fieldApiName) && !selectParts.contains(fieldApiName)) {
            selectParts.add(fieldApiName);
        }
    }

    private static String pickField(Map<String, Schema.SObjectField> fieldMap, List<String> preferredNames) {
        for (String name : preferredNames) {
            if (fieldMap.containsKey(name)) {
                return name;
            }
        }
        return null;
    }

    private static String asString(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Datetime asDatetime(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Datetime) {
            return (Datetime) value;
        }
        return null;
    }

    private static Decimal asDecimal(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Decimal) {
            return (Decimal) value;
        }
        if (value instanceof Integer) {
            return Decimal.valueOf((Integer) value);
        }
        if (value instanceof Long) {
            return Decimal.valueOf((Long) value);
        }
        return null;
    }

    private static void putIfFieldExists(
        Map<String, Schema.SObjectField> fieldMap,
        SObject recordToFill,
        List<String> fieldNames,
        Object value
    ) {
        for (String name : fieldNames) {
            if (!fieldMap.containsKey(name)) {
                continue;
            }
            Schema.DescribeFieldResult dfr = fieldMap.get(name).getDescribe();
            if (!dfr.isCreateable()) {
                continue;
            }
            if (dfr.isAutoNumber()) {
                continue;
            }
            if (!dfr.isCalculated()) {
                recordToFill.put(name, value);
                return;
            }
        }
    }

    private static String removeFileExtension(String fileName) {
        Integer idx = fileName == null ? -1 : fileName.lastIndexOf('.');
        if (idx == null || idx <= 0) {
            return fileName;
        }
        return fileName.substring(0, idx);
    }
}