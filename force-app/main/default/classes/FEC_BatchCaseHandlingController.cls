public without sharing class FEC_BatchCaseHandlingController {
    private static final String OBJECT_API_NAME = 'FEC_Batch_Case_Handling__c';
    private static final String TEMPLATE_OBJECT_API_NAME = 'FEC_Template_Import__c';
    private static final Integer MAX_ROWS = 200;
    private static final Integer MAX_ATTACHMENT_CASE_SET = 1000;
    private static final Integer MAX_ZIP_BYTES = 10 * 1024 * 1024;
    private static final Integer MAX_EXPORT_ROWS = 100000;
    private static final Integer EXPORT_CURSOR_PAGE_SIZE = 1000;
    private static final Integer REMARK_MAX_LEN = 32768;

    private static final List<String> ALLOWED_BUSINESS_PROCESS_NAMES = new List<String>{
        'COF (Complaint or Feedback)',
        'GSR (General Service Request)',
        'Address Update',
        'Phone Update',
        'Document Request',
        'MRC Return',
        'Refund Request (Loan)',
        'Incorrect Payment Handling (Loan)',
        'IPP Closure',
        'Card Unblock',
        'Contract Closure',
        'Card Closure & Refund Request (Card)',
        'Card Replacement',
        'IPP Conversion',
        'Points Redemption'
    };

    private static final List<String> RESOLVED_SERVICE_CASE_STATUSES = new List<String>{
        FEC_ConstantCommon.CASE_STATUS_RESOLVED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED,
        FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANNOT_CONTACT_CUSTOMER
    };

    public class FilterPropertyMeta {
        @AuraEnabled public String propertyKey;
        @AuraEnabled public String label;
        @AuraEnabled public String valueType;
        @AuraEnabled public List<String> operators;
    }

    public class FilteredCaseRow {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String customerType;
        @AuraEnabled public String caseIdSearch;
        @AuraEnabled public String categoryCode;
        @AuraEnabled public String subCategoryCode;
        @AuraEnabled public String subCodeCode;
        @AuraEnabled public String caseStatus;
        @AuraEnabled public Datetime caseCreatedOn;
        @AuraEnabled public Datetime lastUpdatedOn;
        @AuraEnabled public Boolean hasAttachment;
        @AuraEnabled public String caseReviewUrl;
        @AuraEnabled public String businessProcessCode;
        @AuraEnabled public String businessProcessName;
    }

    public class BulkCaseSearchResult {
        @AuraEnabled public List<FilteredCaseRow> rows;
        @AuraEnabled public Integer totalCount;
    }

    public class CaseHandlingImportRow {
        @AuraEnabled public String caseIdSearch;
        @AuraEnabled public String routingAction;
        @AuraEnabled public String inputtedRemarks;
        @AuraEnabled public String assignmentId;
        @AuraEnabled public String assignmentRoutingAction;
        @AuraEnabled public String recordId;
        @AuraEnabled public String status;
        @AuraEnabled public String errors;
    }

    public class CaseSetRangeOption {
        @AuraEnabled public String label;
        @AuraEnabled public Integer startIndex;
        @AuraEnabled public Integer endIndex;
    }

    public class AttachmentZipResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String downloadUrl;
        @AuraEnabled public String fileName;
    }

    public class BusinessProcessExportRow {
        @AuraEnabled public String businessProcessCode;
        @AuraEnabled public Integer totalCases;
        @AuraEnabled public String templateName;
        @AuraEnabled public String templateDownloadUrl;
    }

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

    @AuraEnabled(cacheable=true)
    public static List<FilterPropertyMeta> getCaseFilterPropertyMetadata() {
        List<FilterPropertyMeta> out = new List<FilterPropertyMeta>();
        out.add(buildMeta('CUSTOMER_TYPE', 'Customer Type', 'picklist', new List<String>{ 'equals', 'not_equal_to' }));
        out.add(buildMeta('CASE_ID', 'Case ID', 'text', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with' }));
        out.add(buildMeta('CASE_CREATED_BY', 'Case Created By', 'text', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with' }));
        out.add(buildMeta('CASE_CREATED_BY_ROLE', 'Case Created By Role', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with' }));
        out.add(buildMeta('CASE_STATUS', 'Case Status', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with' }));
        out.add(buildMeta('PRODUCT_TYPE', 'Product Type', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' }));
        out.add(buildMeta('CATEGORY', 'Category', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' }));
        out.add(buildMeta('SUB_CATEGORY', 'Sub Category', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' }));
        out.add(buildMeta('SUB_CODE', 'Sub Code', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' }));
        out.add(buildMeta('CASE_CREATED_ON', 'Case Created On', 'date', new List<String>{ 'equals', 'not_equal_to', 'less_than', 'greater_than', 'less_or_equal', 'greater_or_equal' }));
        out.add(buildMeta('ATTACHMENTS', 'Attachments', 'checkbox', new List<String>{ 'equals', 'not_equal_to' }));
        return out;
    }

    private static FilterPropertyMeta buildMeta(String key, String label, String valueType, List<String> ops) {
        FilterPropertyMeta m = new FilterPropertyMeta();
        m.propertyKey = key;
        m.label = label;
        m.valueType = valueType;
        m.operators = ops;
        return m;
    }

    @AuraEnabled(cacheable=true)
    public static List<BatchRow> getRecentRows() {
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(OBJECT_API_NAME).getDescribe().fields.getMap();
        String fileField = pickField(fieldMap, new List<String>{ 'FEC_File_Name__c', 'Name' });
        String fileContentDocumentIdField = pickField(fieldMap, new List<String>{ 'FEC_File_Content_Document_Id__c' });
        String uploadedOnField = pickField(fieldMap, new List<String>{ 'FEC_Uploaded_On__c', 'CreatedDate' });
        String totalRecordsField = pickField(fieldMap, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' });
        String totalSuccessField = pickField(fieldMap, new List<String>{ 'FEC_Total_Success_Records__c' });
        String totalFailedField = pickField(fieldMap, new List<String>{ 'FEC_Total_Failed_Records__c' });
        String statusField = pickField(fieldMap, new List<String>{ 'FEC_Status__c' });
        String failureReasonField = pickField(fieldMap, new List<String>{ 'FEC_Failure_Reason__c' });
        String resultField = pickField(fieldMap, new List<String>{ 'FEC_Result__c' });

        List<String> selectParts = new List<String>{ 'Id', 'CreatedBy.Email', 'CreatedById', 'CreatedDate' };
        addIfNotBlank(selectParts, fileField);
        addIfNotBlank(selectParts, fileContentDocumentIdField);
        addIfNotBlank(selectParts, uploadedOnField);
        addIfNotBlank(selectParts, totalRecordsField);
        addIfNotBlank(selectParts, totalSuccessField);
        addIfNotBlank(selectParts, totalFailedField);
        addIfNotBlank(selectParts, statusField);
        addIfNotBlank(selectParts, failureReasonField);
        addIfNotBlank(selectParts, resultField);

        Datetime sinceDt = Datetime.now().addMonths(-6);
        Id currentUserId = UserInfo.getUserId();
        String orderExpr = 'CreatedDate DESC';
        if (String.isNotBlank(uploadedOnField) && uploadedOnField != 'CreatedDate') {
            orderExpr = uploadedOnField + ' DESC NULLS LAST, CreatedDate DESC';
        }

        String queryText =
            'SELECT ' + String.join(selectParts, ', ') +
            ' FROM ' + OBJECT_API_NAME +
            ' WHERE CreatedDate >= :sinceDt AND CreatedById = :currentUserId' +
            ' ORDER BY ' + orderExpr +
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

    @AuraEnabled
    public static BulkCaseSearchResult searchBulkCases(String filtersJson, Integer pageSize, Integer pageNumber) {
        BulkCaseSearchResult out = new BulkCaseSearchResult();
        out.rows = new List<FilteredCaseRow>();
        out.totalCount = 0;
        Integer ps = pageSize == null || pageSize < 1 ? 20 : pageSize;
        if (ps > 100) {
            ps = 100;
        }
        Integer pn = pageNumber == null || pageNumber < 1 ? 1 : pageNumber;
        Integer offsetRows = (pn - 1) * ps;
        if (offsetRows > 2000) {
            offsetRows = 2000;
        }

        List<Object> rawFilters = String.isBlank(filtersJson)
            ? new List<Object>()
            : (List<Object>) JSON.deserializeUntyped(filtersJson);
        List<Map<String, Object>> filterMaps = new List<Map<String, Object>>();
        if (rawFilters != null) {
            for (Object o : rawFilters) {
                if (o instanceof Map<String, Object>) {
                    filterMaps.add((Map<String, Object>) o);
                }
            }
        }

        List<String> whereParts = buildBaseCaseWhere();
        List<String> dynamicParts = buildDynamicWhereFromFilters(filterMaps);
        whereParts.addAll(dynamicParts);
        String whereClause = String.join(whereParts, ' AND ');

        String countSoql = 'SELECT COUNT() FROM Case WHERE ' + whereClause;
        out.totalCount = Database.countQuery(countSoql);

        List<String> selectFields = new List<String>{
            'Id',
            'FEC_Customer_Type__c',
            'FEC_ID_Search__c',
            'FEC_Final_Status__c',
            'FEC_Case_Created_On__c',
            'FEC_Last_Updated_On__c',
            'FEC_Category__r.FEC_Code__c',
            'FEC_SubCategory__r.FEC_Code__c',
            'FEC_SubCode__r.FEC_Code__c',
            'FEC_Business_Process__r.FEC_Code__c',
            'FEC_Business_Process__r.Name',
            '(SELECT Id FROM ContentDocumentLinks LIMIT 1)'
        };
        String dataSoql =
            'SELECT ' + String.join(selectFields, ', ') +
            ' FROM Case WHERE ' + whereClause +
            ' ORDER BY FEC_Case_Created_On__c ASC NULLS LAST' +
            ' LIMIT ' + ps +
            ' OFFSET ' + offsetRows;

        List<Case> cases = Database.query(dataSoql);
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, cases);
        cases = (List<Case>) decision.getRecords();

        for (Case c : cases) {
            FilteredCaseRow r = new FilteredCaseRow();
            r.caseId = c.Id;
            r.customerType = c.FEC_Customer_Type__c;
            r.caseIdSearch = c.FEC_ID_Search__c;
            r.categoryCode = c.FEC_Category__r == null ? null : c.FEC_Category__r.FEC_Code__c;
            r.subCategoryCode = c.FEC_SubCategory__r == null ? null : c.FEC_SubCategory__r.FEC_Code__c;
            r.subCodeCode = c.FEC_SubCode__r == null ? null : c.FEC_SubCode__r.FEC_Code__c;
            r.caseStatus = c.FEC_Final_Status__c;
            r.caseCreatedOn = c.FEC_Case_Created_On__c;
            r.lastUpdatedOn = c.FEC_Last_Updated_On__c;
            r.hasAttachment = c.ContentDocumentLinks != null && !c.ContentDocumentLinks.isEmpty();
            r.caseReviewUrl = '/lightning/r/Case/' + String.valueOf(c.Id) + '/view';
            r.businessProcessCode = c.FEC_Business_Process__r == null ? null : c.FEC_Business_Process__r.FEC_Code__c;
            r.businessProcessName = c.FEC_Business_Process__r == null ? null : c.FEC_Business_Process__r.Name;
            out.rows.add(r);
        }
        return out;
    }

    @AuraEnabled
    public static BulkCaseSearchResult searchBulkCasesForExport(String filtersJson, String afterCaseId, Integer pageSize) {
        BulkCaseSearchResult out = new BulkCaseSearchResult();
        out.rows = new List<FilteredCaseRow>();
        out.totalCount = 0;
        Integer ps = pageSize == null || pageSize < 1 ? EXPORT_CURSOR_PAGE_SIZE : pageSize;
        if (ps > EXPORT_CURSOR_PAGE_SIZE) {
            ps = EXPORT_CURSOR_PAGE_SIZE;
        }

        List<Object> rawFilters = String.isBlank(filtersJson)
            ? new List<Object>()
            : (List<Object>) JSON.deserializeUntyped(filtersJson);
        List<Map<String, Object>> filterMaps = new List<Map<String, Object>>();
        if (rawFilters != null) {
            for (Object o : rawFilters) {
                if (o instanceof Map<String, Object>) {
                    filterMaps.add((Map<String, Object>) o);
                }
            }
        }

        List<String> whereParts = buildBaseCaseWhere();
        List<String> dynamicParts = buildDynamicWhereFromFilters(filterMaps);
        whereParts.addAll(dynamicParts);

        Id cursorId;
        if (String.isNotBlank(afterCaseId)) {
            try {
                cursorId = Id.valueOf(afterCaseId);
            } catch (Exception ex) {
                cursorId = null;
            }
            if (cursorId != null) {
                whereParts.add('Id > :cursorId');
            }
        }

        String whereClause = String.join(whereParts, ' AND ');
        List<String> selectFields = new List<String>{
            'Id',
            'FEC_Customer_Type__c',
            'FEC_ID_Search__c',
            'FEC_Final_Status__c',
            'FEC_Case_Created_On__c',
            'FEC_Last_Updated_On__c',
            'FEC_Category__r.FEC_Code__c',
            'FEC_SubCategory__r.FEC_Code__c',
            'FEC_SubCode__r.FEC_Code__c',
            'FEC_Business_Process__r.FEC_Code__c',
            'FEC_Business_Process__r.Name',
            '(SELECT Id FROM ContentDocumentLinks LIMIT 1)'
        };
        String dataSoql =
            'SELECT ' + String.join(selectFields, ', ') +
            ' FROM Case WHERE ' + whereClause +
            ' ORDER BY Id ASC' +
            ' LIMIT ' + ps;

        List<Case> cases = Database.query(dataSoql);
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, cases);
        cases = (List<Case>) decision.getRecords();

        for (Case c : cases) {
            FilteredCaseRow r = new FilteredCaseRow();
            r.caseId = c.Id;
            r.customerType = c.FEC_Customer_Type__c;
            r.caseIdSearch = c.FEC_ID_Search__c;
            r.categoryCode = c.FEC_Category__r == null ? null : c.FEC_Category__r.FEC_Code__c;
            r.subCategoryCode = c.FEC_SubCategory__r == null ? null : c.FEC_SubCategory__r.FEC_Code__c;
            r.subCodeCode = c.FEC_SubCode__r == null ? null : c.FEC_SubCode__r.FEC_Code__c;
            r.caseStatus = c.FEC_Final_Status__c;
            r.caseCreatedOn = c.FEC_Case_Created_On__c;
            r.lastUpdatedOn = c.FEC_Last_Updated_On__c;
            r.hasAttachment = c.ContentDocumentLinks != null && !c.ContentDocumentLinks.isEmpty();
            r.caseReviewUrl = '/lightning/r/Case/' + String.valueOf(c.Id) + '/view';
            r.businessProcessCode = c.FEC_Business_Process__r == null ? null : c.FEC_Business_Process__r.FEC_Code__c;
            r.businessProcessName = c.FEC_Business_Process__r == null ? null : c.FEC_Business_Process__r.Name;
            out.rows.add(r);
        }
        return out;
    }

    @AuraEnabled
    public static List<CaseSetRangeOption> getAttachmentCaseSetOptions(String filtersJson) {
        List<CaseSetRangeOption> out = new List<CaseSetRangeOption>();
        Integer total = 0;
        List<String> whereParts = buildBaseCaseWhere();
        List<Object> rawFilters = String.isBlank(filtersJson)
            ? new List<Object>()
            : (List<Object>) JSON.deserializeUntyped(filtersJson);
        List<Map<String, Object>> filterMaps = new List<Map<String, Object>>();
        if (rawFilters != null) {
            for (Object o : rawFilters) {
                if (o instanceof Map<String, Object>) {
                    filterMaps.add((Map<String, Object>) o);
                }
            }
        }
        whereParts.addAll(buildDynamicWhereFromFilters(filterMaps));
        String whereClause = String.join(whereParts, ' AND ');
        total = Database.countQuery('SELECT COUNT() FROM Case WHERE ' + whereClause);
        if (total < 1) {
            return out;
        }
        Integer max = Math.min(total, MAX_ATTACHMENT_CASE_SET);
        for (Integer i = 1; i <= max; i += 50) {
            CaseSetRangeOption item = new CaseSetRangeOption();
            item.startIndex = i;
            item.endIndex = Math.min(i + 49, max);
            item.label = String.valueOf(item.startIndex) + '-' + String.valueOf(item.endIndex);
            out.add(item);
        }
        return out;
    }

    @AuraEnabled
    public static AttachmentZipResult downloadAttachmentsZip(String filtersJson, Integer startIndex, Integer endIndex) {
        AttachmentZipResult out = new AttachmentZipResult();
        out.success = false;
        out.message = 'No attachment data.';
        if (startIndex == null || endIndex == null || startIndex < 1 || endIndex < startIndex) {
            out.message = 'Case set không hợp lệ.';
            return out;
        }
        Integer maxEnd = Math.min(endIndex, MAX_ATTACHMENT_CASE_SET);
        Integer start = startIndex;
        Integer countToTake = maxEnd - start + 1;
        if (countToTake < 1) {
            out.message = 'Case set không hợp lệ.';
            return out;
        }
        Integer offsetRows = start - 1;
        if (offsetRows > 2000) {
            offsetRows = 2000;
        }

        List<String> whereParts = buildBaseCaseWhere();
        List<Object> rawFilters = String.isBlank(filtersJson)
            ? new List<Object>()
            : (List<Object>) JSON.deserializeUntyped(filtersJson);
        List<Map<String, Object>> filterMaps = new List<Map<String, Object>>();
        if (rawFilters != null) {
            for (Object o : rawFilters) {
                if (o instanceof Map<String, Object>) {
                    filterMaps.add((Map<String, Object>) o);
                }
            }
        }
        whereParts.addAll(buildDynamicWhereFromFilters(filterMaps));
        String whereClause = String.join(whereParts, ' AND ');

        List<Case> cases = Database.query(
            'SELECT Id, FEC_ID_Search__c FROM Case WHERE ' + whereClause +
            ' ORDER BY FEC_Case_Created_On__c ASC NULLS LAST LIMIT ' + countToTake + ' OFFSET ' + offsetRows
        );
        if (cases.isEmpty()) {
            out.message = 'Không có Case trong khoảng đã chọn.';
            return out;
        }

        Map<Id, String> caseLabelById = new Map<Id, String>();
        Set<Id> caseIds = new Set<Id>();
        for (Case c : cases) {
            caseIds.add(c.Id);
            caseLabelById.put(c.Id, String.isBlank(c.FEC_ID_Search__c) ? String.valueOf(c.Id) : c.FEC_ID_Search__c);
        }
        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :caseIds
        ];
        if (links.isEmpty()) {
            out.message = 'Các Case đã chọn không có tệp đính kèm.';
            return out;
        }

        Map<Id, Id> docToCase = new Map<Id, Id>();
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) {
            docIds.add(l.ContentDocumentId);
            if (!docToCase.containsKey(l.ContentDocumentId)) {
                docToCase.put(l.ContentDocumentId, l.LinkedEntityId);
            }
        }
        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, ContentSize, VersionData, ContentDocumentId
            FROM ContentVersion
            WHERE IsLatest = true AND ContentDocumentId IN :docIds
        ];
        if (versions.isEmpty()) {
            out.message = 'Không lấy được tệp đính kèm.';
            return out;
        }

        Compression.ZipWriter writer = new Compression.ZipWriter();
        Integer totalSize = 0;
        Integer added = 0;
        for (ContentVersion cv : versions) {
            Integer sz = cv.ContentSize == null ? 0 : cv.ContentSize;
            if (totalSize + sz > MAX_ZIP_BYTES) {
                break;
            }
            Id ownerCaseId = docToCase.get(cv.ContentDocumentId);
            String caseLabel = caseLabelById.get(ownerCaseId);
            String ext = String.isBlank(cv.FileExtension) ? FEC_ConstantCommon.STR_EMPTY : '.' + cv.FileExtension;
            String entryName = String.valueOf(caseLabel) + ' - ' + cv.Title + ext;
            writer.addEntry(entryName, cv.VersionData);
            totalSize += sz;
            added += 1;
        }
        if (added == 0) {
            out.message = 'Tổng dung lượng file vượt quá 10MB.';
            return out;
        }

        Blob zipBlob = writer.getArchive();
        ContentVersion zipCv = new ContentVersion();
        zipCv.Title = 'BatchCaseAttachments_' + String.valueOf(Datetime.now().getTime());
        zipCv.PathOnClient = '/' + zipCv.Title + '.zip';
        zipCv.VersionData = zipBlob;
        zipCv.FirstPublishLocationId = UserInfo.getUserId();
        insert zipCv;

        ContentVersion inserted = [
            SELECT Id
            FROM ContentVersion
            WHERE Id = :zipCv.Id
            LIMIT 1
        ];
        out.success = true;
        out.fileName = zipCv.Title + '.zip';
        out.downloadUrl = '/sfc/servlet.shepherd/version/download/' + String.valueOf(inserted.Id);
        out.message = 'Tải file thành công.';
        return out;
    }

    @AuraEnabled
    public static AttachmentZipResult zipExcelFiles(List<Map<String, Object>> files, String archiveName) {
        AttachmentZipResult out = new AttachmentZipResult();
        out.success = false;
        if (files == null || files.isEmpty()) {
            out.message = 'No files to zip.';
            return out;
        }
        Compression.ZipWriter writer = new Compression.ZipWriter();
        Integer added = 0;
        Long totalRawBytes = 0;
        Set<String> usedNames = new Set<String>();
        for (Map<String, Object> f : files) {
            if (f == null) {
                continue;
            }
            String name = f.get('fileName') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(f.get('fileName'));
            String b64 = f.get('base64Body') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(f.get('base64Body'));
            if (String.isBlank(name) || String.isBlank(b64)) {
                continue;
            }
            Blob entryBlob;
            try {
                entryBlob = EncodingUtil.base64Decode(b64);
            } catch (Exception ex) {
                continue;
            }
            Integer entrySize = entryBlob == null ? 0 : entryBlob.size();
            if (totalRawBytes + entrySize > MAX_ZIP_BYTES) {
                out.message = 'Tổng dung lượng file vượt quá 10MB.';
                return out;
            }
            String entry = name;
            Integer dup = 1;
            while (usedNames.contains(entry)) {
                Integer dot = entry.lastIndexOf('.');
                if (dot > 0) {
                    entry = name.substring(0, dot) + '_' + String.valueOf(dup) + name.substring(dot);
                } else {
                    entry = name + '_' + String.valueOf(dup);
                }
                dup += 1;
            }
            usedNames.add(entry);
            writer.addEntry(entry, entryBlob);
            totalRawBytes += entrySize;
            added += 1;
        }
        if (added == 0) {
            out.message = 'No files to zip.';
            return out;
        }
        Blob archive = writer.getArchive();
        if (archive != null && archive.size() > MAX_ZIP_BYTES) {
            out.message = 'Tổng dung lượng file vượt quá 10MB.';
            return out;
        }
        String prefix = String.isBlank(archiveName) ? 'FilteredCasesExport' : archiveName;
        String title = prefix + '_' + String.valueOf(Datetime.now().getTime());
        ContentVersion cv = new ContentVersion();
        cv.Title = title;
        cv.PathOnClient = '/' + title + '.zip';
        cv.VersionData = archive;
        cv.FirstPublishLocationId = UserInfo.getUserId();
        insert cv;
        ContentVersion ins = [
            SELECT Id
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];
        out.success = true;
        out.fileName = title + '.zip';
        out.downloadUrl = '/sfc/servlet.shepherd/version/download/' + String.valueOf(ins.Id);
        out.message = 'Tải file thành công.';
        return out;
    }

    @AuraEnabled
    public static AttachmentZipResult downloadCaseAttachmentsZip(Id caseId) {
        AttachmentZipResult out = new AttachmentZipResult();
        out.success = false;
        out.message = 'No attachment data.';
        if (caseId == null) {
            out.message = 'Case không hợp lệ.';
            return out;
        }
        Case c = [
            SELECT Id, FEC_ID_Search__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :caseId
        ];
        if (links.isEmpty()) {
            out.message = 'Case không có tệp đính kèm.';
            return out;
        }
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) {
            docIds.add(l.ContentDocumentId);
        }
        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, ContentSize, VersionData
            FROM ContentVersion
            WHERE IsLatest = true AND ContentDocumentId IN :docIds
        ];
        if (versions.isEmpty()) {
            out.message = 'Không lấy được tệp đính kèm.';
            return out;
        }
        Compression.ZipWriter writer = new Compression.ZipWriter();
        Integer totalSize = 0;
        Integer added = 0;
        String caseLabel = String.isBlank(c.FEC_ID_Search__c) ? String.valueOf(c.Id) : c.FEC_ID_Search__c;
        for (ContentVersion cv : versions) {
            Integer sz = cv.ContentSize == null ? 0 : cv.ContentSize;
            if (totalSize + sz > MAX_ZIP_BYTES) {
                break;
            }
            String ext = String.isBlank(cv.FileExtension) ? FEC_ConstantCommon.STR_EMPTY : '.' + cv.FileExtension;
            writer.addEntry(caseLabel + ' - ' + cv.Title + ext, cv.VersionData);
            totalSize += sz;
            added += 1;
        }
        if (added == 0) {
            out.message = 'Tổng dung lượng file vượt quá 10MB.';
            return out;
        }
        ContentVersion zipCv = new ContentVersion();
        zipCv.Title = 'CaseAttachments_' + caseLabel + '_' + String.valueOf(Datetime.now().getTime());
        zipCv.PathOnClient = '/' + zipCv.Title + '.zip';
        zipCv.VersionData = writer.getArchive();
        zipCv.FirstPublishLocationId = UserInfo.getUserId();
        insert zipCv;
        out.success = true;
        out.fileName = zipCv.Title + '.zip';
        out.downloadUrl = '/sfc/servlet.shepherd/version/download/' + String.valueOf(zipCv.Id);
        out.message = 'Tải file thành công.';
        return out;
    }

    @AuraEnabled
    public static List<BusinessProcessExportRow> getBusinessProcessExportRows(String filtersJson) {
        List<BusinessProcessExportRow> out = new List<BusinessProcessExportRow>();
        List<String> whereParts = buildBaseCaseWhere();
        List<Object> rawFilters = String.isBlank(filtersJson)
            ? new List<Object>()
            : (List<Object>) JSON.deserializeUntyped(filtersJson);
        List<Map<String, Object>> filterMaps = new List<Map<String, Object>>();
        if (rawFilters != null) {
            for (Object o : rawFilters) {
                if (o instanceof Map<String, Object>) {
                    filterMaps.add((Map<String, Object>) o);
                }
            }
        }
        whereParts.addAll(buildDynamicWhereFromFilters(filterMaps));
        List<String> allowedBpNames = ALLOWED_BUSINESS_PROCESS_NAMES;
        whereParts.add('FEC_Business_Process__r.Name IN :allowedBpNames');
        String whereClause = String.join(whereParts, ' AND ');
        List<AggregateResult> grouped = Database.query(
            'SELECT FEC_Business_Process__r.Name bpName, COUNT(Id) cnt ' +
            'FROM Case WHERE ' + whereClause +
            ' GROUP BY FEC_Business_Process__r.Name'
        );

        List<SObject> templateRows = queryActiveBatchCaseHandlingTemplates();
        Map<Id, String> urlByTemplateId = new Map<Id, String>();
        Set<Id> templateIds = new Set<Id>();
        for (SObject r : templateRows) {
            templateIds.add((Id) r.get('Id'));
        }
        if (!templateIds.isEmpty()) {
            for (ContentDocumentLink link : [
                SELECT LinkedEntityId, ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :templateIds
                ORDER BY LinkedEntityId, SystemModstamp DESC
            ]) {
                if (!urlByTemplateId.containsKey(link.LinkedEntityId)) {
                    urlByTemplateId.put(link.LinkedEntityId, '/sfc/servlet.shepherd/version/download/' + String.valueOf(link.ContentDocument.LatestPublishedVersionId));
                }
            }
        }

        String userGroup = FEC_ConstantCommon.STR_EMPTY;
        Map<String, Schema.SObjectField> userFields = User.SObjectType.getDescribe().fields.getMap();
        if (userFields.containsKey('FEC_User_Group__c')) {
            Id currentUserId = UserInfo.getUserId();
            User u = [
                SELECT FEC_User_Group__c
                FROM User
                WHERE Id = :currentUserId
                LIMIT 1
            ];
            userGroup = String.isBlank(u.FEC_User_Group__c) ? FEC_ConstantCommon.STR_EMPTY : u.FEC_User_Group__c.trim();
        }

        for (AggregateResult ar : grouped) {
            String bpName = ar.get('bpName') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(ar.get('bpName'));
            if (String.isBlank(bpName)) {
                continue;
            }
            BusinessProcessExportRow item = new BusinessProcessExportRow();
            item.businessProcessCode = bpName;
            item.totalCases = Integer.valueOf(String.valueOf(ar.get('cnt')));
            SObject matched = resolveTemplateByBusinessProcessAndUserGroup(bpName, userGroup, templateRows);
            if (matched != null) {
                item.templateName = String.valueOf(matched.get('Name'));
                item.templateDownloadUrl = urlByTemplateId.get((Id) matched.get('Id'));
            } else {
                item.templateName = FEC_ConstantCommon.STR_EMPTY;
                item.templateDownloadUrl = FEC_ConstantCommon.STR_EMPTY;
            }
            if (item.templateDownloadUrl == null) {
                item.templateDownloadUrl = FEC_ConstantCommon.STR_EMPTY;
            }
            out.add(item);
        }
        return out;
    }

    private static List<SObject> queryActiveBatchCaseHandlingTemplates() {
        Schema.SObjectType templateType = Schema.getGlobalDescribe().get(TEMPLATE_OBJECT_API_NAME);
        if (templateType == null) {
            return new List<SObject>();
        }
        Map<String, Schema.SObjectField> templateFields = templateType.getDescribe().fields.getMap();
        List<String> selectParts = new List<String>{ 'Id', 'Name' };
        List<String> whereParts = new List<String>{ 'Name != null' };
        if (templateFields.containsKey('FEC_Applicable_for__c')) {
            selectParts.add('FEC_Applicable_for__c');
            whereParts.add('FEC_Applicable_for__c = \'Batch Case Handling\'');
        }
        if (templateFields.containsKey('FEC_Active__c')) {
            selectParts.add('FEC_Active__c');
            whereParts.add('FEC_Active__c = TRUE');
        }
        String soql =
            'SELECT ' + String.join(selectParts, ', ') +
            ' FROM ' + TEMPLATE_OBJECT_API_NAME +
            ' WHERE ' + String.join(whereParts, ' AND ') +
            ' ORDER BY Name ASC';
        return Database.query(soql);
    }

    private static SObject resolveTemplateByBusinessProcessAndUserGroup(
        String businessProcessCode,
        String userGroup,
        List<SObject> activeTemplates
    ) {
        if (activeTemplates == null || activeTemplates.isEmpty()) {
            return null;
        }
        String namePrefix = mapBusinessProcessToTemplatePrefix(businessProcessCode);
        if (String.isBlank(namePrefix)) {
            return null;
        }
        List<String> suffixCandidates = mapUserGroupToTemplateSuffixes(businessProcessCode, userGroup);
        String prefixLower = namePrefix.toLowerCase();
        SObject prefixFallback;
        for (SObject tr : activeTemplates) {
            String name = tr.get('Name') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(tr.get('Name'));
            if (String.isBlank(name)) {
                continue;
            }
            String nameLower = name.toLowerCase();
            if (!nameLower.startsWith(prefixLower + 'temp')) {
                continue;
            }
            for (String suffix : suffixCandidates) {
                if (String.isNotBlank(suffix) && nameLower.endsWith('_' + suffix.toLowerCase())) {
                    return tr;
                }
            }
            if (prefixFallback == null) {
                prefixFallback = tr;
            }
        }
        return prefixFallback;
    }

    private static String mapBusinessProcessToTemplatePrefix(String businessProcessCode) {
        if (String.isBlank(businessProcessCode)) {
            return null;
        }
        String key = businessProcessCode.trim().toUpperCase();
        Map<String, String> bpToPrefix = new Map<String, String>{
            'COF' => 'COF',
            'COF (COMPLAINT OR FEEDBACK)' => 'COF',
            'GSR' => 'GSR',
            'GSR (GENERAL SERVICE REQUEST)' => 'GSR',
            'ADDRESS UPDATE' => 'AddressUpdate',
            'PHONE UPDATE' => 'PhoneUpdate',
            'DOCUMENT REQUEST' => 'DocumentRequest',
            'MRC RETURN' => 'MRCReturn',
            'REFUND REQUEST (LOAN)' => 'RefundLoan',
            'INCORRECT PAYMENT HANDLING (LOAN)' => 'IncorrectPayment',
            'IPP CLOSURE' => 'IPPClosure',
            'IPP CONVERSION' => 'IPPConversion',
            'CARD UNBLOCK' => 'CardUnblock',
            'CONTRACT CLOSURE' => 'ContractClosure',
            'CARD CLOSURE & REFUND REQUEST (CARD)' => 'CardClosure',
            'CARD REPLACEMENT' => 'CardReplacement',
            'POINTS REDEMPTION' => 'PointsRedemption'
        };
        return bpToPrefix.get(key);
    }

    private static List<String> mapUserGroupToTemplateSuffixes(String businessProcessCode, String userGroup) {
        String bp = String.isBlank(businessProcessCode) ? FEC_ConstantCommon.STR_EMPTY : businessProcessCode.trim().toUpperCase();
        String ug = String.isBlank(userGroup) ? FEC_ConstantCommon.STR_EMPTY : userGroup.trim().toUpperCase();
        List<String> out = new List<String>();
        if (bp == 'COF' || bp == 'COF (COMPLAINT OR FEEDBACK)') {
            if (ug == 'CC') { out.add('CSCustomerCare'); }
            else if (ug == 'CO') { out.add('CO'); }
            else if (ug == 'CL') { out.add('CL'); }
            else if (ug == 'CP') { out.add('CP'); }
            else if (ug == 'PM') { out.add('PM'); }
            else if (ug == 'CA') { out.add('CA'); }
            else if (ug == 'DS' || ug == 'TS') { out.add('Sales'); }
            else { out.add('OtherCS'); }
            return out;
        }
        if (bp == 'GSR' || bp == 'GSR (GENERAL SERVICE REQUEST)') {
            if (ug == 'SP') { out.add('CSSupport'); }
            else if (ug == 'CO') { out.add('CO'); }
            else if (ug == 'CL') { out.add('CL'); }
            else if (ug == 'CP') { out.add('CP'); }
            else if (ug == 'PM') { out.add('PM'); }
            else if (ug == 'CA') { out.add('CA'); }
            else if (ug == 'DS' || ug == 'TS') { out.add('Sales'); }
            else { out.add('OtherCS'); }
            return out;
        }
        if (String.isNotBlank(ug)) {
            String generic;
            if (ug == 'SP') { generic = 'CSSupport'; }
            else if (ug == 'OM') { generic = 'CSD2C'; }
            else if (ug == 'CC') { generic = 'CSCustomerCare'; }
            else if (ug == 'DS' || ug == 'TS') { generic = 'Sales'; }
            else if (ug == 'CO' || ug == 'CL' || ug == 'CP' || ug == 'PM' || ug == 'CA') { generic = ug; }
            if (String.isNotBlank(generic)) {
                out.add(generic);
            }
        }
        return out;
    }

    private static List<String> buildBaseCaseWhere() {
        List<String> parts = new List<String>();
        parts.add(
            'RecordType.DeveloperName IN (\'' +
            String.escapeSingleQuotes(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME) +
            '\',\'' +
            String.escapeSingleQuotes(FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME) +
            '\')'
        );
        parts.add('IsClosed = false');
        parts.add(
            '(FEC_Case_Status__c = null OR FEC_Case_Status__c NOT IN (\'' +
            String.join(escapeStatusList(RESOLVED_SERVICE_CASE_STATUSES), '\',\'') +
            '\'))'
        );
        parts.add('(FEC_Final_Status__c LIKE \'Pending-%\' OR FEC_Final_Status__c = \'Open\')');
        return parts;
    }

    private static List<String> escapeStatusList(List<String> src) {
        List<String> out = new List<String>();
        for (String s : src) {
            out.add(String.escapeSingleQuotes(s));
        }
        return out;
    }

    private static List<String> buildDynamicWhereFromFilters(List<Map<String, Object>> filterMaps) {
        List<String> parts = new List<String>();
        if (filterMaps == null || filterMaps.isEmpty()) {
            return parts;
        }
        for (Map<String, Object> fm : filterMaps) {
            String prop = normalizePropertyKey(fm.get('propertyKey'));
            String op = normalizeOperatorKey(fm.get('operatorKey'));
            if (String.isBlank(prop) || String.isBlank(op)) {
                continue;
            }
            String vText = fm.get('valueText') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(fm.get('valueText')).trim();
            List<Object> rawList = fm.get('valueList') instanceof List<Object> ? (List<Object>) fm.get('valueList') : null;
            List<String> vList = new List<String>();
            if (rawList != null) {
                for (Object o : rawList) {
                    if (o != null && String.isNotBlank(String.valueOf(o))) {
                        vList.add(String.valueOf(o).trim());
                    }
                }
            }
            String clause = buildOneFilterClause(prop, op, vText, vList);
            if (String.isNotBlank(clause)) {
                parts.add(clause);
            }
        }
        return parts;
    }

    private static String normalizePropertyKey(Object o) {
        if (o == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return String.valueOf(o).trim().replace(' ', '_').toUpperCase();
    }

    private static String normalizeOperatorKey(Object o) {
        if (o == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String s = String.valueOf(o).trim().toLowerCase().replace(' ', '_');
        if (s == 'notequalto') {
            return 'not_equal_to';
        }
        if (s == 'lessthan') {
            return 'less_than';
        }
        if (s == 'greaterthan') {
            return 'greater_than';
        }
        if (s == 'lessorequal') {
            return 'less_or_equal';
        }
        if (s == 'greaterorequal') {
            return 'greater_or_equal';
        }
        if (s == 'doesnotcontain') {
            return 'does_not_contain';
        }
        if (s == 'startswith') {
            return 'starts_with';
        }
        if (s == 'doesnotstartswith') {
            return 'does_not_start_with';
        }
        if (s == 'isnull') {
            return 'is_null';
        }
        if (s == 'isnotnull') {
            return 'is_not_null';
        }
        return s;
    }

    private static String buildOneFilterClause(String prop, String op, String vText, List<String> vList) {
        if (prop == 'CUSTOMER_TYPE') {
            return buildInOrNotClause('FEC_Customer_Type__c', op, vList, vText, true);
        }
        if (prop == 'CASE_ID') {
            return buildTextClause('FEC_ID_Search__c', op, vText);
        }
        if (prop == 'CASE_CREATED_BY') {
            return buildTextClause('FEC_Case_Created_By__c', op, vText);
        }
        if (prop == 'CASE_CREATED_BY_ROLE') {
            return buildTextClause('CreatedBy.FEC_User_Group__c', op, vText);
        }
        if (prop == 'CASE_STATUS') {
            return buildTextClause('FEC_Final_Status__c', op, vText);
        }
        if (prop == 'PRODUCT_TYPE') {
            return buildTextClause('FEC_Product_Type__r.Name', op, vText);
        }
        if (prop == 'CATEGORY') {
            return buildTextClause('FEC_Category__r.Name', op, vText);
        }
        if (prop == 'SUB_CATEGORY') {
            return buildTextClause('FEC_SubCategory__r.Name', op, vText);
        }
        if (prop == 'SUB_CODE') {
            return buildTextClause('FEC_SubCode__r.Name', op, vText);
        }
        if (prop == 'CASE_CREATED_ON') {
            return buildDateClause('FEC_Case_Created_On__c', op, vText);
        }
        if (prop == 'ATTACHMENTS') {
            Boolean wantHas = interpretBoolean(vText);
            if (op == 'equals' && wantHas != null) {
                if (wantHas) {
                    return 'Id IN (SELECT LinkedEntityId FROM ContentDocumentLink)';
                }
                return 'Id NOT IN (SELECT LinkedEntityId FROM ContentDocumentLink)';
            }
            if (op == 'not_equal_to' && wantHas != null) {
                if (wantHas) {
                    return 'Id NOT IN (SELECT LinkedEntityId FROM ContentDocumentLink)';
                }
                return 'Id IN (SELECT LinkedEntityId FROM ContentDocumentLink)';
            }
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static Boolean interpretBoolean(String vText) {
        if (String.isBlank(vText)) {
            return null;
        }
        String s = vText.toLowerCase();
        if (s == 'true' || s == '1' || s == 'yes') {
            return true;
        }
        if (s == 'false' || s == '0' || s == 'no') {
            return false;
        }
        return null;
    }

    private static String buildInOrNotClause(String fieldApi, String op, List<String> vList, String vText, Boolean bindAsString) {
        List<String> vals = new List<String>();
        if (vList != null && !vList.isEmpty()) {
            vals.addAll(vList);
        } else if (String.isNotBlank(vText)) {
            vals.add(vText);
        }
        if (vals.isEmpty()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        List<String> lit = new List<String>();
        for (String v : vals) {
            lit.add('\'' + String.escapeSingleQuotes(v) + '\'');
        }
        String inList = '(' + String.join(lit, ',') + ')';
        if (op == 'equals') {
            return fieldApi + ' IN ' + inList;
        }
        if (op == 'not_equal_to') {
            return fieldApi + ' NOT IN ' + inList;
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static String buildTextClause(String fieldApi, String op, String vText) {
        if (String.isBlank(vText) && op != 'is_null' && op != 'is_not_null') {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String esc = String.escapeSingleQuotes(vText);
        if (op == 'equals') {
            return fieldApi + ' = \'' + esc + '\'';
        }
        if (op == 'not_equal_to') {
            return fieldApi + ' != \'' + esc + '\'';
        }
        if (op == 'contains') {
            return fieldApi + ' LIKE \'%' + esc + '%\'';
        }
        if (op == 'does_not_contain') {
            return '(NOT (' + fieldApi + ' LIKE \'%' + esc + '%\'))';
        }
        if (op == 'starts_with') {
            return fieldApi + ' LIKE \'' + esc + '%\'';
        }
        if (op == 'does_not_start_with') {
            return '(NOT (' + fieldApi + ' LIKE \'' + esc + '%\'))';
        }
        if (op == 'is_null') {
            return fieldApi + ' = null';
        }
        if (op == 'is_not_null') {
            return fieldApi + ' != null';
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static String buildLookupClause(String fieldApi, String op, String vText) {
        if (String.isBlank(vText) && op != 'is_null' && op != 'is_not_null') {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String esc = String.escapeSingleQuotes(vText);
        if (op == 'equals') {
            return fieldApi + ' = \'' + esc + '\'';
        }
        if (op == 'not_equal_to') {
            return fieldApi + ' != \'' + esc + '\'';
        }
        if (op == 'contains') {
            return fieldApi + ' = \'' + esc + '\'';
        }
        if (op == 'does_not_contain') {
            return fieldApi + ' != \'' + esc + '\'';
        }
        if (op == 'starts_with') {
            return fieldApi + ' = \'' + esc + '\'';
        }
        if (op == 'does_not_start_with') {
            return fieldApi + ' != \'' + esc + '\'';
        }
        if (op == 'is_null') {
            return fieldApi + ' = null';
        }
        if (op == 'is_not_null') {
            return fieldApi + ' != null';
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static String buildDateClause(String fieldApi, String op, String vText) {
        if (String.isBlank(vText)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Date d;
        try {
            d = Date.valueOf(vText);
        } catch (Exception e) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String y = String.valueOf(d.year());
        String mo = d.month() < 10 ? '0' + String.valueOf(d.month()) : String.valueOf(d.month());
        String da = d.day() < 10 ? '0' + String.valueOf(d.day()) : String.valueOf(d.day());
        String dayLit = y + '-' + mo + '-' + da;
        if (op == 'equals') {
            return 'DATEVALUE(' + fieldApi + ') = ' + dayLit;
        }
        if (op == 'not_equal_to') {
            return 'DATEVALUE(' + fieldApi + ') != ' + dayLit;
        }
        if (op == 'less_than') {
            return 'DATEVALUE(' + fieldApi + ') < ' + dayLit;
        }
        if (op == 'greater_than') {
            return 'DATEVALUE(' + fieldApi + ') > ' + dayLit;
        }
        if (op == 'less_or_equal') {
            return 'DATEVALUE(' + fieldApi + ') <= ' + dayLit;
        }
        if (op == 'greater_or_equal') {
            return 'DATEVALUE(' + fieldApi + ') >= ' + dayLit;
        }
        return FEC_ConstantCommon.STR_EMPTY;
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
            if (!dfr.isCreateable() || dfr.isAutoNumber() || dfr.isCalculated()) {
                continue;
            }
            recordToFill.put(name, value);
            return;
        }
    }

    private static String removeFileExtension(String fileName) {
        if (fileName == null) {
            return fileName;
        }
        Integer idx = fileName.lastIndexOf('.');
        if (idx <= 0) {
            return fileName;
        }
        return fileName.substring(0, idx);
    }

    @AuraEnabled
    public static ImportResult importBatchData(
        String fileName,
        String fileBodyBase64,
        String templateName,
        String rowsJson
    ) {
        ImportResult out = new ImportResult();
        out.success = false;

        if (String.isBlank(fileName) || String.isBlank(fileBodyBase64) || String.isBlank(rowsJson)) {
            out.message = 'Vui lòng đính kèm tệp dữ liệu';
            upsertFailedBatchHandling(fileName, templateName, out.message);
            return out;
        }

        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(OBJECT_API_NAME).getDescribe().fields.getMap();
        SObject batchRow;
        try {
            List<Object> inputRows = (List<Object>) JSON.deserializeUntyped(rowsJson);
            if (inputRows == null || inputRows.isEmpty()) {
                out.message = 'Vui lòng đính kèm tệp dữ liệu';
                upsertFailedBatchHandling(fileName, templateName, out.message);
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

            batchRow = Schema.getGlobalDescribe().get(OBJECT_API_NAME).newSObject();
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'Name', 'FEC_File_Name__c' }, fileName);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Uploaded');
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, FEC_ConstantCommon.STR_EMPTY);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Template_Name__c', 'FEC_Template__c' }, templateName);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_File_Content_Document_Id__c' }, String.valueOf(insertedCv.ContentDocumentId));
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, FEC_ConstantCommon.STR_EMPTY);
            insert batchRow;
            linkFileToBatchHandling((Id) batchRow.get('Id'), insertedCv.ContentDocumentId);

            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processing');
            update batchRow;

            Boolean cofOrGsr = isCofOrGsrTemplate(templateName);
            List<CaseHandlingImportRow> rowResults = validateCaseHandlingImportRows(inputRows, cofOrGsr);
            applyCaseHandlingUpdates(rowResults, cofOrGsr);
            Integer failedCount = countFailedImportRows(rowResults);
            Integer totalCount = rowResults.size();
            Integer successCount = totalCount - failedCount;
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, totalCount);

            String finalStatus;
            String failureReason = FEC_ConstantCommon.STR_EMPTY;
            if (totalCount == 0) {
                finalStatus = 'Failure';
                failureReason = 'Vui lòng đính kèm tệp dữ liệu';
            } else if (failedCount == totalCount) {
                finalStatus = 'Failure';
                failureReason = 'Một hoặc nhiều dòng import không hợp lệ.';
            } else {
                finalStatus = 'Processed';
            }
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, finalStatus);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, successCount < 0 ? 0 : successCount);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, failedCount);
            putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, failureReason);
            update batchRow;

            out.success = true;
            out.message = 'Import request has been submitted.';
            out.batchRecordId = (Id) batchRow.get('Id');
            out.contentDocumentId = insertedCv.ContentDocumentId;
            out.status = finalStatus;
            out.resultRowsJson = JSON.serialize(rowResults);
            return out;
        } catch (Exception ex) {
            if (batchRow != null && batchRow.get('Id') != null) {
                try {
                    putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Failure');
                    putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
                    putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, ex.getMessage());
                    update batchRow;
                } catch (Exception nestedEx) {
                    upsertFailedBatchHandling(fileName, templateName, ex.getMessage());
                }
            } else {
                upsertFailedBatchHandling(fileName, templateName, ex.getMessage());
            }
            out.message = ex.getMessage();
            return out;
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

    @AuraEnabled
    public static void logFailedImport(String fileName, String templateName, String reason) {
        upsertFailedBatchHandling(fileName, templateName, reason);
    }

    private static void upsertFailedBatchHandling(String fileName, String templateName, String reason) {
        try {
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(OBJECT_API_NAME).getDescribe().fields.getMap();
            SObject failedRow = Schema.getGlobalDescribe().get(OBJECT_API_NAME).newSObject();
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'Name', 'FEC_File_Name__c' }, fileName);
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Status__c' }, 'Failure');
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Result__c' }, 'Result');
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Failure_Reason__c' }, reason);
            putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Template_Name__c', 'FEC_Template__c' }, templateName);
            insert failedRow;
        } catch (Exception ex) {
        }
    }

    private static void linkFileToBatchHandling(Id batchId, Id contentDocumentId) {
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

    private static Boolean isCofOrGsrTemplate(String templateName) {
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

    private static Boolean routingActionRequiresExtraParams(String methodKey) {
        if (String.isBlank(methodKey)) {
            return true;
        }
        return methodKey == FEC_CaseBusinessService.ROUTE_TO ||
            methodKey == FEC_CaseBusinessService.UPDATEACTION ||
            methodKey == FEC_CaseBusinessService.TRANSFER ||
            methodKey == FEC_CaseBusinessService.REVERT;
    }

    private static Boolean isResolvedOrRejectCaseRouting(String routingLabel) {
        String k = resolveRoutingMethodKey(routingLabel);
        if (String.isBlank(k)) {
            return false;
        }
        return k == FEC_CaseBusinessService.RESOLVE || k == FEC_CaseBusinessService.REJECT;
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

    private static String appendError(String current, String incoming) {
        if (String.isBlank(incoming)) {
            return current;
        }
        if (String.isBlank(current)) {
            return incoming;
        }
        return current + ' ' + incoming;
    }

    private static Integer countFailedImportRows(List<CaseHandlingImportRow> rows) {
        Integer n = 0;
        for (CaseHandlingImportRow r : rows) {
            if (r != null && r.status == System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed) {
                n += 1;
            }
        }
        return n;
    }

    private static List<CaseHandlingImportRow> validateCaseHandlingImportRows(List<Object> inputRows, Boolean cofOrGsr) {
        List<CaseHandlingImportRow> output = new List<CaseHandlingImportRow>();
        List<String> searchKeys = new List<String>();
        for (Object rowObj : inputRows) {
            if (!(rowObj instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> row = (Map<String, Object>) rowObj;
            CaseHandlingImportRow rr = new CaseHandlingImportRow();
            rr.caseIdSearch = pickRowString(row, new List<String>{ 'caseidsearch', 'caseid' });
            rr.routingAction = pickRowString(row, new List<String>{ 'routingaction' });
            rr.inputtedRemarks = pickRowString(row, new List<String>{ 'inputtedremarks', 'remark', 'remarks' });
            rr.assignmentId = pickRowString(row, new List<String>{ 'assignmentid' });
            rr.assignmentRoutingAction = pickRowString(row, new List<String>{ 'assignmentroutingaction' });
            Boolean rowEmpty =
                String.isBlank(rr.caseIdSearch) &&
                String.isBlank(rr.routingAction) &&
                String.isBlank(rr.inputtedRemarks) &&
                String.isBlank(rr.assignmentId) &&
                String.isBlank(rr.assignmentRoutingAction);
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
                SELECT Id, IsClosed, FEC_ID_Search__c
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
        for (CaseHandlingImportRow rr : output) {
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

        Set<String> seenCaseSearch = new Set<String>();
        for (CaseHandlingImportRow rr : output) {
            List<String> errs = new List<String>();
            if (String.isBlank(rr.caseIdSearch)) {
                errs.add('Thiếu dữ liệu Case ID.');
            }
            Case matched = String.isNotBlank(rr.caseIdSearch) ? caseBySearch.get(rr.caseIdSearch) : null;
            if (String.isNotBlank(rr.caseIdSearch) && matched == null) {
                errs.add('Case ID không tồn tại trong hệ thống');
            } else if (matched != null && matched.IsClosed) {
                errs.add('Case ID đã ở trạng thái Closed (không cho phép cập nhật)');
            }
            if (String.isNotBlank(rr.caseIdSearch)) {
                if (seenCaseSearch.contains(rr.caseIdSearch)) {
                    errs.add('Cùng Case ID xuất hiện nhiều dòng trong file import.');
                } else {
                    seenCaseSearch.add(rr.caseIdSearch);
                }
            }

            if (cofOrGsr) {
                Boolean hasAssignment = String.isNotBlank(rr.assignmentId);
                if (hasAssignment) {
                    Id asgId;
                    try {
                        asgId = Id.valueOf(rr.assignmentId.trim());
                    } catch (Exception e) {
                        errs.add('Assignment ID không tồn tại trong hệ thống');
                        asgId = null;
                    }
                    if (asgId != null) {
                        FEC_Assignment__c asg = assignmentById.get(asgId);
                        if (asg == null) {
                            errs.add('Assignment ID không tồn tại trong hệ thống');
                        } else if (matched != null && asg.FEC_Case__c != matched.Id) {
                            errs.add('Assignment ID không tồn tại trong hệ thống');
                        } else if (String.isNotBlank(asg.FEC_Assignment_Status__c) && asg.FEC_Assignment_Status__c.startsWith('Resolved-')) {
                            errs.add('Assignment ID đã ở trạng thái Closed (không cho phép cập nhật)');
                        }
                    }
                    if (String.isNotBlank(rr.routingAction) && String.isNotBlank(rr.assignmentRoutingAction)) {
                        errs.add('Đã nhập Assignment Routing Action thì không nhập Routing Action ở level Case.');
                    }
                    if (String.isBlank(rr.routingAction) && String.isBlank(rr.assignmentRoutingAction)) {
                        errs.add('Thiếu dữ liệu Routing Action/Assignment Routing Action.');
                    }
                    if (String.isNotBlank(rr.routingAction)) {
                        String caseMethod = resolveRoutingMethodKey(rr.routingAction);
                        if (caseMethod == null) {
                            errs.add('Giá trị Routing Action không đúng format hoặc không tồn tại trong Datagroup đã define');
                        } else if (!isResolvedOrRejectCaseRouting(rr.routingAction)) {
                            errs.add('Khi có Assignment ID, chỉ cho phép Routing Action level Case là Resolve/Reject.');
                        }
                    }
                    if (String.isNotBlank(rr.assignmentRoutingAction) && resolveRoutingMethodKey(rr.assignmentRoutingAction) == null) {
                        errs.add('Giá trị Assignment Routing Action không đúng format hoặc không tồn tại trong Datagroup đã define');
                    }
                } else {
                    if (String.isBlank(rr.routingAction)) {
                        errs.add('Thiếu dữ liệu Routing Action');
                    } else if (resolveRoutingMethodKey(rr.routingAction) == null) {
                        errs.add('Giá trị Routing Action không đúng format hoặc không tồn tại trong Datagroup đã define');
                    }
                    if (String.isNotBlank(rr.assignmentRoutingAction)) {
                        errs.add('Không nhập Assignment Routing Action khi không có Assignment ID.');
                    }
                }
            } else {
                if (String.isNotBlank(rr.assignmentRoutingAction)) {
                    errs.add('Không nhập Assignment Routing Action đối với quy trình này.');
                }
                if (String.isNotBlank(rr.assignmentId)) {
                    errs.add('Không sử dụng Assignment ID đối với quy trình này.');
                }
                if (String.isBlank(rr.routingAction)) {
                    errs.add('Thiếu dữ liệu Routing Action');
                } else if (resolveRoutingMethodKey(rr.routingAction) == null) {
                    errs.add('Giá trị Routing Action không đúng format hoặc không tồn tại trong Datagroup đã define');
                }
            }

            if (String.isBlank(rr.inputtedRemarks)) {
                errs.add('Thiếu dữ liệu Remark');
            } else if (rr.inputtedRemarks.length() > REMARK_MAX_LEN) {
                errs.add('Giá trị Remark vượt quá số ký tự cho phép (32,768 ký tự)');
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

    private static void applyCaseHandlingUpdates(List<CaseHandlingImportRow> rows, Boolean cofOrGsr) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        for (CaseHandlingImportRow rr : rows) {
            if (rr == null || rr.status == System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed || String.isBlank(rr.recordId)) {
                continue;
            }
            Id caseId;
            try {
                caseId = Id.valueOf(rr.recordId);
            } catch (Exception e) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(rr.errors, 'Record Id không hợp lệ.');
                continue;
            }
            String actionLabel = rr.routingAction;
            if (cofOrGsr && String.isBlank(actionLabel)) {
                actionLabel = rr.assignmentRoutingAction;
            }
            String methodKey = resolveRoutingMethodKey(actionLabel);
            if (String.isBlank(methodKey)) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(
                    rr.errors,
                    cofOrGsr
                        ? 'Giá trị Assignment Routing Action không đúng format hoặc không tồn tại trong Datagroup đã define'
                        : 'Giá trị Routing Action không đúng format hoặc không tồn tại trong Datagroup đã define'
                );
                continue;
            }
            if (routingActionRequiresExtraParams(methodKey)) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(
                    rr.errors,
                    'Routing action cần tham số bổ sung (queue / decision / transfer / revert) — không xử lý qua Bulk Import.'
                );
                continue;
            }
            try {
                FEC_CaseBusinessService.run(methodKey, new Map<String, String>{ 'caseId' => String.valueOf(caseId) });
            } catch (Exception ex) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(rr.errors, ex.getMessage());
                continue;
            }
            if (String.isNotBlank(rr.inputtedRemarks)) {
                try {
                    FEC_CaseRemarkController.createRemark(rr.inputtedRemarks, String.valueOf(caseId), null);
                } catch (Exception ex) {
                    rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                    rr.errors = appendError(rr.errors, ex.getMessage());
                }
            }
        }
    }

}
