public with sharing class FEC_AddIPP {
  public static final String API_CONFIG_NAME = 'FEC_Add_IPP';

  private static final String SOAP_NS = 'http://schemas.xmlsoap.org/soap/envelope/';
  private static final String SERVICE_NS = 'http://esbservice.fecredit.org/EStatementService/';

  // Wrapper Class cho Add IPP Result
  public class AddIPPResult {
    @AuraEnabled
    public String transId { get; set; }
    @AuraEnabled
    public String dateTimes { get; set; }
    @AuraEnabled
    public Integer status { get; set; }
    @AuraEnabled
    public String description { get; set; }
    @AuraEnabled
    public Integer httpStatus { get; set; }
    @AuraEnabled
    public String rawResponse { get; set; }
    @AuraEnabled
    public Boolean success { get; set; }
    @AuraEnabled
    public String errorMessage { get; set; }

    // Response fields (có thể empty nếu failed)
    @AuraEnabled
    public String accountNumber { get; set; }
    @AuraEnabled
    public Integer ippTerm { get; set; }
    @AuraEnabled
    public Decimal principalAmount { get; set; }
    @AuraEnabled
    public Decimal installmentAmount { get; set; }
    @AuraEnabled
    public Decimal conversionFee { get; set; }
    @AuraEnabled
    public Decimal emi { get; set; }
    @AuraEnabled
    public String responseDescription { get; set; }
    @AuraEnabled
    public String planNumber { get; set; }
    @AuraEnabled
    public Decimal interestRate { get; set; }
  }

  // Wrapper cho request parameters
  public class IPPRequest {
    @AuraEnabled
    public String accountNumber { get; set; }
    @AuraEnabled
    public Date effectiveDate { get; set; }
    @AuraEnabled
    public Decimal amount { get; set; }
    @AuraEnabled
    public String planNumber { get; set; }
    @AuraEnabled
    public Integer ippTerm { get; set; }
    @AuraEnabled
    public String referenceNumber { get; set; }
    @AuraEnabled
    public String transactionPlan { get; set; }
    @AuraEnabled
    public Date postingDate { get; set; }
    @AuraEnabled
    public String cardNumber { get; set; }
    @AuraEnabled
    public Integer cardSeq { get; set; }
    @AuraEnabled
    public String ippKey { get; set; }
  }

  public static String generateTransId() {
    return String.valueOf(UUID.randomUUID());
  }

  public static String formatTimestamp() {
    return Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT);
  }

  @AuraEnabled
  public static AddIPPResult addIPP(IPPRequest request) {
    validate(request);
    AddIPPResult finalResult = new AddIPPResult();
    String transId = generateTransId();
    String timestamp = formatTimestamp();

    Dom.Document doc = buildRequestDocument(request, transId, timestamp);

    try {
      HttpResponse res = sendRequest(doc);
      Integer status = (res == null) ? null : res.getStatusCode();
      String body = (res == null) ? null : res.getBody();
      finalResult = parseResponse(body, status);

      if (finalResult.transId == null) {
        finalResult.transId = transId;
      }
      if (finalResult.httpStatus == null) {
        finalResult.httpStatus = status;
      }
      if (finalResult.rawResponse == null) {
        finalResult.rawResponse = body;
      }
    } catch (Exception ex) {
      finalResult.errorMessage = ex.getMessage();
      finalResult.success = false;
    }
    return finalResult;
  }

  public static Dom.Document buildRequestDocument(
    IPPRequest request,
    String transId,
    String timestamp
  ) {
    // 1. Tạo Request với namespace đúng
    Dom.Document doc = new Dom.Document();
    Dom.XmlNode envelope = doc.createRootElement(
      'Envelope',
      SOAP_NS,
      'soapenv'
    );
    envelope.addChildElement('Header', SOAP_NS, null);

    Dom.XmlNode body = envelope.addChildElement('Body', SOAP_NS, null);
    Dom.XmlNode requestNode = body.addChildElement('AddIPP', SERVICE_NS, 'est');
    envelope.setNamespace('est', SERVICE_NS);

    // SysRequest Node
    Dom.XmlNode sysRequestNode = requestNode.addChildElement(
      'SysRequest',
      SERVICE_NS,
      'est'
    );
    sysRequestNode.addChildElement('TransID', null, null).addTextNode(transId);
    sysRequestNode.addChildElement('RequestorID', null, null)
      .addTextNode(FEC_ConstantCommon.REQUESTOR_APS);
    sysRequestNode.addChildElement('DateTime', null, null)
      .addTextNode(timestamp);

    // Request Fields
    requestNode.addChildElement('AccountNumber', null, null)
      .addTextNode(request.accountNumber);
    requestNode.addChildElement('EffectiveDate', null, null)
      .addTextNode(FEC_CommonUltils.formatDate(request.effectiveDate));
    requestNode.addChildElement('Amount', null, null)
      .addTextNode(String.valueOf(request.amount));

    if (String.isNotBlank(request.planNumber)) {
      requestNode.addChildElement('PlanNumber', null, null)
        .addTextNode(request.planNumber);
    }
    if (request.ippTerm != null) {
      requestNode.addChildElement('IPPTerm', null, null)
        .addTextNode(String.valueOf(request.ippTerm));
    }
    if (String.isNotBlank(request.referenceNumber)) {
      requestNode.addChildElement('ReferenceNumber', null, null)
        .addTextNode(request.referenceNumber);
    }
    if (String.isNotBlank(request.transactionPlan)) {
      requestNode.addChildElement('TransactionPlan', null, null)
        .addTextNode(request.transactionPlan);
    }
    if (request.postingDate != null) {
      requestNode.addChildElement('PostingDate', null, null)
        .addTextNode(FEC_CommonUltils.formatDate(request.postingDate));
    }
    if (String.isNotBlank(request.cardNumber)) {
      requestNode.addChildElement('CardNumber', null, null)
        .addTextNode(request.cardNumber);
    }
    if (request.cardSeq != null) {
      requestNode.addChildElement('CardSeq', null, null)
        .addTextNode(String.valueOf(request.cardSeq));
    }
    if (String.isNotBlank(request.ippKey)) {
      requestNode.addChildElement('IPPKey', null, null)
        .addTextNode(request.ippKey);
    }

    return doc;
  }

  public static HttpResponse sendRequest(Dom.Document doc) {
    FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
    FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(
      API_CONFIG_NAME
    );

    String endpoint = apiSetting?.FEC_Call_Mock__c
      ? FEC_MockupEndpoint.ADD_IPP_ENDPOINT_MOCKUP
      : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

    HttpResponse res = FEC_CommonUltils.calloutApi(
      endpoint,
      FEC_ConstantCommon.API_METHOD_POST,
      FEC_ConstantCommon.API_CONTENT_TYPE,
      apiConfig?.FEC_SOAP_Action__c,
      doc,
      null
    );
    return res;
  }

  public static AddIPPResult parseResponse(
    String responseBody,
    Integer httpStatus
  ) {
    AddIPPResult result = new AddIPPResult();
    result.httpStatus = httpStatus;
    result.rawResponse = responseBody;

    try {
      if (String.isBlank(responseBody)) {
        result.errorMessage = System.Label.FEC_MSG_Response_Null;
        result.success = false;
        return result;
      }

      Dom.Document doc = new Dom.Document();
      doc.load(responseBody);

      Dom.XmlNode root = doc.getRootElement();
      if (root == null) {
        return result;
      }

      Dom.XmlNode sysResponseNode = root.getChildElement(
        'SysResponse',
        SERVICE_NS
      );
      if (sysResponseNode == null) {
        sysResponseNode = root.getChildElement('SysResponse', null);
      }

      if (sysResponseNode != null) {
        result.transId = FEC_CommonUltils.getXmlValue(
          sysResponseNode,
          'TransID'
        );
        result.dateTimes = FEC_CommonUltils.getXmlValue(
          sysResponseNode,
          'DateTime'
        );

        String statusStr = FEC_CommonUltils.getXmlValue(
          sysResponseNode,
          'Status'
        );
        result.status = String.isNotBlank(statusStr)
          ? Integer.valueOf(statusStr)
          : 0;

        result.description = FEC_CommonUltils.getXmlValue(
          sysResponseNode,
          'Description'
        );

        result.success = (result.status == 1 ||
        result.description == 'Success');
      } else {
        result.errorMessage = System.Label.FEC_MSG_Response_Sys_Null;
        result.success = false;
        return result;
      }

      result.accountNumber = FEC_CommonUltils.getXmlValue(
        root,
        'AccountNumber'
      );

      String ippTermStr = FEC_CommonUltils.getXmlValue(root, 'IPPTerm');
      result.ippTerm = String.isNotBlank(ippTermStr)
        ? Integer.valueOf(ippTermStr)
        : null;

      String principalStr = FEC_CommonUltils.getXmlValue(
        root,
        'PrincipalAmount'
      );
      result.principalAmount = String.isNotBlank(principalStr)
        ? Decimal.valueOf(principalStr)
        : null;

      String installmentStr = FEC_CommonUltils.getXmlValue(
        root,
        'InstallmentAmount'
      );
      result.installmentAmount = String.isNotBlank(installmentStr)
        ? Decimal.valueOf(installmentStr)
        : null;

      String conversionStr = FEC_CommonUltils.getXmlValue(
        root,
        'ConversionFee'
      );
      result.conversionFee = String.isNotBlank(conversionStr)
        ? Decimal.valueOf(conversionStr)
        : null;

      String emiStr = FEC_CommonUltils.getXmlValue(root, 'EMI');
      result.emi = String.isNotBlank(emiStr) ? Decimal.valueOf(emiStr) : null;

      result.responseDescription = FEC_CommonUltils.getXmlValue(
        root,
        'Description'
      );

      String planStr = FEC_CommonUltils.getXmlValue(root, 'PlanNumber');
      result.planNumber = planStr;

      String interestStr = FEC_CommonUltils.getXmlValue(root, 'InterestRate');
      result.interestRate = String.isNotBlank(interestStr)
        ? Decimal.valueOf(interestStr)
        : null;

      if (result.success == null)
        result.success = true;
    } catch (Exception e) {
      result.errorMessage = String.format(
        System.Label.FEC_MSG_Parse_XML_Error,
        new List<String>{ e.getMessage() }
      );
      result.success = false;
    }

    return result;
  }

  private static void validate(IPPRequest request) {
    // Validate required fields
    if (String.isBlank(request.accountNumber)) {
      throw new FEC_APIServiceException(
        String.format(
          System.Label.FEC_MSG_Param_Required,
          new List<String>{ 'Account Number' }
        )
      );
    }
    if (request.effectiveDate == null) {
      throw new FEC_APIServiceException(
        String.format(
          System.Label.FEC_MSG_Param_Required,
          new List<String>{ 'Effective Date' }
        )
      );
    }
    if (request.amount == null || request.amount <= 0) {
      throw new AuraHandledException(
        String.format(
          System.Label.FEC_MSG_From_To_Invalid,
          new List<String>{ 'Amount', '0' }
        )
      );
    }
  }
}