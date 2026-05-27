public with sharing class FEC_GetAssetsList {
  public static final String API_CONFIG_NAME = 'FEC_Get_Assets_List';
  public static FEC_ResponseLog responseLog;

  public class AssetsListRequest {
    public String ContractNumber;
  }

  public class AssetsListResult {
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
    public List<Asset> assets;

    @AuraEnabled
    public List<Collateral> collaterals;
  }

  public class Asset {
    @AuraEnabled
    public String type;

    @AuraEnabled
    public String description;

    @AuraEnabled
    public String cost;

    @AuraEnabled
    public String currencyCode;

    @AuraEnabled
    public String color;

    @AuraEnabled
    public String amountPledged;

    @AuraEnabled
    public String engineNo;

    @AuraEnabled
    public String chasisNo;

    @AuraEnabled
    public String model;

    @AuraEnabled
    public String aditionalInfo;

    @AuraEnabled
    public String categoryCode;

    @AuraEnabled
    public String supplierName;

    @AuraEnabled
    public String regNo;

    @AuraEnabled
    public String assetBoughtOn;
  }

  public class Collateral {
    @AuraEnabled
    public String value;

    @AuraEnabled
    public String description;

    @AuraEnabled
    public String payoutType;

    @AuraEnabled
    public String makeDate;

    @AuraEnabled
    public String category;

    @AuraEnabled
    public String type;

    @AuraEnabled
    public String lienTitle;

    @AuraEnabled
    public String currencyCode;
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
    AssetsListRequest req,
    String transId,
    String timestamp
  ) {
    validate(req, transId, timestamp);

    String env = '';
    env += '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cif="http://fecredit.com.vn/CIF_LoanInfo">';
    env += '<soapenv:Header/>';
    env += '<soapenv:Body>';
    env += '<cif:GetAssetsList>';
    env += '<Sys>';
    env += '<TransID>' + escapeXml(transId) + '</TransID>';
    env += '<RequestorID>APS</RequestorID>';
    env += '<DateTime>' + escapeXml(timestamp) + '</DateTime>';
    env += '</Sys>';
    env +=
      '<ContractNumber>' +
      escapeXml(req.ContractNumber) +
      '</ContractNumber>';
    env += '</cif:GetAssetsList>';
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
      ? FEC_MockupEndpoint.GET_ASSETS_LIST_ENDPOINT_MOCKUP
      : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
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

  public static AssetsListResult parseResponse(String xml, Integer httpStatus) {
    AssetsListResult result = new AssetsListResult();
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
        'GetAssetsListResponse',
        null
      );
      if (responseNode == null) {
        for (Dom.XmlNode n : body.getChildElements()) {
          if (n.getName().endsWith('GetAssetsListResponse')) {
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
        result.transId = FEC_CommonUltils.getXmlValue(sys, 'TransID');
        result.dateTimeStr = FEC_CommonUltils.getXmlValue(sys, 'DateTime');
        result.code = FEC_CommonUltils.getXmlValue(sys, 'Code');
        result.description = FEC_CommonUltils.getXmlValue(sys, 'Description');
        result.success = (result.code == '1');
      } else {
        result.errorMessage = System.Label.FEC_MSG_Response_Sys_Null;
        result.success = false;
      }

      // Parse Assets
      Dom.XmlNode assetsNode = responseNode.getChildElement('Assets', null);
      if (assetsNode != null) {
        result.assets = new List<Asset>();
        for (Dom.XmlNode aNode : assetsNode.getChildElements()) {
          Asset asset = new Asset();
          asset.type = FEC_CommonUltils.getXmlValue(aNode, 'Type');
          asset.description = FEC_CommonUltils.getXmlValue(
            aNode,
            'Description'
          );
          asset.cost = FEC_CommonUltils.getXmlValue(aNode, 'Cost');
          asset.currencyCode = FEC_CommonUltils.getXmlValue(aNode, 'Currency');
          asset.color = FEC_CommonUltils.getXmlValue(aNode, 'Color');
          asset.amountPledged = FEC_CommonUltils.getXmlValue(
            aNode,
            'AmountPledged'
          );
          asset.engineNo = FEC_CommonUltils.getXmlValue(aNode, 'EngineNo');
          asset.chasisNo = FEC_CommonUltils.getXmlValue(aNode, 'ChasisNo');
          asset.model = FEC_CommonUltils.getXmlValue(aNode, 'Model');
          asset.aditionalInfo = FEC_CommonUltils.getXmlValue(
            aNode,
            'AditionalInfo'
          );
          asset.categoryCode = FEC_CommonUltils.getXmlValue(
            aNode,
            'CategoryCode'
          );
          asset.supplierName = FEC_CommonUltils.getXmlValue(
            aNode,
            'SupplierName'
          );
          asset.regNo = FEC_CommonUltils.getXmlValue(aNode, 'RegNo');
          asset.assetBoughtOn = FEC_CommonUltils.getXmlValue(
            aNode,
            'AssetBoughtOn'
          );
          result.assets.add(asset);
        }
      }

      // Parse Collaterals
      Dom.XmlNode collateralsNode = responseNode.getChildElement(
        'Collaterals',
        null
      );
      if (collateralsNode != null) {
        result.collaterals = new List<Collateral>();
        for (Dom.XmlNode cNode : collateralsNode.getChildElements()) {
          Collateral collateral = new Collateral();
          collateral.value = FEC_CommonUltils.getXmlValue(cNode, 'Value');
          collateral.description = FEC_CommonUltils.getXmlValue(
            cNode,
            'Description'
          );
          collateral.payoutType = FEC_CommonUltils.getXmlValue(
            cNode,
            'PayoutType'
          );
          collateral.makeDate = FEC_CommonUltils.getXmlValue(cNode, 'MakeDate');
          collateral.category = FEC_CommonUltils.getXmlValue(cNode, 'Category');
          collateral.type = FEC_CommonUltils.getXmlValue(cNode, 'Type');
          collateral.lienTitle = FEC_CommonUltils.getXmlValue(
            cNode,
            'LienTitle'
          );
          collateral.currencyCode = FEC_CommonUltils.getXmlValue(
            cNode,
            'Currency'
          );
          result.collaterals.add(collateral);
        }
      }
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
  public static AssetsListResult getAssetsList(AssetsListRequest req) {
    AssetsListResult finalResult = new AssetsListResult();
    String transId = FEC_CommonUltils.generateTransactionId();
    String timestamp = FEC_CommonUltils.formatTimestamp(Datetime.now(), FEC_ConstantCommon.DATETIME_FORMAT);
    String envelope = buildEnvelope(req, transId, timestamp);
    try {
      HttpResponse res = sendRequest(envelope);
      Integer status = (res == null) ? null : res.getStatusCode();
      String body = (res == null) ? null : res.getBody();

      FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
      FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);
      String endpoint = apiSetting?.FEC_Call_Mock__c
        ? FEC_MockupEndpoint.GET_ASSETS_LIST_ENDPOINT_MOCKUP
        : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

      responseLog = new FEC_ResponseLog(
        'FEC_GetAssetsList',
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
    AssetsListRequest req,
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
          new List<String>{ 'ContractNumber' }
        )
      );
    }
  }

  @AuraEnabled
  public static FEC_Asset__c updateCaseAssets(Id caseId) {
    if (caseId == null) {
      return null;
    }

    // Query for the Case to get the Contract Number
    List<Case> cases = [
      SELECT Id, FEC_Contract_Number__c, FEC_Search_Contract_Number__c 
      FROM Case
      WHERE Id = :caseId
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

    // Call the API
    AssetsListRequest req = new AssetsListRequest();
    String contractNumber = cases[0].FEC_Contract_Number__c;

    if (String.isBlank(contractNumber)) {
        contractNumber = cases[0].FEC_Search_Contract_Number__c;
    }
    
    req.ContractNumber = contractNumber != null ? contractNumber.trim() : null;
    
    AssetsListResult response = getAssetsList(req);

    if (
      response == null ||
      !response.success ||
      response.assets == null ||
      response.assets.isEmpty()
    ) {
      throw new AuraHandledException(
        response.errorMessage != null
          ? response.errorMessage
          : System.Label.FEC_MSG_Error_API_Label
      );
    }

    // There is only one FEC_Asset__c record for each case.
    Asset apiAsset = response.assets[0];
    Collateral apiCollateral = (response.collaterals != null &&
      !response.collaterals.isEmpty())
      ? response.collaterals[0]
      : null;

    List<FEC_Asset__c> assetsToUpdate = [
      SELECT Id
      FROM FEC_Asset__c
      WHERE FEC_Case__c = :caseId
      LIMIT 1
    ];

    FEC_Asset__c assetRec = assetsToUpdate.isEmpty()
      ? new FEC_Asset__c(FEC_Case__c = caseId)
      : assetsToUpdate[0];

    assetRec.FEC_Category_Code__c = apiAsset.categoryCode;
    assetRec.FEC_Asset_Type__c = apiAsset.type;
    assetRec.FEC_Asset_Description__c = apiAsset.description;
    assetRec.FEC_Additional_Info__c = apiAsset.aditionalInfo;
    assetRec.FEC_Asset_Model__c = apiAsset.model;
    assetRec.FEC_Asset_Color__c = apiAsset.color;
    assetRec.FEC_Engine_No__c = apiAsset.engineNo;
    assetRec.FEC_Chasis_No__c = apiAsset.chasisNo;
    assetRec.FEC_Reg_No__c = apiAsset.regNo;
    assetRec.FEC_Supplier_Name__c = apiAsset.supplierName;

    assetRec.FEC_Asset_Cost__c = String.isBlank(apiAsset.cost)
      ? null
      : Decimal.valueOf(apiAsset.cost);
    assetRec.FEC_Amount_Pledged__c = String.isBlank(apiAsset.amountPledged)
      ? null
      : Decimal.valueOf(apiAsset.amountPledged);

    assetRec.FEC_Bought_Date__c = String.isBlank(apiAsset.assetBoughtOn)
      ? null
      : Date.valueOf(apiAsset.assetBoughtOn);

    if (apiCollateral != null) {
      assetRec.FEC_Make_Date__c = String.isBlank(apiCollateral.makeDate)
        ? null
        : Date.valueOf(apiCollateral.makeDate);
    }

    upsert assetRec;

    return assetRec;
  }
}