public with sharing class FEC_UpdateCustomerContact {
  public static final String PHONE_UPDATE = 'Phone Update';
  public static final String EMAIL_UPDATE = 'Email Update';
  public static final String API_NAME = 'FEC_UpdateCustomerContact';
  public static final String API_NAME_CONTACT_LIST_MATCH =
    API_NAME + '_ContactListMatch';
  public static FEC_ResponseLog responseLog;

  public class ContactListMatchResult {
    public List<FEC_Contact_List__c> matches;
    public String diagnosticDetail;
    public String matchStrategy;
  }

  @TestVisible
  private class ContactListPickResult {
    public List<FEC_Contact_List__c> matches;
    public String strategy;
  }

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
        result.transId = (t != null) ? t.getText().trim() : null;
        result.dateTimeStr = (dt != null) ? dt.getText().trim() : null;
        result.code = (c != null) ? c.getText().trim() : null;
        result.description = (d != null) ? d.getText().trim() : null;
        // 01/06/2026 linhdev - API trả Code=1 (SUCCESSFULLY UPDATED); trim Code để LWC nhận success=true
        result.success = (FEC_ConstantCommon.SUCCESS_STATUS_CODE.equals(
          result.code
        ) ||
        FEC_ConstantCommon.SUCCESS_CODE_1.equals(result.code) ||
        FEC_ConstantCommon.SUCCESS_CODE_4.equals(result.code));
        result.errorMessage = result.success ? null : result.description;
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
    String endpoint = '';
    String method = FEC_ConstantCommon.API_METHOD_POST;
    try {
      FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
      FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Update_Customer_Contact');
      endpoint = apiSetting?.FEC_Call_Mock__c
        ? FEC_MockupEndpoint.UPDATE_CUSTOMER_CONTACT_ENDPOINT_MOCKUP
        : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
      HttpResponse res = sendRequest(envelope);
      responseLog = new FEC_ResponseLog(
        API_NAME,
        endpoint,
        method,
        envelope,
        res,
        null
      );
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
      if (responseLog != null) {
        responseLog.errorMessage = ex.getMessage();
      } else {
        responseLog = new FEC_ResponseLog(
          API_NAME,
          endpoint,
          method,
          envelope,
          null,
          ex.getMessage()
        );
      }
      finalResult.errorMessage = ex.getMessage();
      finalResult.success = false;
    }
    return finalResult;
  }

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
      responseLog = null;
    }
  }

  // 01/06/2026 linhdev - FEC_Contact_List__c.FEC_Communication_Type__c có nhiều giá trị (Primary/Work/Actual/Home Phone/Mobile...)
  @TestVisible
  private static Boolean isEmailCommunicationType(String commType) {
    if (String.isBlank(commType)) {
      return false;
    }
    return FEC_ConstantCommon.EMAIL.equalsIgnoreCase(commType.trim());
  }

  @TestVisible
  private static Boolean isPhoneCommunicationType(String commType) {
    if (String.isBlank(commType) || isEmailCommunicationType(commType)) {
      return false;
    }
    String trimmed = commType.trim();
    if (FEC_ConstantCommon.COMMUNICATION_TYPE_MOBILE.equalsIgnoreCase(trimmed)) {
      return true;
    }
    return trimmed.toLowerCase().contains('phone');
  }

  @TestVisible
  private static Boolean communicationTypesMatch(String expected, String actual) {
    if (String.isBlank(expected)) {
      return true;
    }
    if (String.isBlank(actual)) {
      return false;
    }
    return expected.trim().equalsIgnoreCase(actual.trim());
  }

  @TestVisible
  private static Boolean contactPhonesMatch(String casePhone, String contactPhone) {
    if (String.isBlank(casePhone) || String.isBlank(contactPhone)) {
      return false;
    }
    if (casePhone.trim() == contactPhone.trim()) {
      return true;
    }
    String normCase = FEC_CommonUltils.normalizePhone(casePhone);
    String normContact = FEC_CommonUltils.normalizePhone(contactPhone);
    if (String.isNotBlank(normCase) && normCase == normContact) {
      return true;
    }
    if (casePhone.contains('*')) {
      String digitsCase = casePhone.replaceAll('[^0-9]', '');
      String digitsContact = contactPhone.replaceAll('[^0-9]', '');
      if (digitsCase.length() >= 7 && digitsContact.length() >= 7) {
        String casePrefix = digitsCase.substring(0, Math.min(5, digitsCase.length()));
        String caseSuffix = digitsCase.substring(digitsCase.length() - 3);
        return digitsContact.startsWith(casePrefix) && digitsContact.endsWith(caseSuffix);
      }
    }
    return false;
  }

  // 13/06/2026 linhdev - Internal_Case gửi Channel=Internal; Customer_Case gửi FEC_Channel__c
  @TestVisible
  private static String resolveChannelForApi(Case selectedCase) {
    if (
      selectedCase.RecordType != null &&
      FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME.equals(
        selectedCase.RecordType.DeveloperName
      )
    ) {
      return FEC_ConstantCommon.CHANNEL_INTERNAL;
    }
    return selectedCase.FEC_Channel__c;
  }

  @TestVisible
  private static Boolean isMobileCommunicationType(String commType) {
    return String.isNotBlank(commType) &&
      FEC_ConstantCommon.COMMUNICATION_TYPE_MOBILE.equalsIgnoreCase(commType.trim());
  }

  @TestVisible
  private static Decimal parseContactIdAsDecimal(String contactId) {
    if (String.isBlank(contactId)) {
      return null;
    }
    try {
      return Decimal.valueOf(contactId.trim());
    } catch (Exception e) {
      return null;
    }
  }

  @TestVisible
  private static FEC_Contact_List__c pickLargestContactIdMatch(
    List<FEC_Contact_List__c> rows
  ) {
    if (rows == null || rows.isEmpty()) {
      return null;
    }
    FEC_Contact_List__c bestNumeric = null;
    Decimal bestNumericId = null;
    FEC_Contact_List__c bestText = null;
    String bestTextId = null;
    for (FEC_Contact_List__c row : rows) {
      Decimal idNum = parseContactIdAsDecimal(row.FEC_Contact_ID__c);
      if (idNum != null) {
        if (bestNumericId == null || idNum > bestNumericId) {
          bestNumericId = idNum;
          bestNumeric = row;
        }
        continue;
      }
      if (String.isBlank(row.FEC_Contact_ID__c)) {
        continue;
      }
      String idText = row.FEC_Contact_ID__c.trim();
      if (bestTextId == null || idText.compareTo(bestTextId) > 0) {
        bestTextId = idText;
        bestText = row;
      }
    }
    return bestNumeric != null ? bestNumeric : bestText;
  }

  private static ContactListPickResult findMobileContactMatch(
    List<FEC_Contact_List__c> rows,
    String originalPhone
  ) {
    ContactListPickResult result = new ContactListPickResult();
    result.matches = new List<FEC_Contact_List__c>();
    if (rows == null || rows.isEmpty() || String.isBlank(originalPhone)) {
      return result;
    }
    List<FEC_Contact_List__c> mobileMatches = new List<FEC_Contact_List__c>();
    for (FEC_Contact_List__c row : rows) {
      if (
        isMobileCommunicationType(row.FEC_Communication_Type__c) &&
        contactPhonesMatch(originalPhone, row.FEC_Contact_String__c)
      ) {
        mobileMatches.add(row);
      }
    }
    FEC_Contact_List__c best = pickLargestContactIdMatch(mobileMatches);
    if (best != null) {
      result.matches = new List<FEC_Contact_List__c>{ best };
      result.strategy = 'mobile_original_phone_match';
    }
    return result;
  }

  private static ContactListPickResult findEmailContactMatch(
    List<FEC_Contact_List__c> rows,
    String originalEmail
  ) {
    ContactListPickResult result = new ContactListPickResult();
    result.matches = new List<FEC_Contact_List__c>();
    if (rows == null || rows.isEmpty() || String.isBlank(originalEmail)) {
      return result;
    }
    List<FEC_Contact_List__c> emailMatches = new List<FEC_Contact_List__c>();
    String normalizedOriginal = originalEmail.trim();
    for (FEC_Contact_List__c row : rows) {
      if (
        isEmailCommunicationType(row.FEC_Communication_Type__c) &&
        String.isNotBlank(row.FEC_Contact_String__c) &&
        normalizedOriginal == row.FEC_Contact_String__c.trim()
      ) {
        emailMatches.add(row);
      }
    }
    FEC_Contact_List__c best = pickLargestContactIdMatch(emailMatches);
    if (best != null) {
      result.matches = new List<FEC_Contact_List__c>{ best };
      result.strategy = 'email_original_email_match';
    }
    return result;
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
    } else if (!FEC_CommonUltils.isLengthValid(req.Channel, 255)) {
      throw new FEC_APIServiceException(
        String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'Channel', '255'})
      );
    }

    if (String.isBlank(req.CommunicationType)) {
      throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CommunicationType'}));
    } else {
      Boolean isPhoneCommType = isPhoneCommunicationType(req.CommunicationType);
      Boolean isEmailCommType = isEmailCommunicationType(req.CommunicationType);
      // 01/06/2026 linhdev - chấp nhận mọi loại *Phone* từ FEC_Contact_List__c (Work Phone, Actual/Home Phone...)
      if (!isPhoneCommType && !isEmailCommType) {
        throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Invalid, new List<String>{'CommunicationType'}));
      }
      if (
        (isPhoneCommType &&
        !(FEC_CommonUltils.isPhone(req.ContactString))) ||
        (isEmailCommType &&
        !FEC_CommonUltils.isMail(req.ContactString))
      ) {
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
        FEC_Original_Info_Phone_Number__c,
        FEC_Original_Info_Email__c,
        FEC_Original_Info_Phone_Type__c,
        FEC_Updated_Info_Phone_Type__c,
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
    UpdateContactResult result;
    try {
      CustomerContactRequest req = new CustomerContactRequest();
      if (selectedCase.FEC_Account_or_Contract__r != null) {
        req.CIFNumber = selectedCase.FEC_Account_or_Contract__r.FEC_CIF_Number__c;
      } else {
        throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{'Customer History'}));
      }

      ContactListMatchResult matchResult = findMatchingContactList(
        selectedCase,
        method
      );
      List<FEC_Contact_List__c> contactlst = matchResult.matches;

      if (!contactlst.isEmpty()) {
        FEC_Contact_List__c matched = contactlst.get(0);
        req.ContactId = matched.FEC_Contact_ID__c;
        req.Channel = matched.FEC_Channel__c;
        req.CommunicationType = matched.FEC_Communication_Type__c;
        if (String.isBlank(req.Channel)) {
          throw new FEC_APIServiceException(
            String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Channel'})
          );
        }
        if (String.isBlank(req.CommunicationType)) {
          throw new FEC_APIServiceException(
            String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CommunicationType'})
          );
        }
        req.ContactString = PHONE_UPDATE.equals(method)
          ? selectedCase.FEC_Updated_Info_Phone_Number__c
          : selectedCase.FEC_Updated_Info_Email__c;
        // 01/06/2026 linhdev - gửi SĐT/email Updated lên CIF; ContactId/CIF lấy từ Contact List + History
        if (String.isBlank(req.ContactString)) {
          throw new FEC_APIServiceException(
            String.format(
              System.Label.FEC_MSG_Param_Required,
              new List<String>{ PHONE_UPDATE.equals(method) ? 'Updated Phone' : 'Updated Email' }
            )
          );
        }
      } else {
        logContactListMatchFailure(
          selectedCase,
          method,
          matchResult
        );
        throw new FEC_APIServiceException(
          String.format(System.Label.FEC_MSG_Not_Found, new List<String>{'Matching FEC_Contact_List__c'})
        );
      }

      try {
        result = updateCustomerContact(req);
      } finally {
        logApiResponse();
      }

      if (result.success == true) {
        selectedCase.FEC_Process_Action_Count__c = -1;
      } else {
        if (selectedCase.FEC_Process_Action_Count__c == null) {
          selectedCase.FEC_Process_Action_Count__c = 0;
        }
        selectedCase.FEC_Process_Action_Count__c += 1;
      }
    } catch (Exception ex) {
      if (selectedCase.FEC_Process_Action_Count__c == null) {
        selectedCase.FEC_Process_Action_Count__c = 0;
      }
      selectedCase.FEC_Process_Action_Count__c += 1;
      update selectedCase;
      FEC_CommonUltils.createProcessActionHistory(
        method,
        selectedCase,
        false
      );
      if (ex instanceof FEC_APIServiceException) {
        throw (FEC_APIServiceException) ex;
      }
      throw ex;
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
   * @description Tìm FEC_Contact_List__c theo Interface Mapping.
   *              Phone Update: FEC_Original_Info_Phone_Number__c khớp FEC_Contact_String__c,
   *              FEC_Communication_Type__c = Mobile; trùng thì lấy FEC_Contact_ID__c lớn nhất.
   *              Email Update: FEC_Original_Info_Email__c khớp FEC_Contact_String__c,
   *              FEC_Communication_Type__c = Email; trùng thì lấy FEC_Contact_ID__c lớn nhất.
   */
  public static List<FEC_Contact_List__c> getMatchingContactList(
    Case selectedCase,
    String method
  ) {
    return findMatchingContactList(selectedCase, method).matches;
  }

  @TestVisible
  private static ContactListMatchResult findMatchingContactList(
    Case selectedCase,
    String method
  ) {
    ContactListMatchResult result = new ContactListMatchResult();
    result.matches = new List<FEC_Contact_List__c>();
    List<String> diagLines = new List<String>();
    diagLines.add('method=' + method);
    diagLines.add('caseId=' + selectedCase.Id);

    Id accountOrContractId = selectedCase.FEC_Account_or_Contract__c;
    diagLines.add('customerHistoryId=' + accountOrContractId);
    if (accountOrContractId == null) {
      diagLines.add('reason=Case.FEC_Account_or_Contract__c is blank');
      result.diagnosticDetail = String.join(diagLines, '; ');
      return result;
    }

    Boolean isPhoneMethod = PHONE_UPDATE.equals(method);
    if (!isPhoneMethod && !EMAIL_UPDATE.equals(method)) {
      diagLines.add('reason=Unsupported method');
      result.diagnosticDetail = String.join(diagLines, '; ');
      return result;
    }

    diagLines.add(
      'expectedCommType=' +
      (isPhoneMethod
        ? FEC_ConstantCommon.COMMUNICATION_TYPE_MOBILE
        : FEC_ConstantCommon.EMAIL)
    );

    diagLines.add(
      'cifNumber=' +
      formatCifNumberForLog(resolveCustomerHistoryCif(accountOrContractId))
    );

    String originalContactString;
    String caseOriginalContactString;
    if (isPhoneMethod) {
      originalContactString = selectedCase.FEC_Original_Info_Phone_Number__c;
      caseOriginalContactString = originalContactString;
      diagLines.add(
        'caseOriginalPhone=' +
        formatContactStringForLog(caseOriginalContactString, true)
      );
      diagLines.add(
        'caseUpdatedPhone=' +
        formatContactStringForLog(
          readCaseStringFieldIfQueried(
            selectedCase,
            'FEC_Updated_Info_Phone_Number__c'
          ),
          true
        )
      );
    } else {
      originalContactString = selectedCase.FEC_Original_Info_Email__c;
      caseOriginalContactString = originalContactString;
      diagLines.add(
        'caseOriginalEmail=' +
        formatContactStringForLog(caseOriginalContactString, false)
      );
      diagLines.add(
        'caseUpdatedEmail=' +
        formatContactStringForLog(
          readCaseStringFieldIfQueried(
            selectedCase,
            'FEC_Updated_Info_Email__c'
          ),
          false
        )
      );
    }

    diagLines.add(
      'matchOriginalString=' +
      formatContactStringForLog(originalContactString, isPhoneMethod)
    );

    List<FEC_Contact_List__c> rows = [
      SELECT
        Id,
        FEC_Customer_History__c,
        FEC_Communication_Type__c,
        FEC_Channel__c,
        FEC_Contact_ID__c,
        FEC_Contact_String__c
      FROM FEC_Contact_List__c
      WHERE FEC_Customer_History__c = :accountOrContractId
    ];
    diagLines.add('totalContactListRows=' + rows.size());

    Integer eligibleTypeRowCount = 0;
    Integer contactStringMatchEligibleTypeCount = 0;
    Integer contactStringMatchAnyCommTypeCount = 0;
    List<String> allRowSummaries = new List<String>();
    List<String> eligibleRowSummaries = new List<String>();
    List<String> wrongCommTypeButContactStringMatch = new List<String>();
    for (FEC_Contact_List__c row : rows) {
      Boolean acceptedAsCandidate = isPhoneMethod
        ? isMobileCommunicationType(row.FEC_Communication_Type__c)
        : isEmailCommunicationType(row.FEC_Communication_Type__c);
      Boolean contactStringMatch = contactStringMatchesForMethod(
        isPhoneMethod,
        originalContactString,
        row.FEC_Contact_String__c
      );
      if (acceptedAsCandidate) {
        eligibleTypeRowCount++;
        eligibleRowSummaries.add(
          summarizeContactListRow(
            row,
            isPhoneMethod,
            true,
            originalContactString
          )
        );
        if (contactStringMatch) {
          contactStringMatchEligibleTypeCount++;
        }
      }
      if (contactStringMatch) {
        contactStringMatchAnyCommTypeCount++;
        if (!acceptedAsCandidate) {
          wrongCommTypeButContactStringMatch.add(
            summarizeContactListRow(
              row,
              isPhoneMethod,
              false,
              originalContactString
            )
          );
        }
      }
      allRowSummaries.add(
        summarizeContactListRow(
          row,
          isPhoneMethod,
          acceptedAsCandidate,
          originalContactString
        )
      );
    }
    diagLines.add('eligibleTypeRowCount=' + eligibleTypeRowCount);
    diagLines.add(
      'contactStringMatchEligibleTypeCount=' + contactStringMatchEligibleTypeCount
    );
    diagLines.add(
      'contactStringMatchAnyCommTypeCount=' + contactStringMatchAnyCommTypeCount
    );
    diagLines.add('allContactListRows=' + String.join(allRowSummaries, ' | '));
    if (!eligibleRowSummaries.isEmpty()) {
      diagLines.add('eligibleTypeRows=' + String.join(eligibleRowSummaries, ' | '));
    }
    if (!wrongCommTypeButContactStringMatch.isEmpty()) {
      diagLines.add(
        'wrongCommTypeButContactStringMatch=' +
        String.join(wrongCommTypeButContactStringMatch, ' | ')
      );
    }

    ContactListPickResult pickResult = isPhoneMethod
      ? findMobileContactMatch(rows, originalContactString)
      : findEmailContactMatch(rows, originalContactString);
    result.matches = pickResult.matches;
    result.matchStrategy = pickResult.strategy;
    if (result.matches.isEmpty()) {
      if (rows.isEmpty()) {
        diagLines.add('reason=No FEC_Contact_List__c on Customer History');
      } else if (String.isBlank(originalContactString)) {
        diagLines.add('reason=Original contact string on Case is blank');
      } else if (isPhoneMethod) {
        diagLines.add(
          'reason=No Mobile FEC_Contact_List__c matches FEC_Original_Info_Phone_Number__c'
        );
      } else {
        diagLines.add(
          'reason=No Email FEC_Contact_List__c matches FEC_Original_Info_Email__c'
        );
      }
    } else {
      diagLines.add('matchStrategy=' + pickResult.strategy);
      FEC_Contact_List__c matched = result.matches[0];
      diagLines.add(
        'matchedRow=' +
        summarizeContactListRow(matched, isPhoneMethod, true, originalContactString)
      );
    }
    result.diagnosticDetail = String.join(diagLines, '; ');
    return result;
  }

  private static String readCaseStringFieldIfQueried(
    Case selectedCase,
    String fieldApiName
  ) {
    if (selectedCase == null || String.isBlank(fieldApiName)) {
      return null;
    }
    Map<String, Object> populatedFields = selectedCase.getPopulatedFieldsAsMap();
    if (!populatedFields.containsKey(fieldApiName)) {
      return null;
    }
    Object value = populatedFields.get(fieldApiName);
    return value == null ? null : String.valueOf(value);
  }

  @TestVisible
  private static String resolveCustomerHistoryCif(Id customerHistoryId) {
    if (customerHistoryId == null) {
      return null;
    }
    List<FEC_Customer_History__c> historyRows = [
      SELECT FEC_CIF_Number__c
      FROM FEC_Customer_History__c
      WHERE Id = :customerHistoryId
      LIMIT 1
    ];
    return historyRows.isEmpty() ? null : historyRows[0].FEC_CIF_Number__c;
  }

  private static String formatCifNumberForLog(String cifNumber) {
    return String.isBlank(cifNumber) ? '(blank)' : cifNumber;
  }

  @TestVisible
  private static Boolean contactStringMatchesForMethod(
    Boolean isPhoneMethod,
    String originalContactString,
    String contactListString
  ) {
    if (String.isBlank(originalContactString) || String.isBlank(contactListString)) {
      return false;
    }
    if (isPhoneMethod) {
      return contactPhonesMatch(originalContactString, contactListString);
    }
    return originalContactString.trim() == contactListString.trim();
  }

  private static String formatContactStringForLog(
    String value,
    Boolean isPhoneMethod
  ) {
    if (String.isBlank(value)) {
      return '(blank)';
    }
    if (isPhoneMethod) {
      return FEC_CommonUltils.maskPhone(value);
    }
    Integer atIdx = value.indexOf('@');
    if (atIdx > 1) {
      return value.substring(0, 2) + '***' + value.substring(atIdx);
    }
    return '***';
  }

  private static String summarizeContactListRow(
    FEC_Contact_List__c row,
    Boolean isPhoneMethod,
    Boolean acceptedAsCandidate,
    String originalContactString
  ) {
    Boolean contactStringMatch = contactStringMatchesForMethod(
      isPhoneMethod,
      originalContactString,
      row.FEC_Contact_String__c
    );
    return '{ContactListId=' +
      row.Id +
      ',ContactId=' +
      row.FEC_Contact_ID__c +
      ',Channel=' +
      row.FEC_Channel__c +
      ',CommType=' +
      row.FEC_Communication_Type__c +
      ',ContactString=' +
      formatContactStringForLog(row.FEC_Contact_String__c, isPhoneMethod) +
      ',ContactStringMatch=' +
      contactStringMatch +
      ',MobileTypeAccepted=' +
      isMobileCommunicationType(row.FEC_Communication_Type__c) +
      ',EmailTypeAccepted=' +
      isEmailCommunicationType(row.FEC_Communication_Type__c) +
      ',AcceptedAsCandidate=' +
      acceptedAsCandidate +
      '}';
  }

  private static void logContactListMatchFailure(
    Case selectedCase,
    String method,
    ContactListMatchResult matchResult
  ) {
    String diagnosticDetail = matchResult != null
      ? matchResult.diagnosticDetail
      : '';
    String logMessage =
      'Matching FEC_Contact_List__c not found. ' + diagnosticDetail;
    String cifNumber = resolveCustomerHistoryCif(
      selectedCase.FEC_Account_or_Contract__c
    );
    String endpoint =
      'CaseId=' +
      selectedCase.Id +
      ';CustomerHistoryId=' +
      selectedCase.FEC_Account_or_Contract__c +
      ';CIF=' +
      formatCifNumberForLog(cifNumber);
    System.debug(LoggingLevel.WARN, API_NAME_CONTACT_LIST_MATCH + ': ' + logMessage);
    FEC_CommonUltils.logApi(
      API_NAME_CONTACT_LIST_MATCH,
      endpoint,
      method,
      diagnosticDetail,
      null,
      logMessage
    );
  }
}
