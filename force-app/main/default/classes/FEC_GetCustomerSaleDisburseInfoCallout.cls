public without sharing class FEC_GetCustomerSaleDisburseInfoCallout {
    
    //=============== REQUEST CLASSES ===============//
    
    public class CustomerSaleDisburseInfoRequest {
        public Map<String, Object> headers;
        public List<String> parameters;
        public Map<String, Object> body;
        
        public CustomerSaleDisburseInfoRequest() {
            this.headers = new Map<String, Object>();
            this.parameters = new List<String>();
            this.body = new Map<String, Object>();
        }
    }
    
    //=============== RESPONSE CLASSES ===============//
    
    public class CustomerSaleDisburseInfoResponse {
        public Sys Sys;
        public List<CustomerSaleInfo> CustomerSaleInfos;
        
        public String errorCode;
        public String errorMessage;
    }
    
    public class Sys {
        public String TransID;
        public String DateTime_x; // DateTime is reserved keyword
        public Integer Code;
        public String Description;
    }
    
    public class CustomerSaleInfo {
        public String APPLICATION_ID;
        public String BANK_NAME;
        public String BRANCH_NAME;
        public Decimal TOP_UP_LOAN_AMT;
        public Decimal TOP_UP_OLD_AC_OUSTANDING;
        public String TOP_UP_AGREEMENT_ID;
        public String TOPUP_FLAG;
        public String CC_CODE;
        public String CC_NAME;
        public String DSA_CODE;
        public String DSA_NAME;
        public String TSA_CODE;
        public String TSA_NAME;
        public String DISB_CHANNEL;
        public String DISB_STATUS;
        public String DATE_STATUS;
        public Decimal DISB_AMT;
        public String LOAN_CONTRACT;
        public String BANK_ACCOUNT_NUMBER;
    }
    
    //=============== RESULT WRAPPER FOR LWC ===============//
    
    public class ResultWrapper {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorCode;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String transId;
        @AuraEnabled public SalesInfoWrapper salesInfo;
        @AuraEnabled public List<SalesInfoWrapper> salesInfoList;
        
        public ResultWrapper() {
            this.isSuccess = false;
            this.salesInfoList = new List<SalesInfoWrapper>();
        }
    }
    
    public class SalesInfoWrapper {
        @AuraEnabled public String applicationId;
        @AuraEnabled public String bankName;
        @AuraEnabled public String branchName;
        @AuraEnabled public Decimal topUpLoanAmt;
        @AuraEnabled public Decimal topUpOldAcOutstanding;
        @AuraEnabled public String topUpAgreementId;
        @AuraEnabled public String topupFlag;
        @AuraEnabled public String ccCode;
        @AuraEnabled public String ccName;
        @AuraEnabled public String dsaCode;
        @AuraEnabled public String dsaName;
        @AuraEnabled public String tsaCode;
        @AuraEnabled public String tsaName;
        @AuraEnabled public String disbChannel;
        @AuraEnabled public String disbStatus;
        @AuraEnabled public String dateStatus;
        @AuraEnabled public Decimal disbAmt;
        @AuraEnabled public String loanContract;
        @AuraEnabled public String bankAccountNumber;
        
        public SalesInfoWrapper() {}
        
        public SalesInfoWrapper(CustomerSaleInfo info) {
            if (info != null) {
                this.applicationId = info.APPLICATION_ID;
                this.bankName = info.BANK_NAME;
                this.branchName = info.BRANCH_NAME;
                this.topUpLoanAmt = info.TOP_UP_LOAN_AMT;
                this.topUpOldAcOutstanding = info.TOP_UP_OLD_AC_OUSTANDING;
                this.topUpAgreementId = info.TOP_UP_AGREEMENT_ID;
                this.topupFlag = info.TOPUP_FLAG;
                this.ccCode = info.CC_CODE;
                this.ccName = info.CC_NAME;
                this.dsaCode = info.DSA_CODE;
                this.dsaName = info.DSA_NAME;
                this.tsaCode = info.TSA_CODE;
                this.tsaName = info.TSA_NAME;
                this.disbChannel = info.DISB_CHANNEL;
                this.disbStatus = info.DISB_STATUS;
                this.dateStatus = info.DATE_STATUS;
                this.disbAmt = info.DISB_AMT;
                this.loanContract = info.LOAN_CONTRACT;
                this.bankAccountNumber = info.BANK_ACCOUNT_NUMBER;
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
    
    public static CustomerSaleDisburseInfoResponse getCustomerSaleDisburseInfo(String applicationId) {
        
        // Generate header values
        String transactionId = String.valueOf(UUID.randomUUID());
        String dateTimeValue = Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_XXX);
        String requestorId = FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN;
        
        // Validate request headers (TransID, DateTime, RequestorID)
        ValidationResult headerValidation = validateRequestHeaders(transactionId, dateTimeValue, requestorId);
        if (!headerValidation.isValid) {
            CustomerSaleDisburseInfoResponse errorResponse = new CustomerSaleDisburseInfoResponse();
            errorResponse.errorCode = 'HEADER_VALIDATION_ERROR';
            errorResponse.errorMessage = headerValidation.errorMessage;
            return errorResponse;
        }
        
        String requestBodyJson = '{"APPLICATION_ID":"' + applicationId + '"}';
        
        // Build HTTP request
        HttpRequest req = new HttpRequest();
        
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Customer_Sale_Disburse_Info');

        String endpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.GET_CUSTOMER_SALE_DISBURSE_INFO_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
        
        endpoint += '?APPLICATION_ID=' + EncodingUtil.urlEncode(applicationId, 'UTF-8');
        
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Content-Type', FEC_ConstantCommon.API_CONTENT_TYPE_JSON);
        req.setHeader('TransID', transactionId);
        req.setHeader('DateTime', dateTimeValue);
        req.setHeader('RequestorID', requestorId);
        req.setTimeout(120000);
        
        Http http = new Http();
        HttpResponse resp = http.send(req);

        // FEC_CommonUltils.logApi(
        //     'FEC_GetCustomerSaleDisburseInfoCallout',
        //     endpoint,
        //     'GET',
        //     requestBodyJson,
        //     resp,
        //     null
        // );

        // Parse response
        CustomerSaleDisburseInfoResponse response;
        if (resp.getStatusCode() == 200) {
            // Handle DateTime field mapping (DateTime is reserved in Apex)
            String responseBody = resp.getBody().replace('"DateTime":', '"DateTime_x":');
            response = (CustomerSaleDisburseInfoResponse) JSON.deserialize(
                responseBody,
                CustomerSaleDisburseInfoResponse.class
            );
        } else {
            response = new CustomerSaleDisburseInfoResponse();
            response.errorCode = String.valueOf(resp.getStatusCode());
            response.errorMessage = resp.getStatus();   
        }
        return response;        
    }
    
    //=============== VALIDATION METHODS ===============//
    
    public static ValidationResult validateRequest(String applicationId) {
        if (String.isBlank(applicationId)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'ApplicationID'}));
        }
        return new ValidationResult(true, null);
    }
    
    /**
     * Validate request headers (TransID, DateTime, RequestorID)
     * @param transId - Transaction ID
     * @param dateTimeValue - DateTime value
     * @param requestorId - Requestor ID
     * @return ValidationResult
     */
    public static ValidationResult validateRequestHeaders(String transId, String dateTimeValue, String requestorId) {
        // Validate TransID
        if (String.isBlank(transId)) {
            return new ValidationResult(false, System.Label.FEC_MSG_TransID_Null);
        }
        
        // Validate DateTime
        if (String.isBlank(dateTimeValue)) {
            return new ValidationResult(false, System.Label.FEC_MSG_Datetime_Null);
        }
        
        // Validate DateTime format (ISO 8601: yyyy-MM-dd'T'HH:mm:ss.SSSXXX)
        try {
            // Check if DateTime matches expected pattern
            Pattern dateTimePattern = Pattern.compile(FEC_ConstantCommon.PATTERN_DATE_TIME_FULL);
            Matcher matcher = dateTimePattern.matcher(dateTimeValue);
            if (!matcher.matches()) {
                return new ValidationResult(false, String.format(System.Label.FEC_MSG_Datetime_Invalid, new List<String>{dateTimeValue}));
            }
        } catch (Exception e) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Datetime_Invalid, new List<String>{dateTimeValue}));
        }
        
        // Validate RequestorID
        if (String.isBlank(requestorId)) {
            return new ValidationResult(false, System.Label.FEC_MSG_RequestorID_Null);
        }
        
        return new ValidationResult(true, null);
    }
    
    public static ValidationResult validateResponse(CustomerSaleDisburseInfoResponse response) {
        if (response == null) {
            return new ValidationResult(false, System.Label.FEC_MSG_Response_Null);
        }
        
        if (String.isNotBlank(response.errorCode)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{response.errorCode + ' - ' + response.errorMessage}));
        }
        
        if (response.Sys == null) {
            return new ValidationResult(false, System.Label.FEC_MSG_Response_Sys_Null);
        }
        
        if (response.Sys.Code != 1) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_API_Error, new List<String>{response.Sys.Description}));
        }
        
        return new ValidationResult(true, null);
    }
    
    //=============== WRAPPER CONVERSION METHODS ===============//
    
    public static ResultWrapper convertToResultWrapper(CustomerSaleDisburseInfoResponse response) {
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
        
        // Convert all CustomerSaleInfos
        if (response.CustomerSaleInfos != null && !response.CustomerSaleInfos.isEmpty()) {
            for (CustomerSaleInfo info : response.CustomerSaleInfos) {
                SalesInfoWrapper wrapper = new SalesInfoWrapper(info);
                result.salesInfoList.add(wrapper);
            }
            
            // Set first item as main data
            if (!result.salesInfoList.isEmpty()) {
                result.salesInfo = result.salesInfoList[0];
            }
        }
        
        return result;
    }
    
    //=============== MAIN METHOD WITH VALIDATION ===============//
    
    @AuraEnabled(cacheable=false)
    public static ResultWrapper getCustomerSaleDisburseInfoWithValidation(String applicationId) {
        ResultWrapper result = new ResultWrapper();
        
        try {
            // Validate request
            ValidationResult requestValidation = validateRequest(applicationId);
            if (!requestValidation.isValid) {
                result.isSuccess = false;
                result.errorCode = 'VALIDATION_ERROR';
                result.errorMessage = requestValidation.errorMessage;
                return result;
            }
            
            // Call API
            CustomerSaleDisburseInfoResponse response = getCustomerSaleDisburseInfo(applicationId);
            
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
    
    //=============== HELPER METHODS ===============//
    
    // Method để kiểm tra response có success hay không
    public static Boolean isSuccess(CustomerSaleDisburseInfoResponse response) {
        return response != null 
            && response.Sys != null 
            && response.Sys.Code == 1;
    }
    
    // Method để lấy CustomerSaleInfo đầu tiên từ response
    public static CustomerSaleInfo getFirstSaleInfo(CustomerSaleDisburseInfoResponse response) {
        if (response != null 
            && response.CustomerSaleInfos != null 
            && !response.CustomerSaleInfos.isEmpty()) {
            return response.CustomerSaleInfos[0];
        }
        return null;
    }
}