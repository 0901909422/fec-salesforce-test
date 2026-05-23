public without sharing class FEC_BatchCaseHandlingController {
    private static final String OBJECT_API_NAME = 'FEC_Batch_Case_Handling__c';
    private static final Integer MAX_ROWS = 200;
    private static final Integer MAX_ATTACHMENT_CASE_SET = 1000;
    private static final Integer MAX_EXPORT_ROWS = 100000;
    private static final Integer EXPORT_CURSOR_PAGE_SIZE = 1000;
    private static final String PROPERTY_GROUP_PREDEFINED = 'PREDEFINED';
    private static final String PROPERTY_GROUP_CASE_FIELD = 'CASE_FIELD';
    private static final String QUEUE_MY_PENDING = 'My Pending Cases';
    public class FilterPicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
    public class FilterPropertyMeta {
        @AuraEnabled public String propertyKey;
        @AuraEnabled public String label;
        @AuraEnabled public String valueType;
        @AuraEnabled public List<String> operators;
        @AuraEnabled public String propertyGroup;
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public Boolean multiValue;
        @AuraEnabled public List<FilterPicklistOption> picklistOptions;
    }

    public class BulkCaseSearchResult {
        @AuraEnabled public List<FEC_BatchCaseHandlingExportRow> rows;
        @AuraEnabled public Integer totalCount;
    }

    public class CaseSetRangeOption {
        @AuraEnabled public String label;
        @AuraEnabled public Integer startIndex;
        @AuraEnabled public Integer endIndex;
    }

    public class BusinessProcessExportRow {
        @AuraEnabled public String businessProcessCode;
        @AuraEnabled public String businessProcessName;
        @AuraEnabled public Integer totalCases;
        @AuraEnabled public String templateName;
        @AuraEnabled public String templateDownloadUrl;
        @AuraEnabled public Id templateContentVersionId;
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

    public class FilterPropertyMetadataBundle {
        @AuraEnabled public List<FilterPropertyMeta> preDefineProperties;
        @AuraEnabled public List<FilterPropertyMeta> allCaseProperties;
    }

    @AuraEnabled(cacheable=true)
    public static List<FilterPropertyMeta> getCaseFilterPropertyMetadata(String filterScope) {
        List<FilterPropertyMeta> out = FEC_BCH_FilterPropertyService.getMetadata(filterScope);
        hydrateFilterMetadata(out);
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static FilterPropertyMetadataBundle getCaseFilterPropertyMetadataBundle() {
        FilterPropertyMetadataBundle bundle = new FilterPropertyMetadataBundle();
        bundle.preDefineProperties = FEC_BCH_FilterPropertyService.getMetadata(
            FEC_BCH_FilterPropertyService.SCOPE_PRE_DEFINE
        );
        hydrateFilterMetadata(bundle.preDefineProperties);
        bundle.allCaseProperties = FEC_BCH_FilterPropertyService.getMetadata(
            FEC_BCH_FilterPropertyService.SCOPE_ALL_CASE
        );
        hydrateFilterMetadata(bundle.allCaseProperties);
        return bundle;
    }

    private static void hydrateFilterMetadata(List<FilterPropertyMeta> metas) {
        if (metas == null || metas.isEmpty()) {
            return;
        }
        Map<String, Schema.SObjectField> caseFieldMap = Case.SObjectType.getDescribe().fields.getMap();
        for (FilterPropertyMeta m : metas) {
            if (m == null) {
                continue;
            }
            m.propertyGroup = FEC_BCH_FilterPropertyService.isPredefinedPropertyKey(m.propertyKey)
                ? PROPERTY_GROUP_PREDEFINED
                : PROPERTY_GROUP_CASE_FIELD;
            m.picklistOptions = new List<FilterPicklistOption>();
            m.multiValue = false;
            if (PROPERTY_GROUP_PREDEFINED == m.propertyGroup) {
                hydratePredefinedFilterMeta(m);
            } else {
                hydrateCaseFieldFilterMeta(m, caseFieldMap);
            }
        }
    }

    private static void hydratePredefinedFilterMeta(FilterPropertyMeta m) {
        String key = String.isBlank(m.propertyKey) ? FEC_ConstantCommon.STR_EMPTY : m.propertyKey.trim().toUpperCase();
        if (key == 'CUSTOMER_TYPE') {
            m.fieldApiName = 'FEC_Customer_Type__c';
            m.multiValue = true;
            m.picklistOptions = toFilterPicklistOptions(
                FEC_CommonUltils.getPicklistOptionsWithAccess('Case', m.fieldApiName)
            );
            return;
        }
        if (key == 'QUEUE') {
            m.fieldApiName = FEC_ConstantCommon.STR_EMPTY;
            m.multiValue = true;
            m.picklistOptions = loadQueueOptions();
            return;
        }
        if (key == 'PRODUCT_TYPE') {
            m.fieldApiName = 'FEC_Product_Type__c';
            m.picklistOptions = loadMasterDataCodeOptions('FEC_Product_Type__c');
            return;
        }
        if (key == 'CATEGORY') {
            m.fieldApiName = 'FEC_Category__c';
            m.picklistOptions = loadMasterDataCodeOptions('FEC_Category__c');
            return;
        }
        if (key == 'SUB_CATEGORY') {
            m.fieldApiName = 'FEC_SubCategory__c';
            m.picklistOptions = loadMasterDataCodeOptions('FEC_Sub_Category__c');
            return;
        }
        if (key == 'SUB_CODE') {
            m.fieldApiName = 'FEC_SubCode__c';
            m.picklistOptions = loadMasterDataCodeOptions('FEC_Sub_Code__c');
            return;
        }
        if (key == 'CASE_ID') {
            m.fieldApiName = 'FEC_ID_Search__c';
            return;
        }
        if (key == 'CASE_CREATED_ON') {
            m.fieldApiName = 'FEC_Case_Created_On__c';
            return;
        }
        if (key == 'CASE_CREATED_BY') {
            m.fieldApiName = 'FEC_Case_Created_By__c';
            m.multiValue = true;
            m.picklistOptions = loadCaseCreatedByOptions();
            return;
        }
        if (key == 'CASE_CREATED_BY_ROLE') {
            m.fieldApiName = 'CreatedBy.FEC_User_Group__c';
            m.multiValue = true;
            m.picklistOptions = loadUserGroupOptions();
            return;
        }
        if (key == 'CASE_STATUS') {
            m.fieldApiName = 'FEC_Final_Status__c';
            m.multiValue = true;
            m.picklistOptions = loadCaseStatusOptions();
            return;
        }
        if (key == 'ATTACHMENTS') {
            m.fieldApiName = FEC_ConstantCommon.STR_EMPTY;
        }
    }

    private static void hydrateCaseFieldFilterMeta(FilterPropertyMeta m, Map<String, Schema.SObjectField> caseFieldMap) {
        String fieldApi = m.propertyKey;
        m.fieldApiName = fieldApi;
        if (String.isBlank(fieldApi) || caseFieldMap == null || !caseFieldMap.containsKey(fieldApi)) {
            return;
        }
        Schema.DescribeFieldResult dfr = caseFieldMap.get(fieldApi).getDescribe();
        Schema.DisplayType dt = dfr.getType();
        if (dt == Schema.DisplayType.MULTIPICKLIST) {
            m.multiValue = true;
        }
        if (dt == Schema.DisplayType.PICKLIST || dt == Schema.DisplayType.MULTIPICKLIST || dt == Schema.DisplayType.COMBOBOX) {
            m.picklistOptions = toFilterPicklistOptionsFromEntries(dfr.getPicklistValues());
        }
    }

    private static List<FilterPicklistOption> toFilterPicklistOptions(List<FEC_CommonUltils.PicklistOption> src) {
        List<FilterPicklistOption> out = new List<FilterPicklistOption>();
        if (src == null) {
            return out;
        }
        for (FEC_CommonUltils.PicklistOption o : src) {
            if (o == null || String.isBlank(o.value)) {
                continue;
            }
            FilterPicklistOption item = new FilterPicklistOption();
            item.label = String.isBlank(o.label) ? o.value : o.label;
            item.value = o.value;
            out.add(item);
        }
        return out;
    }

    private static List<FilterPicklistOption> toFilterPicklistOptionsFromEntries(List<Schema.PicklistEntry> entries) {
        List<FilterPicklistOption> out = new List<FilterPicklistOption>();
        if (entries == null) {
            return out;
        }
        for (Schema.PicklistEntry entry : entries) {
            if (entry == null) {
                continue;
            }
            String value = entry.getValue();
            if (String.isBlank(value)) {
                continue;
            }
            FilterPicklistOption item = new FilterPicklistOption();
            item.label = String.isBlank(entry.getLabel()) ? value : entry.getLabel();
            item.value = value;
            out.add(item);
        }
        return out;
    }

    private static List<FilterPicklistOption> loadCaseStatusOptions() {
        List<FilterPicklistOption> out = new List<FilterPicklistOption>();
        for (FEC_CommonUltils.PicklistOption o : FEC_CommonUltils.getPicklistOptionsWithAccess('Case', 'FEC_Final_Status__c')) {
            if (o == null || String.isBlank(o.value)) {
                continue;
            }
            String v = o.value;
            if (v == 'Open' || v.startsWith('Pending')) {
                FilterPicklistOption item = new FilterPicklistOption();
                item.label = String.isBlank(o.label) ? v : o.label;
                item.value = v;
                out.add(item);
            }
        }
        return out;
    }

    private static List<FilterPicklistOption> loadCaseCreatedByOptions() {
        List<FilterPicklistOption> out = new List<FilterPicklistOption>();
        Map<String, String> seen = new Map<String, String>();
        for (Case row : [
            SELECT FEC_Case_Created_By__c
            FROM Case
            WHERE RecordType.DeveloperName = :FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME
            AND FEC_Case_Created_By__c != null
            ORDER BY FEC_Case_Created_By__c
            LIMIT 5000
        ]) {
            String v = row.FEC_Case_Created_By__c == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(row.FEC_Case_Created_By__c).trim();
            if (String.isBlank(v) || seen.containsKey(v)) {
                continue;
            }
            seen.put(v, v);
            FilterPicklistOption item = new FilterPicklistOption();
            item.label = v;
            item.value = v;
            out.add(item);
        }
        return out;
    }

    private static List<FilterPicklistOption> loadUserGroupOptions() {
        List<FilterPicklistOption> out = new List<FilterPicklistOption>();
        Map<String, Schema.SObjectField> userFields = User.SObjectType.getDescribe().fields.getMap();
        if (!userFields.containsKey('FEC_User_Group__c')) {
            return out;
        }
        for (AggregateResult ar : [
            SELECT FEC_User_Group__c grp
            FROM User
            WHERE FEC_User_Group__c != null
            GROUP BY FEC_User_Group__c
            ORDER BY FEC_User_Group__c
            LIMIT 500
        ]) {
            String v = ar.get('grp') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(ar.get('grp'));
            if (String.isBlank(v)) {
                continue;
            }
            FilterPicklistOption item = new FilterPicklistOption();
            item.label = v;
            item.value = v;
            out.add(item);
        }
        return out;
    }

    private static List<FilterPicklistOption> loadQueueOptions() {
        List<FilterPicklistOption> out = new List<FilterPicklistOption>();
        FilterPicklistOption myPending = new FilterPicklistOption();
        myPending.label = QUEUE_MY_PENDING;
        myPending.value = QUEUE_MY_PENDING;
        out.add(myPending);
        Id currentUserId = UserInfo.getUserId();
        for (GroupMember gm : [
            SELECT Group.Name
            FROM GroupMember
            WHERE UserOrGroupId = :currentUserId AND Group.Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            ORDER BY Group.Name
        ]) {
            if (gm.Group == null || String.isBlank(gm.Group.Name)) {
                continue;
            }
            FilterPicklistOption item = new FilterPicklistOption();
            item.label = gm.Group.Name;
            item.value = gm.Group.Name;
            out.add(item);
        }
        return out;
    }

    private static List<FilterPicklistOption> loadMasterDataCodeOptions(String objectApi) {
        List<FilterPicklistOption> out = new List<FilterPicklistOption>();
        if (objectApi == 'FEC_Product_Type__c') {
            for (FEC_Product_Type__c row : [
                SELECT FEC_Code__c
                FROM FEC_Product_Type__c
                WHERE FEC_Active__c = true AND FEC_Code__c != null
                ORDER BY FEC_Code__c
                LIMIT 5000
            ]) {
                FilterPicklistOption item = new FilterPicklistOption();
                item.label = row.FEC_Code__c;
                item.value = row.FEC_Code__c;
                out.add(item);
            }
        } else if (objectApi == 'FEC_Category__c') {
            for (FEC_Category__c row : [
                SELECT FEC_Code__c
                FROM FEC_Category__c
                WHERE FEC_Active__c = true AND FEC_Code__c != null
                ORDER BY FEC_Code__c
                LIMIT 5000
            ]) {
                FilterPicklistOption item = new FilterPicklistOption();
                item.label = row.FEC_Code__c;
                item.value = row.FEC_Code__c;
                out.add(item);
            }
        } else if (objectApi == 'FEC_Sub_Category__c') {
            for (FEC_Sub_Category__c row : [
                SELECT FEC_Code__c
                FROM FEC_Sub_Category__c
                WHERE FEC_Active__c = true AND FEC_Code__c != null
                ORDER BY FEC_Code__c
                LIMIT 5000
            ]) {
                FilterPicklistOption item = new FilterPicklistOption();
                item.label = row.FEC_Code__c;
                item.value = row.FEC_Code__c;
                out.add(item);
            }
        } else if (objectApi == 'FEC_Sub_Code__c') {
            for (FEC_Sub_Code__c row : [
                SELECT FEC_Code__c
                FROM FEC_Sub_Code__c
                WHERE FEC_Active__c = true AND FEC_Code__c != null
                ORDER BY FEC_Code__c
                LIMIT 5000
            ]) {
                FilterPicklistOption item = new FilterPicklistOption();
                item.label = row.FEC_Code__c;
                item.value = row.FEC_Code__c;
                out.add(item);
            }
        }
        return out;
    }

    @AuraEnabled
    public static List<BatchRow> getRecentRows() {
        FEC_BatchCaseHandlingImportService.expireStaleProcessingBatchImports(UserInfo.getUserId());
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(OBJECT_API_NAME).getDescribe().fields.getMap();
        String fileField = FEC_BatchCaseHandlingSObjectUtil.pickField(fieldMap, new List<String>{ 'FEC_File_Name__c' });
        String nameField = fieldMap.containsKey('Name') ? 'Name' : null;
        String fileContentDocumentIdField = FEC_BatchCaseHandlingSObjectUtil.pickField(fieldMap, new List<String>{ 'FEC_File_Content_Document_Id__c' });
        String uploadedOnField = FEC_BatchCaseHandlingSObjectUtil.pickField(fieldMap, new List<String>{ 'FEC_Uploaded_On__c', 'CreatedDate' });
        String totalRecordsField = FEC_BatchCaseHandlingSObjectUtil.pickField(fieldMap, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' });
        String totalSuccessField = FEC_BatchCaseHandlingSObjectUtil.pickField(fieldMap, new List<String>{ 'FEC_Total_Success_Records__c' });
        String totalFailedField = FEC_BatchCaseHandlingSObjectUtil.pickField(fieldMap, new List<String>{ 'FEC_Total_Failed_Records__c' });
        String statusField = FEC_BatchCaseHandlingSObjectUtil.pickField(fieldMap, new List<String>{ 'FEC_Status__c' });
        String failureReasonField = FEC_BatchCaseHandlingSObjectUtil.pickField(fieldMap, new List<String>{ 'FEC_Failure_Reason__c' });
        String resultField = FEC_BatchCaseHandlingSObjectUtil.pickField(fieldMap, new List<String>{ 'FEC_Result__c' });

        List<String> selectParts = new List<String>{ 'Id', 'CreatedBy.Email', 'CreatedById', 'CreatedDate' };
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, fileField);
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, nameField);
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, fileContentDocumentIdField);
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, uploadedOnField);
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, totalRecordsField);
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, totalSuccessField);
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, totalFailedField);
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, statusField);
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, failureReasonField);
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, resultField);

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
        Map<Id, String> sourceTitleByBatchId = new Map<Id, String>();
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
                String downloadUrl = FEC_ConstantCommon.CONTENT_VERSION_DOWNLOAD_URL_PREFIX + versionId;
                if (FEC_BatchImportCommon.isResultContentTitle(title)) {
                    if (!resultUrlByBatchId.containsKey(link.LinkedEntityId)) {
                        resultUrlByBatchId.put(link.LinkedEntityId, downloadUrl);
                    }
                } else if (!sourceUrlByBatchId.containsKey(link.LinkedEntityId)) {
                    sourceUrlByBatchId.put(link.LinkedEntityId, downloadUrl);
                    sourceTitleByBatchId.put(link.LinkedEntityId, title);
                }
            }
        }

        for (SObject row : rows) {
            BatchRow dto = new BatchRow();
            dto.id = (Id) row.get('Id');
            dto.fileName = FEC_BatchCaseHandlingSObjectUtil.asString(row.get(fileField));
            if (String.isBlank(dto.fileName) && String.isNotBlank(nameField)) {
                dto.fileName = FEC_BatchCaseHandlingSObjectUtil.asString(row.get(nameField));
            }
            if (String.isBlank(dto.fileName)) {
                dto.fileName = sourceTitleByBatchId.get(dto.id);
            }
            String sourceDocumentId = String.isBlank(fileContentDocumentIdField)
                ? null
                : FEC_BatchCaseHandlingSObjectUtil.asString(row.get(fileContentDocumentIdField));
            dto.fileDownloadUrl = sourceUrlByBatchId.get(dto.id);
            if (String.isBlank(dto.fileDownloadUrl) && String.isNotBlank(sourceDocumentId)) {
                dto.fileDownloadUrl = '/sfc/servlet.shepherd/document/download/' + sourceDocumentId;
            }
            dto.uploadedOn = FEC_BatchCaseHandlingSObjectUtil.asDatetime(row.get(uploadedOnField));
            SObject createdBy = row.getSObject('CreatedBy');
            dto.uploadedBy = createdBy == null ? null : (String) createdBy.get('Email');
            dto.totalRecordsCount = FEC_BatchCaseHandlingSObjectUtil.asDecimal(row.get(totalRecordsField));
            dto.totalSuccessRecords = FEC_BatchCaseHandlingSObjectUtil.asDecimal(row.get(totalSuccessField));
            dto.totalFailedRecords = FEC_BatchCaseHandlingSObjectUtil.asDecimal(row.get(totalFailedField));
            dto.status = FEC_BatchCaseHandlingSObjectUtil.asString(row.get(statusField));
            dto.failureReason = FEC_BatchCaseHandlingSObjectUtil.asString(row.get(failureReasonField));
            dto.result = FEC_BatchCaseHandlingSObjectUtil.asString(row.get(resultField));
            dto.resultDownloadUrl = resultUrlByBatchId.get(dto.id);
            output.add(dto);
        }
        return output;
    }

    @AuraEnabled
    public static BulkCaseSearchResult searchBulkCases(String filtersJson, Integer pageSize, Integer pageNumber) {
        BulkCaseSearchResult out = new BulkCaseSearchResult();
        out.rows = new List<FEC_BatchCaseHandlingExportRow>();
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

        List<Map<String, Object>> filterMaps = FEC_BatchCaseHandlingCaseFilter.parseFilterMaps(filtersJson);

        List<String> whereParts = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(filterMaps);
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
            '(SELECT Id FROM ContentDocumentLinks LIMIT 1)'
        };
        selectFields.addAll(FEC_BatchCaseHandlingTemplateHelper.buildCaseStageBusinessProcessSelectFields());
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
            FEC_BatchCaseHandlingExportRow r = new FEC_BatchCaseHandlingExportRow();
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
            FEC_BatchCaseHandlingTemplateHelper.applyStageBusinessProcessToExportRow(r, c);
            out.rows.add(r);
        }
        return out;
    }

    @AuraEnabled
    public static BulkCaseSearchResult searchBulkCasesForExport(String filtersJson, String afterCaseId, Integer pageSize) {
        BulkCaseSearchResult out = new BulkCaseSearchResult();
        out.rows = new List<FEC_BatchCaseHandlingExportRow>();
        out.totalCount = 0;
        Integer ps = pageSize == null || pageSize < 1 ? EXPORT_CURSOR_PAGE_SIZE : pageSize;
        if (ps > EXPORT_CURSOR_PAGE_SIZE) {
            ps = EXPORT_CURSOR_PAGE_SIZE;
        }

        List<Map<String, Object>> filterMaps = FEC_BatchCaseHandlingCaseFilter.parseFilterMaps(filtersJson);

        List<String> whereParts = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(filterMaps);

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
        List<String> selectFields = FEC_BatchCaseHandlingExportService.buildCaseExportSelectFields();
        String dataSoql =
            'SELECT ' + String.join(selectFields, ', ') +
            ' FROM Case WHERE ' + whereClause +
            ' ORDER BY Id ASC' +
            ' LIMIT ' + ps;

        List<Case> cases = Database.query(dataSoql);
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, cases);
        cases = (List<Case>) decision.getRecords();

        for (Case c : cases) {
            out.rows.add(FEC_BatchCaseHandlingExportService.mapCaseToExportRow(c));
        }
        FEC_BatchCaseHandlingExportService.enrichExportRows(out.rows);
        return out;
    }

    @AuraEnabled
    public static List<CaseSetRangeOption> getAttachmentCaseSetOptions(String filtersJson) {
        List<CaseSetRangeOption> out = new List<CaseSetRangeOption>();
        Integer total = 0;
        List<Map<String, Object>> filterMaps = FEC_BatchCaseHandlingCaseFilter.parseFilterMaps(filtersJson);
        List<String> whereParts = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(filterMaps);
        String whereClause = String.join(whereParts, ' AND ');
        total = Database.countQuery('SELECT COUNT() FROM Case WHERE ' + whereClause);
        if (total < 1) {
            return out;
        }
        Integer max = MAX_ATTACHMENT_CASE_SET;
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
    public static FEC_BatchCaseHandlingZipResult downloadAttachmentsZip(String filtersJson, Integer startIndex, Integer endIndex) {
        return FEC_BatchCaseHandlingZipService.downloadAttachmentsZip(filtersJson, startIndex, endIndex);
    }

    @AuraEnabled
    public static FEC_BatchCaseHandlingZipResult zipExcelFiles(List<Map<String, Object>> files, String archiveName) {
        return FEC_BatchCaseHandlingZipService.zipExcelFiles(files, archiveName);
    }

    @AuraEnabled
    public static FEC_BatchCaseHandlingZipResult downloadCaseAttachmentsZip(Id caseId) {
        return FEC_BatchCaseHandlingZipService.downloadCaseAttachmentsZip(caseId);
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getBulkExportAllowedBusinessProcessNames() {
        return new List<String>(FEC_BatchCaseHandlingTemplateHelper.queryAllowedBusinessProcessNames());
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getBulkExportAllowedBusinessProcessCodes() {
        return new List<String>(FEC_BatchCaseHandlingTemplateHelper.queryAllowedBusinessProcessCodes());
    }

    @AuraEnabled
    public static List<BusinessProcessExportRow> getBusinessProcessExportRows(String filtersJson) {
        List<BusinessProcessExportRow> out = new List<BusinessProcessExportRow>();
        List<Map<String, Object>> filterMaps = FEC_BatchCaseHandlingCaseFilter.parseFilterMaps(filtersJson);
        List<String> whereParts = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(filterMaps);
        whereParts.add(FEC_BatchCaseHandlingTemplateHelper.buildAllowedStageBusinessProcessWhereClause());
        String whereClause = String.join(whereParts, ' AND ');
        List<AggregateResult> grouped = Database.query(
            'SELECT FEC_Current_Case_Stage__r.FEC_Business_Process__r.FEC_Code__c bpCode, FEC_Current_Case_Stage__r.FEC_Business_Process__r.Name bpName, COUNT(Id) cnt ' +
            'FROM Case WHERE ' + whereClause +
            ' GROUP BY FEC_Current_Case_Stage__r.FEC_Business_Process__r.FEC_Code__c, FEC_Current_Case_Stage__r.FEC_Business_Process__r.Name'
        );

        List<SObject> templateRows = FEC_BatchCaseHandlingTemplateHelper.queryActiveBatchCaseHandlingTemplates();
        Map<Id, String> urlByTemplateId = new Map<Id, String>();
        Map<Id, Id> versionIdByTemplateId = new Map<Id, Id>();
        Set<Id> templateIds = new Set<Id>();
        for (SObject r : templateRows) {
            templateIds.add((Id) r.get('Id'));
        }
        if (!templateIds.isEmpty()) {
            FEC_BatchCaseHandlingTemplateHelper.populateTemplateContentVersionMaps(
                templateIds,
                versionIdByTemplateId,
                urlByTemplateId
            );
        }

        String userGroup = resolveCurrentUserGroup();

        for (AggregateResult ar : grouped) {
            String bpCode = ar.get('bpCode') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(ar.get('bpCode')).trim();
            String bpName = ar.get('bpName') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(ar.get('bpName')).trim();
            if (String.isBlank(bpCode) || !FEC_BatchCaseHandlingTemplateHelper.isAllowedBusinessProcessForExport(bpCode, bpName)) {
                continue;
            }
            BusinessProcessExportRow item = new BusinessProcessExportRow();
            item.businessProcessCode = bpCode;
            item.businessProcessName = bpName;
            item.totalCases = Integer.valueOf(String.valueOf(ar.get('cnt')));
            FEC_BatchCaseHandlingTemplateHelper.TemplateExportBinding binding =
                FEC_BatchCaseHandlingTemplateHelper.resolveExportTemplateBinding(
                    bpCode,
                    bpName,
                    userGroup,
                    templateRows,
                    versionIdByTemplateId,
                    urlByTemplateId
                );
            item.templateName = binding == null || binding.templateName == null
                ? FEC_ConstantCommon.STR_EMPTY
                : binding.templateName;
            item.templateDownloadUrl = binding == null || binding.templateDownloadUrl == null
                ? FEC_ConstantCommon.STR_EMPTY
                : binding.templateDownloadUrl;
            item.templateContentVersionId = binding == null ? null : binding.templateContentVersionId;
            out.add(item);
        }
        return out;
    }

    @AuraEnabled
    public static BusinessProcessExportRow resolveExportTemplateMeta(
        String businessProcessCode,
        String businessProcessName
    ) {
        BusinessProcessExportRow item = new BusinessProcessExportRow();
        item.businessProcessCode = String.isBlank(businessProcessCode)
            ? FEC_ConstantCommon.STR_EMPTY
            : businessProcessCode.trim();
        item.businessProcessName = String.isBlank(businessProcessName)
            ? item.businessProcessCode
            : businessProcessName.trim();
        item.totalCases = 0;
        List<SObject> templateRows = FEC_BatchCaseHandlingTemplateHelper.queryActiveBatchCaseHandlingTemplates();
        Map<Id, String> urlByTemplateId = new Map<Id, String>();
        Map<Id, Id> versionIdByTemplateId = new Map<Id, Id>();
        Set<Id> templateIds = new Set<Id>();
        for (SObject r : templateRows) {
            templateIds.add((Id) r.get('Id'));
        }
        if (!templateIds.isEmpty()) {
            FEC_BatchCaseHandlingTemplateHelper.populateTemplateContentVersionMaps(
                templateIds,
                versionIdByTemplateId,
                urlByTemplateId
            );
        }
        String userGroup = resolveCurrentUserGroup();
        FEC_BatchCaseHandlingTemplateHelper.TemplateExportBinding binding =
            FEC_BatchCaseHandlingTemplateHelper.resolveExportTemplateBinding(
                item.businessProcessCode,
                item.businessProcessName,
                userGroup,
                templateRows,
                versionIdByTemplateId,
                urlByTemplateId
            );
        item.templateName = binding == null || binding.templateName == null
            ? FEC_ConstantCommon.STR_EMPTY
            : binding.templateName;
        item.templateDownloadUrl = binding == null || binding.templateDownloadUrl == null
            ? FEC_ConstantCommon.STR_EMPTY
            : binding.templateDownloadUrl;
        item.templateContentVersionId = binding == null ? null : binding.templateContentVersionId;
        return item;
    }

    private static String resolveImportTemplateName(
        String templateName,
        String businessProcessCode,
        String businessProcessName
    ) {
        if (String.isNotBlank(templateName) && !'Other'.equalsIgnoreCase(templateName.trim()) && !'GSR'.equalsIgnoreCase(templateName.trim())) {
            return templateName.trim();
        }
        if (String.isBlank(businessProcessCode) && String.isBlank(businessProcessName)) {
            return String.isBlank(templateName) ? FEC_ConstantCommon.STR_EMPTY : templateName.trim();
        }
        List<SObject> templateRows = FEC_BatchCaseHandlingTemplateHelper.queryActiveBatchCaseHandlingTemplates();
        Map<Id, String> urlByTemplateId = new Map<Id, String>();
        Map<Id, Id> versionIdByTemplateId = new Map<Id, Id>();
        Set<Id> templateIds = new Set<Id>();
        for (SObject r : templateRows) {
            templateIds.add((Id) r.get('Id'));
        }
        if (!templateIds.isEmpty()) {
            FEC_BatchCaseHandlingTemplateHelper.populateTemplateContentVersionMaps(
                templateIds,
                versionIdByTemplateId,
                urlByTemplateId
            );
        }
        FEC_BatchCaseHandlingTemplateHelper.TemplateExportBinding binding =
            FEC_BatchCaseHandlingTemplateHelper.resolveExportTemplateBinding(
                businessProcessCode,
                businessProcessName,
                resolveCurrentUserGroup(),
                templateRows,
                versionIdByTemplateId,
                urlByTemplateId
            );
        if (binding != null && String.isNotBlank(binding.templateName)) {
            return binding.templateName;
        }
        return String.isBlank(templateName) ? FEC_ConstantCommon.STR_EMPTY : templateName.trim();
    }

    private static String resolveCurrentUserGroup() {
        Map<String, Schema.SObjectField> userFields = User.SObjectType.getDescribe().fields.getMap();
        if (!userFields.containsKey('FEC_User_Group__c')) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        User u = [
            SELECT FEC_User_Group__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        return String.isBlank(u.FEC_User_Group__c) ? FEC_ConstantCommon.STR_EMPTY : u.FEC_User_Group__c.trim();
    }

    @AuraEnabled(cacheable=true)
    public static String getTemplateFileBase64(Id contentVersionId) {
        if (contentVersionId == null) {
            return null;
        }
        List<ContentVersion> versions = [
            SELECT VersionData
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];
        if (versions.isEmpty() || versions[0].VersionData == null) {
            return null;
        }
        return EncodingUtil.base64Encode(versions[0].VersionData);
    }

    @AuraEnabled
    public static FEC_BCH_TemplateExportService.ExportWorkbookResponse exportTemplateWorkbook(
        String requestJson
    ) {
        return FEC_BCH_TemplateExportService.exportWorkbook(requestJson);
    }
    @AuraEnabled
    public static ImportResult importBatchData(
        String fileName,
        String fileBodyBase64,
        String templateName,
        String rowsJson,
        String businessProcessCode,
        String businessProcessName
    ) {
        ImportResult out = new ImportResult();
        out.success = false;

        if (String.isBlank(fileName) || String.isBlank(fileBodyBase64) || String.isBlank(rowsJson)) {
            out.message = System.Label.FEC_BCH_RequireFile;
            upsertFailedBatchHandling(fileName, templateName, out.message);
            return out;
        }

        Schema.SObjectType batchType = Schema.getGlobalDescribe().get(OBJECT_API_NAME);
        if (batchType == null) {
            out.message = System.Label.FEC_BCH_ImportFailed;
            upsertFailedBatchHandling(fileName, templateName, out.message);
            return out;
        }
        Map<String, Schema.SObjectField> fieldMap = batchType.getDescribe().fields.getMap();
        SObject batchRow;
        try {
            List<Object> inputRows = (List<Object>) JSON.deserializeUntyped(rowsJson);
            if (inputRows == null || inputRows.isEmpty()) {
                out.message = System.Label.FEC_BCH_RequireFile;
                upsertFailedBatchHandling(fileName, templateName, out.message);
                return out;
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = FEC_BatchCaseHandlingSObjectUtil.removeFileExtension(fileName);
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
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_File_Name__c' }, fileName);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(
                fieldMap,
                batchRow,
                new List<String>{ 'FEC_Total_Records__c', 'FEC_Total_Records_Count__c' },
                inputRows.size()
            );
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Uploaded');
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, FEC_ConstantCommon.STR_EMPTY);
            String resolvedTemplateName = resolveImportTemplateName(
                templateName,
                businessProcessCode,
                businessProcessName
            );
            if (
                FEC_BatchCaseHandlingTemplateHelper.validateUploadedTemplateFileName(
                    fileName,
                    resolvedTemplateName
                ) != null
            ) {
                out.message = 'Tên file không khớp template Bulk Actions của quy trình và nhóm người dùng.';
                upsertFailedBatchHandling(fileName, resolvedTemplateName, out.message);
                return out;
            }
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(
                fieldMap,
                batchRow,
                new List<String>{ 'FEC_Template_Name__c', 'FEC_Template__c' },
                resolvedTemplateName
            );
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_File_Content_Document_Id__c' }, String.valueOf(insertedCv.ContentDocumentId));
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, FEC_ConstantCommon.STR_EMPTY);
            insert batchRow;
            linkFileToBatchHandling((Id) batchRow.get('Id'), insertedCv.ContentDocumentId);

            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processing');
            update batchRow;

            Boolean cofOrGsr = FEC_BatchCaseHandlingImportService.isCofOrGsrTemplate(resolvedTemplateName);
            List<FEC_BatchCaseHandlingImportRow> rowResults = FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, cofOrGsr);
            if (FEC_BatchCaseHandlingImportService.hasApplicableImportRows(rowResults)) {
                System.enqueueJob(
                    new FEC_BatchCaseHandlingImportQueueable(
                        (Id) batchRow.get('Id'),
                        JSON.serialize(rowResults),
                        cofOrGsr,
                        0
                    )
                );
                out.success = true;
                out.message = System.Label.FEC_BCH_Import_Submitted;
                out.batchRecordId = (Id) batchRow.get('Id');
                out.contentDocumentId = insertedCv.ContentDocumentId;
                out.status = 'Processing';
                out.resultRowsJson = JSON.serialize(rowResults);
                return out;
            }

            FEC_BatchCaseHandlingImportService.finalizeBatchImportRecord((Id) batchRow.get('Id'), rowResults);
            Integer failedCount = FEC_BatchCaseHandlingImportService.countFailedImportRows(rowResults);
            Integer totalCount = rowResults.size();
            String finalStatus;
            String failureReason = FEC_ConstantCommon.STR_EMPTY;
            if (totalCount == 0) {
                finalStatus = 'Failure';
                failureReason = System.Label.FEC_BCH_RequireFile;
            } else if (failedCount == totalCount) {
                finalStatus = 'Failure';
                failureReason = System.Label.FEC_BCH_Import_Rows_Invalid;
            } else {
                finalStatus = 'Processed';
            }

            out.success = true;
            out.message = System.Label.FEC_BCH_Import_Submitted;
            out.batchRecordId = (Id) batchRow.get('Id');
            out.contentDocumentId = insertedCv.ContentDocumentId;
            out.status = finalStatus;
            out.resultRowsJson = JSON.serialize(rowResults);
            return out;
        } catch (Exception ex) {
            if (batchRow != null && batchRow.get('Id') != null) {
                try {
                    FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Failure');
                    FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
                    FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, ex.getMessage());
                    update batchRow;
                } catch (Exception nestedEx) {
                    upsertFailedBatchHandling(fileName, templateName, ex.getMessage());
                }
            } else {
                upsertFailedBatchHandling(fileName, templateName, ex.getMessage());
            }
            out.message = System.Label.FEC_BCH_ImportFailed;
            return out;
        }
    }

    @AuraEnabled
    public static void saveResultFile(Id batchRecordId, String resultFileName, String fileBodyBase64) {
        if (batchRecordId == null || String.isBlank(resultFileName) || String.isBlank(fileBodyBase64)) {
            return;
        }
        ContentVersion cv = new ContentVersion();
        cv.Title = ensureResultContentTitle(resultFileName);
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
            Schema.SObjectType batchType = Schema.getGlobalDescribe().get(OBJECT_API_NAME);
            if (batchType == null) {
                return;
            }
            Map<String, Schema.SObjectField> fieldMap = batchType.getDescribe().fields.getMap();
            SObject failedRow = batchType.newSObject();
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_File_Name__c' }, fileName);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Status__c' }, 'Failure');
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Result__c' }, 'Result');
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Failure_Reason__c' }, reason);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'FEC_Template_Name__c', 'FEC_Template__c' }, templateName);
            insert failedRow;
        } catch (Exception ex) {
        }
    }

    private static String ensureResultContentTitle(String fileName) {
        String title = FEC_BatchCaseHandlingSObjectUtil.removeFileExtension(fileName);
        if (String.isBlank(title) || title.toLowerCase().endsWith('_result')) {
            return title;
        }
        return title + '_Result';
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
}
