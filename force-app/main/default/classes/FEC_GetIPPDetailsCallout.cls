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

    //=============== DTO REQUEST ===============//

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

    //=============== DTO RESPONSE ===============//

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

    //=============== VALIDATION METHODS ===============//

    /**
     * Validate request parameters.
     * Required: AccountNumber, EffectiveDate, Amount, PostingDate.
     */
    public static ValidationResult validateRequest(IPPRequest reqData) {
        if (reqData == null) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Request data' }));
        }

        if (String.isBlank(reqData.accountNumber)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'AccountNumber' }));
        }
        if (!Pattern.matches(FEC_ConstantCommon.PATTERN_ACCOUNT_NUMBER, reqData.accountNumber)) {
            return new ValidationResult(false, System.Label.FEC_MSG_AccountNumber_Invalid);
        }

        if (String.isBlank(reqData.effectiveDate)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'EffectiveDate' }));
        }
        if (!Pattern.matches(FEC_ConstantCommon.PATTERN_DATE, reqData.effectiveDate)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Date_Format_Invalid, new List<String>{ 'EffectiveDate', reqData.effectiveDate }));
        }
        if (!isValidDate(reqData.effectiveDate)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Date_Value_Invalid, new List<String>{ 'EffectiveDate', reqData.effectiveDate }));
        }

        if (reqData.amount == null) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Amount' }));
        }
        if (reqData.amount <= 0) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Positive_Number_Error, new List<String>{ 'Amount' }));
        }

        if (String.isBlank(reqData.postingDate)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'PostingDate' }));
        }
        if (!Pattern.matches(FEC_ConstantCommon.PATTERN_DATE, reqData.postingDate)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Date_Format_Invalid, new List<String>{ 'PostingDate', reqData.postingDate }));
        }
        if (!isValidDate(reqData.postingDate)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Date_Value_Invalid, new List<String>{ 'PostingDate', reqData.postingDate }));
        }

        return new ValidationResult(true, null);
    }

    /**
     * Validate SysRequest headers (TransID, RequestorID, DateTime)
     */
    public static ValidationResult validateSysRequestHeaders(String transId, String requestorId, String dateTimeValue) {
        if (String.isBlank(transId)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'TransID' }));
        }
        if (transId.length() > 36) {
            return new ValidationResult(false, System.Label.FEC_MSG_TransID_Null);
        }

        if (String.isBlank(requestorId)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'RequestorID' }));
        }

        if (String.isBlank(dateTimeValue)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'SysRequest.DateTime' }));
        }
        if (!Pattern.matches(FEC_ConstantCommon.PATTERN_DATE_TIME, dateTimeValue)) {
            return new ValidationResult(false, String.format(System.Label.FEC_MSG_Param_Datetime_Format_Invalid, new List<String>{ 'SysRequest.DateTime', dateTimeValue }));
        }

        return new ValidationResult(true, null);
    }

    private static Boolean isValidDate(String dateStr) {
        try {
            Date.valueOf(dateStr);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    //=============== MAIN CALLOUT METHOD ===============//

    public static IPPDetailsResponse getIPPDetails(IPPRequest reqData) {

        ValidationResult validation = validateRequest(reqData);
        if (!validation.isValid) {
            IPPDetailsResponse errorResponse = new IPPDetailsResponse();
            errorResponse.status = 'ERROR';
            errorResponse.sysMessage = validation.errorMessage;
            return errorResponse;
        }

        String transId = String.valueOf(UUID.randomUUID());
        String requestorId = FEC_ConstantCommon.REQUESTOR_SD;
        String dateTimeValue = Datetime.now().formatGmt(FEC_ConstantCommon.DATETIME_FORMAT);

        ValidationResult sysValidation = validateSysRequestHeaders(transId, requestorId, dateTimeValue);
        if (!sysValidation.isValid) {
            IPPDetailsResponse errorResponse = new IPPDetailsResponse();
            errorResponse.status = 'ERROR';
            errorResponse.sysMessage = sysValidation.errorMessage;
            return errorResponse;
        }

        // Step 3: Build and send request
        Dom.Document doc = buildSoapRequestXml(reqData, transId, requestorId, dateTimeValue);

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_IPP_Detail');

        String endpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.GET_IPP_DETAIL_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
        HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, FEC_ConstantCommon.API_METHOD_POST, FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, doc, '');

        FEC_CommonUltils.logApi(
            'FEC_GetIPPDetailsCallout',
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            doc.toXmlString(),
            res,
            null
        );

        if (res.getStatusCode() != 200) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{ res.getStatus() + ' ' + res.getBody() })
            );
        }

        return parseResponse(res.getBody());
    }

    //=============== BUILD SOAP REQUEST (XML NODE) ===============//

    private static Dom.Document buildSoapRequestXml(
        IPPRequest d,
        String transId,
        String requestorId,
        String dateTimeValue
    ) {
        String soapEnv = 'http://schemas.xmlsoap.org/soap/envelope/';
        String estNs = 'http://esbservice.fecredit.org/EStatementService/';

        Dom.Document doc = new Dom.Document();
        Dom.XmlNode envelope = doc.createRootElement('Envelope', soapEnv, 'soapenv');
        envelope.addChildElement('Header', soapEnv, null);

        Dom.XmlNode body = envelope.addChildElement('Body', soapEnv, null);
        Dom.XmlNode requestNode = body.addChildElement('GetIPPDetails', estNs, 'est');

        // SysRequest
        Dom.XmlNode sysNode = requestNode.addChildElement('SysRequest', estNs, 'est');
        sysNode.addChildElement('TransID', null, null).addTextNode(transId);
        sysNode.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sysNode.addChildElement('DateTime', null, null).addTextNode(dateTimeValue);

        // Required fields
        requestNode.addChildElement('AccountNumber', null, null).addTextNode(d.accountNumber);
        requestNode.addChildElement('EffectiveDate', null, null).addTextNode(d.effectiveDate);
        requestNode.addChildElement('Amount', null, null).addTextNode(String.valueOf(d.amount));

        // Optional fields
        addOptionalNodeOrEmpty(requestNode, 'PlanNumber', d.planNumber);
        addOptionalNodeOrEmpty(requestNode, 'IPPTerm', d.ippTerm);
        addOptionalNodeOrEmpty(requestNode, 'ReferenceNumber', d.referenceNumber);
        addOptionalNodeOrEmpty(requestNode, 'TransactionPlan', d.transactionPlan);

        // Required
        requestNode.addChildElement('PostingDate', null, null).addTextNode(d.postingDate);

        addOptionalNodeOrEmpty(requestNode, 'CardNumber', d.cardNumber);
        requestNode.addChildElement('CardSeq', null, null)
            .addTextNode(d.cardSeq != null ? String.valueOf(d.cardSeq) : '0');
        addOptionalNodeOrEmpty(requestNode, 'IPPKey', d.ippKey);

        return doc;
    }

    /**(optional fields before PostingDate). */
    private static void addOptionalNodeOrEmpty(Dom.XmlNode parent, String tagName, Object value) {
        String text = (value != null && String.isNotBlank(String.valueOf(value))) ? String.valueOf(value) : '';
        parent.addChildElement(tagName, null, null).addTextNode(text);
    }

    private static void addOptionalNode(Dom.XmlNode parent, String tagName, Object value) {
        if (value != null && String.isNotBlank(String.valueOf(value))) {
            parent.addChildElement(tagName, null, null).addTextNode(String.valueOf(value));
        }
    }

    //=============== PARSE RESPONSE ===============//

    private static IPPDetailsResponse parseResponse(String xml) {
        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xml);

            Dom.XmlNode envelope = doc.getRootElement();
            Dom.XmlNode body = FEC_CommonUltils.findChildByName(envelope, 'Body');

            if (body == null) {
                throw new CalloutException(System.Label.FEC_MSG_Response_Null);
            }

            Dom.XmlNode response = FEC_CommonUltils.findChildByName(body, 'GetIPPDetailsResponse');
            if (response == null) {
                List<Dom.XmlNode> children = body.getChildElements();
                if (!children.isEmpty()) {
                    response = children[0];
                }
            }

            if (response == null) {
                throw new CalloutException(System.Label.FEC_MSG_Response_Null);
            }

            IPPDetailsResponse result = new IPPDetailsResponse();

            Dom.XmlNode sysResp = FEC_CommonUltils.findChildByName(response, 'SysResponse');
            if (sysResp != null) {
                result.status = FEC_CommonUltils.getXmlValue(sysResp, 'Status');
                result.sysMessage = FEC_CommonUltils.getXmlValue(sysResp, 'Description');
                result.transId = FEC_CommonUltils.getXmlValue(sysResp, 'TransID');
                result.responseTime = FEC_CommonUltils.getXmlValue(sysResp, 'DateTime');
            }

            result.accountNumber = FEC_CommonUltils.getXmlValue(response, 'AccountNumber');
            result.ippTerm = FEC_CommonUltils.getXmlValue(response, 'IPPTerm');
            result.principalAmount = FEC_CommonUltils.xmlValToDecimal(response, 'PrincipalAmount');
            result.installmentAmount = FEC_CommonUltils.xmlValToDecimal(response, 'InstallmentAmount');
            result.conversionFee = FEC_CommonUltils.xmlValToDecimal(response, 'ConversionFee');
            result.emi = FEC_CommonUltils.xmlValToDecimal(response, 'EMI');
            result.planNumber = FEC_CommonUltils.getXmlValue(response, 'PlanNumber');
            result.interestRate = FEC_CommonUltils.xmlValToDecimal(response, 'InterestRate');
            result.description = FEC_CommonUltils.getXmlValue(response, 'Description');

            return result;
        } catch (Exception e) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Parse_XML_Error, new List<String>{ e.getMessage() }));
        }
    }
}