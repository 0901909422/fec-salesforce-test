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
      SELECT FEC_Current_Case_Stage__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (cases.isEmpty() || cases[0].FEC_Current_Case_Stage__c == null) {
      return actions;
    }
    Id stageId = cases[0].FEC_Current_Case_Stage__c;

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

  public static Boolean isRl0402OrRl0403SubCode(String subCodeCode) {
    if (String.isBlank(subCodeCode)) {
      return false;
    }
    String code = subCodeCode.trim();
    return SUB_CODE_RL0402.equalsIgnoreCase(code) ||
      SUB_CODE_RL0403.equalsIgnoreCase(code);
  }
}
