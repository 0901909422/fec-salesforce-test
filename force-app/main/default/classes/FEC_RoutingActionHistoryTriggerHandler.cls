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
    // STEP 1: Collect all Case IDs from history records (null-safe)
    Set<Id> caseIds = new Set<Id>();
    for (FEC_Routing_Action_History__c history : newRecords) {
      if (history.FEC_Case__c != null) {
        caseIds.add(history.FEC_Case__c);
      }
    }

    if (caseIds.isEmpty()) {
      return;
    }

    // STEP 2: Bulk query Cases with FEC_Team__c (no SOQL in loop)
    Map<Id, Case> caseMap = new Map<Id, Case>(
      [SELECT Id, FEC_Team__c FROM Case WHERE Id IN :caseIds]
    );

    // STEP 3: Apply updateCaseTeams logic for each history record
    for (FEC_Routing_Action_History__c history : newRecords) {
      if (history.FEC_Case__c == null) {
        continue;
      }

      Case caseRecord = caseMap.get(history.FEC_Case__c);
      if (caseRecord == null) {
        continue;
      }

      updateCaseTeams(
        (Id) history.FEC_Original_User_Queue_ID__c,
        (Id) history.FEC_Updated_User_Queue_ID__c,
        caseRecord
      );
    }

    // STEP 4: Bulk update all modified Cases
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