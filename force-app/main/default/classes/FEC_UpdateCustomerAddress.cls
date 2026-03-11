/****************************************************************************************
 * File Name    : FEC_UpdateCustomerAddress
 * Author       : Toannd61
 * Date         : 2026-03-11
 * Description  : SOAP API callout to insert/update customer address (UpdateCustomerAddress)
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-03-11     Toannd61             Create

****************************************************************************************/

public with sharing class FEC_UpdateCustomerAddress {

  private static final String CIF_NS = 'http://fecredit.com.vn/CIF_CustomerInfoUpdate';

  public class CustomerAddressInfo {
    @AuraEnabled public String cifNumber { get; set; }
    @AuraEnabled public String addressId { get; set; }
    @AuraEnabled public String addressType { get; set; }
    @AuraEnabled public String number_x { get; set; }
    @AuraEnabled public String building { get; set; }
    @AuraEnabled public String street { get; set; }
    @AuraEnabled public String ward { get; set; }
    @AuraEnabled public String city { get; set; }
    @AuraEnabled public String propertyStatus { get; set; }
    @AuraEnabled public String years { get; set; }
    @AuraEnabled public String months { get; set; }
    @AuraEnabled public String isMailingAddress { get; set; }
    @AuraEnabled public String isPrimary { get; set; }
    @AuraEnabled public String receiveStatement { get; set; }
    @AuraEnabled public String cardDelivery { get; set; }
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

  // ==========================================
  // MAIN METHOD
  // ==========================================
  @AuraEnabled
  public static UpdateResult updateCustomerAddress(CustomerAddressInfo info) {
    try {
      validateInput(info);

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
        'UpdateCustomerAddress',
        CIF_NS,
        'cif'
      );
      envelope.setNamespace('cif', CIF_NS);

      // --- SYS ---
      Dom.XmlNode sysNode = requestNode.addChildElement('Sys', null, null);
      sysNode.addChildElement('TransID', null, null).addTextNode(transId);
      sysNode.addChildElement('RequestorID', null, null)
        .addTextNode(UUID.randomUUID().toString());
      sysNode.addChildElement('DateTime', null, null).addTextNode(timestamp);

      // --- CIFNumber ---
      addTextNodeSafe(requestNode, 'CIFNumber', info.cifNumber);

      // --- Address ---
      Dom.XmlNode addrNode = requestNode.addChildElement('Address', null, null);

      addTextNodeSafe(addrNode, 'AddressId', info.addressId);
      addTextNodeSafe(addrNode, 'AddressType', info.addressType);

      if (String.isNotBlank(info.number_x))
        addTextNodeSafe(addrNode, 'Number', info.number_x);

      if (String.isNotBlank(info.building))
        addTextNodeSafe(addrNode, 'Building', info.building);

      if (String.isNotBlank(info.street))
        addTextNodeSafe(addrNode, 'Street', info.street);

      if (String.isNotBlank(info.ward))
        addTextNodeSafe(addrNode, 'Ward', info.ward);

      if (String.isNotBlank(info.city))
        addTextNodeSafe(addrNode, 'City', info.city);

      if (String.isNotBlank(info.propertyStatus))
        addTextNodeSafe(addrNode, 'PropertyStatus', info.propertyStatus);

      if (String.isNotBlank(info.years))
        addTextNodeSafe(addrNode, 'Years', info.years);

      if (String.isNotBlank(info.months))
        addTextNodeSafe(addrNode, 'Months', info.months);

      if (String.isNotBlank(info.isMailingAddress))
        addTextNodeSafe(addrNode, 'IsMailingAddress', info.isMailingAddress);

      if (String.isNotBlank(info.isPrimary))
        addTextNodeSafe(addrNode, 'IsPrimary', info.isPrimary);

      if (String.isNotBlank(info.receiveStatement))
        addTextNodeSafe(addrNode, 'ReceiveStatement', info.receiveStatement);

      if (String.isNotBlank(info.cardDelivery))
        addTextNodeSafe(addrNode, 'CardDelivery', info.cardDelivery);

      UpdateResult finalResult = new UpdateResult();
      String endpoint = '';
      try {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Update_Customer_Address');

        endpoint = (apiSetting != null && apiSetting.FEC_Call_Mock__c == true)
            ? FEC_MockupEndpoint.UPDATE_CUSTOMER_ADDRESS_ENDPOINT_MOCKUP
            : ((apiSetting != null ? apiSetting.FEC_Endpoint__c : '') + (apiConfig != null ? apiConfig.FEC_Endpoint__c : ''));

        HttpResponse res = FEC_CommonUltils.calloutApi(
          endpoint,
          FEC_ConstantCommon.API_METHOD_POST,
          FEC_ConstantCommon.API_CONTENT_TYPE,
          apiConfig?.FEC_SOAP_Action__c,
          doc,
          ''
        );

        FEC_CommonUltils.logApi(
          'FEC_UpdateCustomerAddress',
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
        FEC_CommonUltils.logApi(
          'FEC_UpdateCustomerAddress',
          endpoint,
          FEC_ConstantCommon.API_METHOD_POST,
          doc.toXmlString(),
          null,
          ex.getMessage()
        );
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
  // VALIDATION
  // ==========================================
  private static void validateInput(CustomerAddressInfo info) {
    if (info == null) {
      throw new FEC_APIServiceException(
        String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Request Data'})
      );
    }

    if (String.isBlank(info.cifNumber)) {
      throw new FEC_APIServiceException(
        String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CIFNumber'})
      );
    }

    if (String.isBlank(info.addressId)) {
      throw new FEC_APIServiceException(
        String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'AddressId'})
      );
    }

    if (String.isBlank(info.addressType)) {
      throw new FEC_APIServiceException(
        String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'AddressType'})
      );
    }

    checkLength('CIFNumber', info.cifNumber, 255);
    checkLength('AddressId', info.addressId, 255);
    checkLength('AddressType', info.addressType, 255);

    if (String.isNotBlank(info.number_x))
      checkLength('Number', info.number_x, 255);

    if (String.isNotBlank(info.building))
      checkLength('Building', info.building, 255);

    if (String.isNotBlank(info.street))
      checkLength('Street', info.street, 255);

    if (String.isNotBlank(info.ward))
      checkLength('Ward', info.ward, 255);

    if (String.isNotBlank(info.city))
      checkLength('City', info.city, 255);
  }

  // ==========================================
  // PARSE RESPONSE
  // ==========================================
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

      Dom.XmlNode responseNode = body.getChildElement(
        'UpdateCustomerAddressResponse',
        CIF_NS
      );

      if (responseNode == null) {
        for (Dom.XmlNode n : body.getChildElements()) {
          if (n.getName().endsWith('UpdateCustomerAddressResponse')) {
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

        // Code 4 = successfully created, 5 = successfully updated
        result.success = (result.code == '4' || result.code == '5');
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

  // ==========================================
  // HELPERS
  // ==========================================
  private static void checkLength(String fieldName, String value, Integer length) {
    if (String.isNotBlank(value) && value.length() > length) {
      throw new FEC_APIServiceException(
        String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{fieldName, String.valueOf(length)})
      );
    }
  }

  private static void addTextNodeSafe(Dom.XmlNode parent, String tagName, String value) {
    parent.addChildElement(tagName, null, null)
      .addTextNode(value == null ? '' : value);
  }
}
