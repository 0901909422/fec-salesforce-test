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

  // 01/06/2026 linhdev - FEC_Contact_List__c.FEC_Communication_Type__c có nhiều giá trị (Primary/Work/Actual/Home Phone/Mobile…)
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

  private static String resolveCommunicationTypeForApi(
    Case selectedCase,
    FEC_Contact_List__c matched,
    String method
  ) {
    if (PHONE_UPDATE.equals(method)) {
      if (
        matched != null &&
        isPhoneCommunicationType(matched.FEC_Communication_Type__c)
      ) {
        return matched.FEC_Communication_Type__c.trim();
      }
      if (isPhoneCommunicationType(selectedCase.FEC_Updated_Info_Phone_Type__c)) {
        return selectedCase.FEC_Updated_Info_Phone_Type__c.trim();
      }
      if (isPhoneCommunicationType(selectedCase.FEC_Original_Info_Phone_Type__c)) {
        return selectedCase.FEC_Original_Info_Phone_Type__c.trim();
      }
      return FEC_ConstantCommon.PRIMARY_PHONE;
    }
    if (
      matched != null &&
      isEmailCommunicationType(matched.FEC_Communication_Type__c)
    ) {
      return matched.FEC_Communication_Type__c.trim();
    }
    return FEC_ConstantCommon.EMAIL;
  }

  private static List<FEC_Contact_List__c> pickBestContactMatch(
    List<FEC_Contact_List__c> candidates,
    Case selectedCase,
    Boolean isPhoneMethod,
    String originalContactString,
    String originalCommType
  ) {
    if (candidates == null || candidates.isEmpty()) {
      return new List<FEC_Contact_List__c>();
    }
    FEC_Contact_List__c best = null;
    Integer bestScore = -1;
    for (FEC_Contact_List__c row : candidates) {
      Integer score = 0;
      if (isPhoneMethod) {
        if (contactPhonesMatch(originalContactString, row.FEC_Contact_String__c)) {
          score += 2;
        }
      } else if (
        String.isNotBlank(originalContactString) &&
        originalContactString.trim() == row.FEC_Contact_String__c
      ) {
        score += 2;
      }
      if (communicationTypesMatch(originalCommType, row.FEC_Communication_Type__c)) {
        score += 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = row;
      }
    }
    if (best != null && bestScore > 0) {
      return new List<FEC_Contact_List__c>{ best };
    }
    if (String.isNotBlank(originalCommType)) {
      for (FEC_Contact_List__c row : candidates) {
        if (communicationTypesMatch(originalCommType, row.FEC_Communication_Type__c)) {
          return new List<FEC_Contact_List__c>{ row };
        }
      }
    }
    if (candidates.size() == 1) {
      return candidates;
    }
    return new List<FEC_Contact_List__c>();
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
      Boolean isPhoneCommType = isPhoneCommunicationType(req.CommunicationType);
      Boolean isEmailCommType = isEmailCommunicationType(req.CommunicationType);
      // 01/06/2026 linhdev - chấp nhận mọi loại *Phone* từ FEC_Contact_List__c (Work Phone, Actual/Home Phone…)
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
        req.Channel = selectedCase.FEC_Channel__c;
        req.CommunicationType = resolveCommunicationTypeForApi(
          selectedCase,
          matched,
          method
        );
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
          selectedCase.Id,
          method,
          matchResult.diagnosticDetail
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
   * @description Tìm FEC_Contact_List__c theo Customer History, loại liên lạc (Phone/Email)
   *              và khớp SĐT/email + FEC_Communication_Type__c trên Case (Original Info).
   * @param selectedCase Case có FEC_Account_or_Contract__c; FEC_Original_Info_Phone_Type__c cho Phone Update.
   * @param method PHONE_UPDATE hoặc EMAIL_UPDATE.
   * @return Danh sách bản ghi khớp tốt nhất (0 hoặc 1 phần tử).
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

    String originalContactString;
    String originalCommType;
    String caseOriginalContactString;
    if (isPhoneMethod) {
      originalContactString = selectedCase.FEC_Original_Info_Phone_Number__c;
      caseOriginalContactString = originalContactString;
      originalCommType = selectedCase.FEC_Original_Info_Phone_Type__c;
      diagLines.add(
        'caseOriginalPhone=' +
        formatContactStringForLog(caseOriginalContactString, true)
      );
      diagLines.add('caseOriginalPhoneType=' + originalCommType);
    } else {
      originalContactString = selectedCase.FEC_Original_Info_Email__c;
      caseOriginalContactString = originalContactString;
      originalCommType = null;
      diagLines.add(
        'caseOriginalEmail=' +
        formatContactStringForLog(caseOriginalContactString, false)
      );
    }

    Boolean usedHistoryFallback = false;
    String historyPrimaryPhone;
    String historyEmail;
    if (String.isBlank(originalContactString)) {
      List<FEC_Customer_History__c> historyRows = [
        SELECT FEC_Email__c, FEC_Primary_Phone__c
        FROM FEC_Customer_History__c
        WHERE Id = :accountOrContractId
        LIMIT 1
      ];
      if (!historyRows.isEmpty()) {
        historyPrimaryPhone = historyRows[0].FEC_Primary_Phone__c;
        historyEmail = historyRows[0].FEC_Email__c;
        originalContactString = isPhoneMethod
          ? historyPrimaryPhone
          : historyEmail;
        usedHistoryFallback = true;
      }
    }
    diagLines.add('usedHistoryFallback=' + usedHistoryFallback);
    if (isPhoneMethod) {
      diagLines.add(
        'historyPrimaryPhone=' +
        formatContactStringForLog(historyPrimaryPhone, true)
      );
    } else {
      diagLines.add(
        'historyEmail=' + formatContactStringForLog(historyEmail, false)
      );
    }
    diagLines.add(
      'matchOriginalString=' +
      formatContactStringForLog(originalContactString, isPhoneMethod)
    );
    if (isPhoneMethod) {
      diagLines.add('matchOriginalPhoneType=' + originalCommType);
    }

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

    List<FEC_Contact_List__c> candidates = new List<FEC_Contact_List__c>();
    List<String> allRowSummaries = new List<String>();
    List<String> candidateSummaries = new List<String>();
    Set<Id> candidateIds = new Set<Id>();
    for (FEC_Contact_List__c row : rows) {
      Boolean accepted = false;
      if (isPhoneMethod && isPhoneCommunicationType(row.FEC_Communication_Type__c)) {
        candidates.add(row);
        candidateIds.add(row.Id);
        accepted = true;
      } else if (
        !isPhoneMethod &&
        isEmailCommunicationType(row.FEC_Communication_Type__c)
      ) {
        candidates.add(row);
        candidateIds.add(row.Id);
        accepted = true;
      }
      allRowSummaries.add(summarizeContactListRow(row, isPhoneMethod, accepted));
    }
    diagLines.add('candidateCount=' + candidates.size());
    for (FEC_Contact_List__c row : candidates) {
      candidateSummaries.add(summarizeContactListRow(row, isPhoneMethod, true));
    }
    diagLines.add('allContactListRows=' + String.join(allRowSummaries, ' | '));
    diagLines.add('candidates=' + String.join(candidateSummaries, ' | '));

    result.matches = pickBestContactMatch(
      candidates,
      selectedCase,
      isPhoneMethod,
      originalContactString,
      originalCommType
    );
    if (result.matches.isEmpty()) {
      if (rows.isEmpty()) {
        diagLines.add('reason=No FEC_Contact_List__c on Customer History');
      } else if (candidates.isEmpty()) {
        diagLines.add(
          'reason=No contact row with supported CommunicationType (Phone/Mobile/Email)'
        );
      } else if (candidates.size() > 1) {
        diagLines.add(
          'reason=Multiple candidates but no phone/email/type match and not a single candidate'
        );
      } else {
        diagLines.add('reason=Candidate scoring produced no match');
      }
    } else {
      FEC_Contact_List__c matched = result.matches[0];
      diagLines.add(
        'matchedRow=' +
        summarizeContactListRow(matched, isPhoneMethod, true)
      );
    }
    result.diagnosticDetail = String.join(diagLines, '; ');
    return result;
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
    Boolean acceptedAsCandidate
  ) {
    return '{ContactListId=' +
      row.Id +
      ',ContactId=' +
      row.FEC_Contact_ID__c +
      ',CommType=' +
      row.FEC_Communication_Type__c +
      ',ContactString=' +
      formatContactStringForLog(row.FEC_Contact_String__c, isPhoneMethod) +
      ',PhoneTypeAccepted=' +
      isPhoneCommunicationType(row.FEC_Communication_Type__c) +
      ',EmailTypeAccepted=' +
      isEmailCommunicationType(row.FEC_Communication_Type__c) +
      ',AcceptedAsCandidate=' +
      acceptedAsCandidate +
      '}';
  }

  private static void logContactListMatchFailure(
    String caseId,
    String method,
    String diagnosticDetail
  ) {
    String logMessage =
      'Matching FEC_Contact_List__c not found. ' + diagnosticDetail;
    System.debug(LoggingLevel.WARN, API_NAME_CONTACT_LIST_MATCH + ': ' + logMessage);
    FEC_CommonUltils.logApi(
      API_NAME_CONTACT_LIST_MATCH,
      'CaseId=' + caseId,
      method,
      diagnosticDetail,
      null,
      logMessage
    );
  }
}