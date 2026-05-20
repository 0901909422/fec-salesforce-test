public with sharing class FEC_BatchCaseCreationController {
    private static final String OBJECT_API_NAME = 'FEC_Batch_Case_Creation__c';
    private static final String TEMPLATE_OBJECT_API_NAME = 'FEC_Template_Import__c';
    private static final String TEMPLATE_APPLICABLE_VALUE = 'Batch Case Creation';
    private static final Integer MAX_ROWS = 200;

    /** Template import có chứa chuỗi này → luồng Welcome Call (Interaction + Customer Case). */
    private static final String WELCOME_CALL_TEMPLATE_TOKEN = 'welcome call';
    private static final String WELCOME_CALL_TEMPLATE_TOKEN_COMPACT = 'welcomecall';

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

    /** Bộ NOC (FEC_Nature_of_Case__c) active — validate phân cấp Product → Category → Sub Category → Sub Code (theo text import). */
    private class NatureOfCaseHierarchyMaps {
        Set<String> fullTextKeys = new Set<String>();
        Map<String, Set<String>> categoryTextKeysByProductId = new Map<String, Set<String>>();
        Map<String, Set<String>> subCategoryTextKeysByProductId = new Map<String, Set<String>>();
        Map<String, Set<String>> subCategoryTextKeysByProductCategory = new Map<String, Set<String>>();
        Map<String, Set<String>> subCodeTextKeysByProductCategorySubCategory = new Map<String, Set<String>>();
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
                    option.downloadUrl = FEC_ConstantCommon.CONTENT_VERSION_DOWNLOAD_URL_PREFIX + latestVersionId;
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
                        // skip invalid id
                    }
                }
            }
        }
        if (!batchIds.isEmpty()) {
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
                String url = FEC_ConstantCommon.CONTENT_VERSION_DOWNLOAD_URL_PREFIX + versionId;
                Id sourceDocId = sourceDocIdByBatchId.get(link.LinkedEntityId);
                if (sourceDocId != null) {
                    if (link.ContentDocumentId == sourceDocId) {
                        if (!sourceUrlByBatchId.containsKey(link.LinkedEntityId)) {
                            sourceUrlByBatchId.put(link.LinkedEntityId, url);
                        }
                    } else {
                        // File result upload sau (CreatedDate ASC) → ghi đè để lấy bản mới nhất (xlsx client).
                        resultUrlByBatchId.put(link.LinkedEntityId, url);
                    }
                } else if (FEC_BatchImportCommon.isResultContentTitle(title)) {
                    resultUrlByBatchId.put(link.LinkedEntityId, url);
                } else if (!sourceUrlByBatchId.containsKey(link.LinkedEntityId)) {
                    sourceUrlByBatchId.put(link.LinkedEntityId, url);
                } else {
                    resultUrlByBatchId.put(link.LinkedEntityId, url);
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
                dto.fileDownloadUrl = FEC_ConstantCommon.CONTENT_DOCUMENT_DOWNLOAD_URL_PREFIX + sourceDocumentId;
            }
            dto.uploadedOn = FEC_BatchImportCommon.asDatetime(FEC_BatchImportCommon.getFieldValue(row, uploadedOnField));
            if (dto.uploadedOn == null) {
                dto.uploadedOn = FEC_BatchImportCommon.asDatetime(row.get('CreatedDate'));
            }
            SObject createdBy = row.getSObject('CreatedBy');
            dto.uploadedBy = createdBy == null ? null : (String) createdBy.get('Email');
            dto.totalRecordsCount = FEC_BatchImportCommon.asDecimal(FEC_BatchImportCommon.getFieldValue(row, totalRecordsField));
            dto.totalSuccessRecords = FEC_BatchImportCommon.asDecimal(FEC_BatchImportCommon.getFieldValue(row, totalSuccessField));
            dto.totalFailedRecords = FEC_BatchImportCommon.asDecimal(FEC_BatchImportCommon.getFieldValue(row, totalFailedField));
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
            out.message = System.Label.FEC_Batch_Import_Select_File;
            upsertFailedBatch(fileName, templateName, out.message);
            return out;
        }

        Schema.SObjectType batchType = Schema.getGlobalDescribe().get(OBJECT_API_NAME);
        if (batchType == null) {
            out.message = String.format(System.Label.FEC_Batch_Import_Object_Not_Available, new List<String>{ OBJECT_API_NAME });
            upsertFailedBatch(fileName, templateName, out.message);
            return out;
        }

        Map<String, Schema.SObjectField> batchFieldMap = batchType.getDescribe().fields.getMap();
        SObject batchRow;
        try {
            List<Object> inputRows = (List<Object>) JSON.deserializeUntyped(rowsJson);
            if (inputRows == null || inputRows.isEmpty()) {
                out.message = System.Label.FEC_BCH_RequireFile;
                upsertFailedBatch(fileName, templateName, out.message);
                return out;
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = FEC_BatchImportCommon.normalizeSourceContentTitle(fileName);
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

            List<ParsedCaseRow> parsed = parseInputRows(inputRows);
            Boolean isWelcomeFlow = isWelcomeCallInput(templateName, parsed);
            List<CaseRowResult> rowResults = validateAndBuildCases(parsed, isWelcomeFlow);
            Integer totalCount = rowResults.size();
            Integer failedCount = countFailedRowResults(rowResults);
            String batchFailureReason = failedCount > 0
                ? String.format(System.Label.FEC_Batch_Import_Invalid_Row_Count, new List<String>{ String.valueOf(failedCount) })
                : '';

            // Có bất kỳ dòng lỗi validation → không import cả file, không tạo Case.
            if (failedCount > 0) {
                markAllRowResultsFailedForBatchNoImport(rowResults);
                applyBatchImportFailureOutcome(
                    batchFieldMap,
                    batchRow,
                    totalCount,
                    failedCount,
                    batchFailureReason,
                    fileName,
                    rowResults
                );
                out.success = false;
                out.message = batchFailureReason;
                out.batchRecordId = (Id) batchRow.get('Id');
                out.contentDocumentId = insertedCv.ContentDocumentId;
                out.status = 'Failure';
                out.resultRowsJson = JSON.serialize(rowResults);
                return out;
            }

            Savepoint importSavepoint = Database.setSavepoint();
            if (isWelcomeFlow) {
                insertWelcomeCallCases(parsed, rowResults);
            } else {
                insertStandardCasesWithInteraction(parsed, rowResults);
            }

            failedCount = countFailedRowResults(rowResults);
            if (failedCount > 0) {
                Database.rollback(importSavepoint);
                markRowResultsNotImportedAfterRollback(rowResults);
                markAllRowResultsFailedForBatchNoImport(rowResults);
                batchFailureReason = String.format(
                    System.Label.FEC_Batch_Import_Invalid_Row_Count,
                    new List<String>{ String.valueOf(failedCount) }
                );
                applyBatchImportFailureOutcome(
                    batchFieldMap,
                    batchRow,
                    totalCount,
                    failedCount,
                    batchFailureReason,
                    fileName,
                    rowResults
                );
                out.success = false;
                out.message = batchFailureReason;
                out.batchRecordId = (Id) batchRow.get('Id');
                out.contentDocumentId = insertedCv.ContentDocumentId;
                out.status = 'Failure';
                out.resultRowsJson = JSON.serialize(rowResults);
                return out;
            }

            enrichRowResultsFromInsertedCases(rowResults);

            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processed');
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Records__c', 'FEC_Total_Records_Count__c' }, totalCount);
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, totalCount);
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
            FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, '');
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

    private static List<ParsedCaseRow> parseInputRows(List<Object> inputRows) {
        List<ParsedCaseRow> out = new List<ParsedCaseRow>();
        for (Object rowObj : inputRows) {
            Map<String, Object> m = (Map<String, Object>) rowObj;
            ParsedCaseRow r = new ParsedCaseRow();
            r.layout = FEC_BatchImportCommon.normalizeText(m.get('layout'));
            r.contractNumber = FEC_BatchImportCommon.normalizeText(m.get('contractNumber'));
            r.interactionPhone = FEC_BatchImportCommon.normalizeText(m.get('interactionPhone'));
            r.productType = FEC_BatchImportCommon.normalizeText(m.get('productType'));
            r.category = FEC_BatchImportCommon.normalizeText(m.get('category'));
            r.subCategory = FEC_BatchImportCommon.normalizeText(m.get('subCategory'));
            r.subCode = FEC_BatchImportCommon.normalizeText(m.get('subCode'));
            r.caseStatus = FEC_BatchImportCommon.normalizeText(m.get('caseStatus'));
            r.caseRemarks = FEC_BatchImportCommon.normalizeText(m.get('caseRemarks'));
            r.interactionChannel = FEC_BatchImportCommon.normalizeText(m.get('interactionChannel'));
            r.interactionSubChannel = FEC_BatchImportCommon.normalizeText(m.get('interactionSubChannel'));
            r.interactionEmail = FEC_BatchImportCommon.normalizeText(m.get('interactionEmail'));
            out.add(r);
        }
        return out;
    }

    private static List<CaseRowResult> validateAndBuildCases(List<ParsedCaseRow> parsed, Boolean welcome) {
        LookupMaps maps = loadLookupMaps(parsed);

        Schema.DescribeFieldResult channelDfr = Case.FEC_Channel__c.getDescribe();
        Schema.DescribeFieldResult subChannelDfr = Case.FEC_Interaction_Subchannel__c.getDescribe();
        Schema.DescribeFieldResult statusDfr = Case.Status.getDescribe();
        Map<String, Set<String>> subChannelsByChannel = buildSubChannelsByChannelMap(channelDfr, subChannelDfr);

        Set<Id> productIdsForNoc = new Set<Id>();
        for (ParsedCaseRow rowForNoc : parsed) {
            Id productIdForNoc = lookupFromMap(rowForNoc.productType, maps.productMap);
            if (productIdForNoc != null) {
                productIdsForNoc.add(productIdForNoc);
            }
        }
        NatureOfCaseHierarchyMaps nocMaps = loadNatureOfCaseHierarchyMaps(productIdsForNoc);

        List<CaseRowResult> rowResults = new List<CaseRowResult>();

        for (ParsedCaseRow r : parsed) {
            CaseRowResult rr = toRowResultShell(r);
            List<String> errs = new List<String>();

            Boolean extended = 'extended'.equalsIgnoreCase(r.layout);
            if (!extended && !'simple'.equalsIgnoreCase(r.layout)) {
                errs.add(System.Label.FEC_Batch_Import_Invalid_Layout);
            }

            if (String.isBlank(r.contractNumber)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Account_Contract_Number);
            }
            if (String.isBlank(r.interactionPhone)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Interaction_Phone);
            } else if (!Pattern.matches(FEC_ConstantCommon.PATTERN_PHONE_NUMBER, r.interactionPhone)) {
                errs.add(System.Label.FEC_Batch_Import_Invalid_Interaction_Phone_Format);
            }
            if (String.isBlank(r.productType)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Product_Type);
            }
            if (String.isBlank(r.category)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Category);
            }
            if (String.isBlank(r.subCategory)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Sub_Category);
            }
            if (String.isBlank(r.subCode)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Sub_Code);
            }
            if (String.isBlank(r.caseRemarks)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Case_Remarks);
            }
            if (!welcome && String.isBlank(r.caseStatus)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Case_Status);
            }

            if (extended) {
                if (String.isBlank(r.interactionChannel)) {
                    errs.add(System.Label.FEC_Batch_Import_Required_Interaction_Channel);
                }
                if (String.isBlank(r.interactionSubChannel)) {
                    errs.add(System.Label.FEC_Batch_Import_Required_Interaction_Sub_Channel);
                }
            }

            Id productId = lookupFromMap(r.productType, maps.productMap);
            Id categoryId = lookupFromMap(r.category, maps.categoryMap);
            Id subCategoryId = lookupFromMap(r.subCategory, maps.subCategoryMap);
            Id subCodeId = lookupFromMap(r.subCode, maps.subCodeMap);

            if (String.isNotBlank(r.productType) && productId == null) {
                errs.add(System.Label.FEC_Batch_Import_Lookup_Product_Type_Not_Found);
            }
            if (String.isNotBlank(r.category) && categoryId == null) {
                errs.add(System.Label.FEC_Batch_Import_Lookup_Category_Not_Found);
            }
            if (String.isNotBlank(r.subCategory) && subCategoryId == null) {
                errs.add(System.Label.FEC_Batch_Import_Lookup_Sub_Category_Not_Found);
            }
            if (String.isNotBlank(r.subCode) && subCodeId == null) {
                errs.add(System.Label.FEC_Batch_Import_Lookup_Sub_Code_Not_Found);
            }

            if (!welcome) {
                String statusApi = matchBatchImportCaseStatus(statusDfr, r.caseStatus);
                if (String.isBlank(statusApi)) {
                    errs.add(System.Label.FEC_Batch_Import_Invalid_Case_Status);
                }
            }

            if (extended) {
                String channelApi = matchPicklist(channelDfr, r.interactionChannel);
                String subChannelApi = matchPicklist(subChannelDfr, r.interactionSubChannel);
                if (String.isNotBlank(r.interactionChannel) && channelApi == null) {
                    errs.add(System.Label.FEC_Batch_Import_Invalid_Interaction_Channel);
                }
                if (String.isNotBlank(r.interactionSubChannel) && subChannelApi == null) {
                    errs.add(System.Label.FEC_Batch_Import_Invalid_Interaction_Sub_Channel);
                }
                if (
                    String.isNotBlank(channelApi) &&
                    String.isNotBlank(subChannelApi) &&
                    !isSubChannelValidForChannel(channelApi, subChannelApi, subChannelsByChannel)
                ) {
                    errs.add(System.Label.FEC_Batch_Import_Invalid_Sub_Channel_For_Channel);
                }
            }

            if (String.isNotBlank(r.interactionEmail) && !Pattern.matches(FEC_ConstantCommon.PATTERN_EMAIL, r.interactionEmail)) {
                errs.add(System.Label.FEC_Batch_Import_Invalid_Interaction_Email);
            }

            // NOC: chạy khi đủ Product/Category/Sub Category/Sub Code (kể cả dòng còn lỗi Contract, Channel...)
            if (
                productId != null &&
                String.isNotBlank(r.productType) &&
                String.isNotBlank(r.category) &&
                String.isNotBlank(r.subCategory) &&
                String.isNotBlank(r.subCode)
            ) {
                appendNatureOfCaseValidationErrors(r, productId, nocMaps, errs);
            }

            rr.status = errs.isEmpty() ? 'Succeeded' : 'Failed';
            rr.errors = errs.isEmpty() ? '' : joinRowErrors(errs);
            rowResults.add(rr);
        }

        return rowResults;
    }

    private static List<Case> buildCasesFromResults(List<ParsedCaseRow> parsed) {
        Id rtId = FEC_BatchImportCommon.getCustomerCaseRecordTypeId();
        if (rtId == null) {
            throw new AuraHandledException(System.Label.FEC_Batch_Import_RT_Customer_Case_Not_Found);
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
        FEC_BatchImportCommon.putIfFieldExists(caseFieldMap, interactionCase, new List<String>{ 'FEC_Interaction_Status__c' }, FEC_ConstantCommon.INTERACTION_STATUS_CLOSED);
    }

    private static void applyWelcomeCustomerDefaults(Case customerCase) {
        // Welcome Call chỉ ép theo custom status field theo yêu cầu nghiệp vụ.
        Map<String, Schema.SObjectField> caseFieldMap = Case.SObjectType.getDescribe().fields.getMap();
        FEC_BatchImportCommon.putIfFieldExists(caseFieldMap, customerCase, new List<String>{ 'FEC_Case_Status__c' }, FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED);
    }

    private static void applyWelcomeChannelDefaults(
        Case caseToFill,
        Schema.DescribeFieldResult channelDfr,
        Schema.DescribeFieldResult subChannelDfr
    ) {
        String channelApi = matchPicklist(channelDfr, FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME);
        String subChannelApi = matchPicklist(subChannelDfr, FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME);
        caseToFill.FEC_Channel__c = String.isNotBlank(channelApi) ? channelApi : FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME;
        caseToFill.FEC_Interaction_Subchannel__c = String.isNotBlank(subChannelApi) ? subChannelApi : FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME;
    }

    private static void insertWelcomeCallCases(List<ParsedCaseRow> parsed, List<CaseRowResult> rowResults) {
        Id intRt = FEC_CommonUltils.getRecordTypeIdByDev(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);
        Id custRt = FEC_BatchImportCommon.getCustomerCaseRecordTypeId();
        if (intRt == null) {
            throw new AuraHandledException(System.Label.FEC_Batch_Import_RT_Interaction_Not_Found);
        }
        if (custRt == null) {
            throw new AuraHandledException(System.Label.FEC_Batch_Import_RT_Customer_Case_Not_Found);
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
                        String.format(
                            System.Label.FEC_Batch_Import_Welcome_Customer_Case_Failed,
                            new List<String>{ formatSaveResultErrors(srCust[k]) }
                        );
                }
            }
        }
    }

    private static void insertStandardCasesWithInteraction(List<ParsedCaseRow> parsed, List<CaseRowResult> rowResults) {
        Id intRt = FEC_CommonUltils.getRecordTypeIdByDev(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);
        Id custRt = FEC_BatchImportCommon.getCustomerCaseRecordTypeId();
        if (intRt == null) {
            throw new AuraHandledException(System.Label.FEC_Batch_Import_RT_Interaction_Not_Found);
        }
        if (custRt == null) {
            throw new AuraHandledException(System.Label.FEC_Batch_Import_RT_Customer_Case_Not_Found);
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
            String statusApi = matchBatchImportCaseStatus(statusDfr, r.caseStatus);
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
                    rr.errors = String.format(
                        System.Label.FEC_Batch_Import_Welcome_Customer_Case_Failed,
                        new List<String>{ formatSaveResultErrors(srCust[k]) }
                    );
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

    private static Set<String> natureTextAliases(String name, String code) {
        Set<String> aliases = new Set<String>();
        if (String.isNotBlank(name)) {
            aliases.add(name.trim().toLowerCase());
        }
        if (String.isNotBlank(code)) {
            aliases.add(code.trim().toLowerCase());
        }
        return aliases;
    }

    private static void addTextAliasesToSet(Set<String> target, Set<String> aliases) {
        if (target == null || aliases == null || aliases.isEmpty()) {
            return;
        }
        target.addAll(aliases);
    }

    private static Boolean natureInputMatches(Set<String> allowed, String raw) {
        if (allowed == null || allowed.isEmpty() || String.isBlank(raw)) {
            return false;
        }
        return allowed.contains(raw.trim().toLowerCase());
    }

    private static String joinRowErrors(List<String> errs) {
        List<String> normalized = new List<String>();
        if (errs == null) {
            return '';
        }
        for (String err : errs) {
            if (String.isBlank(err)) {
                continue;
            }
            String message = err.trim().replaceAll('[\\r\\n\\u2028\\u2029]+', ' ').replaceAll('\\s+', ' ');
            while (message.endsWith('.')) {
                message = message.substring(0, message.length() - 1).trim();
            }
            if (String.isNotBlank(message)) {
                normalized.add(message);
            }
        }
        return String.join(normalized, ', ');
    }

    private static Set<String> resolveSubCodesForCategorySubCategory(
        NatureOfCaseHierarchyMaps nocMaps,
        String productIdKey,
        String categoryRaw,
        String subCategoryRaw
    ) {
        if (nocMaps == null || String.isBlank(productIdKey) || String.isBlank(categoryRaw) || String.isBlank(subCategoryRaw)) {
            return null;
        }
        String categoryNorm = categoryRaw.trim().toLowerCase();
        String subCategoryNorm = subCategoryRaw.trim().toLowerCase();
        String directKey = productIdKey + '|' + categoryNorm + '|' + subCategoryNorm;
        Set<String> direct = nocMaps.subCodeTextKeysByProductCategorySubCategory.get(directKey);
        if (direct != null && !direct.isEmpty()) {
            return direct;
        }
        for (String mapKey : nocMaps.subCodeTextKeysByProductCategorySubCategory.keySet()) {
            if (!mapKey.startsWith(productIdKey + '|')) {
                continue;
            }
            List<String> parts = mapKey.split('\\|');
            if (parts.size() < 3) {
                continue;
            }
            String catAlias = parts[1];
            String subAlias = parts[2];
            if (catAlias.equals(categoryNorm) && subAlias.equals(subCategoryNorm)) {
                Set<String> codes = nocMaps.subCodeTextKeysByProductCategorySubCategory.get(mapKey);
                if (codes != null && !codes.isEmpty()) {
                    return codes;
                }
            }
        }
        return null;
    }

    private static NatureOfCaseHierarchyMaps loadNatureOfCaseHierarchyMaps(Set<Id> productIds) {
        NatureOfCaseHierarchyMaps out = new NatureOfCaseHierarchyMaps();
        if (productIds == null || productIds.isEmpty()) {
            return out;
        }
        for (FEC_Nature_of_Case__c noc : [
            SELECT
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_Sub_Category__c,
                FEC_Sub_Code__c,
                FEC_Product_Type__r.Name,
                FEC_Product_Type__r.FEC_Code__c,
                FEC_Category__r.Name,
                FEC_Category__r.FEC_Code__c,
                FEC_Sub_Category__r.Name,
                FEC_Sub_Category__r.FEC_Code__c,
                FEC_Sub_Code__r.Name,
                FEC_Sub_Code__r.FEC_Code__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Active__c = true AND FEC_Product_Type__c IN :productIds
        ]) {
            if (noc.FEC_Product_Type__c == null || noc.FEC_Category__c == null) {
                continue;
            }
            String productIdKey = String.valueOf(noc.FEC_Product_Type__c);
            Set<String> categoryAliases = natureTextAliases(
                noc.FEC_Category__r == null ? null : noc.FEC_Category__r.Name,
                noc.FEC_Category__r == null ? null : noc.FEC_Category__r.FEC_Code__c
            );
            if (categoryAliases.isEmpty()) {
                continue;
            }
            if (!out.categoryTextKeysByProductId.containsKey(productIdKey)) {
                out.categoryTextKeysByProductId.put(productIdKey, new Set<String>());
            }
            addTextAliasesToSet(out.categoryTextKeysByProductId.get(productIdKey), categoryAliases);

            Set<String> subCategoryAliases = natureTextAliases(
                noc.FEC_Sub_Category__r == null ? null : noc.FEC_Sub_Category__r.Name,
                noc.FEC_Sub_Category__r == null ? null : noc.FEC_Sub_Category__r.FEC_Code__c
            );
            if (!subCategoryAliases.isEmpty()) {
                if (!out.subCategoryTextKeysByProductId.containsKey(productIdKey)) {
                    out.subCategoryTextKeysByProductId.put(productIdKey, new Set<String>());
                }
                addTextAliasesToSet(
                    out.subCategoryTextKeysByProductId.get(productIdKey),
                    subCategoryAliases
                );
            }
            Set<String> subCodeAliases = natureTextAliases(
                noc.FEC_Sub_Code__r == null ? null : noc.FEC_Sub_Code__r.Name,
                noc.FEC_Sub_Code__r == null ? null : noc.FEC_Sub_Code__r.FEC_Code__c
            );

            for (String categoryAlias : categoryAliases) {
                String productCategoryKey = productIdKey + '|' + categoryAlias;
                if (!subCategoryAliases.isEmpty()) {
                    if (!out.subCategoryTextKeysByProductCategory.containsKey(productCategoryKey)) {
                        out.subCategoryTextKeysByProductCategory.put(productCategoryKey, new Set<String>());
                    }
                    addTextAliasesToSet(
                        out.subCategoryTextKeysByProductCategory.get(productCategoryKey),
                        subCategoryAliases
                    );
                    for (String subCategoryAlias : subCategoryAliases) {
                        String tripleKey = productCategoryKey + '|' + subCategoryAlias;
                        if (!subCodeAliases.isEmpty()) {
                            if (!out.subCodeTextKeysByProductCategorySubCategory.containsKey(tripleKey)) {
                                out.subCodeTextKeysByProductCategorySubCategory.put(tripleKey, new Set<String>());
                            }
                            addTextAliasesToSet(
                                out.subCodeTextKeysByProductCategorySubCategory.get(tripleKey),
                                subCodeAliases
                            );
                        }
                        if (!subCodeAliases.isEmpty()) {
                            for (String subCodeAlias : subCodeAliases) {
                                out.fullTextKeys.add(
                                    productIdKey + '|' + categoryAlias + '|' + subCategoryAlias + '|' + subCodeAlias
                                );
                            }
                        }
                    }
                }
            }
        }
        return out;
    }

    /**
     * Validate NOC theo thứ tự Product Type → Category → Sub Category → Sub Code.
     * Dừng ở mức lỗi đầu tiên; so khớp text import với Name/Code trên NOC (không dùng Id lookup chéo).
     */
    private static void appendNatureOfCaseValidationErrors(
        ParsedCaseRow r,
        Id productId,
        NatureOfCaseHierarchyMaps nocMaps,
        List<String> errs
    ) {
        if (productId == null || r == null || nocMaps == null) {
            return;
        }
        if (String.isBlank(r.category) || String.isBlank(r.subCategory) || String.isBlank(r.subCode)) {
            return;
        }
        String productIdKey = String.valueOf(productId);
        String categoryNorm = r.category.trim().toLowerCase();
        String subCategoryNorm = r.subCategory.trim().toLowerCase();
        String subCodeNorm = r.subCode.trim().toLowerCase();
        String fullKey = productIdKey + '|' + categoryNorm + '|' + subCategoryNorm + '|' + subCodeNorm;
        if (nocMaps.fullTextKeys.contains(fullKey)) {
            return;
        }

        Set<String> categoriesForProduct = nocMaps.categoryTextKeysByProductId.get(productIdKey);
        if (!natureInputMatches(categoriesForProduct, r.category)) {
            errs.add(System.Label.FEC_Batch_Import_Invalid_Category_For_Product_Type);
            return;
        }

        Set<String> subCategoriesForProduct = nocMaps.subCategoryTextKeysByProductId.get(productIdKey);
        if (!natureInputMatches(subCategoriesForProduct, r.subCategory)) {
            errs.add(System.Label.FEC_Batch_Import_Invalid_Sub_Category_For_Category);
            return;
        }

        Set<String> subCodesForTriple = resolveSubCodesForCategorySubCategory(
            nocMaps,
            productIdKey,
            r.category,
            r.subCategory
        );
        if (subCodesForTriple == null || subCodesForTriple.isEmpty()) {
            errs.add(System.Label.FEC_Batch_Import_Invalid_Sub_Code_For_Sub_Category);
            return;
        }
        if (!natureInputMatches(subCodesForTriple, r.subCode)) {
            errs.add(System.Label.FEC_Batch_Import_Invalid_Sub_Code_For_Sub_Category);
        }
    }

    private static Map<String, Set<String>> buildSubChannelsByChannelMap(
        Schema.DescribeFieldResult channelDfr,
        Schema.DescribeFieldResult subChannelDfr
    ) {
        Map<String, Set<String>> subChannelsByChannel = new Map<String, Set<String>>();
        if (channelDfr == null || subChannelDfr == null) {
            return subChannelsByChannel;
        }
        List<Schema.PicklistEntry> channelEntries = channelDfr.getPicklistValues();
        List<Schema.PicklistEntry> subChannelEntries = subChannelDfr.getPicklistValues();
        Schema.SObjectField controllerFieldRef = subChannelDfr.getController();
        String controllerFieldApi =
            controllerFieldRef == null ? null : controllerFieldRef.getDescribe().getName();
        Boolean dependent =
            String.isNotBlank(controllerFieldApi) &&
            controllerFieldApi.equalsIgnoreCase(String.valueOf(channelDfr.getName()));
        if (!dependent) {
            return subChannelsByChannel;
        }

        for (Integer channelIndex = 0; channelIndex < channelEntries.size(); channelIndex++) {
            Schema.PicklistEntry channelEntry = channelEntries[channelIndex];
            if (channelEntry == null || !channelEntry.isActive()) {
                continue;
            }
            registerChannelSubChannelKey(subChannelsByChannel, channelEntry.getValue());
            registerChannelSubChannelKey(subChannelsByChannel, channelEntry.getLabel());

            for (Schema.PicklistEntry subEntry : subChannelEntries) {
                if (subEntry == null || !subEntry.isActive()) {
                    continue;
                }
                if (dependent && !isPicklistEntryValidForControllerIndex(subEntry, channelIndex)) {
                    continue;
                }
                addSubChannelForChannelKey(subChannelsByChannel, channelEntry.getValue(), subEntry.getValue());
                addSubChannelForChannelKey(subChannelsByChannel, channelEntry.getValue(), subEntry.getLabel());
                addSubChannelForChannelKey(subChannelsByChannel, channelEntry.getLabel(), subEntry.getValue());
                addSubChannelForChannelKey(subChannelsByChannel, channelEntry.getLabel(), subEntry.getLabel());
            }
        }
        return subChannelsByChannel;
    }

    private static void registerChannelSubChannelKey(Map<String, Set<String>> subChannelsByChannel, String channelKey) {
        if (String.isBlank(channelKey)) {
            return;
        }
        String normalized = channelKey.trim().toLowerCase();
        if (!subChannelsByChannel.containsKey(normalized)) {
            subChannelsByChannel.put(normalized, new Set<String>());
        }
    }

    private static void addSubChannelForChannelKey(
        Map<String, Set<String>> subChannelsByChannel,
        String channelKey,
        String subChannelKey
    ) {
        if (String.isBlank(channelKey) || String.isBlank(subChannelKey)) {
            return;
        }
        registerChannelSubChannelKey(subChannelsByChannel, channelKey);
        subChannelsByChannel.get(channelKey.trim().toLowerCase()).add(subChannelKey.trim().toLowerCase());
    }

    private static String readPicklistEntryValidFor(Schema.PicklistEntry entry) {
        if (entry == null) {
            return null;
        }
        Map<String, Object> entryMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(entry));
        Object validForObj = entryMap == null ? null : entryMap.get('validFor');
        return validForObj == null ? null : String.valueOf(validForObj);
    }

    private static Boolean isPicklistEntryValidForControllerIndex(Schema.PicklistEntry entry, Integer controllerIndex) {
        if (entry == null || controllerIndex == null || controllerIndex < 0) {
            return false;
        }
        String validForBits = readPicklistEntryValidFor(entry);
        if (String.isBlank(validForBits)) {
            return true;
        }
        String hexString = EncodingUtil.convertToHex(EncodingUtil.base64Decode(validForBits));
        Integer controlByteIndex = controllerIndex / 8;
        Integer controlBitIndex = Math.mod(controllerIndex, 8);
        Integer startChar = controlByteIndex * 2;
        if (hexString.length() <= startChar + 1) {
            return false;
        }
        Integer byteValue = hexStringToInt(hexString.substring(startChar, startChar + 2));
        return (byteValue & (1 << controlBitIndex)) != 0;
    }

    private static Integer hexStringToInt(String hex) {
        if (String.isBlank(hex)) {
            return 0;
        }
        Integer result = 0;
        String hexChars = '0123456789ABCDEF';
        String normalized = hex.toUpperCase();
        for (Integer i = 0; i < normalized.length(); i++) {
            String ch = normalized.substring(i, i + 1);
            Integer digit = hexChars.indexOf(ch);
            if (digit < 0) {
                continue;
            }
            result = (result << 4) + digit;
        }
        return result;
    }

    private static Boolean isSubChannelValidForChannel(
        String channelApi,
        String subChannelApi,
        Map<String, Set<String>> subChannelsByChannel
    ) {
        if (String.isBlank(channelApi) || String.isBlank(subChannelApi) || subChannelsByChannel == null) {
            return true;
        }
        Set<String> allowed = subChannelsByChannel.get(channelApi.trim().toLowerCase());
        if (allowed == null || allowed.isEmpty()) {
            return true;
        }
        return allowed.contains(subChannelApi.trim().toLowerCase());
    }

    private static String matchBatchImportCaseStatus(Schema.DescribeFieldResult statusDfr, String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String direct = matchPicklist(statusDfr, raw);
        if (String.isNotBlank(direct)) {
            if (
                direct == FEC_ConstantCommon.CASE_STATUS_OPEN ||
                direct == FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED
            ) {
                return direct;
            }
            return null;
        }
        String trimmed = raw.trim();
        if (trimmed.equalsIgnoreCase(FEC_ConstantCommon.CASE_STATUS_OPEN)) {
            return FEC_ConstantCommon.CASE_STATUS_OPEN;
        }
        if (trimmed.equalsIgnoreCase(FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED)) {
            return FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED;
        }
        return null;
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
        for (String allowed : FEC_ConstantCommon.CUSTOMER_CASE_IMPORT_STATUS_VALUES) {
            if (t.equalsIgnoreCase(allowed)) {
                return allowed;
            }
        }
        return null;
    }

    private static Integer countFailedRowResults(List<CaseRowResult> rowResults) {
        Integer failedCount = 0;
        if (rowResults == null) {
            return failedCount;
        }
        for (CaseRowResult rr : rowResults) {
            if ('Failed'.equals(rr.status)) {
                failedCount += 1;
            }
        }
        return failedCount;
    }

    private static void applyBatchImportFailureOutcome(
        Map<String, Schema.SObjectField> batchFieldMap,
        SObject batchRow,
        Integer totalCount,
        Integer failedCount,
        String batchFailureReason,
        String sourceFileName,
        List<CaseRowResult> rowResults
    ) {
        saveCaseImportResultCsv((Id) batchRow.get('Id'), sourceFileName, rowResults);
        FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Failure');
        FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
        FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Records__c', 'FEC_Total_Records_Count__c' }, totalCount);
        FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
        FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, failedCount);
        FEC_BatchImportCommon.putIfFieldExists(batchFieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, batchFailureReason);
        update batchRow;
    }

    /** File result CSV trên server — luôn có link tải khi validation/DML fail (không phụ thuộc SheetJS client). */
    private static void saveCaseImportResultCsv(Id batchRecordId, String sourceFileName, List<CaseRowResult> rowResults) {
        if (batchRecordId == null || rowResults == null || rowResults.isEmpty()) {
            return;
        }
        try {
            List<String> lines = new List<String>();
            lines.add(
                '"Row","Contract","Phone","Product","Category","Sub Category","Sub Code","Case Status","Remarks","Channel","Sub Channel","Email","Import Status","Errors"'
            );
            Integer rowNum = 0;
            for (CaseRowResult rr : rowResults) {
                rowNum += 1;
                lines.add(
                    String.join(
                        new List<String>{
                            csvEscape(String.valueOf(rowNum)),
                            csvEscape(rr.contractNumber),
                            csvEscape(rr.interactionPhone),
                            csvEscape(rr.productType),
                            csvEscape(rr.category),
                            csvEscape(rr.subCategory),
                            csvEscape(rr.subCode),
                            csvEscape(rr.caseStatus),
                            csvEscape(rr.caseRemarks),
                            csvEscape(rr.interactionChannel),
                            csvEscape(rr.interactionSubChannel),
                            csvEscape(rr.interactionEmail),
                            csvEscape(rr.status),
                            csvEscape(rr.errors)
                        },
                        ','
                    )
                );
            }
            String resultTitle = FEC_BatchImportCommon.buildResultContentTitle(sourceFileName);
            ContentVersion cv = new ContentVersion();
            cv.Title = resultTitle;
            cv.PathOnClient = '/' + resultTitle + '.csv';
            cv.VersionData = Blob.valueOf('\uFEFF' + String.join(lines, '\r\n'));
            cv.FirstPublishLocationId = batchRecordId;
            insert cv;
        } catch (Exception ex) {
            // Không chặn cập nhật batch Failure nếu không ghi được file result.
        }
    }

    private static String csvEscape(String value) {
        String v = value == null ? '' : value;
        if (v.contains('"') || v.contains(',') || v.contains('\n') || v.contains('\r')) {
            return '"' + v.replace('"', '""') + '"';
        }
        return '"' + v + '"';
    }

    /** Cả file không import — mọi dòng Failed, không có ID/Interaction/Case ID. */
    private static void markAllRowResultsFailedForBatchNoImport(List<CaseRowResult> rowResults) {
        if (rowResults == null) {
            return;
        }
        for (CaseRowResult rr : rowResults) {
            rr.status = 'Failed';
            rr.recordId = '';
            rr.finalStatus = '';
            rr.interactionId = '';
            rr.caseBusinessId = '';
        }
    }

    /** Sau rollback: dòng từng insert thành công — đánh Failed, xóa Id Case (lỗi chi tiết giữ trên dòng đã Failed từ trước). */
    private static void markRowResultsNotImportedAfterRollback(List<CaseRowResult> rowResults) {
        if (rowResults == null) {
            return;
        }
        for (CaseRowResult rr : rowResults) {
            if (!'Succeeded'.equals(rr.status)) {
                continue;
            }
            rr.status = 'Failed';
            rr.recordId = '';
            rr.finalStatus = '';
            rr.interactionId = '';
            rr.caseBusinessId = '';
        }
    }

    private static void enrichRowResultsFromInsertedCases(List<CaseRowResult> rowResults) {
        if (rowResults == null || rowResults.isEmpty()) {
            return;
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