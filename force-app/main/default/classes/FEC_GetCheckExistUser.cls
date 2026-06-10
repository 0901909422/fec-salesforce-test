/****************************************************************************************
* File Name    : FEC_GetCheckExistUser
* Author       : Quangdv7
* Date         : 2026-06-10
* Description  : Get data for API service
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
   1.0      2026-06-10     Quangdv7             Create
 
****************************************************************************************/
 
public with sharing class FEC_GetCheckExistUser {

    private static ResponseLog responseLog;

    // =========================================================================
    // RESPONSE LOG
    // =========================================================================
    public class ResponseLog {
        public String apiName;
        public String endpoint;
        public String method;
        public String requestBody;
        public HttpResponse response;
        public String errorMessage;

        public ResponseLog(String apiName, String endpoint, String method, String requestBody, HttpResponse response, String errorMessage) {
            this.apiName = apiName;
            this.endpoint = endpoint;
            this.method = method;
            this.requestBody = requestBody;
            this.response = response;
            this.errorMessage = errorMessage;
        }
    }

    // =========================================================================
    // RESPONSE WRAPPER
    // =========================================================================
    public class ResponseWrapper {
        public String pxObjClass;
        public String pxResults;
        public SysResponse Sys;
        public RequestParameters RequestParams;
    }

    // =========================================================================
    // SYS
    // =========================================================================
    public class SysResponse {
        public String pxObjClass;
        public Integer Code2;
        public String Description;
        public String DateTime2;
        public String TransID;
    }

    // =========================================================================
    // REQUEST PARAMETERS
    // =========================================================================
    public class RequestParameters {
        public String NationalID;
        public String PhoneNumber;
    }

    // =========================================================================
    // PUBLIC CALL METHOD
    // =========================================================================
    public static ResponseWrapper getCheckExistUser(String phoneNumber, String nationalId) {
        return callGetCheckExistUser(phoneNumber, nationalId, false);
    }

    // =========================================================================
    // PUBLIC CALL METHOD
    // =========================================================================
    public static ResponseWrapper callGetCheckExistUser(
        String phoneNumber,
        String nationalId,
        Boolean isTestApi
    ) {
        String normalizedPhone = normalizePhoneNumber(phoneNumber);
        validateRequest(normalizedPhone, nationalId);

        if (isTestApi == true) {
            throw new CalloutException(
                String.format(
                    System.Label.FEC_MSG_API_Error,
                    new List<String>{ 'API Fail' }
                )
            );
        }

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_GetCheckExistUser');

        String endpoint = apiSetting?.FEC_Call_Mock__c == true
            ? FEC_MockupEndpoint.FEC_GET_CARD_TXN_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

        endpoint += '?PhoneNumber=' + EncodingUtil.urlEncode(normalizedPhone, 'UTF-8')
            + '&NationalID=' + EncodingUtil.urlEncode(nationalId, 'UTF-8');

        Map<String, String> headers = new Map<String, String>{
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
        };
        if (String.isNotBlank(apiConfig?.FEC_Consumer_Name__c)) {
            headers.put('Authorization', apiConfig.FEC_Consumer_Name__c);
        }

        String requestBody = JSON.serialize(new Map<String, String>{
            'PhoneNumber' => normalizedPhone,
            'NationalID' => nationalId
        });

        HttpResponse res = FEC_CommonUltils.calloutApiWithHeaders(
            endpoint,
            FEC_ConstantCommon.API_METHOD_GET,
            headers,
            null
        );

        responseLog = new ResponseLog(
            'FEC_GetCheckExistUser',
            endpoint,
            FEC_ConstantCommon.API_METHOD_GET,
            requestBody,
            res,
            null
        );

        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{ res.getStatusCode().toString() })
            );
        }

        return parseResponse(res.getBody());
    }

    // =========================================================================
    // JSON PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String jsonBody) {
        ResponseWrapper result = new ResponseWrapper();
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);

        result.pxObjClass = (String) root.get('pxObjClass');
        result.pxResults = root.containsKey('pxResults')
            ? (String) root.get('pxResults')
            : (String) root.get('pxStatus');

        Object responseGetObj = root.get('response_GET');
        if (responseGetObj != null) {
            Map<String, Object> responseGet = (Map<String, Object>) responseGetObj;
            result.Sys = new SysResponse();
            result.Sys.pxObjClass = (String) responseGet.get('pxObjClass');
            result.Sys.Code2 = toInteger(responseGet.get('Code2'));
            result.Sys.Description = (String) responseGet.get('Description');
            result.Sys.DateTime2 = (String) responseGet.get('DateTime2');
            result.Sys.TransID = (String) responseGet.get('TransID');
        }

        Object reqParamsObj = root.containsKey('pxReqParameters')
            ? root.get('pxReqParameters')
            : root.get('pxDPParameters');
        if (reqParamsObj != null) {
            Map<String, Object> reqParams = (Map<String, Object>) reqParamsObj;
            result.RequestParams = new RequestParameters();
            result.RequestParams.NationalID = (String) reqParams.get('NationalID');
            result.RequestParams.PhoneNumber = (String) reqParams.get('PhoneNumber');
        }

        return result;
    }

    // =========================================================================
    // PHONE NORMALIZATION
    // =========================================================================
    
    public static String normalizePhoneNumber(String rawPhone) {
        if (String.isBlank(rawPhone)) {
            return rawPhone;
        }

        String phone = rawPhone.replaceAll('\\s', '');
        Matcher matcher = Pattern.compile(FEC_ConstantCommon.PHONE_NORMALIZE_REGEX).matcher(phone);
        if (matcher.matches()) {
            return '0' + matcher.group(1);
        }

        return phone;
    }

    // =========================================================================
    // VALIDATION
    // =========================================================================
    private static void validateRequest(
        String phoneNumber,
        String nationalId
    ) {
        if (String.isBlank(phoneNumber)) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'PhoneNumber' })
            );
        }

        if (!Pattern.matches(FEC_ConstantCommon.PHONE_NORMALIZE_REGEX, phoneNumber.replaceAll('\\s', ''))
            && !Pattern.matches(FEC_ConstantCommon.PATTERN_PHONE_NUMBER, phoneNumber)) {
            throw new CalloutException(System.Label.FEC_MSG_Phone_Number_Invalid);
        }

        if (phoneNumber.length() > 15) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{ 'PhoneNumber', '15' })
            );
        }

        if (String.isBlank(nationalId)) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'NationalID' })
            );
        }

        if (nationalId.length() > 20) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{ 'NationalID', '20' })
            );
        }
    }

    private static Integer toInteger(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Integer) {
            return (Integer) value;
        }
        if (value instanceof Decimal) {
            return Integer.valueOf((Decimal) value);
        }
        return FEC_CommonUltils.toInt(String.valueOf(value));
    }

    public static void logApiResponse() {
        if (responseLog != null) {
            FEC_CommonUltils.logApi(
                responseLog.apiName,
                responseLog.endpoint,
                responseLog.method,
                responseLog.requestBody,
                responseLog.response,
                responseLog.errorMessage
            );
        }
    }
}
