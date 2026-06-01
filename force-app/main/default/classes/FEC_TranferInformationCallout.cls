public without sharing class FEC_TranferInformationCallout {
  public static FEC_ResponseLog responseLog;

  // --- Request DTO (Pega body + map từ Case) ---

  public class TransferCallInput {
    @AuraEnabled
    public String genesysId { get; set; }
    @AuraEnabled
    public String requestorId { get; set; }
    @AuraEnabled
    public Map<String, String> callData { get; set; }
  }

  /** Một phần tử trong body.data (fieldKey / fieldValue). */
  public class TransferDataEntry {
    public String fieldKey;
    public String fieldValue;

    public TransferDataEntry(String k, String v) {
      this.fieldKey = k;
      this.fieldValue = v;
    }
  }

  /** Body POST: genesysId, data[], csCaseID (header tách riêng). */
  public class TransferCallRequestBody {
    public String genesysId;
    public List<TransferDataEntry> data;
    public String csCaseID;
  }

  public class CaseCallData {
    /** Genesys ID: Case Interaction = FEC_External_Interaction_ID__c; Customer Case = Interaction cha. */
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
    ensureCaseNocForTransfer(caseId);
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
        FEC_Remark_for_Collections__c,
        FEC_Case_ID__c,
        FEC_ID_Search__c,
        FEC_Current_Case_Stage__r.FEC_Nature_of_Cases__r.FEC_Product_Type__r.Name,
        FEC_Current_Case_Stage__r.FEC_Nature_of_Cases__r.FEC_Category__r.Name,
        FEC_Current_Case_Stage__r.FEC_Nature_of_Cases__r.FEC_Sub_Category__r.Name,
        FEC_Current_Case_Stage__r.FEC_Nature_of_Cases__r.FEC_Sub_Code__r.Name,
        FEC_Actual_Nature_of_Case__r.FEC_Product_Type__r.Name,
        FEC_Actual_Nature_of_Case__r.FEC_Category__r.Name,
        FEC_Actual_Nature_of_Case__r.FEC_Sub_Category__r.Name,
        FEC_Actual_Nature_of_Case__r.FEC_Sub_Code__r.Name
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
    // Phone: Case → Interaction cha → FEC_Case_Phone_Number__c
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
    applyNocLabelFallbacks(c, data);
    data.remark = c.FEC_Remark_for_Collections__c;
    data.csCaseID = c.FEC_ID_Search__c; // mã Case (S-xxxx), không dùng hyperlink formula
    return data;
  }

  /**
   * Transfer Call đọc Category/Sub-Category/Sub-Code từ Case, nhưng UI chọn NOC chỉ set
   * FEC_Current_Case_Stage__c (getByCase) — chưa ghi lookup NOC lên Case trước submit.
   * Đồng bộ từ Actual NOC hoặc Nature of Case trên Case Stage trước khi build payload Pega.
   */
  @TestVisible
  private static void ensureCaseNocForTransfer(Id caseId) {
    if (caseId == null) {
      return;
    }
    List<Case> rows = [
      SELECT
        Id,
        FEC_Is_Submited__c,
        FEC_Product_Type__c,
        FEC_Category__c,
        FEC_SubCategory__c,
        FEC_SubCode__c,
        FEC_Actual_Nature_of_Case__c,
        FEC_Current_Case_Stage__r.FEC_Nature_of_Cases__c
      FROM Case
      WHERE Id = :caseId
      WITH SECURITY_ENFORCED
      LIMIT 1
    ];
    if (rows.isEmpty() || rows[0].FEC_Is_Submited__c == true) {
      return;
    }
    Case c = rows[0];
    if (!caseNeedsNocSync(c)) {
      return;
    }

    Id actualNatureId = c.FEC_Actual_Nature_of_Case__c;
    Id templateNatureId = c.FEC_Current_Case_Stage__r?.FEC_Nature_of_Cases__c;
    Case patch = new Case(Id = caseId);
    Boolean patched = false;

    if (actualNatureId != null) {
      List<FEC_Actual_Nature_of_Case__c> actuals = [
        SELECT
          FEC_Product_Type__c,
          FEC_Category__c,
          FEC_Sub_Category__c,
          FEC_Sub_Code__c
        FROM FEC_Actual_Nature_of_Case__c
        WHERE Id = :actualNatureId
        WITH SECURITY_ENFORCED
        LIMIT 1
      ];
      if (!actuals.isEmpty()) {
        applyNocIdsToCasePatch(
          patch,
          actuals[0].FEC_Product_Type__c,
          actuals[0].FEC_Category__c,
          actuals[0].FEC_Sub_Category__c,
          actuals[0].FEC_Sub_Code__c
        );
        patched = true;
      }
    }

    if (!patched && templateNatureId != null) {
      List<FEC_Nature_of_Case__c> templates = [
        SELECT
          FEC_Product_Type__c,
          FEC_Category__c,
          FEC_Sub_Category__c,
          FEC_Sub_Code__c
        FROM FEC_Nature_of_Case__c
        WHERE Id = :templateNatureId
        WITH SECURITY_ENFORCED
        LIMIT 1
      ];
      if (!templates.isEmpty()) {
        applyNocIdsToCasePatch(
          patch,
          templates[0].FEC_Product_Type__c,
          templates[0].FEC_Category__c,
          templates[0].FEC_Sub_Category__c,
          templates[0].FEC_Sub_Code__c
        );
        patched = true;
      }
    }

    if (!patched || !Schema.sObjectType.Case.isUpdateable()) {
      return;
    }
    try {
      FEC_CaseTriggerHandler.isSystemUpdate = true;
      update patch;
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.WARN,
        '[TransferCall] ensureCaseNocForTransfer: ' + ex.getMessage()
      );
    }
  }

  @TestVisible
  private static Boolean caseNeedsNocSync(Case c) {
    return c == null
      || c.FEC_Product_Type__c == null
      || c.FEC_Category__c == null
      || c.FEC_SubCategory__c == null;
  }

  private static void applyNocIdsToCasePatch(
    Case patch,
    Id productTypeId,
    Id categoryId,
    Id subCategoryId,
    Id subCodeId
  ) {
    if (productTypeId != null) {
      patch.FEC_Product_Type__c = productTypeId;
    }
    if (categoryId != null) {
      patch.FEC_Category__c = categoryId;
    }
    if (subCategoryId != null) {
      patch.FEC_SubCategory__c = subCategoryId;
    }
    if (subCodeId != null) {
      patch.FEC_SubCode__c = subCodeId;
    }
  }

  /** Fallback tên NOC khi Case lookup trống nhưng Stage/Actual NOC đã có (vd. update Case thất bại). */
  @TestVisible
  private static void applyNocLabelFallbacks(Case c, CaseCallData data) {
    if (c == null || data == null) {
      return;
    }
    FEC_Nature_of_Case__c stageNoc = c.FEC_Current_Case_Stage__r?.FEC_Nature_of_Cases__r;
    FEC_Actual_Nature_of_Case__c actualNoc = c.FEC_Actual_Nature_of_Case__r;

    data.productType = firstNonBlank(
      data.productType,
      c.FEC_Product_Type__r?.Name,
      stageNoc?.FEC_Product_Type__r?.Name,
      actualNoc?.FEC_Product_Type__r?.Name
    );
    data.category = firstNonBlank(
      data.category,
      c.FEC_Category__r?.Name,
      stageNoc?.FEC_Category__r?.Name,
      actualNoc?.FEC_Category__r?.Name
    );
    data.subCategory = firstNonBlank(
      data.subCategory,
      c.FEC_SubCategory__r?.Name,
      stageNoc?.FEC_Sub_Category__r?.Name,
      actualNoc?.FEC_Sub_Category__r?.Name
    );
    data.subCode = firstNonBlank(
      data.subCode,
      c.FEC_SubCode__r?.Name,
      stageNoc?.FEC_Sub_Code__r?.Name,
      actualNoc?.FEC_Sub_Code__r?.Name
    );
  }

  @TestVisible
  private static String firstNonBlank(
    String primary,
    String secondary,
    String tertiary,
    String quaternary
  ) {
    if (String.isNotBlank(primary)) {
      return primary.trim();
    }
    if (String.isNotBlank(secondary)) {
      return secondary.trim();
    }
    if (String.isNotBlank(tertiary)) {
      return tertiary.trim();
    }
    if (String.isNotBlank(quaternary)) {
      return quaternary.trim();
    }
    return null;
  }

  /** LWC: Case Id + remark; RequestorID = CSM constant. */
  @AuraEnabled
  public static TransferCallResponse transferCallFromCase(Id caseId, String remark) {
    Case historyCase = null;
    TransferCallResponse result = null;
    try {
      if (caseId == null) {
        TransferCallResponse res = new TransferCallResponse();
        res.success = false;
        res.errorMessage = String.format(
          System.Label.FEC_MSG_Param_Required,
          new List<String>{ 'Case ID' }
        );
        res.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
        return res;
      }
      List<Case> submittedCheck = [
        SELECT FEC_Is_Submited__c
        FROM Case
        WHERE Id = :caseId
        WITH SECURITY_ENFORCED
        LIMIT 1
      ];
      if (submittedCheck.isEmpty()) {
        TransferCallResponse res = new TransferCallResponse();
        res.success = false;
        res.errorMessage = String.format(
          System.Label.FEC_MSG_Param_Required,
          new List<String>{ 'Case ID' }
        );
        res.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
        return res;
      }
      if (submittedCheck[0].FEC_Is_Submited__c == true) {
        TransferCallResponse res = new TransferCallResponse();
        res.success = false;
        res.errorMessage = 'Case has been submitted. Transfer Call is readonly.';
        res.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
        return res;
      }
      if (String.isBlank(remark)) {
        TransferCallResponse res = new TransferCallResponse();
        res.success = false;
        res.errorMessage = System.Label.FEC_Transfer_Err_Remark_Null;
        res.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
        return res;
      }
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
      List<Case> historyRows = [
        SELECT Id, FEC_Current_Case_Stage__r.Name
        FROM Case
        WHERE Id = :caseId
        WITH SECURITY_ENFORCED
        LIMIT 1
      ];
      historyCase = historyRows.isEmpty() ? null : historyRows[0];
      result = transferCallByCase(
        caseId,
        data.genesysId,
        FEC_ConstantCommon.TRANSFER_CALL_REQUESTOR_ID_CSM,
        remark
      );
      if (result != null && result.success == true) {
        try {
          String transferTime = Datetime.now().format('dd/MM/yyyy HH:mm:ss', 'Asia/Ho_Chi_Minh');
          Case c = new Case(
            Id = caseId,
            FEC_Transfer_Data_to_Collections__c = 'Yes',
            FEC_Remark_for_Collections__c = remark,
            FEC_Transfer_Time__c = transferTime,
            FEC_Transfer_Status__c = 'Success',
            FEC_Failure_Reason__c = null
          );
          update c;
        } catch (Exception updateEx) {
          System.debug(LoggingLevel.WARN,
            '[TransferCall] Could not update Case fields (success): ' + updateEx.getMessage());
        }
      } else if (result != null && result.success == false) {
        localizeTransferCallFailure(result);
        try {
          String failReason = String.isNotBlank(result.errorMessage)
            ? result.errorMessage
            : (String.isNotBlank(result.Reason) ? result.Reason : result.ResultOfClass);
          Case c = new Case(
            Id = caseId,
            FEC_Transfer_Data_to_Collections__c = 'No',
            FEC_Remark_for_Collections__c = remark,
            FEC_Transfer_Status__c = 'Failure',
            FEC_Failure_Reason__c = failReason
          );
          update c;
        } catch (Exception updateEx) {
          System.debug(LoggingLevel.WARN,
            '[TransferCall] Could not update Case fields (failure): ' + updateEx.getMessage());
        }
      }
      return result;
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, e.getMessage() + '\n' + e.getStackTraceString());
      TransferCallResponse err = new TransferCallResponse();
      err.success = false;
      err.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
      err.errorMessage = formatExceptionDetail(e);
      err.ResultOfClass = err.errorMessage;
      localizeTransferCallFailure(err);
      result = err;
      return err;
    } finally {
      logTransferCallProcessActionHistory(historyCase, result);
    }
  }

  private static void logTransferCallProcessActionHistory(
    Case c,
    TransferCallResponse apiResult
  ) {
    if (c == null || apiResult == null) {
      return;
    }
    FEC_CommonUltils.createProcessActionHistory(
      FEC_ConstantCommon.API_CONFIG_NAME,
      c,
      apiResult.success == true
    );
  }

  /**
   * LWC: mở popup Transfer — xóa remark cũ trên Case để lần transfer sau ghi đè bằng giá trị mới.
   */
  @AuraEnabled
  public static void prepareRemarkForCollectionsTransfer(Id caseId) {
    if (caseId == null) {
      return;
    }
    List<Case> rows = [
      SELECT FEC_Is_Submited__c
      FROM Case
      WHERE Id = :caseId
      WITH SECURITY_ENFORCED
      LIMIT 1
    ];
    if (rows.isEmpty() || rows[0].FEC_Is_Submited__c == true) {
      return;
    }
    ensureCaseNocForTransfer(caseId);
    try {
      update new Case(Id = caseId, FEC_Remark_for_Collections__c = null);
    } catch (Exception updateEx) {
      System.debug(
        LoggingLevel.WARN,
        '[TransferCall] Could not clear FEC_Remark_for_Collections__c: ' +
        updateEx.getMessage()
      );
      throw new AuraHandledException(updateEx.getMessage());
    }
  }

  @AuraEnabled
  public static TransferCallResponse transferCallByCase(
    Id caseId,
    String genesysId,
    String requestorId,
    String remark
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

      String resolvedProductType = normalizeProductType(data.productType);

      TransferCallInput reqObj = new TransferCallInput();
      reqObj.genesysId = String.isNotBlank(genesysId)
        ? genesysId
        : FEC_ConstantCommon.TRANSFER_CALL_DEFAULT_GENESYS_ID;
      reqObj.requestorId = requestorId;
      reqObj.callData = new Map<String, String>{
        'productType' => String.isNotBlank(resolvedProductType) ? resolvedProductType : FEC_ConstantCommon.TRANSFER_CALL_DEFAULT_PRODUCT_TYPE,
        'extAppId' => String.isNotBlank(data.extAppId) ? data.extAppId : FEC_ConstantCommon.TRANSFER_CALL_DEFAULT_EXT_APP_ID,
        'phoneNumber' => String.isNotBlank(data.phoneNumber) ? data.phoneNumber : FEC_ConstantCommon.TRANSFER_CALL_DEFAULT_PHONE,
        'category' => String.isNotBlank(data.category) ? data.category : FEC_ConstantCommon.TRANSFER_CALL_DEFAULT_CATEGORY,
        'subCategory' => String.isNotBlank(data.subCategory) ? data.subCategory : FEC_ConstantCommon.TRANSFER_CALL_DEFAULT_SUB_CATEGORY,
        'subCode' => String.isNotBlank(data.subCode) ? data.subCode : FEC_ConstantCommon.TRANSFER_CALL_DEFAULT_SUB_CODE,
        'remark' => String.isNotBlank(remark) ? remark : data.remark,
        'csCaseID' => String.isNotBlank(data.csCaseID) ? data.csCaseID : FEC_ConstantCommon.TRANSFER_CALL_DEFAULT_CS_CASE_ID
      };

      return transferCall(reqObj);
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, e.getMessage() + '\n' + e.getStackTraceString());
      TransferCallResponse err = new TransferCallResponse();
      err.success = false;
      err.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
      err.errorMessage = formatExceptionDetail(e);
      err.ResultOfClass = err.errorMessage;
      localizeTransferCallFailure(err);
      return err;
    }
  }

  /**
   * Tra FEC_Transfer_Call_Error__c theo FEC_Error_Message_EN__c (khớp chính xác),
   * trả FEC_Error_Message_VI__c để hiển thị. Không có bản ghi → giữ nguyên EN.
   */
  @TestVisible
  private static String resolveTransferCallErrorMessageVi(String englishMessage) {
    if (String.isBlank(englishMessage)) {
      return englishMessage;
    }
    String vi = queryTransferCallErrorVi(englishMessage.trim());
    return vi != null ? vi : englishMessage.trim();
  }

  private static String queryTransferCallErrorVi(String enLookupKey) {
    if (String.isBlank(enLookupKey)) {
      return null;
    }
    try {
      List<FEC_Transfer_Call_Error__c> rows = [
        SELECT FEC_Error_Message_VI__c
        FROM FEC_Transfer_Call_Error__c
        WHERE FEC_Error_Message_EN__c = :enLookupKey
        LIMIT 1
      ];
      if (
        !rows.isEmpty() &&
        String.isNotBlank(rows[0].FEC_Error_Message_VI__c)
      ) {
        return rows[0].FEC_Error_Message_VI__c.trim();
      }
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.WARN,
        '[TransferCall] FEC_Transfer_Call_Error__c lookup failed: ' +
          ex.getMessage()
      );
    }
    return null;
  }

  @TestVisible
  private static void localizeTransferCallFailure(TransferCallResponse res) {
    if (res == null || res.success == true) {
      return;
    }
    String rawEn = String.isNotBlank(res.errorMessage)
      ? res.errorMessage
      : (String.isNotBlank(res.Reason)
          ? res.Reason
          : res.ResultOfClass);
    if (String.isBlank(rawEn)) {
      return;
    }
    String vi = resolveTransferCallErrorMessageVi(rawEn);
    res.errorMessage = vi;
    if (String.isNotBlank(res.ResultOfClass)) {
      res.ResultOfClass = vi;
    }
    if (String.isNotBlank(res.Reason)) {
      res.Reason = vi;
    }
  }

  private static String formatExceptionDetail(Exception e) {
    // FEC_APIServiceException: chỉ getMessage (không nối type/cause cho user).
    if (e instanceof FEC_APIServiceException) {
      return String.isNotBlank(e.getMessage())
        ? e.getMessage().trim()
        : '[' + e.getTypeName() + ']';
    }
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

  /**
   * Parse chuỗi ngày giờ từ service thành Datetime.
   * Hỗ trợ ISO 8601 (JSON deserialize) và "dd/MM/yyyy HH:mm:ss".
   * Trả về null nếu không parse được.
   */
  @TestVisible
  private static Datetime parseCollActionDatetime(String raw) {
    if (String.isBlank(raw)) {
      return null;
    }
    String trimmed = raw.trim();
    // ISO 8601 (e.g. "2026-04-21T08:13:36.000Z")
    try {
      return (Datetime) JSON.deserialize('"' + trimmed + '"', Datetime.class);
    } catch (Exception ignore) {}
    // dd/MM/yyyy HH:mm:ss
    try {
      if (trimmed.length() >= 19
          && trimmed.substring(2, 3) == '/'
          && trimmed.substring(5, 6) == '/') {
        String isoLike = trimmed.substring(6, 10) + '-'
            + trimmed.substring(3, 5) + '-'
            + trimmed.substring(0, 2) + 'T'
            + trimmed.substring(11, 19);
        return (Datetime) JSON.deserialize('"' + isoLike + '"', Datetime.class);
      }
    } catch (Exception ignore) {}
    return null;
  }

  /** Chuẩn hóa productType cho Pega (uppercase). */
  private static String normalizeProductType(String rawValue) {
    if (String.isBlank(rawValue)) {
      return rawValue;
    }
    return rawValue.trim().toUpperCase();
  }

  // --- Response DTO ---
  public class TransferCallResponse {
    @AuraEnabled
    public String Code;

    @AuraEnabled
    public String SubActionCode;

    @AuraEnabled
    public String ResultOfClass;

    @AuraEnabled
    public String Reason;

    @AuraEnabled
    public String TransID;

    @AuraEnabled
    public String ActionDate;

    @AuraEnabled
    public String Agent;

    @AuraEnabled
    public Integer httpStatus;

    @AuraEnabled
    public String rawResponse;

    @AuraEnabled
    public Boolean success;

    @AuraEnabled
    public String errorMessage;
  }

  // --- Callout ---

  private static String resolveTransferEndpoint() {
    FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
    FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(
      FEC_ConstantCommon.API_CONFIG_NAME
    );
    return apiSetting?.FEC_Call_Mock__c
      ? FEC_MockupEndpoint.UPDATE_CUSTOMER_CONTACT_ENDPOINT_MOCKUP
      : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
  }
  /** Serialize body; TransID / RequestorID / DateTime ở header. */
  public static String buildRequestBodyJson(TransferCallInput reqObj) {
    TransferCallRequestBody reqBody = new TransferCallRequestBody();
    reqBody.genesysId = reqObj.genesysId;
    reqBody.csCaseID = reqObj.callData != null
      ? reqObj.callData.get('csCaseID')
      : null;
    reqBody.data = new List<TransferDataEntry>();

    if (reqObj.callData != null) {
      for (String key : FEC_ConstantCommon.TRANSFER_CALL_DATA_FIELD_ORDER) {
        reqBody.data.add(
          new TransferDataEntry(key, reqObj.callData.get(key))
        );
      }
    }

    return JSON.serialize(reqBody);
  }

  public static HttpResponse sendRequest(
    String endpoint,
    String jsonBody,
    String transId,
    String requestorId,
    String dateTimeHeader
  ) {
    Map<String, String> headers = new Map<String, String>{
      'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
      'Accept' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
      'TransID' => transId,
      'RequestorID' => requestorId,
      'DateTime' => dateTimeHeader
    };

    HttpResponse response = FEC_CommonUltils.calloutApiWithHeaders(
      endpoint,
      FEC_ConstantCommon.API_METHOD_POST,
      headers,
      jsonBody
    );

    if (response != null && response.getStatusCode() >= 400) {
      String b = response.getBody();
      if (String.isBlank(b)) {
        System.debug(
          LoggingLevel.WARN,
          '[TransferCall] HTTP ' +
            response.getStatusCode() +
            ' body=(empty)'
        );
      } else {
        String logBody = FEC_CommonUltils.truncateForLog(
          b,
          FEC_ConstantCommon.TRANSFER_CALL_DEBUG_BODY_MAX_LEN,
          '...[truncated]'
        );
        System.debug(
          LoggingLevel.WARN,
          '[TransferCall] HTTP ' + response.getStatusCode() + ' body=' + logBody
        );
      }
    }
    return response;
  }

  /** Lấy chuỗi lỗi từ body khi schema không khớp TransferCallResponse. */
  private static String extractApiErrorHint(String jsonResponse) {
    if (String.isBlank(jsonResponse)) {
      return null;
    }
    String trimmed = jsonResponse.trim();
    Integer maxRaw = FEC_ConstantCommon.TRANSFER_CALL_API_HINT_RAW_MAX_LEN;
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      return trimmed.length() > maxRaw ? trimmed.substring(0, maxRaw) + '…' : trimmed;
    }
    try {
      Object root = JSON.deserializeUntyped(trimmed);
      if (root instanceof Map<String, Object>) {
        Map<String, Object> m = (Map<String, Object>) root;
        for (String k : FEC_ConstantCommon.TRANSFER_CALL_JSON_ERROR_HINT_KEYS) {
          Object v = m.get(k);
          if (v != null && v instanceof String && String.isNotBlank((String) v)) {
            return ((String) v).trim();
          }
        }
        Object errs = m.get('errors');
        if (errs instanceof List<Object>) {
          List<Object> errList = (List<Object>) errs;
          if (!errList.isEmpty() && errList[0] instanceof Map<String, Object>) {
            Map<String, Object> first = (Map<String, Object>) errList[0];
            Object em = first.get('message');
            if (em instanceof String && String.isNotBlank((String) em)) {
              return ((String) em).trim();
            }
          }
        }
      }
    } catch (Exception ignore) {
    }
    return null;
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
      result.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
      localizeTransferCallFailure(result);
      return result;
    }

    try {
      TransferCallResponse parsed = (TransferCallResponse) JSON.deserialize(
        jsonResponse,
        TransferCallResponse.class
      );
      result.Code = parsed.Code;
      result.SubActionCode = parsed.SubActionCode;
      result.ResultOfClass = parsed.ResultOfClass;
      result.Reason = parsed.Reason;
      result.TransID = parsed.TransID;
      result.ActionDate = parsed.ActionDate;
      result.Agent = parsed.Agent;

      result.success = (result.Code == FEC_ConstantCommon.SUCCESS_CODE_1 ||
      result.Code == FEC_ConstantCommon.SUCCESS_CODE_Y ||
      result.Code == FEC_ConstantCommon.SUCCESS_MESSAGE);
      if (!result.success) {
        if (String.isNotBlank(result.Reason)) {
          result.errorMessage = result.Reason;
          if (String.isBlank(result.ResultOfClass)) {
            result.ResultOfClass = result.Reason;
          }
        } else if (
          String.isBlank(result.errorMessage) &&
          String.isNotBlank(result.ResultOfClass)
        ) {
          result.errorMessage = result.ResultOfClass;
        }
      }
      Boolean httpBad = httpStatus != null && httpStatus >= 400;
      if (
        (!result.success || httpBad) &&
        String.isBlank(result.errorMessage) &&
        String.isBlank(result.ResultOfClass)
      ) {
        String apiErrHint = extractApiErrorHint(jsonResponse);
        if (String.isNotBlank(apiErrHint)) {
          result.errorMessage = apiErrHint;
          result.ResultOfClass = apiErrHint;
        }
      }
    } catch (Exception ex) {
      result.errorMessage = String.format(
        System.Label.FEC_MSG_Parse_XML_Error,
        new List<String>{ ex.getMessage() }
      );
      result.success = false;
      result.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
      result.ResultOfClass = result.errorMessage;
      String apiErrHint = extractApiErrorHint(jsonResponse);
      if (String.isNotBlank(apiErrHint)) {
        result.errorMessage = result.errorMessage + ' | API hint: ' + apiErrHint;
        result.ResultOfClass = result.ResultOfClass + ' | API hint: ' + apiErrHint;
      }
    }
    localizeTransferCallFailure(result);
    return result;
  }

  @AuraEnabled
  public static TransferCallResponse transferCall(TransferCallInput reqObj) {
    validate(reqObj);
    TransferCallResponse finalResult = new TransferCallResponse();
    try {
      String transId = FEC_CommonUltils.generateTransactionUUID();
      Datetime nowDt = Datetime.now();
      String timestamp = FEC_CommonUltils.formatTransferCallRequestDateTime(nowDt);
      String jsonPayload = buildRequestBodyJson(reqObj);
      String endpoint = resolveTransferEndpoint();

      HttpResponse res = sendRequest(
        endpoint,
        jsonPayload,
        transId,
        reqObj.requestorId,
        timestamp
      );
      Integer status = (res == null) ? null : res.getStatusCode();
      String body = (res == null) ? null : res.getBody();

      responseLog = new FEC_ResponseLog(
        'FEC_TranferInformationCallout',
        endpoint,
        FEC_ConstantCommon.API_METHOD_POST,
        jsonPayload,
        res,
        null
      );

      finalResult = parseResponse(body, status);
      localizeTransferCallFailure(finalResult);

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
      finalResult.errorMessage = formatExceptionDetail(ex);
      finalResult.success = false;
      finalResult.Code = FEC_ConstantCommon.SUCCESS_CODE_E;
      finalResult.ResultOfClass = finalResult.errorMessage;
      localizeTransferCallFailure(finalResult);
    }
    return finalResult;
  }

  private static void throwTransferValidationError(String enLookupKey) {
    throw new FEC_APIServiceException(enLookupKey);
  }

  private static void validate(TransferCallInput reqObj) {
    if (String.isBlank(reqObj.genesysId)) {
      throwTransferValidationError(
        FEC_ConstantCommon.TRANSFER_ERR_EN_GENESYS_ID_NULL
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

    Map<String, String> m = reqObj.callData;

    if (String.isBlank(m.get('phoneNumber'))) {
      throwTransferValidationError(
        FEC_ConstantCommon.TRANSFER_ERR_EN_PHONE_NUMBER_NULL
      );
    }
    if (!isTransferPhoneFormatValid(m.get('phoneNumber'))) {
      throwTransferValidationError(
        FEC_ConstantCommon.TRANSFER_ERR_EN_PHONE_NUMBER_INVALID
      );
    }

    if (String.isBlank(m.get('csCaseID'))) {
      throwTransferValidationError(
        FEC_ConstantCommon.TRANSFER_ERR_EN_CS_CASE_ID_NULL
      );
    }
    if (String.isBlank(m.get('extAppId'))) {
      throwTransferValidationError(
        FEC_ConstantCommon.TRANSFER_ERR_EN_EXT_APP_ID_NULL
      );
    }

    String productTypeRaw = m.get('productType');
    if (String.isBlank(productTypeRaw)) {
      throwTransferValidationError(
        FEC_ConstantCommon.TRANSFER_ERR_EN_PRODUCT_TYPE_NULL
      );
    }
    String productTypeNorm = normalizeProductType(productTypeRaw);
    if (!isTransferProductTypeValid(productTypeNorm)) {
      throwTransferValidationError(
        FEC_ConstantCommon.TRANSFER_ERR_EN_PRODUCT_TYPE_INVALID
      );
    }

    if (String.isBlank(m.get('category'))) {
      throwTransferValidationError(
        FEC_ConstantCommon.TRANSFER_ERR_EN_CATEGORY_NULL
      );
    }
    if (String.isBlank(m.get('subCategory'))) {
      throwTransferValidationError(
        FEC_ConstantCommon.TRANSFER_ERR_EN_SUB_CATEGORY_NULL
      );
    }
    if (String.isBlank(m.get('subCode'))) {
      throwTransferValidationError(
        FEC_ConstantCommon.TRANSFER_ERR_EN_SUB_CODE_NULL
      );
    }
    if (String.isBlank(m.get('remark'))) {
      throwTransferValidationError(
        FEC_ConstantCommon.TRANSFER_ERR_EN_REMARK_NULL
      );
    }
  }

  private static Boolean isTransferPhoneFormatValid(String rawPhone) {
    if (String.isBlank(rawPhone)) {
      return false;
    }
    String normalized = FEC_CommonUltils.normalizePhone(rawPhone);
    return FEC_CommonUltils.isPhone(normalized);
  }

  private static Boolean isTransferProductTypeValid(String normalizedProductType) {
    if (String.isBlank(normalizedProductType)) {
      return false;
    }
    Set<String> allowedCodes = new Set<String>{
      FEC_ConstantCommon.PRODUCT_TYPE_CARD,
      FEC_ConstantCommon.PRODUCT_TYPE_LOAN,
      FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE,
      FEC_ConstantCommon.PRODUCT_TYPE_UBANK.toUpperCase(),
      FEC_ConstantCommon.PRODUCT_NON_EXISTING_CUSTOMER.toUpperCase()
    };
    if (allowedCodes.contains(normalizedProductType)) {
      return true;
    }
    return Pattern.matches(
      FEC_ConstantCommon.TRANSFER_CALL_PRODUCT_TYPE_NAME_PATTERN,
      normalizedProductType
    );
  }
}