public class FEC_BatchCaseHandlingCaseFilter {

    private static final String CASE_FIELD_PREFIX = 'CASE_FIELD:';
    private static final String QUEUE_MY_PENDING = 'MY_PENDING_CASES';
    private static Map<String, Schema.DescribeFieldResult> caseFieldDescribeCache;

    private static final List<String> RESOLVED_SERVICE_CASE_STATUSES = new List<String>{
        FEC_ConstantCommon.CASE_STATUS_RESOLVED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED,
        FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANNOT_CONTACT_CUSTOMER
    };

    public static List<Map<String, Object>> parseFilterMaps(String filtersJson) {
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
        return filterMaps;
    }

    public static List<String> buildBaseCaseWhere() {
        return buildBaseCaseWhere(null);
    }

    public static List<String> buildBaseCaseWhere(List<Map<String, Object>> filterMaps) {
        List<String> parts = new List<String>();
        parts.add(
            'RecordType.DeveloperName = \'' +
            String.escapeSingleQuotes(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME) +
            '\''
        );
        if (!hasQueueFilter(filterMaps)) {
            parts.add('OwnerId = \'' + String.escapeSingleQuotes(String.valueOf(UserInfo.getUserId())) + '\'');
        }
        parts.add('IsClosed = false');
        parts.add(
            '(FEC_Case_Status__c = null OR FEC_Case_Status__c NOT IN (\'' +
            String.join(escapeStatusList(RESOLVED_SERVICE_CASE_STATUSES), '\',\'') +
            '\'))'
        );
        parts.add('(FEC_Final_Status__c = \'Open\' OR FEC_Final_Status__c LIKE \'Pending%\')');
        return parts;
    }

    private static Boolean hasQueueFilter(List<Map<String, Object>> filterMaps) {
        if (filterMaps == null || filterMaps.isEmpty()) {
            return false;
        }
        for (Map<String, Object> fm : filterMaps) {
            if ('QUEUE'.equals(normalizePropertyKey(fm.get('propertyKey')))) {
                return true;
            }
        }
        return false;
    }

    private static List<String> escapeStatusList(List<String> src) {
        List<String> out = new List<String>();
        for (String s : src) {
            out.add(String.escapeSingleQuotes(s));
        }
        return out;
    }

    private static final String ATTACHMENTS_PROPERTY = 'ATTACHMENTS';
    private static final Integer ID_IN_CHUNK_SIZE = 500;

    public static List<String> buildCompleteWhere(List<Map<String, Object>> filterMaps) {
        AttachmentFilterCriteria attachCrit = parseAttachmentFilter(filterMaps);
        List<String> parts = buildBaseCaseWhere(filterMaps);
        parts.addAll(buildDynamicWhereFromFilters(filterMapsWithoutAttachment(filterMaps)));
        if (attachCrit != null && attachCrit.active) {
            parts.addAll(buildAttachmentFilterParts(attachCrit, parts));
        }
        return parts;
    }

    private class AttachmentFilterCriteria {
        Boolean active = false;
        Boolean wantHas;
    }

