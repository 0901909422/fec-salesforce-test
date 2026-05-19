public without sharing class FEC_BatchCaseHandlingController {
    private static final String OBJECT_API_NAME = 'FEC_Batch_Case_Handling__c';
    private static final Integer MAX_ROWS = 200;
    private static final Integer MAX_ATTACHMENT_CASE_SET = 1000;
    private static final Integer MAX_EXPORT_ROWS = 100000;
    private static final Integer EXPORT_CURSOR_PAGE_SIZE = 1000;
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

    @AuraEnabled
    public static List<FilterPropertyMeta> getCaseFilterPropertyMetadata() {
        List<FilterPropertyMeta> out = new List<FilterPropertyMeta>();
        appendPredefinedFilterMeta(out);
        appendCaseFieldFilterMeta(out);
        return out;
    }

    private static void appendPredefinedFilterMeta(List<FilterPropertyMeta> out) {
        out.add(buildPredefinedMeta('CUSTOMER_TYPE', 'Customer Type', 'FEC_Customer_Type__c', 'picklist', new List<String>{ 'equals', 'not_equal_to' }, true, loadCustomerTypeOptions()));
        out.add(buildPredefinedMeta('QUEUE', 'Queue', null, 'picklist', new List<String>{ 'equals', 'not_equal_to' }, true, loadQueueOptions()));
        out.add(buildPredefinedMeta('PRODUCT_TYPE', 'Product Type', 'FEC_Product_Type__c', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' }, false, loadMasterDataCodeOptions('FEC_Product_Type__c')));
        out.add(buildPredefinedMeta('CATEGORY', 'Category', 'FEC_Category__c', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' }, false, loadMasterDataCodeOptions('FEC_Category__c')));
        out.add(buildPredefinedMeta('SUB_CATEGORY', 'Sub Category', 'FEC_SubCategory__c', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' }, false, loadMasterDataCodeOptions('FEC_Sub_Category__c')));
        out.add(buildPredefinedMeta('SUB_CODE', 'Sub Code', 'FEC_SubCode__c', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' }, false, loadMasterDataCodeOptions('FEC_Sub_Code__c')));
        out.add(buildPredefinedMeta('CASE_ID', 'Case ID', 'FEC_ID_Search__c', 'text', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with' }, false, null));
        out.add(buildPredefinedMeta('CASE_CREATED_ON', 'Case Created On', 'FEC_Case_Created_On__c', 'date', new List<String>{ 'equals', 'not_equal_to', 'less_than', 'greater_than', 'less_or_equal', 'greater_or_equal' }, false, null));
        out.add(buildPredefinedMeta('CASE_CREATED_BY', 'Case Created By', 'FEC_Case_Created_By__c', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with' }, true, loadCaseCreatedByOptions()));
        out.add(buildPredefinedMeta('CASE_CREATED_BY_ROLE', 'Case Created By Role', 'CreatedBy.FEC_User_Group__c', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with' }, true, loadUserGroupOptions()));
        out.add(buildPredefinedMeta('CASE_STATUS', 'Case Status', 'FEC_Final_Status__c', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with' }, true, loadCaseStatusOptions()));
        out.add(buildPredefinedMeta('ATTACHMENTS', 'Attachments', null, 'checkbox', new List<String>{ 'equals', 'not_equal_to' }, false, null));
    }

    private static FilterPropertyMeta buildPredefinedMeta(
        String key,
        String label,
        String fieldApiName,
        String valueType,
        List<String> ops,
        Boolean multiValue,
        List<FilterPicklistOption> picklistOptions
    ) {
        FilterPropertyMeta m = new FilterPropertyMeta();
        m.propertyKey = key;
        m.label = label;
        m.valueType = valueType;
        m.operators = ops;
        m.propertyGroup = 'PREDEFINED';
        m.fieldApiName = String.isBlank(fieldApiName) ? FEC_ConstantCommon.STR_EMPTY : fieldApiName;
        m.multiValue = multiValue == true;
        m.picklistOptions = picklistOptions == null ? new List<FilterPicklistOption>() : picklistOptions;
        return m;
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

    private static List<FilterPicklistOption> loadCustomerTypeOptions() {
        return toFilterPicklistOptions(
            FEC_CommonUltils.getPicklistOptionsWithAccess('Case', 'FEC_Customer_Type__c')
        );
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
        myPending.label = 'My Pending Cases';
        myPending.value = 'MY_PENDING_CASES';
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

    private static final Set<String> PREDEFINED_CASE_FIELD_APIS = new Set<String>{
        'FEC_Customer_Type__c',
        'FEC_ID_Search__c',
        'FEC_Case_Created_By__c',
        'FEC_Final_Status__c',
        'FEC_Product_Type__c',
        'FEC_Category__c',
        'FEC_SubCategory__c',
        'FEC_SubCode__c',
        'FEC_Case_Created_On__c',
        'FEC_Last_Updated_On__c',
        'FEC_Is_Owner_Or_Assigned__c',
        'OwnerId',
        'RecordTypeId',
        'IsClosed',
        'Status',
        'CaseNumber',
        'CreatedById'
    };

    private static void appendCaseFieldFilterMeta(List<FilterPropertyMeta> out) {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Case.fields.getMap();
        List<String> fieldNames = new List<String>(fieldMap.keySet());
        fieldNames.sort();
        for (String key : fieldNames) {
            Schema.DescribeFieldResult dfr = fieldMap.get(key).getDescribe();
            String api = dfr.getName();
            if (!dfr.isAccessible() || !dfr.isFilterable() || PREDEFINED_CASE_FIELD_APIS.contains(api)) {
                continue;
            }
            Schema.DisplayType dt = dfr.getType();
            String valueType = mapDisplayTypeToValueType(dt);
            if (String.isBlank(valueType)) {
                continue;
            }
            FilterPropertyMeta m = new FilterPropertyMeta();
            m.propertyKey = 'CASE_FIELD:' + api;
            m.label = dfr.getLabel();
            m.valueType = valueType;
            m.operators = operatorsForValueType(valueType, dt);
            m.propertyGroup = 'CASE_FIELD';
            m.fieldApiName = api;
            m.multiValue = dt == Schema.DisplayType.MULTIPICKLIST;
            m.picklistOptions = new List<FilterPicklistOption>();
            if (valueType == 'picklist' || valueType == 'multipicklist') {
                m.picklistOptions = toFilterPicklistOptions(
                    FEC_CommonUltils.getPicklistOptionsWithAccess('Case', api)
                );
            }
            out.add(m);
        }
    }

    private static String mapDisplayTypeToValueType(Schema.DisplayType dt) {
        if (dt == Schema.DisplayType.PICKLIST) {
            return 'picklist';
        }
        if (dt == Schema.DisplayType.MULTIPICKLIST) {
            return 'multipicklist';
        }
        if (dt == Schema.DisplayType.BOOLEAN) {
            return 'checkbox';
        }
        if (dt == Schema.DisplayType.DATE) {
            return 'date';
        }
        if (dt == Schema.DisplayType.DATETIME) {
            return 'datetime';
        }
        if (
            dt == Schema.DisplayType.DOUBLE ||
            dt == Schema.DisplayType.CURRENCY ||
            dt == Schema.DisplayType.INTEGER ||
            dt == Schema.DisplayType.PERCENT
        ) {
            return 'number';
        }
        if (
            dt == Schema.DisplayType.STRING ||
            dt == Schema.DisplayType.TEXTAREA ||
            dt == Schema.DisplayType.EMAIL ||
            dt == Schema.DisplayType.PHONE ||
            dt == Schema.DisplayType.URL
        ) {
            return 'text';
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static List<String> operatorsForValueType(String valueType, Schema.DisplayType dt) {
        if (valueType == 'multipicklist') {
            return new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain' };
        }
        if (valueType == 'picklist' || valueType == 'checkbox') {
            return new List<String>{ 'equals', 'not_equal_to' };
        }
        if (valueType == 'date' || valueType == 'datetime' || valueType == 'number') {
            return new List<String>{ 'equals', 'not_equal_to', 'less_than', 'greater_than', 'less_or_equal', 'greater_or_equal' };
        }
        return new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' };
    }

    @AuraEnabled(cacheable=true)
    public static List<BatchRow> getRecentRows() {
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(OBJECT_API_NAME).getDescribe().fields.getMap();
        String fileField = FEC_BatchCaseHandlingSObjectUtil.pickField(fieldMap, new List<String>{ 'FEC_File_Name__c', 'Name' });
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
                        resultUrlByBatchId.put(link.LinkedEntityId, FEC_ConstantCommon.CONTENT_VERSION_DOWNLOAD_URL_PREFIX + versionId);
                    }
                } else if (!sourceUrlByBatchId.containsKey(link.LinkedEntityId)) {
                    sourceUrlByBatchId.put(link.LinkedEntityId, FEC_ConstantCommon.CONTENT_VERSION_DOWNLOAD_URL_PREFIX + versionId);
                }
            }
        }

        for (SObject row : rows) {
            BatchRow dto = new BatchRow();
            dto.id = (Id) row.get('Id');
            dto.fileName = FEC_BatchCaseHandlingSObjectUtil.asString(row.get(fileField));
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
            r.businessProcessCode = c.FEC_Business_Process__r == null ? null : c.FEC_Business_Process__r.FEC_Code__c;
            r.businessProcessName = c.FEC_Business_Process__r == null ? null : c.FEC_Business_Process__r.Name;
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

    @AuraEnabled
    public static List<BusinessProcessExportRow> getBusinessProcessExportRows(String filtersJson) {
        List<BusinessProcessExportRow> out = new List<BusinessProcessExportRow>();
        List<Map<String, Object>> filterMaps = FEC_BatchCaseHandlingCaseFilter.parseFilterMaps(filtersJson);
        List<String> whereParts = FEC_BatchCaseHandlingCaseFilter.buildCompleteWhere(filterMaps);
        List<String> allowedBpNames = FEC_BatchCaseHandlingTemplateHelper.ALLOWED_BUSINESS_PROCESS_NAMES;
        whereParts.add('FEC_Business_Process__r.Name IN :allowedBpNames');
        String whereClause = String.join(whereParts, ' AND ');
        List<AggregateResult> grouped = Database.query(
            'SELECT FEC_Business_Process__r.Name bpName, COUNT(Id) cnt ' +
            'FROM Case WHERE ' + whereClause +
            ' GROUP BY FEC_Business_Process__r.Name'
        );

        List<SObject> templateRows = FEC_BatchCaseHandlingTemplateHelper.queryActiveBatchCaseHandlingTemplates();
        Map<Id, String> urlByTemplateId = new Map<Id, String>();
        Map<Id, Id> versionIdByTemplateId = new Map<Id, Id>();
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
                    Id versionId = link.ContentDocument.LatestPublishedVersionId;
                    urlByTemplateId.put(link.LinkedEntityId, FEC_ConstantCommon.CONTENT_VERSION_DOWNLOAD_URL_PREFIX + String.valueOf(versionId));
                    versionIdByTemplateId.put(link.LinkedEntityId, versionId);
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
            SObject matched = FEC_BatchCaseHandlingTemplateHelper.resolveTemplateByBusinessProcessAndUserGroup(bpName, userGroup, templateRows);
            if (matched != null) {
                Id matchedTemplateId = (Id) matched.get('Id');
                item.templateName = String.valueOf(matched.get('Name'));
                item.templateDownloadUrl = urlByTemplateId.get(matchedTemplateId);
                item.templateContentVersionId = versionIdByTemplateId.get(matchedTemplateId);
            } else {
                item.templateName = FEC_ConstantCommon.STR_EMPTY;
                item.templateDownloadUrl = FEC_ConstantCommon.STR_EMPTY;
                item.templateContentVersionId = null;
            }
            if (item.templateDownloadUrl == null) {
                item.templateDownloadUrl = FEC_ConstantCommon.STR_EMPTY;
            }
            out.add(item);
        }
        return out;
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

            batchRow = Schema.getGlobalDescribe().get(OBJECT_API_NAME).newSObject();
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'Name', 'FEC_File_Name__c' }, fileName);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Uploaded_On__c' }, Datetime.now());
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Uploaded_By__c' }, UserInfo.getUserEmail());
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Uploaded');
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, FEC_ConstantCommon.STR_EMPTY);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Template_Name__c', 'FEC_Template__c' }, templateName);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_File_Content_Document_Id__c' }, String.valueOf(insertedCv.ContentDocumentId));
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, 0);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, 0);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, FEC_ConstantCommon.STR_EMPTY);
            insert batchRow;
            linkFileToBatchHandling((Id) batchRow.get('Id'), insertedCv.ContentDocumentId);

            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processing');
            update batchRow;

            Boolean cofOrGsr = FEC_BatchCaseHandlingImportService.isCofOrGsrTemplate(templateName);
            List<FEC_BatchCaseHandlingImportRow> rowResults = FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, cofOrGsr);
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(rowResults, cofOrGsr);
            Integer failedCount = FEC_BatchCaseHandlingImportService.countFailedImportRows(rowResults);
            Integer totalCount = rowResults.size();
            Integer successCount = totalCount - failedCount;
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Records_Count__c', 'FEC_Total_Records__c' }, totalCount);

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
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, finalStatus);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Result__c' }, 'Result');
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Success_Records__c' }, successCount < 0 ? 0 : successCount);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Failed_Records__c' }, failedCount);
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Failure_Reason__c' }, failureReason);
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
        cv.Title = FEC_BatchCaseHandlingSObjectUtil.removeFileExtension(resultFileName);
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
            FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, failedRow, new List<String>{ 'Name', 'FEC_File_Name__c' }, fileName);
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