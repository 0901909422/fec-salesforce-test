/****************************************************************************************
 * File Name    : FEC_UpdateCustomerAddress
 * Author       : Toannd61
 * Date         : 2026-03-11
 * Description  : SOAP API callout to insert/update customer address (UpdateCustomerAddress)
 * ===============================================================
 * Ver    Date         Author            Modification
 * ===============================================================
   1.0    2026-03-11   Toannd61          Create
****************************************************************************************/

public with sharing class FEC_UpdateCustomerAddress {

  public static FEC_ResponseLog responseLog;

  private static final String CIF_NS = 'http://fecredit.com.vn/CIF_CustomerInfoUpdate';
  private static final String DEFAULT_PATH = '/CIF_CustomerInfoUpdate';
  private static final String SOAP_BODY_NS = 'http://schemas.xmlsoap.org/soap/envelope/';
  private static final String API_NAME = 'FEC_UpdateCustomerAddress';
  /** Bộ master tỉnh/TP theo quốc gia (FEC_Country__c.FEC_Code__c): API CIF dùng bộ 2. */
  private static final String FEC_COUNTRY_CODE_PROVINCE_SET_LEGACY = '1';
  private static final String FEC_COUNTRY_CODE_PROVINCE_SET_API = '2';

  public class CustomerAddressInfo {
    @AuraEnabled public String cifNumber;
    @AuraEnabled public String addressId;
    @AuraEnabled public String addressType;
    @AuraEnabled public String number_x;
    @AuraEnabled public String building;
    @AuraEnabled public String street;
    @AuraEnabled public String district;
    @AuraEnabled public String city;
    @AuraEnabled public String propertyStatus;
    @AuraEnabled public String years;
    @AuraEnabled public String months;
    @AuraEnabled public String isMailingAddress;
    @AuraEnabled public String isPrimary;
    @AuraEnabled public String receiveStatement;
    @AuraEnabled public String cardDelivery;
  }

  public class UpdateResult {
    @AuraEnabled public String transId;
    @AuraEnabled public String dateTimeStr;
    @AuraEnabled public String code;
    @AuraEnabled public String description;
    @AuraEnabled public Integer httpStatus;
    @AuraEnabled public String rawResponse;
    @AuraEnabled public Boolean success;
    @AuraEnabled public String errorMessage;
    @AuraEnabled public Decimal actionCount;
  }

  public static UpdateResult updateCustomerAddress(CustomerAddressInfo info) {
    try {
      validateInput(info);
      if (info != null) {
        info.city = remapProvinceCityCodeForCountryTwo(info.city);
      }
      String transId = UUID.randomUUID().toString();
      String timestampStr = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
      Dom.Document doc = buildSoapDocument(info, transId, timestampStr);
      String reqXml = doc.toXmlString();
      UpdateResult finalResult = new UpdateResult();
      String endpoint = '';
      try {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Update_Customer_Address');
        String pathEndpoint = (apiConfig != null && String.isNotBlank(apiConfig.FEC_Endpoint__c))
          ? apiConfig.FEC_Endpoint__c
          : '';
        if (String.isBlank(pathEndpoint)) {
          pathEndpoint = DEFAULT_PATH;
        }
        endpoint =
          (apiSetting != null && String.isNotBlank(apiSetting.FEC_Endpoint__c) ? apiSetting.FEC_Endpoint__c : '') +
          pathEndpoint;
        String soapAction =
          (apiConfig != null && String.isNotBlank(apiConfig.FEC_SOAP_Action__c)) ? apiConfig.FEC_SOAP_Action__c : '';

        HttpResponse res = FEC_CommonUltils.calloutApi(
          endpoint,
          FEC_ConstantCommon.API_METHOD_POST,
          FEC_ConstantCommon.API_CONTENT_TYPE,
          soapAction,
          doc,
          ''
        );
        responseLog = new FEC_ResponseLog(
          API_NAME,
          endpoint,
          FEC_ConstantCommon.API_METHOD_POST,
          reqXml,
          res,
          null
        );

        Integer status = (res == null) ? null : res.getStatusCode();
        String resBody = (res == null) ? null : res.getBody();
        finalResult = parseResponse(resBody, status);
        if (finalResult.transId == null) {
          finalResult.transId = transId;
        }
        if (finalResult.httpStatus == null) {
          finalResult.httpStatus = status;
        }
        if (finalResult.rawResponse == null) {
          finalResult.rawResponse = resBody;
        }
      } catch (Exception ex) {
        String safeEndpoint = String.isNotBlank(endpoint) ? endpoint : 'Unknown_Endpoint';
        if (responseLog != null) {
          responseLog.errorMessage = ex.getMessage();
        } else {
          responseLog = new FEC_ResponseLog(
            API_NAME,
            safeEndpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            reqXml,
            null,
            ex.getMessage()
          );
        }
        finalResult.errorMessage = ex.getMessage();
        finalResult.success = false;
      }
      return finalResult;
    } catch (Exception e) {
      String errMsg = (e != null && String.isNotBlank(e.getMessage())) ? e.getMessage() : 'Unknown error';
      System.debug(LoggingLevel.ERROR, API_NAME + ': ' + errMsg);
      throw new AuraHandledException(errMsg);
    }
  }

  /**
   * Giống updateCustomerAddress; tham số primitive để LWC deserialize.
   * Thiếu CIF/AddressId/AddressType có thể merge từ getMailingAddressUpdateContext (caseId + sfAddressType).
   */
  public static UpdateResult updateCustomerAddressParams(
    String caseId,
    String sfAddressType,
    String cifNumber,
    String addressId,
    String addressType,
    String number_x,
    String building,
    String street,
    String district,
    String city,
    String propertyStatus,
    String years,
    String months,
    String isMailingAddress,
    String isPrimary,
    String receiveStatement,
    String cardDelivery
  ) {
    String cif = cifNumber;
    String addrId = addressId;
    String addrType = addressType;
    Boolean needMerge = String.isBlank(cif) || String.isBlank(addrId) || String.isBlank(addrType);
    Id caseIdVal;
    if (String.isNotBlank(caseId)) {
      try {
        caseIdVal = Id.valueOf(caseId.trim());
      } catch (Exception e) {
        caseIdVal = null;
      }
    }
    if (needMerge && caseIdVal != null && String.isNotBlank(sfAddressType)) {
      FEC_MainInfoController.MailingAddressContextDTO ctx = FEC_MainInfoController.getMailingAddressUpdateContext(
        caseIdVal,
        sfAddressType
      );
      if (ctx != null && ctx.found == true) {
        if (String.isBlank(cif)) {
          cif = ctx.cifNumber;
        }
        if (String.isBlank(addrId)) {
          addrId = ctx.addressId;
        }
        if (String.isBlank(addrType)) {
          addrType = ctx.addressType;
        }
      }
    }
    CustomerAddressInfo info = new CustomerAddressInfo();
    info.cifNumber = cif;
    info.addressId = addrId;
    info.addressType = addrType;
    info.number_x = number_x;
    info.building = building;
    info.street = street;
    info.district = district;
    info.city = city;
    info.propertyStatus = propertyStatus;
    info.years = years;
    info.months = months;
    info.isMailingAddress = isMailingAddress;
    info.isPrimary = isPrimary;
    info.receiveStatement = receiveStatement;
    info.cardDelivery = cardDelivery;
    return updateCustomerAddress(info);
  }

  public static UpdateResult updateValue(
    String caseId,
    Map<String, String> params,
    String method
  ) {
    if (String.isBlank(caseId)) {
      throw new FEC_APIServiceException(
        String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' })
      );
    }
    List<Case> caselst = [
      SELECT Id, FEC_Process_Action_Count__c, FEC_Current_Case_Stage__r.Name
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (caselst.isEmpty()) {
      throw new FEC_APIServiceException(
        String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Case Id' })
      );
    }

    Case selectedCase = caselst[0];
    Map<String, String> pendingFieldBySfType =
      FEC_MainInfoController.loadCasePendingAddressJsonMap(selectedCase.Id);

    UpdateResult result;
    for (String sfType : new List<String>{ 'Permanent Address', 'Office Address', 'Current Address' }) {
      String pendingJson = pendingFieldBySfType.get(sfType);
      if (String.isBlank(pendingJson)) {
        continue;
      }
      try {
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(pendingJson);
        result = updateCustomerAddressParams(
          caseId,
          sfType,
          (String) data.get('cifNumber'),
          (String) data.get('addressId'),
          (String) data.get('addressType'),
          (String) data.get('number_x'),
          (String) data.get('building'),
          (String) data.get('street'),
          (String) data.get('district'),
          (String) data.get('city'),
          (String) data.get('propertyStatus'),
          (String) data.get('years'),
          (String) data.get('months'),
          (String) data.get('isMailingAddress'),
          (String) data.get('isPrimary'),
          (String) data.get('receiveStatement'),
          (String) data.get('cardDelivery')
        );
      } finally {
        logApiResponse();
      }
      if (result == null || result.success != true) {
        break;
      }
    }

    if (result != null && result.success == true) {
      selectedCase.FEC_Process_Action_Count__c = -1;

      // Sync FEC_Mailing_Address__c trong FEC_Address_Info__c dựa trên isMailingAddress trong pending JSON
      // vì API GetAddressesList không trả cờ mailing, nên phải sync trước khi xóa pending fields
      String selectedMailingSfType = null;
      for (String sfType : new List<String>{
        'Permanent Address',
        'Office Address',
        'Current Address'
      }) {
        String pendingJson = pendingFieldBySfType.get(sfType);
        if (String.isBlank(pendingJson)) continue;
        try {
          Map<String, Object> d = (Map<String, Object>) JSON.deserializeUntyped(pendingJson);
          if ('Y'.equals((String) d.get('isMailingAddress'))) {
            selectedMailingSfType = sfType;
            break;
          }
        } catch (Exception ex) {
          System.debug('### syncMailing parse error: ' + ex.getMessage());
        }
      }
      FEC_MainInfoController.syncLocalMailingAddressSelection(caseId, selectedMailingSfType);

      FEC_MainInfoController.clearCasePendingAddressRows(selectedCase.Id);
    } else {
      if (selectedCase.FEC_Process_Action_Count__c == null) {
        selectedCase.FEC_Process_Action_Count__c = 0;
      }
      selectedCase.FEC_Process_Action_Count__c += 1;
    }
    FEC_CaseTriggerHandler.isExecuting = true;
    update selectedCase;
    if (result == null) {
      result = new UpdateResult();
      result.success = false;
      result.errorMessage = System.Label.FEC_MSG_Response_Null;
    }
    result.actionCount = selectedCase.FEC_Process_Action_Count__c;
    FEC_CommonUltils.createProcessActionHistory(
      String.isNotBlank(method) ? method : API_NAME,
      selectedCase,
      result.success == true
    );
    return result;
  }

  public static UpdateResult parseResponse(String xml, Integer httpStatus) {
    UpdateResult result = new UpdateResult();
    result.httpStatus = httpStatus;
    result.rawResponse = xml;
    if (xml == null) {
      return failResult(result, System.Label.FEC_MSG_Response_Null);
    }
    try {
      Dom.Document d = new Dom.Document();
      d.load(xml);
      Dom.XmlNode body = d.getRootElement().getChildElement('Body', SOAP_BODY_NS);
      if (body == null) {
        return failResult(result, System.Label.FEC_MSG_Response_Null);
      }
      Dom.XmlNode responseNode = body.getChildElement('UpdateCustomerAddressResponse', CIF_NS);
      if (responseNode == null) {
        for (Dom.XmlNode n : body.getChildElements()) {
          if (n.getName().endsWith('UpdateCustomerAddressResponse')) {
            responseNode = n;
            break;
          }
        }
      }
      if (responseNode == null) {
        return failResult(result, System.Label.FEC_MSG_Response_Null);
      }
      Dom.XmlNode sys = responseNode.getChildElement('Sys', null);
      if (sys == null) {
        result.errorMessage = System.Label.FEC_MSG_Response_Sys_Null;
        result.success = false;
        return result;
      }
      Dom.XmlNode t = sys.getChildElement('TransID', null);
      Dom.XmlNode dt = sys.getChildElement('DateTime', null);
      Dom.XmlNode c = sys.getChildElement('Code', null);
      Dom.XmlNode dNode = sys.getChildElement('Description', null);
      result.transId = (t != null) ? t.getText() : null;
      result.dateTimeStr = (dt != null) ? dt.getText() : null;
      String rawCode = (c != null) ? c.getText() : null;
      result.code = String.isNotBlank(rawCode) ? rawCode.trim() : rawCode;
      result.description = (dNode != null) ? dNode.getText() : null;
      // Code 1 và 4 = thành công
      result.success = (result.code == '1' || result.code == '4');
      result.errorMessage = result.success ? null : result.description;
    } catch (Exception ex) {
      result.errorMessage = String.format(
        System.Label.FEC_MSG_Parse_XML_Error,
        new List<String>{ ex.getMessage() }
      );
      result.success = false;
    }
    return result;
  }

  private static UpdateResult failResult(UpdateResult result, String msg) {
    result.errorMessage = msg;
    result.success = false;
    return result;
  }

  /**
   * Province/City (mã FEC_Province__c.FEC_Code__c) trước khi gửi API / hiển thị combobox (bộ 2):
   * - TH1: Thuộc FEC_Country__r.FEC_Code__c = 1 → đổi sang mã tỉnh/TP tương ứng bộ FEC_Code__c = 2
   *   (khớp FEC_Name_VN__c hoặc Name). Không map được hoặc trùng nhiều bản ghi → giữ mã gốc.
   * - TH2: Thuộc FEC_Country__r.FEC_Code__c = 2 (hoặc khác 1) → giữ nguyên mã.
   */
  public static String remapProvinceCityCodeForCountryTwo(String cityCode) {
    if (String.isBlank(cityCode)) {
      return cityCode;
    }
    String codeTrim = cityCode.trim();
    List<FEC_Province__c> srcRows = [
      SELECT Id, Name, FEC_Name_VN__c, FEC_Country__r.FEC_Code__c
      FROM FEC_Province__c
      WHERE FEC_Code__c = :codeTrim
      LIMIT 1
    ];
    if (srcRows.isEmpty()) {
      return cityCode;
    }
    FEC_Province__c src = srcRows[0];
    String countryCode = (src.FEC_Country__r != null) ? src.FEC_Country__r.FEC_Code__c : null;
    // TH2 (+ mọi trường hợp khác TH1): không thuộc bộ 1 → giữ nguyên city (gồm bộ 2)
    if (String.isBlank(countryCode) || !FEC_COUNTRY_CODE_PROVINCE_SET_LEGACY.equals(countryCode.trim())) {
      return cityCode;
    }
    String matchName = String.isNotBlank(src.FEC_Name_VN__c) ? src.FEC_Name_VN__c.trim() : null;
    if (String.isBlank(matchName)) {
      matchName = (src.Name != null) ? src.Name.trim() : null;
    }
    if (String.isBlank(matchName)) {
      return cityCode;
    }
    List<FEC_Province__c> targetRows = [
      SELECT FEC_Code__c
      FROM FEC_Province__c
      WHERE FEC_Country__r.FEC_Code__c = :FEC_COUNTRY_CODE_PROVINCE_SET_API
        AND (FEC_Name_VN__c = :matchName OR Name = :matchName)
    ];
    if (targetRows.size() != 1 || String.isBlank(targetRows[0].FEC_Code__c)) {
      return cityCode;
    }
    return targetRows[0].FEC_Code__c.trim();
  }

  private static void validateInput(CustomerAddressInfo info) {
    if (info == null) {
      throw new FEC_APIServiceException(
        String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Request Data' })
      );
    }
    requireNonBlank(info.cifNumber, 'CIFNumber');
    requireNonBlank(info.addressId, 'AddressId');
    requireNonBlank(info.addressType, 'AddressType');
    FEC_CommonUltils.checkLength('CIFNumber', info.cifNumber, 255);
    FEC_CommonUltils.checkLength('AddressId', info.addressId, 255);
    FEC_CommonUltils.checkLength('AddressType', info.addressType, 255);
    if (String.isNotBlank(info.number_x)) {
      FEC_CommonUltils.checkLength('Number', info.number_x, 255);
    }
    if (String.isNotBlank(info.building)) {
      FEC_CommonUltils.checkLength('Building', info.building, 255);
    }
    if (String.isNotBlank(info.street)) {
      FEC_CommonUltils.checkLength('Street', info.street, 255);
    }
    if (String.isNotBlank(info.district)) {
      FEC_CommonUltils.checkLength('District', info.district, 255);
    }
    if (String.isNotBlank(info.city)) {
      FEC_CommonUltils.checkLength('City', info.city, 255);
    }
  }

  private static void requireNonBlank(String value, String fieldLabel) {
    if (String.isBlank(value)) {
      throw new FEC_APIServiceException(
        String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ fieldLabel })
      );
    }
  }

  private static Dom.Document buildSoapDocument(
    CustomerAddressInfo info,
    String transId,
    String timestampStr
  ) {
    Dom.Document doc = new Dom.Document();
    Dom.XmlNode envelope = doc.createRootElement('Envelope', FEC_ConstantCommon.SOAP_ENV, 'soapenv');
    envelope.addChildElement('Header', FEC_ConstantCommon.SOAP_ENV, null);
    Dom.XmlNode body = envelope.addChildElement('Body', FEC_ConstantCommon.SOAP_ENV, null);
    Dom.XmlNode requestNode = body.addChildElement('UpdateCustomerAddress', CIF_NS, 'cif');
    envelope.setNamespace('cif', CIF_NS);

    Dom.XmlNode sysNode = requestNode.addChildElement('Sys', null, null);
    sysNode.addChildElement('TransID', null, null).addTextNode(transId != null ? transId : '');
    sysNode.addChildElement('RequestorID', null, null)
      .addTextNode(FEC_ConstantCommon.REQUESTOR_APS != null ? FEC_ConstantCommon.REQUESTOR_APS : '');
    sysNode.addChildElement('DateTime', null, null).addTextNode(timestampStr != null ? timestampStr : '');

    FEC_CommonUltils.addTextNodeSafe(requestNode, 'CIFNumber', info.cifNumber);
    Dom.XmlNode addrNode = requestNode.addChildElement('Address', null, null);
    FEC_CommonUltils.addTextNodeSafe(addrNode, 'AddressId', info.addressId);
    FEC_CommonUltils.addTextNodeSafe(addrNode, 'AddressType', info.addressType);
    addIfPresent(addrNode, 'Number', info.number_x);
    addIfPresent(addrNode, 'Building', info.building);
    addIfPresent(addrNode, 'Street', info.street);
    addIfPresent(addrNode, 'District', info.district);
    addIfPresent(addrNode, 'City', info.city);
    addIfPresent(addrNode, 'PropertyStatus', info.propertyStatus);
    addIfPresent(addrNode, 'Years', info.years);
    addIfPresent(addrNode, 'Months', info.months);
    addYIfPresent(addrNode, 'IsMailingAddress', info.isMailingAddress);
    addYIfPresent(addrNode, 'IsPrimary', info.isPrimary);
    addYIfPresent(addrNode, 'ReceiveStatement', info.receiveStatement);
    addYIfPresent(addrNode, 'CardDelivery', info.cardDelivery);
    return doc;
  }

  private static void addIfPresent(Dom.XmlNode parent, String el, String val) {
    if (String.isNotBlank(val)) {
      FEC_CommonUltils.addTextNodeSafe(parent, el, val);
    }
  }

  private static void addYIfPresent(Dom.XmlNode parent, String el, String val) {
    if (String.isNotBlank(val)) {
      FEC_CommonUltils.addTextNodeSafe(parent, el, toSingleChar(val));
    }
  }

  private static String toSingleChar(String value) {
    if (String.isBlank(value)) {
      return '';
    }
    String v = value.trim();
    if (v.length() == 1) {
      return v;
    }
    String upper = v.toUpperCase();
    if (upper == 'TRUE' || upper == 'YES' || upper == '1' || upper == 'Y') {
      return 'Y';
    }
    if (upper == 'FALSE' || upper == 'NO' || upper == '0' || upper == 'N') {
      return 'N';
    }
    return v.substring(0, 1);
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
}