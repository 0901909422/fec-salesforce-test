public with sharing class FEC_BatchCaseCreationController {
    private static final String OBJECT_API_NAME = 'FEC_Batch_Case_Creation__c';
    private static final String TEMPLATE_OBJECT_API_NAME = 'FEC_Template_Import__c';
    private static final String TEMPLATE_APPLICABLE_VALUE = 'Batch Case Creation';
    private static final Integer MAX_ROWS = 200;

    public class TemplateOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Id templateId;
        @AuraEnabled public String downloadUrl;
    }

    public class CaseRowResult {
        @AuraEnabled public String layout;
        @AuraEnabled public String contractNumber;
        @AuraEnabled public String interactionPhone;
        @AuraEnabled public String productType;
        @AuraEnabled public String category;
        @AuraEnabled public String subCategory;
        @AuraEnabled public String subCode;
        @AuraEnabled public String caseStatus;
        @AuraEnabled public String caseRemarks;
        @AuraEnabled public String interactionChannel;
        @AuraEnabled public String interactionSubChannel;
        @AuraEnabled public String interactionEmail;
        @AuraEnabled public String recordId;
        @AuraEnabled public String status;
        @AuraEnabled public String errors;
        @AuraEnabled public String finalStatus;
        @AuraEnabled public String interactionId;
        @AuraEnabled public String caseBusinessId;
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
                String latestVersionId = String.valueOf(link.ContentDocument.LatestPublishedVersionId);
                if (String.isNotBlank(latestVersionId)) {
                    option.downloadUrl = '/sfc/servlet.shepherd/version/download/' + latestVersionId;
                }
            }
        }
        return output;
    }

    @AuraEnabled
    public static List<FEC_BatchDataCreationController.BatchRow> getRecentRows() {
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(OBJECT_API_NAME);
        if (sObjType == null) {
            return new List<FEC_BatchDataCreationController.BatchRow>();
        }

        Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();
        String fileField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_File_Name__c', 'Name' });
        String fileContentDocumentIdField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_File_Content_Document_Id__c' });
        String uploadedOnField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_Uploaded_On__c', 'CreatedDate' });
        String totalRecordsField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_Total_Records__c', 'FEC_Total_Records_Count__c' });
        String totalSuccessField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_Total_Success_Records__c' });
        String totalFailedField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_Total_Failed_Records__c' });
        String statusField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_Status__c' });
        String failureReasonField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_Failure_Reason__c' });
        String resultField = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FEC_Result__c' });

        List<String> selectParts = new List<String>{ 'Id', 'Name', 'CreatedDate', 'CreatedBy.Email' };
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
        List<FEC_BatchDataCreationController.BatchRow> output = new List<FEC_BatchDataCreationController.BatchRow>();
        Map<Id, String> resultUrlByBatchId = new Map<Id, String>();
        Map<Id, String> sourceUrlByBatchId = new Map<Id, String>();
        Set<Id> batchIds = new Set<Id>();
        for (SObject row : rows) {
            batchIds.add((Id) row.get('Id'));
        }
        if (!batchIds.isEmpty()) {
            for (ContentDocumentLink link : [
                SELECT LinkedEntityId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :batchIds
                ORDER BY LinkedEntityId, SystemModstamp DESC
            ]) {
                String title = link.ContentDocument == null ? null : link.ContentDocument.Title;
                String versionId = String.valueOf(link.ContentDocument.LatestPublishedVersionId);
                if (String.isBlank(versionId) || String.isBlank(title)) {
                    continue;
                }
                if (title.toLowerCase().endsWith('_result')) {
                    if (!resultUrlByBatchId.containsKey(link.LinkedEntityId)) {
                        resultUrlByBatchId.put(link.LinkedEntityId, '/sfc/servlet.shepherd/version/download/' + versionId);
                    }
                } else if (!sourceUrlByBatchId.containsKey(link.LinkedEntityId)) {
                    sourceUrlByBatchId.put(link.LinkedEntityId, '/sfc/servlet.shepherd/version/download/' + versionId);
                }
            }
        }

        for (SObject row : rows) {
            FEC_BatchDataCreationController.BatchRow dto = new FEC_BatchDataCreationController.BatchRow();
            dto.id = (Id) row.get('Id');
            dto.fileName = FEC_BatchImportCommon.asString(FEC_BatchImportCommon.getFieldValue(row, fileField));
            if (String.isBlank(dto.fileName)) {
                dto.fileName = FEC_BatchImportCommon.asString(row.get('Name'));
            }
            String sourceDocumentId = String.isBlank(fileContentDocumentIdField)
                ? null
                : FEC_BatchImportCommon.asString(FEC_BatchImportCommon.getFieldValue(row, fileContentDocumentIdField));
            dto.fileDownloadUrl = sourceUrlByBatchId.get(dto.id);
            if (String.isBlank(dto.fileDownloadUrl) && String.isNotBlank(sourceDocumentId)) {
                dto.fileDownloadUrl = '/sfc/servlet.shepherd/document/download/' + sourceDocumentId;
            }
            dto.uploadedOn = FEC_BatchImportCommon.asDatetime(FEC_BatchImportCommon.getFieldValue(row, uploadedOnField));
            if (dto.uploadedOn == null) {
                dto.uploadedOn = FEC_BatchImportCommon.asDatetime(row.get('CreatedDate'));
            }
            SObject createdBy = row.getSObject('CreatedBy');
            dto.uploadedBy = createdBy == null ? null : (String) createdBy.get('Email');
            dto.totalRecordsCount = asDecimal(FEC_BatchImportCommon.getFieldValue(row, totalRecordsField));
            dto.totalSuccessRecords = asDecimal(FEC_BatchImportCommon.getFieldValue(row, totalSuccessField));
            dto.totalFailedRecords = asDecimal(FEC_BatchImportCommon.getFieldValue(row, totalFailedField));
            dto.status = FEC_BatchImportCommon.asString(FEC_BatchImportCommon.getFieldValue(row, statusField));
            dto.failureReason = FEC_BatchImportCommon.asString(FEC_BatchImportCommon.getFieldValue(row, failureReasonField));
            dto.result = FEC_BatchImportCommon.asString(FEC_BatchImportCommon.getFieldValue(row, resultField));
            dto.resultDownloadUrl = resultUrlByBatchId.get(dto.id);
            output.add(dto);
        }
        return output;
    }

    @AuraEnabled
    public static FEC_BatchDataCreationController.ImportResult importBatchData(
        String fileName,
        String fileBodyBase64,
        String templateName,
        String rowsJson
    ) {
        FEC_BatchDataCreationController.ImportResult out = new FEC_BatchDataCreationController.ImportResult();
        out.success = false;

        if (String.isBlank(fileName) || String.isBlank(fileBodyBase64) || String.isBlank(rowsJson)) {
            out.message = 'Please select a file before importing.';
            upsertFailedBatch(fileName, templateName, out.message);
            return out;
        }

        Schema.SObjectType batchType = Schema.getGlobalDescribe().get(OBJECT_API_NAME);
        if (batchType == null) {
            out.message = OBJECT_API_NAME + ' is not available in this org.';
            upsertFailedBatch(fileName, templateName, out.message);
            return out;
        }

        Map<String, Schema.SObjectField> batchFieldMap = batchType.getDescribe().fields.getMap();
        SObject batchRow;
        try {
            List<Object> inputRows = (List<Object>) JSON.deserializeUntyped(rowsJson);
            if (inputRows == null || inputRows.isEmpty()) {
                out.message = 'Vui lòng đính kèm tệp dữ liệu';
                upsertFailedBatch(fileName, templateName, out.message);
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

            batchRow = batchType.newSObject();
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'Name', 'FEC_File_Name__c' }, fileName);
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Uploaded');
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, '');
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Template__c', 'FEC_Template_Name__c' }, templateName);
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_File_Content_Document_Id__c' }, String.valueOf(insertedCv.ContentDocumentId));
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Records__c', 'FEC_Total_Records_Count__c' }, inputRows.size());
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, '');
            insert batchRow;
            FEC_BatchImportCommon.linkFileToBatch((Id) batchRow.get('Id'), insertedCv.ContentDocumentId);

            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processing');
            update batchRow;

            List<CaseRowResult> rowResults = FEC_BatchCaseCreationService.processImportRows(inputRows, templateName);
            Integer totalCount = rowResults.size();

            Set<Id> insertedCaseIds = new Set<Id>();
            for (CaseRowResult rr : rowResults) {
                if ('Succeeded'.equals(rr.status) && String.isNotBlank(rr.recordId)) {
                    insertedCaseIds.add(Id.valueOf(rr.recordId));
                }
            }

            Map<Id, Case> finalById = new Map<Id, Case>();
            if (!insertedCaseIds.isEmpty()) {
                finalById = new Map<Id, Case>([
                    SELECT
                        Id,
                        Status,
                        FEC_Interaction_ID__c,
                        FEC_Case_ID__c,
                        FEC_Interaction__c,
                        FEC_Interaction__r.FEC_Interaction_ID__c,
                        FEC_Interaction__r.FEC_Case_ID__c,
                        FEC_Interaction__r.Id
                    FROM Case
                    WHERE Id IN :insertedCaseIds
                ]);
            }
            for (CaseRowResult rr : rowResults) {
                if ('Succeeded'.equals(rr.status) && String.isNotBlank(rr.recordId)) {
                    Case c = finalById.get((Id) rr.recordId);
                    rr.finalStatus = c == null ? '' : c.Status;
                    rr.interactionId = '';
                    if (c != null) {
                        rr.interactionId = normalizeCaseBusinessId(c.FEC_Interaction_ID__c);
                        if (String.isBlank(rr.interactionId) && c.FEC_Interaction__r != null) {
                            rr.interactionId = normalizeCaseBusinessId(c.FEC_Interaction__r.FEC_Interaction_ID__c);
                        }
                        if (String.isBlank(rr.interactionId) && c.FEC_Interaction__r != null) {
                            rr.interactionId = normalizeCaseBusinessId(c.FEC_Interaction__r.FEC_Case_ID__c);
                        }
                        if (String.isBlank(rr.interactionId) && c.FEC_Interaction__r != null) {
                            rr.interactionId = String.valueOf(c.FEC_Interaction__r.Id);
                        }
                    }
                    rr.caseBusinessId = c == null ? '' : normalizeCaseBusinessId(c.FEC_Case_ID__c);
                } else {
                    rr.finalStatus = '';
                    rr.interactionId = '';
                    rr.caseBusinessId = '';
                }
            }

            Integer successCount = 0;
            Integer failedCount = 0;
            for (CaseRowResult rr : rowResults) {
                if ('Succeeded'.equals(rr.status)) {
                    successCount += 1;
                } else if ('Failed'.equals(rr.status)) {
                    failedCount += 1;
                }
            }

            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processed');
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Records__c', 'FEC_Total_Records_Count__c' }, totalCount);
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, successCount);
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, failedCount);
            FEC_BatchImportCommon.putIfFieldExists(
                batchFieldMap,
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
                    FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Failure');
                    FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
                    FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, ex.getMessage());
                    update batchRow;
                } catch (Exception e) {
                    upsertFailedBatch(fileName, templateName, ex.getMessage());
                }
            } else {
                upsertFailedBatch(fileName, templateName, ex.getMessage());
            }
            out.message = ex.getMessage();
            return out;
        }
    }

    @AuraEnabled
    public static void saveResultFile(Id batchRecordId, String resultFileName, String fileBodyBase64) {
        FEC_BatchDataCreationController.saveResultFile(batchRecordId, resultFileName, fileBodyBase64);
    }

    @AuraEnabled
    public static void logFailedImport(String fileName, String templateName, String reason) {
        upsertFailedBatch(fileName, templateName, reason);
    }

    private static void upsertFailedBatch(String fileName, String templateName, String reason) {
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
            FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Status__c' }, 'Failure');
            FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Result__c' }, 'Result');
            FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Failure_Reason__c' }, reason);
            FEC_BatchImportCommon.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Template__c', 'FEC_Template_Name__c' }, templateName);
            insert failedRow;
        } catch (Exception ex) {
        }
    }

    /**
     * Một số org lưu FEC_Case_ID__c dưới dạng hyperlink HTML (<a href=...>S-2063</a>).
     * Khi export result cần chỉ lấy text hiển thị để tránh lộ raw HTML trong Excel.
     */
    private static String normalizeCaseBusinessId(String rawValue) {
        if (String.isBlank(rawValue)) {
            return '';
        }
        String s = rawValue.trim();
        Matcher m = Pattern.compile('>([^<]+)<').matcher(s);
        if (m.find()) {
            return m.group(1);
        }
        return s.replaceAll('<[^>]*>', '').trim();
    }
}
