/**
 * Migrate Case legacy → Salesforce: lấy danh sách Routing Action theo Case Id.
 * @author: thangtv
 * @date: 01/06/2026
 * @description: 
 * - Lấy danh sách Routing Action theo Case Id.
 * - moveNextStage: preview Stage Change theo action (không DML).
  */
public with sharing class FEC_CaseMigrationService {
  private static final String ROUTING_ACTION_TYPE = 'Routing Action';
  private static final String ROUTE_TO = FEC_CaseBusinessService.ROUTE_TO;
  private static final String REVERT = FEC_CaseBusinessService.REVERT;
  private static final String ESCALATE = FEC_CaseBusinessService.ESCALATE;
  private static final String REJECT = FEC_CaseBusinessService.REJECT;
  private static final String RESOLVE = FEC_CaseBusinessService.RESOLVE;
  private static final String TRANSFER = FEC_CaseBusinessService.TRANSFER;
  private static final String ACTION_UPDATE = FEC_CaseBusinessService.UPDATEACTION;

  /**
   * Input: Case Id. NOC, stage, user group đọc từ Case + user hiện tại.
   */
  @AuraEnabled(cacheable=true)
  public static List<RoutingAction> getRoutingActionlst(String caseId) {
    try {
      return getRoutingActionlstCore(caseId);
    } catch (MigrationServiceException e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Wrapper cho Apex class / Batch / Anonymous Apex — không ném AuraHandledException.
   * @return RoutingActionListResult.success = true khi có data; message khi lỗi.
   */
  public static RoutingActionListResult getRoutingActionlstForApex(String caseId) {
    RoutingActionListResult result = new RoutingActionListResult();
    try {
      result.data = getRoutingActionlstCore(caseId);
      result.success = true;
    } catch (MigrationServiceException e) {
      result.success = false;
      result.message = e.getMessage();
    }
    return result;
  }

  private static List<RoutingAction> getRoutingActionlstCore(String caseId) {
    if (String.isBlank(caseId)) {
      throw migrationInvalid('Case Id');
    }

    Case caseRow = loadCase(caseId);
    List<String> rolelst = resolveRoleListForCurrentUser();
    if (rolelst.isEmpty()) {
      return new List<RoutingAction>();
    }

    StageContext stageCtx = resolveStageContext(caseRow, rolelst);
    if (stageCtx.stageId == null) {
      throw migrationNotFound('Case Stage');
    }

    Boolean isRevert = resolveIsRevertFromLatestHistory(caseId);
    List<RoutingAction> actions = queryRoutingActionsForStage(
      stageCtx.stageId,
      rolelst,
      isRevert
    );

    if (actions == null || actions.isEmpty()) {
      throw migrationNotFound('Routing Action');
    }

    return actions;
  }

  /**
   * Preview chuyển stage theo routing action — query FEC_Stage_Change__c, không gọi run()/DML.
   * actionCode phải có trong getRoutingActionlst.
   * Revert: nextQueue / teamUserGroup từ Routing Action History (người xử lý trước), giống revert().
   */
  @AuraEnabled(cacheable=true)
  public static List<MoveNextStageItem> moveNextStage(
    String caseId,
    String actionCode
  ) {
    try {
      return moveNextStageCore(caseId, actionCode);
    } catch (MigrationServiceException e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Wrapper cho Apex class / Batch / Anonymous Apex — không ném AuraHandledException.
   * @return MoveNextStageListResult.success = true khi gọi thành công (data có thể rỗng).
   */
  public static MoveNextStageListResult moveNextStageForApex(
    String caseId,
    String actionCode
  ) {
    MoveNextStageListResult result = new MoveNextStageListResult();
    try {
      result.data = moveNextStageCore(caseId, actionCode);
      result.success = true;
    } catch (MigrationServiceException e) {
      result.success = false;
      result.message = e.getMessage();
    }
    return result;
  }

  private static List<MoveNextStageItem> moveNextStageCore(
    String caseId,
    String actionCode
  ) {
    if (String.isBlank(caseId)) {
      throw migrationInvalid('Case Id');
    }
    String canonicalAction = normalizeActionCode(actionCode);
    if (canonicalAction == null) {
      throw migrationInvalid('Action Code');
    }

    RoutingAction allowedAction = resolveAllowedRoutingAction(caseId, canonicalAction);
    if (allowedAction == null || String.isBlank(allowedAction.id)) {
      throw migrationInvalid(canonicalAction + ' (not in routing actions)');
    }

    Case caseRow = loadCaseForMove(caseId);
    List<String> rolelst = resolveRoleListForCurrentUser();
    if (rolelst.isEmpty()) {
      return new List<MoveNextStageItem>();
    }

    StageContext stageCtx = resolveStageContext(caseRow, rolelst);
    if (stageCtx.stageId == null) {
      return new List<MoveNextStageItem>();
    }

    return queryMoveNextStageItems(
      caseId,
      stageCtx.stageId,
      allowedAction.id,
      canonicalAction
    );
  }

  private static List<MoveNextStageItem> queryMoveNextStageItems(
    String caseId,
    Id currentStageId,
    String actionId,
    String canonicalAction
  ) {
    List<FEC_Stage_Change__c> changelst = queryStageChangesForAction(
      caseId,
      currentStageId,
      actionId,
      canonicalAction
    );
    return mapStageChangesToItems(caseId, canonicalAction, changelst);
  }

  /**
   * Query FEC_Stage_Change__c — Route to / Revert dùng filter giống route()/revert(); action khác lấy mọi dòng active.
   */
  private static List<FEC_Stage_Change__c> queryStageChangesForAction(
    String caseId,
    Id currentStageId,
    String actionId,
    String canonicalAction
  ) {
    if (currentStageId == null || String.isBlank(actionId)) {
      return new List<FEC_Stage_Change__c>();
    }

    if (ROUTE_TO.equals(canonicalAction)) {
      return queryStageChangesForRouteTo(caseId, currentStageId, actionId);
    }
    if (REVERT.equals(canonicalAction)) {
      return [
        SELECT
          Id,
          FEC_Previous_Stage__c,
          FEC_Previous_Stage__r.Name,
          FEC_Next_Stage__c,
          FEC_Next_Stage__r.Name,
          FEC_Action_Button__c,
          FEC_Action_Button__r.Name,
          FEC_Next_Queue__c,
          FEC_Team_User_Group__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :currentStageId
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__c = :actionId
          AND FEC_IsReverted__c = TRUE
        ORDER BY FEC_Team_User_Group__c, Id
      ];
    }

    return [
      SELECT
        Id,
        FEC_Previous_Stage__c,
        FEC_Previous_Stage__r.Name,
        FEC_Next_Stage__c,
        FEC_Next_Stage__r.Name,
        FEC_Action_Button__c,
        FEC_Action_Button__r.Name,
        FEC_Next_Queue__c,
        FEC_Team_User_Group__c
      FROM FEC_Stage_Change__c
      WHERE
        FEC_Previous_Stage__c = :currentStageId
        AND FEC_Active__c = TRUE
        AND FEC_Action_Button__c = :actionId
      ORDER BY FEC_Team_User_Group__c, Id
    ];
  }

  private static List<FEC_Stage_Change__c> queryStageChangesForRouteTo(
    String caseId,
    Id currentStageId,
    String actionId
  ) {
    List<FEC_Routing_Action_History__c> latestHistForRoute = [
      SELECT
        FEC_Routing_Action__c,
        FEC_IsReverted__c,
        FEC_Previous_Stage__c
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Routing_Action__c IN (:ROUTE_TO, :REVERT)
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 1
    ];
    Boolean routeByLatestRevertHistory =
      !latestHistForRoute.isEmpty() &&
      REVERT.equals(latestHistForRoute[0].FEC_Routing_Action__c) &&
      latestHistForRoute[0].FEC_IsReverted__c == true &&
      latestHistForRoute[0].FEC_Previous_Stage__c != null;

    if (routeByLatestRevertHistory) {
      return [
        SELECT
          Id,
          FEC_Previous_Stage__c,
          FEC_Previous_Stage__r.Name,
          FEC_Next_Stage__c,
          FEC_Next_Stage__r.Name,
          FEC_Action_Button__c,
          FEC_Action_Button__r.Name,
          FEC_Next_Queue__c,
          FEC_Team_User_Group__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :currentStageId
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__c = :actionId
          AND FEC_Next_Stage__c = :latestHistForRoute[0].FEC_Previous_Stage__c
        ORDER BY FEC_Team_User_Group__c, Id
      ];
    }

    return [
      SELECT
        Id,
        FEC_Previous_Stage__c,
        FEC_Previous_Stage__r.Name,
        FEC_Next_Stage__c,
        FEC_Next_Stage__r.Name,
        FEC_Action_Button__c,
        FEC_Action_Button__r.Name,
        FEC_Next_Queue__c,
        FEC_Team_User_Group__c
      FROM FEC_Stage_Change__c
      WHERE
        FEC_Previous_Stage__c = :currentStageId
        AND FEC_Active__c = TRUE
        AND FEC_Action_Button__c = :actionId
        AND FEC_IsReverted__c = FALSE
      ORDER BY FEC_Team_User_Group__c, Id
    ];
  }

  private static List<MoveNextStageItem> mapStageChangesToItems(
    String caseId,
    String canonicalAction,
    List<FEC_Stage_Change__c> changelst
  ) {
    List<MoveNextStageItem> items = new List<MoveNextStageItem>();
    if (changelst == null || changelst.isEmpty()) {
      return items;
    }

    Map<String, String> queueLabelByKey = resolveQueueLabelMap(changelst);
    Map<Id, RevertOwnerPreview> revertOwnerByNextStage = new Map<Id, RevertOwnerPreview>();

    for (FEC_Stage_Change__c row : changelst) {
      MoveNextStageItem item = new MoveNextStageItem();
      item.previousStage = row.FEC_Previous_Stage__r != null
        ? row.FEC_Previous_Stage__r.Name
        : null;
      item.nextStage = row.FEC_Next_Stage__r != null
        ? row.FEC_Next_Stage__r.Name
        : null;
      item.actionButtonName = row.FEC_Action_Button__r != null
        ? row.FEC_Action_Button__r.Name
        : null;

      if (REVERT.equals(canonicalAction) && row.FEC_Next_Stage__c != null) {
        if (!revertOwnerByNextStage.containsKey(row.FEC_Next_Stage__c)) {
          revertOwnerByNextStage.put(
            row.FEC_Next_Stage__c,
            resolveRevertOwnerPreview(caseId, row.FEC_Next_Stage__c)
          );
        }
        RevertOwnerPreview revertOwner = revertOwnerByNextStage.get(
          row.FEC_Next_Stage__c
        );
        if (revertOwner != null) {
          item.nextQueue = revertOwner.nextQueueLabel;
          item.teamUserGroup = revertOwner.teamUserGroup;
        }
      } else {
        item.teamUserGroup = row.FEC_Team_User_Group__c;
        item.nextQueue = resolveNextQueueLabelFromMap(
          row.FEC_Next_Queue__c,
          queueLabelByKey
        );
      }
      items.add(item);
    }
    return items;
  }

  /**
   * Revert: owner sau revert = người xử lý trước (history) — cùng thứ tự ưu tiên revert().
   * 1) History có FEC_Previous_Stage__c = next stage (stage đích).
   * 2) History Route to / Revert mới nhất — FEC_Perform_User__c.
   */
  private static RevertOwnerPreview resolveRevertOwnerPreview(
    String caseId,
    Id nextStageId
  ) {
    List<FEC_Routing_Action_History__c> histWhereNextWasPrevious = [
      SELECT
        FEC_Perform_User__c,
        FEC_Perform_User__r.Name,
        FEC_Perform_User__r.Email,
        FEC_Perform_User__r.FEC_User_Group__c
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Previous_Stage__c = :nextStageId
        AND FEC_Perform_User__c != NULL
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 1
    ];

    List<FEC_Routing_Action_History__c> latestHist = [
      SELECT
        FEC_Perform_User__c,
        FEC_Perform_User__r.Name,
        FEC_Perform_User__r.Email,
        FEC_Perform_User__r.FEC_User_Group__c
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Routing_Action__c IN (:ROUTE_TO, :REVERT)
        AND FEC_Perform_User__c != NULL
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 1
    ];

    Id ownerId;
    User performUser;
    if (
      !histWhereNextWasPrevious.isEmpty() &&
      histWhereNextWasPrevious[0].FEC_Perform_User__c != null
    ) {
      ownerId = histWhereNextWasPrevious[0].FEC_Perform_User__c;
      performUser = histWhereNextWasPrevious[0].FEC_Perform_User__r;
    } else if (
      !latestHist.isEmpty() &&
      latestHist[0].FEC_Perform_User__c != null
    ) {
      ownerId = latestHist[0].FEC_Perform_User__c;
      performUser = latestHist[0].FEC_Perform_User__r;
    } else {
      return null;
    }

    ownerId = applyFrontlineMainQueuePreview(ownerId);

    RevertOwnerPreview preview = new RevertOwnerPreview();
    preview.nextQueueLabel = FEC_CaseBusinessService.resolveRoutingHistoryOwnerLabel(
      ownerId,
      performUser != null ? performUser.Name : null
    );
    preview.teamUserGroup =
      performUser != null ? performUser.FEC_User_Group__c : null;
    return preview;
  }

  /** CS Frontline → map Owner sang main queue (giống FEC_CaseBusinessService.applyFrontlineMainQueueIfUserOwner). */
  private static Id applyFrontlineMainQueuePreview(Id ownerId) {
    if (ownerId == null) {
      return null;
    }
    if (ownerId.getSobjectType() == Group.SObjectType) {
      return ownerId;
    }
    if (ownerId.getSobjectType() != User.SObjectType) {
      return ownerId;
    }
    List<User> users = [
      SELECT FEC_User_Division_Group__c, FEC_Main_Queue__c
      FROM User
      WHERE Id = :ownerId
      LIMIT 1
    ];
    if (
      users.isEmpty() ||
      !FEC_CaseBusinessService.FRONT_LINE.equals(
        users[0].FEC_User_Division_Group__c
      ) ||
      String.isBlank(users[0].FEC_Main_Queue__c)
    ) {
      return ownerId;
    }
    List<Group> queues = [
      SELECT Id
      FROM Group
      WHERE
        Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
        AND DeveloperName = :users[0].FEC_Main_Queue__c
      LIMIT 1
    ];
    return queues.isEmpty() ? ownerId : queues[0].Id;
  }

  private class RevertOwnerPreview {
    public String nextQueueLabel;
    public String teamUserGroup;
  }

  private static Map<String, String> resolveQueueLabelMap(
    List<FEC_Stage_Change__c> changelst
  ) {
    Set<String> queueKeys = new Set<String>();
    for (FEC_Stage_Change__c row : changelst) {
      if (String.isNotBlank(row.FEC_Next_Queue__c)) {
        queueKeys.add(row.FEC_Next_Queue__c.trim());
      }
    }

    Map<String, String> labelByKey = new Map<String, String>();
    if (queueKeys.isEmpty()) {
      return labelByKey;
    }

    List<String> devNames = new List<String>();
    Set<Id> queueIds = new Set<Id>();
    for (String key : queueKeys) {
      try {
        Id qid = Id.valueOf(key);
        if (qid.getSobjectType() == Group.SObjectType) {
          queueIds.add(qid);
        }
      } catch (Exception e) {
        devNames.add(key);
      }
    }

    if (!devNames.isEmpty()) {
      for (Group g : [
        SELECT Name, DeveloperName
        FROM Group
        WHERE
          Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
          AND DeveloperName IN :devNames
      ]) {
        labelByKey.put(g.DeveloperName, g.Name);
      }
    }
    if (!queueIds.isEmpty()) {
      for (Group g : [
        SELECT Id, Name, DeveloperName
        FROM Group
        WHERE Id IN :queueIds AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
      ]) {
        labelByKey.put(String.valueOf(g.Id), g.Name);
        if (String.isNotBlank(g.DeveloperName)) {
          labelByKey.put(g.DeveloperName, g.Name);
        }
      }
    }
    return labelByKey;
  }

  private static String resolveNextQueueLabelFromMap(
    String nextQueueValue,
    Map<String, String> labelByKey
  ) {
    if (String.isBlank(nextQueueValue)) {
      return null;
    }
    String key = nextQueueValue.trim();
    if (labelByKey != null && labelByKey.containsKey(key)) {
      return labelByKey.get(key);
    }
    return key;
  }

  private static String normalizeActionCode(String actionCode) {
    if (String.isBlank(actionCode)) {
      return null;
    }
    String normalized = actionCode.trim().toLowerCase();
    if (normalized == 'route to' || normalized == 'route_to') {
      return ROUTE_TO;
    }
    if (normalized == 'revert') {
      return REVERT;
    }
    if (normalized == 'escalate') {
      return ESCALATE;
    }
    if (normalized == 'reject') {
      return REJECT;
    }
    if (normalized == 'resolve') {
      return RESOLVE;
    }
    if (normalized == 'transfer') {
      return TRANSFER;
    }
    if (normalized == 'update') {
      return ACTION_UPDATE;
    }
    return null;
  }

  /**
   * actionCode phải có trong danh sách getRoutingActionlst (theo stage + user group + revert).
   */
  private static RoutingAction resolveAllowedRoutingAction(
    String caseId,
    String canonicalActionCode
  ) {
    List<RoutingAction> allowed = getRoutingActionlstCore(caseId);
    if (allowed == null || allowed.isEmpty()) {
      return null;
    }
    for (RoutingAction act : allowed) {
      if (
        act != null &&
        String.isNotBlank(act.code) &&
        canonicalActionCode.equalsIgnoreCase(act.code.trim())
      ) {
        return act;
      }
    }
    return null;
  }

  private static Case loadCase(String caseId) {
    return loadCaseForMove(caseId);
  }

  private static Case loadCaseForMove(String caseId) {
    List<Case> rows = [
      SELECT
        Id,
        FEC_Product_Type__c,
        FEC_Category__c,
        FEC_SubCategory__c,
        FEC_SubCategory__r.FEC_Code__c,
        FEC_SubCode__c,
        FEC_SubCode__r.FEC_Code__c,
        FEC_Current_Case_Stage__c,
        FEC_Current_Case_Stage__r.Name,
        FEC_Customer_Type__c,
        FEC_Actual_Nature_of_Case__c,
        FEC_Is_Submited__c,
        FEC_Team__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      throw migrationInvalid('Case Id');
    }
    return rows[0];
  }

  private class StageContext {
    public Id stageId;
    public String stageName;
  }

  /**
   * Stage: ưu tiên FEC_Current_Case_Stage__c trên Case; không có thì default stage theo Nature of Case (NOC trên Case).
   */
  private static StageContext resolveStageContext(
    Case caseRow,
    List<String> rolelst
  ) {
    StageContext ctx = new StageContext();

    if (caseRow.FEC_Current_Case_Stage__c != null) {
      ctx.stageId = caseRow.FEC_Current_Case_Stage__c;
      ctx.stageName = caseRow.FEC_Current_Case_Stage__r != null
        ? caseRow.FEC_Current_Case_Stage__r.Name
        : null;
      if (String.isBlank(ctx.stageName)) {
        ctx.stageName = resolveStageName(ctx.stageId);
      }
      return ctx;
    }

    Id natureOfCaseId = resolveNatureOfCaseId(caseRow, rolelst);
    if (natureOfCaseId == null) {
      return ctx;
    }

    List<FEC_Case_Stage__c> defaultStages = [
      SELECT Id, Name
      FROM FEC_Case_Stage__c
      WHERE
        FEC_Nature_of_Cases__c = :natureOfCaseId
        AND FEC_Default_Stage__c = TRUE
        AND FEC_Active__c = TRUE
      LIMIT 1
    ];
    if (!defaultStages.isEmpty()) {
      ctx.stageId = defaultStages[0].Id;
      ctx.stageName = defaultStages[0].Name;
    }
    return ctx;
  }

  private static Id resolveNatureOfCaseId(Case caseRow, List<String> rolelst) {
    if (caseRow.FEC_Actual_Nature_of_Case__c != null) {
      return caseRow.FEC_Actual_Nature_of_Case__c;
    }

    if (
      caseRow.FEC_Product_Type__c == null ||
      caseRow.FEC_Category__c == null ||
      caseRow.FEC_SubCategory__c == null ||
      caseRow.FEC_SubCode__c == null ||
      String.isBlank(caseRow.FEC_Customer_Type__c)
    ) {
      return null;
    }

    List<String> additionalRolelst =
      FEC_NatureOfCaseUserGroupService.buildRoleListForIncludes(
        rolelst.isEmpty() ? null : rolelst[0]
      );

    String nocQuery =
      'SELECT Id FROM FEC_Nature_of_Case__c ' +
      'WHERE FEC_Product_Type__c = :productType ' +
      'AND FEC_Category__c = :category ' +
      'AND FEC_Sub_Category__c = :subCategory ' +
      'AND FEC_Sub_Code__c = :subCode ' +
      'AND FEC_Customer_Type__c = :customerType ' +
      'AND FEC_Business_Process__r.FEC_Active__c = TRUE ' +
      'AND FEC_Active__c = TRUE ' +
      FEC_NatureOfCaseUserGroupService.buildNatureOfCaseUserGroupFilterClause(
        rolelst,
        additionalRolelst
      ) +
      ' LIMIT 1';

    Map<String, Object> bindMap = new Map<String, Object>{
      'productType' => caseRow.FEC_Product_Type__c,
      'category' => caseRow.FEC_Category__c,
      'subCategory' => caseRow.FEC_SubCategory__c,
      'subCode' => caseRow.FEC_SubCode__c,
      'customerType' => caseRow.FEC_Customer_Type__c
    };

    List<SObject> nocRows = Database.queryWithBinds(
      nocQuery,
      bindMap,
      AccessLevel.USER_MODE
    );
    return nocRows.isEmpty() ? null : (Id) nocRows[0].get('Id');
  }

  private static List<String> resolveRoleListForCurrentUser() {
    List<String> rolelst = new List<String>();
    List<User> users = [
      SELECT FEC_User_Group__c
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    if (!users.isEmpty() && String.isNotBlank(users[0].FEC_User_Group__c)) {
      rolelst.add(users[0].FEC_User_Group__c);
      rolelst.addAll(
        FEC_NatureOfCaseUserGroupService.buildRoleListForIncludes(
          users[0].FEC_User_Group__c
        )
      );
    }
    return rolelst;
  }

  private static List<RoutingAction> queryRoutingActionsForStage(
    Id stageId,
    List<String> rolelst,
    Boolean isRevert
  ) {
    List<RoutingAction> routingActions = new List<RoutingAction>();
    if (stageId == null || rolelst == null || rolelst.isEmpty()) {
      return routingActions;
    }

    String stageIdEscaped = String.escapeSingleQuotes(String.valueOf(stageId));
    String roleIncludes = String.join(rolelst, '\',\'');

    List<FEC_Stage_Screen__c> screens = Database.query(
      'SELECT Id, FEC_Action_Button__c, ' +
        'FEC_Action_Button__r.Name, ' +
        'FEC_Action_Button__r.FEC_Type__c, ' +
        'FEC_Action_Button__r.FEC_Code__c, ' +
        'FEC_Custom_Action_Button_Label__c, ' +
        'FEC_Field_Type__c ' +
        'FROM FEC_Stage_Screen__c ' +
        'WHERE FEC_Action_Button__c != NULL ' +
        'AND FEC_Active__c = TRUE ' +
        'AND FEC_Action_Button__r.FEC_Type__c = \'' +
        ROUTING_ACTION_TYPE +
        '\' ' +
        'AND FEC_Case_Stage__c = \'' +
        stageIdEscaped +
        '\' ' +
        'AND FEC_User_Group__c INCLUDES (\'' +
        roleIncludes +
        '\')'
    );

    for (FEC_Stage_Screen__c item : screens) {
      if (!matchesFieldType(item.FEC_Field_Type__c, isRevert)) {
        continue;
      }
      routingActions.add(toRoutingAction(item));
    }
    return routingActions;
  }

  private static Boolean matchesFieldType(String fieldType, Boolean isRevert) {
    if (fieldType == 'All') {
      return true;
    }
    if (fieldType == 'New' && !isRevert) {
      return true;
    }
    if (fieldType == 'Revert' && isRevert) {
      return true;
    }
    return false;
  }

  private static RoutingAction toRoutingAction(FEC_Stage_Screen__c item) {
    String displayValue = String.isNotBlank(item.FEC_Custom_Action_Button_Label__c)
      ? item.FEC_Custom_Action_Button_Label__c
      : item.FEC_Action_Button__r.FEC_Code__c;
    String displayLabel = String.isNotBlank(item.FEC_Custom_Action_Button_Label__c)
      ? item.FEC_Custom_Action_Button_Label__c
      : item.FEC_Action_Button__r.Name;

    RoutingAction act = new RoutingAction();
    act.id = item.FEC_Action_Button__c;
    act.value = displayValue;
    act.label = displayLabel;
    act.code = item.FEC_Action_Button__r.FEC_Code__c;
    return act;
  }

  private static Boolean resolveIsRevertFromLatestHistory(String caseId) {
    List<FEC_Routing_Action_History__c> historylst = [
      SELECT FEC_Routing_Action__c
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Routing_Action__c IN (:ROUTE_TO, :REVERT)
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 1
    ];
    return !historylst.isEmpty() && REVERT.equals(historylst[0].FEC_Routing_Action__c);
  }

  private static String resolveStageName(Id stageId) {
    if (stageId == null) {
      return null;
    }
    List<FEC_Case_Stage__c> stages = [
      SELECT Name
      FROM FEC_Case_Stage__c
      WHERE Id = :stageId
      LIMIT 1
    ];
    return stages.isEmpty() ? null : stages[0].Name;
  }

  private static MigrationServiceException migrationInvalid(String fieldLabel) {
    return new MigrationServiceException(
      String.format(System.Label.FEC_MSG_Invalid, new List<String>{ fieldLabel })
    );
  }

  private static MigrationServiceException migrationNotFound(String entityLabel) {
    return new MigrationServiceException(
      String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ entityLabel })
    );
  }

  public class MigrationServiceException extends Exception {
  }

  public class RoutingActionListResult {
    public Boolean success { get; set; }
    public String message { get; set; }
    public List<RoutingAction> data { get; set; }

    public RoutingActionListResult() {
      success = false;
      data = new List<RoutingAction>();
    }
  }

  public class MoveNextStageListResult {
    public Boolean success { get; set; }
    public String message { get; set; }
    public List<MoveNextStageItem> data { get; set; }

    public MoveNextStageListResult() {
      success = false;
      data = new List<MoveNextStageItem>();
    }
  }

  public class RoutingAction {
    @AuraEnabled
    public String id { get; set; }
    @AuraEnabled
    public String value { get; set; }
    @AuraEnabled
    public String label { get; set; }
    @AuraEnabled
    public String code { get; set; }
  }

  public class MoveNextStageItem {
    @AuraEnabled
    public String previousStage { get; set; }
    @AuraEnabled
    public String nextStage { get; set; }
    @AuraEnabled
    public String actionButtonName { get; set; }
    @AuraEnabled
    public String nextQueue { get; set; }
    @AuraEnabled
    public String teamUserGroup { get; set; }
  }
}