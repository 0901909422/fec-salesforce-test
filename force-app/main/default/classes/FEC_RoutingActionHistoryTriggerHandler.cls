public without sharing class FEC_RoutingActionHistoryTriggerHandler {
  public class RoutingActionHistoryException extends Exception {}
  private static Boolean isExecuting = false;
  // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
  private static Map<Id, Case> txnCaseTeamRowById = new Map<Id, Case>();

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
    FEC_RoutingHistTatSvc.applyBeforeSave(newRecords, null);
  }

  private void onBeforeUpdate(
    List<FEC_Routing_Action_History__c> newRecords,
    Map<Id, FEC_Routing_Action_History__c> oldMap
  ) {
    FEC_RoutingHistTatSvc.applyBeforeSave(newRecords, oldMap);
  }

  private void onAfterInsert(List<FEC_Routing_Action_History__c> newRecords) {
    if (isExecuting) {
      return;
    }

    isExecuting = true;

    try {
      handleUpdateCaseTeamsOnInsert(newRecords);
      FEC_CaseManagerListService.applyAfterRoutingHistoryInsert(newRecords);
      // SOQL 101: TAT Full Process enqueue Queueable — không sync Case đồng bộ trong trigger.
      FEC_RoutingHistTatSvc.queueCaseFullProcessTatAfterSave(newRecords);
      FEC_RoutingHistTatSvc.commitPendingCaseFullProcessTatSync();
      sendNotificationEmails(newRecords);
    } catch (Exception e) {
      throw new RoutingActionHistoryException('Error processing Routing Action History after insert: ' + e.getMessage());
    } finally {
      isExecuting = false;
    }
  }

  public static void sendNotificationEmails(List<FEC_Routing_Action_History__c> newList) {
    if (newList == null || newList.isEmpty()) return;
    if (FEC_BatchCaseHandlingImportService.isBatchImportApplyInProgress()) {
      return;
    }
    if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
      return;
    }
    System.enqueueJob(new FEC_SendNotificationEmailsQueueable(newList));
  }

  public static void processNotificationEmails(List<FEC_Routing_Action_History__c> newList) {
     //System.debug('--- [processNotificationEmails] routing action history START');
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
               FEC_SubCategory__c, FEC_SubCode__c, FEC_Case_Stage__c
               // FEC_Notification_Channel__r.Name,
               // FEC_Notification_Template__c
        FROM FEC_Notification__c
        WHERE FEC_Notification_Status__c = true 
          // AND FEC_Notification_Channel__r.Name = :FEC_ConstantCommon.EMAIL
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
                && FEC_CommonUltils.notificationCustomerTypeMatchesCase(notif.FEC_Customer_Type__c, relatedCase.FEC_Customer_Type__c)
                && (notif.FEC_Product_Type__c == relatedCase.FEC_Product_Type__c)
                && (notif.FEC_Category__c == relatedCase.FEC_Category__c)
                && (notif.FEC_SubCategory__c == relatedCase.FEC_SubCategory__c)
                && (notif.FEC_SubCode__c == relatedCase.FEC_SubCode__c);
            //  if (notif.Name == 'TestAutoKHv1_14/4') {
            //     System.debug('--- [sendNotificationEmails] notif name: ' + notif.Name);
            //     System.debug('--- [sendNotificationEmails] history.FEC_Current_Status__c.replaceAll(FEC_ConstantCommon.PATTERN_CLEAN_TEXT, ""): ' + history.FEC_Current_Status__c?.replaceAll(FEC_ConstantCommon.PATTERN_CLEAN_TEXT, ''));
            //     System.debug('--- [sendNotificationEmails] notif.FEC_Current_Status__c: ' + notif?.FEC_Current_Status__c);
            //     System.debug('--- [sendNotificationEmails] history.FEC_Changed_Status__c: ' + history.FEC_Changed_Status__c);
            //     System.debug('--- [sendNotificationEmails] history.FEC_Changed_Status__c.replaceAll(FEC_ConstantCommon.PATTERN_CLEAN_TEXT, ""): ' + history.FEC_Changed_Status__c?.replaceAll(FEC_ConstantCommon.PATTERN_CLEAN_TEXT, ''));
            //     System.debug('--- [sendNotificationEmails] notif.FEC_Changed_Status__c: ' + notif?.FEC_Changed_Status__c);
            //     System.debug('--- [sendNotificationEmails] (notif.FEC_Customer_Type__c == relatedCase.FEC_Customer_Type__c): ' + (notif?.FEC_Customer_Type__c == relatedCase?.FEC_Customer_Type__c));
            //     System.debug('--- [sendNotificationEmails] (notif.FEC_Product_Type__c == relatedCase.FEC_Product_Type__c): ' + (notif?.FEC_Product_Type__c == relatedCase?.FEC_Product_Type__c));
            //     System.debug('--- [sendNotificationEmails] (notif.FEC_Category__c == relatedCase.FEC_Category__c): ' + (notif?.FEC_Category__c == relatedCase?.FEC_Category__c));
            //     System.debug('--- [sendNotificationEmails] (notif.FEC_SubCategory__c == relatedCase.FEC_SubCategory__c): ' + (notif?.FEC_SubCategory__c == relatedCase?.FEC_SubCategory__c));
            //     System.debug('--- [sendNotificationEmails] (notif.FEC_SubCode__c == relatedCase.FEC_SubCode__c): ' + (notif?.FEC_SubCode__c == relatedCase?.FEC_SubCode__c));
            //     System.debug('--- [sendNotificationEmails] isMatch: ' + isMatch);
            // }
            
            if (isMatch) {
                historyToNotifMap.put(history, notif);
                // if (notif.FEC_Notification_Template__c != null) {
                //     templateIds.add(notif.FEC_Notification_Template__c);
                // }
                break; 
            }
        }
    }

    if (historyToNotifMap.isEmpty()) return;

    // 4. Query toàn bộ nội dung Template 1 lần duy nhất (Bulk SOQL)
    Map<Id, FEC_Template__c> templateMap = new Map<Id, FEC_Template__c>();
    if (!templateIds.isEmpty()) {
        templateMap = new Map<Id, FEC_Template__c>([
            SELECT Id, Name, FEC_Subject_Line__c, FEC_Body__c, FEC_Enhanced_Letterhead__c, FEC_Enhanced_Letterhead__r.FEC_Header__c, FEC_Enhanced_Letterhead__r.FEC_Footer__c
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
        // FEC_Template__c template = templateMap.get(matchedNotification.FEC_Notification_Template__c);

         //System.debug('--- [sendNotificationEmails] targetEmailAddress: ' + targetEmailAddress);
         //System.debug('--- [sendNotificationEmails] template: ' + template);
        // if (String.isNotBlank(targetEmailAddress) && template != null) {
        //     listEmailsToProcess.add(new FEC_Notification.EmailInfo(
        //         relatedCase.Id,
        //         targetEmailAddress,
        //         String.isNotBlank(template.FEC_Subject_Line__c) ? template.FEC_Subject_Line__c : 'Notification',
        //         template.FEC_Enhanced_Letterhead__r?.FEC_Header__c,
        //         template.FEC_Body__c,
        //         template.FEC_Enhanced_Letterhead__r?.FEC_Footer__c,
        //         template.Id
        //     ));

        //     FEC_Notification.RoutingEmailHistoryInput hi = new FEC_Notification.RoutingEmailHistoryInput();
        //     hi.caseId = relatedCase.Id;
        //     hi.notificationRuleId = matchedNotification.Id;
        //     hi.stageName = relatedCase.FEC_Stage_Name__c;
        //     hi.templateDisplayName = template.Name;
        //     // hi.channelName =
        //     //     (matchedNotification.FEC_Notification_Channel__r != null &&
        //     //     String.isNotBlank(matchedNotification.FEC_Notification_Channel__r.Name))
        //     //         ? matchedNotification.FEC_Notification_Channel__r.Name
        //     //         : FEC_ConstantCommon.EMAIL;
        //     hi.channelName = FEC_ConstantCommon.EMAIL;
        //     hi.targetGroup = matchedNotification.FEC_Target_Group__c;
        //     hi.notificationRuleName = matchedNotification.Name;
        //     routingHistories.add(hi);
        // }
    }

    // 6. Gửi hàng loạt qua hàm Bulk của FEC_Notification
    if (!listEmailsToProcess.isEmpty()) {
        FEC_Notification.executeSendEmailsBulk(listEmailsToProcess, senderEmail, routingHistories);
        // System.debug('--- [sendNotificationEmails] Bulk process completed for ' + listEmailsToProcess.size() + ' records.');
    }
  }

  // SOQL 101: bulk merge FEC_Team__c — cache Case/owner/assignment, lookup qua FEC_OwnerTeamLookupSvc.
  private void handleUpdateCaseTeamsOnInsert(
    List<FEC_Routing_Action_History__c> newRecords
  ) {
    Map<Id, Case> caseById = loadCachedCaseTeamRows(newRecords);
    if (caseById.isEmpty()) {
      return;
    }

    List<FEC_Routing_Action_History__c> caseLevel = new List<FEC_Routing_Action_History__c>();
    List<FEC_Routing_Action_History__c> assignmentLevel = new List<FEC_Routing_Action_History__c>();
    // SOQL 101: tách Route to (case) vs bulk Assignment RAH — xử lý team khác nhau.
    partitionHistoriesByAssignment(newRecords, caseLevel, assignmentLevel);

    Map<Id, FEC_Assignment__c> assignmentById = loadAssignmentsForHistories(assignmentLevel);
    Set<Id> ownerIds = new Set<Id>();
    ownerIds.addAll(collectOwnerIdsFromRouteHistory(caseLevel, true));
    // SOQL 101: assignment RAH chỉ lookup original owner; updated team từ FEC_Assignment__c.FEC_Team__c.
    ownerIds.addAll(collectOwnerIdsFromRouteHistory(assignmentLevel, false));
    Map<Id, String> teamByOwnerId = FEC_OwnerTeamLookupSvc.getByOwnerIds(ownerIds);

    for (FEC_Routing_Action_History__c history : caseLevel) {
      applyCaseTeamFromHistory(history, caseById, teamByOwnerId, null);
    }
    for (FEC_Routing_Action_History__c history : assignmentLevel) {
      FEC_Assignment__c asg = assignmentById.get(history.FEC_Assignment__c);
      applyCaseTeamFromHistory(
        history,
        caseById,
        teamByOwnerId,
        asg != null ? asg.FEC_Team__c : null
      );
    }

    // SOQL 101: isSystemUpdate — Case trigger bỏ qua syncChannel/participants khi update FEC_Team__c.
    Boolean priorSystem = FEC_CaseTriggerHandler.isSystemUpdate;
    FEC_CaseTriggerHandler.isSystemUpdate = true;
    try {
      Database.update(caseById.values(), AccessLevel.SYSTEM_MODE);
    } finally {
      FEC_CaseTriggerHandler.isSystemUpdate = priorSystem;
    }
  }

  // SOQL 101: mỗi Case Id chỉ SELECT FEC_Team__c một lần/transaction.
  private static Map<Id, Case> loadCachedCaseTeamRows(
    List<FEC_Routing_Action_History__c> histories
  ) {
    Set<Id> caseIds = new Set<Id>();
    for (FEC_Routing_Action_History__c history : histories) {
      if (history.FEC_Case__c != null) {
        caseIds.add(history.FEC_Case__c);
      }
    }
    Set<Id> missingCaseIds = new Set<Id>();
    for (Id caseId : caseIds) {
      if (!txnCaseTeamRowById.containsKey(caseId)) {
        missingCaseIds.add(caseId);
      }
    }
    if (!missingCaseIds.isEmpty()) {
      for (Case row : [
        SELECT Id, FEC_Team__c
        FROM Case
        WHERE Id IN :missingCaseIds
      ]) {
        txnCaseTeamRowById.put(row.Id, row);
      }
    }
    Map<Id, Case> caseById = new Map<Id, Case>();
    for (Id caseId : caseIds) {
      if (txnCaseTeamRowById.containsKey(caseId)) {
        caseById.put(caseId, txnCaseTeamRowById.get(caseId));
      }
    }
    return caseById;
  }

  private static void partitionHistoriesByAssignment(
    List<FEC_Routing_Action_History__c> source,
    List<FEC_Routing_Action_History__c> caseLevel,
    List<FEC_Routing_Action_History__c> assignmentLevel
  ) {
    for (FEC_Routing_Action_History__c history : source) {
      if (history.FEC_Case__c == null) {
        continue;
      }
      if (history.FEC_Assignment__c != null) {
        assignmentLevel.add(history);
      } else {
        caseLevel.add(history);
      }
    }
  }

  // SOQL 101: bulk SELECT FEC_Team__c từ Assignment — không lookup Group/FEC_Team_Queue__c từng RAH.
  private static Map<Id, FEC_Assignment__c> loadAssignmentsForHistories(
    List<FEC_Routing_Action_History__c> assignmentLevel
  ) {
    Set<Id> assignmentIds = new Set<Id>();
    for (FEC_Routing_Action_History__c history : assignmentLevel) {
      assignmentIds.add(history.FEC_Assignment__c);
    }
    if (assignmentIds.isEmpty()) {
      return new Map<Id, FEC_Assignment__c>();
    }
    return new Map<Id, FEC_Assignment__c>([
      SELECT Id, FEC_Team__c
      FROM FEC_Assignment__c
      WHERE Id IN :assignmentIds
    ]);
  }

  private static void applyCaseTeamFromHistory(
    FEC_Routing_Action_History__c history,
    Map<Id, Case> caseById,
    Map<Id, String> teamByOwnerId,
    String updatedTeamOverride
  ) {
    Case caseRecord = caseById.get(history.FEC_Case__c);
    if (caseRecord == null) {
      return;
    }
    updateCaseTeams(
      parseOwnerIdField(history.FEC_Original_User_Queue_ID__c),
      parseOwnerIdField(history.FEC_Updated_User_Queue_ID__c),
      caseRecord,
      history,
      teamByOwnerId,
      updatedTeamOverride
    );
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
      // Chỉ sync khi field TAT RAH đổi (needsRecalc trong queueCaseFullProcessTatAfterSave).
      FEC_RoutingHistTatSvc.queueCaseFullProcessTatAfterSave(newRecords, oldMap);
      FEC_RoutingHistTatSvc.commitPendingCaseFullProcessTatSync();
      sendNotificationEmails(newRecords);
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
    return buildPendingStatusFromRouteHistoryRow(history, null);
  }

  public static String buildPendingStatusFromRouteHistoryRow(
    FEC_Routing_Action_History__c history,
    Map<Id, String> teamByOwnerId
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
      return buildPendingStatusFromOwnerIds(null, updId, teamByOwnerId);
    }
    return buildPendingStatusFromOwnerIds(origId, updId, teamByOwnerId);
  }

  /** Hai Id Owner (User hoặc Queue) — Team từ User qua FEC_Main_Queue__c + FEC_Team_Queue__c; Queue trực tiếp. */
  public static String buildPendingStatusFromOwnerIds(Id originalOwnerId, Id updatedOwnerId) {
    return buildPendingStatusFromOwnerIds(originalOwnerId, updatedOwnerId, null);
  }

  public static String buildPendingStatusFromOwnerIds(
    Id originalOwnerId,
    Id updatedOwnerId,
    Map<Id, String> teamByOwnerId
  ) {
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
    // SOQL 101: teamByOwnerId preload từ bulk; null thì FEC_OwnerTeamLookupSvc (cache transaction).
    Map<Id, String> teamMap = teamByOwnerId != null
      ? teamByOwnerId
      : FEC_OwnerTeamLookupSvc.getByOwnerIds(idSet);
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
    updateCaseTeams(
      originalUserQueueId,
      updatedUserQueueId,
      caseRecord,
      history,
      null
    );
  }

  public static void updateCaseTeams(
    Id originalUserQueueId,
    Id updatedUserQueueId,
    Case caseRecord,
    FEC_Routing_Action_History__c history,
    Map<Id, String> teamByOwnerId
  ) {
    updateCaseTeams(
      originalUserQueueId,
      updatedUserQueueId,
      caseRecord,
      history,
      teamByOwnerId,
      null
    );
  }

  public static void updateCaseTeams(
    Id originalUserQueueId,
    Id updatedUserQueueId,
    Case caseRecord,
    FEC_Routing_Action_History__c history,
    Map<Id, String> teamByOwnerId,
    String preResolvedUpdatedTeam
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

    // SOQL 101: teamByOwnerId preload từ handleUpdateCaseTeamsOnInsert; fallback FEC_OwnerTeamLookupSvc.
    Map<Id, String> teamMap = teamByOwnerId != null
      ? teamByOwnerId
      : FEC_OwnerTeamLookupSvc.getByOwnerIds(idSet);
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
    String updatedTeam;
    // SOQL 101: preResolvedUpdatedTeam từ Assignment — bỏ getTeamsFromIds cho updated queue Id.
    if (String.isNotBlank(preResolvedUpdatedTeam)) {
      updatedTeam = preResolvedUpdatedTeam.replaceAll('\\W+', '').trim();
    } else if (history.FEC_Routing_Action__c == FEC_CaseBusinessService.UPDATEACTION) {
      updatedTeam = decisionToTeamMap.get(history.FEC_Decision__c);
    } else {
      updatedTeam = teamMap.get(updatedUserQueueId)?.replaceAll('\\W+', '').trim();
    }

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

  public static Set<Id> collectOwnerIdsFromRouteHistory(
    Iterable<FEC_Routing_Action_History__c> histories
  ) {
    return collectOwnerIdsFromRouteHistory(histories, true);
  }

  // SOQL 101: includeUpdatedOwnerId=false — assignment bulk chỉ cần original owner Id.
  public static Set<Id> collectOwnerIdsFromRouteHistory(
    Iterable<FEC_Routing_Action_History__c> histories,
    Boolean includeUpdatedOwnerId
  ) {
    Set<Id> ownerIds = new Set<Id>();
    if (histories == null) {
      return ownerIds;
    }
    Boolean withUpdated = includeUpdatedOwnerId != null && includeUpdatedOwnerId;
    for (FEC_Routing_Action_History__c hist : histories) {
      if (hist == null) {
        continue;
      }
      Id origId = parseOwnerIdField(hist.FEC_Original_User_Queue_ID__c);
      if (origId != null) {
        ownerIds.add(origId);
      }
      if (withUpdated) {
        Id updId = parseOwnerIdField(hist.FEC_Updated_User_Queue_ID__c);
        if (updId != null) {
          ownerIds.add(updId);
        }
      }
    }
    return ownerIds;
  }

  // SOQL 101: lookup owner → team (cache transaction) — logic trong FEC_OwnerTeamLookupSvc.
  public static Map<Id, String> getTeamsFromIds(Set<Id> targetIds) {
    return FEC_OwnerTeamLookupSvc.getByOwnerIds(targetIds);
  }
}