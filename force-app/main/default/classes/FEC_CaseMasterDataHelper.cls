/**
 * Tiện ích xử lý danh sách Master Data Case (lọc Assignment ẩn, GSR revert stage).
 */
public without sharing class FEC_CaseMasterDataHelper {
  private static final String TYPE_ASSIGNMENT = 'Assignment';

  private FEC_CaseMasterDataHelper() {
  }

  /**
   * Assignment + FEC_Hidden__c: loại khỏi masterDatalst mọi dòng có cùng FEC_Field_API_Name__c
   * (kể cả type Field/LWC khác Assignment).
   */
  @TestVisible
  public static List<SObject> removeMasterDataRowsByHiddenAssignmentFieldApis(
    List<SObject> masterDatalst,
    Boolean hasCaseAssignment
  ) {
    if (
      masterDatalst == null ||
      masterDatalst.isEmpty() ||
      hasCaseAssignment != true
    ) {
      return masterDatalst;
    }
    Set<String> hiddenAssignmentFieldApis = new Set<String>();
    for (SObject mdsRow : masterDatalst) {
      if (
        TYPE_ASSIGNMENT.equals((String) mdsRow.get('FEC_Type__c')) &&
        (Boolean) mdsRow.get('FEC_Hidden__c') == true
      ) {
        String api = (String) mdsRow.get('FEC_Field_API_Name__c');
        if (String.isNotBlank(api)) {
          hiddenAssignmentFieldApis.add(api);
        }
      }
    }
    if (hiddenAssignmentFieldApis.isEmpty()) {
      return masterDatalst;
    }
    List<SObject> filtered = new List<SObject>();
    for (SObject mdsRow : masterDatalst) {
      String api = (String) mdsRow.get('FEC_Field_API_Name__c');
      if (String.isNotBlank(api) && hiddenAssignmentFieldApis.contains(api)) {
        continue;
      }
      filtered.add(mdsRow);
    }
    return filtered;
  }

  /** GSR revert về currentStage: stage trước revert (FEC_Previous_Stage) khớp previousStageNameToken (vd Stage 2). */
  public static Boolean isGsrRevertFromPreviousStageName(
    Id caseId,
    Id currentStageId,
    String previousStageNameToken,
    String currentStageName
  ) {
    if (
      caseId == null ||
      currentStageId == null ||
      String.isBlank(previousStageNameToken)
    ) {
      return false;
    }
    List<FEC_Routing_Action_History__c> latestRevertHist = [
      SELECT FEC_Previous_Stage__r.Name
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Next_Stage__c = :currentStageId
        AND FEC_Next_Stage__c != NULL
        AND FEC_IsReverted__c = true
      ORDER BY LastModifiedDate DESC
      LIMIT 1
    ];
    if (!latestRevertHist.isEmpty()) {
      return stageNameContains(
        latestRevertHist[0].FEC_Previous_Stage__r?.Name,
        previousStageNameToken
      );
    }
    Integer currentStageNum = extractStageNumberFromStageName(currentStageName);
    if (currentStageNum == null) {
      return false;
    }
    List<FEC_Routing_Action_History__c> latestRevertByCase = [
      SELECT FEC_Next_Stage__r.Name, FEC_Previous_Stage__r.Name
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_IsReverted__c = true
        AND FEC_Next_Stage__c != NULL
      ORDER BY LastModifiedDate DESC
      LIMIT 1
    ];
    if (latestRevertByCase.isEmpty()) {
      return false;
    }
    Integer revertNextStageNum = extractStageNumberFromStageName(
      latestRevertByCase[0].FEC_Next_Stage__r?.Name
    );
    if (revertNextStageNum == null || revertNextStageNum != currentStageNum) {
      return false;
    }
    return stageNameContains(
      latestRevertByCase[0].FEC_Previous_Stage__r?.Name,
      previousStageNameToken
    );
  }

  @TestVisible
  private static Integer extractStageNumberFromStageName(String stageName) {
    if (String.isBlank(stageName)) {
      return null;
    }
    Matcher m = FEC_ConstantCommon.PAT_STAGE_NAME_WITH_NUMBER.matcher(stageName);
    if (m.find()) {
      return Integer.valueOf(m.group(1));
    }
    return null;
  }

  private static Boolean stageNameContains(
    String selectedStageName,
    String stageNameToken
  ) {
    return selectedStageName?.contains(stageNameToken);
  }
}
