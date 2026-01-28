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

    private static final String SOAP_NS = 'http://schemas.xmlsoap.org/soap/envelope/';
    private static final String CIF_NS = 'http://fecredit.com.vn/CIF_CardInfo'; 
    
    private static final String ENDPOINT = '/CIF_CardInfo';
    private static final String MOCKUP_ENDPOINT = 'https://0ad0dbbf-693f-473e-a8db-d69d703f19a2.mock.pstmn.io/CIF_CardInfo';
    
    
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
            String reqTime = Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss');

            validateRequest(transId, requestorId, reqTime, accountNumber);

            // 2. TẠO REQUEST XML
            Dom.Document doc = new Dom.Document();
            Dom.XmlNode envelope = doc.createRootElement('Envelope', SOAP_NS, 'soapenv');
            envelope.addChildElement('Header', SOAP_NS, null);
            Dom.XmlNode body = envelope.addChildElement('Body', SOAP_NS, null);
            Dom.XmlNode requestNode = body.addChildElement('GetCardPlanInfo', CIF_NS, 'cif');
            
            Dom.XmlNode sysNode = requestNode.addChildElement('Sys', null, null);
            sysNode.addChildElement('TransID', null, null).addTextNode(transId);
            sysNode.addChildElement('RequestorID', null, null).addTextNode(requestorId);
            sysNode.addChildElement('DateTime', null, null).addTextNode(reqTime);
            
            requestNode.addChildElement('AccountNumber', null, null).addTextNode(accountNumber);
            
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();

            // 3. CALLOUT
            HttpRequest req = new HttpRequest();
            req.setEndpoint(apiSetting?.FEC_Call_Mock__c ? MOCKUP_ENDPOINT : (apiSetting?.FEC_Endpoint__c + ENDPOINT));
            // req.setEndpoint('https://0ad0dbbf-693f-473e-a8db-d69d703f19a2.mock.pstmn.io/CIF_CardInfo'); 
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', 'http://fecredit.com.vn/CIF_CardInfo/GetCardPlanInfo');
            req.setBodyDocument(doc);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Parse kết quả
                CardPlanResult result = parseResponse(res.getBodyDocument());
                
                return result;
            } else {
                throw new CalloutException('API Error: ' + res.getStatus() + ' - ' + res.getBody());
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
        Dom.XmlNode body = root.getChildElement('Body', SOAP_NS);
        Dom.XmlNode responseNode = body.getChildElement('GetCardPlanInfoResponse', CIF_NS);
        
        if (responseNode != null) {
            Dom.XmlNode sysNode = responseNode.getChildElement('Sys', null);
            result.transId = getTextSafe(sysNode, 'TransID');
            result.sysDateTime = getTextSafe(sysNode, 'DateTime'); 
            result.responseCode = getTextSafe(sysNode, 'Code');
            result.responseDesc = getTextSafe(sysNode, 'Description');
            
            Dom.XmlNode planInfoNode = responseNode.getChildElement('CardPlanInfo', null);
            if (planInfoNode != null) {
                Dom.XmlNode plansNode = planInfoNode.getChildElement('CardPlans', null);
                if (plansNode != null) {
                    for (Dom.XmlNode planNode : plansNode.getChildElements()) {
                        if (planNode.getName() == 'CardPlan') {
                            CardPlan plan = new CardPlan();
                            
                            // Map String Fields
                            plan.recordNumber = getTextSafe(planNode, 'RecordNumber');
                            plan.planNumber = getTextSafe(planNode, 'PlanNumber');
                            plan.openDate = getTextSafe(planNode, 'PlanOpenDate');
                            plan.beginDate = getTextSafe(planNode, 'BeginDate');
                            plan.refNumber = getTextSafe(planNode, 'REFNumber');
                            
                            // Parse CloseFeelIndicator 
                            plan.closeFeeIndicator = getTextSafe(planNode, 'CloseFeelIndicator'); 

                            // Map Decimal Fields
                            plan.currentBalance = getDecimalSafe(planNode, 'PlanCurrentBalance');
                            plan.baseRate = getDecimalSafe(planNode, 'BaseRate');
                            plan.deferredInterest = getDecimalSafe(planNode, 'DeferredInterest');
                            plan.accruedInterest = getDecimalSafe(planNode, 'AccruedInterest');
                            plan.perDiem = getDecimalSafe(planNode, 'PerDiem');
                            plan.ippInterest = getDecimalSafe(planNode, 'IPPInterest');
                            
                            // Parse CloseFeelIndicatorAmount 
                            plan.closeFeeIndicatorAmt = getDecimalSafe(planNode, 'CloseFeelIndicatorAmount'); 
                            
                            plan.closeFeeAmount = getDecimalSafe(planNode, 'CloseFeeAmount');
                            plan.totalPaymentAmount = getDecimalSafe(planNode, 'PlanPaymentAmount');
                            plan.additionalAccruedInt = getDecimalSafe(planNode, 'AccruedInt');

                            // Map Integer Fields
                            String aggDays = getTextSafe(planNode, 'AggregateDays');
                            plan.aggregateDays = String.isNotBlank(aggDays) ? Integer.valueOf(aggDays) : 0;

                            result.plans.add(plan);
                        }
                    }
                }
            }
        }
        return result;
    }

    private static String getTextSafe(Dom.XmlNode parent, String childName) {
        if (parent == null) return '';
        Dom.XmlNode child = parent.getChildElement(childName, null);
        return child != null ? child.getText() : '';
    }
    
    private static Decimal getDecimalSafe(Dom.XmlNode parent, String childName) {
        String val = getTextSafe(parent, childName);
        return String.isNotBlank(val) ? Decimal.valueOf(val) : 0;
    }
}