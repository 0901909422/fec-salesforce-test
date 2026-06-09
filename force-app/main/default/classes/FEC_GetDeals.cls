/****************************************************************************************
 * File Name    : FEC_GetDeals
 * Author       : Quangdv7
 * Date         : 2026-03-02
 * Description  : Call API
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-03-02     Quangdv7             Create
 
****************************************************************************************/

public without sharing class FEC_GetDeals {

    private static ResponseLog responseLog;

    // ============================================================
    // REQUEST CLASSES
    // ============================================================
    public class GetDealsRequest {
        public Map<String, String> headers;
        public Map<String, Object> body;
    }

    // ============================================================
    // RESPONSE CLASSES
    // ============================================================
    public class GetDealsResponse {
        public Sys Sys;
        public Integer totalDeal;
        public Integer pageNumber;
        public Integer totalPage;
        public List<Deal> result;
        public String errorCode;
        public String errorMessage;
    }

    public class Sys {
        public String TransID;
        public String dateTimeStr;
    }

    public class Deal {
        public Integer dealId;
        public String dealName;
        public Integer categoryId;
        public String categoryName;
        public String partnercategoryId;
        public String partnerCategoryName;
        public List<Address> address;
        public Decimal originalPrice;
        public Decimal price;
        public String startDate;
        public String expiredDate;
        public String avatar;
        public String brandId;
        public String brandName;
        public Integer status;
        public Integer dealType;
        public Boolean isIdentification;
        public String lastChanged;
    }

    public class Address {
        public Integer id;
        public String name;
        public String address;
        public Decimal latitude;
        public Decimal longitude;
        public Integer locationId;
        public String locationName;
    }

    // ============================================================
    // VALIDATION CLASS
    // ============================================================
    public class ValidationResult {
        public Boolean isValid;
        public String errorMessage;

        public ValidationResult(Boolean isValid, String errorMessage) {
            this.isValid = isValid;
            this.errorMessage = errorMessage;
        }
    }

    // ============================================================
    // RESPONSE LOG CLASS
    // ============================================================
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

    // ============================================================
    // MAIN CALLOUT METHOD
    // ============================================================
    public static GetDealsResponse callGetDeals(
        Integer pageSize,
        Integer pageNumber,
        Integer categoryId,
        Integer brandId
    ){
        GetDealsResponse response = new GetDealsResponse();

        try {
            GetDealsRequest request = new GetDealsRequest();

            request.headers = new Map<String, String>{
                'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
            };

            request.body = new Map<String, Object>{
                'pageSize' => pageSize,
                'pageNumber' => pageNumber
            };

            if (categoryId != null) {
                request.body.put('categoryId', categoryId);
            }
            if (brandId != null) {
                request.body.put('brandId', brandId);
            }

            String requestBodyJson = JSON.serialize(request.body);

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_GetDeals');

            String endpoint = apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c;

            HttpResponse res = FEC_CommonUltils.calloutApiWithHeaders(
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                request.headers,
                requestBodyJson
            );

            // // Log response
            // String requestJson = JSON.serialize(request);
            // responseLog = new ResponseLog(
            //     'FEC_GetDeals',
            //     endpoint,
            //     FEC_ConstantCommon.API_METHOD_POST,
            //     requestJson,
            //     res,
            //     null
            // );

            if (res.getStatusCode() == 200) {
                response = (GetDealsResponse) JSON.deserialize(res.getBody(), GetDealsResponse.class);
            } else {
                response.errorCode = String.valueOf(res.getStatusCode());
                response.errorMessage = res.getBody();
            }

        } catch (Exception e) {
            response.errorCode = 'CALLOUT_ERROR';
            response.errorMessage = e.getMessage();
        }

        return response;
    }

    // ============================================================
    // SUCCESS CHECK
    // ============================================================
    public static Boolean isSuccess(GetDealsResponse response){
        return response != null
            && response.errorCode == '00';
    }

    // ============================================================
    // VALIDATE REQUEST
    // ============================================================
    public static ValidationResult validateRequest(
        Integer pageSize,
        Integer pageNumber
    ){
        if (pageSize == null || pageSize <= 0) {
            return new ValidationResult(false,  System.Label.FEC_Page_Size_Deals);
        }

        if (pageNumber == null || pageNumber <= 0) {
            return new ValidationResult(false, System.label.FEC_Page_Number_Deals);
        }

        return new ValidationResult(true, null);
    }

    // // ============================================================
    // // LOG API
    // // ============================================================
    // public static void logApiResponse() {
    //     if (responseLog != null) {
    //         FEC_CommonUltils.logApi(
    //             responseLog.apiName, 
    //             responseLog.endpoint, 
    //             responseLog.method, 
    //             responseLog.requestBody, 
    //             responseLog.response, 
    //             responseLog.errorMessage
    //         );
    //     }
    // }
}