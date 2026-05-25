/**
 * RL04.02 / RL04.03 — bổ sung routing actions khi không đủ điều kiện phát hành giấy
 * (getByCase có thể trả routingActionlst rỗng). Không thay đổi luồng getByCase hiện tại.
 */
public with sharing class FEC_DocumentRequestRoutingActionService {

  private static final String SUB_CODE_RL0402 = 'RL04.02';
  private static final String SUB_CODE_RL0403 = 'RL04.03';

  @AuraEnabled(cacheable=false)
  public static List<FEC_CaseBusinessService.Action> getRoutingActionsForRl0402Rl0403(
    Id caseId
  ) {
    List<FEC_CaseBusinessService.Action> actions = new List<FEC_CaseBusinessService.Action>();
    if (caseId == null) {
      return actions;
    }

    List<Case> cases = [
      SELECT
        FEC_Current_Case_Stage__c,
        FEC_Product_Type__c,
        FEC_Category__c,
        FEC_SubCategory__c,
        FEC_SubCode__c,
        FEC_Customer_Type__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (cases.isEmpty()) {
      return actions;
    }
    Id stageId = cases[0].FEC_Current_Case_Stage__c;
    if (stageId == null) {
      stageId = defaultStageIdForDocumentRequestCase(cases[0]);
    }
    if (stageId == null) {
      return actions;
    }

    List<User> users = [
      SELECT FEC_User_Group__c
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    List<String> rolelst = new List<String>();
    if (!users.isEmpty() && String.isNotBlank(users[0].FEC_User_Group__c)) {
      rolelst.add(users[0].FEC_User_Group__c);
    }
    if (rolelst.isEmpty()) {
      return actions;
    }
    String userGroup = rolelst[0];

    Boolean isRevert = false;
    List<FEC_Routing_Action_History__c> historylst = [
      SELECT FEC_Routing_Action__c
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Routing_Action__c IN (
          :FEC_CaseBusinessService.ROUTE_TO,
          :FEC_CaseBusinessService.REVERT
        )
        AND FEC_Case__c = :caseId
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 1
    ];
    if (
      !historylst.isEmpty() &&
      FEC_CaseBusinessService.REVERT.equals(historylst[0].FEC_Routing_Action__c)
    ) {
      isRevert = true;
    }

    List<FEC_Stage_Screen__c> actionlst = [
      SELECT
        Id,
        FEC_Action_Button__c,
        FEC_Action_Button__r.Name,
        FEC_Action_Button__r.FEC_Type__c,
        FEC_Action_Button__r.FEC_Code__c,
        FEC_Custom_Action_Button_Label__c,
        FEC_Field_Type__c
      FROM FEC_Stage_Screen__c
      WHERE
        FEC_Action_Button__c != NULL
        AND FEC_Active__c = TRUE
        AND FEC_Action_Button__r.FEC_Type__c = 'Routing Action'
        AND FEC_Case_Stage__c = :stageId
        AND FEC_User_Group__c INCLUDES (:userGroup)
    ];

    for (FEC_Stage_Screen__c item : actionlst) {
      FEC_CaseBusinessService.Action act = new FEC_CaseBusinessService.Action(
        item.FEC_Action_Button__c,
        String.isNotBlank(item.FEC_Custom_Action_Button_Label__c)
          ? item.FEC_Custom_Action_Button_Label__c
          : item.FEC_Action_Button__r.FEC_Code__c,
        String.isNotBlank(item.FEC_Custom_Action_Button_Label__c)
          ? item.FEC_Custom_Action_Button_Label__c
          : item.FEC_Action_Button__r.Name,
        item.FEC_Action_Button__r.FEC_Code__c
      );
      if (item.FEC_Field_Type__c == 'All') {
        actions.add(act);
      } else if (item.FEC_Field_Type__c == 'New' && !isRevert) {
        actions.add(act);
      } else if (item.FEC_Field_Type__c == 'Revert' && isRevert) {
        actions.add(act);
      }
    }
    return actions;
  }

  /** Fallback khi FEC_Current_Case_Stage__c null — default stage của NOC trên Case (giống getByCase). */
  private static Id defaultStageIdForDocumentRequestCase(Case c) {
    if (
      c == null ||
      c.FEC_Product_Type__c == null ||
      c.FEC_Category__c == null ||
      c.FEC_SubCategory__c == null ||
      c.FEC_SubCode__c == null
    ) {
      return null;
    }
    List<String> customerTypelst = new List<String>{ 'All' };
    if (String.isNotBlank(c.FEC_Customer_Type__c)) {
      customerTypelst.add(c.FEC_Customer_Type__c);
    }
    List<FEC_Nature_of_Case__c> noclst = [
      SELECT Id
      FROM FEC_Nature_of_Case__c
      WHERE
        FEC_Product_Type__c = :c.FEC_Product_Type__c
        AND FEC_Category__c = :c.FEC_Category__c
        AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
        AND FEC_Sub_Code__c = :c.FEC_SubCode__c
        AND FEC_Customer_Type__c IN :customerTypelst
        AND FEC_Active__c = TRUE
        AND FEC_Business_Process__r.FEC_Active__c = TRUE
      LIMIT 1
    ];
    if (noclst.isEmpty()) {
      return null;
    }
    List<FEC_Case_Stage__c> stagelst = [
      SELECT Id
      FROM FEC_Case_Stage__c
      WHERE
        FEC_Nature_of_Cases__c = :noclst[0].Id
        AND FEC_Active__c = TRUE
        AND FEC_Default_Stage__c = TRUE
      LIMIT 1
    ];
    return stagelst.isEmpty() ? null : stagelst[0].Id;
  }

  public static Boolean isRl0402OrRl0403SubCode(String subCodeCode) {
    if (String.isBlank(subCodeCode)) {
      return false;
    }
    String code = subCodeCode.trim();
    return SUB_CODE_RL0402.equalsIgnoreCase(code) ||
      SUB_CODE_RL0403.equalsIgnoreCase(code);
  }

  /**
   * RL05 — bổ sung routing actions khi getByCase trả routingActionlst rỗng (Stage 1 / template fallback).
   */
  @AuraEnabled(cacheable=false)
  public static List<FEC_CaseBusinessService.Action> getRoutingActionsForMrcRl05(
    Id caseId
  ) {
    List<FEC_CaseBusinessService.Action> actions = new List<FEC_CaseBusinessService.Action>();
    if (caseId == null) {
      return actions;
    }

    List<Case> cases = [
      SELECT
        FEC_Current_Case_Stage__c,
        FEC_Current_Case_Stage__r.Name,
        FEC_SubCategory__r.FEC_Code__c,
        FEC_SubCode__r.FEC_Code__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (cases.isEmpty()) {
      return actions;
    }
    Case selectedCase = cases[0];
    String subCategoryCode = selectedCase.FEC_SubCategory__r != null
      ? selectedCase.FEC_SubCategory__r.FEC_Code__c
      : null;
    String subCodeCode = selectedCase.FEC_SubCode__r != null
      ? selectedCase.FEC_SubCode__r.FEC_Code__c
      : null;
    if (
      !FEC_MrcReturnCaseService.isRl05Branch(subCategoryCode, subCodeCode)
    ) {
      return actions;
    }

    List<String> rolelst = resolveCurrentUserGroups();
    if (rolelst.isEmpty()) {
      return actions;
    }

    Boolean isRevert = resolveLatestRevertFlag(caseId);
    if (selectedCase.FEC_Current_Case_Stage__c != null) {
      actions.addAll(
        queryRoutingActionsForStage(
          selectedCase.FEC_Current_Case_Stage__c,
          rolelst,
          isRevert
        )
      );
    }

    if (!actions.isEmpty()) {
      return actions;
    }

    FEC_CaseBusinessService.Business result = new FEC_CaseBusinessService.Business();
    result.subCategoryCode = subCategoryCode;
    result.subCodeCode = subCodeCode;
    String stageName = selectedCase.FEC_Current_Case_Stage__r != null
      ? selectedCase.FEC_Current_Case_Stage__r.Name
      : FEC_ConstantCommon.STAGE_ONE;
    FEC_MrcReturnCaseService.supplementStage1RoutingActionsIfEmpty(
      result,
      stageName,
      rolelst,
      isRevert
    );
    return result.routingActionlst != null
      ? result.routingActionlst
      : new List<FEC_CaseBusinessService.Action>();
  }

  private static List<String> resolveCurrentUserGroups() {
    List<String> rolelst = new List<String>();
    List<User> users = [
      SELECT FEC_User_Group__c
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    if (!users.isEmpty() && String.isNotBlank(users[0].FEC_User_Group__c)) {
      rolelst.add(users[0].FEC_User_Group__c);
    }
    return rolelst;
  }

  private static Boolean resolveLatestRevertFlag(Id caseId) {
    List<FEC_Routing_Action_History__c> historylst = [
      SELECT FEC_Routing_Action__c
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Routing_Action__c IN (
          :FEC_CaseBusinessService.ROUTE_TO,
          :FEC_CaseBusinessService.REVERT
        )
        AND FEC_Case__c = :caseId
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 1
    ];
    return !historylst.isEmpty() &&
      FEC_CaseBusinessService.REVERT.equals(historylst[0].FEC_Routing_Action__c);
  }

  private static List<FEC_CaseBusinessService.Action> queryRoutingActionsForStage(
    Id stageId,
    List<String> rolelst,
    Boolean isRevert
  ) {
    List<FEC_CaseBusinessService.Action> actions = new List<FEC_CaseBusinessService.Action>();
    String userGroup = rolelst[0];
    List<FEC_Stage_Screen__c> actionlst = [
      SELECT
        Id,
        FEC_Action_Button__c,
        FEC_Action_Button__r.Name,
        FEC_Action_Button__r.FEC_Type__c,
        FEC_Action_Button__r.FEC_Code__c,
        FEC_Custom_Action_Button_Label__c,
        FEC_Field_Type__c
      FROM FEC_Stage_Screen__c
      WHERE
        FEC_Action_Button__c != NULL
        AND FEC_Active__c = TRUE
        AND FEC_Action_Button__r.FEC_Type__c = :FEC_ConstantCommon.ACTION_BUTTON_TYPE_ROUTING_ACTION
        AND FEC_Case_Stage__c = :stageId
        AND FEC_User_Group__c INCLUDES (:userGroup)
    ];

    for (FEC_Stage_Screen__c item : actionlst) {
      FEC_CaseBusinessService.Action act = new FEC_CaseBusinessService.Action(
        item.FEC_Action_Button__c,
        String.isNotBlank(item.FEC_Custom_Action_Button_Label__c)
          ? item.FEC_Custom_Action_Button_Label__c
          : item.FEC_Action_Button__r.FEC_Code__c,
        String.isNotBlank(item.FEC_Custom_Action_Button_Label__c)
          ? item.FEC_Custom_Action_Button_Label__c
          : item.FEC_Action_Button__r.Name,
        item.FEC_Action_Button__r.FEC_Code__c
      );
      if (item.FEC_Field_Type__c == FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_ALL) {
        actions.add(act);
      } else if (
        item.FEC_Field_Type__c == FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_NEW &&
        isRevert != true
      ) {
        actions.add(act);
      } else if (
        item.FEC_Field_Type__c == FEC_ConstantCommon.ACTION_REVERT &&
        isRevert == true
      ) {
        actions.add(act);
      }
    }
    return actions;
  }
}
