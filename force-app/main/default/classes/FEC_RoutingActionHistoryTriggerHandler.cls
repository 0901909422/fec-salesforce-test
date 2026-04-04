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
      sendNotificationEmails(newRecords);
    } finally {
      isExecuting = false;
    }
  }

  public static void sendNotificationEmails(List<FEC_Routing_Action_History__c> newList) {
        System.debug('--- [sendNotificationEmails] START - Total records in newList: ' + newList.size());

        // 1. Thu thập danh sách Case Ids từ Trigger
        Set<Id> caseIds = new Set<Id>();
        for (FEC_Routing_Action_History__c history : newList) {
            if (history.FEC_Case__c != null) {
                caseIds.add(history.FEC_Case__c);
            }
        }
        
        System.debug('--- [sendNotificationEmails] Step 1: Extracted Case IDs size: ' + caseIds.size());
        if (caseIds.isEmpty()) {
            System.debug('--- [sendNotificationEmails] No Case IDs found. Exiting method.');
            return;
        }

        // 2. Query thông tin Case và các object liên quan (Account_or_Contract__r, Interaction__r)
        Map<Id, Case> caseMap = new Map<Id, Case>([
            SELECT Id, FEC_Customer_Type__c, FEC_Product_Type__c, FEC_Category__c, 
                   FEC_SubCategory__c, FEC_SubCode__c, FEC_Current_Case_Stage__c,
                   FEC_Account_or_Contract__r.FEC_Customer_Type__c, 
                   FEC_Account_or_Contract__r.FEC_Email__c,
                   FEC_Interaction__r.FEC_Interaction_Email__c, 
                   FEC_Case_Email__c
            FROM Case
            WHERE Id IN :caseIds
        ]);
        System.debug('--- [sendNotificationEmails] Step 2: Queried CaseMap size: ' + caseMap.size());

        // 3. Query các cấu hình Notification thỏa mãn điều kiện tĩnh
        List<FEC_Notification__c> activeNotifications = [
            SELECT Id, FEC_Current_Status__c, FEC_Changed_Status__c, FEC_Target_Group__c, 
                   FEC_Customer_Type__c, FEC_Product_Type__c, FEC_Category__c, 
                   FEC_SubCategory__c, FEC_SubCode__c, FEC_Case_Stage__c
            FROM FEC_Notification__c
            WHERE FEC_Notification_Status__c = true 
              AND FEC_Notification_Channel__r.Name = 'Email'
              AND FEC_Target_Group__c = 'Customer'
        ];
        System.debug('--- [sendNotificationEmails] Step 3: Active Notifications found: ' + activeNotifications.size());

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        // 4. Xử lý logic cho từng Routing Action History
        for (FEC_Routing_Action_History__c history : newList) {
            System.debug('--- [sendNotificationEmails] Step 4: Processing History Record: ' + history);

            if (history.FEC_Case__c == null || !caseMap.containsKey(history.FEC_Case__c)) {
                System.debug('--- [sendNotificationEmails] Skipped: No related Case found for History ID: ' + history.Id);
                continue;
            }
            
            Case relatedCase = caseMap.get(history.FEC_Case__c);
            FEC_Notification__c matchedNotification = null;

            // Tìm Notification ĐẦU TIÊN khớp với các điều kiện
            for (FEC_Notification__c notif : activeNotifications) {
                System.debug('--- [sendNotificationEmails] Step 4.1: Processing Notification: ' + notif);

                Boolean isCurrentStatusMatch = String.isNotBlank(notif.FEC_Current_Status__c) 
                    && String.isNotBlank(history.FEC_Current_Status__c)
                    && notif.FEC_Current_Status__c.contains(history.FEC_Current_Status__c);
                                  
                    System.debug('--- [sendNotificationEmails] Step 4.2: isCurrentStatusMatch ' + isCurrentStatusMatch);
                    
                    
                
                // Lưu ý bug tiềm ẩn ở đây (so sánh FEC_Changed_Status__c với FEC_Current_Status__c của history)
                Boolean isChangedStatusMatch = String.isNotBlank(notif.FEC_Changed_Status__c) 
                    && String.isNotBlank(history.FEC_Changed_Status__c) 
                    && notif.FEC_Changed_Status__c.contains(history.FEC_Changed_Status__c);   
                    System.debug('--- [sendNotificationEmails] Step 4.2: isChangedStatusMatch: ' + isChangedStatusMatch);
                    

                Boolean isCaseMatch = 
                       (notif.FEC_Customer_Type__c == relatedCase.FEC_Customer_Type__c)
                    && (notif.FEC_Product_Type__c == relatedCase.FEC_Product_Type__c)
                    && (notif.FEC_Category__c == relatedCase.FEC_Category__c)
                    && (notif.FEC_SubCategory__c == relatedCase.FEC_SubCategory__c)
                    && (notif.FEC_SubCode__c == relatedCase.FEC_SubCode__c);

    
                if (isCurrentStatusMatch && isChangedStatusMatch && isCaseMatch) {
                    matchedNotification = notif;
                    System.debug('--- [sendNotificationEmails] MATCH FOUND! Notification ID: ' + notif.Id + ' for History ID: ' + history.Id);
                    break; 
                }
            }

            // 5. Nếu tìm thấy Notification, tiến hành xác định Email và tạo Email Message
            if (matchedNotification != null) {
                String targetEmailAddress = null;
                String accCustomerType = relatedCase.FEC_Account_or_Contract__r?.FEC_Customer_Type__c;

                System.debug('--- [sendNotificationEmails] Step 5: Account Customer Type: ' + accCustomerType);
                System.debug('--- [sendNotificationEmails] Step 5: Case Customer Type: ' + relatedCase.FEC_Customer_Type__c);
                if (accCustomerType == 'Existing') {
                    targetEmailAddress = relatedCase.FEC_Account_or_Contract__r?.FEC_Email__c;
                } 
                else if (accCustomerType == 'Non-existing') {
                    if (String.isNotBlank(relatedCase.FEC_Interaction__r?.FEC_Interaction_Email__c)) {
                        targetEmailAddress = relatedCase.FEC_Interaction__r.FEC_Interaction_Email__c;
                    } else {
                        targetEmailAddress = relatedCase.FEC_Case_Email__c;
                    }
                }

                System.debug('--- [sendNotificationEmails] Target Email Address resolved: ' + targetEmailAddress);
                List<OrgWideEmailAddress> owaList = [
                    SELECT Id, Address 
                    FROM OrgWideEmailAddress 
                    WHERE Address = 'minhtung2108@gmail.com'
                    LIMIT 1
                ];
                
                Id emailId = owaList.isEmpty() ? null : owaList[0].Id;

                if (String.isNotBlank(targetEmailAddress)) {
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new List<String>{ targetEmailAddress });
                    if (emailId != null) {
                        mail.setOrgWideEmailAddressId(emailId);
                    }
                    mail.setSubject('Thông báo cập nhật Case từ hệ thống'); 
                    mail.setPlainTextBody('Nội dung email dựa theo logic notification: ' + matchedNotification.Id);
                    
                    emailsToSend.add(mail);
                    System.debug('--- [sendNotificationEmails] Email added to list for: ' + targetEmailAddress);
                } else {
                    System.debug('--- [sendNotificationEmails] Skipped: Target Email Address is blank.');
                }
            } else {
                System.debug('--- [sendNotificationEmails] No matching notification found for History ID: ' + history.Id);
            }
        }

        // 6. Gửi toàn bộ email ra ngoài cùng 1 lúc (Bulk DML)
        System.debug('--- [sendNotificationEmails] Step 6: Total emails to send: ' + emailsToSend.size());
        if (!emailsToSend.isEmpty()) {
            try {
                List<Messaging.SendEmailResult> results = Messaging.sendEmail(emailsToSend);
                // Bạn có thể log thêm kết quả chi tiết của từng email nếu cần
                System.debug('--- [sendNotificationEmails] Emails sent successfully.');
            } catch (Exception e) {
                System.debug('--- [sendNotificationEmails] ERROR sending email: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
            }
        }   
        System.debug('--- [sendNotificationEmails] END');
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