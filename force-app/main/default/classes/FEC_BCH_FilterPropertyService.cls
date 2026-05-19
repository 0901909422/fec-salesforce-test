public class FEC_BCH_FilterPropertyService {

    public static final String SCOPE_PRE_DEFINE = 'PRE_DEFINE';
    public static final String SCOPE_ALL_CASE = 'ALL_CASE';

    private static final Set<String> PREDEFINED_PROPERTY_KEYS = new Set<String>{
        'CUSTOMER_TYPE',
        'QUEUE',
        'PRODUCT_TYPE',
        'CATEGORY',
        'SUB_CATEGORY',
        'SUB_CODE',
        'CASE_ID',
        'CASE_CREATED_ON',
        'CASE_CREATED_BY',
        'CASE_CREATED_BY_ROLE',
        'CASE_STATUS',
        'ATTACHMENTS'
    };

    public static List<FEC_BatchCaseHandlingController.FilterPropertyMeta> getMetadata(String filterScope) {
        String scope = normalizeScope(filterScope);
        if (scope == SCOPE_ALL_CASE) {
            return buildAllCaseMetadata();
        }
        return buildPreDefineMetadata();
    }

    public static Boolean isPredefinedPropertyKey(String propertyKey) {
        if (String.isBlank(propertyKey)) {
            return false;
        }
        String raw = propertyKey.trim();
        if (raw.contains('__')) {
            return false;
        }
        return PREDEFINED_PROPERTY_KEYS.contains(raw.replace(' ', '_').toUpperCase());
    }

    public static String normalizeScope(String filterScope) {
        if (String.isBlank(filterScope)) {
            return SCOPE_PRE_DEFINE;
        }
        String scope = filterScope.trim().toUpperCase();
        if (scope == SCOPE_ALL_CASE) {
            return SCOPE_ALL_CASE;
        }
        return SCOPE_PRE_DEFINE;
    }

    private static String normalizePropertyKey(String propertyKey) {
        if (String.isBlank(propertyKey)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return propertyKey.trim().replace(' ', '_').toUpperCase();
    }

    private static List<FEC_BatchCaseHandlingController.FilterPropertyMeta> buildPreDefineMetadata() {
        List<FEC_BatchCaseHandlingController.FilterPropertyMeta> out = new List<FEC_BatchCaseHandlingController.FilterPropertyMeta>();
        out.add(buildMeta('CUSTOMER_TYPE', 'Customer Type', 'picklist', new List<String>{ 'equals', 'not_equal_to' }));
        out.add(buildMeta('QUEUE', 'Queue', 'picklist', new List<String>{ 'equals', 'not_equal_to' }));
        out.add(buildMeta('PRODUCT_TYPE', 'Product Type', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' }));
        out.add(buildMeta('CATEGORY', 'Category', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' }));
        out.add(buildMeta('SUB_CATEGORY', 'Sub Category', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' }));
        out.add(buildMeta('SUB_CODE', 'Sub Code', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' }));
        out.add(buildMeta('CASE_ID', 'Case ID', 'text', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with' }));
        out.add(buildMeta('CASE_CREATED_ON', 'Case Created On', 'date', new List<String>{ 'equals', 'not_equal_to', 'less_than', 'greater_than', 'less_or_equal', 'greater_or_equal' }));
        out.add(buildMeta('CASE_CREATED_BY', 'Case Created By', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with' }));
        out.add(buildMeta('CASE_CREATED_BY_ROLE', 'Case Created By Role', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with' }));
        out.add(buildMeta('CASE_STATUS', 'Case Status', 'picklist', new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with' }));
        out.add(buildMeta('ATTACHMENTS', 'Attachments', 'checkbox', new List<String>{ 'equals', 'not_equal_to' }));
        return out;
    }

    private static List<FEC_BatchCaseHandlingController.FilterPropertyMeta> buildAllCaseMetadata() {
        List<FEC_BatchCaseHandlingController.FilterPropertyMeta> out = buildPreDefineMetadata();
        Set<String> seenPropertyKeys = new Set<String>();
        for (FEC_BatchCaseHandlingController.FilterPropertyMeta m : out) {
            if (m != null && String.isNotBlank(m.propertyKey)) {
                seenPropertyKeys.add(m.propertyKey.trim());
            }
        }
        Map<String, Schema.SObjectField> fieldMap = Case.SObjectType.getDescribe().fields.getMap();
        List<String> fieldNames = new List<String>(fieldMap.keySet());
        fieldNames.sort();
        for (String fieldName : fieldNames) {
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
            if (!dfr.isAccessible() || !dfr.isFilterable()) {
                continue;
            }
            if (!isSupportedDisplayType(dfr.getType())) {
                continue;
            }
            String label = String.isBlank(dfr.getLabel()) ? fieldName : dfr.getLabel();
            if (seenPropertyKeys.contains(fieldName)) {
                continue;
            }
            out.add(buildMeta(fieldName, label, mapDisplayType(dfr.getType()), operatorsForDisplayType(dfr.getType())));
            seenPropertyKeys.add(fieldName);
        }
        return out;
    }

    private static Boolean isSupportedDisplayType(Schema.DisplayType displayType) {
        return displayType == Schema.DisplayType.BOOLEAN
            || displayType == Schema.DisplayType.COMBOBOX
            || displayType == Schema.DisplayType.CURRENCY
            || displayType == Schema.DisplayType.DATE
            || displayType == Schema.DisplayType.DATETIME
            || displayType == Schema.DisplayType.DOUBLE
            || displayType == Schema.DisplayType.EMAIL
            || displayType == Schema.DisplayType.INTEGER
            || displayType == Schema.DisplayType.LONG
            || displayType == Schema.DisplayType.MULTIPICKLIST
            || displayType == Schema.DisplayType.PERCENT
            || displayType == Schema.DisplayType.PHONE
            || displayType == Schema.DisplayType.PICKLIST
            || displayType == Schema.DisplayType.REFERENCE
            || displayType == Schema.DisplayType.STRING
            || displayType == Schema.DisplayType.TEXTAREA
            || displayType == Schema.DisplayType.URL
            || displayType == Schema.DisplayType.ID;
    }

    private static String mapDisplayType(Schema.DisplayType displayType) {
        if (displayType == Schema.DisplayType.BOOLEAN) {
            return 'checkbox';
        }
        if (displayType == Schema.DisplayType.DATE || displayType == Schema.DisplayType.DATETIME) {
            return 'date';
        }
        if (displayType == Schema.DisplayType.PICKLIST || displayType == Schema.DisplayType.MULTIPICKLIST || displayType == Schema.DisplayType.COMBOBOX) {
            return 'picklist';
        }
        return 'text';
    }

    private static List<String> operatorsForDisplayType(Schema.DisplayType displayType) {
        if (displayType == Schema.DisplayType.BOOLEAN) {
            return new List<String>{ 'equals', 'not_equal_to' };
        }
        if (displayType == Schema.DisplayType.DATE || displayType == Schema.DisplayType.DATETIME) {
            return new List<String>{ 'equals', 'not_equal_to', 'less_than', 'greater_than', 'less_or_equal', 'greater_or_equal', 'is_null', 'is_not_null' };
        }
        if (displayType == Schema.DisplayType.REFERENCE || displayType == Schema.DisplayType.ID) {
            return new List<String>{ 'equals', 'not_equal_to', 'is_null', 'is_not_null' };
        }
        if (displayType == Schema.DisplayType.PICKLIST || displayType == Schema.DisplayType.MULTIPICKLIST || displayType == Schema.DisplayType.COMBOBOX) {
            return new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' };
        }
        if (isNumericDisplayType(displayType)) {
            return new List<String>{ 'equals', 'not_equal_to', 'less_than', 'greater_than', 'less_or_equal', 'greater_or_equal', 'is_null', 'is_not_null' };
        }
        return new List<String>{ 'equals', 'not_equal_to', 'contains', 'does_not_contain', 'starts_with', 'does_not_start_with', 'is_null', 'is_not_null' };
    }

    private static Boolean isNumericDisplayType(Schema.DisplayType displayType) {
        return displayType == Schema.DisplayType.CURRENCY
            || displayType == Schema.DisplayType.DOUBLE
            || displayType == Schema.DisplayType.INTEGER
            || displayType == Schema.DisplayType.LONG
            || displayType == Schema.DisplayType.PERCENT;
    }

    private static FEC_BatchCaseHandlingController.FilterPropertyMeta buildMeta(String key, String label, String valueType, List<String> ops) {
        FEC_BatchCaseHandlingController.FilterPropertyMeta m = new FEC_BatchCaseHandlingController.FilterPropertyMeta();
        m.propertyKey = key;
        m.label = label;
        m.valueType = valueType;
        m.operators = ops;
        return m;
    }
}
