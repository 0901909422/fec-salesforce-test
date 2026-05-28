/**
 * Tiện ích xử lý danh sách Master Data Case (lọc Assignment ẩn, GSR revert stage).
 */
public without sharing class FEC_CaseMasterDataHelper {
  private static final String TYPE_ASSIGNMENT = 'Assignment';
  private static final String ROUTING_ACTION_RECALL = 'Recall';

  private FEC_CaseMasterDataHelper() {
  }

  /**
   * Mỗi FEC_Field_API_Name__c chỉ giữ một dòng; trùng API thì bỏ Assignment, giữ Field/LWC/...
   * Giữ thứ tự xuất hiện đầu tiên của API trong masterDatalst.
   */
  public static List<SObject> deduplicateMasterDataRowsByFieldApiName(
    List<SObject> masterDatalst
  ) {
    if (masterDatalst == null || masterDatalst.isEmpty()) {
      return masterDatalst;
    }

    Map<String, SObject> winnerByApi = new Map<String, SObject>();
    for (SObject mdsRow : masterDatalst) {
      String api = (String) mdsRow.get('FEC_Field_API_Name__c');
      if (String.isBlank(api)) {
        continue;
      }
      if (!winnerByApi.containsKey(api)) {
        winnerByApi.put(api, mdsRow);
        continue;
      }
      SObject currentWinner = winnerByApi.get(api);
      if (isAssignmentRow(currentWinner) && !isAssignmentRow(mdsRow)) {
        winnerByApi.put(api, mdsRow);
      }
    }

    List<SObject> deduped = new List<SObject>();
    Set<String> emittedApis = new Set<String>();
    for (SObject mdsRow : masterDatalst) {
      String api = (String) mdsRow.get('FEC_Field_API_Name__c');
      if (String.isBlank(api)) {
        deduped.add(mdsRow);
        continue;
      }
      if (emittedApis.contains(api)) {
        continue;
      }
      emittedApis.add(api);
      deduped.add(winnerByApi.get(api));
    }
    return deduped;
  }

  private static Boolean isAssignmentRow(SObject mdsRow) {
    return TYPE_ASSIGNMENT.equals((String) mdsRow.get('FEC_Type__c'));
  }

  /**
   * Assignment + FEC_Hidden__c: loại khỏi masterDatalst mọi dòng có cùng FEC_Field_API_Name__c
   * (kể cả type Field/LWC khác Assignment) — chỉ với user thuộc FEC_Editable_User_Group__c
   * trên dòng Assignment đó (cùng quy tắc contains như isLwcDynamicMasterInEditMode).
   */
  @TestVisible
  public static List<SObject> removeMasterDataRowsByHiddenAssignmentFieldApis(
    List<SObject> masterDatalst,
    Boolean hasCaseAssignment,
    String currentUserGroup
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
        (Boolean) mdsRow.get('FEC_Hidden__c') == true &&
        isUserInEditableGroup(
          (String) mdsRow.get('FEC_Editable_User_Group__c'),
          currentUserGroup
        )
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

  /** Map FEC_Field_API_Name__c → FEC_Editable_User_Group__c từ các dòng TYPE Assignment. */
  public static Map<String, String> collectAssignmentFieldEditableGroups(
    List<SObject> masterDatalst
  ) {
    Map<String, String> result = new Map<String, String>();
    if (masterDatalst == null) {
      return result;
    }
    for (SObject mdsRow : masterDatalst) {
      if (!TYPE_ASSIGNMENT.equals((String) mdsRow.get('FEC_Type__c'))) {
        continue;
      }
      String api = (String) mdsRow.get('FEC_Field_API_Name__c');
      if (String.isNotBlank(api)) {
        result.put(api, (String) mdsRow.get('FEC_Editable_User_Group__c'));
      }
    }
    return result;
  }

  /** Assignment field chỉ editable khi FEC_Field_Editable__c và user thuộc FEC_Editable_User_Group__c. */
  public static Boolean isAssignmentFieldEditable(
    Boolean fieldEditableFlag,
    String editableUserGroup,
    String currentUserGroup
  ) {
    return fieldEditableFlag == true &&
      isUserInEditableGroup(editableUserGroup, currentUserGroup);
  }

  public static Boolean isUserInEditableGroup(
    String editableUserGroup,
    String currentUserGroup
  ) {
    return String.isNotBlank(editableUserGroup) &&
      String.isNotBlank(currentUserGroup) &&
      editableUserGroup.contains(currentUserGroup);
  }

  /** History mới nhất trên Case có FEC_Routing_Action__c = Recall. */
  public static Boolean isLatestRoutingActionRecall(Id caseId) {
    if (caseId == null) {
      return false;
    }
    List<FEC_Routing_Action_History__c> latestHist = [
      SELECT FEC_Routing_Action__c
      FROM FEC_Routing_Action_History__c
      WHERE FEC_Case__c = :caseId
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 1
    ];
    return (
      !latestHist.isEmpty() &&
      ROUTING_ACTION_RECALL.equals(latestHist[0].FEC_Routing_Action__c)
    );
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
