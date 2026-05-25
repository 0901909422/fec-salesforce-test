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
    Set<String> hiddenFieldApis = new Set<String>();
    for (SObject mdsRow : masterDatalst) {
      if (
        TYPE_ASSIGNMENT.equals((String) mdsRow.get('FEC_Type__c')) &&
        mdsRow.get('FEC_Hidden__c') == true
      ) {
        String fieldApi = (String) mdsRow.get('FEC_Field_API_Name__c');
        if (String.isNotBlank(fieldApi)) {
          hiddenFieldApis.add(fieldApi);
        }
      }
    }
    if (hiddenFieldApis.isEmpty()) {
      return masterDatalst;
    }
    List<SObject> filtered = new List<SObject>();
    for (SObject mdsRow : masterDatalst) {
      String fieldApi = (String) mdsRow.get('FEC_Field_API_Name__c');
      if (String.isNotBlank(fieldApi) && hiddenFieldApis.contains(fieldApi)) {
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
    String previousStageNameToken
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
    if (latestRevertHist.isEmpty()) {
      return false;
    }
    return stageNameContains(
      latestRevertHist[0].FEC_Previous_Stage__r?.Name,
      previousStageNameToken
    );
  }

  private static Boolean stageNameContains(
    String selectedStageName,
    String stageNameToken
  ) {
    return selectedStageName?.contains(stageNameToken);
  }
}
