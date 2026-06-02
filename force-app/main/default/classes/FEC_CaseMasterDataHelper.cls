/**
 * Tiện ích xử lý danh sách Master Data Case (lọc Assignment ẩn, GSR revert stage).
 */
public without sharing class FEC_CaseMasterDataHelper {
  private static final String TYPE_ASSIGNMENT = 'Assignment';
  private static final String ROUTING_ACTION_RECALL = 'Recall';
  @TestVisible
  private static final String API_CONFIRM_D2C_ASSESSMENT = 'FEC_Confirm_D2C_Assessment__c';
  @TestVisible
  private static final String API_CONFIRM_CS_SP_ASSESSMENT = 'FEC_Confirm_CS_SP_Assessment__c';

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
   * Lọc master data trước khi build UI Case Business (gọi từ FEC_CaseBusinessService.getByCase).
   * Field / LWC: giữ nguyên toàn bộ.
   * Assignment: áp dụng shouldExcludeHiddenAssignmentRowForUserGroup và
   * shouldExcludeVisibleAssignmentRowWhenHiddenApplies — chỉ giữ dòng Assignment phù hợp user group + hidden.
   */
  public static List<SObject> filterAssignmentRowsByCurrentUserGroup(
    List<SObject> masterDatalst,
    String currentUserGroup
  ) {
    if (masterDatalst == null || masterDatalst.isEmpty()) {
      return masterDatalst;
    }
    Set<String> hiddenApisForUserGroup = collectHiddenAssignmentApisForUserGroup(
      masterDatalst,
      currentUserGroup
    );
    List<SObject> filtered = new List<SObject>();
    for (SObject mdsRow : masterDatalst) {
      if (!isAssignmentRow(mdsRow)) {
        filtered.add(mdsRow);
        continue;
      }
      if (shouldExcludeHiddenAssignmentRowForUserGroup(mdsRow, currentUserGroup)) {
        continue;
      }
      if (
        shouldExcludeVisibleAssignmentRowWhenHiddenApplies(
          mdsRow,
          hiddenApisForUserGroup
        )
      ) {
        continue;
      }
      filtered.add(mdsRow);
    }
    return filtered;
  }

  /**
   * Thu thập FEC_Field_API_Name__c từ các dòng Assignment có FEC_Hidden__c = true
   * mà user hiện tại thuộc FEC_Editable_User_Group__c (contains).
   * Dùng để biết API nào cần ẩn bản Assignment hidden=false tương ứng.
   */
  @TestVisible
  private static Set<String> collectHiddenAssignmentApisForUserGroup(
    List<SObject> masterDatalst,
    String currentUserGroup
  ) {
    Set<String> apis = new Set<String>();
    if (masterDatalst == null || masterDatalst.isEmpty()) {
      return apis;
    }
    for (SObject mdsRow : masterDatalst) {
      if (
        isAssignmentRow(mdsRow) &&
        (Boolean) mdsRow.get('FEC_Hidden__c') == true &&
        isUserInEditableGroup(
          (String) mdsRow.get('FEC_Editable_User_Group__c'),
          currentUserGroup
        )
      ) {
        String api = (String) mdsRow.get('FEC_Field_API_Name__c');
        if (String.isNotBlank(api)) {
          apis.add(api);
        }
      }
    }
    return apis;
  }

  /**
   * Trả true → bỏ dòng Assignment khỏi masterDatalst.
   * Chỉ áp dụng khi FEC_Hidden__c = true và currentUserGroup không nằm trong FEC_Editable_User_Group__c
   * (user không được xem cấu hình assignment ẩn của team khác).
   */
  @TestVisible
  private static Boolean shouldExcludeHiddenAssignmentRowForUserGroup(
    SObject assignmentRow,
    String currentUserGroup
  ) {
    if (assignmentRow == null || !isAssignmentRow(assignmentRow)) {
      return false;
    }
    if ((Boolean) assignmentRow.get('FEC_Hidden__c') != true) {
      return false;
    }
    return !isUserInEditableGroup(
      (String) assignmentRow.get('FEC_Editable_User_Group__c'),
      currentUserGroup
    );
  }

  /**
   * Trả true → bỏ dòng Assignment hidden=false khỏi masterDatalst.
   * Khi user thuộc group của bản hidden=true (API có trong hiddenApisForUserGroup),
   * không hiển thị thêm bản hidden=false cùng FEC_Field_API_Name__c — tránh trùng / lộ field cho team khác.
   */
  @TestVisible
  private static Boolean shouldExcludeVisibleAssignmentRowWhenHiddenApplies(
    SObject assignmentRow,
    Set<String> hiddenApisForUserGroup
  ) {
    if (
      assignmentRow == null ||
      !isAssignmentRow(assignmentRow) ||
      hiddenApisForUserGroup == null ||
      hiddenApisForUserGroup.isEmpty()
    ) {
      return false;
    }
    if ((Boolean) assignmentRow.get('FEC_Hidden__c') == true) {
      return false;
    }
    String api = (String) assignmentRow.get('FEC_Field_API_Name__c');
    return String.isNotBlank(api) && hiddenApisForUserGroup.contains(api);
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

  /**
   * Stage nguồn (FEC_Previous_Stage) của lần revert mới nhất về currentStageId.
   */
  public static String getLatestRevertPreviousStageName(
    Id caseId,
    Id currentStageId,
    String currentStageName
  ) {
    if (caseId == null || currentStageId == null) {
      return null;
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
      return latestRevertHist[0].FEC_Previous_Stage__r?.Name;
    }
    Integer currentStageNum = extractStageNumberFromStageName(currentStageName);
    if (currentStageNum == null) {
      return null;
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
      return null;
    }
    Integer revertNextStageNum = extractStageNumberFromStageName(
      latestRevertByCase[0].FEC_Next_Stage__r?.Name
    );
    if (revertNextStageNum == null || revertNextStageNum != currentStageNum) {
      return null;
    }
    return latestRevertByCase[0].FEC_Previous_Stage__r?.Name;
  }

  /**
   * Revert về Stage 1: stage nguồn (2 hoặc 3) — chỉ hiện field xác nhận tương ứng.
   * latestRoutingActionIsRevert = routing history mới nhất là Revert.
   */
  public static Integer resolveRevertConfirmAssessmentSourceStage(
    Id caseId,
    Id currentStageId,
    String currentStageName,
    Boolean latestRoutingActionIsRevert
  ) {
    if (
      latestRoutingActionIsRevert != true ||
      !stageNameContains(currentStageName, FEC_ConstantCommon.STAGE_ONE)
    ) {
      return null;
    }
    String previousStageName = getLatestRevertPreviousStageName(
      caseId,
      currentStageId,
      currentStageName
    );
    Integer previousStageNum = extractStageNumberFromStageName(previousStageName);
    if (previousStageNum == 2 || previousStageNum == 3) {
      return previousStageNum;
    }
    return null;
  }

  /**
   * Revert 2→1 / 3→1: ẩn cả subsection (vd "Confirm to D2C Assessment") — không chỉ field.
   */
  public static Boolean shouldHideRevertConfirmSubSection(
    Integer revertSourceStageNumber,
    String subSectionName
  ) {
    if (revertSourceStageNumber == null || String.isBlank(subSectionName)) {
      return false;
    }
    String n = subSectionName.trim().toLowerCase();
    if (revertSourceStageNumber == 3) {
      return n.contains('confirm') && n.contains('d2c');
    }
    if (revertSourceStageNumber == 2) {
      return n.contains('confirm') &&
        (n.contains('cs sp') || n.contains('support'));
    }
    return false;
  }

  /**
   * Revert 2→1 / 3→1: bỏ subsection xác nhận không thuộc stage nguồn (tránh header trống trên UI).
   */
  public static void pruneRevertConfirmAssessmentSubSections(
    List<FEC_CaseBusinessService.Section> sectionlst,
    Integer revertConfirmAssessmentSourceStage
  ) {
    if (
      sectionlst == null ||
      revertConfirmAssessmentSourceStage == null
    ) {
      return;
    }
    for (FEC_CaseBusinessService.Section section : sectionlst) {
      if (section.subSectionlst == null || section.subSectionlst.isEmpty()) {
        continue;
      }
      for (Integer i = section.subSectionlst.size() - 1; i >= 0; i--) {
        FEC_CaseBusinessService.Section sub = section.subSectionlst[i];
        if (
          shouldHideRevertConfirmSubSection(
            revertConfirmAssessmentSourceStage,
            sub.name
          )
        ) {
          section.subSectionlst.remove(i);
        }
      }
    }
  }

  /** Ẩn field xác nhận không thuộc stage nguồn khi revert 2→1 hoặc 3→1. */
  public static Boolean shouldSkipRevertConfirmAssessmentField(
    Integer revertSourceStageNumber,
    String fieldApiName
  ) {
    if (revertSourceStageNumber == null || String.isBlank(fieldApiName)) {
      return false;
    }
    if (revertSourceStageNumber == 2) {
      return API_CONFIRM_CS_SP_ASSESSMENT.equals(fieldApiName);
    }
    if (revertSourceStageNumber == 3) {
      return API_CONFIRM_D2C_ASSESSMENT.equals(fieldApiName);
    }
    return false;
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
    return stageNameContains(
      getLatestRevertPreviousStageName(caseId, currentStageId, currentStageName),
      previousStageNameToken
    );
  }

  /**
   * GSR revert về Stage 1 từ Stage 2 — dùng để skip updateCaseNocFromSelection theo NOC Stage 2.
   */
  public static Boolean isGsrRevertStage2ToStage1(String caseId) {
    if (String.isBlank(caseId)) {
      return false;
    }
    List<Case> caseRows = [
      SELECT
        FEC_Current_Case_Stage__c,
        FEC_Current_Case_Stage__r.Name,
        FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (caseRows.isEmpty()) {
      return false;
    }
    Case c = caseRows[0];
    String bpCode = c.FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c;
    if (String.isBlank(bpCode) || !bpCode.toUpperCase().contains('GSR')) {
      return false;
    }
    if (!stageNameContains(c.FEC_Current_Case_Stage__r?.Name, FEC_ConstantCommon.STAGE_ONE)) {
      return false;
    }
    return isGsrRevertFromPreviousStageName(
      caseId,
      c.FEC_Current_Case_Stage__c,
      FEC_ConstantCommon.STAGE_TWO,
      c.FEC_Current_Case_Stage__r.Name
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
