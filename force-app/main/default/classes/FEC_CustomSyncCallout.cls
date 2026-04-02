/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Create Callout Sync Data 
Test Class:     
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/03/31     Duan Nguyen          Init
------------------------------------------------------------*/
public with sharing class FEC_CustomSyncCallout { 
    
    public static FEC_API_Log__c sendRequest(CustomSync__c cus, FEC_API_Log__c log, List<SObject> scope) {
        try {   
            CustomSyncSetting__c apiSetting = CustomSyncSetting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Custom_Sync_Bix'); 

            String jsonBody = toJson(cus,scope);
            
            log.FEC_Quantity_Call__c = (log.FEC_Quantity_Call__c ?? 0) + 1;
            log.FEC_Endpoint__c = apiSetting?.Endpoint__c + apiConfig?.FEC_Endpoint__c;
            log.FEC_Method__c = 'POST';
            log.FEC_Request_String__c = jsonBody;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(apiSetting?.Endpoint__c + apiConfig?.FEC_Endpoint__c);
            req.setMethod('POST');
            req.setTimeout(60000);
            req.setHeader('X-API-KEY', apiSetting.ApiKey__c);
            req.setHeader('Content-Type', 'application/json');  
            req.setBody(jsonBody);
            Http http = new Http();
            HttpResponse response = http.send(req); 
            
            log.FEC_Status_Code__c = String.valueOf(response.getStatusCode());
            log.FEC_Response_String__c = response.getBody();
            log.FEC_Is_Success__c =  (response.getStatusCode() == 200);

        } catch (Exception e) {   
            log.FEC_Status_Code__c = '500'; 
            String errorMsg = 'Exception: Line: ' + e.getLineNumber() + ' - ' + e.getMessage();
            log.FEC_Error_Message__c = errorMsg.length() > 255 ? errorMsg.substring(0, 255) : errorMsg;
            System.debug(errorMsg);
        }
        return log;
    } 
    private static String toJson(CustomSync__c cus,List<SObject> scope){ 
        String temporaryJson = JSON.serialize(scope);
        List<Object> cleanedRecords = (List<Object>) JSON.deserializeUntyped(temporaryJson);
 
        for (Object recordObj : cleanedRecords) {
            Map<String, Object> recordMap = (Map<String, Object>) recordObj; 
            for (String key : recordMap.keySet()) {
                Object value = recordMap.get(key); 
                if (value instanceof Map<String, Object>) {
                    Map<String, Object> childMap = (Map<String, Object>) value; 
                    childMap.remove('attributes');  
                }
            }
        } 
        Map<String, Object> finalWrapper = new Map<String, Object>();
        finalWrapper.put('tableName', cus.TableName__c);
        finalWrapper.put('records', cleanedRecords);
        return  JSON.serialize(finalWrapper);
    }
}