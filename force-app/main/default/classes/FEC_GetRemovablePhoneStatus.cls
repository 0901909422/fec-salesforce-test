/****************************************************************************************
 * File Name    : FEC_GetRemovablePhoneStatus
 * Author       : Toannd61
 * Date         : 2026-03-11
 * Description  : SOAP API callout to check if a phone number is eligible to be removed
 *                from a customer record (GetRemovablePhoneStatus)
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-03-11     Toannd61             Create

****************************************************************************************/

public with sharing class FEC_GetRemovablePhoneStatus {

  private static ResponseLog responseLog;
  private static final String PHONE_CHECK_NS = 'http://fecredit.com.vn/PhoneCheckWS';

  public class PhoneCheckResult {
    @AuraEnabled public String transId;
    @AuraEnabled public String dateTimeStr;
    @AuraEnabled public String code;
    @AuraEnabled public String description;
    @AuraEnabled public Integer httpStatus;
    @AuraEnabled public String rawResponse;
    @AuraEnabled public Boolean success;
    @AuraEnabled public String errorMessage;
  }

  // ==========================================
  // RESPONSE LOG CLASS
  // ==========================================
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

  // ==========================================
  // MAIN METHOD
  // ==========================================
  @AuraEnabled
  public static PhoneCheckResult getRemovablePhoneStatus(String phone) {
    try {
      if (String.isBlank(phone)) {
        throw new FEC_APIServiceException(
          String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Phone'})
        );
      }
      if (phone.length() > 40) {
        throw new FEC_APIServiceException(
          String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'Phone', '40'})
        );
      }

      String transId = UUID.randomUUID().toString();
      String timestamp = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);

      Dom.Document doc = new Dom.Document();
      Dom.XmlNode envelope = doc.createRootElement(
        'Envelope',
        FEC_ConstantCommon.SOAP_ENV,
        'soapenv'
      );
      envelope.addChildElement('Header', FEC_ConstantCommon.SOAP_ENV, null);

      Dom.XmlNode body = envelope.addChildElement('Body', FEC_ConstantCommon.SOAP_ENV, null);
      Dom.XmlNode requestNode = body.addChildElement(
        'GetRemovablePhoneStatus',
        PHONE_CHECK_NS,
        'cif'
      );
      envelope.setNamespace('cif', PHONE_CHECK_NS);

      // --- SYS ---
      Dom.XmlNode sysNode = requestNode.addChildElement('Sys', null, null);
      sysNode.addChildElement('TransID', null, null).addTextNode(transId);
      sysNode.addChildElement('RequestorID', null, null)
        .addTextNode(UUID.randomUUID().toString());
      sysNode.addChildElement('DateTime', null, null).addTextNode(timestamp);

      // --- Phone ---
      requestNode.addChildElement('Phone', null, null).addTextNode(phone);

      PhoneCheckResult finalResult = new PhoneCheckResult();
      String endpoint = '';
      try {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Removable_Phone_Status');

        endpoint = (apiSetting != null && apiSetting.FEC_Call_Mock__c == true)
            ? FEC_MockupEndpoint.GET_REMOVABLE_PHONE_STATUS_ENDPOINT_MOCKUP
            : ((apiSetting != null ? apiSetting.FEC_Endpoint__c : '') + (apiConfig != null ? apiConfig.FEC_Endpoint__c : ''));

        HttpResponse res = FEC_CommonUltils.calloutApi(
          endpoint,
          FEC_ConstantCommon.API_METHOD_POST,
          FEC_ConstantCommon.API_CONTENT_TYPE,
          apiConfig?.FEC_SOAP_Action__c,
          doc,
          ''
        );

        responseLog = new ResponseLog(
          'FEC_GetRemovablePhoneStatus',
          endpoint,
          FEC_ConstantCommon.API_METHOD_POST,
          doc.toXmlString(),
          res,
          null
        );

        Integer status = (res == null) ? null : res.getStatusCode();
        String resBody = (res == null) ? null : res.getBody();

        finalResult = parseResponse(resBody, status);

        if (finalResult.transId == null)
          finalResult.transId = transId;

        if (finalResult.httpStatus == null)
          finalResult.httpStatus = status;

        if (finalResult.rawResponse == null)
          finalResult.rawResponse = resBody;

      } catch (Exception ex) {
        if (responseLog != null) {
          responseLog.errorMessage = ex.getMessage();
        } else {
          responseLog = new ResponseLog(
            'FEC_GetRemovablePhoneStatus',
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            doc.toXmlString(),
            null,
            ex.getMessage()
          );
        }
        finalResult.errorMessage = ex.getMessage();
        finalResult.success = false;
      }

      return finalResult;
    } catch (Exception e) {
      System.debug('Error: ' + e.getMessage());
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Trả về ResponseLog để controller gọi FEC_CommonUltils.logApi sau khi call xong API.
   */
  public static ResponseLog getResponseLog() {
    return responseLog;
  }

  // ==========================================
  // PARSE RESPONSE
  // ==========================================
  public static PhoneCheckResult parseResponse(String xml, Integer httpStatus) {
    PhoneCheckResult result = new PhoneCheckResult();
    result.httpStatus = httpStatus;
    result.rawResponse = xml;

    if (xml == null) {
      result.errorMessage = System.Label.FEC_MSG_Response_Null;
      result.success = false;
      return result;
    }

    try {
      Dom.Document doc = new Dom.Document();
      doc.load(xml);

      Dom.XmlNode envelope = doc.getRootElement();
      Dom.XmlNode body = envelope.getChildElement(
        'Body',
        'http://schemas.xmlsoap.org/soap/envelope/'
      );

      if (body == null) {
        result.errorMessage = System.Label.FEC_MSG_Response_Null;
        result.success = false;
        return result;
      }

      Dom.XmlNode responseNode = body.getChildElement(
        'GetRemovablePhoneStatusResponse',
        PHONE_CHECK_NS
      );

      if (responseNode == null) {
        for (Dom.XmlNode n : body.getChildElements()) {
          if (n.getName().endsWith('GetRemovablePhoneStatusResponse')) {
            responseNode = n;
            break;
          }
        }
      }

      if (responseNode == null) {
        result.errorMessage = System.Label.FEC_MSG_Response_Null;
        result.success = false;
        return result;
      }

      Dom.XmlNode sys = responseNode.getChildElement('Sys', null);

      if (sys != null) {
        Dom.XmlNode t = sys.getChildElement('TransID', null);
        Dom.XmlNode dt = sys.getChildElement('DateTime', null);
        Dom.XmlNode c = sys.getChildElement('Code', null);
        Dom.XmlNode d = sys.getChildElement('Description', null);

        result.transId = (t != null) ? t.getText() : null;
        result.dateTimeStr = (dt != null) ? dt.getText() : null;
        result.code = (c != null) ? c.getText() : null;
        result.description = (d != null) ? d.getText() : null;

        // 1 = eligible, 2 = not eligible, 3 = data not found
        result.success = (result.code == '1');
        result.errorMessage = result.success ? null : result.description;
      } else {
        result.errorMessage = System.Label.FEC_MSG_Response_Sys_Null;
        result.success = false;
      }
    } catch (Exception ex) {
      result.errorMessage = String.format(
        System.Label.FEC_MSG_Parse_XML_Error,
        new List<String>{ex.getMessage()}
      );
      result.success = false;
    }

    return result;
  }
}
