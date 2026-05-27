/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   A class for 3rd-party to call SFCMS to insert Undelivered Card
Test Class:    FEC_UndeliveredCardRestService_Test
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/05/19     Thanh Van          Init
2026/05/20     DuanNguyen          Setup Api
------------------------------------------------------------*/
@RestResource(urlMapping = '/v1/UndeliveredCard')
global without sharing class FEC_UndeliveredCardRestService { 

    public class ReturnOrderListData {
        public String requestId {get; set;}
        public String sourceSystem {get; set;}
        public String sendDateTime {get; set;}
        public List<DelayRecord> delayRecords {get; set;}
    }

    public class DelayRecord {
        public String accountNo {get; set;}
        public String phone {get; set;}
        public Integer delayCode {get; set;}
        public String delayNotes {get; set;}
        public String deliveryNotes {get; set;}
        public String trackingNo {get; set;}
        public String plasticId {get; set;}
    } 

    public class UndeliveredCardResponse {
        public String code;
        public String message;
        public String requestId;
        public Boolean isSuccessfully;
        public List<RecordResult> resultsFail;
        public List<RecordResult> resultsSuccess;

        public UndeliveredCardResponse(String code, String message) {
            this.code = code;
            this.message = message;
            this.isSuccessfully = false;
            this.resultsFail = new List<RecordResult>();
            this.resultsSuccess = new List<RecordResult>();
        }
    }

    public class RecordResult {
        public String accountNo;
        public String trackingNo;
        public String errorMessage;
        public String SFID;
    } 

    private static final String CODE_SUCCESS        = '200';
    private static final String CODE_BAD_REQUEST    = '400';
    private static final String CODE_INTERNAL_ERROR = '500'; 

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        UndeliveredCardResponse response;
        String requestBodyStr = req.requestBody?.toString();

        try { 
            ReturnOrderListData reqBody = (ReturnOrderListData) JSON.deserialize(
                requestBodyStr, ReturnOrderListData.class
            );
 
            String headerError = validateHeader(reqBody);
            if (headerError != null) {
                response = new UndeliveredCardResponse(CODE_BAD_REQUEST, headerError);
                response.requestId = reqBody?.requestId;
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(response));
                logRequest(requestBodyStr, response);
                return;
            }

            // Check duplicate requestId on FEC_Undelivered_Card__c
            List<FEC_Undelivered_Card__c> existingRecords = [
                SELECT Id
                FROM FEC_Undelivered_Card__c
                WHERE FEC_Request_ID__c = :reqBody.requestId
                LIMIT 1
            ];
            if (!existingRecords.isEmpty()) {
                response = new UndeliveredCardResponse(CODE_BAD_REQUEST, 'requestId ' + reqBody.requestId + ' already exists');
                response.requestId = reqBody.requestId;
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(response));
                logRequest(requestBodyStr, response);
                return;
            }

            Datetime receivedDt = parseSendDateTime(reqBody.sendDateTime);
  
            List<FEC_Undelivered_Card__c> recordsToInsert = new List<FEC_Undelivered_Card__c>();
            List<Integer> validIndexes = new List<Integer>();

            response = new UndeliveredCardResponse(CODE_SUCCESS, 'Request processed successfully');
            response.requestId = reqBody.requestId;

            for (Integer i = 0; i < reqBody.delayRecords.size(); i++) {
                DelayRecord record = reqBody.delayRecords[i];
                String itemError = validateItem(record, i);

                RecordResult rr = new RecordResult();
                rr.accountNo = record.accountNo;
                rr.trackingNo = record.trackingNo;

                if (itemError != null) {
                    rr.errorMessage = itemError;
                    response.resultsFail.add(rr);
                } else {
                    FEC_Undelivered_Card__c udc = new FEC_Undelivered_Card__c();
                    udc.FEC_Request_ID__c = reqBody.requestId;
                    udc.FEC_Source_System__c = reqBody.sourceSystem;
                    udc.FEC_Received_DateTime__c = receivedDt;
                    udc.FEC_Account_No__c = record.accountNo;
                    udc.FEC_Phone__c = record.phone;
                    udc.FEC_Delay_Code__c = record.delayCode;
                    udc.FEC_Delay_Notes__c = record.delayNotes;
                    udc.FEC_Delivery_Notes__c = record.deliveryNotes;
                    udc.FEC_Tracking_No__c = record.trackingNo;
                    udc.FEC_Plastic_Id__c = record.plasticId;

                    recordsToInsert.add(udc);
                    validIndexes.add(i);
                }
            }

            if (!recordsToInsert.isEmpty()) {
                List<Database.SaveResult> saveResults = Database.insert(recordsToInsert, false);

                for (Integer i = 0; i < saveResults.size(); i++) {
                    Integer originalIndex = validIndexes[i];
                    DelayRecord record = reqBody.delayRecords[originalIndex];

                    RecordResult rr = new RecordResult();
                    rr.accountNo = record.accountNo;
                    rr.trackingNo = record.trackingNo;

                    if (saveResults[i].isSuccess()) {
                        rr.SFID = saveResults[i].getId();
                        response.resultsSuccess.add(rr);
                    } else {
                        rr.errorMessage = saveResults[i].getErrors()[0].getMessage();
                        response.resultsFail.add(rr);
                    }
                }
            }

            response.isSuccessfully = response.resultsFail.isEmpty();

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(response));

        } catch (Exception e) { 
            response = new UndeliveredCardResponse(CODE_INTERNAL_ERROR, 'Internal server error: ' + e.getMessage());
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(response));
        } finally {
            logRequest(requestBodyStr, response);
        }
    }
 
    private static String validateHeader(ReturnOrderListData reqBody) {
        if (reqBody == null) {
            return 'Request body is required';
        }
        if (String.isBlank(reqBody.requestId)) {
            return String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'requestId'});
        }
        if (String.isBlank(reqBody.sourceSystem)) {
            return String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'sourceSystem'});
        }
        if (String.isBlank(reqBody.sendDateTime)) {
            return String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'sendDateTime'});
        }
        if (reqBody.delayRecords == null || reqBody.delayRecords.isEmpty()) {
            return String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'delayRecords'});
        }
        return null;
    }

    private static String validateItem(DelayRecord record, Integer index) {
        if (String.isBlank(record.accountNo)) {
            return String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'accountNo at index ' + index});
        }
        if (String.isBlank(record.trackingNo)) {
            return String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'trackingNo at index ' + index});
        }

        // Validate field lengths
        if (record.accountNo.length() > 50) {
            return String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'accountNo', '50'});
        }
        if (record.phone != null && record.phone.length() > 20) {
            return String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'phone', '20'});
        }
        if (record.delayNotes != null && record.delayNotes.length() > 300) {
            return String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'delayNotes', '300'});
        }
        if (record.deliveryNotes != null && record.deliveryNotes.length() > 100) {
            return String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'deliveryNotes', '100'});
        }
        if (record.trackingNo.length() > 50) {
            return String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'trackingNo', '50'});
        }
        if (record.plasticId != null && record.plasticId.length() > 30) {
            return String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'plasticId', '30'});
        }

        return null;
    } 
    private static Datetime parseSendDateTime(String sendDateTime) {
        if (String.isBlank(sendDateTime)) {
            return null;
        }
        try {
            // Format: YYYY-MM-DDThh:mm:ssZ
            String normalized = sendDateTime.replace('T', ' ').replace('Z', '');
            return Datetime.valueOfGmt(normalized);
        } catch (Exception e) {
            System.debug('FEC_DEBUG parseSendDateTime error: ' + e.getMessage());
            return null;
        }
    }
 
    private static void logRequest(String requestBodyStr, UndeliveredCardResponse response) {
        try {
            String resBody = response != null ? JSON.serialize(response) : '';
            String resCode = response != null ? response.code : '';
            FEC_IntegrationFraudCaseUtil.logIntegrationService(
                'FEC_UndeliveredCardRestService',
                'UndeliveredCard',
                '',
                '',
                requestBodyStr,
                resBody,
                resCode,
                '',
                'Api Salesforce'
            );
        } catch (Exception e) {
            System.debug('FEC_DEBUG logRequest error: ' + e.getMessage());
        }
    }
}