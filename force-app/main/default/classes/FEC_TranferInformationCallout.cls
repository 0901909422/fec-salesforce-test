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
  public static String generateTransactionID() {
    return String.valueOf(UUID.randomUUID());
  }

  // ============================================================
  // 4. Các Phương thức Gọi API (Refactored like FEC_GetLoanApplicationHistory)
  // ============================================================
  public static HttpResponse sendRequest(TransferCallInput reqObj) {
    String transId = generateTransactionID();
    String timestamp = Datetime.now()
      .formatGMT(FEC_ConstantCommon.DATETIME_FORMAT_GMT_OUTPUT);

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

    String jsonPayload = JSON.serialize(fullRequest);

    FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
    FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(
      API_CONFIG_NAME
    );

    String endpoint = apiSetting?.FEC_Call_Mock__c
      ? FEC_MockupEndpoint.UPDATE_CUSTOMER_CONTACT_ENDPOINT_MOCKUP
      : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

    Http http = new Http();
    HttpRequest req = new HttpRequest();
    req.setEndpoint(endpoint);
    req.setMethod(FEC_ConstantCommon.API_METHOD_POST);
    req.setHeader('Content-Type', FEC_ConstantCommon.API_CONTENT_TYPE_JSON);
    req.setHeader('Accept', FEC_ConstantCommon.API_CONTENT_TYPE_JSON);
    req.setBody(jsonPayload);
    req.setTimeout(60000);

    HttpResponse res = http.send(req);
    return res;
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
      HttpResponse res = sendRequest(reqObj);
      Integer status = (res == null) ? null : res.getStatusCode();
      String body = (res == null) ? null : res.getBody();
      finalResult = parseResponse(body, status);

      if (finalResult.TransID == null)
        finalResult.TransID = generateTransactionID();
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