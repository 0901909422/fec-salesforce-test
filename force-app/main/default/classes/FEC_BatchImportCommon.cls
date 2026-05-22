/**
 * Shared helpers for batch import controllers (Case / Data creation).
 */
public with sharing class FEC_BatchImportCommon {
    public static Id getCustomerCaseRecordTypeId() {
        return FEC_CommonUltils.getRecordTypeIdByDev(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME);
    }

    public static String removeFileExtension(String fileName) {
        if (String.isBlank(fileName)) {
            return fileName;
        }
        Integer idx = fileName.lastIndexOf('.');
        if (idx == null || idx <= 0) {
            return fileName;
        }
        return fileName.substring(0, idx);
    }

    /** Title ContentDocument của file upload gốc (tránh nhầm với file result khi tên có *_Result). */
    public static String normalizeSourceContentTitle(String fileName) {
        String base = removeFileExtension(fileName);
        if (String.isBlank(base)) {
            return base;
        }
        String lower = base.toLowerCase();
        if (lower.endsWith('_importresult')) {
            return base.substring(0, base.length() - 13);
        }
        if (lower.endsWith('_result')) {
            return base.substring(0, base.length() - 7);
        }
        return base;
    }

    public static String buildResultContentTitle(String sourceFileName) {
        return normalizeSourceContentTitle(sourceFileName) + '_ImportResult';
    }

    public static Boolean isResultContentTitle(String title) {
        if (String.isBlank(title)) {
            return false;
        }
        String lower = title.toLowerCase();
        return lower.endsWith('_importresult') || lower.endsWith('_result');
    }

    public static void addIfNotBlank(List<String> selectParts, String fieldApiName) {
        if (String.isNotBlank(fieldApiName) && !selectParts.contains(fieldApiName)) {
            selectParts.add(fieldApiName);
        }
    }

    public static String pickField(Map<String, Schema.SObjectField> fieldMap, List<String> preferredNames) {
        for (String name : preferredNames) {
            if (fieldMap.containsKey(name)) {
                return name;
            }
        }
        return null;
    }

    public static String normalizeText(Object value) {
        return value == null ? '' : String.valueOf(value).trim();
    }

    public static String asString(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    public static Object getFieldValue(SObject row, String fieldApiName) {
        if (row == null || String.isBlank(fieldApiName)) {
            return null;
        }
        return row.get(fieldApiName);
    }

    public static Datetime asDatetime(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Datetime) {
            return (Datetime) value;
        }
        return null;
    }

    public static Decimal asDecimal(Object value) {
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

    public static void putIfFieldExists(
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

    /** Nối nhiều lỗi bằng dấu phẩy (file result Batch Data / Batch Case). */
    public static String joinRowErrors(List<String> errs) {
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

    public static void linkFileToBatch(Id batchId, Id contentDocumentId) {
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
}
