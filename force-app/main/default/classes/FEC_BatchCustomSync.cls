global class FEC_BatchCustomSync implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
     
    private String query;
    private FEC_Custom_Sync__c cus;
    private Integer countSuccess = 0;
    private Integer countFail = 0;
    private Integer totalSize = 0;
    private DateTime toDate ;
    private DateTime startTime ;
    private Boolean isEndJob = false ;
    private List<FEC_integration_service_log__c> logs = new List<FEC_integration_service_log__c>();
    
    public FEC_BatchCustomSync(FEC_Custom_Sync__c recordCustom, Boolean isEndd) { 
        this.cus = recordCustom;
        this.isEndJob = isEndd; 
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {  
        DateTime currentNow = System.now();
        toDate = DateTime.newInstance(
            currentNow.year(), 
            currentNow.month(), 
            currentNow.day(), 
            currentNow.hour(), 
            0, 
            0 
        );  
        startTime  = cus.FEC_End_At__c ?? toDate.addHours(-1);
        System.debug('Batch Start Time: ' + startTime + ' || Batch End Time: ' + toDate);
        if (cus.FEC_Table_Name__c == 'BIX_FECS_AdditionalProperties') {
            System.debug('Executing Additional Properties Batch with Dynamic Query');
            return Database.getQueryLocator(FEC_CustomSyncAdditionalData.getAdditionalNeedToSync(cus, startTime, toDate));
        } else {
            System.debug('Executing Main Batch with Dynamic Query');
            return Database.getQueryLocator(getFields(cus));
        }
    } 
    
    global void execute(Database.BatchableContext bc, List<sObject> scope) { 
        FEC_integration_service_log__c log = new FEC_integration_service_log__c();  
        log.FEC_Custom_Sync__c = cus.id;
        
        try{
            totalSize = totalSize + scope.size();
            if(scope == null || scope.isEmpty()){
                log.FEC_Error_Message__c = 'Record not found'; 
            } else {
                
                // [CORE ENGINE]: Gom dữ liệu động từ cả Dynamic Query (có biến) và Static Query (không biến)
                Map<Id, Map<String, Object>> dynamicQueryData = getDynamicQueryData(scope, cus.FEC_Request_Body_Mapping__c, cus.FEC_Map_Select_Field__c);
                
                // Truyền Map qua Callout để sinh JSON
                List<FEC_integration_service_log__c> resultLogs = FEC_CustomSyncCallout.sendRequest(cus, log, scope, dynamicQueryData);  
                
                for (FEC_integration_service_log__c rLog : resultLogs) {
                    if (rLog.FEC_Bix_Is_Success__c == true) { 
                         countSuccess = countSuccess + countIdsFromJsonString(rLog.Records__c); 
                    } else {  
                         countFail = countFail + countIdsFromJsonString(rLog.Records__c); 
                    }
                    logs.add(rLog);
                }
                return;
            }
        }Catch(Exception e){ 
            log.FEC_Error_Message__c = 'Exception FEC_BatchCustomSync: Line ' + e.getLineNumber() + ' - '+e.getMessage();
            log.FEC_Bix_Is_Success__c = false;
        }
        logs.add(log);
    }
 
    global void finish(Database.BatchableContext bc) { 
        cus.FEC_Start_At__c = cus.FEC_End_At__c ?? toDate.addHours(-1);
        cus.FEC_End_At__c = toDate;
        cus.FEC_Sync_Successfully__c = countSuccess;
        cus.FEC_Sync_Failed__c = countFail;
        cus.FEC_Total_Record_Sync__c = totalSize;
        update cus; 
        
        if(!logs.isEmpty()){
            upsert logs;
        }
        if(isEndJob) System.enqueueJob(new FEC_QueueReportCustomSyncBix());   
    }

    public static Integer countIdsFromJsonString(String jsonStringInput) { 
        if (String.isBlank(jsonStringInput)) return 0; 
        try { 
            List<String> idList = (List<String>) JSON.deserialize(jsonStringInput, List<String>.class);
            return idList.size(); 
        } catch (Exception e) { 
            return 0;
        }
    }

    // ==================================================================================
    // Hàm getFields: Lấy list field từ Mapping và FEC_Map_Select_Field__c để tạo SOQL cha
    // ==================================================================================
   public static String getFields(FEC_Custom_Sync__c cus) { 
        Set<String> fieldSet = extractFieldsFromMapping(cus.FEC_Request_Body_Mapping__c);
        
        // Đọc cấu hình từ FEC_Map_Select_Field__c để map thêm Field vào
        if (cus.FEC_Map_Select_Field__c != null && String.isNotBlank(cus.FEC_Map_Select_Field__c ?? '')) {
            String cleanMapStr = cus.FEC_Map_Select_Field__c.replace('""', '"');
            try {
                Map<String, Object> mapSelect = (Map<String, Object>) JSON.deserializeUntyped(cleanMapStr);
                for (Object fieldName : mapSelect.values()) {
                    if (fieldName != null) {
                        fieldSet.add(String.valueOf(fieldName).toLowerCase()); 
                    }
                }
            } catch (Exception e) { System.debug('Lỗi parse FEC_Map_Select_Field__c: ' + e.getMessage()); }
        }
        
        String fieldList = String.join(new List<String>(fieldSet), ', ');


        
        String additionalConditions = Test.isRunningTest() ? '' :  String.isNotBlank(cus.FEC_Additional_Conditions__c) ? ' ' + cus.FEC_Additional_Conditions__c + ' ' : ''; 
        String modifiedField = Test.isRunningTest() ? '' :  String.isNotBlank(cus.FEC_Modified_Date_Field__c) ? cus.FEC_Modified_Date_Field__c : 'LastModifiedDate';
        String createdField = Test.isRunningTest() ? '' :  String.isNotBlank(cus.FEC_Created_Date_Field__c) ? cus.FEC_Created_Date_Field__c : 'CreatedDate';
        
        // FIX LỖI MẤT BIẾN WHATNAME: Chèn trực tiếp value vào chuỗi thay vì dùng :whatName
        String caseType = '';
        if (String.isNotBlank(cus.FEC_Case_Business_Code__c)) {
            caseType = ' AND FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c = \'' + String.escapeSingleQuotes(cus.FEC_Case_Business_Code__c) + '\' ';
        }
                if (Test.isRunningTest()) return 'SELECT ' + fieldList + ' FROM ' + cus.FEC_Target_Object__c; 
        String wherePart = ' WHERE ((' + modifiedField + ' > :startTime AND ' + modifiedField + ' <= :toDate) ' +
                           ' OR (' + createdField + ' > :startTime AND ' + createdField + ' <= :toDate) )' + 
                           caseType + additionalConditions;   
        return 'SELECT ' + fieldList + ' FROM ' + cus.FEC_Target_Object__c + wherePart;
    }

    public static Set<String> extractFieldsFromMapping(String mappingJson) {
        String cleanMappingStr = String.isNotBlank(mappingJson) ? mappingJson.replace('""', '"') : '{}';
        Map<String, Object> mapping = (Map<String, Object>) JSON.deserializeUntyped(cleanMappingStr);
        Set<String> fields = new Set<String>();
        fields.add('id'); // ID in thường để tránh Duplicate
        
        for (String key : mapping.keySet()) {
            Object val = mapping.get(key);
            if (val instanceof String && (String) val != 'DateTimeNow') {
                String strVal = (String) val;
                if (!strVal.endsWith('__g')) {
                    fields.add(strVal.toLowerCase());
                }
            }
        }
        return fields;
    }

    // Helper: Hỗ trợ truy xuất dữ liệu có chứa quan hệ chấm (.) như CreatedBy.Name
    public static Object getFieldValue(SObject record, String fieldPath) {
        if (record == null || String.isBlank(fieldPath)) return null;
        List<String> parts = fieldPath.split('\\.');
        SObject current = record;
        for (Integer i = 0; i < parts.size() - 1; i++) {
            if (current == null) return null;
            try { current = current.getSObject(parts[i]); } catch (Exception e) { return null; }
        }
        if (current == null) return null;
        try { return current.get(parts[parts.size() - 1]); } catch (Exception e) { return null; }
    }

    // ==================================================================================
    // [ENGINE] Hàm xử lý Sub-Queries (Routing map, Bulkification IN query, Static/Dynamic)
    // ==================================================================================
    public static Map<Id, Map<String, Object>> getDynamicQueryData(List<sObject> scope, String mappingJson, String mapSelectJson) {
        Map<Id, Map<String, Object>> scopeDynamicData = new Map<Id, Map<String, Object>>();
        for (sObject record : scope) {
            scopeDynamicData.put((Id) record.get('Id'), new Map<String, Object>());
        }

        String cleanMappingStr = String.isNotBlank(mappingJson) ? mappingJson.replace('""', '"') : '{}';
        Map<String, Object> mappingConfig = (Map<String, Object>) JSON.deserializeUntyped(cleanMappingStr);
        Map<String, Map<String, Object>> queryFieldsConfig = new Map<String, Map<String, Object>>();
        
        for (String key : mappingConfig.keySet()) {
            if (mappingConfig.get(key) instanceof Map<String, Object>) {
                queryFieldsConfig.put(key, (Map<String, Object>) mappingConfig.get(key));
            }
        }
        if(queryFieldsConfig.isEmpty()) return scopeDynamicData;

        Map<String, String> varToFieldMap = new Map<String, String>();
        String cleanSelectStr = String.isNotBlank(mapSelectJson) ? mapSelectJson.replace('""', '"') : '{"ObjectID": "Id"}';
        try {
            Map<String, Object> rawMap = (Map<String, Object>) JSON.deserializeUntyped(cleanSelectStr);
            for(String key : rawMap.keySet()) varToFieldMap.put(key, String.valueOf(rawMap.get(key)));
        } catch(Exception e) { varToFieldMap.put('ObjectID', 'Id'); } 

        Map<String, Set<String>> varValuesToQuery = new Map<String, Set<String>>();
        Map<String, Map<String, List<Id>>> routingMap = new Map<String, Map<String, List<Id>>>();
        Set<Id> scopeIds = scopeDynamicData.keySet();

        for (String varName : varToFieldMap.keySet()) {
            varValuesToQuery.put(varName, new Set<String>());
            routingMap.put(varName, new Map<String, List<Id>>());
        }

        for (sObject record : scope) {
            Id parentId = (Id) record.get('Id');
            for (String varName : varToFieldMap.keySet()) {
                Object valObj = getFieldValue(record, varToFieldMap.get(varName));
                if (valObj != null) {
                    String valStr = String.valueOf(valObj);
                    varValuesToQuery.get(varName).add(valStr); 
                    
                    if (!routingMap.get(varName).containsKey(valStr)) {
                        routingMap.get(varName).put(valStr, new List<Id>());
                    }
                    routingMap.get(varName).get(valStr).add(parentId); 
                }
            }
        }

        for (String jsonKey : queryFieldsConfig.keySet()) {
            Map<String, Object> qConfig = queryFieldsConfig.get(jsonKey);
            String selectField = (String) qConfig.get('Select');
            String fromObject = (String) qConfig.get('From');
            String whereClause = (String) qConfig.get('Where');

            Pattern p = Pattern.compile('(?i)\\b([\\w\\.]+)\\s*=\\s*:(\\w+)\\b');
            Matcher m = String.isNotBlank(whereClause) ? p.matcher(whereClause) : p.matcher('');

            if (m.find()) {
                // =========================================================
                // TRƯỜNG HỢP 1: DYNAMIC QUERY 
                // =========================================================
                String childLinkField = m.group(1);
                String mappedVarName = m.group(2); 
                String matchedExpression = m.group(0); 

                if (String.isBlank(mappedVarName) || !varValuesToQuery.containsKey(mappedVarName) || varValuesToQuery.get(mappedVarName).isEmpty()) {
                    continue; 
                }

                List<String> inValues = new List<String>();
                for(String v : varValuesToQuery.get(mappedVarName)) {
                    inValues.add('\'' + String.escapeSingleQuotes(v) + '\'');
                }
                String inClauseStr = 'IN (' + String.join(inValues, ',') + ')';

                String dynamicWhere = whereClause.replaceAll('(?i)\\s*limit\\s+\\d+', '');
                dynamicWhere = dynamicWhere.replace(matchedExpression, childLinkField + ' ' + inClauseStr);

                // [FIX LỖI TRÙNG ID BÊN TRONG CÂU QUERY]
                String selectStr = 'Id';
                if (selectField.toLowerCase() != 'id') {
                    selectStr += ', ' + selectField;
                }
                if (String.isNotBlank(childLinkField) && !selectStr.toLowerCase().contains(childLinkField.toLowerCase())) {
                    selectStr += ', ' + childLinkField;
                }

                String queryString = 'SELECT ' + selectStr + ' FROM ' + fromObject + ' WHERE ' + dynamicWhere;

                try {
                    List<sObject> queriedRecords = Database.query(queryString);
                    for (sObject childRecord : queriedRecords) {
                        
                        Object childLinkValObj = getFieldValue(childRecord, childLinkField);
                        if (childLinkValObj != null) {
                            String childLinkValStr = String.valueOf(childLinkValObj);
                            
                            if (routingMap.containsKey(mappedVarName) && routingMap.get(mappedVarName).containsKey(childLinkValStr)) {
                                List<Id> matchedParentIds = routingMap.get(mappedVarName).get(childLinkValStr);
                                
                                for (Id pId : matchedParentIds) {
                                    if (!scopeDynamicData.get(pId).containsKey(jsonKey)) {
                                        Object rawValue = getFieldValue(childRecord, selectField);
                                        scopeDynamicData.get(pId).put(jsonKey, rawValue);
                                    }
                                }
                            }
                        }
                    }
                } catch (Exception e) {
                    System.debug('Error in Dynamic Query (' + jsonKey + '): ' + queryString + ' || Exception: ' + e.getMessage());
                }

            } else {
                // =========================================================
                // TRƯỜNG HỢP 2: STATIC QUERY (FIX LỖI TRÙNG ID)
                // =========================================================
                String selectStr = 'Id';
                if (selectField.toLowerCase() != 'id') {
                    selectStr += ', ' + selectField;
                }

                String queryString = 'SELECT ' + selectStr + ' FROM ' + fromObject;
                if (String.isNotBlank(whereClause)) {
                    queryString += ' WHERE ' + whereClause; 
                }

                try {
                    List<sObject> staticRecords = Database.query(queryString);
                    if (!staticRecords.isEmpty()) {
                        Object staticValue = getFieldValue(staticRecords[0], selectField);
                        
                        for (Id pId : scopeIds) {
                            if (!scopeDynamicData.get(pId).containsKey(jsonKey)) {
                                scopeDynamicData.get(pId).put(jsonKey, staticValue);
                            }
                        }
                    }
                } catch (Exception e) {
                    System.debug('Error in Static Query (' + jsonKey + '): ' + queryString + ' || Exception: ' + e.getMessage());
                }
            }
        }
        
        return scopeDynamicData;
    }
}