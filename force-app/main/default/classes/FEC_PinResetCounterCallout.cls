public without sharing class FEC_PinResetCounterCallout {

    private static ResponseLog responseLog;

    private static final String API_NAME        = 'FEC_PinResetCounter';
    private static final String REQUESTOR_ID    = 'CSM';

    // ============================================================
    // RESPONSE CLASSES
    // ============================================================
    public class PinResetCounterResponse {
        public String AccountNumber;
        public String CardNumber;
        public String pxObjClass;
        public Sys    Sys;

        public String errorCode;
        public String errorMessage;
    }

    public class Sys {
        public String Code;
        public String Description;
        public String pxObjClass;
        public String RequestDateTime;
        public String TransID;
    }

    // ============================================================
    // VALIDATION CLASS
    // ============================================================
    public class ValidationResult {

        public Boolean isValid;
        public String  errorMessage;

        public ValidationResult(Boolean isValid, String errorMessage) {
            this.isValid      = isValid;
            this.errorMessage = errorMessage;
        }
    }

    // ============================================================
    // RESPONSE LOG CLASS
    // ============================================================
    public class ResponseLog {
        public String       apiName;
        public String       endpoint;
        public String       method;
        public String       requestBody;
        public HttpResponse response;
        public String       errorMessage;

        public ResponseLog(
            String apiName,
            String endpoint,
            String method,
            String requestBody,
            HttpResponse response,
            String errorMessage
        ) {
            this.apiName      = apiName;
            this.endpoint     = endpoint;
            this.method       = method;
            this.requestBody  = requestBody;
            this.response     = response;
            this.errorMessage = errorMessage;
        }
    }

    // ============================================================
    // MAIN CALLOUT METHOD
    // ============================================================

    /**
     * Gọi API PinResetCounter (API #58) — POST /CmsCardExt/PinResetCounter.
     *
     * Tham số isTestApi được giữ trong signature để nhất quán với các callout class khác,
     * nhưng không ảnh hưởng đến data gửi đi — luôn dùng real data từ input.
     *
     * @param last4CardNumber  4 chữ số cuối số thẻ (trích xuất từ Case.FEC_Account_or_Contract__r.FEC_Card_Number__c)
     * @param transId          GUID duy nhất cho transaction
     * @param accountNumber    Số tài khoản đầy đủ (Case.FEC_Account_Number__c)
     * @param isTestApi        Không dùng để routing data; giữ để tương thích interface
     */
    public static PinResetCounterResponse callPinResetCounter(
        String  last4CardNumber,
        String  transId,
        String  accountNumber,
        Boolean isTestApi
    ) {
        PinResetCounterResponse response = new PinResetCounterResponse();
        String endpoint = '';
        String requestJson = '';

        try {
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_NAME);

            String dateTimeStr = Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_XXX);

            // Build endpoint
            endpoint = FEC_CommonUltils.buildCalloutEndpoint(
                apiSetting?.FEC_Endpoint__c,
                apiConfig?.FEC_Endpoint__c
            );

            // Build headers
            Map<String, String> headers = new Map<String, String>{
                'TransID'      => transId,
                'DateTime'     => dateTimeStr,
                'RequestorID'  => REQUESTOR_ID,
                'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
            };

            // Build body — luôn dùng real data từ input
            Map<String, String> bodyMap = new Map<String, String>{
                '4LastCardNumber' => last4CardNumber,
                'AccountNumber'   => accountNumber
            };
            requestJson = JSON.serialize(bodyMap);

            HttpResponse res = FEC_CommonUltils.calloutApiWithHeaders(
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                headers,
                requestJson
            );

            // Log response (luôn set, dù thành công hay thất bại)
            responseLog = new ResponseLog(
                API_NAME,
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                requestJson,
                res,
                null
            );

            if (res.getStatusCode() == 200) {
                response = (PinResetCounterResponse) JSON.deserialize(
                    res.getBody(),
                    PinResetCounterResponse.class
                );
            } else {
                response.errorCode    = String.valueOf(res.getStatusCode());
                response.errorMessage = res.getBody();
            }

        } catch (Exception e) {
            response.errorCode    = 'CALLOUT_ERROR';
            response.errorMessage = e.getMessage();

            // Đảm bảo responseLog luôn được set kể cả khi exception xảy ra trước khi res có giá trị
            if (responseLog == null) {
                responseLog = new ResponseLog(
                    API_NAME,
                    endpoint,
                    FEC_ConstantCommon.API_METHOD_POST,
                    requestJson,
                    null,
                    e.getMessage()
                );
            }
        }

        return response;
    }

    // ============================================================
    // SUCCESS CHECK
    // ============================================================

    /**
     * Trả về true khi Sys.Code == '1' (PIN_RESET_COUNTER_SUCCESS).
     */
    public static Boolean isSuccess(PinResetCounterResponse response) {
        return response != null
            && response.Sys != null
            && response.Sys.Code == '1';
    }

    // ============================================================
    // VALIDATE REQUEST
    // ============================================================

    public static ValidationResult validateRequest(
        String last4CardNumber,
        String transId,
        String accountNumber
    ) {
        if (String.isBlank(transId)) {
            return new ValidationResult(false, System.Label.FEC_MSG_TransID_Null);
        }

        if (String.isBlank(last4CardNumber)) {
            return new ValidationResult(
                false,
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Last4CardNumber' })
            );
        }

        if (String.isBlank(accountNumber)) {
            return new ValidationResult(
                false,
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Account Number' })
            );
        }

        return new ValidationResult(true, null);
    }

    // ============================================================
    // LOGGING
    // ============================================================

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
