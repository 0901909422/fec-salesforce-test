public with sharing class FEC_CMSIPPBlockWS {

    //Thangtv: API Log sau callout (ResponseLog + logApiResponse)
    public static final String API_CONFIG_NAME = 'FEC_CMS_IPP_BlockWS';
    // 29/05/2026 14:00 linhdev - default payload CMSIPPBlockWS theo integration spec
    public static final String DEFAULT_DISB_CHANNEL = 'PC';
    public static final Integer DEFAULT_TENURE = 0;
    public static final String DEFAULT_CAMPAIGN_NAME = 'TMN';
    private static ResponseLog responseLog;

    /* ================================
     * RESPONSE MODELS
     * ================================ */
    public class ResponseWrapper {
        @AuraEnabled public SysResponse Sys;
        @AuraEnabled public Decimal AvailableCredit;
    }

    public class SysResponse {
        @AuraEnabled public String TransID;
        @AuraEnabled public Datetime DateTime_x;
        @AuraEnabled public String Code;
        @AuraEnabled public String Description;
    }

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

    /* ================================
     * PUBLIC CALL METHOD
     * ================================ */
    @AuraEnabled
    public static ResponseWrapper cmsIPPBlockWS(
        String requestorId,
        String crmID,
        String disbChannel,
        String accountNumber,
        Decimal amount,
        Integer tenure,
        Boolean noIPP,
        String campaignName,
        Decimal flatRate,
        String custAccount,
        String bankName,
        String bankBranch,
        Decimal smsRate,
        Decimal insuranceAmount,
        String highRisk
    ) {
        String transId = String.valueOf(UUID.randomUUID());
        String dateTimeStr = FEC_CommonUltils.formatTimestamp(
            Datetime.now(),
            FEC_ConstantCommon.STR_DATETIME_FORMAT_Z
        );

        try { //Thangtv
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);

            // 29/05/2026 14:00 linhdev - default DisbChannel/CampaignName: ưu tiên FEC_API_Config__mdt, fallback constant
            if (String.isBlank(disbChannel)) {
                disbChannel = resolveDisbChannelDefault(apiConfig);
            }
            if (String.isBlank(campaignName)) {
                campaignName = resolveCampaignNameDefault(apiConfig);
            }
            tenure = tenure != null ? tenure : DEFAULT_TENURE;
            noIPP = noIPP != null ? noIPP : true;
            flatRate = flatRate != null ? flatRate : 0;

            validate(
                transId,
                requestorId,
                dateTimeStr,
                crmID,
                disbChannel,
                accountNumber,
                amount,
                tenure
            );

            String soapBody = buildSoapBody(
                transId,
                requestorId,
                dateTimeStr,
                crmID,
                disbChannel,
                accountNumber,
                amount,
                tenure,
                noIPP,
                campaignName,
                flatRate,
                custAccount,
                bankName,
                bankBranch,
                smsRate,
                insuranceAmount,
                highRisk
            );

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();

            String baseEndpoint = (apiSetting != null && String.isNotBlank(apiSetting.FEC_Endpoint__c))
                ? apiSetting.FEC_Endpoint__c
                : '';
            String configEndpoint = (apiConfig != null && String.isNotBlank(apiConfig.FEC_Endpoint__c))
                ? apiConfig.FEC_Endpoint__c
                : '';
            String endpoint = FEC_CommonUltils.buildCalloutEndpoint(baseEndpoint, configEndpoint); //Thangtv

            responseLog = new ResponseLog(
                API_CONFIG_NAME,
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                soapBody,
                null,
                null
            );

            HttpResponse res = FEC_CommonUltils.calloutApi(
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                FEC_ConstantCommon.API_CONTENT_TYPE,
                apiConfig?.FEC_SOAP_Action__c,
                null,
                soapBody
            );
            responseLog.response = res;

            System.debug('res: ' + res.getBody());
            if (res.getStatusCode() == 200 && String.isNotBlank(res.getBody())) {
                return parseResponse(res.getBody());
            }
            return null;
        } catch (Exception e) {
            if (responseLog != null) {
                responseLog.errorMessage = e.getMessage();
            }
            throw e;
        } finally {
            logApiResponse(); //Thangtv: ghi FEC_API_Log__c
        }
    }

    //Thangtv
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
    
    /* ================================
     * SOAP BODY BUILDER
     * ================================ */
    private static String buildSoapBody(
        String transId,
        String requestorId,
        String dateTimeStr,
        String crmID,
        String disbChannel,
        String accountNumber,
        Decimal amount,
        Integer tenure,
        Boolean noIPP,
        String campaignName,
        Decimal flatRate,
        String custAccount,
        String bankName,
        String bankBranch,
        Decimal smsRate,
        Decimal insuranceAmount,
        String highRisk

    ) {
        Dom.Document doc = new Dom.Document();
        
        Dom.XmlNode envelope = doc.createRootElement(
            'soapenv:Envelope',
            null,
            null
        );
        
        envelope.setAttribute(
            'xmlns:soapenv',
            FEC_ConstantCommon.SOAP_ENV
        );

            envelope.setAttribute(
            'xmlns:cms',
            'http://fecredit.com.vn/CMS_IPP_BlockWS'
        );
        
         // ===== Header =====
        envelope.addChildElement('soapenv:Header', null, null);
        
        // ===== Body =====
        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);
        
        // ===== Main Action =====
        Dom.XmlNode action =
            body.addChildElement('cms:CMSIPPBlock', null, null);
   

         // Sys
        Dom.XmlNode sys = action.addChildElement('Sys', null, null);
        sys.addChildElement('TransID', null, null).addTextNode(transId);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        // CRM ID 
        Dom.XmlNode crmIDNode = action.addChildElement('CrmID', null, null).addTextNode(crmID);

        // DisbChannel 
        Dom.XmlNode disbChannelNode = action.addChildElement('DisbChannel', null, null).addTextNode(disbChannel);

        // Account 
        Dom.XmlNode accountNode = action.addChildElement('Account', null, null).addTextNode(accountNumber);

        // Amount 
        Dom.XmlNode amountNode = action.addChildElement('Amount', null, null).addTextNode(String.valueOf(amount));

        // Tenure 
        Dom.XmlNode tenureNode = action.addChildElement('Tenure', null, null).addTextNode(String.valueOf(tenure));

        // NO_IPP 
        Dom.XmlNode noIPPNode = action.addChildElement('NO_IPP', null, null).addTextNode(String.valueOf(noIPP));

        // Campagin Name 
        Dom.XmlNode campaignNameNode = action.addChildElement('CampaignName', null, null).addTextNode(campaignName);

        // FlatRate
        Dom.XmlNode flatRateNode = action.addChildElement('FlatRate', null, null).addTextNode(String.valueOf(flatRate));

        // CustAccount
        Dom.XmlNode custAccountNode = action.addChildElement('CustAccount', null, null).addTextNode(custAccount);

        // BankName
        Dom.XmlNode bankNameNode = action.addChildElement('BankName', null, null).addTextNode(bankName);

        // BankBranch
        Dom.XmlNode bankBranchNode = action.addChildElement('BankBranch', null, null).addTextNode(bankBranch);

        // SMSRate
        Dom.XmlNode smsRateNode = action.addChildElement('SMSRate', null, null).addTextNode(String.valueOf(smsRate));

        // InsuranceAmount
        Dom.XmlNode insuranceAmountNode = action.addChildElement('InsuranceAmount', null, null).addTextNode(String.valueOf(insuranceAmount));

        // HighRisk
        Dom.XmlNode highRiskNode = action.addChildElement('HighRisk', null, null).addTextNode(highRisk);

        return doc.toXmlString();
    }

    /* ================================
     * RESPONSE PARSER
     * ================================ */
    public static ResponseWrapper parseResponse(String xml) {

        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode body = doc.getRootElement()
            .getChildElement(
                'Body',
                FEC_ConstantCommon.SOAP_ENV
            );

        Dom.XmlNode resNode = body.getChildElement(
            'CMSIPPBlockResponse',
            'http://fecredit.com.vn/CMS_IPP_BlockWS'
        );
        if (resNode == null) {
            throw new CalloutException('Cannot find CMSIPPBlockResponse');
        }

        ResponseWrapper res = new ResponseWrapper();
        /* ===== SYS ===== */
        Dom.XmlNode sysNode = resNode.getChildElement('Sys', null);
        res.Sys = new SysResponse();
        res.Sys.TransID     = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
        res.Sys.DateTime_x  = FEC_CommonUltils.toDatetime(FEC_CommonUltils.getXmlValue(sysNode, 'DateTime'));
        res.Sys.Code        = FEC_CommonUltils.getXmlValue(sysNode, 'Code');
        res.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');

        /* ===== AvailableCredit ===== */
        res.AvailableCredit = FEC_CommonUltils.xmlValToDecimal(resNode, 'AvailableCredit');

        System.debug('>>Output: '+ res);
        return res;
    }

    public static void validate(
        String transId,
        String requestorId,
        String dateTimeStr,
        String crmID,
        String disbChannel,
        String accountNumber,
        Decimal amount,
        Integer tenure
    ) {
        Set<String> validRequestors = new Set<String>{
            FEC_ConstantCommon.REQUESTOR_CRM,
            FEC_ConstantCommon.REQUESTOR_CORE,
            FEC_ConstantCommon.REQUESTOR_MOBILE,
            FEC_ConstantCommon.REQUESTOR_PORTAL,
            FEC_ConstantCommon.REQUESTOR_VTIGER_CL,
            FEC_ConstantCommon.REQUESTOR_VTIGER_PL,
            FEC_ConstantCommon.REQUESTOR_PEGA_CSM_LEGACY
        };
        /* ================= TransID ================= */
        if (String.isBlank(transId) || transId.length() > 36) {
            throw new CalloutException(
                System.Label.FEC_MSG_TransID_Null
            );
        }

        /* ================= RequestorID ================= */
        if (String.isBlank(requestorId) || !validRequestors.contains(requestorId)) {
            throw new CalloutException(
                System.Label.FEC_MSG_RequestorID_Null
            );
        }
        // ===================== DATETIME =====================
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException(System.Label.FEC_MSG_Datetime_Null);
        }
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T',' '));
        } catch(Exception e) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Datetime_Invalid, new List<String>{dateTimeStr}));
        }

        
        /* ================= crmID ================= */
        if (String.isBlank(crmID)) {
            throw new CalloutException(System.Label.FEC_MSG_CRM_ID_Null);
        }


        /* ================= disbChannel ================= */
        if (String.isBlank(disbChannel)) {
            throw new CalloutException(System.Label.FEC_MSG_DisbChannel_Null);
        }

        /* ================= AccountNumber ================= */
        if (String.isBlank(accountNumber)) {
            throw new CalloutException(System.Label.FEC_MSG_Account_Number_Null);
        }

        /* ================= AccountNumber ================= */
        if (String.isNotBlank(accountNumber) &&
            !Pattern.matches(FEC_ConstantCommon.PATTERN_ACCOUNT_NUMBER, accountNumber)) {
            throw new CalloutException(
                System.Label.FEC_MSG_AccountNumber_Invalid
            );
        }

        if (amount == null) {
            throw new CalloutException(System.Label.FEC_MSG_Amount_Null);
        }

        if (tenure == null) {
            throw new CalloutException(System.Label.FEC_MSG_Tenure_Null);
        }


    }

    // 29/05/2026 14:00 linhdev - DisbChannel default: FEC_API_Config.FEC_Disb_Channel__c hoặc DEFAULT_DISB_CHANNEL
    private static String resolveDisbChannelDefault(FEC_API_Config__mdt apiConfig) {
        if (apiConfig != null && String.isNotBlank(apiConfig.FEC_Disb_Channel__c)) {
            return apiConfig.FEC_Disb_Channel__c.trim();
        }
        return DEFAULT_DISB_CHANNEL;
    }

    // 29/05/2026 14:00 linhdev - CampaignName default: FEC_API_Config.FEC_Campaign_Name__c hoặc DEFAULT_CAMPAIGN_NAME
    private static String resolveCampaignNameDefault(FEC_API_Config__mdt apiConfig) {
        if (apiConfig != null && String.isNotBlank(apiConfig.FEC_Campaign_Name__c)) {
            return apiConfig.FEC_Campaign_Name__c.trim();
        }
        return DEFAULT_CAMPAIGN_NAME;
    }
    
}