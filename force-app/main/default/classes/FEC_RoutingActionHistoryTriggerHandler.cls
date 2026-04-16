public without sharing class FEC_RoutingActionHistoryTriggerHandler {
  public class RoutingActionHistoryException extends Exception {}
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
      sendNotificationEmails(newRecords);
    } catch (Exception e) {
      throw new RoutingActionHistoryException('Error processing Routing Action History after insert: ' + e.getMessage());
    } finally {
      isExecuting = false;
    }
  }

  public static void sendNotificationEmails(List<FEC_Routing_Action_History__c> newList) {
    System.debug('--- [sendNotificationEmails] routing action history START');
    if (newList == null || newList.isEmpty()) return;   
    Set<Id> caseIds = new Set<Id>();
    for (FEC_Routing_Action_History__c history : newList) {
        if (history.FEC_Case__c != null) caseIds.add(history.FEC_Case__c);
    }
    if (caseIds.isEmpty()) return;

    // 1. Lấy Sender Email từ Metadata
    String senderEmail = '';
    FEC_System_Config__c systemConfig = FEC_System_Config__c.getOrgDefaults();
    if (String.isNotBlank(systemConfig?.FEC_Sender_Email__c)) {
        senderEmail = systemConfig.FEC_Sender_Email__c;
    }

    // 2. Query thông tin Case
    Map<Id, Case> caseMap = new Map<Id, Case>([
        SELECT Id, FEC_Customer_Type__c, FEC_Product_Type__c, FEC_Category__c, 
               FEC_SubCategory__c, FEC_SubCode__c, FEC_Current_Case_Stage__c,
               FEC_Stage_Name__c,
               FEC_Account_or_Contract__r.FEC_Customer_Type__c, 
               FEC_Account_or_Contract__r.FEC_Email__c,
               FEC_Interaction__r.FEC_Interaction_Email__c, 
               FEC_Case_Email__c
        FROM Case WHERE Id IN :caseIds
    ]);

    // 3. Query các Notification đang active và lấy thêm trường Template ID
    List<FEC_Notification__c> activeNotifications = [
        SELECT Id, Name, FEC_Current_Status__c, FEC_Changed_Status__c, FEC_Target_Group__c, 
               FEC_Customer_Type__c, FEC_Product_Type__c, FEC_Category__c, 
               FEC_SubCategory__c, FEC_SubCode__c, FEC_Case_Stage__c,
               FEC_Notification_Channel__r.Name,
               FEC_Notification_Template__c
        FROM FEC_Notification__c
        WHERE FEC_Notification_Status__c = true 
          AND FEC_Notification_Channel__r.Name = :FEC_ConstantCommon.EMAIL
          AND FEC_Target_Group__c = :FEC_ConstantCommon.TARGET_GROUP_CUSTOMER
    ];

    // Cấu trúc để lưu vết các bản ghi cần gửi mail và tập hợp ID Template
    Map<FEC_Routing_Action_History__c, FEC_Notification__c> historyToNotifMap = new Map<FEC_Routing_Action_History__c, FEC_Notification__c>();
    Set<Id> templateIds = new Set<Id>();

    if (activeNotifications.isEmpty()) return;

    for (FEC_Routing_Action_History__c history : newList) {
        if (history.FEC_Case__c == null || !caseMap.containsKey(history.FEC_Case__c)) continue;
        Case relatedCase = caseMap.get(history.FEC_Case__c);

        for (FEC_Notification__c notif : activeNotifications) {
            // Logic so khớp điều kiện (Giữ nguyên logic cũ của bạn)
            Boolean isMatch = (String.isNotBlank(history.FEC_Current_Status__c) && notif.FEC_Current_Status__c?.contains(history.FEC_Current_Status__c?.replaceAll(FEC_ConstantCommon.PATTERN_CLEAN_TEXT, '')) == true)
                && (String.isNotBlank(history.FEC_Changed_Status__c) && notif.FEC_Changed_Status__c?.contains(history.FEC_Changed_Status__c?.replaceAll(FEC_ConstantCommon.PATTERN_CLEAN_TEXT, '')) == true)
                && (notif.FEC_Customer_Type__c == relatedCase.FEC_Customer_Type__c)
                && (notif.FEC_Product_Type__c == relatedCase.FEC_Product_Type__c)
                && (notif.FEC_Category__c == relatedCase.FEC_Category__c)
                && (notif.FEC_SubCategory__c == relatedCase.FEC_SubCategory__c)
                && (notif.FEC_SubCode__c == relatedCase.FEC_SubCode__c);
            // if (notif.Id == 'a088500000K2Nl0AAF') {
            //     System.debug('--- [sendNotificationEmails] history.FEC_Current_Status__c.replaceAll(FEC_ConstantCommon.PATTERN_CLEAN_TEXT, ""): ' + history.FEC_Current_Status__c?.replaceAll(FEC_ConstantCommon.PATTERN_CLEAN_TEXT, ''));
            //     System.debug('--- [sendNotificationEmails] notif.FEC_Current_Status__c: ' + notif.FEC_Current_Status__c);
            //     System.debug('--- [sendNotificationEmails] history.FEC_Changed_Status__c.replaceAll(FEC_ConstantCommon.PATTERN_CLEAN_TEXT, ""): ' + history.FEC_Changed_Status__c.replaceAll(FEC_ConstantCommon.PATTERN_CLEAN_TEXT, ''));
            //     System.debug('--- [sendNotificationEmails] notif.FEC_Changed_Status__c: ' + notif.FEC_Changed_Status__c);
            //     System.debug('--- [sendNotificationEmails] (notif.FEC_Customer_Type__c == relatedCase.FEC_Customer_Type__c): ' + (notif.FEC_Customer_Type__c == relatedCase.FEC_Customer_Type__c));
            //     System.debug('--- [sendNotificationEmails] (notif.FEC_Product_Type__c == relatedCase.FEC_Product_Type__c): ' + (notif.FEC_Product_Type__c == relatedCase.FEC_Product_Type__c));
            //     System.debug('--- [sendNotificationEmails] (notif.FEC_Category__c == relatedCase.FEC_Category__c): ' + (notif.FEC_Category__c == relatedCase.FEC_Category__c));
            //     System.debug('--- [sendNotificationEmails] (notif.FEC_SubCategory__c == relatedCase.FEC_SubCategory__c): ' + (notif.FEC_SubCategory__c == relatedCase.FEC_SubCategory__c));
            //     System.debug('--- [sendNotificationEmails] (notif.FEC_SubCode__c == relatedCase.FEC_SubCode__c): ' + (notif.FEC_SubCode__c == relatedCase.FEC_SubCode__c));
            // }
            
            if (isMatch) {
                historyToNotifMap.put(history, notif);
                if (notif.FEC_Notification_Template__c != null) {
                    templateIds.add(notif.FEC_Notification_Template__c);
                }
                break; 
            }
        }
    }

    if (historyToNotifMap.isEmpty()) return;

    // 4. Query toàn bộ nội dung Template 1 lần duy nhất (Bulk SOQL)
    Map<Id, FEC_Template__c> templateMap = new Map<Id, FEC_Template__c>();
    if (!templateIds.isEmpty()) {
        templateMap = new Map<Id, FEC_Template__c>([
            SELECT Id, Name, FEC_Subject_Line__c, FEC_Body__c 
            FROM FEC_Template__c 
            WHERE Id IN :templateIds
        ]);
    }

    // 5. Chuẩn bị danh sách email để gửi hàng loạt
    List<FEC_Notification.EmailInfo> listEmailsToProcess = new List<FEC_Notification.EmailInfo>();
    List<FEC_Notification.RoutingEmailHistoryInput> routingHistories = new List<FEC_Notification.RoutingEmailHistoryInput>();

    for (FEC_Routing_Action_History__c history : historyToNotifMap.keySet()) {
        FEC_Notification__c matchedNotification = historyToNotifMap.get(history);
        Case relatedCase = caseMap.get(history.FEC_Case__c);
        
        // Xác định địa chỉ email nhận
        String targetEmailAddress = null;
        String accType = relatedCase.FEC_Account_or_Contract__r?.FEC_Customer_Type__c;
        if (accType == FEC_ConstantCommon.CUSTOMER_HISTORY_EXISTING_CUSTOMER) {
            targetEmailAddress = relatedCase.FEC_Account_or_Contract__r?.FEC_Email__c;
        } else {
            targetEmailAddress = String.isNotBlank(relatedCase.FEC_Interaction__r?.FEC_Interaction_Email__c) 
                ? relatedCase.FEC_Interaction__r.FEC_Interaction_Email__c 
                : relatedCase.FEC_Case_Email__c;
        }

        // Lấy Template tương ứng từ Map
        FEC_Template__c template = templateMap.get(matchedNotification.FEC_Notification_Template__c);

        if (String.isNotBlank(targetEmailAddress) && template != null) {
            listEmailsToProcess.add(new FEC_Notification.EmailInfo(
                relatedCase.Id,
                targetEmailAddress,
                String.isNotBlank(template.FEC_Subject_Line__c) ? template.FEC_Subject_Line__c : 'Notification',
                '',
                template.FEC_Body__c,
                ''
            ));

            FEC_Notification.RoutingEmailHistoryInput hi = new FEC_Notification.RoutingEmailHistoryInput();
            hi.caseId = relatedCase.Id;
            hi.notificationRuleId = matchedNotification.Id;
            hi.stageName = relatedCase.FEC_Stage_Name__c;
            hi.templateDisplayName = template.Name;
            hi.channelName =
                (matchedNotification.FEC_Notification_Channel__r != null &&
                String.isNotBlank(matchedNotification.FEC_Notification_Channel__r.Name))
                    ? matchedNotification.FEC_Notification_Channel__r.Name
                    : FEC_ConstantCommon.EMAIL;
            hi.targetGroup = matchedNotification.FEC_Target_Group__c;
            hi.notificationRuleName = matchedNotification.Name;
            routingHistories.add(hi);
        }
    }

    // 6. Gửi hàng loạt qua hàm Bulk của FEC_Notification
    if (!listEmailsToProcess.isEmpty()) {
        FEC_Notification.executeSendEmailsBulk(listEmailsToProcess, senderEmail, routingHistories);
        System.debug('--- [sendNotificationEmails] Bulk process completed for ' + listEmailsToProcess.size() + ' records.');
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
        caseRecord,
        history
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
    // Change Owner (UI/API): chỉ hiển thị team của owner mới — không ghép Pending-TeamOld_TeamNew
    if (history.FEC_Routing_Action__c == FEC_ConstantCommon.FEC_ROUTING_ACTION_CHANGE_OWNER) {
      if (updId == null) {
        return FEC_ConstantCommon.CASE_STATUS_PENDING;
      }
      Map<Id, String> teamMap = getTeamsFromIds(new Set<Id>{ updId });
      String tUpd = teamMap.get(updId);
      if (String.isBlank(tUpd)) {
        return FEC_ConstantCommon.CASE_STATUS_PENDING;
      }
      return FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX + tUpd;
    }
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
    Case caseRecord,
    FEC_Routing_Action_History__c history
  ) {
    if (caseRecord == null || history == null) {
      return;
    }

    if (
      history.FEC_Routing_Action__c == FEC_CaseBusinessService.CANCEL ||
      history.FEC_Routing_Action__c == FEC_CaseBusinessService.REJECT ||
      history.FEC_Routing_Action__c == FEC_CaseBusinessService.RESOLVE
    ) {
      caseRecord.FEC_Team__c = null;
      return;
    }

    Set<Id> idSet = new Set<Id>();
    if (originalUserQueueId != null)
      idSet.add(originalUserQueueId);
    if (updatedUserQueueId != null)
      idSet.add(updatedUserQueueId);

    Map<Id, String> teamMap = getTeamsFromIds(idSet);
    Map<String, String> decisionToTeamMap = FEC_ConstantCommon.decisionToTeamMap;
    String originalTeam = teamMap.get(originalUserQueueId);
    if (String.isNotBlank(originalTeam)) {
        // Xóa sạch khoảng trắng dư thừa, ký tự invisible, newline...
        originalTeam = originalTeam.replaceAll('\\W+', '').trim();
    }

    if (history.FEC_Routing_Action__c == FEC_CaseBusinessService.REOPEN) {
      caseRecord.FEC_Team__c = originalTeam;
      return;
    }
    // Change Owner: gán FEC_Team__c = team của owner mới (thay thế toàn bộ), không merge với team cũ trên Case
    if (history.FEC_Routing_Action__c == FEC_CaseBusinessService.CHANGE_OWNER) {
      String updatedTeamOnly = teamMap.get(updatedUserQueueId);
      if (String.isNotBlank(updatedTeamOnly)) {
        caseRecord.FEC_Team__c = FEC_CommonUltils.sortTeamField(updatedTeamOnly);
      } else {
        caseRecord.FEC_Team__c = null;
      }
      return;
    }
    String updatedTeam = history.FEC_Routing_Action__c == FEC_CaseBusinessService.UPDATEACTION ? decisionToTeamMap.get(history.FEC_Decision__c) : teamMap.get(updatedUserQueueId)?.replaceAll('\\W+', '').trim();

    String currentTeamsStr = caseRecord.FEC_Team__c;
    Set<String> teamSet = new Set<String>();
    if (String.isNotBlank(currentTeamsStr)) {
      for (
        String t : currentTeamsStr.split(FEC_ConstantCommon.DELIMITER_UNDERSCORE)
      ) {
        if (String.isNotBlank(t)) {
          teamSet.add(t.replaceAll('\\W+', '').trim());
        }
      }
    }
    if (teamSet.contains(originalTeam)) {
      teamSet.remove(originalTeam);
    }

    // Add updated team if not exists
    if (String.isNotBlank(updatedTeam)) {
      teamSet.add(updatedTeam);
    }

    if (teamSet.isEmpty()) {
      caseRecord.FEC_Team__c = null;
    } else {
      caseRecord.FEC_Team__c = FEC_CommonUltils.sortTeamField(String.join(
        new List<String>(teamSet),
        FEC_ConstantCommon.DELIMITER_UNDERSCORE
      ));
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