/****************************************************************************************
 * File Name    : FEC_EmeaAccountInqService
 * Author       : Toannd61
 * Date         : 2026-01-26
 * Description  : Callout to M_CMS_EMEA_ACCOUNT_INQ (VMX Integration)
 * Includes mapping for Memo Debit/Credit
 * Context Path : /CMS_VMXIntegrationWS
 * SOAPAction   : M_CMS_EMEA_ACCOUNT_INQ
 ****************************************************************************************/

 public with sharing class FEC_EmeaAccountInqService {

    // ==========================================
    // CONSTANTS & CONFIGURATION
    // ==========================================
    private static final String SERVICE_NS = 'http://fecredit.com.vn/CMS_VMXIntegrationWS';
    private static final String WS_RESPONSE_NS = 'http://fecredit.com.vn/cms/ws/v2'; // Namespace cho WSRequest/WSResponse

    // ==========================================
    // 1. INPUT DTO (Data Transfer Object)
    // ==========================================
    public class EmeaInput {
        @AuraEnabled public String context { get; set; }     // VMX_MSGIN.CONTEXT (required)
        @AuraEnabled public String name { get; set; }         // VMX_MSGIN.NAME (required)
        @AuraEnabled public String org { get; set; }          // VMX_MSGIN.ORG (required)
        @AuraEnabled public String account { get; set; }       // VMX_MSGIN.ACCOUNT (required)
        @AuraEnabled public String dualInd { get; set; }       // VMX_MSGIN.DUAL_IND (optional)
        // Sys.VMXVersion (optional). 
        @AuraEnabled public String vmxVersion { get; set; }
    }

    // ==========================================
    // 2. OUTPUT DTO (Wrapper Result)
    // ==========================================
    public class EmeaResult {
        // --- Sys Block ---
        @AuraEnabled public String transId { get; set; }
        @AuraEnabled public String responseCode { get; set; }
        @AuraEnabled public String responseDesc { get; set; }
        
        // --- VMX Output ---
        @AuraEnabled public String svcReturn { get; set; }
        
        // --- Account Basic Info ---
        @AuraEnabled public String acctNbr { get; set; }
        @AuraEnabled public String shortName { get; set; }
        @AuraEnabled public String custNbr { get; set; }
        
        // Financials
        @AuraEnabled public Decimal currBal { get; set; }
        @AuraEnabled public Decimal income { get; set; }
        @AuraEnabled public Decimal pmtTotAmtDue { get; set; }
        @AuraEnabled public Decimal pmtPastDue { get; set; }
        @AuraEnabled public Decimal loanBal { get; set; }
        
        // Memo Debit & Credit
        @AuraEnabled public Decimal amtMemoDb { get; set; }  // AMT_MEMO_DB
        @AuraEnabled public Decimal amtMemoCr { get; set; }  // AMT_MEMO_CR
        
        // Dates
        @AuraEnabled public Date dtOpened { get; set; }
        @AuraEnabled public Date dtPmtDue { get; set; }
        @AuraEnabled public Date dtCardExp { get; set; }
        
        // --- NA Data (Contact Info) ---
        @AuraEnabled public String naFirstName { get; set; }
        @AuraEnabled public String naMobPh { get; set; }
        @AuraEnabled public String naCity { get; set; }
        @AuraEnabled public String naEmp { get; set; }
    }

    // ==========================================
    // 3. MAIN METHOD
    // ==========================================
    @AuraEnabled
    public static EmeaResult callAccountInquiry(EmeaInput input) {
        try {
            // 1. Validate Input
            validateInput(input);

            // 2. Prepare Sys Data
            String transId = UUID.randomUUID().toString();
            String requestorId = FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN;
            String reqTime = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);

            // 3. Construct XML Request
            Dom.Document doc = new Dom.Document();
            Dom.XmlNode envelope = doc.createRootElement('Envelope', FEC_ConstantCommon.SOAP_ENV, 'soapenv');
            envelope.setNamespace('v2', WS_RESPONSE_NS);
            envelope.addChildElement('Header', FEC_ConstantCommon.SOAP_ENV, 'soapenv');
            Dom.XmlNode body = envelope.addChildElement('Body', FEC_ConstantCommon.SOAP_ENV, 'soapenv');
            Dom.XmlNode wsRequest = body.addChildElement('WSRequest', WS_RESPONSE_NS, 'v2');

            Dom.XmlNode sysNode = wsRequest.addChildElement('Sys', null, null);
            sysNode.addChildElement('TransID', null, null).addTextNode(transId);
            sysNode.addChildElement('RequestorID', null, null).addTextNode(requestorId);
            sysNode.addChildElement('DateTime', null, null).addTextNode(reqTime);
            // Sys.VMXVersion optional - chỉ thêm node khi caller truyền giá trị
            if (String.isNotBlank(input.vmxVersion)) {
                sysNode.addChildElement('VMXVersion', null, null).addTextNode(input.vmxVersion);
            }

            // Root Element Service: M_CMS_EMEA_ACCOUNT_INQ
            Dom.XmlNode rootRequest = wsRequest.addChildElement('M_CMS_EMEA_ACCOUNT_INQ', null, null);

            // Block VMX_ROOT -> VMX_MSGIN
            Dom.XmlNode vmxRoot = rootRequest.addChildElement('VMX_ROOT', null, null);
            Dom.XmlNode msgIn = vmxRoot.addChildElement('VMX_MSGIN', null, null);
            
            addTextNode(msgIn, 'CONTEXT', input.context);
            addTextNode(msgIn, 'NAME', input.name);
            addTextNode(msgIn, 'ORG', input.org);
            addTextNode(msgIn, 'ACCOUNT', input.account);
            // VMX_MSGIN.DUAL_IND optiona
            if (String.isNotBlank(input.dualInd)) {
                addTextNode(msgIn, 'DUAL_IND', input.dualInd);
            }


            // Lấy cấu hình API từ Custom Setting
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Emea_Account_Inq');

            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.EMEA_ACCOUNT_INQ_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, doc, '');

            // 5. Process Response
            if (res.getStatusCode() == 200) {

                String responseBody = res.getBody();
                if (String.isNotBlank(responseBody)) {

                    // normalize using common utility (handles BOM, leading chars, trimming)
                    responseBody = FEC_CommonUltils.cleanResponseBody(responseBody);

                    System.debug('### Response Body (first 500 chars): ' + responseBody.substring(0, Math.min(500, responseBody.length())));
                    
                    Dom.Document responseDoc = new Dom.Document();
                    responseDoc.load(responseBody);
                    return parseResponse(responseDoc);
                } else {
                    throw new CalloutException(System.Label.FEC_MSG_Response_Null);
                }
            } else {
                
                System.debug('HTTP Error: ' + res.getBody());
                throw new CalloutException(String.format(System.Label.FEC_MSG_API_Error, new List<String>{res.getStatus() + ' - ' + res.getBody()}));
            }

        } catch (Exception e) {
            System.debug('Exception in callAccountInquiry: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ==========================================
    // 4. VALIDATION
    // ==========================================
    private static void validateInput(EmeaInput input) {
        if (input == null) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Input'}));
        }
        if (String.isBlank(input.context)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CONTEXT'}));
        }
        if (String.isBlank(input.name)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'NAME'}));
        }
        if (String.isBlank(input.org)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'ORG'}));
        }
        if (String.isBlank(input.account)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'ACCOUNT'}));
        }
    }

    // ==========================================
    // 5. PARSER (XML Response Handler)
    // ==========================================
    private static EmeaResult parseResponse(Dom.Document doc) {
        EmeaResult result = new EmeaResult();
        Dom.XmlNode root = doc.getRootElement();
        String rootName = root.getName();
        Dom.XmlNode wsResponse = null;
        
        if (rootName == 'WSResponse' || rootName.contains('WSResponse')) {
            wsResponse = root;
        } else if (rootName == 'Envelope') {
            Dom.XmlNode body = root.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
            if (body != null) {

                wsResponse = body.getChildElement('WSResponse', WS_RESPONSE_NS);
                if (wsResponse == null) {
                    wsResponse = body.getChildElement('WSResponse', null);
                }
                
                if (wsResponse == null) {
                    Dom.XmlNode responseNode = body.getChildElement('M_CMS_EMEA_ACCOUNT_INQResponse', SERVICE_NS);
                    if (responseNode != null) {
                        return parseOldFormatResponse(responseNode);
                    }
                }
            }
        } else {
            
            wsResponse = root.getChildElement('WSResponse', WS_RESPONSE_NS);
            if (wsResponse == null) {
                wsResponse = root.getChildElement('WSResponse', null);
            }
        }
        
        if (wsResponse == null) {
            System.debug('### ERROR: Cannot find WSResponse in response. Root element: ' + rootName);
            return result;
        }

        // A. Parse Sys từ WSResponse
        Dom.XmlNode sysNode = wsResponse.getChildElement('Sys', null);
        if (sysNode != null) {
            result.transId = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
            result.responseCode = FEC_CommonUltils.getXmlValue(sysNode, 'Code');
            result.responseDesc = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
        }

        // B. Parse M_CMS_EMEA_ACCOUNT_INQ từ WSResponse
        Dom.XmlNode emeaInq = wsResponse.getChildElement('M_CMS_EMEA_ACCOUNT_INQ', null);
        if (emeaInq != null) {
            Dom.XmlNode vmxRoot = emeaInq.getChildElement('VMX_ROOT', null);
            if (vmxRoot != null) {
                Dom.XmlNode msgOut = vmxRoot.getChildElement('VMX_MSGOUT', null);
                if (msgOut != null) {
                    result.svcReturn = FEC_CommonUltils.getXmlValue(msgOut, 'SVC_RETURN');

                    // C. Parse ACCT_BS_OUTPUT
                    Dom.XmlNode acctBs = msgOut.getChildElement('ACCT_BS_OUTPUT', null);
                    if (acctBs != null) {
                        result.acctNbr = FEC_CommonUltils.getXmlValue(acctBs, 'ACCT_NBR');
                        result.shortName = FEC_CommonUltils.getXmlValue(acctBs, 'SHORT_NAME');
                        result.custNbr = FEC_CommonUltils.getXmlValue(acctBs, 'CUST_NBR');
                        
                        result.currBal = FEC_CommonUltils.xmlValToDecimal(acctBs, 'CURR_BAL');
                        result.income = FEC_CommonUltils.xmlValToDecimal(acctBs, 'INCOME');
                        result.pmtTotAmtDue = FEC_CommonUltils.xmlValToDecimal(acctBs, 'PMT_TOT_AMT_DUE');
                        result.pmtPastDue = FEC_CommonUltils.xmlValToDecimal(acctBs, 'PMT_PAST_DUE');
                        result.loanBal = FEC_CommonUltils.xmlValToDecimal(acctBs, 'LOAN_BAL');
                        
                        result.amtMemoDb = FEC_CommonUltils.xmlValToDecimal(acctBs, 'AMT_MEMO_DB');
                        result.amtMemoCr = FEC_CommonUltils.xmlValToDecimal(acctBs, 'AMT_MEMO_CR');
                        
                        // --- Parse Dates ---
                        result.dtOpened = FEC_CommonUltils.xmlValToDate(acctBs, 'DT_OPENED');
                        result.dtPmtDue = FEC_CommonUltils.xmlValToDate(acctBs, 'DT_PMT_DUE');
                        result.dtCardExp = FEC_CommonUltils.xmlValToDate(acctBs, 'DT_CARD_EXP');

                        // D. Parse NA_DATA_TBL -> NA_DATA 
                        Dom.XmlNode naTbl = acctBs.getChildElement('NA_DATA_TBL', null);
                        if (naTbl != null) {
                            Dom.XmlNode naData = naTbl.getChildElement('NA_DATA', null);
                            if (naData != null) {
                                result.naFirstName = FEC_CommonUltils.getXmlValue(naData, 'NA_FIRST_NAME');
                                result.naMobPh = FEC_CommonUltils.getXmlValue(naData, 'NA_MOB_PH');
                                result.naCity = FEC_CommonUltils.getXmlValue(naData, 'NA_CITY');
                                result.naEmp = FEC_CommonUltils.getXmlValue(naData, 'NA_EMP');
                            }
                        }
                    }
                }
            }
        }
        return result;
    }

    // Parser cho format cũ (backward compatibility)
    private static EmeaResult parseOldFormatResponse(Dom.XmlNode responseNode) {
        EmeaResult result = new EmeaResult();
        
        // A. Parse Sys
        Dom.XmlNode sysNode = responseNode.getChildElement('Sys', null);
        if (sysNode != null) {
            result.transId = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
            result.responseCode = FEC_CommonUltils.getXmlValue(sysNode, 'Code');
            result.responseDesc = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
        }

        // B. Parse VMX_ROOT
        Dom.XmlNode vmxRoot = responseNode.getChildElement('VMX_ROOT', null);
        if (vmxRoot != null) {
            Dom.XmlNode msgOut = vmxRoot.getChildElement('VMX_MSGOUT', null);
            if (msgOut != null) {
                result.svcReturn = FEC_CommonUltils.getXmlValue(msgOut, 'SVC_RETURN');

                // C. Parse ACCT_BS_OUTPUT
                Dom.XmlNode acctBs = msgOut.getChildElement('ACCT_BS_OUTPUT', null);
                if (acctBs != null) {
                    result.acctNbr = FEC_CommonUltils.getXmlValue(acctBs, 'ACCT_NBR');
                    result.shortName = FEC_CommonUltils.getXmlValue(acctBs, 'SHORT_NAME');
                    result.custNbr = FEC_CommonUltils.getXmlValue(acctBs, 'CUST_NBR');
                    
                    result.currBal = FEC_CommonUltils.xmlValToDecimal(acctBs, 'CURR_BAL');
                    result.income = FEC_CommonUltils.xmlValToDecimal(acctBs, 'INCOME');
                    result.pmtTotAmtDue = FEC_CommonUltils.xmlValToDecimal(acctBs, 'PMT_TOT_AMT_DUE');
                    result.pmtPastDue = FEC_CommonUltils.xmlValToDecimal(acctBs, 'PMT_PAST_DUE');
                    result.loanBal = FEC_CommonUltils.xmlValToDecimal(acctBs, 'LOAN_BAL');
                    
                    // Memo Fields
                    result.amtMemoDb = FEC_CommonUltils.xmlValToDecimal(acctBs, 'AMT_MEMO_DB');
                    result.amtMemoCr = FEC_CommonUltils.xmlValToDecimal(acctBs, 'AMT_MEMO_CR');
                    
                    // --- Parse Dates ---
                    result.dtOpened = FEC_CommonUltils.xmlValToDate(acctBs, 'DT_OPENED');
                    result.dtPmtDue = FEC_CommonUltils.xmlValToDate(acctBs, 'DT_PMT_DUE');
                    result.dtCardExp = FEC_CommonUltils.xmlValToDate(acctBs, 'DT_CARD_EXP');

                    // D. Parse NA_DATA_TBL -> NA_DATA 
                    Dom.XmlNode naTbl = acctBs.getChildElement('NA_DATA_TBL', null);
                    if (naTbl != null) {
                        Dom.XmlNode naData = naTbl.getChildElement('NA_DATA', null);
                        if (naData != null) {
                            result.naFirstName = FEC_CommonUltils.getXmlValue(naData, 'NA_FIRST_NAME');
                            result.naMobPh = FEC_CommonUltils.getXmlValue(naData, 'NA_MOB_PH');
                            result.naCity = FEC_CommonUltils.getXmlValue(naData, 'NA_CITY');
                            result.naEmp = FEC_CommonUltils.getXmlValue(naData, 'NA_EMP');
                        }
                    }
                }
            }
        }
        return result;
    }

    // ==========================================
    // 6. HELPERS
    // ==========================================
    
    // Thêm Text Node vào XML
    private static void addTextNode(Dom.XmlNode parent, String name, String value) {
        parent.addChildElement(name, null, null).addTextNode(value == null ? '' : value);
    }
    
}