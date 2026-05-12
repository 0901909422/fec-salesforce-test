public with sharing class FEC_BatchCaseCreationController {
    private static final String OBJECT_API_NAME = 'FEC_Batch_Case_Creation__c';
    private static final String CASE_RECORD_TYPE_DEVELOPER_NAME = 'Customer_Case';
    private static final String TEMPLATE_OBJECT_API_NAME = 'FEC_Template_Import__c';
    private static final String TEMPLATE_APPLICABLE_VALUE = 'Batch Case Creation';
    private static final Integer MAX_ROWS = 200;

    private static final List<String> CUSTOMER_CASE_STATUS_VALUES = new List<String>{
        'Open',
        'Pending',
        'Resolved-AutoCancelled',
        'Resolved-Cancelled',
        'Resolved-CannotContactCustomer',
        'Resolved-Completed',
        'Resolved-Rejected'
    };

    /** Template import có chứa chuỗi này → luồng Welcome Call (Interaction + Customer Case). */
    private static final String WELCOME_CALL_TEMPLATE_TOKEN = 'welcome call';
    private static final String WELCOME_CALL_TEMPLATE_TOKEN_COMPACT = 'welcomecall';
    private static final String WELCOME_CALL_CHANNEL_VALUE = 'Outbound';
    private static final String WELCOME_CALL_SUB_CHANNEL_VALUE = 'Outbound Call';

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

    private class ParsedCaseRow {
        String layout;
        String contractNumber;
        String interactionPhone;
        String productType;
        String category;
        String subCategory;
        String subCode;
        String caseStatus;
        String caseRemarks;
        String interactionChannel;
        String interactionSubChannel;
        String interactionEmail;
    }

    private class LookupMaps {
        Map<String, String> productMap;
        Map<String, String> categoryMap;
        Map<String, String> subCategoryMap;
        Map<String, String> subCodeMap;
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
            String nameValue = row.get('Name') == null ? null : String.valueOf(row.get('Name'));
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
        String fileField = pickField(fieldMap, new List<String>{ 'FEC_File_Name__c', 'Name' });
        String fileContentDocumentIdField = pickField(fieldMap, new List<String>{ 'FEC_File_Content_Document_Id__c' });
        String uploadedOnField = pickField(fieldMap, new List<String>{ 'FEC_Uploaded_On__c', 'CreatedDate' });
        String totalRecordsField = pickField(fieldMap, new List<String>{ 'FEC_Total_Records__c', 'FEC_Total_Records_Count__c' });
        String totalSuccessField = pickField(fieldMap, new List<String>{ 'FEC_Total_Success_Records__c' });
        String totalFailedField = pickField(fieldMap, new List<String>{ 'FEC_Total_Failed_Records__c' });
        String statusField = pickField(fieldMap, new List<String>{ 'FEC_Status__c' });
        String failureReasonField = pickField(fieldMap, new List<String>{ 'FEC_Failure_Reason__c' });
        String resultField = pickField(fieldMap, new List<String>{ 'FEC_Result__c' });

        List<String> selectParts = new List<String>{ 'Id', 'Name', 'CreatedDate', 'CreatedBy.Email' };
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
            dto.fileName = asString(getFieldValue(row, fileField));
            if (String.isBlank(dto.fileName)) {
                dto.fileName = asString(row.get('Name'));
            }
            String sourceDocumentId = String.isBlank(fileContentDocumentIdField)
                ? null
                : asString(getFieldValue(row, fileContentDocumentIdField));
            dto.fileDownloadUrl = sourceUrlByBatchId.get(dto.id);
            if (String.isBlank(dto.fileDownloadUrl) && String.isNotBlank(sourceDocumentId)) {
                dto.fileDownloadUrl = '/sfc/servlet.shepherd/document/download/' + sourceDocumentId;
            }
            dto.uploadedOn = asDatetime(getFieldValue(row, uploadedOnField));
            if (dto.uploadedOn == null) {
                dto.uploadedOn = asDatetime(row.get('CreatedDate'));
            }
            SObject createdBy = row.getSObject('CreatedBy');
            dto.uploadedBy = createdBy == null ? null : (String) createdBy.get('Email');
            dto.totalRecordsCount = asDecimal(getFieldValue(row, totalRecordsField));
            dto.totalSuccessRecords = asDecimal(getFieldValue(row, totalSuccessField));
            dto.totalFailedRecords = asDecimal(getFieldValue(row, totalFailedField));
            dto.status = asString(getFieldValue(row, statusField));
            dto.failureReason = asString(getFieldValue(row, failureReasonField));
            dto.result = asString(getFieldValue(row, resultField));
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

            batchRow = batchType.newSObject();
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'Name', 'FEC_File_Name__c' }, fileName);
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Uploaded');
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, '');
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Template__c', 'FEC_Template_Name__c' }, templateName);
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_File_Content_Document_Id__c' }, String.valueOf(insertedCv.ContentDocumentId));
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Records__c', 'FEC_Total_Records_Count__c' }, inputRows.size());
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, '');
            insert batchRow;
            linkFileToBatch((Id) batchRow.get('Id'), insertedCv.ContentDocumentId);

            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processing');
            update batchRow;

            List<ParsedCaseRow> parsed = parseInputRows(inputRows);
            Boolean isWelcomeFlow = isWelcomeCallInput(templateName, parsed);
            List<CaseRowResult> rowResults = validateAndBuildCases(parsed, isWelcomeFlow);
            Integer totalCount = rowResults.size();

            // Row-by-row: dòng pass validation thì insert, dòng fail giữ nguyên status='Failed' và errors,
            // KHÔNG còn rollback toàn bộ vì có dòng lỗi như trước.
            if (isWelcomeFlow) {
                insertWelcomeCallCases(parsed, rowResults);
            } else {
                insertStandardCasesWithInteraction(parsed, rowResults);
            }

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

            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processed');
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Records__c', 'FEC_Total_Records_Count__c' }, totalCount);
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, successCount);
            putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, failedCount);
            putIfFieldExists(
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
                    putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Failure');
                    putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
                    putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, ex.getMessage());
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

    private static List<ParsedCaseRow> parseInputRows(List<Object> inputRows) {
        List<ParsedCaseRow> out = new List<ParsedCaseRow>();
        for (Object rowObj : inputRows) {
            Map<String, Object> m = (Map<String, Object>) rowObj;
            ParsedCaseRow r = new ParsedCaseRow();
            r.layout = normalizeText(m.get('layout'));
            r.contractNumber = normalizeText(m.get('contractNumber'));
            r.interactionPhone = normalizeText(m.get('interactionPhone'));
            r.productType = normalizeText(m.get('productType'));
            r.category = normalizeText(m.get('category'));
            r.subCategory = normalizeText(m.get('subCategory'));
            r.subCode = normalizeText(m.get('subCode'));
            r.caseStatus = normalizeText(m.get('caseStatus'));
            r.caseRemarks = normalizeText(m.get('caseRemarks'));
            r.interactionChannel = normalizeText(m.get('interactionChannel'));
            r.interactionSubChannel = normalizeText(m.get('interactionSubChannel'));
            r.interactionEmail = normalizeText(m.get('interactionEmail'));
            out.add(r);
        }
        return out;
    }

    private static List<CaseRowResult> validateAndBuildCases(List<ParsedCaseRow> parsed, Boolean welcome) {
        LookupMaps maps = loadLookupMaps(parsed);

        Schema.DescribeFieldResult channelDfr = Case.FEC_Channel__c.getDescribe();
        Schema.DescribeFieldResult subChannelDfr = Case.FEC_Interaction_Subchannel__c.getDescribe();
        Schema.DescribeFieldResult statusDfr = Case.Status.getDescribe();

        List<CaseRowResult> rowResults = new List<CaseRowResult>();

        for (ParsedCaseRow r : parsed) {
            CaseRowResult rr = toRowResultShell(r);
            List<String> errs = new List<String>();

            Boolean extended = 'extended'.equalsIgnoreCase(r.layout);
            if (!extended && !'simple'.equalsIgnoreCase(r.layout)) {
                errs.add('layout không hợp lệ.');
            }

            if (String.isBlank(r.contractNumber)) {
                errs.add('Contract Number là bắt buộc.');
            }
            if (String.isBlank(r.interactionPhone)) {
                errs.add('Interaction Phone là bắt buộc.');
            }
            if (String.isBlank(r.productType)) {
                errs.add('Product Type là bắt buộc.');
            }
            if (String.isBlank(r.category)) {
                errs.add('Category là bắt buộc.');
            }
            if (String.isBlank(r.subCategory)) {
                errs.add('Sub Category là bắt buộc.');
            }
            if (String.isBlank(r.subCode)) {
                errs.add('Sub Code là bắt buộc.');
            }
            if (!welcome && String.isBlank(r.caseStatus)) {
                errs.add('Case Status là bắt buộc.');
            }

            if (extended) {
                if (String.isBlank(r.interactionChannel)) {
                    errs.add('Interaction Channel là bắt buộc.');
                }
                if (String.isBlank(r.interactionSubChannel)) {
                    errs.add('Interaction Sub Channel là bắt buộc.');
                }
            }

            Id productId = lookupFromMap(r.productType, maps.productMap);
            Id categoryId = lookupFromMap(r.category, maps.categoryMap);
            Id subCategoryId = lookupFromMap(r.subCategory, maps.subCategoryMap);
            Id subCodeId = lookupFromMap(r.subCode, maps.subCodeMap);

            if (String.isNotBlank(r.productType) && productId == null) {
                errs.add('Không tìm thấy Product Type.');
            }
            if (String.isNotBlank(r.category) && categoryId == null) {
                errs.add('Không tìm thấy Category.');
            }
            if (String.isNotBlank(r.subCategory) && subCategoryId == null) {
                errs.add('Không tìm thấy Sub Category.');
            }
            if (String.isNotBlank(r.subCode) && subCodeId == null) {
                errs.add('Không tìm thấy Sub Code.');
            }

            if (!welcome) {
                String statusApi = matchCaseStatus(statusDfr, r.caseStatus);
                if (String.isBlank(statusApi)) {
                    errs.add('Case Status không hợp lệ.');
                }
            }

            if (extended) {
                String channelApi = matchPicklist(channelDfr, r.interactionChannel);
                String subChannelApi = matchPicklist(subChannelDfr, r.interactionSubChannel);
                if (String.isNotBlank(r.interactionChannel) && channelApi == null) {
                    errs.add('Interaction Channel không hợp lệ.');
                }
                if (String.isNotBlank(r.interactionSubChannel) && subChannelApi == null) {
                    errs.add('Interaction Sub Channel không hợp lệ.');
                }
            }

            if (String.isNotBlank(r.interactionEmail) && !Pattern.matches('^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$', r.interactionEmail)) {
                errs.add('Interaction Email không đúng định dạng.');
            }

            rr.status = errs.isEmpty() ? 'Succeeded' : 'Failed';
            rr.errors = errs.isEmpty() ? '' : String.join(errs, ' ');
            rowResults.add(rr);
        }

        return rowResults;
    }

    private static List<Case> buildCasesFromResults(List<ParsedCaseRow> parsed) {
        Id rtId = getCustomerCaseRecordTypeId();
        if (rtId == null) {
            throw new AuraHandledException('Không tìm thấy Record Type Customer Case.');
        }

        LookupMaps maps = loadLookupMaps(parsed);
        Schema.DescribeFieldResult channelDfr = Case.FEC_Channel__c.getDescribe();
        Schema.DescribeFieldResult subChannelDfr = Case.FEC_Interaction_Subchannel__c.getDescribe();
        Schema.DescribeFieldResult statusDfr = Case.Status.getDescribe();

        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < parsed.size(); i++) {
            ParsedCaseRow r = parsed[i];
            String statusApi = matchCaseStatus(statusDfr, r.caseStatus);

            Case c = new Case();
            c.RecordTypeId = rtId;
            c.Subject = buildSubject(r.contractNumber);
            c.Status = statusApi;
            applyNatureFields(c, r, maps, channelDfr, subChannelDfr);

            cases.add(c);
        }
        return cases;
    }

    private static LookupMaps loadLookupMaps(List<ParsedCaseRow> parsed) {
        Set<String> prodKeys = new Set<String>();
        Set<String> catKeys = new Set<String>();
        Set<String> subCatKeys = new Set<String>();
        Set<String> subCodeKeys = new Set<String>();
        for (ParsedCaseRow r : parsed) {
            addLookupKeys(prodKeys, r.productType);
            addLookupKeys(catKeys, r.category);
            addLookupKeys(subCatKeys, r.subCategory);
            addLookupKeys(subCodeKeys, r.subCode);
        }
        LookupMaps lm = new LookupMaps();
        lm.productMap = loadProductTypeMap(prodKeys);
        lm.categoryMap = loadCategoryMap(catKeys);
        lm.subCategoryMap = loadSubCategoryMap(subCatKeys);
        lm.subCodeMap = loadSubCodeMap(subCodeKeys);
        return lm;
    }

    private static void applyNatureFields(
        Case c,
        ParsedCaseRow r,
        LookupMaps maps,
        Schema.DescribeFieldResult channelDfr,
        Schema.DescribeFieldResult subChannelDfr
    ) {
        Boolean extended = 'extended'.equalsIgnoreCase(r.layout);
        Id productId = lookupFromMap(r.productType, maps.productMap);
        Id categoryId = lookupFromMap(r.category, maps.categoryMap);
        Id subCategoryId = lookupFromMap(r.subCategory, maps.subCategoryMap);
        Id subCodeId = lookupFromMap(r.subCode, maps.subCodeMap);
        c.FEC_Contract_Number__c = r.contractNumber;
        c.FEC_Phone_Number__c = r.interactionPhone;
        c.FEC_Remarks__c = r.caseRemarks;
        c.FEC_Product_Type__c = productId;
        c.FEC_Category__c = categoryId;
        c.FEC_SubCategory__c = subCategoryId;
        c.FEC_SubCode__c = subCodeId;
        if (extended) {
            c.FEC_Channel__c = matchPicklist(channelDfr, r.interactionChannel);
            c.FEC_Interaction_Subchannel__c = matchPicklist(subChannelDfr, r.interactionSubChannel);
            if (String.isNotBlank(r.interactionEmail)) {
                c.FEC_Interaction_Email__c = r.interactionEmail;
            }
        }
    }

    private static Boolean isWelcomeCallTemplate(String templateName) {
        if (String.isBlank(templateName)) {
            return false;
        }
        String lowered = templateName.toLowerCase();
        if (lowered.contains(WELCOME_CALL_TEMPLATE_TOKEN)) {
            return true;
        }
        String compact = lowered.replaceAll('[^a-z0-9]', '');
        return compact.contains(WELCOME_CALL_TEMPLATE_TOKEN_COMPACT);
    }

    private static Boolean isWelcomeCallInput(String templateName, List<ParsedCaseRow> parsed) {
        if (isWelcomeCallTemplate(templateName)) {
            return true;
        }
        if (parsed == null || parsed.isEmpty()) {
            return false;
        }
        for (ParsedCaseRow r : parsed) {
            if (looksLikeWelcomeValue(r.category) || looksLikeWelcomeValue(r.subCategory) || looksLikeWelcomeValue(r.subCode)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean looksLikeWelcomeValue(String raw) {
        if (String.isBlank(raw)) {
            return false;
        }
        String lowered = raw.toLowerCase();
        if (lowered.contains('welcome') || lowered.contains('wc_')) {
            return true;
        }
        String compact = lowered.replaceAll('[^a-z0-9]', '');
        return compact.contains('welcomecall') || compact.startsWith('wc');
    }

    private static String formatSaveResultErrors(Database.SaveResult sr) {
        List<String> parts = new List<String>();
        for (Database.Error err : sr.getErrors()) {
            parts.add(err.getMessage());
        }
        return String.join(parts, ' ');
    }

    private static String truncateWelcomeSubject(String prefix, String contractNumber) {
        String base = prefix + (String.isNotBlank(contractNumber) ? contractNumber : 'Unknown');
        if (base.length() > 255) {
            return base.substring(0, 255);
        }
        return base;
    }

    private static void applyWelcomeInteractionDefaults(Case interactionCase) {
        // Welcome Call chỉ ép theo custom status field theo yêu cầu nghiệp vụ.
        Map<String, Schema.SObjectField> caseFieldMap = Case.SObjectType.getDescribe().fields.getMap();
        putIfFieldExists(caseFieldMap, interactionCase, new List<String>{ 'FEC_Interaction_Status__c' }, 'Closed');
    }

    private static void applyWelcomeCustomerDefaults(Case customerCase) {
        // Welcome Call chỉ ép theo custom status field theo yêu cầu nghiệp vụ.
        Map<String, Schema.SObjectField> caseFieldMap = Case.SObjectType.getDescribe().fields.getMap();
        putIfFieldExists(caseFieldMap, customerCase, new List<String>{ 'FEC_Case_Status__c' }, 'Resolved-Completed');
    }

    private static void applyWelcomeChannelDefaults(
        Case caseToFill,
        Schema.DescribeFieldResult channelDfr,
        Schema.DescribeFieldResult subChannelDfr
    ) {
        String channelApi = matchPicklist(channelDfr, WELCOME_CALL_CHANNEL_VALUE);
        String subChannelApi = matchPicklist(subChannelDfr, WELCOME_CALL_SUB_CHANNEL_VALUE);
        caseToFill.FEC_Channel__c = String.isNotBlank(channelApi) ? channelApi : WELCOME_CALL_CHANNEL_VALUE;
        caseToFill.FEC_Interaction_Subchannel__c = String.isNotBlank(subChannelApi) ? subChannelApi : WELCOME_CALL_SUB_CHANNEL_VALUE;
    }

    private static void insertWelcomeCallCases(List<ParsedCaseRow> parsed, List<CaseRowResult> rowResults) {
        Id intRt = FEC_CommonUltils.getRecordTypeIdByDev(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);
        Id custRt = getCustomerCaseRecordTypeId();
        if (intRt == null) {
            throw new AuraHandledException('Không tìm thấy Record Type Interaction.');
        }
        if (custRt == null) {
            throw new AuraHandledException('Không tìm thấy Record Type Customer Case.');
        }

        LookupMaps maps = loadLookupMaps(parsed);
        Schema.DescribeFieldResult channelDfr = Case.FEC_Channel__c.getDescribe();
        Schema.DescribeFieldResult subChannelDfr = Case.FEC_Interaction_Subchannel__c.getDescribe();

        // Chỉ build & insert những dòng pass validation; dòng Failed bỏ qua, không insert.
        List<Case> interactionCases = new List<Case>();
        List<Integer> interactionOrigRowIndex = new List<Integer>();
        for (Integer i = 0; i < parsed.size(); i++) {
            if (!'Succeeded'.equals(rowResults[i].status)) {
                continue;
            }
            ParsedCaseRow r = parsed[i];
            Case ic = new Case();
            ic.RecordTypeId = intRt;
            applyWelcomeInteractionDefaults(ic);
            ic.Subject = truncateWelcomeSubject('Welcome Call Interaction - ', r.contractNumber);
            applyNatureFields(ic, r, maps, channelDfr, subChannelDfr);
            applyWelcomeChannelDefaults(ic, channelDfr, subChannelDfr);
            interactionCases.add(ic);
            interactionOrigRowIndex.add(i);
        }

        if (interactionCases.isEmpty()) {
            return;
        }

        Database.SaveResult[] srInt = Database.insert(interactionCases, false);

        List<Case> customerCases = new List<Case>();
        List<Integer> customerOrigRowIndex = new List<Integer>();
        for (Integer k = 0; k < srInt.size(); k++) {
            Integer origIdx = interactionOrigRowIndex[k];
            if (!srInt[k].isSuccess()) {
                CaseRowResult rr = rowResults[origIdx];
                rr.status = 'Failed';
                rr.recordId = '';
                rr.errors = formatSaveResultErrors(srInt[k]);
                continue;
            }
            ParsedCaseRow r = parsed[origIdx];
            Case cc = new Case();
            cc.RecordTypeId = custRt;
            cc.FEC_Interaction__c = srInt[k].getId();
            applyWelcomeCustomerDefaults(cc);
            cc.Subject = truncateWelcomeSubject('Welcome Call Case - ', r.contractNumber);
            applyNatureFields(cc, r, maps, channelDfr, subChannelDfr);
            applyWelcomeChannelDefaults(cc, channelDfr, subChannelDfr);
            customerCases.add(cc);
            customerOrigRowIndex.add(origIdx);
        }

        Database.SaveResult[] srCust = customerCases.isEmpty() ? null : Database.insert(customerCases, false);
        if (srCust != null) {
            for (Integer k = 0; k < srCust.size(); k++) {
                Integer origIdx = customerOrigRowIndex[k];
                CaseRowResult rr = rowResults[origIdx];
                if (srCust[k].isSuccess()) {
                    rr.recordId = srCust[k].getId();
                    rr.status = 'Succeeded';
                    rr.errors = '';
                } else {
                    rr.status = 'Failed';
                    rr.recordId = '';
                    rr.errors =
                        'Interaction đã tạo nhưng Case Customer không tạo được: ' + formatSaveResultErrors(srCust[k]);
                }
            }
        }
    }

    private static void insertStandardCasesWithInteraction(List<ParsedCaseRow> parsed, List<CaseRowResult> rowResults) {
        Id intRt = FEC_CommonUltils.getRecordTypeIdByDev(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);
        Id custRt = getCustomerCaseRecordTypeId();
        if (intRt == null) {
            throw new AuraHandledException('Không tìm thấy Record Type Interaction.');
        }
        if (custRt == null) {
            throw new AuraHandledException('Không tìm thấy Record Type Customer Case.');
        }

        LookupMaps maps = loadLookupMaps(parsed);
        Schema.DescribeFieldResult channelDfr = Case.FEC_Channel__c.getDescribe();
        Schema.DescribeFieldResult subChannelDfr = Case.FEC_Interaction_Subchannel__c.getDescribe();
        Schema.DescribeFieldResult statusDfr = Case.Status.getDescribe();

        List<Case> interactionCases = new List<Case>();
        List<Integer> interactionOrigRowIndex = new List<Integer>();
        for (Integer i = 0; i < parsed.size(); i++) {
            if (!'Succeeded'.equals(rowResults[i].status)) {
                continue;
            }
            ParsedCaseRow r = parsed[i];
            Case ic = new Case();
            ic.RecordTypeId = intRt;
            ic.Subject = truncateWelcomeSubject('Batch Interaction - ', r.contractNumber);
            applyNatureFields(ic, r, maps, channelDfr, subChannelDfr);
            interactionCases.add(ic);
            interactionOrigRowIndex.add(i);
        }

        if (interactionCases.isEmpty()) {
            return;
        }

        Database.SaveResult[] srInt = Database.insert(interactionCases, false);
        List<Case> customerCases = new List<Case>();
        List<Integer> customerOrigRowIndex = new List<Integer>();

        for (Integer k = 0; k < srInt.size(); k++) {
            Integer origIdx = interactionOrigRowIndex[k];
            if (!srInt[k].isSuccess()) {
                CaseRowResult rr = rowResults[origIdx];
                rr.status = 'Failed';
                rr.recordId = '';
                rr.errors = formatSaveResultErrors(srInt[k]);
                continue;
            }
            ParsedCaseRow r = parsed[origIdx];
            String statusApi = matchCaseStatus(statusDfr, r.caseStatus);
            Case cc = new Case();
            cc.RecordTypeId = custRt;
            cc.FEC_Interaction__c = srInt[k].getId();
            cc.Subject = buildSubject(r.contractNumber);
            cc.Status = statusApi;
            applyNatureFields(cc, r, maps, channelDfr, subChannelDfr);
            customerCases.add(cc);
            customerOrigRowIndex.add(origIdx);
        }

        Database.SaveResult[] srCust = customerCases.isEmpty() ? null : Database.insert(customerCases, false);
        if (srCust != null) {
            for (Integer k = 0; k < srCust.size(); k++) {
                Integer origIdx = customerOrigRowIndex[k];
                CaseRowResult rr = rowResults[origIdx];
                if (srCust[k].isSuccess()) {
                    rr.recordId = srCust[k].getId();
                    rr.status = 'Succeeded';
                    rr.errors = '';
                } else {
                    rr.status = 'Failed';
                    rr.recordId = '';
                    rr.errors = 'Interaction đã tạo nhưng Case Customer không tạo được: ' + formatSaveResultErrors(srCust[k]);
                }
            }
        }
    }

    private static String buildSubject(String contractNumber) {
        String base = 'Batch Case Creation';
        if (String.isNotBlank(contractNumber)) {
            base += ' - ' + contractNumber;
        }
        if (base.length() > 255) {
            return base.substring(0, 255);
        }
        return base;
    }

    private static CaseRowResult toRowResultShell(ParsedCaseRow r) {
        CaseRowResult rr = new CaseRowResult();
        rr.layout = r.layout;
        rr.contractNumber = r.contractNumber;
        rr.interactionPhone = r.interactionPhone;
        rr.productType = r.productType;
        rr.category = r.category;
        rr.subCategory = r.subCategory;
        rr.subCode = r.subCode;
        rr.caseStatus = r.caseStatus;
        rr.caseRemarks = r.caseRemarks;
        rr.interactionChannel = r.interactionChannel;
        rr.interactionSubChannel = r.interactionSubChannel;
        rr.interactionEmail = r.interactionEmail;
        rr.recordId = '';
        rr.finalStatus = '';
        rr.interactionId = '';
        rr.caseBusinessId = '';
        return rr;
    }

    private static void addLookupKeys(Set<String> keys, String raw) {
        if (String.isBlank(raw)) {
            return;
        }
        keys.add(raw.trim().toLowerCase());
        keys.add(extractCodeKey(raw).toLowerCase());
    }

    private static Id lookupFromMap(String raw, Map<String, String> m) {
        if (String.isBlank(raw) || m == null || m.isEmpty()) {
            return null;
        }
        String t = raw.trim();
        String s1 = m.get(t.toLowerCase());
        if (String.isNotBlank(s1)) {
            return (Id) s1;
        }
        String k = extractCodeKey(t);
        String s2 = m.get(k.toLowerCase());
        return String.isNotBlank(s2) ? (Id) s2 : null;
    }

    private static String extractCodeKey(String raw) {
        if (String.isBlank(raw)) {
            return '';
        }
        String t = raw.trim();
        Integer dash = t.indexOf('-');
        if (dash > 0) {
            return t.substring(0, dash).trim();
        }
        return t;
    }

    private static Map<String, String> loadProductTypeMap(Set<String> keys) {
        Map<String, String> idByKey = new Map<String, String>();
        if (keys == null || keys.isEmpty()) {
            return idByKey;
        }
        Set<String> candidates = new Set<String>();
        for (String k : keys) {
            if (String.isNotBlank(k)) {
                candidates.add(k);
            }
        }
        for (FEC_Product_Type__c rec : [
            SELECT Id, Name, FEC_Code__c
            FROM FEC_Product_Type__c
            WHERE FEC_Active__c = true AND (Name IN :candidates OR FEC_Code__c IN :candidates)
        ]) {
            String rid = String.valueOf(rec.Id);
            if (rec.Name != null) {
                idByKey.put(rec.Name.toLowerCase(), rid);
            }
            if (rec.FEC_Code__c != null) {
                idByKey.put(rec.FEC_Code__c.toLowerCase(), rid);
            }
        }
        return idByKey;
    }

    private static Map<String, String> loadCategoryMap(Set<String> keys) {
        Map<String, String> idByKey = new Map<String, String>();
        if (keys == null || keys.isEmpty()) {
            return idByKey;
        }
        Set<String> candidates = new Set<String>();
        for (String k : keys) {
            if (String.isNotBlank(k)) {
                candidates.add(k);
            }
        }
        for (FEC_Category__c rec : [
            SELECT Id, Name, FEC_Code__c
            FROM FEC_Category__c
            WHERE FEC_Active__c = true AND (Name IN :candidates OR FEC_Code__c IN :candidates)
        ]) {
            String rid = String.valueOf(rec.Id);
            if (rec.Name != null) {
                idByKey.put(rec.Name.toLowerCase(), rid);
            }
            if (rec.FEC_Code__c != null) {
                idByKey.put(rec.FEC_Code__c.toLowerCase(), rid);
            }
        }
        return idByKey;
    }

    private static Map<String, String> loadSubCategoryMap(Set<String> keys) {
        Map<String, String> idByKey = new Map<String, String>();
        if (keys == null || keys.isEmpty()) {
            return idByKey;
        }
        Set<String> candidates = new Set<String>();
        for (String k : keys) {
            if (String.isNotBlank(k)) {
                candidates.add(k);
            }
        }
        for (FEC_Sub_Category__c rec : [
            SELECT Id, Name, FEC_Code__c
            FROM FEC_Sub_Category__c
            WHERE FEC_Active__c = true AND (Name IN :candidates OR FEC_Code__c IN :candidates)
        ]) {
            String rid = String.valueOf(rec.Id);
            if (rec.Name != null) {
                idByKey.put(rec.Name.toLowerCase(), rid);
            }
            if (rec.FEC_Code__c != null) {
                idByKey.put(rec.FEC_Code__c.toLowerCase(), rid);
            }
        }
        return idByKey;
    }

    private static Map<String, String> loadSubCodeMap(Set<String> keys) {
        Map<String, String> idByKey = new Map<String, String>();
        if (keys == null || keys.isEmpty()) {
            return idByKey;
        }
        Set<String> candidates = new Set<String>();
        for (String k : keys) {
            if (String.isNotBlank(k)) {
                candidates.add(k);
            }
        }
        for (FEC_Sub_Code__c rec : [
            SELECT Id, Name, FEC_Code__c
            FROM FEC_Sub_Code__c
            WHERE FEC_Active__c = true AND (Name IN :candidates OR FEC_Code__c IN :candidates)
        ]) {
            String rid = String.valueOf(rec.Id);
            if (rec.Name != null) {
                idByKey.put(rec.Name.toLowerCase(), rid);
            }
            if (rec.FEC_Code__c != null) {
                idByKey.put(rec.FEC_Code__c.toLowerCase(), rid);
            }
        }
        return idByKey;
    }

    private static String matchPicklist(Schema.DescribeFieldResult dfr, String raw) {
        if (String.isBlank(raw) || dfr == null) {
            return null;
        }
        String t = raw.trim();
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (!pe.isActive()) {
                continue;
            }
            if (t.equalsIgnoreCase(pe.getValue()) || t.equalsIgnoreCase(pe.getLabel())) {
                return pe.getValue();
            }
        }
        return null;
    }

    private static String matchCaseStatus(Schema.DescribeFieldResult statusDfr, String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String t = raw.trim();
        String direct = matchPicklist(statusDfr, t);
        if (String.isNotBlank(direct)) {
            return direct;
        }
        for (String allowed : CUSTOMER_CASE_STATUS_VALUES) {
            if (t.equalsIgnoreCase(allowed)) {
                return allowed;
            }
        }
        return null;
    }

    private static Id getCustomerCaseRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case' AND DeveloperName = :CASE_RECORD_TYPE_DEVELOPER_NAME
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
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
        }
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

    private static String normalizeText(Object value) {
        return value == null ? '' : String.valueOf(value).trim();
    }

    private static String asString(Object value) {
        return value == null ? null : String.valueOf(value);
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

    private static Object getFieldValue(SObject row, String fieldApiName) {
        if (row == null || String.isBlank(fieldApiName)) {
            return null;
        }
        return row.get(fieldApiName);
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