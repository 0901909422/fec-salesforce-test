public without sharing class FEC_LogApiQueueable implements Queueable {

    String apiName;
    String endpoint;
    String method;
    String requestBody;
    Boolean isSuccess;
    String errorMessage;
    String statusCode;
    String responseBody;

    public FEC_LogApiQueueable(String apiName, String endpoint, String method, String requestBody, Boolean isSuccess, String statusCode, String errorMessage, String responseBody) {
        this.apiName = apiName;
        this.endpoint = endpoint;
        this.method = method;
        this.requestBody = requestBody;
        this.isSuccess = isSuccess;
        this.statusCode = statusCode;
        this.errorMessage = errorMessage;
        this.responseBody = responseBody;
    }

    public void execute(QueueableContext context) {
        try {
            FEC_API_Log__c log = new FEC_API_Log__c();

            log.Name = apiName;
            log.FEC_Endpoint__c = endpoint;
            log.FEC_Method__c = method;
            log.FEC_Request_String__c = requestBody;
            log.FEC_Status_Code__c =  statusCode;
            log.FEC_Response_String__c = responseBody;
            log.FEC_Is_Success__c = isSuccess;
            log.FEC_Error_Message__c = errorMessage;

            insert log;

        } catch(Exception e) {
            System.debug('LOG INSERT ERROR: ' + e.getMessage());
        }
    }
}