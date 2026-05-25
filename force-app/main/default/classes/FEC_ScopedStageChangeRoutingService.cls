/**
 * Route to theo FEC_Stage_Change__c cho Document Request và Original MRC Return (Stage 2+ chọn Team).
 */
public without sharing class FEC_ScopedStageChangeRoutingService {
  public static final String DOCUMENT_REQUEST = 'Document Request';
  /** Khớp FEC_Business_Process__c.FEC_Code__c / Name trên org. */
  public static final String ORIGINAL_MRC_RETURN = 'Original MRC Return';

  private static final Set<String> SCOPED_BUSINESS_PROCESS_CODES = new Set<String>{
    DOCUMENT_REQUEST,
    ORIGINAL_MRC_RETURN
  };

  /** Kết quả tra History + Stage Change khi chọn lại Team đã Route to trước đó. */
  private class PriorTeamRouteMatch {
    Id revisitStageId;
    String ownerId;
  }

  public class RouteToTeamOption {
    @AuraEnabled
    public String stageChangeId { get; set; }
    @AuraEnabled
    public String team { get; set; }
    @AuraEnabled
    public String queueLabel { get; set; }
    @AuraEnabled
    public String queueValue { get; set; }
    @AuraEnabled
    public String queueDeveloperName { get; set; }
  }

  public static Boolean isScopedBusinessProcess(String businessProcessCode) {
    if (String.isBlank(businessProcessCode)) {
      return false;
    }
    return SCOPED_BUSINESS_PROCESS_CODES.contains(businessProcessCode.trim());
  }

  public static Integer extractStageNumber(String stageName) {
    if (String.isBlank(stageName)) {
      return null;
    }
    Matcher m = FEC_ConstantCommon.PAT_STAGE_NAME_WITH_NUMBER.matcher(stageName.trim());
    if (m.find()) {
      return Integer.valueOf(m.group(1));
    }
    return null;
  }

  @AuraEnabled(cacheable=true)
  public static List<RouteToTeamOption> getRouteToTeamOptions(
    Id caseId,
    String routeToActionId
  ) {
    List<RouteToTeamOption> result = new List<RouteToTeamOption>();
    if (caseId == null || String.isBlank(routeToActionId)) {
      return result;
    }

    List<Case> cases = [
      SELECT Id, FEC_Current_Case_Stage__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (cases.isEmpty() || cases[0].FEC_Current_Case_Stage__c == null) {
      return result;
    }

    Id currentStageId = cases[0].FEC_Current_Case_Stage__c;
    List<FEC_Stage_Change__c> rows = [
      SELECT Id, FEC_Team_User_Group__c, FEC_Next_Queue__c
      FROM FEC_Stage_Change__c
      WHERE
        FEC_Previous_Stage__c = :currentStageId
        AND FEC_Active__c = TRUE
        AND FEC_Action_Button__c = :routeToActionId
        AND FEC_IsReverted__c = FALSE
      ORDER BY FEC_Team_User_Group__c ASC, FEC_Next_Queue__c ASC
    ];
    if (rows.isEmpty()) {
      return result;
    }

    Set<String> queueDevNames = new Set<String>();
    for (FEC_Stage_Change__c row : rows) {
      if (String.isNotBlank(row.FEC_Next_Queue__c)) {
        queueDevNames.add(row.FEC_Next_Queue__c);
      }
    }
    Map<String, Group> devNameToQueue = new Map<String, Group>();
    if (!queueDevNames.isEmpty()) {
      for (Group g : [
        SELECT Id, Name, DeveloperName
        FROM Group
        WHERE
          Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
          AND DeveloperName IN :queueDevNames
      ]) {
        devNameToQueue.put(g.DeveloperName, g);
      }
    }

    for (FEC_Stage_Change__c row : rows) {
      RouteToTeamOption opt = new RouteToTeamOption();
      opt.stageChangeId = row.Id;
      opt.team = row.FEC_Team_User_Group__c;
      opt.queueDeveloperName = row.FEC_Next_Queue__c;
      if (
        String.isNotBlank(row.FEC_Next_Queue__c) &&
        devNameToQueue.containsKey(row.FEC_Next_Queue__c)
      ) {
        Group q = devNameToQueue.get(row.FEC_Next_Queue__c);
        opt.queueLabel = q.Name;
        opt.queueValue = (String) q.Id;
      } else if (String.isNotBlank(row.FEC_Next_Queue__c)) {
        opt.queueLabel = row.FEC_Next_Queue__c;
        opt.queueValue = row.FEC_Next_Queue__c;
      }
      result.add(opt);
    }
    return result;
  }

  /**
   * Route to cho Document Request / Original MRC Return — dùng đúng dòng FEC_Stage_Change__c user chọn (Stage 2+).
   */
  @AuraEnabled
  public static void submitRouteTo(
    Id caseId,
    Id selectedStageChangeId,
    String selectedTeam,
    String actionId,
    String natureOfCaseId,
    String fieldListJson
  ) {
    if (caseId == null || selectedStageChangeId == null) {
      throw new AuraHandledException(
        String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Case / Stage Change' })
      );
    }

    List<Case> caselst = [
      SELECT
        Id,
        OwnerId,
        Owner.Name,
        FEC_Current_Case_Stage__c,
        Status,
        FEC_Team__c,
        FEC_Is_Submited__c,
        FEC_Actual_Nature_of_Case__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (caselst.isEmpty()) {
      throw new AuraHandledException(
        String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Case Id' })
      );
    }
    Case updatedCase = caselst[0];
    if (updatedCase.FEC_Is_Submited__c != true) {
      throw new AuraHandledException(
        String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Case submit status' })
      );
    }
    String finalStatusBeforeSubmit = FEC_CaseBusinessService.routingHistoryStatusSnapshot(
      updatedCase
    );

    List<FEC_Stage_Change__c> changelst = [
      SELECT
        Id,
        FEC_Previous_Stage__c,
        FEC_Previous_Stage__r.FEC_Code__c,
        FEC_Next_Stage__c,
        FEC_Next_Queue__c,
        FEC_Team_User_Group__c,
        FEC_Action_Button__c
      FROM FEC_Stage_Change__c
      WHERE
        Id = :selectedStageChangeId
        AND FEC_Active__c = TRUE
        AND FEC_IsReverted__c = FALSE
      LIMIT 1
    ];
    if (changelst.isEmpty()) {
      throw new AuraHandledException(
        String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Stage Change' })
      );
    }
    FEC_Stage_Change__c selectedChange = changelst[0];
    if (
      updatedCase.FEC_Current_Case_Stage__c != selectedChange.FEC_Previous_Stage__c ||
      (String.isNotBlank(actionId) &&
      selectedChange.FEC_Action_Button__c != actionId)
    ) {
      throw new AuraHandledException(
        String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Stage Change selection' })
      );
    }

    Id resolvedNextStageId = selectedChange.FEC_Next_Stage__c;
    String queueId;

    PriorTeamRouteMatch priorMatch = findPriorRouteByTeam(
      caseId,
      selectedTeam,
      actionId,
      updatedCase.FEC_Current_Case_Stage__c
    );
    if (priorMatch != null && priorMatch.revisitStageId != null) {
      resolvedNextStageId = priorMatch.revisitStageId;
    }

    queueId = resolveOwnerForTargetStage(
      caseId,
      resolvedNextStageId,
      selectedChange.FEC_Next_Queue__c
    );
    if (String.isBlank(queueId)) {
      throw new AuraHandledException(System.Label.FEC_MSG_Can_Not_Find_Next_Stage);
    }

    Boolean isCreationStage = updatedCase.FEC_Is_Submited__c != true;
    FEC_CaseBusinessService.markCaseSubmittedAndClearDrafts(caseId);
    if (isCreationStage && String.isNotBlank(natureOfCaseId)) {
      FEC_CaseBusinessService.createCaseFlowHistory(
        caseId,
        natureOfCaseId,
        fieldListJson
      );
    }

    applyScopedRouteCaseUpdate(
      caseId,
      updatedCase,
      selectedChange,
      resolvedNextStageId,
      queueId,
      finalStatusBeforeSubmit
    );
  }

  /**
   * Cách 2: History Route to + FEC_Stage_Change__c cùng cặp stage và FEC_Team_User_Group__c.
   * Lấy bản history mới nhất khớp Team → quay lại FEC_Next_Stage__c lúc đó.
   */
  private static PriorTeamRouteMatch findPriorRouteByTeam(
    Id caseId,
    String selectedTeam,
    String routeToActionId,
    Id currentStageId
  ) {
    if (caseId == null || String.isBlank(selectedTeam)) {
      return null;
    }
    String teamTrim = selectedTeam.trim();
    Id actionButtonId;
    try {
      actionButtonId = String.isNotBlank(routeToActionId)
        ? Id.valueOf(routeToActionId.trim())
        : null;
    } catch (Exception e) {
      return null;
    }
    if (actionButtonId == null) {
      return null;
    }

    List<FEC_Routing_Action_History__c> histories = [
      SELECT
        Id,
        FEC_Previous_Stage__c,
        FEC_Next_Stage__c,
        FEC_Perform_User__c,
        FEC_Updated_User_Queue_ID__c
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Routing_Action__c = :FEC_CaseBusinessService.ROUTE_TO
      ORDER BY CreatedDate DESC, Id DESC
    ];

    for (FEC_Routing_Action_History__c hist : histories) {
      if (hist.FEC_Previous_Stage__c == null || hist.FEC_Next_Stage__c == null) {
        continue;
      }
      if (currentStageId != null && hist.FEC_Next_Stage__c == currentStageId) {
        continue;
      }

      List<FEC_Stage_Change__c> stageChangeRows = [
        SELECT Id, FEC_Next_Queue__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :hist.FEC_Previous_Stage__c
          AND FEC_Next_Stage__c = :hist.FEC_Next_Stage__c
          AND FEC_Active__c = TRUE
          AND FEC_IsReverted__c = FALSE
          AND FEC_Team_User_Group__c = :teamTrim
          AND FEC_Action_Button__c = :actionButtonId
        LIMIT 1
      ];
      if (stageChangeRows.isEmpty()) {
        continue;
      }

      PriorTeamRouteMatch match = new PriorTeamRouteMatch();
      match.revisitStageId = hist.FEC_Next_Stage__c;
      return match;
    }
    return null;
  }

  /**
   * Owner khi revisit stage đích: Change Owner tại stage (assign user/queue thủ công),
   * rồi Route to vào stage, rồi Route to rời stage, rồi FEC_Next_Queue__c Stage Change.
   */
  private static String resolveOwnerForTargetStage(
    Id caseId,
    Id targetStageId,
    String stageChangeNextQueueFallback
  ) {
    if (caseId == null) {
      return ownerFromStageChangeQueueOnly(stageChangeNextQueueFallback);
    }

    String stageCode = lookupStageCode(targetStageId);

    if (String.isNotBlank(stageCode)) {
      List<FEC_Routing_Action_History__c> changeOwnerAtStage = [
        SELECT FEC_Perform_User__c, FEC_Updated_User_Queue_ID__c
        FROM FEC_Routing_Action_History__c
        WHERE
          FEC_Case__c = :caseId
          AND FEC_Routing_Action__c = :FEC_CaseBusinessService.CHANGE_OWNER
          AND FEC_Stage_Name__c = :stageCode
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];
      if (!changeOwnerAtStage.isEmpty()) {
        String fromChangeOwner = resolveOwnerIdFromRouteHistory(
          changeOwnerAtStage[0],
          null
        );
        if (String.isNotBlank(fromChangeOwner)) {
          return fromChangeOwner;
        }
      }
    }

    if (targetStageId != null) {
      List<FEC_Routing_Action_History__c> routeToArrival = [
        SELECT FEC_Perform_User__c, FEC_Updated_User_Queue_ID__c
        FROM FEC_Routing_Action_History__c
        WHERE
          FEC_Case__c = :caseId
          AND FEC_Routing_Action__c = :FEC_CaseBusinessService.ROUTE_TO
          AND FEC_Next_Stage__c = :targetStageId
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];
      if (!routeToArrival.isEmpty()) {
        String fromArrival = resolveOwnerIdFromRouteHistory(routeToArrival[0], null);
        if (String.isNotBlank(fromArrival)) {
          return fromArrival;
        }
      }

      List<FEC_Routing_Action_History__c> routeFromStage = [
        SELECT FEC_Perform_User__c, FEC_Updated_User_Queue_ID__c
        FROM FEC_Routing_Action_History__c
        WHERE
          FEC_Case__c = :caseId
          AND FEC_Routing_Action__c = :FEC_CaseBusinessService.ROUTE_TO
          AND FEC_Previous_Stage__c = :targetStageId
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];
      if (!routeFromStage.isEmpty()) {
        String fromDeparture = resolveOwnerIdFromRouteHistory(routeFromStage[0], null);
        if (String.isNotBlank(fromDeparture)) {
          return fromDeparture;
        }
      }
    }

    return ownerFromStageChangeQueueOnly(stageChangeNextQueueFallback);
  }

  private static String lookupStageCode(Id stageId) {
    if (stageId == null) {
      return null;
    }
    List<FEC_Case_Stage__c> rows = [
      SELECT FEC_Code__c
      FROM FEC_Case_Stage__c
      WHERE Id = :stageId
      LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0].FEC_Code__c;
  }

  private static String ownerFromStageChangeQueueOnly(String stageChangeNextQueueValue) {
    if (String.isBlank(stageChangeNextQueueValue)) {
      return null;
    }
    return applyPriorCaseOwnerFromHistory(
      resolveQueueOwnerIdFromStageChangeValue(stageChangeNextQueueValue)
    );
  }

  /**
   * Owner khi revisit stage: lấy owner/queue sau action từ FEC_Updated_User_Queue_ID__c,
   * rồi fallback FEC_Next_Queue__c Stage Change. Không dùng FEC_Perform_User__c (user thao tác, không phải owner cũ).
   */
  private static String resolveOwnerIdFromRouteHistory(
    FEC_Routing_Action_History__c hist,
    String stageChangeNextQueueValue
  ) {
    if (hist != null && String.isNotBlank(hist.FEC_Updated_User_Queue_ID__c)) {
      return applyPriorCaseOwnerFromHistory(hist.FEC_Updated_User_Queue_ID__c);
    }
    if (String.isNotBlank(stageChangeNextQueueValue)) {
      return applyPriorCaseOwnerFromHistory(
        resolveQueueOwnerIdFromStageChangeValue(stageChangeNextQueueValue)
      );
    }
    return null;
  }

  /**
   * User/queue cũ từ history: nếu là User CS Frontline → Owner = Main Queue (FEC_Main_Queue__c);
   * không thuộc Frontline → giữ đúng User; đã là Queue → giữ Queue.
   */
  private static String applyPriorCaseOwnerFromHistory(String ownerIdStr) {
    if (String.isBlank(ownerIdStr)) {
      return ownerIdStr;
    }
    try {
      Id ownerId = Id.valueOf(ownerIdStr.trim());
      if (ownerId.getSobjectType() == Group.SObjectType) {
        return ownerIdStr;
      }
      if (ownerId.getSobjectType() != User.SObjectType) {
        return ownerIdStr;
      }
      // SYSTEM_MODE: submit có thể do user khác (vd ducnm148) — FLS thường che FEC_User_Division_Group__c / FEC_Main_Queue__c của owner cũ.
      List<User> users = [
        SELECT FEC_User_Division_Group__c, FEC_Main_Queue__c
        FROM User
        WHERE Id = :ownerId
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      if (users.isEmpty()) {
        return ownerIdStr;
      }
      User u = users[0];
      if (
        !FEC_CaseBusinessService.FRONT_LINE.equals(u.FEC_User_Division_Group__c) ||
        String.isBlank(u.FEC_Main_Queue__c)
      ) {
        return ownerIdStr;
      }
      List<Group> qs = [
        SELECT Id
        FROM Group
        WHERE
          Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
          AND DeveloperName = :u.FEC_Main_Queue__c
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      return qs.isEmpty() ? ownerIdStr : String.valueOf(qs[0].Id);
    } catch (Exception e) {
      return ownerIdStr;
    }
  }

  private static void applyScopedRouteCaseUpdate(
    Id caseId,
    Case caseBefore,
    FEC_Stage_Change__c selectedChange,
    Id resolvedNextStageId,
    String queueId,
    String finalStatusBeforeSubmit
  ) {
    List<User> userlst = [
      SELECT Email, UserRole.Name, Id
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    if (userlst.isEmpty()) {
      return;
    }

    String currentOwnerName = FEC_CaseBusinessService.resolveRoutingHistoryOwnerLabel(
      caseBefore.OwnerId,
      caseBefore.Owner?.Name
    );
    Id currentOwnerId = caseBefore.OwnerId;

    String nextOwnerName;
    List<Group> queuelst = [
      SELECT Id, Name
      FROM Group
      WHERE Id = :queueId
    ];
    if (queuelst.isEmpty()) {
      nextOwnerName = FEC_CaseBusinessService.resolveRoutingHistoryOwnerLabel(
        Id.valueOf(queueId.trim()),
        null
      );
    } else {
      nextOwnerName = queuelst[0].Name;
    }

    FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
      FEC_Perform_User__c = userlst[0].Id,
      FEC_Previous_Stage__c = selectedChange.FEC_Previous_Stage__c,
      FEC_Next_Stage__c = resolvedNextStageId,
      FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
      FEC_Case__c = caseId,
      FEC_Original_User_Queue__c = currentOwnerName,
      FEC_Original_User_Queue_ID__c = currentOwnerId != null
        ? String.valueOf(currentOwnerId)
        : null,
      FEC_Updated_User_Queue__c = nextOwnerName,
      FEC_Updated_User_Queue_ID__c = queueId,
      FEC_Stage_Name__c = selectedChange.FEC_Previous_Stage__r?.FEC_Code__c,
      FEC_User__c = FEC_CaseBusinessService.emailLocalPart(userlst[0].Email),
      FEC_User_Role__c = userlst[0].UserRole?.Name,
      FEC_Current_Status__c = finalStatusBeforeSubmit
    );

    Database.insert(history, AccessLevel.SYSTEM_MODE);

    Case updatedCase = new Case(
      Id = caseId,
      OwnerId = Id.valueOf(queueId.trim()),
      FEC_Current_Case_Stage__c = resolvedNextStageId
    );
    FEC_CaseBusinessService.registerSkipOwnerChangeRoutingHistory(caseId);
    Database.update(updatedCase, AccessLevel.SYSTEM_MODE);

    Case endCase = [
      SELECT Status, FEC_Team__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    FEC_CaseBusinessService.patchRoutingHistoryChangedStatus(
      history.Id,
      FEC_CaseBusinessService.routingHistoryStatusSnapshot(endCase)
    );
    FEC_AutoHoldCaseService.enqueueAfterRoutingHistory(history.Id);
  }

  private static String resolveQueueOwnerIdFromStageChangeValue(String nextQueueValue) {
    if (String.isBlank(nextQueueValue)) {
      return nextQueueValue;
    }
    String normalized = nextQueueValue.trim();
    try {
      Id qid = Id.valueOf(normalized);
      if (qid.getSobjectType() == Group.SObjectType) {
        List<Group> grp = [
          SELECT Id, Type
          FROM Group
          WHERE Id = :qid
          LIMIT 1
        ];
        if (
          !grp.isEmpty() &&
          FEC_ConstantCommon.GROUP_TYPE_QUEUE.equals(grp[0].Type)
        ) {
          return String.valueOf(grp[0].Id);
        }
      }
      return normalized;
    } catch (Exception e) {
      List<Group> q = [
        SELECT Id
        FROM Group
        WHERE
          Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
          AND DeveloperName = :normalized
        LIMIT 1
      ];
      return q.isEmpty() ? normalized : String.valueOf(q[0].Id);
    }
  }
}