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
    
    public static List<FEC_integration_service_log__c> sendRequest(CustomSync__c cus, FEC_integration_service_log__c log, List<SObject> scope) {
        List<FEC_integration_service_log__c> resultLogs = new List<FEC_integration_service_log__c>();
        log.FEC_Quantity_Call__c = (log.FEC_Quantity_Call__c ?? 0) + 1;
        try {   
            CustomSyncSetting__c apiSetting = CustomSyncSetting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Custom_Sync_Bix'); 

            String jsonBody = toJson(cus,scope);
            
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
                    
                    if (totalFailed > 0) {
                        // Build map: FEC_ID_Search__c -> SFID
                         Map<String, String> extIdToSfId = new Map<String, String>();
                        for (SObject record : scope) {
                            String extId = (String) record.get('FEC_ID_Search__c');
                            if (extId != null) {
                                extIdToSfId.put(extId, String.valueOf(record.get('Id')));
                            }
                        }

                        // Failed record IDs
                        List<Object> failedRecords = (List<Object>) data.get('failedRecords');
                        Set<String> failedExtIds = new Set<String>();
                        if (failedRecords != null) {
                            for (Object fr : failedRecords) {
                                Map<String, Object> frMap = (Map<String, Object>) fr;
                                String recordId = (String) frMap.get('recordId');
                                if (recordId != null) failedExtIds.add(recordId);
                            }
                        }

                        // Success record IDs
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
                        for (String extId : failedExtIds) {
                            if (extIdToSfId.containsKey(extId)) {
                                failedSfIds.add(extIdToSfId.get(extId));
                            }
                        }

                        Boolean isReCall = log.Id != null;

                        if (isReCall) {
                            // Case 2: Recall - có cả Fail và Success
                            // Giữ log gốc là fail, remove success records, FEC_Quantity_Call__c đã +1 ở trên
                            log.Records__c = JSON.serialize(failedSfIds);
                            log.FEC_Bix_Is_Success__c = false;
                            log.FEC_Response_Data__c = truncatedRes;
                            resultLogs.add(log);

                            // Tạo log MỚI cho success records
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
                            // First call
                            if (!successSfIds.isEmpty()) {
                                // Log 1: Success records
                                log.Records__c = JSON.serialize(successSfIds);
                                log.FEC_Bix_Is_Success__c = true;
                                resultLogs.add(log);

                                // Log 2: Failed records
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
                                // Tất cả đều fail, không có success record nào
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
            System.debug(errorMsg);
        }
        resultLogs.add(log);
        return resultLogs;
    } 
    private static String toJson(CustomSync__c cus, List<SObject> scope) {
        Map<String, Object> mapping = (Map<String, Object>) JSON.deserializeUntyped(cus.RequestBodyMapping__c);
        Map<String, Object> dataTypeMap = String.isNotBlank(cus.MappingDataType__c)
            ? (Map<String, Object>) JSON.deserializeUntyped(cus.MappingDataType__c)
            : new Map<String, Object>();
        List<Map<String, Object>> mappedRecords = new List<Map<String, Object>>();

        for (SObject record : scope) {
            Map<String, Object> row = new Map<String, Object>();
            for (String jsonKey : mapping.keySet()) {
                Object mappingVal = mapping.get(jsonKey);
                Object rawValue;
                if (mappingVal == null) {
                    rawValue = null;
                } else if (mappingVal instanceof String) {
                    rawValue = getFieldValue(record, (String) mappingVal);
                } else {
                    // Integer, Boolean, Decimal, etc. — dùng trực tiếp
                    rawValue = mappingVal;
                }
                String targetType = dataTypeMap.containsKey(jsonKey) 
                    ? ((String) dataTypeMap.get(jsonKey)).toUpperCase() 
                    : null;
                // Nếu mappingVal không phải String (hardcode value) thì không cần cast
                if (mappingVal instanceof String) {
                    row.put(jsonKey, castValue(rawValue, targetType));
                } else {
                    row.put(jsonKey, rawValue);
                }
            }
            mappedRecords.add(row);
        }

        Map<String, Object> finalWrapper = new Map<String, Object>();
        finalWrapper.put('tableName', cus.TableName__c);
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
            } else if (targetType.startsWith('TIMESTAMP')) {
                if (rawValue instanceof Datetime) return ((Datetime) rawValue).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
                if (rawValue instanceof Date) return Datetime.newInstance((Date) rawValue, Time.newInstance(0,0,0,0)).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
                return String.valueOf(rawValue);
            } else {
                // VARCHAR2 and other string types
                return String.valueOf(rawValue);
            }
        } catch (Exception e) {
            return String.valueOf(rawValue);
        }
    }

    private static Object getFieldValue(SObject record, String fieldPath) {
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