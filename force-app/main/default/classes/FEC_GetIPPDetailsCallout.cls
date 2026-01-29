public with sharing class FEC_GetIPPDetailsCallout {

    private static final String ENDPOINT =
        'https://api-internal.fecredit.com.vn/EStatementService';

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
        if (!Pattern.matches('^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$', dateTimeValue)) {
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
        String dateTimeValue = Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss');
        
        ValidationResult sysValidation = validateSysRequestHeaders(transId, requestorId, dateTimeValue);
        if (!sysValidation.isValid) {
            IPPDetailsResponse errorResponse = new IPPDetailsResponse();
            errorResponse.status = 'ERROR';
            errorResponse.sysMessage = sysValidation.errorMessage;
            return errorResponse;
        }

        // Step 3: Build and send request
        HttpRequest req = new HttpRequest();
        // req.setEndpoint(ENDPOINT);
        req.setEndpoint('https://5fea0f8e-afdd-4820-aead-2a9a1fef654e.mock.pstmn.io');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'text/xml; charset=UTF-8');
        req.setHeader('SOAPAction', 'GetIPPDetails');
        req.setTimeout(120000);

        req.setBody(buildSoapRequest(reqData, transId, requestorId, dateTimeValue));

        Http http = new Http();
        HttpResponse res = http.send(req);

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
            Dom.XmlNode body = findChildByName(envelope, 'Body');
            
            if (body == null) {
                throw new CalloutException('Invalid XML: Body element not found');
            }

            // Tìm GetIPPDetailsResponse - thử cả với namespace và không namespace
            Dom.XmlNode response = findChildByName(body, 'GetIPPDetailsResponse');
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
            Dom.XmlNode sysResp = findChildByName(response, 'SysResponse');
            if (sysResp != null) {
                result.status      = getTextSafe(sysResp, 'Status');
                result.sysMessage  = getTextSafe(sysResp, 'Description');
                result.transId     = getTextSafe(sysResp, 'TransID');
                result.responseTime= getTextSafe(sysResp, 'DateTime');
            }

            // Business fields - tìm không cần namespace
            result.accountNumber      = getTextSafe(response, 'AccountNumber');
            result.ippTerm            = getTextSafe(response, 'IPPTerm');  // String để hỗ trợ format "3 months"
            result.principalAmount    = getDecimalSafe(response, 'PrincipalAmount');
            result.installmentAmount  = getDecimalSafe(response, 'InstallmentAmount');
            result.conversionFee      = getDecimalSafe(response, 'ConversionFee');
            result.emi                = getDecimalSafe(response, 'EMI');
            result.planNumber         = getTextSafe(response, 'PlanNumber');
            result.interestRate       = getDecimalSafe(response, 'InterestRate');
            result.description        = getTextSafe(response, 'Description');

            return result;
        } catch (Exception e) {
            throw new CalloutException('Failed to parse XML: ' + e.getMessage());
        }
    }

    /**
     * Helper: Tìm child node theo tên
     */
    private static Dom.XmlNode findChildByName(Dom.XmlNode parent, String nodeName) {
        if (parent == null) return null;
        for (Dom.XmlNode child : parent.getChildElements()) {
            if (child.getName() == nodeName || child.getName().endsWith(':' + nodeName)) {
                return child;
            }
        }
        return null;
    }

    /**
     * Helper: Lấy text từ child node
     */
    private static String getTextSafe(Dom.XmlNode parent, String name) {
        if (parent == null) return null;
        
        // Tìm child element - thử cả với và không có namespace
        Dom.XmlNode child = findChildByName(parent, name);
        if (child == null) return null;
        
        // Lấy text content
        String text = child.getText();
        return text != null ? text.trim() : null;
    }
    
    private static String getText(Dom.XmlNode parent, String name) {
        Dom.XmlNode child = parent.getChildElement(name, null);
        return child != null ? child.getText() : null;
    }

    /**
     * Helper: Lấy Decimal từ child node
     */
    private static Decimal getDecimalSafe(Dom.XmlNode parent, String name) {
        String val = getTextSafe(parent, name);
        if (String.isBlank(val)) return null;
        try {
            return Decimal.valueOf(val);
        } catch (Exception e) {
            System.debug('Error parsing decimal for ' + name + ': ' + val + ' - ' + e.getMessage());
            return null;
        }
    }
    
    private static Decimal getDecimal(Dom.XmlNode parent, String name) {
        String val = getText(parent, name);
        return String.isBlank(val) ? null : Decimal.valueOf(val);
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