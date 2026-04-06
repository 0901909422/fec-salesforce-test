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
      FEC_CaseManagerListService.applyAfterRoutingHistoryInsert(newRecords);
    } finally {
      isExecuting = false;
    }
  }

  private void handleUpdateCaseTeamsOnInsert(
    List<FEC_Routing_Action_History__c> newRecords
  ) {
    Set<Id> caseIds = new Set<Id>();
    for (FEC_Routing_Action_History__c history : newRecords) {
      if (history.FEC_Case__c != null) {
        caseIds.add(history.FEC_Case__c);
      }
    }

    if (caseIds.isEmpty()) {
      return;
    }

    Map<Id, Case> caseMap = new Map<Id, Case>(
      [
        SELECT Id, FEC_Team__c
        FROM Case
        WHERE Id IN :caseIds
      ]
    );

    for (FEC_Routing_Action_History__c history : newRecords) {
      if (history.FEC_Case__c == null) {
        continue;
      }

      Case caseRecord = caseMap.get(history.FEC_Case__c);
      if (caseRecord == null) {
        continue;
      }

      updateCaseTeams(
        parseOwnerIdField(history.FEC_Original_User_Queue_ID__c),
        parseOwnerIdField(history.FEC_Updated_User_Queue_ID__c),
        caseRecord
      );
    }

    if (!caseMap.isEmpty()) {
      Database.update(caseMap.values(), AccessLevel.SYSTEM_MODE);
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
   * Pending-{Team} hoặc Pending-{Team1}_{Team2} từ một dòng history (Route to / Change Owner;
   * map Team qua ID Owner; FEC_Original_User_Queue__c / FEC_Updated_User_Queue__c là nhãn).
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

  private static Map<Id, String> getTeamsFromIds(Set<Id> targetIds) {
    Map<Id, String> resultMap = new Map<Id, String>();
    if (targetIds == null || targetIds.isEmpty()) {
      return resultMap;
    }

    Map<Id, String> idToQueueNameMap = new Map<Id, String>();
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

    if (!userIds.isEmpty()) {
      for (User u : [
        SELECT Id, FEC_Main_Queue__c
        FROM User
        WHERE Id IN :userIds
      ]) {
        if (String.isNotBlank(u.FEC_Main_Queue__c)) {
          idToQueueNameMap.put(u.Id, u.FEC_Main_Queue__c);
        }
      }
    }

    if (!groupIds.isEmpty()) {
      for (Group g : [
        SELECT Id, DeveloperName
        FROM Group
        WHERE Id IN :groupIds AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
      ]) {
        idToQueueNameMap.put(g.Id, g.DeveloperName);
      }
    }

    if (idToQueueNameMap.isEmpty()) {
      return resultMap;
    }

    Set<String> queueNames = new Set<String>(idToQueueNameMap.values());
    Map<String, String> queueToTeamMap = new Map<String, String>();
    for (FEC_Team_Queue__c tq : [
      SELECT FEC_Queue_Name__c, FEC_Team__c
      FROM FEC_Team_Queue__c
      WHERE FEC_Queue_Name__c IN :queueNames
    ]) {
      queueToTeamMap.put(tq.FEC_Queue_Name__c, tq.FEC_Team__c);
    }

    for (Id tid : targetIds) {
      if (idToQueueNameMap.containsKey(tid)) {
        String qName = idToQueueNameMap.get(tid);
        if (queueToTeamMap.containsKey(qName)) {
          resultMap.put(tid, queueToTeamMap.get(qName));
        }
      }
    }

    return resultMap;
  }
}