public with sharing class FEC_BCH_ExportPropertyService {

    // 12/06/2026 23:15 linhdev - Sub Section đúng theo Case Detail/MDS là 'Property Info' (FEC_ConstantCommon.PROPERTY_INFO), không phải 'Property'
    private static final String SUB_SECTION_PROPERTY = FEC_ConstantCommon.PROPERTY_INFO;

    public class ExportPropertyColumn {
        @AuraEnabled public String columnKey;
        @AuraEnabled public String label;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public Decimal sortOrder;
    }

    public class BulkExportPropertyBundle {
        @AuraEnabled public List<ExportPropertyColumn> columns;
        @AuraEnabled public Map<Id, Map<String, String>> valuesByCaseId;
    }

    public static BulkExportPropertyBundle buildBundle(
        List<String> businessProcessCodes,
        List<Id> caseIds,
        Boolean includeAllProperties
    ) {
        BulkExportPropertyBundle bundle = new BulkExportPropertyBundle();
        bundle.columns = new List<ExportPropertyColumn>();
        bundle.valuesByCaseId = new Map<Id, Map<String, String>>();
        if (includeAllProperties != true) {
            return bundle;
        }
        Set<Id> caseIdSet = new Set<Id>();
        if (caseIds != null) {
            for (Id caseId : caseIds) {
                if (caseId != null) {
                    caseIdSet.add(caseId);
                }
            }
        }
        if (caseIdSet.isEmpty()) {
            return bundle;
        }
        // 12/06/2026 23:15 linhdev - Property scope phải khớp Business/Stage/NOC của chính Case đang xử lý
        // (Stage hiện tại của Case đã gắn Business Process + NOC), không lấy toàn bộ stage của BP.
        CaseStageContext stageContext = loadCaseStageContext(caseIdSet);
        if (stageContext.stageIds.isEmpty()) {
            return bundle;
        }
        List<ExportPropertyColumn> columns = loadPropertyColumns(
            stageContext.stageIds,
            stageContext.natureOfCaseIds
        );
        bundle.columns = columns;
        if (columns.isEmpty()) {
            return bundle;
        }
        bundle.valuesByCaseId = resolvePropertyValues(caseIdSet, columns);
        return bundle;
    }

    // 12/06/2026 23:15 linhdev - Stage/NOC context của các Case đang export (Stage gắn Business Process + NOC)
    private class CaseStageContext {
        Set<Id> stageIds = new Set<Id>();
        Set<Id> natureOfCaseIds = new Set<Id>();
    }

    // 12/06/2026 23:15 linhdev - lấy Stage hiện tại + NOC của Stage (FEC_Nature_of_Cases__c) cho từng Case
    private static CaseStageContext loadCaseStageContext(Set<Id> caseIds) {
        CaseStageContext ctx = new CaseStageContext();
        if (caseIds == null || caseIds.isEmpty()) {
            return ctx;
        }
        for (Case c : [
            SELECT
                Id,
                FEC_Current_Case_Stage__c,
                FEC_Current_Case_Stage__r.FEC_Nature_of_Cases__c
            FROM Case
            WHERE Id IN :caseIds
            AND FEC_Current_Case_Stage__c != NULL
        ]) {
            ctx.stageIds.add(c.FEC_Current_Case_Stage__c);
            Id nocId = c.FEC_Current_Case_Stage__r == null
                ? null
                : c.FEC_Current_Case_Stage__r.FEC_Nature_of_Cases__c;
            if (nocId != null) {
                ctx.natureOfCaseIds.add(nocId);
            }
        }
        return ctx;
    }

    // 12/06/2026 23:15 linhdev - query MDS Property Info theo Stage (+ NOC nếu xác định được) của Case đang xử lý
    private static List<ExportPropertyColumn> loadPropertyColumns(
        Set<Id> stageIds,
        Set<Id> natureOfCaseIds
    ) {
        List<ExportPropertyColumn> out = new List<ExportPropertyColumn>();
        if (stageIds == null || stageIds.isEmpty()) {
            return out;
        }
        String subSection = SUB_SECTION_PROPERTY;
        String soql =
            'SELECT FEC_Field_Label_Name__c, FEC_Field_Object_Name__c, ' +
            'FEC_Field_API_Name__c, FEC_Field_Order_Display__c ' +
            'FROM FEC_Master_Data_Setting__c ' +
            'WHERE FEC_Stage_Name__c IN :stageIds ' +
            'AND FEC_Sub_Section__c = :subSection ' +
            'AND FEC_Field_Status__c = TRUE ' +
            'AND FEC_Field_API_Name__c != NULL ' +
            'AND FEC_Field_Object_Name__c != NULL';
        if (natureOfCaseIds != null && !natureOfCaseIds.isEmpty()) {
            soql += ' AND FEC_Nature_Of_Case__c IN :natureOfCaseIds';
        }
        soql +=
            ' ORDER BY FEC_Field_Order_Display__c NULLS LAST, ' +
            'FEC_Field_Label_Name__c NULLS LAST';
        List<FEC_Master_Data_Setting__c> mdsRows = Database.query(soql);
        Map<String, ExportPropertyColumn> deduped = new Map<String, ExportPropertyColumn>();
        for (FEC_Master_Data_Setting__c row : mdsRows) {
            if (!isReadableField(row.FEC_Field_Object_Name__c, row.FEC_Field_API_Name__c)) {
                continue;
            }
            String columnKey = buildColumnKey(
                row.FEC_Field_Object_Name__c,
                row.FEC_Field_API_Name__c
            );
            if (deduped.containsKey(columnKey)) {
                continue;
            }
            ExportPropertyColumn col = new ExportPropertyColumn();
            col.columnKey = columnKey;
            col.label = String.isBlank(row.FEC_Field_Label_Name__c)
                ? row.FEC_Field_API_Name__c
                : row.FEC_Field_Label_Name__c.trim();
            col.objectApiName = row.FEC_Field_Object_Name__c.trim();
            col.fieldApiName = row.FEC_Field_API_Name__c.trim();
            col.sortOrder = row.FEC_Field_Order_Display__c;
            deduped.put(columnKey, col);
        }
        out.addAll(deduped.values());
        out.sort(new ExportPropertyColumnComparator());
        return out;
    }

    private static Map<Id, Map<String, String>> resolvePropertyValues(
        Set<Id> caseIds,
        List<ExportPropertyColumn> columns
    ) {
        Map<Id, Map<String, String>> out = new Map<Id, Map<String, String>>();
        if (caseIds == null || caseIds.isEmpty() || columns == null || columns.isEmpty()) {
            return out;
        }
        Map<String, Set<String>> fieldsByObject = new Map<String, Set<String>>();
        Map<String, List<ExportPropertyColumn>> columnsByObject = new Map<String, List<ExportPropertyColumn>>();
        for (ExportPropertyColumn col : columns) {
            if (col == null || String.isBlank(col.objectApiName) || String.isBlank(col.fieldApiName)) {
                continue;
            }
            if (!fieldsByObject.containsKey(col.objectApiName)) {
                fieldsByObject.put(col.objectApiName, new Set<String>());
                columnsByObject.put(col.objectApiName, new List<ExportPropertyColumn>());
            }
            fieldsByObject.get(col.objectApiName).add(col.fieldApiName);
            columnsByObject.get(col.objectApiName).add(col);
        }
        Map<Id, Map<String, SObject>> recordsByCaseId = loadRecordsByCaseId(caseIds, fieldsByObject);
        for (Id caseId : caseIds) {
            Map<String, String> rowValues = new Map<String, String>();
            Map<String, SObject> objMap = recordsByCaseId.get(caseId);
            if (objMap == null) {
                out.put(caseId, rowValues);
                continue;
            }
            for (ExportPropertyColumn col : columns) {
                SObject rec = objMap.get(col.objectApiName);
                rowValues.put(col.columnKey, formatFieldValue(rec, col.fieldApiName));
            }
            out.put(caseId, rowValues);
        }
        return out;
    }

    private static Map<Id, Map<String, SObject>> loadRecordsByCaseId(
        Set<Id> caseIds,
        Map<String, Set<String>> fieldsByObject
    ) {
        Map<Id, Map<String, SObject>> out = new Map<Id, Map<String, SObject>>();
        for (Id caseId : caseIds) {
            out.put(caseId, new Map<String, SObject>());
        }
        if (fieldsByObject.containsKey('Case')) {
            loadCaseObjectRecords(caseIds, fieldsByObject.get('Case'), out);
        }
        for (String objName : fieldsByObject.keySet()) {
            if ('Case'.equalsIgnoreCase(objName)) {
                continue;
            }
            loadChildObjectRecords(caseIds, objName, fieldsByObject.get(objName), out);
        }
        return out;
    }

    private static void loadCaseObjectRecords(
        Set<Id> caseIds,
        Set<String> fieldApis,
        Map<Id, Map<String, SObject>> out
    ) {
        if (caseIds == null || caseIds.isEmpty() || fieldApis == null || fieldApis.isEmpty()) {
            return;
        }
        List<String> selectFields = buildReadableSelectFields('Case', fieldApis);
        if (selectFields.isEmpty()) {
            return;
        }
        String soql =
            'SELECT ' +
            String.join(selectFields, ', ') +
            ' FROM Case WHERE Id IN :caseIds';
        List<Case> cases = Database.query(soql);
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, cases);
        cases = (List<Case>) decision.getRecords();
        for (Case c : cases) {
            out.get(c.Id).put('Case', c);
        }
    }

    private static void loadChildObjectRecords(
        Set<Id> caseIds,
        String objName,
        Set<String> fieldApis,
        Map<Id, Map<String, SObject>> out
    ) {
        if (caseIds == null || caseIds.isEmpty() || String.isBlank(objName) || fieldApis == null || fieldApis.isEmpty()) {
            return;
        }
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objName);
        if (objType == null) {
            return;
        }
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey('FEC_Case__c')) {
            return;
        }
        List<String> selectFields = buildReadableSelectFields(objName, fieldApis);
        if (selectFields.isEmpty()) {
            return;
        }
        if (!selectFields.contains('FEC_Case__c')) {
            selectFields.add('FEC_Case__c');
        }
        String soql =
            'SELECT ' +
            String.join(selectFields, ', ') +
            ' FROM ' +
            objName +
            ' WHERE FEC_Case__c IN :caseIds';
        List<SObject> rows = Database.query(soql);
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, rows);
        rows = decision.getRecords();
        for (SObject row : rows) {
            Id caseId = (Id) row.get('FEC_Case__c');
            if (caseId == null || !out.containsKey(caseId)) {
                continue;
            }
            out.get(caseId).put(objName, row);
        }
    }

    private static List<String> buildReadableSelectFields(String objName, Set<String> fieldApis) {
        List<String> out = new List<String>();
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objName);
        if (objType == null || fieldApis == null) {
            return out;
        }
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
        for (String fieldApi : fieldApis) {
            if (String.isBlank(fieldApi) || !fieldMap.containsKey(fieldApi)) {
                continue;
            }
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldApi).getDescribe();
            if (!dfr.isAccessible()) {
                continue;
            }
            if (
                dfr.getType() == Schema.DisplayType.Picklist ||
                dfr.getType() == Schema.DisplayType.MultiPicklist
            ) {
                out.add('toLabel(' + fieldApi + ')');
            } else {
                out.add(fieldApi);
            }
        }
        return out;
    }

    private static Boolean isReadableField(String objectApiName, String fieldApiName) {
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) {
            return false;
        }
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName.trim());
        if (objType == null) {
            return false;
        }
        if (!objType.getDescribe().isAccessible()) {
            return false;
        }
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldApiName.trim())) {
            return false;
        }
        return fieldMap.get(fieldApiName.trim()).getDescribe().isAccessible();
    }

    private static String buildColumnKey(String objectApiName, String fieldApiName) {
        return objectApiName.trim().toLowerCase() + '::' + fieldApiName.trim().toLowerCase();
    }

    private static String formatFieldValue(SObject row, String fieldApiName) {
        if (row == null || String.isBlank(fieldApiName)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Object val;
        try {
            val = row.get(fieldApiName);
        } catch (Exception ex) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (val == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (val instanceof Date) {
            Date d = (Date) val;
            String day = d.day() < 10 ? '0' + d.day() : String.valueOf(d.day());
            String month = d.month() < 10 ? '0' + d.month() : String.valueOf(d.month());
            return day + '/' + month + '/' + d.year();
        }
        if (val instanceof Datetime) {
            return ((Datetime) val).format('dd/MM/yyyy HH:mm');
        }
        if (val instanceof Boolean) {
            return ((Boolean) val) ? 'true' : 'false';
        }
        return String.valueOf(val);
    }

    private class ExportPropertyColumnComparator implements System.Comparator<ExportPropertyColumn> {
        public Integer compare(ExportPropertyColumn a, ExportPropertyColumn b) {
            if (a == null && b == null) {
                return 0;
            }
            if (a == null) {
                return 1;
            }
            if (b == null) {
                return -1;
            }
            Decimal ao = a.sortOrder;
            Decimal bo = b.sortOrder;
            if (ao == null && bo == null) {
                return safeLabel(a).compareTo(safeLabel(b));
            }
            if (ao == null) {
                return 1;
            }
            if (bo == null) {
                return -1;
            }
            if (ao > bo) {
                return 1;
            }
            if (ao < bo) {
                return -1;
            }
            return safeLabel(a).compareTo(safeLabel(b));
        }

        private String safeLabel(ExportPropertyColumn col) {
            return col == null || col.label == null ? FEC_ConstantCommon.STR_EMPTY : col.label;
        }
    }
}