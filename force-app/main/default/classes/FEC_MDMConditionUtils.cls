/**
 * @description Pure utility class for MDM condition evaluation:
 *              field type resolution, value comparison, expression application.
 *              Extracted from FEC_MDM_WorkflowEngine in Phase 2.2 refactor.
 *              Shared by Phase 2.2 (FEC_RuleEngineService, FEC_RuleTestService) and
 *              Phase 2.3 (FEC_StageTransitionValidator) — single source of truth
 *              for condition evaluation logic.
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.2
 */
public with sharing class FEC_MDMConditionUtils {

    // ════════════════════════════════════════════════════════
    // STATIC CACHE — Issue #6: avoid repeated getGlobalDescribe() calls
    // ════════════════════════════════════════════════════════
    @TestVisible private static Map<String, Schema.SObjectType> globalDescribeCache;
    @TestVisible private static Map<String, Map<String, Schema.SObjectField>> objectFieldsCache = new Map<String, Map<String, Schema.SObjectField>>();

    // ════════════════════════════════════════════════════════
    // FIELD(...) DYNAMIC VALUE — so sánh field-to-field
    // Cú pháp trong cột Value: FIELD(Label_Field_Khác)
    // Vd: condition Label="Original Info - Email", Value="FIELD(Updated Info - Email)"
    //     → engine so Case.Original_Email == Case.Updated_Email
    // ════════════════════════════════════════════════════════
    private static final Pattern FIELD_REF_PATTERN = Pattern.compile('(?i)^\\s*FIELD\\s*\\(\\s*(.+?)\\s*\\)\\s*$');

    /** True nếu conditionValue có dạng FIELD(...). */
    public static Boolean isFieldReference(String conditionValue) {
        if (String.isBlank(conditionValue)) return false;
        return FIELD_REF_PATTERN.matcher(conditionValue).matches();
    }

    /** Trích label field bên trong FIELD(...). Null nếu không phải field ref. */
    public static String extractFieldRefLabel(String conditionValue) {
        if (String.isBlank(conditionValue)) return null;
        Matcher m = FIELD_REF_PATTERN.matcher(conditionValue);
        return m.matches() ? m.group(1).trim() : null;
    }

    /**
     * Resolve conditionValue: nếu là FIELD(x) → trả giá trị field x từ caseData;
     * ngược lại trả nguyên conditionValue (literal).
     */
    public static String resolveConditionValue(String conditionValue, Map<String, Object> caseData) {
        String refLabel = extractFieldRefLabel(conditionValue);
        if (refLabel == null) return conditionValue;
        if (caseData == null) return '';
        Object val = caseData.get(refLabel.toLowerCase());
        return val != null ? String.valueOf(val) : '';
    }

    public static Map<String, Schema.SObjectType> getGlobalDescribeCached() {
        if (globalDescribeCache == null) {
            globalDescribeCache = Schema.getGlobalDescribe();
        }
        return globalDescribeCache;
    }

    /**
     * Resolve field data type from Salesforce schema.
     * Returns simplified type string: Text, Number, Boolean, Picklist, Date, DateTime, Time, Reference.
     */
    public static String resolveFieldDataType(String objectName, String fieldApiName) {
        if (String.isBlank(objectName) || String.isBlank(fieldApiName)) return 'Text';
        try {
            Schema.SObjectType objType = getGlobalDescribeCached().get(objectName);
            if (objType == null) return 'Text';
            Schema.SObjectField field = getCachedField(objType, objectName, fieldApiName);
            if (field == null) return 'Text';
            return mapDisplayTypeToString(field.getDescribe().getType());
        } catch (Exception e) {
            return 'Text';
        }
    }

    private static Schema.SObjectField getCachedField(Schema.SObjectType objType, String objectName, String fieldApiName) {
        Map<String, Schema.SObjectField> fieldMap = objectFieldsCache.get(objectName);
        if (fieldMap == null) {
            fieldMap = objType.getDescribe().fields.getMap();
            objectFieldsCache.put(objectName, fieldMap);
        }
        return fieldMap.get(fieldApiName.toLowerCase());
    }

    private static String mapDisplayTypeToString(Schema.DisplayType dt) {
        switch on dt {
            when STRING, TEXTAREA, URL, EMAIL, PHONE, ID, ENCRYPTEDSTRING { return 'Text'; }
            when INTEGER, DOUBLE, CURRENCY, PERCENT, LONG { return 'Number'; }
            when BOOLEAN { return 'Boolean'; }
            when PICKLIST, MULTIPICKLIST { return 'Picklist'; }
            when DATE { return 'Date'; }
            when DATETIME { return 'DateTime'; }
            when TIME { return 'Time'; }
            when REFERENCE { return 'Reference'; }
            when else { return 'Text'; }
        }
    }

    // ════════════════════════════════════════════════════════
    // CONDITION EVALUATION
    // ════════════════════════════════════════════════════════

    /**
     * Evaluate single condition: apply expression first, then compare value.
     */
    public static Boolean evaluateCondition(String actualValue, String operator, String conditionValue, String expression) {
        String processedValue = actualValue != null ? actualValue : '';
        if (String.isNotBlank(expression) && expression != 'RANGE_START' && expression != 'RANGE_END') {
            processedValue = applyExpression(expression, processedValue);
        }

        if (String.isBlank(operator)) {
            return processedValue == conditionValue;
        }

        return compareByOperator(processedValue, operator, conditionValue);
    }

    private static Boolean compareByOperator(String processedValue, String operator, String conditionValue) {
        switch on operator {
            when '='        { return processedValue == conditionValue; }
            when '!='       { return processedValue != conditionValue; }
            when '>'        { return compareNumeric(processedValue, conditionValue) > 0; }
            when '<'        { return compareNumeric(processedValue, conditionValue) < 0; }
            when '>='       { return compareNumeric(processedValue, conditionValue) >= 0; }
            when '<='       { return compareNumeric(processedValue, conditionValue) <= 0; }
            when 'IN'       { return isInList(processedValue, conditionValue); }
            when 'NOT IN'   { return !isInList(processedValue, conditionValue); }
            when 'Contains' {
                return processedValue != null && conditionValue != null && processedValue.containsIgnoreCase(conditionValue);
            }
            when 'Starts With' {
                return processedValue != null && conditionValue != null && processedValue.startsWithIgnoreCase(conditionValue);
            }
            when 'Ends With' {
                return processedValue != null && conditionValue != null && processedValue.endsWithIgnoreCase(conditionValue);
            }
            when 'BETWEEN' { return evaluateBetween(processedValue, conditionValue); }
            when else      { return processedValue == conditionValue; }
        }
    }

    /**
     * Apply expression function: TRIM, UPPER, LOWER, LENGTH, LEFT(field,n), RIGHT(field,n).
     */
    public static String applyExpression(String expression, String value) {
        if (value == null) value = '';
        if (String.isBlank(expression)) return value;

        String expr = expression.toUpperCase().trim();

        if (expr.startsWith('TRIM'))   return value.trim();
        if (expr.startsWith('UPPER'))  return value.toUpperCase();
        if (expr.startsWith('LOWER'))  return value.toLowerCase();
        if (expr.startsWith('LENGTH')) return String.valueOf(value.length());
        if (expr.startsWith('LEFT')) {
            Integer n = extractNumber(expression);
            return (n != null && value.length() >= n) ? value.left(n) : value;
        }
        if (expr.startsWith('RIGHT')) {
            Integer n = extractNumber(expression);
            return (n != null && value.length() >= n) ? value.right(n) : value;
        }
        return value;
    }

    /**
     * Extract numeric parameter from FUNC(..., N) — returns last number before closing paren.
     */
    public static Integer extractNumber(String expression) {
        if (String.isBlank(expression)) return null;
        Pattern p = Pattern.compile('\\,\\s*(\\d+)\\s*\\)');
        Matcher m = p.matcher(expression);
        if (m.find()) {
            try {
                return Integer.valueOf(m.group(1));
            } catch (Exception e) {
                return null;
            }
        }
        return null;
    }

    /**
     * Compare two values as Decimals. Returns negative/zero/positive.
     * Falls back to String comparison if not numeric.
     */
    public static Integer compareNumeric(String val1, String val2) {
        try {
            Decimal d1 = Decimal.valueOf(val1.trim());
            Decimal d2 = Decimal.valueOf(val2.trim());
            if (d1 > d2) return 1;
            if (d1 < d2) return -1;
            return 0;
        } catch (Exception e) {
            String s1 = val1 != null ? val1 : '';
            String s2 = val2 != null ? val2 : '';
            if (s1 > s2) return 1;
            if (s1 < s2) return -1;
            return 0;
        }
    }

    /**
     * Check if value is in comma-separated list (case-insensitive).
     */
    public static Boolean isInList(String value, String commaSeparatedList) {
        if (String.isBlank(commaSeparatedList)) return false;
        String lowerValue = (value != null ? value.trim().toLowerCase() : '');
        for (String item : commaSeparatedList.split(',')) {
            if (item.trim().toLowerCase() == lowerValue) {
                return true;
            }
        }
        return false;
    }

    /**
     * Evaluate BETWEEN: value format ">=5,<=10" or ">5,<10".
     * Each part has operator prefix (>=, >, <=, <) + numeric value.
     */
    public static Boolean evaluateBetween(String actualValue, String rangeValue) {
        if (String.isBlank(rangeValue) || String.isBlank(actualValue)) return false;
        try {
            List<String> parts = rangeValue.split(',');
            if (parts.size() != 2) return false;

            BoundaryParseResult startRange = parseBoundary(parts[0].trim(), true);
            BoundaryParseResult endRange = parseBoundary(parts[1].trim(), false);
            Decimal actual = Decimal.valueOf(actualValue.trim());

            Boolean startOk = (startRange.op == '>=') ? actual >= startRange.val : actual > startRange.val;
            Boolean endOk = (endRange.op == '<=') ? actual <= endRange.val : actual < endRange.val;

            return startOk && endOk;
        } catch (Exception e) {
            return false;
        }
    }

    private static BoundaryParseResult parseBoundary(String boundary, Boolean isStart) {
        BoundaryParseResult result = new BoundaryParseResult();
        if (isStart) {
            if (boundary.startsWith('>=')) {
                result.op = '>=';
                result.val = Decimal.valueOf(boundary.substring(2).trim());
            } else if (boundary.startsWith('>')) {
                result.op = '>';
                result.val = Decimal.valueOf(boundary.substring(1).trim());
            } else {
                result.op = '>=';
                result.val = Decimal.valueOf(boundary);
            }
        } else {
            if (boundary.startsWith('<=')) {
                result.op = '<=';
                result.val = Decimal.valueOf(boundary.substring(2).trim());
            } else if (boundary.startsWith('<')) {
                result.op = '<';
                result.val = Decimal.valueOf(boundary.substring(1).trim());
            } else {
                result.op = '<=';
                result.val = Decimal.valueOf(boundary);
            }
        }
        return result;
    }

    private class BoundaryParseResult {
        public String op;
        public Decimal val;
    }
}