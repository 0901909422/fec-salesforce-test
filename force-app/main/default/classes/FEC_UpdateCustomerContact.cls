public with sharing class FEC_UpdateCustomerContact {
  public static final String PHONE_UPDATE = 'Phone Update';
  public static final String EMAIL_UPDATE = 'Email Update';

  public class CustomerContactRequest {
    public String CIFNumber;
    public String ContactId;
    public String Channel;
    public String CommunicationType;
    public String ContactString;
    public String OfficeExtension;
    public String ReceiveStatement;
  }

  public class UpdateContactResult {
    @AuraEnabled
    public String transId;

    @AuraEnabled
    public String dateTimeStr;

    @AuraEnabled
    public String code;

    @AuraEnabled
    public String description;

    @AuraEnabled
    public Integer httpStatus;

    @AuraEnabled
    public String rawResponse;

    @AuraEnabled
    public Boolean success;

    @AuraEnabled
    public String errorMessage;

    @AuraEnabled
    public Decimal actionCount;
  }

  public static String generateTransId() {
    return String.valueOf(UUID.randomUUID());
  }

  public static String formatTimestamp() {
    return Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT);
  }

  private static String escapeXml(String s) {
    if (s == null)
      return '';
    return s.replace('&', '&amp;')
      .replace('<', '&lt;')
      .replace('>', '&gt;')
      .replace('"', '&quot;')
      .replace('\'', '&apos;');
  }

  public static String buildEnvelope(
    CustomerContactRequest req,
    String transId,
    String timestamp
  ) {
    validate(req, transId, timestamp);

    String env = '';
    env += '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">';
    env += '<soapenv:Header/>';
    env += '<soapenv:Body>';
    env += '<cif:UpdateCustomerContact>';
    env += '<Sys>';
    env += '<TransID>' + escapeXml(transId) + '</TransID>';
    env += '<RequestorID>' + escapeXml(FEC_ConstantCommon.REQUESTOR_APS) + '</RequestorID>';
    env += '<DateTime>' + escapeXml(timestamp) + '</DateTime>';
    env += '</Sys>';
    env += '<CIFNumber>' + escapeXml(req.CIFNumber) + '</CIFNumber>';
    env += '<Contact>';

    if (String.isNotBlank(req.ContactId))
      env += '<ContactId>' + escapeXml(req.ContactId) + '</ContactId>';

    env += '<Channel>' + escapeXml(req.Channel) + '</Channel>';
    env +=
      '<CommunicationType>' +
      escapeXml(req.CommunicationType) +
      '</CommunicationType>';
    if (req.ContactString != null)
      env +=
        '<ContactString>' +
        escapeXml(req.ContactString) +
        '</ContactString>';

    if (String.isNotBlank(req.OfficeExtension))
      env +=
        '<OfficeExtension>' +
        escapeXml(req.OfficeExtension) +
        '</OfficeExtension>';
    if (String.isNotBlank(req.ReceiveStatement))
      env +=
        '<ReceiveStatement>' +
        escapeXml(req.ReceiveStatement) +
        '</ReceiveStatement>';
    env += '</Contact>';
    env += '</cif:UpdateCustomerContact>';
    env += '</soapenv:Body>';
    env += '</soapenv:Envelope>';
    return env;
  }

  public static HttpResponse sendRequest(String envelope) {
    FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
    FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Update_Customer_Contact');

    String endpoint = apiSetting?.FEC_Call_Mock__c
        ? FEC_MockupEndpoint.UPDATE_CUSTOMER_CONTACT_ENDPOINT_MOCKUP
        : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
    HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, FEC_ConstantCommon.API_METHOD_POST, FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, envelope);
    return res;
  }

  public static UpdateContactResult parseResponse(
    String xml,
    Integer httpStatus
  ) {
    UpdateContactResult result = new UpdateContactResult();
    result.httpStatus = httpStatus;
    result.rawResponse = xml;
    if (xml == null) {
      result.errorMessage = 'Empty response body';
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
        result.errorMessage = 'No SOAP Body';
        result.success = false;
        return result;
      }
      Dom.XmlNode responseNode = body.getChildElement(
        'UpdateCustomerContactResponse',
        'http://fecredit.com.vn/CIF_CustomerInfoUpdate'
      );
      if (responseNode == null) {
        for (Dom.XmlNode n : body.getChildElements()) {
          if (n.getName().endsWith('UpdateCustomerContactResponse')) {
            responseNode = n;
            break;
          }
        }
      }
      if (responseNode == null) {
        result.errorMessage = 'No UpdateCustomerContactResponse found';
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
        result.success = (result.code == '0' || result.code == '4');
      } else {
        result.errorMessage = 'No Sys node in response';
        result.success = false;
      }
    } catch (Exception ex) {
      result.errorMessage = 'XML parse error: ' + ex.getMessage();
      result.success = false;
    }
    return result;
  }

  @AuraEnabled
  public static UpdateContactResult updateCustomerContact(
    CustomerContactRequest req
  ) {
    UpdateContactResult finalResult = new UpdateContactResult();
    String transId = generateTransId();
    String timestamp = formatTimestamp();
    String envelope = buildEnvelope(req, transId, timestamp);
    try {
      HttpResponse res = sendRequest(envelope);
      Integer status = (res == null) ? null : res.getStatusCode();
      String body = (res == null) ? null : res.getBody();
      finalResult = parseResponse(body, status);
      if (finalResult.transId == null)
        finalResult.transId = transId;
      if (finalResult.httpStatus == null)
        finalResult.httpStatus = status;
      if (finalResult.rawResponse == null)
        finalResult.rawResponse = body;
    } catch (Exception ex) {
      finalResult.errorMessage = 'Callout error: ' + ex.getMessage();
      finalResult.success = false;
    }
    return finalResult;
  }

  private static void validate(
    CustomerContactRequest req,
    String transId,
    String timestamp
  ) {
    if (String.isBlank(transId) || transId.length() > 36) {
      throw new FEC_APIServiceException(System.Label.FEC_MSG_TransID_Null);
    }

    if (String.isBlank(timestamp)) {
      throw new FEC_APIServiceException(System.Label.FEC_MSG_Datetime_Null);
    }

    if (String.isBlank(req.CIFNumber)) {
      throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CIFNumber'}));
    } else if (!FEC_CommonUltils.isLengthValid(req.CIFNumber, 255)) {
      throw new FEC_APIServiceException(
        String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'CIFNumber', '255'})
      );
    }

    if (String.isBlank(req.Channel)) {
      throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Channel'}));
    } else {
      List<FEC_CommonUltils.PicklistOption> channelOptionlst = FEC_CommonUltils.getPicklistOptions(
        'Case',
        'FEC_Channel__c'
      );

      Set<String> validChannellst = new Set<String>();
      for (FEC_CommonUltils.PicklistOption option : channelOptionlst) {
        validChannellst.add(option.value);
      }

      if (!validChannellst.contains(req.Channel)) {
        throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Invalid, new List<String>{'Channel'}));
      }
    }

    if (String.isBlank(req.CommunicationType)) {
      throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CommunicationType'}));
    } else {
      Set<String> validTypelst = new Set<String>{ 'Primary Phone', 'Email' };

      if (!validTypelst.contains(req.CommunicationType)) {
        throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Invalid, new List<String>{'CommunicationType'}));
      }

      if (
        ('Primary Phone'.equals(req.CommunicationType) &&
        !(FEC_CommonUltils.isPhone(req.ContactString)) ||
        ('Email'.equals(req.CommunicationType) &&
        !FEC_CommonUltils.isMail(req.ContactString)))
      ) {
        // valid
        throw new FEC_APIServiceException(
          String.format(System.Label.FEC_MSG_Invalid, new List<String>{'ContactString'})
        );
      }
    }
  }

  public static UpdateContactResult updateValue(String caseId, String method) {
    List<Case> caselst = [
      SELECT
        Id,
        FEC_Channel__c,
        FEC_Updated_Info_Phone_Number__c,
        FEC_Updated_Info_Email__c,
        FEC_Account_or_Contract__r.FEC_CIF_Number__c,
        FEC_Process_Action_Count__c
      FROM Case
      WHERE Id = :caseId
    ];

    if (caselst.isEmpty()) {
      throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{'Case Id'}));
    }

    Case selectedCase = caselst.get(0);
    CustomerContactRequest req = new CustomerContactRequest();
    req.CIFNumber = selectedCase.FEC_Account_or_Contract__r?.FEC_CIF_Number__c;

    req.Channel = selectedCase.FEC_Channel__c;

    if (PHONE_UPDATE.equals(method)) {
      req.CommunicationType = 'Primary Phone';
      req.ContactString = selectedCase.FEC_Updated_Info_Phone_Number__c;
    } else if (EMAIL_UPDATE.equals(method)) {
      req.CommunicationType = 'Email';
      req.ContactString = selectedCase.FEC_Updated_Info_Email__c;
    }

    UpdateContactResult result = updateCustomerContact(req);

    if (result.success) {
      selectedCase.FEC_Process_Action_Count__c = -1;
    } else {
      if (selectedCase.FEC_Process_Action_Count__c == null) {
        selectedCase.FEC_Process_Action_Count__c = 0;
      }

      selectedCase.FEC_Process_Action_Count__c += 1;
    }

    update selectedCase;

    result.actionCount = selectedCase.FEC_Process_Action_Count__c;

    return result;
  }
}
// ...existing code...