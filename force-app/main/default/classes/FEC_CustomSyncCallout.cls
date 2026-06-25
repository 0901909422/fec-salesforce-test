/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Create Callout Sync Data 
Test Class:     FEC_CustomSyncAllInOneTest
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/03/31     Duan Nguyen          Init
------------------------------------------------------------*/
public with sharing class FEC_CustomSyncCallout { 
    
    // Overload 3-arg: gọi 4-arg với mapDynamicData = null
    public static List<FEC_integration_service_log__c> sendRequest(FEC_Custom_Sync__c cus, FEC_integration_service_log__c log, List<SObject> scope) {
        return sendRequest(cus, log, scope, null);
    }

    // Đã thêm tham số mapDynamicData để nhận kết quả query động từ Batch
    public static List<FEC_integration_service_log__c> sendRequest(FEC_Custom_Sync__c cus, FEC_integration_service_log__c log, List<SObject> scope, Map<Id, Map<String, Object>> mapDynamicData) {
        List<FEC_integration_service_log__c> resultLogs = new List<FEC_integration_service_log__c>();
        log.FEC_Quantity_Call__c = (log.FEC_Quantity_Call__c ?? 0) + 1;
        
        // LƯU TOÀN BỘ RECORD IDS TRƯỚC KHI CALL API (Mặc định coi như tất cả đều failed)
        List<String> allRecordIds = new List<String>();
        if (scope != null && !scope.isEmpty()) {
            for (SObject record : scope) {
                allRecordIds.add(String.valueOf(record.get('Id')));
            }
            log.Records__c = JSON.serialize(allRecordIds);
        }
        log.FEC_Bix_Is_Success__c = false; // Mặc định là failed
        
        try {   
            CustomSyncSetting__c apiSetting = CustomSyncSetting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Custom_Sync_Bix'); 

            String jsonBody = null;
            // Build json body for table AdditionalProperties
            if (cus.FEC_Table_Name__c == 'BIX_FECS_AdditionalProperties') {
                jsonBody = FEC_CustomSyncAdditionalData.getAdditionalInfoJson(scope, cus.FEC_Table_Name__c);
            } else {
                // Truyền mapDynamicData vào hàm toJson
                jsonBody = toJson(cus, scope, mapDynamicData);
            }
            
            log.FEC_Endpoint__c = apiSetting?.Endpoint__c + apiConfig?.FEC_Endpoint__c;
            log.FEC_Method__c = 'POST'; 

            HttpRequest req = new HttpRequest();
            req.setEndpoint(apiSetting?.Endpoint__c + apiConfig?.FEC_Endpoint__c);
            req.setMethod('POST');
            req.setTimeout(60000);
            req.setHeader('X-API-KEY', apiSetting.ApiKey__c);
            req.setHeader('Content-Type', 'application/json');  
            req.setBody(jsonBody);
            Http http = new Http(); 
            HttpResponse response = http.send(req); 
            
            log.FEC_Request_Data__c = jsonBody.length() > 32768 ? jsonBody.substring(0, 32768) : jsonBody;
            log.FEC_Status_Code__c = String.valueOf(response.getStatusCode());
            String resBody = response.getBody();
            String truncatedRes = resBody != null && resBody.length() > 32768 ? resBody.substring(0, 32768) : resBody;
            log.FEC_Response_Data__c = truncatedRes;
            
            // Parse response to split success/failed records
            if (response.getStatusCode() == 200 && String.isNotBlank(resBody)) {
                Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(resBody);
                Map<String, Object> data = (Map<String, Object>) resMap.get('data');
                if (data != null) {
                    Integer totalSuccess = data.get('totalSuccess') != null ? Integer.valueOf(String.valueOf(data.get('totalSuccess'))) : 0;
                    log.FEC_Bix_Is_Success__c = (totalSuccess != null && totalSuccess > 0);
                    Integer totalFailed = data.get('totalFailed') != null ? Integer.valueOf(String.valueOf(data.get('totalFailed'))) : 0;
                    
                    // XỬ LÝ TRƯỜNG HỢP 100% SUCCESS (totalFailed = 0)
                    if (totalFailed == 0 && totalSuccess > 0) {
                        Map<String, String> extIdToSfId = new Map<String, String>();
                        for (SObject record : scope) {
                            String extId = null;
                            try {
                                extId = (String) record.get('FEC_ID_Search__c');
                            } catch (Exception e) {
                                // Field không tồn tại
                            }
                            String sfId = String.valueOf(record.get('Id'));
                            if (extId != null) {
                                extIdToSfId.put(extId, sfId);
                            } else {
                                extIdToSfId.put(sfId, sfId);
                            }
                        }
                        
                        List<Object> successRecords = (List<Object>) data.get('successRecords');
                        List<String> successSfIds = new List<String>();
                        if (successRecords != null) {
                            for (Object sr : successRecords) {
                                String extId = (String) sr;
                                if (extIdToSfId.containsKey(extId)) {
                                    successSfIds.add(extIdToSfId.get(extId));
                                }
                            }
                        }
                        
                        // FALLBACK: Nếu không map được, dùng tất cả IDs từ scope
                        if (successSfIds.isEmpty() && successRecords != null && !successRecords.isEmpty()) {
                            for (SObject record : scope) {
                                successSfIds.add(String.valueOf(record.get('Id')));
                            }
                        }
                        
                        log.Records__c = JSON.serialize(successSfIds);
                        log.FEC_Bix_Is_Success__c = true;
                        resultLogs.add(log);
                        return resultLogs;
                    }
                    
                    if (totalFailed > 0) {
                        Map<String, String> extIdToSfId = new Map<String, String>();
                        Map<String, String> sfIdToExtId = new Map<String, String>(); // Reverse map
                        
                        for (SObject record : scope) {
                            // Ưu tiên FEC_ID_Search__c làm external ID, fallback sang Salesforce Id
                            String extId = null;
                            try {
                                extId = (String) record.get('FEC_ID_Search__c');
                            } catch (Exception e) {
                                // Field không tồn tại trên object này → dùng Id
                            }
                            String sfId = String.valueOf(record.get('Id'));
                            
                            if (extId != null) {
                                extIdToSfId.put(extId, sfId);
                                sfIdToExtId.put(sfId, extId);
                            } else {
                                // Fallback: dùng Salesforce Id làm key mapping
                                extIdToSfId.put(sfId, sfId);
                            }
                        }

                        List<Object> failedRecords = (List<Object>) data.get('failedRecords');
                        Set<String> failedExtIds = new Set<String>();
                        if (failedRecords != null) {
                            for (Object fr : failedRecords) {
                                Map<String, Object> frMap = (Map<String, Object>) fr;
                                String recordId = (String) frMap.get('recordId');
                                if (recordId != null) failedExtIds.add(recordId);
                            }
                        }

                        List<Object> successRecords = (List<Object>) data.get('successRecords');
                        List<String> successSfIds = new List<String>();
                        if (successRecords != null) {
                            for (Object sr : successRecords) {
                                String extId = (String) sr;
                                if (extIdToSfId.containsKey(extId)) {
                                    successSfIds.add(extIdToSfId.get(extId));
                                }
                            }
                        }

                        List<String> failedSfIds = new List<String>();
                        Set<String> unmappedFailedIds = new Set<String>(); // Track IDs không map được
                        
                        for (String extId : failedExtIds) {
                            if (extIdToSfId.containsKey(extId)) {
                                failedSfIds.add(extIdToSfId.get(extId));
                            } else {
                                unmappedFailedIds.add(extId); // Không tìm thấy mapping
                            }
                        }
                        
                        // FALLBACK: Nếu không map được, dùng scope IDs trừ đi success
                        if (failedSfIds.isEmpty() && !failedExtIds.isEmpty()) {
                            // Tạo Set của successSfIds để loại trừ nhanh
                            Set<String> successSet = new Set<String>(successSfIds);
                            for (SObject record : scope) {
                                String sfId = String.valueOf(record.get('Id'));
                                if (!successSet.contains(sfId)) {
                                    failedSfIds.add(sfId);
                                }
                            }
                        }
                        
                        // FALLBACK cấp 2: Nếu cả success và fail đều không map được
                        // Dùng totalSuccess và totalFailed để phân bổ
                        if (successSfIds.isEmpty() && failedSfIds.isEmpty() && scope != null && !scope.isEmpty()) {
                            Integer successCount = 0;
                            for (SObject record : scope) {
                                String sfId = String.valueOf(record.get('Id'));
                                if (successCount < totalSuccess) {
                                    successSfIds.add(sfId);
                                    successCount++;
                                } else {
                                    failedSfIds.add(sfId);
                                }
                            }
                        }

                        Boolean isReCall = log.Id != null;

                        if (isReCall) {
                            log.Records__c = JSON.serialize(failedSfIds);
                            log.FEC_Bix_Is_Success__c = false;
                            log.FEC_Response_Data__c = truncatedRes;
                            resultLogs.add(log);

                            if(!successSfIds.isEmpty()){ 
                                FEC_integration_service_log__c successLog = new FEC_integration_service_log__c();
                                successLog.FEC_Custom_Sync__c = log.FEC_Custom_Sync__c;
                                successLog.FEC_Quantity_Call__c = 1;
                                successLog.FEC_Endpoint__c = log.FEC_Endpoint__c;
                                successLog.FEC_Method__c = log.FEC_Method__c;
                                successLog.FEC_Request_Data__c = log.FEC_Request_Data__c;
                                successLog.FEC_Response_Data__c = truncatedRes;
                                successLog.FEC_Status_Code__c = log.FEC_Status_Code__c;
                                successLog.Records__c = JSON.serialize(successSfIds);
                                successLog.FEC_Bix_Is_Success__c = true;
                                resultLogs.add(successLog);
                            }
                        } else {
                            if (!successSfIds.isEmpty()) {
                                log.Records__c = JSON.serialize(successSfIds);
                                log.FEC_Bix_Is_Success__c = true;
                                resultLogs.add(log);

                                FEC_integration_service_log__c failLog = new FEC_integration_service_log__c();
                                failLog.FEC_Custom_Sync__c = log.FEC_Custom_Sync__c;
                                failLog.FEC_Quantity_Call__c = log.FEC_Quantity_Call__c;
                                failLog.FEC_Endpoint__c = log.FEC_Endpoint__c;
                                failLog.FEC_Method__c = log.FEC_Method__c;
                                failLog.FEC_Request_Data__c = log.FEC_Request_Data__c;
                                failLog.FEC_Response_Data__c = truncatedRes;
                                failLog.FEC_Status_Code__c = log.FEC_Status_Code__c;
                                failLog.Records__c = JSON.serialize(failedSfIds);
                                failLog.FEC_Bix_Is_Success__c = false;
                                resultLogs.add(failLog);
                            } else {
                                log.Records__c = JSON.serialize(failedSfIds);
                                log.FEC_Bix_Is_Success__c = false;
                                resultLogs.add(log);
                            }
                        }
                        return resultLogs;
                    }
                }
            }

        } catch (Exception e) {   
            log.FEC_Status_Code__c = '500'; 
            String errorMsg = 'Exception: FEC_CustomSyncCallout Line: ' + e.getLineNumber() + ' - ' + e.getMessage();
            log.FEC_Error_Message__c = errorMsg.length() > 255 ? errorMsg.substring(0, 255) : errorMsg;
            log.FEC_Bix_Is_Success__c = false;
            // Records__c đã được set ở đầu hàm với toàn bộ scope (failed)
            System.debug(errorMsg);
        }
        
        // FALLBACK CUỐI CÙNG: Nếu không có log nào được tạo, trả về log mặc định với toàn bộ scope (failed)
        if (resultLogs.isEmpty()) {
            resultLogs.add(log);
        }
        return resultLogs;
    } 

    private static String toJson(FEC_Custom_Sync__c cus, List<SObject> scope, Map<Id, Map<String, Object>> mapDynamicData) {
        
        // TỰ ĐỘNG FIX LỖI "V" CODE 86 & DỌN DẸP DẤU NGOẶC KÉP LỖI TỪ CSV IMPORT
        String cleanMappingStr = String.isNotBlank(cus.FEC_Request_Body_Mapping__c) ? cus.FEC_Request_Body_Mapping__c.replace('""', '"') : '{}';
        String cleanDataTypeStr = String.isNotBlank(cus.FEC_Mapping_Data_Type__c) ? cus.FEC_Mapping_Data_Type__c.replace('""', '"') : '{}';
        String cleanStaticMapStr = String.isNotBlank(cus.FEC_Static_Map_Value__c) ? cus.FEC_Static_Map_Value__c.replace('""', '"') : '{}';

        Map<String, Object> mapping = (Map<String, Object>) JSON.deserializeUntyped(cleanMappingStr);
        Map<String, Object> dataTypeMap = (Map<String, Object>) JSON.deserializeUntyped(cleanDataTypeStr);
        Map<String, Object> staticMap = (Map<String, Object>) JSON.deserializeUntyped(cleanStaticMapStr);
        
        List<Map<String, Object>> mappedRecords = new List<Map<String, Object>>();

        for (SObject record : scope) {
            Map<String, Object> row = new Map<String, Object>();
            Id recordId = (Id) record.get('Id');

            for (String jsonKey : mapping.keySet()) {
                Object mappingVal = mapping.get(jsonKey);
                Object rawValue;

                if (mappingVal == null) {
                    rawValue = null;
                } else if (mappingVal instanceof Map<String, Object>) {
                    // XỬ LÝ NHỮNG FIELD MAPPING LÀ OBJECT TỪ DYNAMIC SOQL
                    if (mapDynamicData != null && mapDynamicData.containsKey(recordId) && mapDynamicData.get(recordId).containsKey(jsonKey)) {
                        rawValue = mapDynamicData.get(recordId).get(jsonKey);
                    } else {
                        rawValue = null;
                    }
                } else if (mappingVal instanceof String && ((String) mappingVal).endsWith('__g')) {
                    String staticKey = (String) mappingVal;
                    rawValue = staticMap.containsKey(staticKey) ? staticMap.get(staticKey) : null;
                } else if (mappingVal instanceof String && (String) mappingVal == 'DateTimeNow') {
                    rawValue = System.now();
                } else if (mappingVal instanceof String) {
                    rawValue = getFieldValue(record, (String) mappingVal);
                } else {
                    rawValue = mappingVal;
                }

                String targetType = dataTypeMap.containsKey(jsonKey) 
                    ? String.valueOf(dataTypeMap.get(jsonKey)).toUpperCase() 
                    : null;
                
                if (mappingVal instanceof String || mappingVal instanceof Map<String, Object>) {
                    row.put(jsonKey, castValue(rawValue, targetType));
                } else {
                    row.put(jsonKey, rawValue);
                }
            }
            mappedRecords.add(row);
        }

        Map<String, Object> finalWrapper = new Map<String, Object>();
        finalWrapper.put('tableName', cus.FEC_Table_Name__c);
        finalWrapper.put('records', mappedRecords);
        return JSON.serialize(finalWrapper);
    }

   private static Object castValue(Object rawValue, String targetType) {
        if (rawValue == null || String.isBlank(targetType)) {
            return rawValue;
        }
        try {
            if (targetType == 'NUMBER') {
                if (rawValue instanceof Decimal) return rawValue;
                return Decimal.valueOf(String.valueOf(rawValue));
                
            } else if (targetType == 'DATE') {
                // [TÍNH NĂNG MỚI]: Chuyển format thành YYYYMMDD
                if (rawValue instanceof Datetime) {
                    return ((Datetime) rawValue).formatGmt('yyyyMMdd');
                } else if (rawValue instanceof Date) {
                    Date d = (Date) rawValue;
                    // Tạo Datetime theo giờ GMT để khi format không bị lùi ngày do Timezone
                    Datetime dt = Datetime.newInstanceGmt(d.year(), d.month(), d.day());
                    return dt.formatGmt('yyyyMMdd');
                } else {
                    // Nếu dữ liệu đang là String (vd: "2026-06-15"), cố gắng parse nó
                    try {
                        Date d = Date.valueOf(String.valueOf(rawValue));
                        Datetime dt = Datetime.newInstanceGmt(d.year(), d.month(), d.day());
                        return dt.formatGmt('yyyyMMdd');
                    } catch (Exception e) {
                        return String.valueOf(rawValue); // Trả về nguyên gốc nếu parse thất bại
                    }
                }
                
            } else if (targetType.startsWith('TIMESTAMP')) {
                if (rawValue instanceof Datetime) return ((Datetime) rawValue).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
                if (rawValue instanceof Date) return Datetime.newInstance((Date) rawValue, Time.newInstance(0,0,0,0)).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
                return String.valueOf(rawValue);
                
            } else {
                // Các kiểu khác như VARCHAR2 (String)
                return String.valueOf(rawValue);
            }
        } catch (Exception e) {
            return String.valueOf(rawValue);
        }
    }

    private static Object getFieldValue(SObject record, String fieldPath) {
        if (record == null || String.isBlank(fieldPath)) return null;
        List<String> parts = fieldPath.split('\\.');
        SObject current = record;
        for (Integer i = 0; i < parts.size() - 1; i++) {
            if (current == null) return null;
            current = current.getSObject(parts[i]);
        }
        if (current == null) return null;
        return current.get(parts[parts.size() - 1]);
    }
}