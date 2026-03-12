public without sharing class FEC_GetAppStatusCallout {
    
    //=============== REQUEST CLASSES ===============//
    
    public class AppStatusRequest {
        public List<String> parameters;
        public Map<String, Object> headers;
        public AppStatusRequestBody body;
    }
    
    public class AppStatusRequestBody {
        public Integer AgeOfRecords;
        public String ApplicationID;
        public String BusinessStatus;
    }
    
    //=============== RESPONSE CLASSES ===============//
    
    public class AppStatusResponse {
        public String pxObjClass;
        public Sys Sys;
        public List<Applications> Applications;
        
        public String errorCode;
        public String errorMessage;
    }
    
    public class Sys {
        public String pxObjClass;
        public String Code;
        public String Description;
        public String RequestDateTime;
        public String TransID;
    }
    
    public class Applications {
        public String pxObjClass;
        public Application Application;
    }
    
    public class Application {
        public String pxObjClass;
        public String AppID;
        public String BusinessStatus;
        public String NationalID1;
        public String NationalID2;
        public String OriginalChannel;
        public String OriginalProduct;
        public String PersonID;
        public String Stage;
        public String Status;
        public String StatusForSale;
        public String Step;
        public String UpdatedDateTime;
    }
    
    //=============== RESULT WRAPPER FOR LWC/CONTROLLER ===============//
    
    public class ResultWrapper {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorCode;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String transId;
        @AuraEnabled public ApplicationWrapper applicationData;
        @AuraEnabled public List<ApplicationWrapper> applicationList;
        
        public ResultWrapper() {
            this.isSuccess = false;
            this.applicationList = new List<ApplicationWrapper>();
        }
    }
    
    public class ApplicationWrapper {
        @AuraEnabled public String appId;
        @AuraEnabled public String businessStatus;
        @AuraEnabled public String nationalId1;
        @AuraEnabled public String nationalId2;
        @AuraEnabled public String originalChannel;
        @AuraEnabled public String originalProduct;
        @AuraEnabled public String personId;
        @AuraEnabled public String stage;
        @AuraEnabled public String status;
        @AuraEnabled public String statusForSale;
        @AuraEnabled public String step;
        @AuraEnabled public Datetime updatedDateTime;
        
        public ApplicationWrapper() {}
        
        public ApplicationWrapper(Application app) {
            if (app != null) {
                this.appId = app.AppID;
                this.businessStatus = app.BusinessStatus;
                this.nationalId1 = app.NationalID1;
                this.nationalId2 = app.NationalID2;
                this.originalChannel = app.OriginalChannel;
                this.originalProduct = app.OriginalProduct;
                this.personId = app.PersonID;
                this.stage = app.Stage;
                this.status = app.Status;
                this.statusForSale = app.StatusForSale;
                this.step = app.Step;
                this.updatedDateTime = FEC_CommonUltils.parseDateTime(app.UpdatedDateTime);
            }
        }
    }
    
    //=============== VALIDATION CLASS ===============//
    
    public class ValidationResult {
        public Boolean isValid;
        public String errorMessage;
        
        public ValidationResult(Boolean isValid, String errorMessage) {
            this.isValid = isValid;
            this.errorMessage = errorMessage;
        }
    }
    
    //=============== MAIN CALL METHOD ===============//
    
    public static AppStatusResponse getAppStatus(String applicationId, Integer ageOfRecords, String businessStatus) {
        
        String transactionId = String.valueOf(UUID.randomUUID());
        String dateTimeValue = Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_XXX);
        String requestorId = FEC_ConstantCommon.REQUESTOR_PEGA_CSM;
        
        AppStatusRequestBody requestBody = new AppStatusRequestBody();
        requestBody.AgeOfRecords = ageOfRecords != null ? ageOfRecords : 17;
        requestBody.ApplicationID = applicationId;
        requestBody.BusinessStatus = businessStatus != null ? businessStatus : '';
        
        AppStatusRequest request = new AppStatusRequest();
        request.headers = new Map<String, Object>{
            'TransID'      => transactionId,
            'DateTime'     => dateTimeValue,
            'RequestorID'  => requestorId,
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
        };
        request.parameters = new List<String>();
        request.body = requestBody;
        
        String requestBodyJson = JSON.serialize(request);
        
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_App_Status');

        String endpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.GET_APP_STATUS_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
        
        Map<String,String> headers = new Map<String,String>{
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            'TransID'      => transactionId,
            'DateTime'     => dateTimeValue,
            'RequestorID'  => requestorId
        };

        HttpResponse resp = FEC_CommonUltils.calloutApiWithHeaders(endpoint, 'POST', headers, requestBodyJson);

        FEC_CommonUltils.logApi(
            'FEC_GetAppStatusCallout',
            endpoint,
            'POST',
            requestBodyJson,
            resp,
            null
        );


        // Parse response
        AppStatusResponse response;
        if (resp.getStatusCode() == 200) {
            response = (AppStatusResponse) JSON.deserialize(
                resp.getBody(),
                AppStatusResponse.class
            );
        } else {
            response = new AppStatusResponse();
            response.errorCode = String.valueOf(resp.getStatusCode());
            response.errorMessage = resp.getStatus();   
        }
        return response;        
    }
    
    // Overloaded method với default values
    public static AppStatusResponse getAppStatus(String applicationId) {
        return getAppStatus(applicationId, 17, '');
    }
    
    // Method để kiểm tra response có success hay không
    public static Boolean isSuccess(AppStatusResponse response) {
        return response != null 
            && response.Sys != null 
            && response.Sys.Code == '1';
    }
    
    // Method để lấy Application đầu tiên từ response
    public static Application getFirstApplication(AppStatusResponse response) {
        if (response != null 
            && response.Applications != null 
            && !response.Applications.isEmpty()
            && response.Applications[0].Application != null) {
            return response.Applications[0].Application;
        }
        return null;
    }
    
    //=============== VALIDATION METHODS ===============//
    
    // Validate request parameters
    public static ValidationResult validateRequest(String applicationId, Integer ageOfRecords) {
        if (String.isBlank(applicationId)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'ApplicationID'}));
            
        }
        
        if (ageOfRecords != null && ageOfRecords < 0) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Positive_Number_Error, new List<String>{'AgeOfRecords'}));
            
        }
        
        // Validate ApplicationID format (chỉ chứa số)
        if (!applicationId.isNumeric()) {
            return new ValidationResult(false, System.Label.FEC_MSG_ApplicationID_must_number);
        }
        
        return new ValidationResult(true, null);
    }
    
    // Validate response
    public static ValidationResult validateResponse(AppStatusResponse response) {
        if (response == null) {
            return new ValidationResult(false, System.Label.FEC_MSG_Response_Null);
        }
        
        if (String.isNotBlank(response.errorCode)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{response.errorCode + ' - ' + response.errorMessage}));
        }
        
        if (response.Sys == null) {
            return new ValidationResult(false, System.Label.FEC_MSG_Response_Sys_Null);
        }
        
        if (response.Sys.Code != '1') {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_API_Error, new List<String>{response.Sys.Description}));
        }
        
        return new ValidationResult(true, null);
    }
    
    //=============== WRAPPER CONVERSION METHODS ===============//
    
    // Convert API response to ResultWrapper cho LWC/Controller
    public static ResultWrapper convertToResultWrapper(AppStatusResponse response) {
        ResultWrapper result = new ResultWrapper();
        
        // Validate response
        ValidationResult validation = validateResponse(response);
        if (!validation.isValid) {
            result.isSuccess = false;
            result.errorCode = response?.errorCode;
            result.errorMessage = validation.errorMessage;
            return result;
        }
        
        result.isSuccess = true;
        result.transId = response.Sys.TransID;
        
        // Convert all applications
        if (response.Applications != null && !response.Applications.isEmpty()) {
            for (Applications apps : response.Applications) {
                if (apps.Application != null) {
                    ApplicationWrapper appWrapper = new ApplicationWrapper(apps.Application);
                    result.applicationList.add(appWrapper);
                }
            }
            
            // Set first application as main data
            if (!result.applicationList.isEmpty()) {
                result.applicationData = result.applicationList[0];
            }
        }
        
        return result;
    }
    
    //=============== MAIN METHOD WITH VALIDATION ===============//
    
    // Main method với đầy đủ validation và trả về ResultWrapper cho LWC
    @AuraEnabled(cacheable=false)
    public static ResultWrapper getAppStatusWithValidation(String applicationId, Integer ageOfRecords, String businessStatus) {
        ResultWrapper result = new ResultWrapper();
        
        // Set default values nếu null
        Integer age = ageOfRecords != null ? ageOfRecords : 17;
        String status = businessStatus != null ? businessStatus : '';
        
        try {
            // Validate request
            ValidationResult requestValidation = validateRequest(applicationId, age);
            if (!requestValidation.isValid) {
                result.isSuccess = false;
                result.errorCode = 'VALIDATION_ERROR';
                result.errorMessage = requestValidation.errorMessage;
                return result;
            }
            
            // Call API
            AppStatusResponse response = getAppStatus(applicationId, age, status);
            
            // Convert to wrapper
            result = convertToResultWrapper(response);
            
        } catch (CalloutException e) {
            result.isSuccess = false;
            result.errorCode = 'CALLOUT_ERROR';
            result.errorMessage = String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{e.getMessage()});
        } catch (JSONException e) {
            result.isSuccess = false;
            result.errorCode = 'JSON_PARSE_ERROR';
            result.errorMessage = String.format(System.Label.FEC_MSG_Parse_JSON_Error, new List<String>{e.getMessage()});
        } catch (Exception e) {
            result.isSuccess = false;
            result.errorCode = 'UNKNOWN_ERROR';
            result.errorMessage = e.getMessage();
        }
        
        return result;
    }
    
}