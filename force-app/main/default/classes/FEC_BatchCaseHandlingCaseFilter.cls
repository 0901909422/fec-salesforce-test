public without sharing class FEC_BatchCaseHandlingCaseFilter {

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

    public static List<String> buildCompleteWhere(List<Map<String, Object>> filterMaps) {
        List<String> whereParts = buildBaseCaseWhere();
        whereParts.addAll(buildDynamicWhereFromFilters(filterMaps));
        return whereParts;
    }

    public static List<String> buildDynamicWhereFromFilters(List<Map<String, Object>> filterMaps) {
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
        String raw = String.valueOf(o).trim();
        if (raw.contains('__')) {
            return raw;
        }
        return raw.replace(' ', '_').toUpperCase();
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

    private static final String MY_PENDING_CASES_VALUE = 'My Pending Cases';
    private static final String QUEUE_MY_PENDING = 'MY_PENDING_CASES';

    private static String buildOneFilterClause(String prop, String op, String vText, List<String> vList) {
        if (prop == 'CUSTOMER_TYPE') {
            return buildInOrNotClause('FEC_Customer_Type__c', op, vList, vText, true);
        }
        if (prop == 'QUEUE') {
            return buildQueueClause(op, vList, vText);
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
            return buildTextClause('FEC_Product_Type__r.FEC_Code__c', op, vText);
        }
        if (prop == 'CATEGORY') {
            return buildTextClause('FEC_Category__r.FEC_Code__c', op, vText);
        }
        if (prop == 'SUB_CATEGORY') {
            return buildTextClause('FEC_SubCategory__r.FEC_Code__c', op, vText);
        }
        if (prop == 'SUB_CODE') {
            return buildTextClause('FEC_SubCode__r.FEC_Code__c', op, vText);
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
        return buildGenericCaseFieldClause(prop, op, vText);
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

        Boolean hasMyPending = false;
        List<String> queueNames = new List<String>();
        for (String v : vals) {
            if (String.isBlank(v)) {
                continue;
            }
            if (v.trim().equalsIgnoreCase(MY_PENDING_CASES_VALUE) || v.trim().equalsIgnoreCase(QUEUE_MY_PENDING)) {
                hasMyPending = true;
            } else {
                queueNames.add(v.trim());
            }
        }

        List<String> clauseParts = new List<String>();
        if (hasMyPending) {
            if (op == 'equals') {
                clauseParts.add('FEC_Is_Owner_Or_Assigned__c = true');
            } else if (op == 'not_equal_to') {
                clauseParts.add('FEC_Is_Owner_Or_Assigned__c = false');
            }
        }
        if (!queueNames.isEmpty()) {
            Set<Id> queueIds = resolveQueueIdsByName(queueNames);
            if (!queueIds.isEmpty()) {
                List<String> idLit = new List<String>();
                for (Id queueId : queueIds) {
                    idLit.add('\'' + String.escapeSingleQuotes(String.valueOf(queueId)) + '\'');
                }
                String inList = '(' + String.join(idLit, ',') + ')';
                if (op == 'equals') {
                    clauseParts.add('OwnerId IN ' + inList);
                } else if (op == 'not_equal_to') {
                    clauseParts.add('OwnerId NOT IN ' + inList);
                }
            }
        }
        if (clauseParts.isEmpty()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (clauseParts.size() == 1) {
            return clauseParts[0];
        }
        if (op == 'not_equal_to') {
            return '(' + String.join(clauseParts, ' AND ') + ')';
        }
        return '(' + String.join(clauseParts, ' OR ') + ')';
    }

    private static Set<Id> resolveQueueIdsByName(List<String> queueNames) {
        Set<Id> out = new Set<Id>();
        if (queueNames == null || queueNames.isEmpty()) {
            return out;
        }
        for (Group q : [
            SELECT Id, Name
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND Name IN :queueNames
        ]) {
            out.add(q.Id);
        }
        return out;
    }

    private static String buildGenericCaseFieldClause(String fieldApiName, String op, String vText) {
        if (String.isBlank(fieldApiName) || FEC_BCH_FilterPropertyService.isPredefinedPropertyKey(fieldApiName)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Map<String, Schema.SObjectField> fieldMap = Case.SObjectType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldApiName)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Schema.DescribeFieldResult dfr = fieldMap.get(fieldApiName).getDescribe();
        if (!dfr.isAccessible() || !dfr.isFilterable()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Schema.DisplayType displayType = dfr.getType();
        if (displayType == Schema.DisplayType.BOOLEAN) {
            Boolean wantTrue = interpretBoolean(vText);
            if (wantTrue == null) {
                return FEC_ConstantCommon.STR_EMPTY;
            }
            if (op == 'equals') {
                return fieldApiName + ' = ' + String.valueOf(wantTrue);
            }
            if (op == 'not_equal_to') {
                return fieldApiName + ' != ' + String.valueOf(wantTrue);
            }
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (displayType == Schema.DisplayType.DATE) {
            return buildDateClause(fieldApiName, op, vText);
        }
        if (displayType == Schema.DisplayType.DATETIME) {
            return buildDateTimeClause(fieldApiName, op, vText);
        }
        if (displayType == Schema.DisplayType.REFERENCE || displayType == Schema.DisplayType.ID) {
            return buildLookupClause(fieldApiName, op, vText);
        }
        if (isNumericDisplayType(displayType)) {
            return buildNumberClause(fieldApiName, op, vText);
        }
        return buildTextClause(fieldApiName, op, vText);
    }

    private static Boolean isNumericDisplayType(Schema.DisplayType displayType) {
        return displayType == Schema.DisplayType.CURRENCY
            || displayType == Schema.DisplayType.DOUBLE
            || displayType == Schema.DisplayType.INTEGER
            || displayType == Schema.DisplayType.LONG
            || displayType == Schema.DisplayType.PERCENT;
    }

    private static String buildDateTimeClause(String fieldApi, String op, String vText) {
        if (op == 'is_null') {
            return fieldApi + ' = null';
        }
        if (op == 'is_not_null') {
            return fieldApi + ' != null';
        }
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

    private static String buildNumberClause(String fieldApi, String op, String vText) {
        if (op == 'is_null') {
            return fieldApi + ' = null';
        }
        if (op == 'is_not_null') {
            return fieldApi + ' != null';
        }
        if (String.isBlank(vText)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Decimal numberValue;
        try {
            numberValue = Decimal.valueOf(vText.replace(',', FEC_ConstantCommon.STR_EMPTY));
        } catch (Exception ex) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String lit = String.valueOf(numberValue);
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
        if (op == 'is_null') {
            return fieldApi + ' = null';
        }
        if (op == 'is_not_null') {
            return fieldApi + ' != null';
        }
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