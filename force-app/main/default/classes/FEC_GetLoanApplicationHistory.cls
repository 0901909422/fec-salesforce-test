public with sharing class FEC_GetLoanApplicationHistory {
  public static final String API_CONFIG_NAME = 'FEC_Get_Loan_Application_History';
  public static FEC_ResponseLog responseLog;

  public class LoanApplicationHistoryRequest {
    public String applicationId;
  }

  public class LoanApplicationHistoryResult {
    @AuraEnabled
    public String transId;

    @AuraEnabled
    public String dateTimeStr;

    @AuraEnabled
    public Integer code;

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
    public List<ApplicationHistory> histories;
  }

  public class ApplicationHistory {
    @AuraEnabled
    public String applicationId;

    @AuraEnabled
    public String userId;

    @AuraEnabled
    public String userName;

    @AuraEnabled
    public String activityId;

    @AuraEnabled
    public String activityName;

    @AuraEnabled
    public String statusId;

    @AuraEnabled
    public String editDate;

    @AuraEnabled
    public String endDate;

    @AuraEnabled
    public String createdDate;
  }

  public static HttpResponse sendRequest(String endpoint, Map<String, String> headers) {
    return FEC_CommonUltils.calloutApiWithHeaders(
      endpoint,
      FEC_ConstantCommon.API_METHOD_GET,
      headers,
      null
    );
  }

  public static LoanApplicationHistoryResult parseResponse(
    String jsonResponse,
    Integer httpStatus
  ) {
    LoanApplicationHistoryResult result = new LoanApplicationHistoryResult();
    result.httpStatus = httpStatus;
    result.rawResponse = jsonResponse;
    if (jsonResponse == null) {
      result.errorMessage = System.Label.FEC_MSG_Response_Null;
      result.success = false;
      return result;
    }

    try {
      Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(
        jsonResponse
      );

      // Parse Sys
      Map<String, Object> sysMap = (Map<String, Object>) responseMap.get('Sys');
      if (sysMap != null) {
        result.transId = (String) sysMap.get('TransID');
        result.dateTimeStr = (String) sysMap.get('DateTime');
        result.code = (Integer) sysMap.get('Code');
        result.description = (String) sysMap.get('Description');
        result.success = (result.code == 1);
      } else {
        result.errorMessage = System.Label.FEC_MSG_Response_Sys_Null;
        result.success = false;
        return result;
      }

      // Parse AppInfos
      // Support both 'AppInfos' and 'AppInfors' (typo in some API versions)
      List<Object> appInfosList = (List<Object>) responseMap.get('AppInfos');
      if (appInfosList == null) {
        appInfosList = (List<Object>) responseMap.get('AppInfors');
      }
      if (appInfosList != null && appInfosList.size() > 0) {
        result.histories = new List<ApplicationHistory>();
        for (Object appInfoObj : appInfosList) {
          Map<String, Object> appInfoMap = (Map<String, Object>) appInfoObj;
          ApplicationHistory appInfo = new ApplicationHistory();
          appInfo.applicationId = (String) appInfoMap.get('APPLICATION_ID');
          appInfo.userId = (String) appInfoMap.get('USER_ID');
          appInfo.userName = (String) appInfoMap.get('USER_NAME');
          appInfo.activityId = (String) appInfoMap.get('ACTIVITIY_ID');
          appInfo.activityName = (String) appInfoMap.get('ACTIVITIY_NAME');
          appInfo.statusId = (String) appInfoMap.get('STATUS_ID');
          appInfo.editDate = (String) appInfoMap.get('EDIT_DATE');
          appInfo.endDate = (String) appInfoMap.get('END_DATE');
          appInfo.createdDate = (String) appInfoMap.get('CREATED_DATE');
          result.histories.add(appInfo);
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
  public static LoanApplicationHistoryResult getLoanApplicationHistory(
    LoanApplicationHistoryRequest req
  ) {
    validate(req);
    LoanApplicationHistoryResult finalResult = new LoanApplicationHistoryResult();
    try {
      FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
      FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);

      String baseEndpoint = apiSetting?.FEC_Call_Mock__c
        ? FEC_MockupEndpoint.GET_APP_INFOS_ENDPOINT_MOCKUP
        : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

      String endpoint = baseEndpoint + '?APPLICATION_ID=' + req.applicationId;
      String transId = FEC_CommonUltils.generateTransactionUUID();

      Map<String, String> headers = new Map<String, String>{
        'TransID'      => transId,
        'DateTime'     => FEC_CommonUltils.formatTimestamp(Datetime.now(), FEC_ConstantCommon.STR_DATETIME_FORMAT_Z),
        'RequestorID'  => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
        'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
      };

      HttpResponse res = sendRequest(endpoint, headers);

      responseLog = new FEC_ResponseLog(
        'FEC_GetLoanApplicationHistory',
        endpoint,
        FEC_ConstantCommon.API_METHOD_GET,
        FEC_ConstantCommon.API_BLANK_BODY,
        res,
        null
      );

      Integer status = (res == null) ? null : res.getStatusCode();
      String body = (res == null) ? null : res.getBody();
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

  private static void validate(LoanApplicationHistoryRequest req) {
    if (String.isBlank(req.applicationId)) {
      throw new FEC_APIServiceException(
        String.format(
          System.Label.FEC_MSG_Param_Required,
          new List<String>{ 'ApplicationId' }
        )
      );
    }
  }

  @AuraEnabled
  public static FEC_Application_History__c updateCaseApplicationHistory(
    Id caseId
  ) {
    if (caseId == null) {
      return null;
    }

    // Query for the Case to get the Application ID
    List<Case> cases = [
      SELECT Id, FEC_Application_ID__c, FEC_Search_Application_ID__c
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

    if (String.isBlank(cases[0].FEC_Application_ID__c) && String.isBlank(cases[0].FEC_Search_Application_ID__c)) {
      throw new AuraHandledException(
        String.format(
          System.Label.FEC_MSG_Invalid,
          new List<String>{ 'Application ID' }
        )
      );
    }

    // Call the API
    LoanApplicationHistoryRequest req = new LoanApplicationHistoryRequest();
    req.applicationId = cases[0].FEC_Application_ID__c;
    if (String.isBlank(req.applicationId)) {
        req.applicationId = cases[0].FEC_Search_Application_ID__c;
    }
    LoanApplicationHistoryResult response = getLoanApplicationHistory(req);

    if (
      response == null ||
      !response.success ||
      response.histories == null ||
      response.histories.isEmpty()
    ) {
      throw new AuraHandledException(
        response != null &&
          response.errorMessage != null
          ? response.errorMessage
          : System.Label.FEC_MSG_Error_API_Label
      );
    }

    List<FEC_Application_History__c> historiesToUpdate = [
      SELECT Id, FEC_Activity_ID__c
      FROM FEC_Application_History__c
      WHERE FEC_Case__c = :caseId
      LIMIT 1
    ];

    FEC_Application_History__c historyRec;
    if (historiesToUpdate.isEmpty()) {
      historyRec = new FEC_Application_History__c(FEC_Case__c = caseId);
    } else {
      historyRec = historiesToUpdate[0];
    }

    ApplicationHistory targetApiHistory;

    if (!response.histories.isEmpty()) {
      targetApiHistory = response.histories[0];
    }

    if (targetApiHistory != null) {
      historyRec.FEC_User__c = targetApiHistory.userName;
      historyRec.FEC_Activity_ID__c = targetApiHistory.activityId;
      historyRec.FEC_Status__c = targetApiHistory.statusId;
      historyRec.FEC_Edit_Date__c = String.isNotBlank(targetApiHistory.editDate)
        ? Date.valueOf(targetApiHistory.editDate)
        : null;

      upsert historyRec;
    }

    return historyRec;
  }
}