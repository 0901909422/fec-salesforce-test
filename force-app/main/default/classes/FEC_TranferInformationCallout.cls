public without sharing class FEC_TranferInformationCallout {
  public static final String API_CONFIG_NAME = 'FEC_Transfer_Call';
  public static FEC_ResponseLog responseLog;

  // ============================================================
  // 1. Cấu trúc JSON Request Body
  // ============================================================

  public class TransferCallInput {
    @AuraEnabled
    public String genesysId { get; set; }
    @AuraEnabled
    public String requestorId { get; set; }
    @AuraEnabled
    public Map<String, String> callData { get; set; }
  }

  /** Phần tử mảng body.data — chỉ fieldKey / fieldValue theo contract API */
  public class TransferDataEntry {
    public String fieldKey;
    public String fieldValue;

    public TransferDataEntry(String k, String v) {
      this.fieldKey = k;
      this.fieldValue = v;
    }
  }

  /** Body JSON gửi Pega: genesysId, data[], csCaseID — không bọc headers trong body. */
  public class TransferCallRequestBody {
    public String genesysId;
    public List<TransferDataEntry> data;
    public String csCaseID;
  }

  private static final List<String> CALL_DATA_FIELD_ORDER = new List<String>{
    'productType',
    'extAppId',
    'phoneNumber',
    'category',
    'subCategory',
    'subCode',
    'remark'
  };

  /** DateTime trên HTTP header — khớp Postman/Pega: yyyyMMddTHHmmss.SSS GMT */
  private static String formatTransferRequestDateTime(Datetime dt) {
    Datetime useDt = dt == null ? Datetime.now() : dt;
    return useDt.formatGMT('yyyyMMdd\'T\'HHmmss.SSS') + ' GMT';
  }

  // Wrapper for case data mapped to call request fields
  public class CaseCallData {
    /** Genesys id: trên Case Interaction là chính record; Case KH lấy từ Interaction cha (lookup). */
    @AuraEnabled public String genesysId { get; set; }
    @AuraEnabled public String productType { get; set; }
    @AuraEnabled public String extAppId { get; set; }
    @AuraEnabled public String phoneNumber { get; set; }
    @AuraEnabled public String category { get; set; }
    @AuraEnabled public String subCategory { get; set; }
    @AuraEnabled public String subCode { get; set; }
    @AuraEnabled public String remark { get; set; }
    @AuraEnabled public String csCaseID { get; set; }
  }

  public static CaseCallData getCaseCallData(Id caseId) {
    if (caseId == null) {
      return null;
    }
    Case c = [
      SELECT
        FEC_External_Interaction_ID__c,
        FEC_Interaction__r.FEC_External_Interaction_ID__c,
        FEC_Product_Type__r.Name,
        FEC_Account_Contract_Number_Text__c,
        FEC_Phone_Number__c,
        FEC_Case_Phone_Number__c,
        FEC_Interaction__r.FEC_Phone_Number__c,
        FEC_Category__r.Name,
        FEC_SubCategory__r.Name,
        FEC_SubCode__r.Name,
        FEC_Transfer_Call_to_Collections_Remarks__c,
        FEC_Case_ID__c
      FROM Case
      WHERE Id = :caseId
      WITH SECURITY_ENFORCED
      LIMIT 1
    ];

    CaseCallData data = new CaseCallData();
    data.genesysId = String.isNotBlank(c.FEC_External_Interaction_ID__c)
      ? c.FEC_External_Interaction_ID__c
      : c.FEC_Interaction__r?.FEC_External_Interaction_ID__c;
    data.productType = c.FEC_Product_Type__r?.Name;
    data.extAppId = c.FEC_Account_Contract_Number_Text__c;
    // Interaction Phone trên Case; nếu trống lấy từ Interaction cha; cuối cùng Phone Number (nghiệp vụ Case).
    if (String.isNotBlank(c.FEC_Phone_Number__c)) {
      data.phoneNumber = c.FEC_Phone_Number__c;
    } else if (String.isNotBlank(c.FEC_Interaction__r?.FEC_Phone_Number__c)) {
      data.phoneNumber = c.FEC_Interaction__r.FEC_Phone_Number__c;
    } else {
      data.phoneNumber = c.FEC_Case_Phone_Number__c;
    }
    data.category = c.FEC_Category__r?.Name;
    data.subCategory = c.FEC_SubCategory__r?.Name;
    data.subCode = c.FEC_SubCode__r?.Name;
    data.remark = c.FEC_Transfer_Call_to_Collections_Remarks__c;
    data.csCaseID = c.FEC_Case_ID__c;
    return data;
  }

  /**
   * LWC: transfer chỉ cần Case Id — lấy Genesys ID từ Interaction, RequestorID chuẩn CSM.
   */
  @AuraEnabled
  public static TransferCallResponse transferCallFromCase(Id caseId) {
    try {
      CaseCallData data = getCaseCallData(caseId);
      if (data == null) {
        TransferCallResponse res = new TransferCallResponse();
        res.success = false;
        res.errorMessage = String.format(
          System.Label.FEC_MSG_Param_Required,
          new List<String>{ 'Case ID' }
        );
        res.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
        return res;
      }
      return transferCallByCase(
        caseId,
        data.genesysId,
        FEC_ConstantCommon.API_REQUESTOR_ID
      );
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, e.getMessage() + '\n' + e.getStackTraceString());
      TransferCallResponse err = new TransferCallResponse();
      err.success = false;
      err.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
      err.errorMessage = formatExceptionDetail(e);
      err.ResultOfClass = err.errorMessage;
      return err;
    }
  }

  @AuraEnabled
  public static TransferCallResponse transferCallByCase(
    Id caseId,
    String genesysId,
    String requestorId
  ) {
    try {
      CaseCallData data = getCaseCallData(caseId);
      if (data == null) {
        TransferCallResponse res = new TransferCallResponse();
        res.success = false;
        res.errorMessage = String.format(
          System.Label.FEC_MSG_Param_Required,
          new List<String>{ 'Case ID' }
        );
        res.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
        return res;
      }

      TransferCallInput reqObj = new TransferCallInput();
      reqObj.genesysId = genesysId;
      reqObj.requestorId = requestorId;
      reqObj.callData = new Map<String, String>{
        'productType' => data.productType,
        'extAppId' => data.extAppId,
        'phoneNumber' => data.phoneNumber,
        'category' => data.category,
        'subCategory' => data.subCategory,
        'subCode' => data.subCode,
        'remark' => data.remark,
        'csCaseID' => data.csCaseID
      };

      return transferCall(reqObj);
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, e.getMessage() + '\n' + e.getStackTraceString());
      TransferCallResponse err = new TransferCallResponse();
      err.success = false;
      err.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
      err.errorMessage = formatExceptionDetail(e);
      err.ResultOfClass = err.errorMessage;
      return err;
    }
  }

  private static String formatExceptionDetail(Exception e) {
    List<String> parts = new List<String>();
    if (String.isNotBlank(e.getMessage())) {
      parts.add(e.getMessage());
    }
    parts.add('[' + e.getTypeName() + ']');
    Exception cause = e.getCause();
    while (cause != null) {
      if (String.isNotBlank(cause.getMessage())) {
        parts.add('Cause: ' + cause.getMessage());
      }
      cause = cause.getCause();
    }
    String msg = String.join(parts, ' ');
    return String.isNotBlank(msg) ? msg : '[' + e.getTypeName() + ']';
  }

  // ============================================================
  // 2. Cấu trúc JSON Response Body
  // ============================================================
  public class TransferCallResponse {
    @AuraEnabled
    public String Code; // Mã kết quả (ví dụ: 'Y')

    @AuraEnabled
    public String ResultOfClass; // Mô tả kết quả

    @AuraEnabled
    public String TransID; // ID giao dịch phản hồi

    @AuraEnabled
    public Integer httpStatus;

    @AuraEnabled
    public String rawResponse;

    @AuraEnabled
    public Boolean success;

    @AuraEnabled
    public String errorMessage;
  }

  // ============================================================
  // 3. Hàm tạo Transaction ID (UUID)
  // ============================================================

  // ============================================================
  // 4. Các Phương thức Gọi API (Refactored like FEC_GetLoanApplicationHistory)
  // ============================================================
  /** Chỉ body JSON (genesysId, data, csCaseID) — TransID/RequestorID/DateTime là HTTP header. */
  public static String buildRequestBodyJson(TransferCallInput reqObj) {
    TransferCallRequestBody reqBody = new TransferCallRequestBody();
    reqBody.genesysId = reqObj.genesysId;
    reqBody.csCaseID = reqObj.callData != null
      ? reqObj.callData.get('csCaseID')
      : null;
    reqBody.data = new List<TransferDataEntry>();

    if (reqObj.callData != null) {
      for (String key : CALL_DATA_FIELD_ORDER) {
        reqBody.data.add(
          new TransferDataEntry(key, reqObj.callData.get(key))
        );
      }
    }

    return JSON.serialize(reqBody);
  }

  public static HttpResponse sendRequest(
    String jsonBody,
    String transId,
    String requestorId,
    String dateTimeHeader
  ) {
    FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
    FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(
      API_CONFIG_NAME
    );

    String endpoint = apiSetting?.FEC_Call_Mock__c
      ? FEC_MockupEndpoint.UPDATE_CUSTOMER_CONTACT_ENDPOINT_MOCKUP
      : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

    Map<String, String> headers = new Map<String, String>{
      'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
      'Accept' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
      'TransID' => transId,
      'RequestorID' => requestorId,
      'DateTime' => dateTimeHeader
    };

    return FEC_CommonUltils.calloutApiWithHeaders(
      endpoint,
      FEC_ConstantCommon.API_METHOD_POST,
      headers,
      jsonBody
    );
  }

  public static TransferCallResponse parseResponse(
    String jsonResponse,
    Integer httpStatus
  ) {
    TransferCallResponse result = new TransferCallResponse();
    result.httpStatus = httpStatus;
    result.rawResponse = jsonResponse;

    if (String.isBlank(jsonResponse)) {
      result.errorMessage = System.Label.FEC_MSG_Response_Null;
      result.success = false;
      result.Code = 'E';
      return result;
    }

    try {
      TransferCallResponse parsed = (TransferCallResponse) JSON.deserialize(
        jsonResponse,
        TransferCallResponse.class
      );
      result.Code = parsed.Code;
      result.ResultOfClass = parsed.ResultOfClass;
      result.TransID = parsed.TransID;

      result.success = (result.Code == FEC_ConstantCommon.SUCCESS_CODE_1 ||
      result.Code == FEC_ConstantCommon.SUCCESS_CODE_Y ||
      result.Code == FEC_ConstantCommon.SUCCESS_MESSAGE);
      if (
        !result.success &&
        String.isBlank(result.errorMessage) &&
        String.isNotBlank(result.ResultOfClass)
      ) {
        result.errorMessage = result.ResultOfClass;
      }
    } catch (Exception ex) {
      result.errorMessage = String.format(
        System.Label.FEC_MSG_Parse_XML_Error,
        new List<String>{ ex.getMessage() }
      );
      result.success = false;
      result.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
      result.ResultOfClass = result.errorMessage;
    }
    return result;
  }

  @AuraEnabled
  public static TransferCallResponse transferCall(TransferCallInput reqObj) {
    validate(reqObj);
    TransferCallResponse finalResult = new TransferCallResponse();
    try {
      String transId = FEC_CommonUltils.generateTransactionUUID();
      Datetime nowDt = Datetime.now();
      String timestamp = formatTransferRequestDateTime(nowDt);
      String jsonPayload = buildRequestBodyJson(reqObj);

      HttpResponse res = sendRequest(
        jsonPayload,
        transId,
        reqObj.requestorId,
        timestamp
      );
      Integer status = (res == null) ? null : res.getStatusCode();
      String body = (res == null) ? null : res.getBody();

      FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
      FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);
      String endpoint = apiSetting?.FEC_Call_Mock__c
        ? FEC_MockupEndpoint.UPDATE_CUSTOMER_CONTACT_ENDPOINT_MOCKUP
        : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

      responseLog = new FEC_ResponseLog(
        'FEC_TranferInformationCallout',
        endpoint,
        FEC_ConstantCommon.API_METHOD_POST,
        jsonPayload,
        res,
        null
      );

      finalResult = parseResponse(body, status);

      if (finalResult.TransID == null)
        finalResult.TransID = transId;
      if (finalResult.httpStatus == null)
        finalResult.httpStatus = status;
      if (finalResult.rawResponse == null)
        finalResult.rawResponse = body;

      String logError = null;
      if (!finalResult.success) {
        logError = String.isNotBlank(finalResult.errorMessage)
          ? finalResult.errorMessage
          : finalResult.ResultOfClass;
      }
      if (responseLog != null) {
        responseLog.errorMessage = logError;
      }
      if (res != null) {
        FEC_CommonUltils.logApi(
          'FEC_TranferInformationCallout',
          endpoint,
          FEC_ConstantCommon.API_METHOD_POST,
          jsonPayload,
          res,
          logError
        );
      }
    } catch (Exception ex) {
      finalResult.errorMessage = ex.getMessage();
      finalResult.success = false;
      finalResult.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
      finalResult.ResultOfClass = ex.getMessage();
    }
    return finalResult;
  }

  private static void validate(TransferCallInput reqObj) {
    if (String.isBlank(reqObj.genesysId)) {
      throw new FEC_APIServiceException(
        String.format(
          System.Label.FEC_MSG_Param_Required,
          new List<String>{ 'Genesys ID' }
        )
      );
    }
    if (String.isBlank(reqObj.requestorId)) {
      throw new FEC_APIServiceException(
        String.format(
          System.Label.FEC_MSG_Param_Required,
          new List<String>{ 'Requestor ID' }
        )
      );
    }
    
    if (reqObj.callData == null || reqObj.callData.isEmpty()) {
      throw new FEC_APIServiceException(
        String.format(
          System.Label.FEC_MSG_Param_Required,
          new List<String>{ 'Call Data' }
        )
      );
    }

    Map<String, String> requiredFields = new Map<String, String>{
      'productType' => 'Product Type',
      'extAppId' => 'Ext App ID',
      'phoneNumber' => 'Phone Number',
      'category' => 'Category',
      'subCategory' => 'Sub Category',
      'subCode' => 'Sub Code',
      'remark' => 'Remark',
      'csCaseID' => 'CS Case ID'
    };

    for (String key : requiredFields.keySet()) {
      if (String.isBlank(reqObj.callData.get(key))) {
        throw new FEC_APIServiceException(
          String.format(
            System.Label.FEC_MSG_Param_Required,
            new List<String>{ requiredFields.get(key) }
          )
        );
      }
    }
  }
}