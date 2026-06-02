/****************************************************************************************
 * File Name    : FEC_GetRepaymentScheduleByAppIdCallout
 * Description  : REST GetRepaymentScheduleByAppID — lịch trả nợ theo Application ID
 *                (internal-apps-api/sales/repayment-schedule)
 ****************************************************************************************/
public with sharing class FEC_GetRepaymentScheduleByAppIdCallout {

  public static final String API_CONFIG_NAME = 'FEC_Get_Repayment_Schedule_By_App_Id';

  private static ResponseLog responseLog;

  public class RepaymentScheduleRequest {
    public Map<String, String> headers;
    public List<String> parameters;
    public Map<String, Object> body;
  }

  public class GetRepaymentScheduleResponse {
    @AuraEnabled public String pxObjClass;
    @AuraEnabled public List<RepaymentScheduleDataRecord> Data;
    @AuraEnabled public String errorCode;
    @AuraEnabled public String errorMessage;
  }

  public class RepaymentScheduleDataRecord {
    @AuraEnabled public RepaymentScheduleResponseInfo ResponseInfo;
  }

  public class RepaymentScheduleResponseInfo {
    @AuraEnabled public String ADDRESS;
    @AuraEnabled public String CC_CODE;
    @AuraEnabled public String CONTRACT_NUMBER;
    //PhongBT 02/06/26: Thêm DSA_CODE, END_DATE theo mapping PDF RL04.02
    @AuraEnabled public String DSA_CODE;
    @AuraEnabled public String END_DATE;
    @AuraEnabled public String CUSTOMER_NAME;
    @AuraEnabled public String FIRST_DATE_REPAYMENT;
    @AuraEnabled public String ID_DATE;
    @AuraEnabled public String ID_NO;
    @AuraEnabled public String IDCARD_ISSUEPLACE;
    @AuraEnabled public Boolean IS_MORATORIUM_RATE;
    @AuraEnabled public Boolean IS_NORMAL_RATE;
    @AuraEnabled public Decimal MONTHLY_RATE;
    @AuraEnabled public String MULTI_RATE_APPLICABLE;
    @AuraEnabled public Integer N_TENURE;
    @AuraEnabled public Decimal OVERLAP_INT_RATE;
    @AuraEnabled public Decimal TOTAL_LOAN_AMOUNT;
    @AuraEnabled public String TOTAL_LOAN_AMOUNT_WORDS;
    @AuraEnabled public Decimal X_RATE;
    @AuraEnabled public Decimal Y_RATE;
    @AuraEnabled public Decimal YEARLY_RATE;
    @AuraEnabled public List<RepaymentScheduleItem> RepaymentScheduleItems;
    @AuraEnabled public String DateTimeStr;
    @AuraEnabled public String Guid;
    @AuraEnabled public String Message;
    @AuraEnabled public String pxObjClass;
    @AuraEnabled public String Status;
  }

  public class RepaymentScheduleItem {
    @AuraEnabled public String DUE_DATE;
    @AuraEnabled public Decimal PRINCIPAL_AMOUNT;
    @AuraEnabled public Decimal INTEREST_AMOUNT;
    @AuraEnabled public Decimal REMAINING_PRINCIPAL_AMOUNT;
    @AuraEnabled public Decimal REPAYMENT_FEE;
    @AuraEnabled public Decimal TOTAL_REPAYMENT_FEE;
  }

  public class ResponseLog {
    public String apiName;
    public String endpoint;
    public String method;
    public String requestBody;
    public HttpResponse response;
    public String errorMessage;

    public ResponseLog(
      String apiName,
      String endpoint,
      String method,
      String requestBody,
      HttpResponse response,
      String errorMessage
    ) {
      this.apiName = apiName;
      this.endpoint = endpoint;
      this.method = method;
      this.requestBody = requestBody;
      this.response = response;
      this.errorMessage = errorMessage;
    }
  }

  public static GetRepaymentScheduleResponse getRepaymentScheduleByAppId(
    String applicationId,
    String fecRequestor
  ) {
    GetRepaymentScheduleResponse result = new GetRepaymentScheduleResponse();
    try {
      validateApplicationId(applicationId);

      String requestor = String.isNotBlank(fecRequestor)
        ? fecRequestor.trim()
        : FEC_ConstantCommon.REQUESTOR_PEGA_CSM;

      RepaymentScheduleRequest reqWrapper = new RepaymentScheduleRequest();
      reqWrapper.headers = new Map<String, String>{
        'FEC-Requestor' => requestor
      };
      reqWrapper.parameters = new List<String>{ applicationId.trim() };
      reqWrapper.body = new Map<String, Object>();

      String requestBodyJson = JSON.serialize(reqWrapper);

      FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
      FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);

      String endpoint = FEC_CommonUltils.buildCalloutEndpoint(
        apiSetting?.FEC_Endpoint__c,
        apiConfig?.FEC_Endpoint__c
      );

      Map<String, String> httpHeaders = new Map<String, String>{
        'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
        'FEC-Requestor' => requestor
      };

      HttpResponse res = FEC_CommonUltils.calloutApiWithHeaders(
        endpoint,
        FEC_ConstantCommon.API_METHOD_POST,
        httpHeaders,
        requestBodyJson
      );

      responseLog = new ResponseLog(
        'FEC_GetRepaymentScheduleByAppIdCallout',
        endpoint,
        FEC_ConstantCommon.API_METHOD_POST,
        requestBodyJson,
        res,
        null
      );

      FEC_CommonUltils.logApi(
        responseLog.apiName,
        responseLog.endpoint,
        responseLog.method,
        responseLog.requestBody,
        responseLog.response,
        responseLog.errorMessage
      );

      if (res == null || res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
        result.errorCode = res == null
          ? 'NO_RESPONSE'
          : String.valueOf(res.getStatusCode());
        result.errorMessage = res == null
          ? System.Label.FEC_MSG_Response_Null
          : res.getStatus() + ' - ' + res.getBody();
        return result;
      }

      result = parseResponseBody(res.getBody());
    } catch (Exception ex) {
      result.errorCode = 'CALLOUT_EXCEPTION';
      result.errorMessage = ex.getMessage();
      if (responseLog != null) {
        responseLog.errorMessage = ex.getMessage();
      }
    }
    return result;
  }

  @TestVisible
  private static GetRepaymentScheduleResponse parseResponseBody(String jsonBody) {
    GetRepaymentScheduleResponse parsed = (GetRepaymentScheduleResponse) JSON.deserialize(
      jsonBody,
      GetRepaymentScheduleResponse.class
    );
    if (parsed == null) {
      parsed = new GetRepaymentScheduleResponse();
    }

    if (parsed.Data != null && !parsed.Data.isEmpty()) {
      return parsed;
    }

    Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
    if (root == null) {
      return parsed;
    }

    Object dataObj = root.get('Data');
    if (!(dataObj instanceof List<Object>)) {
      return parsed;
    }

    List<RepaymentScheduleDataRecord> records = new List<RepaymentScheduleDataRecord>();
    for (Object itemObj : (List<Object>) dataObj) {
      if (!(itemObj instanceof Map<String, Object>)) {
        continue;
      }
      Map<String, Object> itemMap = (Map<String, Object>) itemObj;
      RepaymentScheduleDataRecord rec = new RepaymentScheduleDataRecord();
      Object infoObj = itemMap.get('ResponseInfo');
      if (infoObj instanceof Map<String, Object>) {
        rec.ResponseInfo = mapResponseInfo((Map<String, Object>) infoObj);
      } else {
        rec.ResponseInfo = mapResponseInfo(itemMap);
      }
      records.add(rec);
    }
    parsed.Data = records;
    return parsed;
  }

  @TestVisible
  private static RepaymentScheduleResponseInfo mapResponseInfo(
    Map<String, Object> infoMap
  ) {
    RepaymentScheduleResponseInfo info = new RepaymentScheduleResponseInfo();
    info.ADDRESS = (String) infoMap.get('ADDRESS');
    info.CC_CODE = (String) infoMap.get('CC_CODE');
    info.CONTRACT_NUMBER = (String) infoMap.get('CONTRACT_NUMBER');
    info.DSA_CODE = (String) infoMap.get('DSA_CODE');
    info.END_DATE = (String) infoMap.get('END_DATE');
    info.CUSTOMER_NAME = (String) infoMap.get('CUSTOMER_NAME');
    info.FIRST_DATE_REPAYMENT = (String) infoMap.get('FIRST_DATE_REPAYMENT');
    info.ID_DATE = (String) infoMap.get('ID_DATE');
    info.ID_NO = (String) infoMap.get('ID_NO');
    info.IDCARD_ISSUEPLACE = (String) infoMap.get('IDCARD_ISSUEPLACE');
    info.IS_MORATORIUM_RATE = toBoolean(infoMap.get('IS_MORATORIUM_RATE'));
    info.IS_NORMAL_RATE = toBoolean(infoMap.get('IS_NORMAL_RATE'));
    info.MONTHLY_RATE = toDecimal(infoMap.get('MONTHLY_RATE'));
    info.MULTI_RATE_APPLICABLE = (String) infoMap.get('MULTI_RATE_APPLICABLE');
    info.N_TENURE = toInteger(infoMap.get('N_TENURE'));
    info.OVERLAP_INT_RATE = toDecimal(infoMap.get('OVERLAP_INT_RATE'));
    info.TOTAL_LOAN_AMOUNT = toDecimal(infoMap.get('TOTAL_LOAN_AMOUNT'));
    info.TOTAL_LOAN_AMOUNT_WORDS = (String) infoMap.get('TOTAL_LOAN_AMOUNT_WORDS');
    info.X_RATE = toDecimal(infoMap.get('X_RATE'));
    info.Y_RATE = toDecimal(infoMap.get('Y_RATE'));
    info.YEARLY_RATE = toDecimal(infoMap.get('YEARLY_RATE'));
    info.DateTimeStr = (String) infoMap.get('DateTime');
    info.Guid = (String) infoMap.get('Guid');
    info.Message = (String) infoMap.get('Message');
    info.pxObjClass = (String) infoMap.get('pxObjClass');
    info.Status = (String) infoMap.get('Status');

    Object itemsObj = infoMap.get('RepaymentScheduleItems');
    if (itemsObj instanceof List<Object>) {
      info.RepaymentScheduleItems = new List<RepaymentScheduleItem>();
      for (Object rowObj : (List<Object>) itemsObj) {
        if (!(rowObj instanceof Map<String, Object>)) {
          continue;
        }
        Map<String, Object> rowMap = (Map<String, Object>) rowObj;
        RepaymentScheduleItem row = new RepaymentScheduleItem();
        row.DUE_DATE = (String) rowMap.get('DUE_DATE');
        row.PRINCIPAL_AMOUNT = toDecimal(rowMap.get('PRINCIPAL_AMOUNT'));
        row.INTEREST_AMOUNT = toDecimal(rowMap.get('INTEREST_AMOUNT'));
        row.REMAINING_PRINCIPAL_AMOUNT = toDecimal(
          rowMap.get('REMAINING_PRINCIPAL_AMOUNT')
        );
        row.REPAYMENT_FEE = toDecimal(rowMap.get('REPAYMENT_FEE'));
        row.TOTAL_REPAYMENT_FEE = toDecimal(rowMap.get('TOTAL_REPAYMENT_FEE'));
        info.RepaymentScheduleItems.add(row);
      }
    }
    return info;
  }

  private static Boolean toBoolean(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof Boolean) {
      return (Boolean) value;
    }
    String s = String.valueOf(value);
    return 'true'.equalsIgnoreCase(s) || 'Y'.equalsIgnoreCase(s) || '1'.equals(s);
  }

  private static Integer toInteger(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof Integer) {
      return (Integer) value;
    }
    if (value instanceof Decimal) {
      return ((Decimal) value).intValue();
    }
    return Integer.valueOf(String.valueOf(value));
  }

  private static Decimal toDecimal(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof Decimal) {
      return (Decimal) value;
    }
    if (value instanceof Integer) {
      return Decimal.valueOf((Integer) value);
    }
    if (value instanceof Long) {
      return Decimal.valueOf((Long) value);
    }
    if (value instanceof Double) {
      return Decimal.valueOf((Double) value);
    }
    return Decimal.valueOf(String.valueOf(value));
  }

  public static Boolean isSuccess(GetRepaymentScheduleResponse response) {
    RepaymentScheduleResponseInfo info = getFirstResponseInfo(response);
    return info != null && 'SUCCESS'.equalsIgnoreCase(info.Status);
  }

  public static RepaymentScheduleResponseInfo getFirstResponseInfo(
    GetRepaymentScheduleResponse response
  ) {
    if (
      response == null ||
      response.Data == null ||
      response.Data.isEmpty() ||
      response.Data[0].ResponseInfo == null
    ) {
      return null;
    }
    return response.Data[0].ResponseInfo;
  }

  private static void validateApplicationId(String applicationId) {
    if (String.isBlank(applicationId)) {
      throw new CalloutException(
        String.format(
          System.Label.FEC_MSG_Param_Required,
          new List<String>{ 'ApplicationId' }
        )
      );
    }
  }
}
