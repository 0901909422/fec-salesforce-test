/**
 * Chuẩn bị dữ liệu trước Route to COF/GSR: clone Actual Nature of Case + Actual Master Data,
 * và ghi FEC_Case_Flow_History__c khi submit creation stage (logic tách từ FEC_CaseBusinessService.run ROUTE_TO_COF_GSR).
 */
public without sharing class FEC_CofGsrRoutePrepareService {
  private FEC_CofGsrRoutePrepareService() {
  }

  /**
   * @param caseId Case đang xử lý
   * @param params Map params của run() — có thể bị cập nhật key natureOfCaseId sau khi clone Actual NOC
   */
  public static void prepareActualNatureCloneAndCreationHistory(
    String caseId,
    Map<String, String> params,
    String currentMethod
  ) {
    String originalNatureOfCaseId = (String) params.get('natureOfCaseId');
    String fieldListJson = (String) params.get('fieldListJson');
    // Với ROUTE_TO, clone sẽ được xử lý trong FEC_CaseBusinessService.route().
    // Tránh clone lặp 2 lần khi prepare chạy trước switch.
    if (currentMethod != FEC_CaseBusinessService.ROUTE_TO) {
      cloneActualNatureAndMasterData(caseId, params);
    }
    createCaseFlowHistoryIfCreationStage(
      caseId,
      originalNatureOfCaseId,
      fieldListJson
    );
  }

  /**
   * Clone Actual Nature of Case + Actual Master Data Setting cho COF/GSR nếu Case chưa có Actual NOC.
   * Có thể cập nhật lại params.natureOfCaseId sang Id bản actual vừa clone.
   */
  public static void cloneActualNatureAndMasterData(
    String caseId,
    Map<String, String> params
  ) {
    String natureOfCaseIdCof = (String) params.get('natureOfCaseId');
    if (String.isNotBlank(natureOfCaseIdCof)) {
      List<Case> caseRows = [
        SELECT Id, FEC_Actual_Nature_of_Case__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
      ];
      // if (!caseRows.isEmpty() && caseRows[0].FEC_Actual_Nature_of_Case__c == null) {
        Id nocId;
        try {
          nocId = (Id) natureOfCaseIdCof;
        } catch (Exception e) {
          nocId = null;
        }
        if (nocId != null && nocId.getSObjectType() == FEC_Nature_of_Case__c.SObjectType) {
          FEC_Actual_Nature_of_Case__c tgt = FEC_CaseBusinessService.cloneActualNatureOfCase(
            natureOfCaseIdCof
          );
          FEC_CaseBusinessService.cloneMasterDataSetting(tgt.Id, natureOfCaseIdCof);
          update new Case(
            Id = caseId,
            FEC_Actual_Nature_of_Case__c = tgt.Id,
            FEC_Product_Type__c = tgt.FEC_Product_Type__c,
            FEC_Category__c = tgt.FEC_Category__c,
            FEC_SubCategory__c = tgt.FEC_Sub_Category__c,
            FEC_SubCode__c = tgt.FEC_Sub_Code__c
          );
          params.put('natureOfCaseId', String.valueOf(tgt.Id));
        }
      // }
    }
  }

  /**
   * Tạo FEC_Case_Flow_History__c khi Case đang ở creation stage.
   */
  public static void createCaseFlowHistoryIfCreationStage(
    String caseId,
    String natureOfCaseId,
    String fieldListJson
  ) {
    Boolean isCreationStageCof =
      !([SELECT FEC_Is_Submited__c FROM Case WHERE Id = :caseId LIMIT 1].FEC_Is_Submited__c == true);
    if (isCreationStageCof) {
      FEC_CaseBusinessService.createCaseFlowHistory(
        caseId,
        natureOfCaseId,
        fieldListJson
      );
      updateCaseOriginalNocFromFlowHistory(caseId);
    }
  }

  //PhongBT 15/05/26
  /**
   * Snapshot Category / Sub Category / Sub Code gốc lên Case từ NOC trên FEC_Case_Flow_History__c vừa tạo.
   */
  private static void updateCaseOriginalNocFromFlowHistory(String caseId) {
    if (String.isBlank(caseId)) {
      return;
    }
    try {
      List<FEC_Case_Flow_History__c> flowHistories = [
        SELECT
          FEC_Nature_of_Cases__r.FEC_Category__c,
          FEC_Nature_of_Cases__r.FEC_Sub_Category__c,
          FEC_Nature_of_Cases__r.FEC_Sub_Code__c
        FROM FEC_Case_Flow_History__c
        WHERE FEC_Case__c = :caseId AND FEC_Nature_of_Cases__c != NULL
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];
      if (flowHistories.isEmpty() || flowHistories[0].FEC_Nature_of_Cases__r == null) {
        return;
      }
      FEC_Nature_of_Case__c baselineNoc = flowHistories[0].FEC_Nature_of_Cases__r;
      update new Case(
        Id = caseId,
        FEC_Original_Category__c = baselineNoc.FEC_Category__c,
        FEC_Original_Sub_Category__c = baselineNoc.FEC_Sub_Category__c,
        FEC_Original_Sub_Code__c = baselineNoc.FEC_Sub_Code__c
      );
    } catch (Exception e) {
      System.debug(
        'updateCaseOriginalNocFromFlowHistory error: ' + e.getMessage()
      );
    }
  }
  //PhongBT: update bộ noc chọn ở updated khi revert về
  /**
   * Cập nhật bộ NOC (Product Type, Category, Sub Category, Sub Code) trên Case
   * theo Nature of Case Id được chọn ở Updated NOC trên UI.
   * Template NOC → gán FEC_Actual_Nature_of_Case__c (tìm Actual cũ hoặc clone + MD).
   * Actual NOC → gán trực tiếp lên Case.
   */
  public static void updateCaseNocFromSelection(String caseId, String natureOfCaseId) {
    if (String.isBlank(caseId) || String.isBlank(natureOfCaseId)) {
      return;
    }

    Id nocId;
    try {
      nocId = (Id) natureOfCaseId;
    } catch (Exception e) {
      return;
    }

    if (nocId.getSObjectType() == FEC_Actual_Nature_of_Case__c.SObjectType) {
      List<FEC_Actual_Nature_of_Case__c> actualLst = [
        SELECT
          Id,
          FEC_Product_Type__c,
          FEC_Category__c,
          FEC_Sub_Category__c,
          FEC_Sub_Code__c
        FROM FEC_Actual_Nature_of_Case__c
        WHERE Id = :nocId
        LIMIT 1
      ];
      if (!actualLst.isEmpty()) {
        applyActualNatureToCase(caseId, actualLst[0]);
      }
      return;
    }

    if (nocId.getSObjectType() == FEC_Nature_of_Case__c.SObjectType) {
      syncCaseToActualNatureFromTemplate(caseId, nocId);
    }
  }

  /**
   * GSR Revert Stage 2 → Stage 1: khôi phục Actual NOC + Case Stage theo bộ NOC gốc
   * trên FEC_Case_Flow_History__c (submit lần đầu), không theo Updated NOC Stage 2.
   */
  public static void restoreGsrStage1BaselineAfterStage2Revert(String caseId) {
    if (String.isBlank(caseId)) {
      return;
    }
    Id baselineTemplateId = resolveBaselineTemplateNatureIdFromFlowHistory(caseId);
    if (baselineTemplateId == null) {
      return;
    }
    List<FEC_Nature_of_Case__c> templateLst = [
      SELECT
        Id,
        FEC_Product_Type__c,
        FEC_Category__c,
        FEC_Sub_Category__c,
        FEC_Sub_Code__c,
        FEC_Business_Process__r.FEC_Code__c
      FROM FEC_Nature_of_Case__c
      WHERE Id = :baselineTemplateId
      LIMIT 1
    ];
    if (templateLst.isEmpty()) {
      return;
    }
    FEC_Nature_of_Case__c templateNoc = templateLst[0];
    String bpCode = templateNoc.FEC_Business_Process__r?.FEC_Code__c;
    if (String.isBlank(bpCode) || !bpCode.toUpperCase().contains('GSR')) {
      return;
    }
    Id stage1Id = resolveCaseStageIdForTemplateByStageFragment(
      baselineTemplateId,
      FEC_ConstantCommon.STAGE_ONE
    );
    FEC_Actual_Nature_of_Case__c actualNoc = resolveOrCreateActualNatureForTemplate(
      templateNoc
    );
    applyActualNatureAndStageToCase(caseId, actualNoc, stage1Id);
  }

  @TestVisible
  private static Id resolveBaselineTemplateNatureIdFromFlowHistory(String caseId) {
    List<FEC_Case_Flow_History__c> flowHistories = [
      SELECT FEC_Nature_of_Cases__c
      FROM FEC_Case_Flow_History__c
      WHERE FEC_Case__c = :caseId AND FEC_Nature_of_Cases__c != NULL
      ORDER BY CreatedDate ASC
      LIMIT 1
    ];
    return flowHistories.isEmpty() ? null : flowHistories[0].FEC_Nature_of_Cases__c;
  }

  @TestVisible
  private static Id resolveCaseStageIdForTemplateByStageFragment(
    Id templateNatureId,
    String stageNameFragment
  ) {
    if (templateNatureId == null || String.isBlank(stageNameFragment)) {
      return null;
    }
    String stageNamePattern = '%' + stageNameFragment + '%';
    List<FEC_Case_Stage__c> stageLst = [
      SELECT Id
      FROM FEC_Case_Stage__c
      WHERE
        FEC_Nature_of_Cases__c = :templateNatureId
        AND FEC_Active__c = TRUE
        AND Name LIKE :stageNamePattern
      ORDER BY Name
      LIMIT 1
    ];
    return stageLst.isEmpty() ? null : stageLst[0].Id;
  }

  /**
   * Sau Revert: Actual NOC trên Case phải khớp template của FEC_Current_Case_Stage__c
   * (tránh Actual bộ Stage 2 + Stage Stage 1 NOC gốc → master data COUNT = 0).
   */
  public static void syncActualNatureToMatchCurrentCaseStage(String caseId) {
    if (String.isBlank(caseId)) {
      return;
    }
    List<Case> caseRows = [
      SELECT FEC_Current_Case_Stage__c, FEC_Current_Case_Stage__r.FEC_Nature_of_Cases__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (
      caseRows.isEmpty() ||
      caseRows[0].FEC_Current_Case_Stage__c == null ||
      caseRows[0].FEC_Current_Case_Stage__r?.FEC_Nature_of_Cases__c == null
    ) {
      return;
    }
    syncCaseToActualNatureFromTemplate(
      caseId,
      caseRows[0].FEC_Current_Case_Stage__r.FEC_Nature_of_Cases__c
    );
  }

  @TestVisible
  private static void syncCaseToActualNatureFromTemplate(
    String caseId,
    Id templateNatureId
  ) {
    if (String.isBlank(caseId) || templateNatureId == null) {
      return;
    }

    List<FEC_Nature_of_Case__c> templateLst = [
      SELECT
        Id,
        FEC_Product_Type__c,
        FEC_Category__c,
        FEC_Sub_Category__c,
        FEC_Sub_Code__c
      FROM FEC_Nature_of_Case__c
      WHERE Id = :templateNatureId
      LIMIT 1
    ];
    if (templateLst.isEmpty()) {
      return;
    }
    FEC_Nature_of_Case__c templateNoc = templateLst[0];

    FEC_Actual_Nature_of_Case__c actualNoc = resolveOrCreateActualNatureForTemplate(
      templateNoc
    );
    applyActualNatureToCase(caseId, actualNoc);
  }

  /**
   * Ưu tiên Actual đã tạo sớm nhất (thường là bản Stage 1); nếu chưa có MD thì clone từ template.
   */
  @TestVisible
  private static FEC_Actual_Nature_of_Case__c resolveOrCreateActualNatureForTemplate(
    FEC_Nature_of_Case__c templateNoc
  ) {
    List<FEC_Actual_Nature_of_Case__c> existingActualLst = [
      SELECT
        Id,
        FEC_Product_Type__c,
        FEC_Category__c,
        FEC_Sub_Category__c,
        FEC_Sub_Code__c
      FROM FEC_Actual_Nature_of_Case__c
      WHERE
        FEC_Product_Type__c = :templateNoc.FEC_Product_Type__c
        AND FEC_Category__c = :templateNoc.FEC_Category__c
        AND FEC_Sub_Category__c = :templateNoc.FEC_Sub_Category__c
        AND FEC_Sub_Code__c = :templateNoc.FEC_Sub_Code__c
      ORDER BY CreatedDate ASC
      LIMIT 1
    ];

    FEC_Actual_Nature_of_Case__c actualNoc;
    if (!existingActualLst.isEmpty()) {
      actualNoc = existingActualLst[0];
      Integer mdCount = [
        SELECT COUNT()
        FROM FEC_Actual_Master_Data_Setting__c
        WHERE FEC_Actual_Nature_of_Case__c = :actualNoc.Id
      ];
      if (mdCount == 0) {
        FEC_CaseBusinessService.cloneMasterDataSetting(
          actualNoc.Id,
          templateNoc.Id
        );
      }
      return actualNoc;
    }

    actualNoc = FEC_CaseBusinessService.cloneActualNatureOfCase(templateNoc.Id);
    FEC_CaseBusinessService.cloneMasterDataSetting(actualNoc.Id, templateNoc.Id);
    return actualNoc;
  }

  private static void applyActualNatureToCase(
    String caseId,
    FEC_Actual_Nature_of_Case__c actualNoc
  ) {
    applyActualNatureAndStageToCase(caseId, actualNoc, null);
  }

  private static void applyActualNatureAndStageToCase(
    String caseId,
    FEC_Actual_Nature_of_Case__c actualNoc,
    Id caseStageId
  ) {
    Case c = new Case(
      Id = caseId,
      FEC_Actual_Nature_of_Case__c = actualNoc.Id,
      FEC_Product_Type__c = actualNoc.FEC_Product_Type__c,
      FEC_Category__c = actualNoc.FEC_Category__c,
      FEC_SubCategory__c = actualNoc.FEC_Sub_Category__c,
      FEC_SubCode__c = actualNoc.FEC_Sub_Code__c
    );
    if (caseStageId != null) {
      c.FEC_Current_Case_Stage__c = caseStageId;
    }
    update c;
  }
}
