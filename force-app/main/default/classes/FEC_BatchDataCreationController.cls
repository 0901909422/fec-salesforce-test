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
                if (title.endsWith('_Result')) {
                    if (!resultUrlByBatchId.containsKey(link.LinkedEntityId)) {
                        resultUrlByBatchId.put(link.LinkedEntityId, '/sfc/servlet.shepherd/version/download/' + versionId);
                    }
                } else if (!sourceUrlByBatchId.containsKey(link.LinkedEntityId)) {
                    sourceUrlByBatchId.put(link.LinkedEntityId, '/sfc/servlet.shepherd/version/download/' + versionId);
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
            dto.fileDownloadUrl = sourceUrlByBatchId.get(dto.id);
            if (String.isBlank(dto.fileDownloadUrl) && String.isNotBlank(sourceDocumentId)) {
                dto.fileDownloadUrl = '/sfc/servlet.shepherd/document/download/' + sourceDocumentId;
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
            upsertFailedBatch(fileName, templateName, out.message);
            return out;
        }

        Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();
        SObject batchRow;
        try {
            List<Object> inputRows = (List<Object>) JSON.deserializeUntyped(rowsJson);
            if (inputRows == null || inputRows.isEmpty()) {
                out.message = 'Vui lòng đính kèm tệp dữ liệu';
                upsertFailedBatch(fileName, templateName, out.message);
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

            List<RowResult> rowResults = validateRows(inputRows);
            Integer failedCount = countFailedRows(rowResults);
            Integer totalCount = rowResults.size();
            if (failedCount > 0) {
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Failure');
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, totalCount);
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, totalCount);
                putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, 'Dữ liệu file import không hợp lệ.');
                update batchRow;

                out.success = true;
                out.message = 'Import request has been submitted.';
                out.batchRecordId = (Id) batchRow.get('Id');
                out.contentDocumentId = insertedCv.ContentDocumentId;
                out.status = 'Failure';
                out.resultRowsJson = JSON.serialize(rowResults);
                return out;
            }

            List<FEC_Service_Resource_Absence__c> absences = mapRowsToAbsences(inputRows);
            insert absences;
            for (Integer i = 0; i < rowResults.size(); i += 1) {
                rowResults[i].recordId = String.valueOf(absences[i].Id);
            }

            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processed');
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, totalCount);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, totalCount);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, '');
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
    public static void logFailedImport(String fileName, String templateName, String reason) {
        upsertFailedBatch(fileName, templateName, reason);
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

    private static List<RowResult> validateRows(List<Object> inputRows) {
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
            if (String.isNotBlank(rr.serviceResource) && rr.serviceResource.contains('@') && !Pattern.matches('^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$', rr.serviceResource)) {
                errs.add('Service Resource không đúng định dạng (thiếu @ hoặc .).');
            }

            Id srId = serviceResourceByKey.get(rr.serviceResource.toLowerCase());
            if (srId == null) {
                srId = serviceResourceByKey.get(rr.serviceResource);
            }
            if (String.isNotBlank(rr.serviceResource) && srId == null) {
                errs.add('Service Resource không tồn tại.');
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
                if (uniqueKeys.contains(uniqueKey)) {
                    errs.add('Trùng giá trị Service Resource và Start Date và End Date.');
                } else {
                    uniqueKeys.add(uniqueKey);
                }
            }

            if (!errs.isEmpty()) {
                rr.status = 'Failed';
                rr.errors = String.join(errs, ' ');
            }
        }

        if (countFailedRows(output) > 0) {
            for (RowResult rr : output) {
                if (rr.status == 'Succeeded') {
                    rr.status = 'Failed';
                    rr.errors = 'Không insert do có dòng lỗi trong file.';
                }
            }
        }
        return output;
    }

    private static Integer countFailedRows(List<RowResult> rowResults) {
        Integer countFailed = 0;
        for (RowResult rr : rowResults) {
            if (rr != null && rr.status == 'Failed') {
                countFailed += 1;
            }
        }
        return countFailed;
    }

    private static List<FEC_Service_Resource_Absence__c> mapRowsToAbsences(List<Object> inputRows) {
        Schema.SObjectType absenceType = Schema.getGlobalDescribe().get(ABSENCE_OBJECT_API_NAME);
        if (absenceType == null) {
            throw new AuraHandledException(ABSENCE_OBJECT_API_NAME + ' is not available in this org.');
        }

        Set<String> rawValues = new Set<String>();
        for (Object rowObj : inputRows) {
            Map<String, Object> row = (Map<String, Object>) rowObj;
            String sr = normalizeText(row.get('serviceResource'));
            if (String.isNotBlank(sr)) {
                rawValues.add(sr);
            }
        }
        Map<String, Id> serviceResourceByKey = resolveServiceResourceIds(rawValues);

        List<FEC_Service_Resource_Absence__c> output = new List<FEC_Service_Resource_Absence__c>();
        Integer rowNumber = 1;
        for (Object rowObj : inputRows) {
            rowNumber += 1;
            Map<String, Object> row = (Map<String, Object>) rowObj;
            String srRaw = normalizeText(row.get('serviceResource'));
            String startRaw = normalizeText(row.get('startDate'));
            String endRaw = normalizeText(row.get('endDate'));
            String noteRaw = normalizeText(row.get('note'));

            if (String.isBlank(srRaw) || String.isBlank(startRaw) || String.isBlank(endRaw)) {
                throw new AuraHandledException('Dòng ' + rowNumber + ': phải nhập đủ Service Resource, Start Date, End Date.');
            }

            Id serviceResourceId = serviceResourceByKey.get(srRaw.toLowerCase());
            if (serviceResourceId == null) {
                serviceResourceId = serviceResourceByKey.get(srRaw);
            }
            if (serviceResourceId == null) {
                throw new AuraHandledException('Dòng ' + rowNumber + ': không tìm thấy Service Resource "' + srRaw + '".');
            }

            Datetime startDt = parseDateTimeStrict(startRaw, rowNumber, 'Start Date');
            Datetime endDt = parseDateTimeStrict(endRaw, rowNumber, 'End Date');
            if (endDt < startDt) {
                throw new AuraHandledException('Dòng ' + rowNumber + ': End Date phải lớn hơn hoặc bằng Start Date.');
            }

            FEC_Service_Resource_Absence__c rec = new FEC_Service_Resource_Absence__c();
            rec.FEC_Service_Resource__c = serviceResourceId;
            rec.FEC_Start_Date__c = startDt;
            rec.FEC_End_Date__c = endDt;
            rec.FEC_Note__c = noteRaw;
            output.add(rec);
        }
        return output;
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

    private static void upsertFailedBatch(String fileName, String templateName, String reason) {
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
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Status__c' }, 'Failure');
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Result__c' }, 'Result');
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Failure_Reason__c' }, reason);
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Template__c', 'FEC_Template_Name__c' }, templateName);
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