/****************************************************************************************
 * File Name    : FEC_UpdateCustomerBasicInfo
 * Author       : Toannd61
 * Date         : 2025-12-15
 * Description  : Update data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   2.0      2025-12-13     Toannd61             Create
 
****************************************************************************************/

public with sharing class FEC_UpdateCustomerBasicInfo {
  public static final String FULLNAME_UPDATE = 'Full Name Update';
  public static final String DOB_UPDATE = 'Date of Birth Update';
  public static final String GENDER_UPDATE = 'Gender Update';

  private static final String CIF_NS = 'http://fecredit.com.vn/CIF_CustomerInfoUpdate';

  // Wrapper Input & Output giữ nguyên như cũ...
  public class CustomerBasicInfo {
    @AuraEnabled
    public String cifNumber { get; set; } // REQUIRED
    @AuraEnabled
    public String firstName { get; set; }
    @AuraEnabled
    public String middleName { get; set; }
    @AuraEnabled
    public String lastName { get; set; }
    @AuraEnabled
    public String fullName { get; set; }
    @AuraEnabled
    public String birthday { get; set; }
    @AuraEnabled
    public String gender { get; set; }
    // @AuraEnabled
    // public String nationalId { get; set; }
    // @AuraEnabled
    // public String email { get; set; }
  }

  public class UpdateResult {
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

  // ==========================================
  // MAIN METHOD
  // ==========================================
  @AuraEnabled
  public static UpdateResult updateCustomerBasicInfo(CustomerBasicInfo info) {
    try {
      // BƯỚC 0: VALIDATION
      validateInput(info);

      String transId = UUID.randomUUID().toString();
      String timestamp = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);

      // Bước 1: Tạo Request XML
      Dom.Document doc = new Dom.Document();
      Dom.XmlNode envelope = doc.createRootElement(
        'Envelope',
        FEC_ConstantCommon.SOAP_ENV,
        'soapenv'
      );
      envelope.addChildElement('Header', FEC_ConstantCommon.SOAP_ENV, null);

      Dom.XmlNode body = envelope.addChildElement('Body', FEC_ConstantCommon.SOAP_ENV, null);
      Dom.XmlNode requestNode = body.addChildElement(
        'UpdateCustomerBasicInfo',
        CIF_NS,
        'cif'
      );
      envelope.setNamespace('cif', CIF_NS);

      // --- SYS INFO ---
      Dom.XmlNode sysNode = requestNode.addChildElement('Sys', null, null);
      sysNode.addChildElement('TransID', null, null).addTextNode(transId);
      sysNode.addChildElement('RequestorID', null, null)
        .addTextNode(UUID.randomUUID().toString());
      sysNode.addChildElement('DateTime', null, null).addTextNode(timestamp);

      // --- CUSTOMER INFO ---
      Dom.XmlNode custNode = requestNode.addChildElement(
        'CustomerInfo',
        null,
        null
      );

      if (String.isNotBlank(info.cifNumber))
        addTextNodeSafe(custNode, 'CIFNumber', info.cifNumber);

      if (String.isNotBlank(info.firstName))
        addTextNodeSafe(custNode, 'FirstName', info.firstName);

      if (String.isNotBlank(info.middleName))
        addTextNodeSafe(custNode, 'MiddleName', info.middleName);

      if (String.isNotBlank(info.lastName))
        addTextNodeSafe(custNode, 'LastName', info.lastName);

      if (String.isNotBlank(info.fullName))
        addTextNodeSafe(custNode, 'FullName', info.fullName);

      String dobStr = '';
      if (info.birthday != null) {
        dobStr = String.valueOf(info.birthday);
        custNode.addChildElement('Birthday', null, null).addTextNode(dobStr);
      }

      if (String.isNotBlank(info.gender))
        addTextNodeSafe(custNode, 'Gender', info.gender);
      // addTextNodeSafe(custNode, 'NationalID', info.nationalId);
      // addTextNodeSafe(custNode, 'Email', info.email);

      UpdateResult finalResult = new UpdateResult();
      try {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Update_Customer_Basic_Info');

        String endpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.UPDATE_CUSTOMER_BASIC_INFO_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
        HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, FEC_ConstantCommon.API_METHOD_POST, FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, doc, '');

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
        finalResult.errorMessage = ex.getMessage();
        finalResult.success = false;
      }

      return finalResult;
    } catch (Exception e) {
      System.debug('Error: ' + e.getMessage());
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ==========================================
  // VALIDATION HELPERS
  // ==========================================
  private static void validateInput(CustomerBasicInfo info) {
    if (info == null) {
      throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Request Data'}));
    }

    if (String.isBlank(info.cifNumber)) {
      throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CifNumber'}));
    }

    if (String.isNotBlank(info.gender)) {
      List<FEC_CommonUltils.PicklistOption> genderOptionlst = FEC_CommonUltils.getPicklistOptions(
        'Case',
        'FEC_Updated_Info_Gender__c'
      );

      Set<String> validGenderlst = new Set<String>();
      for (FEC_CommonUltils.PicklistOption option : genderOptionlst) {
        validGenderlst.add(option.value);
      }

      if (!validGenderlst.contains(info.gender)) {
        throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Invalid, new List<String>{'Gender'}));
      }
    }

    // if (!FEC_CommonUltils.isMail(info.email)) {
    //   throw new FEC_APIServiceException('Email is not valid.');
    // }

    if (
      info.birthday != null &&
      !FEC_CommonUltils.isValidDateByFormat(info.birthday)
    ) {
      throw new FEC_APIServiceException(
        String.format(System.Label.FEC_MSG_Param_Date_Format_Invalid, new List<String>{'Birthday', info.birthday})
      );
    }

    if (String.isNotBlank(info.cifNumber))
      checkLength('CIFNumber', info.cifNumber, 255);

    if (String.isNotBlank(info.firstName))
      checkLength('FirstName', info.firstName, 255);

    if (String.isNotBlank(info.middleName))
      checkLength('MiddleName', info.middleName, 255);

    if (String.isNotBlank(info.lastName))
      checkLength('LastName', info.lastName, 255);

    if (String.isNotBlank(info.fullName))
      checkLength('FullName', info.fullName, 255);

    // checkLength('NationalID', info.nationalId, 255);
  }

  private static void checkLength(
    String fieldName,
    String value,
    Integer length
  ) {
    if (String.isNotBlank(value) && value.length() > length) {
      throw new FEC_APIServiceException(
        String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{fieldName, String.valueOf(length)})
      );
    }
  }

  private static void addTextNodeSafe(
    Dom.XmlNode parent,
    String tagName,
    String value
  ) {
    parent.addChildElement(tagName, null, null)
      .addTextNode(value == null ? '' : value);
  }

  private static String getTextSafe(Dom.XmlNode parent, String childName) {
    if (parent == null)
      return '';
    Dom.XmlNode child = parent.getChildElement(childName, null);
    return child != null ? child.getText() : '';
  }

  public static UpdateResult parseResponse(String xml, Integer httpStatus) {
    UpdateResult result = new UpdateResult();
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

      // Try exact match first
      Dom.XmlNode responseNode = body.getChildElement(
        'UpdateCustomerBasicInfoResponse',
        'http://fecredit.com.vn/CIF_CustomerInfoUpdate'
      );

      // Fallback if namespace/prefix changes
      if (responseNode == null) {
        for (Dom.XmlNode n : body.getChildElements()) {
          if (n.getName().endsWith('UpdateCustomerBasicInfoResponse')) {
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

        // In this API: Code = 1 means success
        result.success = (result.code == '1');
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

  public static UpdateResult updateValue(String caseId, String method) {
    List<Case> caselst = [
      SELECT
        Id,
        FEC_Updated_Info_First_Name__c,
        FEC_Updated_Info_Middle_Name__c,
        FEC_Updated_Info_Last_Name__c,
        FEC_Updated_Info_Date_of_Birth__c,
        FEC_Updated_Info_Gender__c,
        FEC_Account_or_Contract__r.FEC_CIF_Number__c,
        FEC_Process_Action_Count__c,
        FEC_Current_Case_Stage__r.Name,
        FEC_Is_Test_API__c 
      FROM Case
      WHERE Id = :caseId
    ];

    if (caselst.isEmpty()) {
      throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{'Case Id'}));
    }

    Case selectedCase = caselst.get(0);

    CustomerBasicInfo info = new CustomerBasicInfo();

    info.cifNumber = selectedCase.FEC_Account_or_Contract__r.FEC_CIF_Number__c; // REQUIRED

    if (FULLNAME_UPDATE.equals(method)) {
      List<String> fullNamelst = new List<String>();

      if (String.isNotBlank(selectedCase.FEC_Updated_Info_Last_Name__c)) {
        fullNamelst.add(selectedCase.FEC_Updated_Info_Last_Name__c);
      }

      if (String.isNotBlank(selectedCase.FEC_Updated_Info_Middle_Name__c)) {
        fullNamelst.add(selectedCase.FEC_Updated_Info_Middle_Name__c);
      }

      if (String.isNotBlank(selectedCase.FEC_Updated_Info_First_Name__c)) {
        fullNamelst.add(selectedCase.FEC_Updated_Info_First_Name__c);
      }

      info.firstName = selectedCase.FEC_Updated_Info_First_Name__c;
      info.middleName = selectedCase.FEC_Updated_Info_Middle_Name__c;
      info.lastName = selectedCase.FEC_Updated_Info_Last_Name__c;

      if (!fullNamelst.isEmpty())
        info.fullName = String.join(fullNamelst, ' ');
    } else if (DOB_UPDATE.equals(method)) {
      info.birthday = String.valueOf(
        selectedCase.FEC_Updated_Info_Date_of_Birth__c
      );
    } else if (GENDER_UPDATE.equals(method)) {
      info.gender = selectedCase.FEC_Updated_Info_Gender__c;
    }

    UpdateResult result = updateCustomerBasicInfo(info);
    
    // init nếu null
    if (selectedCase.FEC_Process_Action_Count__c == null) {
      selectedCase.FEC_Process_Action_Count__c = 0;
    }
    
    if (selectedCase.FEC_Is_Test_API__c) {
      selectedCase.FEC_Process_Action_Count__c += 1;
    } else {
      if (result.success) {
        selectedCase.FEC_Process_Action_Count__c = -1;
      } else {
        selectedCase.FEC_Process_Action_Count__c += 1;
      }
      
    }

    update selectedCase;

    result.actionCount = selectedCase.FEC_Process_Action_Count__c;
    
    if (!selectedCase.FEC_Is_Test_API__c) {
      FEC_CommonUltils.createProcessActionHistory(
        method,
        selectedCase,
        result.success
      );
    }
    
    return result;
  }
}