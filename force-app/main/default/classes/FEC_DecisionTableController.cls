/**
 * @description Dynamic EAV Controller for Decision Table UI
 * @author DAT NGO
 * @date 2026-03-10
 */
public with sharing class FEC_DecisionTableController {
    
    public class TableWrapper {
        @AuraEnabled public String tableId { get; set; }
        @AuraEnabled public List<ColumnWrapper> conditionCols { get; set; }
        @AuraEnabled public List<ColumnWrapper> actionCols { get; set; }
        @AuraEnabled public List<RowWrapper> rows { get; set; }
    }
    public class ColumnWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String type { get; set; }
    }
    public class RowWrapper {
        @AuraEnabled public String rowId { get; set; }
        @AuraEnabled public List<CellWrapper> conditionCells { get; set; }
        @AuraEnabled public List<CellWrapper> actionCells { get; set; }
        @AuraEnabled public List<CellWrapper> allSearchableCells { get; set; }
    }
    public class CellWrapper {
        @AuraEnabled public String colId { get; set; }
        @AuraEnabled public String value { get; set; }
    }
    
    // =========================================================
    // 1. HÀM LOAD CÂY BUSINESS PROCESS (Đã khôi phục đầy đủ)
    // =========================================================
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getBusinessProcessTree() {
        System.debug('[getBusinessProcessTree] START');
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        
        try {
            List<FEC_Business_Process__c> businessProcesses = [
                SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c, FEC_Order__c
                FROM FEC_Business_Process__c
                WHERE FEC_Active__c = true
                ORDER BY FEC_Order__c ASC NULLS LAST, Name ASC
            ];
            
            if (businessProcesses.isEmpty()) return result;
            
            Map<Id, List<FEC_Case_Stage__c>> stagesByBP = new Map<Id, List<FEC_Case_Stage__c>>();
            List<FEC_Case_Stage__c> allStages = [
                SELECT Id, Name, FEC_Code__c, FEC_Business_Process__c, FEC_Order__c
                FROM FEC_Case_Stage__c
                WHERE FEC_Active__c = true AND FEC_Business_Process__c IN :businessProcesses
                ORDER BY FEC_Business_Process__c ASC, FEC_Order__c ASC NULLS LAST, Name ASC
            ];
            
            for (FEC_Case_Stage__c stage : allStages) {
                if (!stagesByBP.containsKey(stage.FEC_Business_Process__c)) {
                    stagesByBP.put(stage.FEC_Business_Process__c, new List<FEC_Case_Stage__c>());
                }
                stagesByBP.get(stage.FEC_Business_Process__c).add(stage);
            }
            
            for (FEC_Business_Process__c bp : businessProcesses) {
                Map<String, Object> bpNode = new Map<String, Object>();
                bpNode.put('id', bp.Id);
                bpNode.put('label', bp.Name);
                bpNode.put('code', bp.FEC_Code__c);
                bpNode.put('nameVN', bp.FEC_Name_VN__c);
                bpNode.put('type', 'BUSINESS_PROCESS');
                bpNode.put('icon', 'utility:process');
                
                List<Map<String, Object>> stageNodes = new List<Map<String, Object>>();
                if (stagesByBP.containsKey(bp.Id)) {
                    for (FEC_Case_Stage__c stage : stagesByBP.get(bp.Id)) {
                        Map<String, Object> stageNode = new Map<String, Object>();
                        stageNode.put('id', stage.Id);
                        stageNode.put('label', stage.Name);
                        stageNode.put('code', stage.FEC_Code__c);
                        stageNode.put('type', 'STAGE');
                        stageNode.put('parentId', bp.Id);
                        stageNode.put('icon', 'utility:steps');
                        stageNodes.add(stageNode);
                    }
                }
                bpNode.put('children', stageNodes);
                bpNode.put('childCount', stageNodes.size());
                result.add(bpNode);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching BP tree: ' + e.getMessage());
        }
    }
    
    // =========================================================
    // 2. HÀM LOAD BẢNG QUYẾT ĐỊNH ĐỘNG
    // =========================================================
    @AuraEnabled(cacheable=true)
    public static TableWrapper getDynamicDecisionTable(String businessProcessId) {
        System.debug('[getDynamicDecisionTable] START');
        TableWrapper result = new TableWrapper();
        result.conditionCols = new List<ColumnWrapper>();
        result.actionCols = new List<ColumnWrapper>();
        result.rows = new List<RowWrapper>();
        
        if (String.isBlank(businessProcessId)) return result;
        
        try {
            List<FEC_Decision_Table__c> tables = [SELECT Id FROM FEC_Decision_Table__c WHERE FEC_Business_Process__c = :businessProcessId AND FEC_Active__c = true LIMIT 1];
            if (tables.isEmpty()) return result;
            
            result.tableId = tables[0].Id;
            
            List<FEC_Decision_Column__c> listCols = [
                SELECT Id, Name, FEC_Column_Type__c 
                FROM FEC_Decision_Column__c 
                WHERE FEC_Decision_Table__c = :result.tableId 
                ORDER BY FEC_Column_Type__c DESC, FEC_Order__c ASC
            ];
            
            for (FEC_Decision_Column__c col : listCols) {
                ColumnWrapper cw = new ColumnWrapper();
                cw.id = col.Id; cw.label = col.Name; cw.type = col.FEC_Column_Type__c;
                if (col.FEC_Column_Type__c == 'Condition') result.conditionCols.add(cw);
                else result.actionCols.add(cw);
            }
            
            Map<Id, RowWrapper> rowMap = new Map<Id, RowWrapper>();
            for (FEC_Decision_Row__c r : [SELECT Id FROM FEC_Decision_Row__c WHERE FEC_Decision_Table__c = :result.tableId ORDER BY FEC_Priority__c ASC]) {
                RowWrapper rw = new RowWrapper();
                rw.rowId = r.Id;
                rw.conditionCells = new List<CellWrapper>();
                rw.actionCells = new List<CellWrapper>();
                rw.allSearchableCells = new List<CellWrapper>();
                rowMap.put(r.Id, rw);
                result.rows.add(rw);
            }
            
            Map<String, String> cellValueMap = new Map<String, String>();
            for (FEC_Decision_Cell__c cell : [SELECT FEC_Decision_Row__c, FEC_Decision_Column__c, FEC_Value__c FROM FEC_Decision_Cell__c WHERE FEC_Decision_Row__c IN :rowMap.keySet()]) {
                cellValueMap.put(cell.FEC_Decision_Row__c + '-' + cell.FEC_Decision_Column__c, cell.FEC_Value__c);
            }
            
            for (RowWrapper rw : result.rows) {
                for (ColumnWrapper cw : result.conditionCols) {
                    CellWrapper cell = new CellWrapper(); cell.colId = cw.id;
                    cell.value = cellValueMap.containsKey(rw.rowId + '-' + cw.id) ? cellValueMap.get(rw.rowId + '-' + cw.id) : '--';
                    rw.conditionCells.add(cell); rw.allSearchableCells.add(cell);
                }
                for (ColumnWrapper cw : result.actionCols) {
                    CellWrapper cell = new CellWrapper(); cell.colId = cw.id;
                    cell.value = cellValueMap.containsKey(rw.rowId + '-' + cw.id) ? cellValueMap.get(rw.rowId + '-' + cw.id) : '--';
                    rw.actionCells.add(cell); rw.allSearchableCells.add(cell);
                }
            }
            return result;
        } catch(Exception e) {
            throw new AuraHandledException('Error loading dynamic table: ' + e.getMessage());
        }
    }
    
    // =========================================================
    // 3. HÀM LƯU VÀ XÓA RULE ĐỘNG
    // =========================================================
    @AuraEnabled
    public static void saveDynamicRule(String tableId, String rowId, Map<String, String> cellDataMap) {
        System.debug('[saveDynamicRule] START');
        Savepoint sp = Database.setSavepoint();
        try {
            FEC_Decision_Row__c row = new FEC_Decision_Row__c();
            if (String.isNotBlank(rowId)) {
                row.Id = rowId;
            } else {
                row.FEC_Decision_Table__c = tableId;
                row.FEC_Active__c = true;
                row.FEC_Priority__c = 99;
                insert row;
                rowId = row.Id;
            }
            
            Map<String, Id> existingCellMap = new Map<String, Id>();
            for(FEC_Decision_Cell__c c : [SELECT Id, FEC_Decision_Column__c FROM FEC_Decision_Cell__c WHERE FEC_Decision_Row__c = :rowId]) {
                existingCellMap.put(c.FEC_Decision_Column__c, c.Id);
            }
            
            List<FEC_Decision_Cell__c> upsertCells = new List<FEC_Decision_Cell__c>();
            for (String colId : cellDataMap.keySet()) {
                FEC_Decision_Cell__c cell = new FEC_Decision_Cell__c();
                if (existingCellMap.containsKey(colId)) {
                    cell.Id = existingCellMap.get(colId);
                } else {
                    cell.FEC_Decision_Row__c = rowId;
                    cell.FEC_Decision_Column__c = colId;
                }
                cell.FEC_Value__c = cellDataMap.get(colId);
                upsertCells.add(cell);
            }
            upsert upsertCells;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Lỗi khi lưu Rule: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void deleteDynamicRule(String rowId) {
        try {
            delete new FEC_Decision_Row__c(Id = rowId);
        } catch (Exception e) {
            throw new AuraHandledException('Lỗi khi xóa Rule: ' + e.getMessage());
        }
    }
    
    // =========================================================
    // 4. HÀM QUẢN LÝ CỘT VÀ DÒNG TRỰC TIẾP TỪ UI (PEGA STYLE)
    // =========================================================
    @AuraEnabled
    public static void addDynamicColumn(String tableId, String targetColId, String position, String colName, String colType, String dataType, String mdmFieldId) {
        Savepoint sp = Database.setSavepoint();
        try {
            Decimal newOrder = 1;
            
            if (String.isNotBlank(targetColId)) {
                FEC_Decision_Column__c targetCol = [SELECT FEC_Order__c, FEC_Column_Type__c FROM FEC_Decision_Column__c WHERE Id = :targetColId LIMIT 1];
                newOrder = position == 'left' ? targetCol.FEC_Order__c : targetCol.FEC_Order__c + 1;
                
                List<FEC_Decision_Column__c> colsToUpdate = [
                    SELECT Id, FEC_Order__c FROM FEC_Decision_Column__c 
                    WHERE FEC_Decision_Table__c = :tableId 
                      AND FEC_Column_Type__c = :colType 
                      AND FEC_Order__c >= :newOrder
                ];
                for (FEC_Decision_Column__c c : colsToUpdate) {
                    c.FEC_Order__c += 1;
                }
                if (!colsToUpdate.isEmpty()) update colsToUpdate;
            } else {
                List<AggregateResult> agg = [SELECT MAX(FEC_Order__c) maxOrder FROM FEC_Decision_Column__c WHERE FEC_Decision_Table__c = :tableId AND FEC_Column_Type__c = :colType];
                if (agg[0].get('maxOrder') != null) {
                    newOrder = (Decimal)agg[0].get('maxOrder') + 1;
                }
            }
            
            // ĐÃ BỔ SUNG FEC_MDM_Field__c VÀO LỆNH INSERT
            FEC_Decision_Column__c newCol = new FEC_Decision_Column__c(
                Name = colName,
            FEC_Decision_Table__c = tableId,
            FEC_Column_Type__c = colType,
            FEC_Data_Type__c = dataType,
            FEC_Order__c = newOrder,
            FEC_MDM_Field__c = mdmFieldId
                );
            insert newCol;
            
            List<FEC_Decision_Row__c> existingRows = [SELECT Id FROM FEC_Decision_Row__c WHERE FEC_Decision_Table__c = :tableId];
            List<FEC_Decision_Cell__c> newCells = new List<FEC_Decision_Cell__c>();
            for (FEC_Decision_Row__c r : existingRows) {
                newCells.add(new FEC_Decision_Cell__c(
                    FEC_Decision_Row__c = r.Id,
                FEC_Decision_Column__c = newCol.Id,
                FEC_Value__c = '--'
                    ));
            }
            if (!newCells.isEmpty()) insert newCells;
            
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Lỗi thêm Cột: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void deleteDynamicColumn(String colId) {
        try {
            // Nhờ Master-Detail, xóa Cột sẽ tự động xóa các Cells liên quan
            delete new FEC_Decision_Column__c(Id = colId);
        } catch (Exception e) {
            throw new AuraHandledException('Lỗi xóa Cột: ' + e.getMessage());
        }
    }
    
    /**
     * @description Thêm một dòng mới (Trên hoặc Dưới dòng đang chọn)
     * @author DAT NGO
     */
    @AuraEnabled
    public static void addDynamicRow(String tableId, String targetRowId, String position) {
        Savepoint sp = Database.setSavepoint();
        try {
            Decimal newPriority = 1;
            
            if (String.isNotBlank(targetRowId)) {
                FEC_Decision_Row__c targetRow = [SELECT FEC_Priority__c FROM FEC_Decision_Row__c WHERE Id = :targetRowId LIMIT 1];
                newPriority = position == 'above' ? targetRow.FEC_Priority__c : targetRow.FEC_Priority__c + 1;
                
                List<FEC_Decision_Row__c> rowsToUpdate = [
                    SELECT Id, FEC_Priority__c FROM FEC_Decision_Row__c 
                    WHERE FEC_Decision_Table__c = :tableId AND FEC_Priority__c >= :newPriority
                ];
                for (FEC_Decision_Row__c r : rowsToUpdate) {
                    r.FEC_Priority__c += 1;
                }
                if (!rowsToUpdate.isEmpty()) update rowsToUpdate;
            } else {
                List<AggregateResult> agg = [SELECT MAX(FEC_Priority__c) maxPri FROM FEC_Decision_Row__c WHERE FEC_Decision_Table__c = :tableId];
                if (agg[0].get('maxPri') != null) {
                    newPriority = (Decimal)agg[0].get('maxPri') + 1;
                }
            }
            
            FEC_Decision_Row__c newRow = new FEC_Decision_Row__c(
                FEC_Decision_Table__c = tableId,
            FEC_Priority__c = newPriority,
            FEC_Active__c = true
                );
            insert newRow;
            
            // Tạo Cells rỗng dựa trên các Columns hiện có
            List<FEC_Decision_Column__c> existingCols = [SELECT Id FROM FEC_Decision_Column__c WHERE FEC_Decision_Table__c = :tableId];
            List<FEC_Decision_Cell__c> newCells = new List<FEC_Decision_Cell__c>();
            for (FEC_Decision_Column__c c : existingCols) {
                newCells.add(new FEC_Decision_Cell__c(
                    FEC_Decision_Row__c = newRow.Id,
                FEC_Decision_Column__c = c.Id,
                FEC_Value__c = '--'
                    ));
            }
            if (!newCells.isEmpty()) insert newCells;
            
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Lỗi thêm Dòng: ' + e.getMessage());
        }
    }
    
    // =========================================================
    // 5. HÀM LẤY DANH SÁCH FIELD TỪ MDM (DỰA THEO BUSINESS PROCESS)
    // =========================================================
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMDMFieldOptions(String businessProcessId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        if (String.isBlank(businessProcessId)) return options;
        
        try {
            // Đã cập nhật Query vào FEC_Master_Data_Setting__c
            List<FEC_Master_Data_Setting__c> mdsList = [
                SELECT FEC_Additional_Field__r.Id, 
                       FEC_Additional_Field__r.Field_Label_Name__c, 
                       FEC_Additional_Field__r.FEC_Data_Type__c
                FROM FEC_Master_Data_Setting__c
                WHERE FEC_Nature_Of_Case__r.FEC_Business_Process__c = :businessProcessId
                   OR FEC_Stage_Name__r.FEC_Business_Process__c = :businessProcessId
            ];
            
            // Dùng Set để lọc trùng lặp
            Set<Id> addedFieldIds = new Set<Id>();
            
            for (FEC_Master_Data_Setting__c mds : mdsList) {
                if (mds.FEC_Additional_Field__c != null && !addedFieldIds.contains(mds.FEC_Additional_Field__c)) {
                    Map<String, String> opt = new Map<String, String>();
                    opt.put('label', mds.FEC_Additional_Field__r.Field_Label_Name__c);
                    opt.put('value', mds.FEC_Additional_Field__r.Id);
                    opt.put('dataType', mds.FEC_Additional_Field__r.FEC_Data_Type__c);
                    options.add(opt);
                    addedFieldIds.add(mds.FEC_Additional_Field__c);
                }
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException('Lỗi khi lấy danh sách Field MDM: ' + e.getMessage());
        }
    }
}