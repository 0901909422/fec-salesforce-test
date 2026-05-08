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
    Map<String, String> params
  ) {
    String originalNatureOfCaseId = (String) params.get('natureOfCaseId');
    String fieldListJson = (String) params.get('fieldListJson');
    cloneActualNatureAndMasterData(caseId, params);
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
    }
  }
}
