public without sharing class FEC_TranferInformationCallout {
  public static final String API_CONFIG_NAME = 'FEC_Transfer_Call';

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

  // Lớp cho mỗi cặp fieldKey/fieldValue trong mảng 'data'
  public class DataEntry {
    public String fieldKey;
    public String fieldValue;
    public String seqID; // Mã dòng (có thể là tùy chọn hoặc ID tuần tự)

    public DataEntry(String k, String v, String s) {
      this.fieldKey = k;
      this.fieldValue = v;
      this.seqID = s;
    }
  }

  // Lớp cho phần 'Body' chứa genesysId và mảng 'data'
  public class RequestBody {
    public String genesysId;
    public List<DataEntry> data;
  }

  // Lớp gốc cho toàn bộ yêu cầu, chứa header và body
  public class TransferCallRequest {
    public String TransID;
    public String DateTimes;
    public String RequestorID;
    public RequestBody Body;
  }

  // Wrapper for case data mapped to call request fields
  public class CaseCallData {
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
        FEC_Product_Type__r.Name,
        FEC_Account_Contract_Number_Text__c,
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
    data.productType = c.FEC_Product_Type__r?.Name;
    data.extAppId = c.FEC_Account_Contract_Number_Text__c;
    data.phoneNumber = c.FEC_Interaction__r?.FEC_Phone_Number__c;
    data.category = c.FEC_Category__r?.Name;
    data.subCategory = c.FEC_SubCategory__r?.Name;
    data.subCode = c.FEC_SubCode__r?.Name;
    data.remark = c.FEC_Transfer_Call_to_Collections_Remarks__c;
    data.csCaseID = c.FEC_Case_ID__c;
    return data;
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
      throw new AuraHandledException(e.getMessage());
    }
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
  public static String buildRequestPayload(TransferCallInput reqObj, String transId, String timestamp) {
    RequestBody reqBody = new RequestBody();
    reqBody.genesysId = reqObj.genesysId;
    reqBody.data = new List<DataEntry>();

    Integer seqCounter = 1;

    if (reqObj.callData != null) {
      for (String key : reqObj.callData.keySet()) {
        reqBody.data.add(
          new DataEntry(
            key,
            reqObj.callData.get(key),
            String.valueOf(seqCounter++)
          )
        );
      }
    }

    TransferCallRequest fullRequest = new TransferCallRequest();
    fullRequest.TransID = transId;
    fullRequest.DateTimes = timestamp;
    fullRequest.RequestorID = reqObj.requestorId;
    fullRequest.Body = reqBody;

    return JSON.serialize(fullRequest);
  }

  public static HttpResponse sendRequest(String jsonPayload) {
    FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
    FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(
      API_CONFIG_NAME
    );

    String endpoint = apiSetting?.FEC_Call_Mock__c
      ? FEC_MockupEndpoint.UPDATE_CUSTOMER_CONTACT_ENDPOINT_MOCKUP
      : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

    Map<String, String> headers = new Map<String, String>{
      'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
      'Accept' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
    };

    return FEC_CommonUltils.calloutApiWithHeaders(
      endpoint,
      FEC_ConstantCommon.API_METHOD_POST,
      headers,
      jsonPayload
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
      String transId = FEC_CommonUltils.generateTransactionId();
      String timestamp = FEC_CommonUltils.formatTimestamp(Datetime.now(), FEC_ConstantCommon.DATETIME_FORMAT);
      String jsonPayload = buildRequestPayload(reqObj, transId, timestamp);

      HttpResponse res = sendRequest(jsonPayload);
      Integer status = (res == null) ? null : res.getStatusCode();
      String body = (res == null) ? null : res.getBody();

      FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
      FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);
      String endpoint = apiSetting?.FEC_Call_Mock__c
        ? FEC_MockupEndpoint.UPDATE_CUSTOMER_CONTACT_ENDPOINT_MOCKUP
        : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

      FEC_CommonUltils.logApi(
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
  }
}