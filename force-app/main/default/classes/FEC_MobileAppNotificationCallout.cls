public with sharing class FEC_MobileAppNotificationCallout {

    public static final String API_CHECK_EXIST_USER = 'FEC_CheckExistUser';
    public static final String API_PUSH_NOTIFICATION = 'FEC_PushNotification';

    public static FEC_ResponseLog responseLogCheckUserExist = null;
    public static FEC_ResponseLog responseLogPushNotification = null;

    // =========================================================================
    // Response DTO For API_CHECK_EXIST_USER
    // =========================================================================
    public class CheckUserResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Integer httpStatusCode;

        @AuraEnabled public String code;
        @AuraEnabled public String dateTimeValue;
        @AuraEnabled public String description;
        @AuraEnabled public String transId;

        @AuraEnabled public Boolean isCustomerExist;
        @AuraEnabled public String rawResponse;
    }

    // =========================================================================
    // Request DTO For API_PUSH_NOTIFICATION
    // =========================================================================
    public class SendNotificationRequest {
        @AuraEnabled public String Content;
        @AuraEnabled public String NationalID;
        @AuraEnabled public String PhoneNumber;
        @AuraEnabled public String Title;
        @AuraEnabled public String Event_Source;
        @AuraEnabled public String Event_Name;
    }

    // =========================================================================
    // Response DTO For API_PUSH_NOTIFICATION
    // =========================================================================
    public class SendNotificationResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Integer httpStatusCode;

        @AuraEnabled public String code;
        @AuraEnabled public String dateTimeValue;
        @AuraEnabled public String description;
        @AuraEnabled public String transId;

        @AuraEnabled public Boolean isSentSuccess;
        @AuraEnabled public String rawResponse;
    }

    // =========================================================================
    // API 1: Check customer exist on Mobile App
    // =========================================================================
    @AuraEnabled
    public static CheckUserResponse checkUserExist(String phoneNumber, String nationalId) {
        String endpoint = buildEndpoint(API_CHECK_EXIST_USER)
            + '?PhoneNumber=' + EncodingUtil.urlEncode(normalizeVietnamPhone(phoneNumber), 'UTF-8')
            + '&NationalID=' + EncodingUtil.urlEncode(nationalId, 'UTF-8');

        String transId = FEC_CommonUltils.generateTransactionUUID();
        String currentDateTime = FEC_CommonUltils.formatTimestamp(
            Datetime.now(),
            FEC_ConstantCommon.STR_DATETIME_FORMAT_Z
        );

        Map<String, String> headers = new Map<String, String>{
            'TransID'     => transId,
            'DateTime'    => currentDateTime,
            'RequestorID' => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN
        };

        try {
            HttpResponse res = sendRequest(
                endpoint,
                FEC_ConstantCommon.API_METHOD_GET,
                headers,
                null
            );

            responseLogCheckUserExist = new FEC_ResponseLog(
                API_CHECK_EXIST_USER,
                endpoint,
                FEC_ConstantCommon.API_METHOD_GET,
                FEC_ConstantCommon.API_BLANK_BODY,
                res,
                null
            );
            logApiResponse(responseLogCheckUserExist);
            responseLogCheckUserExist = null;

            return parseCheckUserResponse(res);

        } catch (Exception ex) {
            HttpResponse errorRes = buildErrorHttpResponse(ex);

            responseLogCheckUserExist = new FEC_ResponseLog(
                API_CHECK_EXIST_USER,
                endpoint,
                FEC_ConstantCommon.API_METHOD_GET,
                FEC_ConstantCommon.API_BLANK_BODY,
                errorRes,
                buildErrorMessage(ex)
            );
            logApiResponse(responseLogCheckUserExist);
            responseLogCheckUserExist = null;

            CheckUserResponse result = new CheckUserResponse();
            result.success = false;
            result.httpStatusCode = 599;
            result.rawResponse = ex.getMessage();
            result.description = 'CALLOUT_ERROR';
            result.isCustomerExist = false;
            return result;
        }
    }

    // =========================================================================
    // API 2: Push notification to Mobile App
    // =========================================================================
    @AuraEnabled
    public static SendNotificationResponse sendNotification(
        String content,
        String nationalId,
        String phoneNumber,
        String title
    ) {
        String endpoint = buildEndpoint(API_PUSH_NOTIFICATION);

        String transId = FEC_CommonUltils.generateTransactionUUID();
        String currentDateTime = FEC_CommonUltils.formatTimestamp(
            Datetime.now(),
            FEC_ConstantCommon.STR_DATETIME_FORMAT_Z
        );

        Map<String, String> headers = new Map<String, String>{
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            'TransID'     => transId,
            'DateTime'    => currentDateTime,
            'RequestorID' => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN
        };

        SendNotificationRequest requestBody = new SendNotificationRequest();
        requestBody.Content = content;
        requestBody.NationalID = nationalId;
        requestBody.PhoneNumber = normalizeVietnamPhone(phoneNumber);
        requestBody.Title = title;
        requestBody.Event_Source = 'pega_csm';
        requestBody.Event_Name = 'pega_csm_support';

        String payload = JSON.serialize(requestBody);

        try {
            HttpResponse res = sendRequest(
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                headers,
                payload
            );

            responseLogPushNotification = new FEC_ResponseLog(
                API_PUSH_NOTIFICATION,
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                payload,
                res,
                null
            );
            logApiResponse(responseLogPushNotification);
            responseLogPushNotification = null;

            return parseSendNotificationResponse(res);

        } catch (Exception ex) {
            HttpResponse errorRes = buildErrorHttpResponse(ex);

            responseLogPushNotification = new FEC_ResponseLog(
                API_PUSH_NOTIFICATION,
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                payload,
                errorRes,
                buildErrorMessage(ex)
            );
            logApiResponse(responseLogPushNotification);
            responseLogPushNotification = null;

            SendNotificationResponse result = new SendNotificationResponse();
            result.success = false;
            result.httpStatusCode = 599;
            result.rawResponse = ex.getMessage();
            result.description = 'CALLOUT_ERROR';
            result.isSentSuccess = false;
            return result;
        }
    }

    // =========================================================================
    // Build endpoint from Custom Setting + Custom Metadata
    // =========================================================================
    private static String buildEndpoint(String apiName) {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(apiName);
        return apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c;
    }

    // =========================================================================
    // Send HTTP request
    // =========================================================================
    private static HttpResponse sendRequest(
        String endpoint,
        String method,
        Map<String, String> headers,
        String body
    ) {
        return FEC_CommonUltils.calloutApiWithHeaders(
            endpoint,
            method,
            headers,
            body
        );
    }

    // =========================================================================
    // Parse response: Check user exist
    // =========================================================================
    private static CheckUserResponse parseCheckUserResponse(HttpResponse res) {
        CheckUserResponse result = new CheckUserResponse();

        result.httpStatusCode = res.getStatusCode();
        result.rawResponse = res.getBody();
        result.success = res.getStatusCode() >= 200 && res.getStatusCode() < 300;

        if (String.isBlank(res.getBody())) {
            return result;
        }

        Map<String, Object> body =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        result.code = (String) body.get('Code');
        result.dateTimeValue = (String) body.get('DateTime');
        result.description = (String) body.get('Description');
        result.transId = (String) body.get('TransID');

        result.isCustomerExist =
            result.success
            && result.code == '1'
            && result.description == 'CUSTOMER_EXIST';

        return result;
    }

    // =========================================================================
    // Parse response: Push notification
    // =========================================================================
    private static SendNotificationResponse parseSendNotificationResponse(HttpResponse res) {
        SendNotificationResponse result = new SendNotificationResponse();

        result.httpStatusCode = res.getStatusCode();
        result.rawResponse = res.getBody();
        result.success = res.getStatusCode() >= 200 && res.getStatusCode() < 300;

        if (String.isBlank(res.getBody())) {
            return result;
        }

        Map<String, Object> body =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        result.code = (String) body.get('Code');
        result.dateTimeValue = (String) body.get('DateTime');
        result.description = (String) body.get('Description');
        result.transId = (String) body.get('TransID');

        result.isSentSuccess =
            result.success
            && result.code == '1'
            && result.description == 'SUCCESS';

        return result;
    }

    // =========================================================================
    // Normalize Vietnam phone
    // 84971953842  -> 0971953842
    // +84971953842 -> 0971953842
    // 0971953842   -> 0971953842
    // =========================================================================
    public static String normalizeVietnamPhone(String phoneNumber) {
        if (String.isBlank(phoneNumber)) {
            return phoneNumber;
        }

        return phoneNumber.replaceAll(
            '^(?:\\+?84)(?=[1-9]\\d{8,9}$)',
            '0'
        );
    }

    // =========================================================================
    // Log API response
    // =========================================================================
    private static void logApiResponse(FEC_ResponseLog responseLog) {
        if (responseLog == null) {
            return;
        }

        FEC_CommonUltils.logApi(
            responseLog.apiName,
            responseLog.endpoint,
            responseLog.method,
            responseLog.requestBody,
            responseLog.response,
            responseLog.errorMessage
        );
    }

    private static HttpResponse buildErrorHttpResponse(Exception ex) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(599);
        res.setStatus('Callout Exception');
        res.setBody(buildErrorMessage(ex));
        return res;
    }

    private static String buildErrorMessage(Exception ex) {
        return ex.getTypeName()
            + ': '
            + ex.getMessage()
            + '\n'
            + ex.getStackTraceString();
    }
}