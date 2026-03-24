public without sharing class FEC_RoutingActionHistoryTriggerHandler {
  private static Boolean isExecuting = false;

  public static void run() {
    FEC_RoutingActionHistoryTriggerHandler handler = new FEC_RoutingActionHistoryTriggerHandler();

    if (Trigger.isBefore && Trigger.isInsert) {
      List<FEC_Routing_Action_History__c> newRecords = (List<FEC_Routing_Action_History__c>) Trigger.new;
      handler.onBeforeInsert(newRecords);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
      List<FEC_Routing_Action_History__c> newRecords = (List<FEC_Routing_Action_History__c>) Trigger.new;
      Map<Id, FEC_Routing_Action_History__c> oldMap = (Map<Id, FEC_Routing_Action_History__c>) Trigger.oldMap;
      handler.onBeforeUpdate(newRecords, oldMap);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
      List<FEC_Routing_Action_History__c> newRecords = (List<FEC_Routing_Action_History__c>) Trigger.new;
      handler.onAfterInsert(newRecords);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
      List<FEC_Routing_Action_History__c> newRecords = (List<FEC_Routing_Action_History__c>) Trigger.new;
      Map<Id, FEC_Routing_Action_History__c> oldMap = (Map<Id, FEC_Routing_Action_History__c>) Trigger.oldMap;
      handler.onAfterUpdate(newRecords, oldMap);
    }
  }

  private void onBeforeInsert(List<FEC_Routing_Action_History__c> newRecords) {
    // TODO: Add before insert logic here
  }

  private void onBeforeUpdate(
    List<FEC_Routing_Action_History__c> newRecords,
    Map<Id, FEC_Routing_Action_History__c> oldMap
  ) {
    // TODO: Add before update logic here
  }

  private void onAfterInsert(List<FEC_Routing_Action_History__c> newRecords) {
    if (isExecuting) {
      return;
    }

    isExecuting = true;

    try {
      handleUpdateCaseTeamsOnInsert(newRecords);
    } finally {
      isExecuting = false;
    }
  }

  private void handleUpdateCaseTeamsOnInsert(
    List<FEC_Routing_Action_History__c> newRecords
  ) {
    List<FEC_Routing_Action_History__c> eligible = new List<FEC_Routing_Action_History__c>();
    for (FEC_Routing_Action_History__c history : newRecords) {
      if (history.FEC_Case__c == null || String.isBlank(history.FEC_Routing_Action__c)) {
        continue;
      }
      if (
        !FEC_ConstantCommon.ROUTING_ACTIONS_SYNC_CASE_TEAMS.contains(
          history.FEC_Routing_Action__c
        )
      ) {
        continue;
      }
      eligible.add(history);
    }

    if (eligible.isEmpty()) {
      return;
    }

    Set<Id> caseIds = new Set<Id>();
    for (FEC_Routing_Action_History__c history : eligible) {
      caseIds.add(history.FEC_Case__c);
    }

    Map<Id, Case> caseMap = new Map<Id, Case>(
      [
        SELECT Id, FEC_Team__c
        FROM Case
        WHERE Id IN :caseIds
      ]
    );

    Map<Id, List<FEC_Routing_Action_History__c>> byCase = new Map<Id, List<FEC_Routing_Action_History__c>>();
    for (FEC_Routing_Action_History__c history : eligible) {
      Id cid = history.FEC_Case__c;
      if (!byCase.containsKey(cid)) {
        byCase.put(cid, new List<FEC_Routing_Action_History__c>());
      }
      byCase.get(cid).add(history);
    }

    for (Id cid : byCase.keySet()) {
      List<FEC_Routing_Action_History__c> rows = byCase.get(cid);
      sortRoutingHistoriesByCreatedDateAsc(rows);
      Case caseRecord = caseMap.get(cid);
      if (caseRecord == null) {
        continue;
      }
      for (FEC_Routing_Action_History__c history : rows) {
        updateCaseTeams(
          parseOwnerIdField(history.FEC_Original_User_Queue_ID__c),
          parseOwnerIdField(history.FEC_Updated_User_Queue_ID__c),
          caseRecord
        );
      }
    }

    if (!caseMap.isEmpty()) {
      Database.update(caseMap.values(), AccessLevel.SYSTEM_MODE);
    }
  }

  /** Cùng transaction, nhiều history / Case: áp dụng theo thứ tự CreatedDate tăng dần. */
  private static void sortRoutingHistoriesByCreatedDateAsc(
    List<FEC_Routing_Action_History__c> lst
  ) {
    if (lst == null || lst.size() < 2) {
      return;
    }
    for (Integer i = 1; i < lst.size(); i++) {
      FEC_Routing_Action_History__c key = lst[i];
      Integer j = i - 1;
      while (j >= 0 && lst[j].CreatedDate > key.CreatedDate) {
        lst[j + 1] = lst[j];
        j--;
      }
      lst[j + 1] = key;
    }
  }

  private void onAfterUpdate(
    List<FEC_Routing_Action_History__c> newRecords,
    Map<Id, FEC_Routing_Action_History__c> oldMap
  ) {
    // Tránh recursive trigger
    if (isExecuting) {
      return;
    }

    isExecuting = true;

    try {
      // TODO: Add after update logic here
    } finally {
      isExecuting = false;
    }
  }

  /**
   * Pending-{Team} hoặc Pending-{Team1}_{Team2} từ bản ghi Route to (map Team qua ID Owner;
   * FEC_Original_User_Queue__c / FEC_Updated_User_Queue__c là nhãn, không dùng để map).
   */
  public static String buildPendingStatusFromRouteHistoryRow(
    FEC_Routing_Action_History__c history
  ) {
    if (history == null) {
      return FEC_ConstantCommon.CASE_STATUS_PENDING;
    }
    Id origId = parseOwnerIdField(history.FEC_Original_User_Queue_ID__c);
    Id updId = parseOwnerIdField(history.FEC_Updated_User_Queue_ID__c);
    return buildPendingStatusFromOwnerIds(origId, updId);
  }

  /** Hai Id Owner (User hoặc Queue) — Team từ User qua FEC_Main_Queue__c + FEC_Team_Queue__c; Queue trực tiếp. */
  public static String buildPendingStatusFromOwnerIds(Id originalOwnerId, Id updatedOwnerId) {
    Set<Id> idSet = new Set<Id>();
    if (originalOwnerId != null) {
      idSet.add(originalOwnerId);
    }
    if (updatedOwnerId != null) {
      idSet.add(updatedOwnerId);
    }
    if (idSet.isEmpty()) {
      return FEC_ConstantCommon.CASE_STATUS_PENDING;
    }
    Map<Id, String> teamMap = getTeamsFromIds(idSet);
    String tOrig = originalOwnerId != null ? teamMap.get(originalOwnerId) : null;
    String tUpd = updatedOwnerId != null ? teamMap.get(updatedOwnerId) : null;

    if (String.isBlank(tOrig) && String.isBlank(tUpd)) {
      return FEC_ConstantCommon.CASE_STATUS_PENDING;
    }
    if (String.isBlank(tOrig)) {
      return FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX + tUpd;
    }
    if (String.isBlank(tUpd)) {
      return FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX + tOrig;
    }
    if (tOrig.equals(tUpd)) {
      return FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX + tOrig;
    }
    return FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX +
      tOrig +
      FEC_ConstantCommon.DELIMITER_UNDERSCORE +
      tUpd;
  }

  private static Id parseOwnerIdField(String idText) {
    if (String.isBlank(idText)) {
      return null;
    }
    try {
      return Id.valueOf(idText.trim());
    } catch (Exception e) {
      return null;
    }
  }

  /**
   * B1: Gỡ Team map từ Owner cũ khỏi FEC_Team__c nếu giá trị đó đang có (Set.remove tương đương).
   * B2: Thêm Team map từ Owner mới nếu chưa có (Set.add không trùng).
   */
  public static void updateCaseTeams(
    Id originalUserQueueId,
    Id updatedUserQueueId,
    Case caseRecord
  ) {
    if (caseRecord == null) {
      return;
    }

    Set<Id> idSet = new Set<Id>();
    if (originalUserQueueId != null)
      idSet.add(originalUserQueueId);
    if (updatedUserQueueId != null)
      idSet.add(updatedUserQueueId);

    Map<Id, String> teamMap = getTeamsFromIds(idSet);
    String originalTeam = teamMap.get(originalUserQueueId);
    String updatedTeam = teamMap.get(updatedUserQueueId);

    String currentTeamsStr = caseRecord.FEC_Team__c;
    Set<String> teamSet = new Set<String>();
    if (String.isNotBlank(currentTeamsStr)) {
      for (
        String t : currentTeamsStr.split(FEC_ConstantCommon.DELIMITER_UNDERSCORE)
      ) {
        if (String.isNotBlank(t)) {
          teamSet.add(t.trim());
        }
      }
    }

    // Remove original team if exists
    if (String.isNotBlank(originalTeam)) {
      teamSet.remove(originalTeam);
    }

    // Add updated team if not exists
    if (String.isNotBlank(updatedTeam)) {
      teamSet.add(updatedTeam);
    }

    if (teamSet.isEmpty()) {
      caseRecord.FEC_Team__c = null;
    } else {
      caseRecord.FEC_Team__c = String.join(
        new List<String>(teamSet),
        FEC_ConstantCommon.DELIMITER_UNDERSCORE
      );
    }
  }

  /**
   * Map Team: User qua FEC_Main_Queue__c; Queue qua DeveloperName hoặc Name (nhãn UI)
   * vì FEC_Team_Queue__c.FEC_Queue_Name__c thường trùng một trong hai tuỳ cấu hình data.
   */
  private static Map<Id, String> getTeamsFromIds(Set<Id> targetIds) {
    Map<Id, String> resultMap = new Map<Id, String>();
    if (targetIds == null || targetIds.isEmpty()) {
      return resultMap;
    }

    Set<Id> userIds = new Set<Id>();
    Set<Id> groupIds = new Set<Id>();

    for (Id tid : targetIds) {
      if (tid == null)
        continue;
      String sObjName = tid.getSObjectType().getDescribe().getName();
      if (sObjName == FEC_ConstantCommon.SOBJECT_USER) {
        userIds.add(tid);
      } else if (sObjName == FEC_ConstantCommon.SOBJECT_GROUP) {
        groupIds.add(tid);
      }
    }

    Map<Id, String> userIdToMainQueue = new Map<Id, String>();
    if (!userIds.isEmpty()) {
      for (User u : [
        SELECT Id, FEC_Main_Queue__c
        FROM User
        WHERE Id IN :userIds
      ]) {
        if (String.isNotBlank(u.FEC_Main_Queue__c)) {
          userIdToMainQueue.put(u.Id, u.FEC_Main_Queue__c);
        }
      }
    }

    Map<Id, String> groupIdToDeveloperName = new Map<Id, String>();
    Map<Id, String> groupIdToLabelName = new Map<Id, String>();
    if (!groupIds.isEmpty()) {
      for (Group g : [
        SELECT Id, DeveloperName, Name
        FROM Group
        WHERE Id IN :groupIds AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
      ]) {
        if (String.isNotBlank(g.DeveloperName)) {
          groupIdToDeveloperName.put(g.Id, g.DeveloperName);
        }
        if (String.isNotBlank(g.Name)) {
          groupIdToLabelName.put(g.Id, g.Name);
        }
      }
    }

    Set<String> queueNameKeys = new Set<String>();
    queueNameKeys.addAll(userIdToMainQueue.values());
    queueNameKeys.addAll(groupIdToDeveloperName.values());
    queueNameKeys.addAll(groupIdToLabelName.values());

    if (queueNameKeys.isEmpty()) {
      return resultMap;
    }

    Map<String, String> queueToTeamMap = new Map<String, String>();
    for (FEC_Team_Queue__c tq : [
      SELECT FEC_Queue_Name__c, FEC_Team__c
      FROM FEC_Team_Queue__c
      WHERE FEC_Queue_Name__c IN :queueNameKeys
    ]) {
      if (String.isNotBlank(tq.FEC_Queue_Name__c)) {
        queueToTeamMap.put(tq.FEC_Queue_Name__c, tq.FEC_Team__c);
      }
    }

    for (Id tid : targetIds) {
      if (tid == null)
        continue;
      String sObjName = tid.getSObjectType().getDescribe().getName();
      if (sObjName == FEC_ConstantCommon.SOBJECT_USER) {
        String mainQ = userIdToMainQueue.get(tid);
        if (
          String.isNotBlank(mainQ) && queueToTeamMap.containsKey(mainQ)
        ) {
          resultMap.put(tid, queueToTeamMap.get(mainQ));
        }
      } else if (sObjName == FEC_ConstantCommon.SOBJECT_GROUP) {
        String dev = groupIdToDeveloperName.get(tid);
        String label = groupIdToLabelName.get(tid);
        String team = null;
        if (String.isNotBlank(dev) && queueToTeamMap.containsKey(dev)) {
          team = queueToTeamMap.get(dev);
        } else if (
          String.isNotBlank(label) && queueToTeamMap.containsKey(label)
        ) {
          team = queueToTeamMap.get(label);
        }
        if (String.isNotBlank(team)) {
          resultMap.put(tid, team);
        }
      }
    }

    return resultMap;
  }
}