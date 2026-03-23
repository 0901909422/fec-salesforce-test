public class FEC_GetCallingListResultBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {

    // 1. Hàm Start: Lấy dữ liệu theo điều kiện
    public Database.QueryLocator start(Database.BatchableContext BC) {
        String dayOfWeek = Datetime.now().format('EEEE');
        
        String query = 'SELECT Id, FEC_AppId__c, FEC_AccountOrContractNumber__c, FEC_ProductLine__c, ' +
                       'FEC_Number1__c, FEC_Number2__c, FEC_Number3__c, FEC_Number4__c, FEC_Number5__c, ' +
                       'FEC_String1__c, FEC_String2__c, FEC_String3__c, FEC_String4__c, FEC_String5__c, ' +
                       'FEC_DateTime1__c, FEC_DateTime2__c, FEC_DateTime3__c, ' +
                       'FEC_RecordId__c, FEC_RecordStatus__c, FEC_RecordLifetime__c, FEC_RecordCurrentLifetime__c, ' +
                       'FEC_MaxCallAttempt__c, FEC_CurrentCallAttempt__c, FEC_CampaignCallingList__c, FEC_SystemName__c, ' +
                       'CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name, ' +
                       'FEC_CS_Campaign__r.FEC_Campaign__r.FEC_CampaignId__c, ' +
                       'FEC_CS_Campaign__r.FEC_ScheduleCampaign__c, ' +
                       'FEC_CS_Campaign__r.FEC_SaturdaySchedule__c, ' +
                       'FEC_CS_Campaign__r.FEC_SundaySchedule__c ' +
                       'FROM FEC_DataCampaign__c ' +
                       'WHERE (NOT FEC_RecordStatus__c LIKE \'Resolved-%\')' + 
                       'AND FEC_CS_Campaign__r.FEC_ScheduleCampaign__c = true ' + 
                       'AND FEC_IsWithinLifetime__c = true '; 

        if (dayOfWeek == 'Saturday') {
            query += 'AND FEC_CS_Campaign__r.FEC_SaturdaySchedule__c = true ';
        } else if (dayOfWeek == 'Sunday') {
            query += 'AND FEC_CS_Campaign__r.FEC_SundaySchedule__c = true ';
        }
        
        return Database.getQueryLocator(query);
    }

    // 2. Hàm Execute: Xử lý Callout và Update dữ liệu
    public void execute(Database.BatchableContext BC, List<FEC_DataCampaign__c> scope) {
        Set<String> accountSet = new Set<String>();
        for (FEC_DataCampaign__c rec : scope) {
            if (String.isNotBlank(rec.FEC_AccountOrContractNumber__c)) {
                accountSet.add(rec.FEC_AccountOrContractNumber__c);
            }
        }

        if (accountSet.isEmpty()) return;

        // Build Request Body
        Map<String, Object> requestPayload = new Map<String, Object>{
            'accountOrContractNumbers' => new List<String>(accountSet)
        };
        
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();

            request.setEndpoint('callout:Your_Service_API/get-calling-list-result'); 
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setBody(JSON.serialize(requestPayload));

            HttpResponse response = http.send(request);

            if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                ApiResponseWrapper responseWrapper = (ApiResponseWrapper) JSON.deserialize(response.getBody(), ApiResponseWrapper.class);
                
                if (responseWrapper.status != 'OK' || responseWrapper.data == null) {
                    System.debug('API returned Error or Empty Data: ' + responseWrapper.message);
                    return;
                }

                Map<String, ApiRecordData> responseMap = new Map<String, ApiRecordData>();
                for (ApiRecordData apiRec : responseWrapper.data) {
                    if (String.isNotBlank(apiRec.accountOrContractNumber)) {
                        responseMap.put(apiRec.accountOrContractNumber, apiRec);
                    }
                }

                List<FEC_DataCampaign__c> recordsToUpdate = new List<FEC_DataCampaign__c>();

                for (FEC_DataCampaign__c rec : scope) {
                    if (responseMap.containsKey(rec.FEC_AccountOrContractNumber__c)) {
                        ApiRecordData apiData = responseMap.get(rec.FEC_AccountOrContractNumber__c);
                        Boolean needsUpdate = false;

                        if (String.isNotBlank(apiData.callResult)) {
                            rec.FEC_AgentID__c = apiData.agentId;

                            if (String.isNotBlank(apiData.attempt)) rec.FEC_Attempt__c = Decimal.valueOf(apiData.attempt);

                            if (String.isNotBlank(apiData.callResult)) rec.FEC_CallResult__c = Decimal.valueOf(apiData.callResult);

                            if (String.isNotBlank(apiData.callTime)) {
                                rec.FEC_CallTime__c = (DateTime)JSON.deserialize('"' + apiData.callTime + '"', DateTime.class);
                            }

                            String newStatus = evaluateCallStatus(apiData.callResult);
                            rec.FEC_CallStatus__c = newStatus;
                            
                            if (newStatus == 'Resolved-Cancelled') {
                                rec.FEC_RecordStatus__c = newStatus;
                            }
                            
                            needsUpdate = true;
                        }

                        if (needsUpdate) {
                            recordsToUpdate.add(rec);
                        }
                    }
                }

                if (!recordsToUpdate.isEmpty()) {
                    update recordsToUpdate;
                }
            } else {
                System.debug('Callout Failed: ' + response.getStatusCode() + ' ' + response.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception in FEC_GetCallingListResultBatch: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('--- FEC_GetCallingListResultBatch hoàn tất ---');
    }

    private String evaluateCallStatus(String callResult) {
        if (String.isBlank(callResult)) {
            return 'Pending-Retry'; 
        }

        switch on callResult {
            when '33', '9' {
                return 'Resolved-Completed';
            }
            when '52', '51' {
                return 'Resolved-Cancelled';
            }
            when '47', '48', '4' {
                return 'Pending-callback';
            }
            when '21', '6', '3', '7', '32', '46', '28' {
                return 'Pending-Retry';
            }
            when else {
                return 'Pending-Retry'; 
            }
        }
    }

    public class ApiResponseWrapper {
        public List<ApiRecordData> data;
        public String status;
        public String message;
    }

    public class ApiRecordData {
        public String recordId;
        public String accountOrContractNumber;
        public String callTime;
        public String attempt;
        public String agentId;
        public String callResult;
    }
}