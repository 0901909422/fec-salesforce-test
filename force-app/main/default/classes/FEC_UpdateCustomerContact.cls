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
        result.success = (FEC_ConstantCommon.SUCCESS_STATUS_CODE.equals(
          result.code
        ) ||
        FEC_ConstantCommon.SUCCESS_CODE_1.equals(result.code) ||
        FEC_ConstantCommon.SUCCESS_CODE_4.equals(result.code));
      } else {
        result.errorMessage = System.Label.FEC_MSG_Response_Sys_Null;
        result.success = false;
      }
    } catch (Exception ex) {
      result.errorMessage = String.format(System.Label.FEC_MSG_Parse_XML_Error, new List<String>{ex.getMessage()});
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
      finalResult.errorMessage = ex.getMessage();
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
      Set<String> validTypelst = new Set<String>{ FEC_ConstantCommon.PRIMARY_PHONE, FEC_ConstantCommon.PHONE, FEC_ConstantCommon.EMAIL };

      if (!validTypelst.contains(req.CommunicationType)) {
        throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Invalid, new List<String>{'CommunicationType'}));
      }

      Boolean isPhoneCommType = FEC_ConstantCommon.PRIMARY_PHONE.equals(req.CommunicationType) || FEC_ConstantCommon.PHONE.equals(req.CommunicationType);
      Boolean isEmailCommType = FEC_ConstantCommon.EMAIL.equals(req.CommunicationType);
      if (
        (isPhoneCommType &&
        !(FEC_CommonUltils.isPhone(req.ContactString))) ||
        (isEmailCommType &&
        !FEC_CommonUltils.isMail(req.ContactString))
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
        FEC_Account_or_Contract__c,
        FEC_Updated_Info_Phone_Number__c,
        FEC_Updated_Info_Email__c,
        FEC_Account_or_Contract__r.FEC_CIF_Number__c,
        FEC_Process_Action_Count__c,
        FEC_Current_Case_Stage__c,
        FEC_Current_Case_Stage__r.Name
      FROM Case
      WHERE Id = :caseId
    ];

    if (caselst.isEmpty()) {
      throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{'Case Id'}));
    }

    Case selectedCase = caselst.get(0);
    CustomerContactRequest req = new CustomerContactRequest();
    req.CIFNumber = selectedCase.FEC_Account_or_Contract__r?.FEC_CIF_Number__c;

    if (PHONE_UPDATE.equals(method)) {
      req.ContactString = selectedCase.FEC_Updated_Info_Phone_Number__c;
    } else if (EMAIL_UPDATE.equals(method)) {
      req.ContactString = selectedCase.FEC_Updated_Info_Email__c;
    }

    List<FEC_Contact_List__c> contactlst = getMatchingContactList(
      selectedCase,
      method
    );

    if (!contactlst.isEmpty()) {
      FEC_Contact_List__c matched = contactlst.get(0);
      req.ContactId = matched.FEC_Contact_ID__c;
      req.Channel = matched.FEC_Channel__c;
      req.CommunicationType = matched.FEC_Communication_Type__c;
    } else {
      throw new FEC_APIServiceException(
        String.format(System.Label.FEC_MSG_Not_Found, new List<String>{'Matching FEC_Contact_List__c'})
      );
    }

    UpdateContactResult result = updateCustomerContact(req);

    if (result.success) {
      selectedCase.FEC_Process_Action_Count__c = -1;
    } else {
      Decimal failedCount = selectedCase.FEC_Process_Action_Count__c;
      if (failedCount == null || failedCount < 0) {
        failedCount = 0;
      }
      selectedCase.FEC_Process_Action_Count__c = Math.min(3, failedCount + 1);
    }

    update selectedCase;

    result.actionCount = selectedCase.FEC_Process_Action_Count__c;

    FEC_CommonUltils.createProcessActionHistory(
      method,
      selectedCase,
      result.success
    );

    return result;
  }

  /**
   * @description Tìm FEC_Contact_List__c theo Customer History, kênh trên Case, loại liên lạc
   *              theo method (Phone/Email) và FEC_Contact_String__c trùng email/điện thoại gốc trên History.
   * @param selectedCase Case có FEC_Account_or_Contract__c = Id Customer History; FEC_Channel__c dùng để lọc.
   * @param method PHONE_UPDATE hoặc EMAIL_UPDATE.
   * @return Danh sách bản ghi khớp.
   */
  public static List<FEC_Contact_List__c> getMatchingContactList(
    Case selectedCase,
    String method
  ) {
    Id accountOrContractId = selectedCase.FEC_Account_or_Contract__c;

    String commTypeForQuery;
    if (PHONE_UPDATE.equals(method)) {
      commTypeForQuery = FEC_ConstantCommon.PHONE;
    } else if (EMAIL_UPDATE.equals(method)) {
      commTypeForQuery = FEC_ConstantCommon.EMAIL;
    } else {
      return new List<FEC_Contact_List__c>();
    }

    String caseChannel = selectedCase.FEC_Channel__c;

    String originalContactString;
    if (accountOrContractId != null) {
      List<FEC_Customer_History__c> historyRows = [
        SELECT FEC_Email__c, FEC_Primary_Phone__c
        FROM FEC_Customer_History__c
        WHERE Id = :accountOrContractId
        LIMIT 1
      ];
      if (!historyRows.isEmpty()) {
        originalContactString = EMAIL_UPDATE.equals(method)
          ? historyRows[0].FEC_Email__c
          : historyRows[0].FEC_Primary_Phone__c;
      }
    }

    if (String.isNotBlank(originalContactString)) {
      return [
        SELECT
          Id,
          FEC_Customer_History__c,
          FEC_Communication_Type__c,
          FEC_Channel__c,
          FEC_Contact_ID__c,
          FEC_Contact_String__c
        FROM FEC_Contact_List__c
        WHERE
          FEC_Customer_History__c = :accountOrContractId
          AND FEC_Communication_Type__c = :commTypeForQuery
          AND FEC_Channel__c = :caseChannel
          AND FEC_Contact_String__c = :originalContactString
      ];
    }

    return [
      SELECT
        Id,
        FEC_Customer_History__c,
        FEC_Communication_Type__c,
        FEC_Channel__c,
        FEC_Contact_ID__c,
        FEC_Contact_String__c
      FROM FEC_Contact_List__c
      WHERE
        FEC_Customer_History__c = :accountOrContractId
        AND FEC_Communication_Type__c = :commTypeForQuery
        AND FEC_Channel__c = :caseChannel
    ];
  }
}