public with sharing class FEC_GetIPPDetailsCallout {

    //=============== VALIDATION CLASS ===============//
    
    public class ValidationResult {
        public Boolean isValid;
        public String errorMessage;
        
        public ValidationResult(Boolean isValid, String errorMessage) {
            this.isValid = isValid;
            this.errorMessage = errorMessage;
        }
    }

    //=============== VALIDATION METHODS ===============//
    
    /**
     * Validate request parameters
     * Required fields: AccountNumber, EffectiveDate, Amount, PostingDate
     */
    public static ValidationResult validateRequest(IPPRequest reqData) {
        if (reqData == null) {
            return new ValidationResult(false, 'Request data is required and cannot be null.');
        }
        
        // Validate AccountNumber (required, 16 or 19 digits)
        if (String.isBlank(reqData.accountNumber)) {
            return new ValidationResult(false, 'AccountNumber is required and cannot be empty.');
        }
        if (!Pattern.matches('^\\d{16}$|^\\d{19}$', reqData.accountNumber)) {
            return new ValidationResult(false, 'AccountNumber must be 16 or 19 digits. Current value: ' + reqData.accountNumber);
        }
        
        // Validate EffectiveDate (required, format yyyy-MM-dd)
        if (String.isBlank(reqData.effectiveDate)) {
            return new ValidationResult(false, 'EffectiveDate is required and cannot be empty.');
        }
        if (!Pattern.matches('^\\d{4}-\\d{2}-\\d{2}$', reqData.effectiveDate)) {
            return new ValidationResult(false, 'EffectiveDate must be in format yyyy-MM-dd. Current value: ' + reqData.effectiveDate);
        }
        if (!isValidDate(reqData.effectiveDate)) {
            return new ValidationResult(false, 'EffectiveDate is not a valid date. Current value: ' + reqData.effectiveDate);
        }
        
        // Validate Amount (required, must be positive number)
        if (reqData.amount == null) {
            return new ValidationResult(false, 'Amount is required and cannot be null.');
        }
        if (reqData.amount <= 0) {
            return new ValidationResult(false, 'Amount must be a positive number. Current value: ' + reqData.amount);
        }
        
        // Validate PostingDate (required, format yyyy-MM-dd)
        if (String.isBlank(reqData.postingDate)) {
            return new ValidationResult(false, 'PostingDate is required and cannot be empty.');
        }
        if (!Pattern.matches('^\\d{4}-\\d{2}-\\d{2}$', reqData.postingDate)) {
            return new ValidationResult(false, 'PostingDate must be in format yyyy-MM-dd. Current value: ' + reqData.postingDate);
        }
        if (!isValidDate(reqData.postingDate)) {
            return new ValidationResult(false, 'PostingDate is not a valid date. Current value: ' + reqData.postingDate);
        }
        
        return new ValidationResult(true, null);
    }
    
    /**
     * Validate SysRequest headers (TransID, RequestorID, DateTime)
     * These are auto-generated but can be validated for format
     */
    public static ValidationResult validateSysRequestHeaders(String transId, String requestorId, String dateTimeValue) {
        // Validate TransID (required, max 36 characters for UUID)
        if (String.isBlank(transId)) {
            return new ValidationResult(false, 'SysRequest.TransID is required and cannot be empty.');
        }
        if (transId.length() > 36) {
            return new ValidationResult(false, 'SysRequest.TransID must not exceed 36 characters.');
        }
        
        // Validate RequestorID (required)
        if (String.isBlank(requestorId)) {
            return new ValidationResult(false, 'SysRequest.RequestorID is required and cannot be empty.');
        }
        
        // Validate DateTime (required, ISO 8601 format)
        if (String.isBlank(dateTimeValue)) {
            return new ValidationResult(false, 'SysRequest.DateTime is required and cannot be empty.');
        }
        if (!Pattern.matches(FEC_ConstantCommon.PATTERN_DATE_TIME, dateTimeValue)) {
            return new ValidationResult(false, 'SysRequest.DateTime must be in ISO 8601 format (yyyy-MM-dd\'T\'HH:mm:ss). Current value: ' + dateTimeValue);
        }
        
        return new ValidationResult(true, null);
    }
    
    /**
     * Helper: Check if date string is valid
     */
    private static Boolean isValidDate(String dateStr) {
        try {
            Date.valueOf(dateStr);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    //=============== MAIN CALLOUT METHOD ===============//
    
    /**
     * Main callout method with validation
     */
    public static IPPDetailsResponse getIPPDetails(IPPRequest reqData) {
        
        // Step 1: Validate request parameters
        ValidationResult validation = validateRequest(reqData);
        if (!validation.isValid) {
            IPPDetailsResponse errorResponse = new IPPDetailsResponse();
            errorResponse.status = 'ERROR';
            errorResponse.sysMessage = validation.errorMessage;
            return errorResponse;
        }
        
        // Step 2: Generate and validate SysRequest headers
        String transId = String.valueOf(UUID.randomUUID());
        String requestorId = 'SD';
        String dateTimeValue = Datetime.now().formatGmt(FEC_ConstantCommon.DATETIME_FORMAT);
        
        ValidationResult sysValidation = validateSysRequestHeaders(transId, requestorId, dateTimeValue);
        if (!sysValidation.isValid) {
            IPPDetailsResponse errorResponse = new IPPDetailsResponse();
            errorResponse.status = 'ERROR';
            errorResponse.sysMessage = sysValidation.errorMessage;
            return errorResponse;
        }

        // Step 3: Build and send request
        String body = buildSoapRequest(reqData, transId, requestorId, dateTimeValue);

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_IPP_Detail');

        String endpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.GET_IPP_DETAIL_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
        HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, body);

        if (res.getStatusCode() != 200) {
            throw new CalloutException(
                'SOAP call failed: ' + res.getStatus() + ' ' + res.getBody()
            );
        }

        return parseResponse(res.getBody());
    }

    /**
     * Build SOAP XML request with validated parameters
     */
    private static String buildSoapRequest(IPPRequest d, String transId, String requestorId, String dateTimeValue) {
        return
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                               'xmlns:est="http://esbservice.fecredit.org/EStatementService/">' +
                '<soapenv:Header/>' +
                '<soapenv:Body>' +
                    '<est:GetIPPDetails>' +

                        '<est:SysRequest>' +
                            '<TransID>' + transId + '</TransID>' +
                            '<RequestorID>' + requestorId + '</RequestorID>' +
                            '<DateTime>' + dateTimeValue + '</DateTime>' +
                        '</est:SysRequest>' +

                        '<AccountNumber>' + d.accountNumber + '</AccountNumber>' +
                        '<EffectiveDate>' + d.effectiveDate + '</EffectiveDate>' +
                        '<Amount>' + d.amount + '</Amount>' +
                        '<PostingDate>' + d.postingDate + '</PostingDate>' +

                        optionalTag('PlanNumber', d.planNumber) +
                        optionalTag('IPPTerm', d.ippTerm) +
                        optionalTag('ReferenceNumber', d.referenceNumber) +
                        optionalTag('TransactionPlan', d.transactionPlan) +
                        optionalTag('CardNumber', d.cardNumber) +
                        optionalTag('CardSeq', d.cardSeq) +
                        optionalTag('IPPKey', d.ippKey) +

                    '</est:GetIPPDetails>' +
                '</soapenv:Body>' +
            '</soapenv:Envelope>';
    }

    private static String optionalTag(String tag, Object value) {
        return value == null ? '' :
            '<' + tag + '>' + String.valueOf(value) + '</' + tag + '>';
    }

    /**
     * Parse SOAP response
     */
    private static IPPDetailsResponse parseResponse(String xml) {
        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xml);

            Dom.XmlNode envelope = doc.getRootElement();
            Dom.XmlNode body = FEC_CommonUltils.findChildByName(envelope, 'Body');
            
            if (body == null) {
                throw new CalloutException('Invalid XML: Body element not found');
            }

            // Tìm GetIPPDetailsResponse - thử cả với namespace và không namespace
            Dom.XmlNode response = FEC_CommonUltils.findChildByName(body, 'GetIPPDetailsResponse');
            if (response == null) {
                // Thử tìm child element đầu tiên
                List<Dom.XmlNode> children = body.getChildElements();
                if (!children.isEmpty()) {
                    response = children[0];
                }
            }

            if (response == null) {
                throw new CalloutException('Invalid XML: GetIPPDetailsResponse not found');
            }

            IPPDetailsResponse result = new IPPDetailsResponse();

            // SysResponse - tìm không cần namespace
            Dom.XmlNode sysResp = FEC_CommonUltils.findChildByName(response, 'SysResponse');
            if (sysResp != null) {
                result.status      = FEC_CommonUltils.getXmlValue(sysResp, 'Status');
                result.sysMessage  = FEC_CommonUltils.getXmlValue(sysResp, 'Description');
                result.transId     = FEC_CommonUltils.getXmlValue(sysResp, 'TransID');
                result.responseTime= FEC_CommonUltils.getXmlValue(sysResp, 'DateTime');
            }

            // Business fields - tìm không cần namespace
            result.accountNumber      = FEC_CommonUltils.getXmlValue(response, 'AccountNumber');
            result.ippTerm            = FEC_CommonUltils.getXmlValue(response, 'IPPTerm');  // String để hỗ trợ format "3 months"
            result.principalAmount    = FEC_CommonUltils.xmlValToDecimal(response, 'PrincipalAmount');
            result.installmentAmount  = FEC_CommonUltils.xmlValToDecimal(response, 'InstallmentAmount');
            result.conversionFee      = FEC_CommonUltils.xmlValToDecimal(response, 'ConversionFee');
            result.emi                = FEC_CommonUltils.xmlValToDecimal(response, 'EMI');
            result.planNumber         = FEC_CommonUltils.getXmlValue(response, 'PlanNumber');
            result.interestRate       = FEC_CommonUltils.xmlValToDecimal(response, 'InterestRate');
            result.description        = FEC_CommonUltils.getXmlValue(response, 'Description');

            return result;
        } catch (Exception e) {
            throw new CalloutException('Failed to parse XML: ' + e.getMessage());
        }
    }

    /**
     * Request DTO
     */
    public class IPPRequest {
        public String accountNumber;
        public String effectiveDate; // yyyy-MM-dd
        public Decimal amount;
        public String postingDate;   // yyyy-MM-dd
        public String planNumber;
        public Integer ippTerm;
        public String referenceNumber;
        public String transactionPlan;
        public String cardNumber;
        public Integer cardSeq;
        public String ippKey;
    }

    /**
     * Response DTO
     */
    public class IPPDetailsResponse {
        public String transId;
        public String responseTime;
        public String status;
        public String sysMessage;

        public String accountNumber;
        public String ippTerm;
        public Decimal principalAmount;
        public Decimal installmentAmount;
        public Decimal conversionFee;
        public Decimal emi;
        public String planNumber;
        public Decimal interestRate;
        public String description;
    }
}