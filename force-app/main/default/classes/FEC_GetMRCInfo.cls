public with sharing class FEC_GetMRCInfo {
  public static final String API_CONFIG_NAME = 'FEC_Get_MRC_Info';
  public static FEC_ResponseLog responseLog;

  public class MRCInfoRequest {
    public String ContractNumber;
  }

  public class MRCInfoResult {
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
    public MRCInfoData data;
  }

  public class MRCInfoData {
    @AuraEnabled
    public String contractNumber;

    @AuraEnabled
    public String id;

    @AuraEnabled
    public String mrcZone;

    @AuraEnabled
    public String area;

    @AuraEnabled
    public String plateNumber;

    @AuraEnabled
    public String statusId;

    @AuraEnabled
    public String status;

    @AuraEnabled
    public String receiverInformation;

    @AuraEnabled
    public String remark;

    @AuraEnabled
    public String modifiedDate;

    @AuraEnabled
    public String mailcode;

    @AuraEnabled
    public String receivedDate;

    @AuraEnabled
    public String notaryPostedDate;

    @AuraEnabled
    public String notaryReceiverInformation;

    @AuraEnabled
    public String notaryMailcode;

    @AuraEnabled
    public String notaryRemark;

    @AuraEnabled
    public String provideNumber;
  }

  public static String buildEnvelope(
    MRCInfoRequest req,
    String transId,
    String timestamp
  ) {
    validate(req, transId, timestamp);

    String env = '';
    env += '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://fecredit.com.vn/MRC_Info">';
    env += '<soapenv:Header/>';
    env += '<soapenv:Body>';
    env += '<ns1:GetMRCInfo>';
    env += '<Sys>';
    env += '<TransID>' + FEC_CommonUltils.escapeXml(transId) + '</TransID>';
    env += '<RequestorID>PEGA_CSM</RequestorID>';
    env += '<DateTime>' + FEC_CommonUltils.escapeXml(timestamp) + '</DateTime>';
    env += '</Sys>';
    env +=
      '<ContractNumber>' +
      FEC_CommonUltils.escapeXml(req.ContractNumber) +
      '</ContractNumber>';
    env += '</ns1:GetMRCInfo>';
    env += '</soapenv:Body>';
    env += '</soapenv:Envelope>';
    return env;
  }



  public static HttpResponse sendRequest(String envelope) {
    FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
    FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(
      API_CONFIG_NAME
    );

    String endpoint = apiSetting?.FEC_Call_Mock__c
      ? FEC_MockupEndpoint.GET_MRC_INFO_ENDPOINT_MOCKUP
      : (
          apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c
        );
    System.debug('endpoint: ' + endpoint);
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

  public static MRCInfoResult parseResponse(String xml, Integer httpStatus) {
    MRCInfoResult result = new MRCInfoResult();
    result.httpStatus = httpStatus;
    result.rawResponse = xml;
    if (xml == null) {
      result.errorMessage = System.Label.FEC_MSG_Response_Null;
      result.success = false;
      return result;
    }
    String trimmed = xml.trim();
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      result.errorMessage = System.Label.FEC_MSG_Error_API_Label;
      result.success = false;
      return result;
    }
    String normalizedXml = FEC_CommonUltils.cleanResponseBody(trimmed);
    if (String.isBlank(normalizedXml)) {
      result.errorMessage = System.Label.FEC_MSG_Response_Null;
      result.success = false;
      return result;
    }
    try {
      Dom.Document doc = new Dom.Document();
      doc.load(normalizedXml);
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
        'GetMRCInfoResponse',
        null
      );
      if (responseNode == null) {
        for (Dom.XmlNode n : body.getChildElements()) {
          if (n.getName().endsWith('GetMRCInfoResponse')) {
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
      // detect namespace
      String ns = responseNode.getNamespace();
      // Sys node - try with namespace first, fallback to null
      Dom.XmlNode sys = responseNode.getChildElement('Sys', ns);
      if (sys == null) {
        sys = responseNode.getChildElement('Sys', null);
      }
      if (sys != null) {
        result.transId = FEC_CommonUltils.getXmlValue(sys, 'TransID');
        result.dateTimeStr = FEC_CommonUltils.getXmlValue(sys, 'DateTime');
        result.code = FEC_CommonUltils.getXmlValue(sys, 'Code');
        result.description = FEC_CommonUltils.getXmlValue(sys, 'Description');
        result.success = (result.code == '1');
      } else {
        result.errorMessage = System.Label.FEC_MSG_Response_Sys_Null;
        result.success = false;
      }
      // parse data
      result.data = new MRCInfoData();
      result.data.contractNumber = FEC_CommonUltils.getXmlValue(
        responseNode,
        'ContractNumber'
      );
      result.data.id = FEC_CommonUltils.getXmlValue(responseNode, 'ID');
      result.data.mrcZone = FEC_CommonUltils.getXmlValue(
        responseNode,
        'MRCZone'
      );
      result.data.area = FEC_CommonUltils.getXmlValue(responseNode, 'Area');
      result.data.plateNumber = FEC_CommonUltils.getXmlValue(
        responseNode,
        'PlateNumber'
      );
      result.data.statusId = FEC_CommonUltils.getXmlValue(
        responseNode,
        'StatusID'
      );
      result.data.status = FEC_CommonUltils.getXmlValue(responseNode, 'Status');
      result.data.receiverInformation = FEC_CommonUltils.getXmlValue(
        responseNode,
        'ReceiverInformation'
      );
      result.data.remark = FEC_CommonUltils.getXmlValue(responseNode, 'Remark');
      result.data.modifiedDate = FEC_CommonUltils.getXmlValue(
        responseNode,
        'ModifiedDate'
      );
      result.data.mailcode = FEC_CommonUltils.getXmlValue(
        responseNode,
        'Mailcode'
      );
      result.data.receivedDate = FEC_CommonUltils.getXmlValue(
        responseNode,
        'ReceivedDate'
      );
      result.data.notaryPostedDate = FEC_CommonUltils.getXmlValue(
        responseNode,
        'NotaryPostedDate'
      );
      result.data.notaryReceiverInformation = FEC_CommonUltils.getXmlValue(
        responseNode,
        'NotaryReceiverInformation'
      );
      result.data.notaryMailcode = FEC_CommonUltils.getXmlValue(
        responseNode,
        'NotaryMailcode'
      );
      result.data.notaryRemark = FEC_CommonUltils.getXmlValue(
        responseNode,
        'NotaryRemark'
      );
      result.data.provideNumber = FEC_CommonUltils.getXmlValue(
        responseNode,
        'ProvideNumber'
      );
    } catch (Exception ex) {
      result.errorMessage = String.format(
        System.Label.FEC_MSG_Parse_XML_Error,
        new List<String>{ ex.getMessage() }
      );
      result.success = false;
    }
    return result;
  }

  @AuraEnabled
  public static MRCInfoResult getMRCInfo(MRCInfoRequest req) {
    MRCInfoResult finalResult = new MRCInfoResult();
    System.debug('getMRCInfo input: ' + (req == null ? 'null' : JSON.serialize(req)));
    String transId = FEC_CommonUltils.generateTransactionUUID();
    String timestamp = FEC_CommonUltils.formatTimestamp(Datetime.now(), FEC_ConstantCommon.DATETIME_FORMAT);
    String envelope = buildEnvelope(req, transId, timestamp);
    try {
      HttpResponse res = sendRequest(envelope);
      Integer status = (res == null) ? null : res.getStatusCode();
      String body = (res == null) ? null : res.getBody();

      if (res != null) {
        System.debug('Status Code: ' + res.getStatusCode());
        System.debug('Status: ' + res.getStatus());
        System.debug('Response Body: ' + res.getBody());
        for (String key : res.getHeaderKeys()) {
            System.debug('Header: ' + key + ' = ' + res.getHeader(key));
        }
        System.debug('Redirect Location: ' + res.getHeader('Location'));
    } else {
        System.debug('Response is NULL');
    }

      FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
      FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);
      String endpoint = apiSetting?.FEC_Call_Mock__c
        ? FEC_MockupEndpoint.GET_MRC_INFO_ENDPOINT_MOCKUP
        : (
            apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c
          );
	  
      responseLog = new FEC_ResponseLog(
        'FEC_GetMRCInfo',
        endpoint,
        FEC_ConstantCommon.API_METHOD_POST,
        envelope,
        res,
        null
      );

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
    MRCInfoRequest req,
    String transId,
    String timestamp
  ) {
    if (String.isBlank(transId)) {
      throw new FEC_APIServiceException(System.Label.FEC_MSG_TransID_Null);
    }

    if (String.isBlank(timestamp)) {
      throw new FEC_APIServiceException(System.Label.FEC_MSG_Datetime_Null);
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
  public static FEC_Customer_History__c updateMRCRecord(String caseId) {
    if (String.isBlank(caseId)) {
      return null;
    }

    // 1. Query the Case to get the Contract Number
    List<Case> cases = [
      SELECT
        Id,
        FEC_Contract_Number__c,
        FEC_Search_Contract_Number__c,
        FEC_Account_or_Contract__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];

    if (cases.isEmpty()) {
      throw new AuraHandledException(
        String.format(
          System.Label.FEC_MSG_Invalid,
          new List<String>{ 'Case Id' }
        )
      );
    }

    if (String.isBlank(cases[0].FEC_Contract_Number__c) && String.isBlank(cases[0].FEC_Search_Contract_Number__c)) {
      throw new AuraHandledException(
        String.format(
          System.Label.FEC_MSG_Invalid,
          new List<String>{ 'Contract Number' }
        )
      );
    }

    if (cases[0].FEC_Account_or_Contract__c == null) {
      throw new AuraHandledException(
        String.format(
          System.Label.FEC_MSG_Invalid,
          new List<String>{ 'Account/Contract' }
        )
      );
    }

    // 2. Call the API
    MRCInfoRequest req = new MRCInfoRequest();
    req.ContractNumber = cases[0].FEC_Contract_Number__c;
    if (String.isBlank(req.ContractNumber)) {
        req.ContractNumber = cases[0].FEC_Search_Contract_Number__c;
    }
    MRCInfoResult result;
    try {
      result = getMRCInfo(req);
    } catch (FEC_APIServiceException ex) {
      throw new AuraHandledException(ex.getMessage());
    } catch (Exception ex) {
      throw new AuraHandledException(ex.getMessage());
    }

    if (!result.success || result.data == null) {
      throw new AuraHandledException(
        result.errorMessage != null
          ? result.errorMessage
          : System.Label.FEC_MSG_Error_API_Label
      );
    }

    // 3. Update FEC_Customer_History__c (Case → FEC_Account_or_Contract__c)
    MRCInfoData data = result.data;
    List<FEC_Customer_History__c> chRecords = [
      SELECT
        Id,
        Name,
        FEC_MRC_Zone__c,
        FEC_Area__c,
        FEC_Plate_Number__c,
        FEC_MRC_Status__c,
        FEC_Status_ID__c,
        FEC_ID__c,
        FEC_Original_MRC_Remark__c,
        FEC_Modified_Date__c,
        FEC_Delivery_Date__c,
        FEC_Received_Date__c,
        FEC_Original_MRC_Receiver__c,
        FEC_Posted_Date__c,
        FEC_Postal_Code__c,
        FEC_Notarized_MRC_Remark__c,
        FEC_Provided_Number__c,
        FEC_Notarized_MRC_Receiver__c
      FROM FEC_Customer_History__c
      WHERE Id = :cases[0].FEC_Account_or_Contract__c
      LIMIT 1
    ];

    if (chRecords.isEmpty()) {
      throw new AuraHandledException(
        String.format(
          System.Label.FEC_MSG_Invalid,
          new List<String>{ 'Customer History' }
        )
      );
    }

    FEC_Customer_History__c chToUpsert = chRecords[0];

    chToUpsert.FEC_MRC_Zone__c = data.mrcZone;
    chToUpsert.FEC_Area__c = data.area;
    chToUpsert.FEC_Plate_Number__c = data.plateNumber;
    chToUpsert.FEC_MRC_Status__c = data.status;
    chToUpsert.FEC_Status_ID__c = data.statusId;
    chToUpsert.FEC_ID__c = data.id;

    chToUpsert.FEC_Original_MRC_Remark__c = data.remark;
    chToUpsert.FEC_Modified_Date__c = String.isBlank(data.modifiedDate)
      ? null
      : Date.valueOf(data.modifiedDate);
    chToUpsert.FEC_Received_Date__c = String.isBlank(data.receivedDate)
      ? null
      : Date.valueOf(data.receivedDate);
    chToUpsert.FEC_Original_MRC_Receiver__c = data.receiverInformation;

    chToUpsert.FEC_Posted_Date__c = String.isBlank(data.notaryPostedDate)
      ? null
      : Date.valueOf(data.notaryPostedDate);
    chToUpsert.FEC_Postal_Code__c = data.notaryMailcode;

    chToUpsert.FEC_Notarized_MRC_Remark__c = data.notaryRemark;
    chToUpsert.FEC_Notarized_MRC_Receiver__c = data.notaryReceiverInformation;

    chToUpsert.FEC_Provided_Number__c = String.isNotBlank(data.provideNumber)
      ? Decimal.valueOf(data.provideNumber)
      : null;

    update chToUpsert;

    return chToUpsert;
  }
}