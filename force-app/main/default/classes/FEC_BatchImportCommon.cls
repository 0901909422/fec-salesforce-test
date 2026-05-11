/**
 * Shared helpers for batch import controllers (Case / Data creation).
 */
public with sharing class FEC_BatchImportCommon {
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