    private static List<Map<String, Object>> filterMapsWithoutAttachment(List<Map<String, Object>> filterMaps) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        if (filterMaps == null) {
            return out;
        }
        for (Map<String, Object> fm : filterMaps) {
            if (!ATTACHMENTS_PROPERTY.equals(normalizePropertyKey(fm.get('propertyKey')))) {
                out.add(fm);
            }
        }
        return out;
    }

    private static AttachmentFilterCriteria parseAttachmentFilter(List<Map<String, Object>> filterMaps) {
        AttachmentFilterCriteria crit = new AttachmentFilterCriteria();
        if (filterMaps == null) {
            return crit;
        }
        for (Map<String, Object> fm : filterMaps) {
            if (!ATTACHMENTS_PROPERTY.equals(normalizePropertyKey(fm.get('propertyKey')))) {
                continue;
            }
            String op = normalizeOperatorKey(fm.get('operatorKey'));
            if (String.isBlank(op)) {
                continue;
            }
            String vText = fm.get('valueText') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(fm.get('valueText')).trim();
            Boolean wantHas = interpretBoolean(vText);
            if (wantHas == null) {
                continue;
            }
            crit.active = true;
            if (op == 'equals') {
                crit.wantHas = wantHas;
            } else if (op == 'not_equal_to') {
                crit.wantHas = !wantHas;
            } else {
                crit.active = false;
            }
            break;
        }
        return crit;
    }

    private static List<String> buildAttachmentFilterParts(AttachmentFilterCriteria crit, List<String> caseWhereParts) {
        if (crit == null || !crit.active || crit.wantHas == null || caseWhereParts == null || caseWhereParts.isEmpty()) {
            return new List<String>();
        }
        String caseWhere = String.join(caseWhereParts, ' AND ');
        Set<Id> caseIdsWithAttachments = queryCaseIdsWithAttachments(caseWhere);
        if (crit.wantHas) {
            if (caseIdsWithAttachments.isEmpty()) {
                return new List<String>{ 'Id = null' };
            }
            return new List<String>{ buildChunkedIdInClause(caseIdsWithAttachments) };
        }
        if (caseIdsWithAttachments.isEmpty()) {
            return new List<String>();
        }
        return new List<String>{ buildChunkedIdNotInClause(caseIdsWithAttachments) };
    }

    private static Set<Id> queryCaseIdsWithAttachments(String caseWhereClause) {
        Set<Id> out = new Set<Id>();
        if (String.isBlank(caseWhereClause)) {
            return out;
        }
        for (ContentDocumentLink cdl : Database.query(
            'SELECT LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN (SELECT Id FROM Case WHERE ' +
            caseWhereClause +
            ')'
        )) {
            if (cdl.LinkedEntityId != null) {
                out.add(cdl.LinkedEntityId);
            }
        }
        return out;
    }

    private static String buildChunkedIdInClause(Set<Id> ids) {
        List<Id> idList = new List<Id>(ids);
        List<String> chunks = new List<String>();
        for (Integer i = 0; i < idList.size(); i += ID_IN_CHUNK_SIZE) {
            chunks.add(buildIdInLiteralChunk(idList, i, Math.min(i + ID_IN_CHUNK_SIZE, idList.size())));
        }
        if (chunks.isEmpty()) {
            return 'Id = null';
        }
        if (chunks.size() == 1) {
            return chunks[0];
        }
        return '(' + String.join(chunks, ' OR ') + ')';
    }

    private static String buildChunkedIdNotInClause(Set<Id> ids) {
        List<Id> idList = new List<Id>(ids);
        List<String> chunks = new List<String>();
        for (Integer i = 0; i < idList.size(); i += ID_IN_CHUNK_SIZE) {
            chunks.add(buildIdNotInLiteralChunk(idList, i, Math.min(i + ID_IN_CHUNK_SIZE, idList.size())));
        }
        if (chunks.isEmpty()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (chunks.size() == 1) {
            return chunks[0];
        }
        return '(' + String.join(chunks, ' AND ') + ')';
    }

    private static String buildIdInLiteralChunk(List<Id> idList, Integer startIdx, Integer endIdx) {
        List<String> lit = new List<String>();
        for (Integer j = startIdx; j < endIdx; j++) {
            lit.add('\'' + String.escapeSingleQuotes(String.valueOf(idList[j])) + '\'');
        }
        return 'Id IN (' + String.join(lit, ',') + ')';
    }

    private static String buildIdNotInLiteralChunk(List<Id> idList, Integer startIdx, Integer endIdx) {
        List<String> lit = new List<String>();
        for (Integer j = startIdx; j < endIdx; j++) {
            lit.add('\'' + String.escapeSingleQuotes(String.valueOf(idList[j])) + '\'');
        }
        return 'Id NOT IN (' + String.join(lit, ',') + ')';
    }

    public static List<String> buildDynamicWhereFromFilters(List<Map<String, Object>> filterMaps) {
        List<String> parts = new List<String>();
        if (filterMaps == null || filterMaps.isEmpty()) {
            return parts;
        }
        for (Map<String, Object> fm : filterMaps) {
            String prop = normalizePropertyKey(fm.get('propertyKey'));
            if (ATTACHMENTS_PROPERTY.equals(prop)) {
                continue;
            }
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
            return buildMultiValueTextClause('FEC_Case_Created_By__c', op, vList, vText);
        }
        if (prop == 'CASE_CREATED_BY_ROLE') {
            return buildMultiValueTextClause('CreatedBy.FEC_User_Group__c', op, vList, vText);
        }
        if (prop == 'CASE_STATUS') {
            return buildMultiValueTextClause('FEC_Final_Status__c', op, vList, vText);
        }
        if (prop == 'QUEUE') {
            return buildQueueClause(op, vList, vText);
        }
        if (prop == 'PRODUCT_TYPE') {
            return buildLookupCodeClause('FEC_Product_Type__r.FEC_Code__c', op, vText);
        }
        if (prop == 'CATEGORY') {
            return buildLookupCodeClause('FEC_Category__r.FEC_Code__c', op, vText);
        }
        if (prop == 'SUB_CATEGORY') {
            return buildLookupCodeClause('FEC_SubCategory__r.FEC_Code__c', op, vText);
        }
        if (prop == 'SUB_CODE') {
            return buildLookupCodeClause('FEC_SubCode__r.FEC_Code__c', op, vText);
        }
        if (prop == 'CASE_CREATED_ON') {
            return buildDateClause('FEC_Case_Created_On__c', op, vText);
        }
        if (prop == ATTACHMENTS_PROPERTY) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (prop.startsWith(CASE_FIELD_PREFIX)) {
            String fieldApi = prop.substring(CASE_FIELD_PREFIX.length());
            return buildCaseFieldClause(fieldApi, op, vText, vList);
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static String buildQueueClause(String op, List<String> vList, String vText) {
        List<String> vals = new List<String>();
        if (vList != null && !vList.isEmpty()) {
            vals.addAll(vList);
        } else if (String.isNotBlank(vText)) {
            vals.add(vText);
        }
        if (vals.isEmpty()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Boolean includeMyPending = false;
        List<String> queueNames = new List<String>();
        for (String v : vals) {
            if (QUEUE_MY_PENDING.equalsIgnoreCase(v)) {
                includeMyPending = true;
            } else if (String.isNotBlank(v)) {
                queueNames.add(v);
            }
        }
        List<String> orParts = new List<String>();
        if (includeMyPending) {
            orParts.add('FEC_Is_Owner_Or_Assigned__c = true');
        }
        if (!queueNames.isEmpty()) {
            List<String> lit = new List<String>();
            for (String qn : queueNames) {
                lit.add('\'' + String.escapeSingleQuotes(qn) + '\'');
            }
            String inList = '(' + String.join(lit, ',') + ')';
            orParts.add(
                'OwnerId IN (SELECT Id FROM Group WHERE Type = \'' +
                String.escapeSingleQuotes(FEC_ConstantCommon.GROUP_TYPE_QUEUE) +
                '\' AND Name IN ' + inList + ')'
            );
        }
        if (orParts.isEmpty()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String combined = orParts.size() == 1 ? orParts[0] : '(' + String.join(orParts, ' OR ') + ')';
        if (op == 'equals') {
            return combined;
        }
        if (op == 'not_equal_to') {
            return '(NOT (' + combined + '))';
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static String buildLookupCodeClause(String fieldApi, String op, String vText) {
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

    private static Map<String, Schema.DescribeFieldResult> getCaseFieldDescribeMap() {
        if (caseFieldDescribeCache != null) {
            return caseFieldDescribeCache;
        }
        caseFieldDescribeCache = new Map<String, Schema.DescribeFieldResult>();
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Case.fields.getMap();
        for (String key : fieldMap.keySet()) {
            Schema.DescribeFieldResult dfr = fieldMap.get(key).getDescribe();
            if (dfr.isAccessible() && dfr.isFilterable()) {
                caseFieldDescribeCache.put(dfr.getName(), dfr);
            }
        }
        return caseFieldDescribeCache;
    }

    private static String buildCaseFieldClause(String fieldApi, String op, String vText, List<String> vList) {
        Map<String, Schema.DescribeFieldResult> fieldMap = getCaseFieldDescribeMap();
        if (!fieldMap.containsKey(fieldApi)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Schema.DescribeFieldResult dfr = fieldMap.get(fieldApi);
        Schema.DisplayType dt = dfr.getType();
        if (dt == Schema.DisplayType.PICKLIST) {
            return buildInOrNotClause(fieldApi, op, vList, vText, true);
        }
        if (dt == Schema.DisplayType.MULTIPICKLIST) {
            return buildMultiPicklistClause(fieldApi, op, vList, vText);
        }
        if (dt == Schema.DisplayType.BOOLEAN) {
            Boolean b = interpretBoolean(vText);
            if (b == null) {
                return FEC_ConstantCommon.STR_EMPTY;
            }
            if (op == 'equals') {
                return fieldApi + ' = ' + (b ? 'true' : 'false');
            }
            if (op == 'not_equal_to') {
                return fieldApi + ' != ' + (b ? 'true' : 'false');
            }
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (dt == Schema.DisplayType.DATE) {
            return buildDateClause(fieldApi, op, vText);
        }
        if (dt == Schema.DisplayType.DATETIME) {
            return buildDateTimeClause(fieldApi, op, vText);
        }
        if (
            dt == Schema.DisplayType.DOUBLE ||
            dt == Schema.DisplayType.CURRENCY ||
            dt == Schema.DisplayType.INTEGER ||
            dt == Schema.DisplayType.PERCENT
        ) {
            return buildNumberClause(fieldApi, op, vText);
        }
        return buildTextClause(fieldApi, op, vText);
    }

    private static String buildDateTimeClause(String fieldApi, String op, String vText) {
        if (String.isBlank(vText)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Datetime dtVal;
        try {
            dtVal = Datetime.valueOf(vText.replace('T', ' '));
        } catch (Exception e) {
            try {
                dtVal = Datetime.valueOf(vText);
            } catch (Exception e2) {
                return FEC_ConstantCommon.STR_EMPTY;
            }
        }
        String lit = dtVal.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        if (op == 'equals') {
            return fieldApi + ' = ' + lit;
        }
        if (op == 'not_equal_to') {
            return fieldApi + ' != ' + lit;
        }
        if (op == 'less_than') {
            return fieldApi + ' < ' + lit;
        }
        if (op == 'greater_than') {
            return fieldApi + ' > ' + lit;
        }
        if (op == 'less_or_equal') {
            return fieldApi + ' <= ' + lit;
        }
        if (op == 'greater_or_equal') {
            return fieldApi + ' >= ' + lit;
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static String buildMultiPicklistClause(String fieldApi, String op, List<String> vList, String vText) {
        List<String> vals = new List<String>();
        if (vList != null && !vList.isEmpty()) {
            vals.addAll(vList);
        } else if (String.isNotBlank(vText)) {
            vals.add(vText);
        }
        if (vals.isEmpty() && op != 'is_null' && op != 'is_not_null') {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (op == 'is_null') {
            return fieldApi + ' = null';
        }
        if (op == 'is_not_null') {
            return fieldApi + ' != null';
        }
        if (vals.isEmpty()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        List<String> parts = new List<String>();
        for (String v : vals) {
            String esc = String.escapeSingleQuotes(v);
            if (op == 'equals') {
                parts.add(fieldApi + ' INCLUDES (\'' + esc + '\')');
            } else if (op == 'not_equal_to') {
                parts.add('(NOT (' + fieldApi + ' INCLUDES (\'' + esc + '\')))');
            } else if (op == 'contains') {
                parts.add(fieldApi + ' INCLUDES (\'' + esc + '\')');
            } else if (op == 'does_not_contain') {
                parts.add('(NOT (' + fieldApi + ' INCLUDES (\'' + esc + '\')))');
            }
        }
        if (parts.isEmpty()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (parts.size() == 1) {
            return parts[0];
        }
        if (op == 'not_equal_to' || op == 'does_not_contain') {
            return '(' + String.join(parts, ' AND ') + ')';
        }
        return '(' + String.join(parts, ' OR ') + ')';
    }

    private static String buildNumberClause(String fieldApi, String op, String vText) {
        if (String.isBlank(vText) && op != 'is_null' && op != 'is_not_null') {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (op == 'is_null') {
            return fieldApi + ' = null';
        }
        if (op == 'is_not_null') {
            return fieldApi + ' != null';
        }
        Decimal numVal;
        try {
            numVal = Decimal.valueOf(vText);
        } catch (Exception e) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String lit = String.valueOf(numVal);
        if (op == 'equals') {
            return fieldApi + ' = ' + lit;
        }
        if (op == 'not_equal_to') {
            return fieldApi + ' != ' + lit;
        }
        if (op == 'less_than') {
            return fieldApi + ' < ' + lit;
        }
        if (op == 'greater_than') {
            return fieldApi + ' > ' + lit;
        }
        if (op == 'less_or_equal') {
            return fieldApi + ' <= ' + lit;
        }
        if (op == 'greater_or_equal') {
            return fieldApi + ' >= ' + lit;
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

    private static String buildMultiValueTextClause(String fieldApi, String op, List<String> vList, String vText) {
        if (op == 'equals' || op == 'not_equal_to') {
            return buildInOrNotClause(fieldApi, op, vList, vText, true);
        }
        List<String> vals = new List<String>();
        if (vList != null && !vList.isEmpty()) {
            vals.addAll(vList);
        } else if (String.isNotBlank(vText)) {
            vals.add(vText);
        }
        if (vals.isEmpty()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        List<String> parts = new List<String>();
        for (String v : vals) {
            String clause = buildTextClause(fieldApi, op, v);
            if (String.isNotBlank(clause)) {
                parts.add(clause);
            }
        }
        if (parts.isEmpty()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (parts.size() == 1) {
            return parts[0];
        }
        if (op == 'does_not_contain') {
            return '(' + String.join(parts, ' AND ') + ')';
        }
        return '(' + String.join(parts, ' OR ') + ')';
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
}