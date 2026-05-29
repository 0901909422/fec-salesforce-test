public with sharing class FEC_MarkNFU {
  public static final String API_CONFIG_NAME = 'FEC_Mark_NFU';

  public class MarkNFURequest {
    public String ContractNumber;
    public String NFUReasonCode;
    public String NFUUpdatedBy;
  }

    public class MarkNFUResult {
    public String code;
    public String description;
    public String nfuReasonCode;
    public String nfuStartDate;
    public String nfuTillDate;
    public Integer httpStatus;
    public String rawResponse;
    public Boolean success;
    public String errorMessage;
  }

  public static String buildEnvelope(MarkNFURequest req) {
    validate(req);

    String env = '';
    env += '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:PegaRULES:SOAP:CollectionServices:Services">';
    env += '<soapenv:Header/>';
    env += '<soapenv:Body>';
    env += '<urn:MarkNFU>';
    if (String.isNotBlank(req.ContractNumber)) {
      env += '<ContractNumber>' + FEC_CommonUltils.escapeXml(req.ContractNumber) + '</ContractNumber>';
    }
    if (String.isNotBlank(req.NFUReasonCode)) {
      env += '<NFUReasonCode>' + FEC_CommonUltils.escapeXml(req.NFUReasonCode) + '</NFUReasonCode>';
    }
    if (String.isNotBlank(req.NFUUpdatedBy)) {
      env += '<NFUUpdatedBy>' + FEC_CommonUltils.escapeXml(req.NFUUpdatedBy) + '</NFUUpdatedBy>';
    }
    env += '</urn:MarkNFU>';
    env += '</soapenv:Body>';
    env += '</soapenv:Envelope>';
    return env;
  }

  public static HttpResponse sendRequest(String envelope) {
    FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
    FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);

    String endpoint = apiSetting?.FEC_Call_Mock__c
      ? FEC_ConstantCommon.STR_EMPTY
      : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
    
    HttpResponse res = FEC_CommonUltils.calloutApi(
      endpoint,
      FEC_ConstantCommon.API_METHOD_POST,
      FEC_ConstantCommon.API_CONTENT_TYPE,
      apiConfig?.FEC_SOAP_Action__c,
      null,
      envelope
    );
    return res;
  }

  public static MarkNFUResult parseResponse(String xml, Integer httpStatus) {
    MarkNFUResult result = new MarkNFUResult();
    result.httpStatus = httpStatus;
    result.rawResponse = xml;
    if (String.isBlank(xml)) {
      result.errorMessage = System.Label.FEC_MSG_Response_Null;
      result.success = false;
      return result;
    }
    try {
      Dom.Document doc = new Dom.Document();
      doc.load(xml);
      Dom.XmlNode envelope = doc.getRootElement();
      Dom.XmlNode body = envelope.getChildElement('Body', 'http://schemas.xmlsoap.org/soap/envelope/');
      if (body == null) {
        result.errorMessage = System.Label.FEC_MSG_Response_Null;
        result.success = false;
        return result;
      }
      
      Dom.XmlNode responseNode = null;
      for (Dom.XmlNode n : body.getChildElements()) {
        if (n.getName().endsWith('MarkNFUResponse')) {
          responseNode = n;
          break;
        }
      }
      
      if (responseNode == null) {
        result.errorMessage = System.Label.FEC_MSG_Response_Null;
        result.success = false;
        return result;
      }
      
      result.code = FEC_CommonUltils.getXmlValue(responseNode, 'Code');
      result.description = FEC_CommonUltils.getXmlValue(responseNode, 'Description');
      result.nfuReasonCode = FEC_CommonUltils.getXmlValue(responseNode, 'NFUReasonCode');
      result.nfuStartDate = FEC_CommonUltils.getXmlValue(responseNode, 'NFUStartDate');
      if (String.isBlank(result.nfuStartDate)) {
        result.nfuStartDate = FEC_CommonUltils.getXmlValue(responseNode, 'NFUFromDate');
      }
      result.nfuTillDate = FEC_CommonUltils.getXmlValue(responseNode, 'NFUTillDate');

      // Mark NFU API: Code 0 = success, Code 1 (and others) = failure. Code 203 handled separately in Hold Case flow.
      result.success = (result.code == FEC_ConstantCommon.SUCCESS_STATUS_CODE);
      if (!result.success && String.isNotBlank(result.description)) {
        result.errorMessage = result.description;
      }

    } catch (Exception ex) {
      result.errorMessage = ex.getMessage();
      result.success = false;
    }
    return result;
  }

  public static MarkNFUResult markNFU(MarkNFURequest req) {
    MarkNFUResult finalResult = new MarkNFUResult();
    try {
      String envelope = buildEnvelope(req);
      HttpResponse res = sendRequest(envelope);
      Integer status = (res == null) ? null : res.getStatusCode();
      String body = (res == null) ? null : res.getBody();
      finalResult = parseResponse(body, status);
    } catch (Exception ex) {
      finalResult.errorMessage = ex.getMessage();
      finalResult.success = false;
    }
    return finalResult;
  }

  private static void validate(MarkNFURequest req) {
    if (req == null) {
      throw new FEC_APIServiceException(
        String.format(
          System.Label.FEC_MSG_Param_Required,
          new List<String>{ 'Request' }
        )
      );
    }

    if (String.isBlank(req.ContractNumber)) {
      throw new FEC_APIServiceException(
        String.format(
          System.Label.FEC_MSG_Param_Required,
          new List<String>{ 'Contract Number' }
        )
      );
    }
  }

  @AuraEnabled
  public static MarkNFUResult markNFUByRecordIds(
    Id caseId,
    Id holdCaseConfigId
  ) {
    try {
      Case c = [
        SELECT FEC_Account_Contract_Number_Text__c
        FROM Case
        WHERE Id = :caseId
        WITH SECURITY_ENFORCED
        LIMIT 1
      ];

      FEC_Hold_Case_Config__c config = [
        SELECT FEC_NFU_Code__c
        FROM FEC_Hold_Case_Config__c
        WHERE Id = :holdCaseConfigId
        WITH SECURITY_ENFORCED
        LIMIT 1
      ];

      String userEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].Email;

      MarkNFURequest req = new MarkNFURequest();
      req.ContractNumber = c.FEC_Account_Contract_Number_Text__c;
      req.NFUReasonCode = config.FEC_NFU_Code__c;
      req.NFUUpdatedBy = userEmail;

      return markNFU(req);
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
}