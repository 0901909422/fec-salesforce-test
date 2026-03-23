public class FEC_CheckCampaignStatusBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, FEC_RecordId__c, FEC_RecordStatus__c ' +
                       'FROM FEC_DataCampaign__c ' +
                       'WHERE FEC_IsPushed__c = true ' +
                       'AND FEC_SendToCommsDB__c = null ' +
                       'AND FEC_RecordStatus__c = \'New\''; 
        
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<FEC_DataCampaign__c> scope) {
        List<String> listRecordIds = new List<String>();
        
        for (FEC_DataCampaign__c record : scope) {
            if (String.isNotBlank(record.FEC_RecordId__c)) {
                listRecordIds.add(record.FEC_RecordId__c);
            }
        }

        if (listRecordIds.isEmpty()) {
            return;
        }

        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            
            request.setEndpoint('callout:Your_Named_Credential/api/v1/check-status'); 
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            
            Map<String, Object> payload = new Map<String, Object>{
                'recordIds' => listRecordIds
            };
            request.setBody(JSON.serialize(payload));

            HttpResponse response = http.send(request);

            if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                try {
                    ApiResponseWrapper responseBody = (ApiResponseWrapper) JSON.deserialize(response.getBody(), ApiResponseWrapper.class);
                    
                    if (responseBody.status != 'OK') {
                        System.debug('API Error: ' + responseBody.message);
                        return;
                    }
        
                    Map<String, ApiRecordData> apiResultMap = new Map<String, ApiRecordData>();
                    if (responseBody.data != null) {
                        for (ApiRecordData item : responseBody.data) {
                            apiResultMap.put(item.recordId, item);
                        }
                    }
        
                    List<FEC_DataCampaign__c> recordsToUpdate = new List<FEC_DataCampaign__c>();
        
                    for (FEC_DataCampaign__c record : scope) {
                        if (apiResultMap.containsKey(record.FEC_RecordId__c)) {
                            ApiRecordData apiData = apiResultMap.get(record.FEC_RecordId__c);
                            Boolean isChanged = false;
        
                            if (apiData.status == '1') {
                                Date insertionDateOnly;

                                if (record.FEC_InsertionDate__c != null) {
                                    insertionDateOnly = record.FEC_InsertionDate__c.date(); 
                                }

                                if (insertionDateOnly != null && insertionDateOnly < System.today()) {
                                    record.FEC_CurrentCallAttempt__c = 1;
                                }

                                record.FEC_CallbackRequested__c = '';
                                record.FEC_SendToCommsDB__c = 'Y';
                                record.FEC_InsertionDate__c = System.now();
                                record.FEC_RecordCurrentLifetime__c = record.FEC_RecordCurrentLifetime__c + 1;
                                
                                if (String.isNotBlank(apiData.csContractString)) {
                                    record.FEC_Number4__c = Decimal.valueOf(FEC_Util.getBeforeSubstring(apiData.csContractString, ''));
                                }
                                if (String.isNotBlank(apiData.idiDocNbr)) {
                                    record.FEC_Number5__c = Decimal.valueOf(apiData.idiDocNbr);
                                }
                                isChanged = true;
                                
                            } else if (apiData.status == '-1') {
                                record.FEC_RecordStatus__c = 'Failed';
                                isChanged = true;
                                
                            }

                            if (isChanged) {
                                recordsToUpdate.add(record);
                            }
                        }
                    }
        
                    if (!recordsToUpdate.isEmpty()) {
                        update recordsToUpdate;
                    }
        
                } catch (Exception e) {
                    System.debug('Lỗi parse JSON hoặc xử lý dữ liệu: ' + e.getMessage() + ' tại dòng ' + e.getLineNumber());
                }
            } else {
                System.debug('Callout failed: HTTP ' + response.getStatusCode() + ' - ' + response.getBody());
            }
            
        } catch (Exception e) {
            System.debug('Exception during Callout: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('--- Job kiểm tra trạng thái Campaign đã hoàn tất ---');
    }

    public class ApiResponseWrapper {
        public List<ApiRecordData> data;
        public String status;
        public String message;
    }

    public class ApiRecordData {
        public String recordId;
        public String csContractString;
        public String idiDocNbr;
        public String status; // "1", "0", "-1"
        public String error;
    }
}