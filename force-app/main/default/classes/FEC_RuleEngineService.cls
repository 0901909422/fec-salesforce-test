/**
 * @description Trái tim của hệ thống: Động cơ đánh giá Luật (Rule Evaluation Engine)
 * @author DAT NGO
 * @date 2026-03-11
 */
public with sharing class FEC_RuleEngineService {

    public class RuleResult {
        @AuraEnabled public Boolean isMatched { get; set; }
        @AuraEnabled public String matchedRowId { get; set; }
        @AuraEnabled public Map<String, String> actionResults { get; set; } 
        @AuraEnabled public String message { get; set; }
        
        public RuleResult() {
            this.isMatched = false;
            this.actionResults = new Map<String, String>();
        }
    }

    public static RuleResult evaluateRule(String businessProcessCode, Id recordId, Map<String, String> contextData) {
        RuleResult result = new RuleResult();
        if (contextData == null) contextData = new Map<String, String>();

        try {
            // 1. Tìm Bảng quyết định
            List<FEC_Decision_Table__c> tables = [
                SELECT Id FROM FEC_Decision_Table__c 
                WHERE FEC_Business_Process__r.FEC_Code__c = :businessProcessCode 
                  AND FEC_Active__c = true LIMIT 1
            ];
            if (tables.isEmpty()) {
                result.message = 'Không tìm thấy Decision Table nào đang Active cho Process: ' + businessProcessCode;
                return result;
            }
            Id tableId = tables[0].Id;

            // 2. Lấy Cột
            List<FEC_Decision_Column__c> columns = [
                SELECT Id, Name, FEC_Column_Type__c, FEC_MDM_Field__r.Field_API_Name__c, FEC_MDM_Field__r.FEC_Data_Type__c 
                FROM FEC_Decision_Column__c 
                WHERE FEC_Decision_Table__c = :tableId
            ];

            Set<String> fieldsToQuery = new Set<String>();
            List<FEC_Decision_Column__c> conditionCols = new List<FEC_Decision_Column__c>();
            List<FEC_Decision_Column__c> actionCols = new List<FEC_Decision_Column__c>();

            for (FEC_Decision_Column__c col : columns) {
                if (col.FEC_Column_Type__c == 'Condition') {
                    conditionCols.add(col);
                    if (String.isNotBlank(col.FEC_MDM_Field__r?.Field_API_Name__c) && !contextData.containsKey(col.FEC_MDM_Field__r.Field_API_Name__c)) {
                        fieldsToQuery.add(col.FEC_MDM_Field__r.Field_API_Name__c);
                    }
                } else {
                    actionCols.add(col);
                }
            }

            // 3. Query dữ liệu Case/Ticket
            SObject recordData = null;
            if (recordId != null && !fieldsToQuery.isEmpty()) {
                String objectName = recordId.getSObjectType().getDescribe().getName();
                List<String> fieldList = new List<String>(fieldsToQuery);
                String soql = 'SELECT ' + String.join(fieldList, ', ') + ' FROM ' + objectName + ' WHERE Id = :recordId';
                
                List<SObject> records = Database.query(soql);
                if (!records.isEmpty()) recordData = records[0];
            }

            Map<String, String> actualValuesMap = new Map<String, String>();
            if (recordData != null) {
                for (String f : fieldsToQuery) {
                    Object val = recordData.get(f);
                    actualValuesMap.put(f, val != null ? String.valueOf(val) : '');
                }
            }
            for (String key : contextData.keySet()) {
                actualValuesMap.put(key, contextData.get(key));
            }

            // 4. Lấy danh sách Rule (ĐÃ FIX LỖI SOQL Ở ĐÂY)
            List<FEC_Decision_Row__c> rows = [
                SELECT Id, FEC_Priority__c 
                FROM FEC_Decision_Row__c 
                WHERE FEC_Decision_Table__c = :tableId AND FEC_Active__c = true 
                ORDER BY FEC_Priority__c ASC
            ];

            // 5. Lấy toàn bộ Cells
            List<FEC_Decision_Cell__c> allCells = [
                SELECT FEC_Decision_Row__c, FEC_Decision_Column__c, FEC_Value__c 
                FROM FEC_Decision_Cell__c 
                WHERE FEC_Decision_Row__c IN :rows
            ];
            
            Map<Id, Map<Id, String>> cellMatrix = new Map<Id, Map<Id, String>>();
            for (FEC_Decision_Cell__c c : allCells) {
                if (!cellMatrix.containsKey(c.FEC_Decision_Row__c)) {
                    cellMatrix.put(c.FEC_Decision_Row__c, new Map<Id, String>());
                }
                cellMatrix.get(c.FEC_Decision_Row__c).put(c.FEC_Decision_Column__c, c.FEC_Value__c);
            }

            // 6. THUẬT TOÁN ĐÁNH GIÁ
            for (FEC_Decision_Row__c row : rows) {
                Boolean isRowMatch = true;
                Map<Id, String> rowCells = cellMatrix.get(row.Id);

                for (FEC_Decision_Column__c condCol : conditionCols) {
                    String ruleValue = rowCells != null ? rowCells.get(condCol.Id) : null;
                    if (String.isBlank(ruleValue) || ruleValue == '--') continue;

                    String fieldApi = condCol.FEC_MDM_Field__r?.Field_API_Name__c;
                    String actualValue = actualValuesMap.containsKey(fieldApi) ? actualValuesMap.get(fieldApi) : '';

                    if (ruleValue != actualValue) {
                        isRowMatch = false; 
                        break;
                    }
                }

                if (isRowMatch) {
                    result.isMatched = true;
                    result.matchedRowId = row.Id;
                    result.message = 'Matched Rule Priority: ' + row.FEC_Priority__c;

                    for (FEC_Decision_Column__c actCol : actionCols) {
                        String actionVal = rowCells != null ? rowCells.get(actCol.Id) : '--';
                        String actApi = String.isNotBlank(actCol.FEC_MDM_Field__r?.Field_API_Name__c) ? actCol.FEC_MDM_Field__r.Field_API_Name__c : actCol.Name;
                        result.actionResults.put(actApi, actionVal);
                    }
                    break; 
                }
            }

            if (!result.isMatched) {
                result.message = 'Không có Rule nào thỏa mãn điều kiện.';
            }

        } catch (Exception e) {
            result.message = 'Lỗi Engine: ' + e.getMessage() + ' - Line: ' + e.getLineNumber();
        }

        return result;
    }
}