/****************************************************************************************
 * File Name    : FEC_GetCardPlanInfo
 * Author       : Toannd61
 * Date         : 2025-12-15
 * Description  : Get Card Plan Info from API and return wrapper data
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
 * 3.4      2025-01-15     Toannd61            Update
 ****************************************************************************************/

 public with sharing class FEC_GetCardPlanInfo {

    private static final String CIF_NS = 'http://fecredit.com.vn/CIF_CardInfo'; 
    
    // Cấu hình Validation
    private static final Integer MAX_ID_LEN = 36; 
    private static final Integer MAX_ACCOUNT_LEN = 255;

    // ==========================================
    // WRAPPER CLASS
    // ==========================================
    public class CardPlanResult {
        @AuraEnabled public String transId { get; set; }
        @AuraEnabled public String sysDateTime { get; set; }
        @AuraEnabled public String responseCode { get; set; }
        @AuraEnabled public String responseDesc { get; set; }
        
        @AuraEnabled public List<CardPlan> plans { get; set; }
        
        public CardPlanResult() {
            plans = new List<CardPlan>();
        }
    }

    public class CardPlan {
        @AuraEnabled public String recordNumber { get; set; }       
        @AuraEnabled public String planNumber { get; set; }         
        @AuraEnabled public String openDate { get; set; }           
        @AuraEnabled public String beginDate { get; set; }          
        @AuraEnabled public Decimal currentBalance { get; set; }    
        @AuraEnabled public Decimal baseRate { get; set; }          
        @AuraEnabled public Decimal deferredInterest { get; set; } 
        
        @AuraEnabled public Decimal accruedInterest { get; set; }    
        @AuraEnabled public Decimal perDiem { get; set; }            
        @AuraEnabled public Integer aggregateDays { get; set; }      
        @AuraEnabled public Decimal ippInterest { get; set; }        
        @AuraEnabled public String closeFeeIndicator { get; set; }   
        @AuraEnabled public Decimal closeFeeIndicatorAmt { get; set;}
        @AuraEnabled public Decimal closeFeeAmount { get; set; }     
        @AuraEnabled public Decimal additionalAccruedInt { get; set;} 
        @AuraEnabled public Decimal totalPaymentAmount { get; set;}   
        @AuraEnabled public String refNumber { get; set; }         
    }

    // ==========================================
    // MAIN METHOD
    // ==========================================
    @AuraEnabled
    public static CardPlanResult getCardPlanInfo(String accountNumber) {
        try {
            // 1. CHUẨN BỊ DỮ LIỆU
            String transId = UUID.randomUUID().toString();
            String requestorId = UUID.randomUUID().toString(); 
            String reqTime = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);

            validateRequest(transId, requestorId, reqTime, accountNumber);

            // 2. TẠO REQUEST XML
            Dom.Document doc = new Dom.Document();
            Dom.XmlNode envelope = doc.createRootElement('Envelope', FEC_ConstantCommon.SOAP_ENV, 'soapenv');
            envelope.addChildElement('Header', FEC_ConstantCommon.SOAP_ENV, null);
            Dom.XmlNode body = envelope.addChildElement('Body', FEC_ConstantCommon.SOAP_ENV, null);
            Dom.XmlNode requestNode = body.addChildElement('GetCardPlanInfo', CIF_NS, 'cif');
            
            Dom.XmlNode sysNode = requestNode.addChildElement('Sys', null, null);
            sysNode.addChildElement('TransID', null, null).addTextNode(transId);
            sysNode.addChildElement('RequestorID', null, null).addTextNode(requestorId);
            sysNode.addChildElement('DateTime', null, null).addTextNode(reqTime);
            
            requestNode.addChildElement('AccountNumber', null, null).addTextNode(accountNumber);
            
            // 3. CALLOUT
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Card_Plan_Info');

            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_CARD_PLAN_INFO_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, doc, '');

            if (res.getStatusCode() == 200) {
                // Parse kết quả
                CardPlanResult result = parseResponse(res.getBodyDocument());
                
                return result;
            } else {
                throw new CalloutException(String.format(System.Label.FEC_MSG_API_Error, new List<String>{res.getStatus() + ' - ' + res.getBody()}));
            }
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ==========================================
    // VALIDATION LOGIC (Giữ nguyên)
    // ==========================================
    public static void validateRequest(String transId, String requestorId, String dateTimeStr, String accountNumber) {
        if (String.isBlank(transId)) throw new CalloutException('TransID invalid');
        if (transId.length() > MAX_ID_LEN) throw new CalloutException('TransID too long');
        if (String.isBlank(requestorId)) throw new CalloutException('RequestorID invalid');
        if (String.isBlank(dateTimeStr)) throw new CalloutException('DateTime invalid');
        if (String.isBlank(accountNumber)) throw new CalloutException('AccountNumber invalid');
    }

    // ==========================================
    // PARSER (Đã Fix lỗi chính tả CloseFee)
    // ==========================================
    private static CardPlanResult parseResponse(Dom.Document doc) {
        CardPlanResult result = new CardPlanResult();
        Dom.XmlNode root = doc.getRootElement();
        Dom.XmlNode body = root.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
        Dom.XmlNode responseNode = body.getChildElement('GetCardPlanInfoResponse', CIF_NS);
        
        if (responseNode != null) {
            Dom.XmlNode sysNode = responseNode.getChildElement('Sys', null);
            result.transId = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
            result.sysDateTime = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime'); 
            result.responseCode = FEC_CommonUltils.getXmlValue(sysNode, 'Code');
            result.responseDesc = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
            
            Dom.XmlNode planInfoNode = responseNode.getChildElement('CardPlanInfo', null);
            if (planInfoNode != null) {
                Dom.XmlNode plansNode = planInfoNode.getChildElement('CardPlans', null);
                if (plansNode != null) {
                    for (Dom.XmlNode planNode : plansNode.getChildElements()) {
                        if (planNode.getName() == 'CardPlan') {
                            CardPlan plan = new CardPlan();
                            
                            // Map String Fields
                            plan.recordNumber = FEC_CommonUltils.getXmlValue(planNode, 'RecordNumber');
                            plan.planNumber = FEC_CommonUltils.getXmlValue(planNode, 'PlanNumber');
                            plan.openDate = FEC_CommonUltils.getXmlValue(planNode, 'PlanOpenDate');
                            plan.beginDate = FEC_CommonUltils.getXmlValue(planNode, 'BeginDate');
                            plan.refNumber = FEC_CommonUltils.getXmlValue(planNode, 'REFNumber');
                            
                            // Parse CloseFeelIndicator 
                            plan.closeFeeIndicator = FEC_CommonUltils.getXmlValue(planNode, 'CloseFeelIndicator'); 

                            // Map Decimal Fields
                            plan.currentBalance = FEC_CommonUltils.xmlValToDecimal(planNode, 'PlanCurrentBalance');
                            plan.baseRate = FEC_CommonUltils.xmlValToDecimal(planNode, 'BaseRate');
                            plan.deferredInterest = FEC_CommonUltils.xmlValToDecimal(planNode, 'DeferredInterest');
                            plan.accruedInterest = FEC_CommonUltils.xmlValToDecimal(planNode, 'AccruedInterest');
                            plan.perDiem = FEC_CommonUltils.xmlValToDecimal(planNode, 'PerDiem');
                            plan.ippInterest = FEC_CommonUltils.xmlValToDecimal(planNode, 'IPPInterest');
                            
                            // Parse CloseFeelIndicatorAmount 
                            plan.closeFeeIndicatorAmt = FEC_CommonUltils.xmlValToDecimal(planNode, 'CloseFeelIndicatorAmount'); 
                            
                            plan.closeFeeAmount = FEC_CommonUltils.xmlValToDecimal(planNode, 'CloseFeeAmount');
                            plan.totalPaymentAmount = FEC_CommonUltils.xmlValToDecimal(planNode, 'PlanPaymentAmount');
                            plan.additionalAccruedInt = FEC_CommonUltils.xmlValToDecimal(planNode, 'AccruedInt');

                            // Map Integer Fields
                            String aggDays = FEC_CommonUltils.getXmlValue(planNode, 'AggregateDays');
                            plan.aggregateDays = String.isNotBlank(aggDays) ? Integer.valueOf(aggDays) : 0;

                            result.plans.add(plan);
                        }
                    }
                }
            }
        }
        return result;
    }

}