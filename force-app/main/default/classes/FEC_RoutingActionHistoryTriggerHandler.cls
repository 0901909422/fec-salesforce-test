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
      processNotification(newRecords);
      if (FEC_MrcDuplicateCaseService.isSuppressRoutingHistoryTriggerSideEffects()) {
        return;
      }
      handleUpdateCaseTeamsOnInsert(newRecords);
      FEC_CaseManagerListService.applyAfterRoutingHistoryInsert(newRecords);
      // SOQL 101: TAT Full Process enqueue Queueable — không sync Case đồng bộ trong trigger.
      FEC_RoutingHistTatSvc.queueCaseFullProcessTatAfterSave(newRecords);
      FEC_RoutingHistTatSvc.commitPendingCaseFullProcessTatSync();
      sendNotificationEmails(newRecords);
      // Moved from trigger body into handler (separation of concerns)
      FEC_AssignmentController.handle(newRecords);
    } catch (Exception e) {
      throw new RoutingActionHistoryException('Error processing Routing Action History after insert: ' + e.getMessage());
    } finally {
      isExecuting = false;
    }
  }

  // 23/06/2026 linhdev - @TestVisible: mô phỏng context queueable khi Test.stopTest() chạy sync (isQueueable=false).
  @TestVisible
  private static Boolean syncNotificationEmailsOverride = false;

  public static void sendNotificationEmails(List<FEC_Routing_Action_History__c> newList) {
    if (newList == null || newList.isEmpty()) return;
    if (FEC_NotificationService.suppressForCaseSubmit) {
      return;
    }
    if (FEC_BatchCaseHandlingImportService.isBatchImportApplyInProgress()) {
      return;
    }
    // 23/06/2026 linhdev - Queueable/Future/Batch (limit=1): xử lý sync để BCH import chain giữ slot.
    if (
      syncNotificationEmailsOverride ||
      System.isQueueable() ||
      System.isFuture() ||
      System.isBatch() ||
      Limits.getLimitQueueableJobs() == 1
    ) {
      processNotificationEmails(newList);
      return;
    }
    // 23/06/2026 linhdev - hết slot queueable trong sync txn: fallback sync thay vì throw LimitException.
    if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
      processNotificationEmails(newList);
      return;
    }
    System.enqueueJob(new FEC_SendNotificationEmailsQueueable(newList));
  }

  public static void processNotification(List<FEC_Routing_Action_History__c> newRecords) {
    // Nếu đã ở async context rồi (Queueable/Batch/Future):
    // - Không gọi lại @future được (future method không được gọi từ context async khác).
    // - Gọi processNotificationEmails() trực tiếp tại đây vẫn đang nằm trong Trigger context
    //   (Trigger.isExecuting), nên callout THẬT (ZNS, Mobile App) sẽ bị Salesforce chặn:
    //   "Callout from triggers are currently not supported". processZnsNotification/
    //   processMobileAppNotification có try-catch nên sẽ không crash, nhưng notification đó
    //   sẽ bị ghi log FAIL (không gửi được) — chỉ Email là an toàn vì không tính là callout.
    // => Ưu tiên enqueue 1 Queueable job MỚI để thoát hẳn khỏi Trigger context (callout hoạt động
    //    bình thường trong transaction riêng của job đó). Enqueue bị giới hạn tối đa 1 job mới
    //    trong 1 Queueable/Batch/Future context đang chạy nên PHẢI check quota trước; nếu hết quota
    //    thì fallback gọi trực tiếp để KHÔNG làm crash job cha (VD: FEC_BatchCaseHandlingImportQueueable).
    if (System.isFuture() || System.isQueueable() || System.isBatch()) {
        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new FEC_SendNotificationEmailsQueueable(newRecords));
        } else {
            System.debug(LoggingLevel.WARN, '--- [processNotification] Hết quota Queueable job, xử lý trực tiếp. ZNS/Mobile App có thể bị log FAIL do callout-from-trigger, Email vẫn gửi bình thường.');
            processNotificationEmails(newRecords);
        }
        return;
    }

    List<Id> routingHistoryIds = new List<Id>();
    for (FEC_Routing_Action_History__c history : newRecords) {
      if (history.Id != null) {
        routingHistoryIds.add(history.Id);
      }
    }
    
    if (!routingHistoryIds.isEmpty()) {
      processNotificationAsync(routingHistoryIds);
    }
  }

  @future(callout=true)
  public static void processNotificationAsync(List<Id> routingHistoryIds) {
      if (routingHistoryIds == null || routingHistoryIds.isEmpty()) {
          return;
      }

      List<FEC_Routing_Action_History__c> histories = [
          SELECT Id,
                FEC_Case__c,
                FEC_Current_Status__c,
                FEC_Changed_Status__c,
                FEC_Routing_Action_Type__c,
                FEC_Assignment__c,
                FEC_Routing_Action__c,
                FEC_Decision__c,
                FEC_Original_User_Queue_ID__c,
                FEC_Updated_User_Queue_ID__c
          FROM FEC_Routing_Action_History__c
          WHERE Id IN :routingHistoryIds
      ];

      processNotificationEmails(histories);
  }

  public static void processNotificationEmails(List<FEC_Routing_Action_History__c> newList) {
      if (newList == null || newList.isEmpty()) return;
      Set<Id> caseIds = new Set<Id>();
      for (FEC_Routing_Action_History__c history : newList) {
          if (history.FEC_Case__c != null) caseIds.add(history.FEC_Case__c);
      }
      if (caseIds.isEmpty()) return;

      // 1. Sender Email cho channel Email (ZNS không cần sender email)
      String senderEmail = '';
      Id orgWideId = FEC_CommonUltils.getOrgWideEmailIdForNotification();
      if (orgWideId != null) {
          List<OrgWideEmailAddress> orgEmails = [SELECT Address FROM OrgWideEmailAddress WHERE Id = :orgWideId LIMIT 1];
          if (!orgEmails.isEmpty()) {
              senderEmail = orgEmails[0].Address;
          }
      }
    System.debug('--- [processNotificationEmails] senderEmail: ' + senderEmail);

      // 2. Query Case - bổ sung Primary Phone để gửi ZNS và National ID để gửi MobileApp
      Map<Id, Case> caseMap = new Map<Id, Case>([
          SELECT Id, FEC_Customer_Type__c, FEC_Product_Type__c, FEC_Category__c,
                FEC_SubCategory__c, FEC_SubCode__c, FEC_Current_Case_Stage__c,
                FEC_SubCategory__r.Name, FEC_SubCode__r.Name,
                FEC_SubCategory__r.FEC_Code__c, FEC_SubCode__r.FEC_Code__c, FEC_Stage_Name__c,
                FEC_Account_or_Contract__r.FEC_Customer_Type__c,
                FEC_Account_or_Contract__r.FEC_Email__c,
                FEC_Account_or_Contract__r.FEC_Primary_Phone__c,
                FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c,
                FEC_Interaction__r.FEC_Interaction_Email__c,
                FEC_Case_Email__c
          FROM Case WHERE Id IN :caseIds
      ]);

      // 3. Query Notification Template Channel cho CẢ Email, ZNS và Mobile App
      Set<String> validChannelNames = new Set<String>{
          FEC_ConstantCommon.EMAIL,
          FEC_ConstantCommon.NOTIFICATION_CHANNEL_ZNS,
          FEC_ConstantCommon.NOTIFICATION_CHANNEL_MOBILE_APP
      };
      List<FEC_Notification_Template_Channel__c> activeChannels = [
          SELECT FEC_Notification_Template__c, FEC_Notification_Channel__c, FEC_Notification_Channel__r.Name,
                FEC_Notification__r.Id, FEC_Notification__r.Name, FEC_Notification__r.FEC_Current_Status__c,
                FEC_Notification__r.FEC_Changed_Status__c, FEC_Notification__r.FEC_Target_Group__c,
                FEC_Notification__r.FEC_Customer_Type__c, FEC_Notification__r.FEC_Product_Type__c,
                FEC_Notification__r.FEC_Category__c, FEC_Notification__r.FEC_SubCategory__c,
                FEC_Notification__r.FEC_SubCode__c, FEC_Notification__r.FEC_Case_Stage__c
          FROM FEC_Notification_Template_Channel__c
          WHERE FEC_Notification__r.FEC_Notification_Status__c = true
            AND FEC_Notification_Channel__r.Name IN :validChannelNames
            AND FEC_Notification__r.FEC_Target_Group__c = :FEC_ConstantCommon.TARGET_GROUP_CUSTOMER
      ];

      if (activeChannels.isEmpty()) return;

      // Gom TẤT CẢ channel khớp cho từng history (KHÔNG break -> 1 history có thể vừa khớp Email vừa khớp ZNS)
      Map<FEC_Routing_Action_History__c, List<FEC_Notification_Template_Channel__c>> historyToChannelsMap =
          new Map<FEC_Routing_Action_History__c, List<FEC_Notification_Template_Channel__c>>();
      Set<Id> templateIds = new Set<Id>();

      for (FEC_Routing_Action_History__c history : newList) {
          if (history.FEC_Case__c == null || !caseMap.containsKey(history.FEC_Case__c)) continue;
          Case relatedCase = caseMap.get(history.FEC_Case__c);

          for (FEC_Notification_Template_Channel__c channel : activeChannels) {
              FEC_Notification__c notif = channel.FEC_Notification__r;
            // Logic so khớp điều kiện (Giữ nguyên logic cũ của bạn)
              Boolean isMatch = (String.isNotBlank(history.FEC_Current_Status__c) && notif.FEC_Current_Status__c?.contains(history.FEC_Current_Status__c) == true)
                  && (String.isNotBlank(history.FEC_Changed_Status__c) && notif.FEC_Changed_Status__c?.contains(history.FEC_Changed_Status__c) == true)
&& FEC_CommonUltils.notificationCustomerTypeMatchesCase(notif.FEC_Customer_Type__c, relatedCase.FEC_Customer_Type__c)
                  && (notif.FEC_Product_Type__c == relatedCase.FEC_Product_Type__c)
                  && (notif.FEC_Category__c == relatedCase.FEC_Category__c)
                  && (String.isBlank(notif?.FEC_SubCategory__c) || (relatedCase.FEC_SubCategory__r != null && notif?.FEC_SubCategory__c?.contains(relatedCase.FEC_SubCategory__r.FEC_Code__c) == true))
                  && (String.isBlank(notif?.FEC_SubCode__c) || (relatedCase?.FEC_SubCode__r != null && notif?.FEC_SubCode__c?.contains(relatedCase?.FEC_SubCode__r?.FEC_Code__c) == true) || String.isBlank(relatedCase?.FEC_SubCode__r?.FEC_Code__c));
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
                  if (!historyToChannelsMap.containsKey(history)) {
                      historyToChannelsMap.put(history, new List<FEC_Notification_Template_Channel__c>());
                  }
                  historyToChannelsMap.get(history).add(channel);
                  if (channel.FEC_Notification_Template__c != null) {
                      templateIds.add(channel.FEC_Notification_Template__c);
                  }
                  // Không break: cho phép 1 history khớp nhiều channel (Email + ZNS)
              }
          }
      }

      if (historyToChannelsMap.isEmpty()) return;

      // 4. Query Template 1 lần (bulk) - bổ sung FEC_Active__c để check ZNS template active
      Map<Id, FEC_Template__c> templateMap = new Map<Id, FEC_Template__c>();
      if (!templateIds.isEmpty()) {
          templateMap = new Map<Id, FEC_Template__c>([
              SELECT Id, Name, FEC_Subject_Line__c, FEC_Body__c, FEC_Active__c,
                    FEC_Enhanced_Letterhead__c, FEC_Enhanced_Letterhead__r.FEC_Header__c, FEC_Enhanced_Letterhead__r.FEC_Footer__c
              FROM FEC_Template__c
              WHERE Id IN :templateIds
          ]);
      }

      // 5. Danh sách Email
      List<FEC_Notification.EmailInfo> listEmailsToProcess = new List<FEC_Notification.EmailInfo>();
      List<FEC_Notification.RoutingEmailHistoryInput> routingHistories = new List<FEC_Notification.RoutingEmailHistoryInput>();

      // 6. Danh sách log cho ZNS (ZNS gửi trực tiếp trong loop, không gửi bulk như Email)
      List<FEC_Notification_History__c> historiesToInsert = new List<FEC_Notification_History__c>();

      for (FEC_Routing_Action_History__c history : historyToChannelsMap.keySet()) {
          Case relatedCase = caseMap.get(history.FEC_Case__c);

          for (FEC_Notification_Template_Channel__c matchedChannel : historyToChannelsMap.get(history)) {
              FEC_Notification__c matchedNotification = matchedChannel.FEC_Notification__r;
              String channelName = matchedChannel.FEC_Notification_Channel__r != null ? matchedChannel.FEC_Notification_Channel__r.Name : null;
              FEC_Template__c template = templateMap.get(matchedChannel.FEC_Notification_Template__c);

              if (channelName == FEC_ConstantCommon.NOTIFICATION_CHANNEL_ZNS) {
                  // ===================== AUTO ZNS =====================
                  processZnsNotification(history, relatedCase, matchedNotification, template, channelName, historiesToInsert);
              } else if (channelName == FEC_ConstantCommon.NOTIFICATION_CHANNEL_MOBILE_APP) {
                  // ===================== AUTO MOBILE APP ===============
                  processMobileAppNotification(history, relatedCase, matchedNotification, template, channelName, historiesToInsert);
              } else
              {
                  // ===================== AUTO EMAIL =====================
                  processEmailNotification(relatedCase, matchedNotification, template, channelName, listEmailsToProcess, routingHistories);
              }
          }
      }

      // 7. Gửi Email bulk (logic cũ - tự resolve merge field + ghi EmailMessage + History bên trong)
      if (!listEmailsToProcess.isEmpty()) {
          FEC_Notification.executeSendEmailsBulk(listEmailsToProcess, senderEmail, routingHistories);
      }

      // 8. Ghi log lịch sử cho ZNS và Mobile App
      FEC_ZNSNotificationCallout.writeLogSendNoti();
      FEC_MobileAppNotificationCallout.writeLogSendNoti();
      if (!historiesToInsert.isEmpty()) {
          FEC_NotificationHistoryService.insertRows(historiesToInsert);
      }
  }

  /**
   * Xử lý gửi thông báo qua kênh ZNS cho 1 cặp (history, case, notification, template) đã match.
   * Khác với Email, ZNS được gửi (callout) ngay trong vòng lặp, không gửi bulk.
   * Sau khi gửi (thành công hoặc lỗi), build 1 dòng log và add vào znsHistoriesToInsert để insert sau.
   *
   * @param history              Routing Action History đang xử lý (chỉ dùng để log Id khi SKIP)
   * @param relatedCase          Case liên quan, dùng lấy số điện thoại (Primary Phone) và Stage Name
   * @param matchedNotification  Notification rule đã match với history/case
   * @param template             Template ZNS tương ứng (FEC_Subject_Line__c lưu Template ID của ZNS)
   * @param channelName          Tên channel (ZNS), dùng để ghi log
   * @param znsHistoriesToInsert List log ZNS (output) - method này append kết quả gửi vào list này
   */
  private static void processZnsNotification(
    FEC_Routing_Action_History__c history,
    Case relatedCase,
    FEC_Notification__c matchedNotification,
    FEC_Template__c template,
    String channelName,
    List<FEC_Notification_History__c> znsHistoriesToInsert
  ) {
      String phoneNumber = relatedCase.FEC_Account_or_Contract__r?.FEC_Primary_Phone__c;
      Boolean templateActive = template != null && template.FEC_Active__c == true;
      String znsTemplateId = template != null ? template.FEC_Subject_Line__c : null; // FEC_Subject_Line__c lưu Template ID của ZNS

      if (String.isBlank(phoneNumber) || template == null || !templateActive || String.isBlank(znsTemplateId)) {
          System.debug('--- [processZnsNotification] SKIP ZNS. history=' + history.Id + ', missing phone/template');
          return;
      }

      try {
          FEC_ZNSNotificationCallout.SendZnsMessageResponseDto res =
              FEC_ZNSNotificationCallout.callSendZNSMessageByCaseWithoutLogging(relatedCase.Id, phoneNumber, znsTemplateId);

          Boolean isSuccess = res != null && res.Sys != null && res.Sys.Code == 1;
          String errorMessage = isSuccess ? null : (res != null && res.Sys != null ? res.Sys.Description : 'Empty response from ZNS API');

          znsHistoriesToInsert.add(
              FEC_NotificationHistoryService.buildRow(
                  relatedCase.Id,
                  matchedNotification.Id,
                  relatedCase.FEC_Stage_Name__c,
                  template.Name,
                  matchedNotification.Name,
                  channelName,
                  matchedNotification.FEC_Target_Group__c,
                  FEC_NotificationHistoryService.SEND_TYPE_AUTO,
                  isSuccess ? FEC_NotificationHistoryService.SEND_STATUS_SUCCESS : FEC_NotificationHistoryService.SEND_STATUS_FAILURE,
                  errorMessage,
                  FEC_NotificationHistoryService.SEND_USER_SYSTEM,
                  null,
                  System.now()
              )
          );
      } catch (Exception ex) {
          znsHistoriesToInsert.add(
              FEC_NotificationHistoryService.buildRow(
                  relatedCase.Id,
                  matchedNotification.Id,
                  relatedCase.FEC_Stage_Name__c,
                  template.Name,
                  matchedNotification.Name,
                  channelName,
                  matchedNotification.FEC_Target_Group__c,
                  FEC_NotificationHistoryService.SEND_TYPE_AUTO,
                  FEC_NotificationHistoryService.SEND_STATUS_FAILURE,
                  ex.getMessage(),
                  FEC_NotificationHistoryService.SEND_USER_SYSTEM,
                  null,
                  System.now()
              )
          );
      }
  }

  /**
   * Xử lý gửi thông báo qua kênh Mobile App cho 1 cặp (history, case, notification, template) đã match.
   * Sau khi gửi (thành công hoặc lỗi), build 1 dòng log và add vào mobileAppHistoriesToInsert để insert sau.
   *
   * @param history              Routing Action History đang xử lý (chỉ dùng để log Id khi SKIP)
   * @param relatedCase          Case liên quan, dùng lấy số điện thoại (Primary Phone) và Stage Name
   * @param matchedNotification  Notification rule đã match với history/case
   * @param template             Template Mobile App tương ứng
   * @param channelName          Tên channel, dùng để ghi log
   * @param historiesToInsert List log (output) - method này append kết quả gửi vào list này
   */
  private static void processMobileAppNotification(
    FEC_Routing_Action_History__c history,
    Case relatedCase,
    FEC_Notification__c matchedNotification,
    FEC_Template__c template,
    String channelName,
    List<FEC_Notification_History__c> historiesToInsert
  ) {
      String phoneNumber = relatedCase.FEC_Account_or_Contract__r?.FEC_Primary_Phone__c;
      String nationalId = relatedCase.FEC_Account_or_Contract__r?.FEC_National_ID_Passport_ID__c;
      Boolean templateActive = template != null && template.FEC_Active__c == true;

      if ((String.isBlank(phoneNumber) && String.isBlank(nationalId)) || template == null || !templateActive) {
          System.debug('--- [processMobileAppNotification] SKIP MobileApp. history=' + history.Id + ', missing phone & nationalId/template');
          return;
      }

      String mobileTitle = FEC_NotificationService.resolveTemplate(template.FEC_Subject_Line__c, relatedCase);
      mobileTitle = String.isNotBlank(mobileTitle) ? mobileTitle.trim() : FEC_ConstantCommon.NOTIFICATION_MOBILE_APP_TITLE;
      String mobileContent = FEC_NotificationService.resolveTemplate(template.FEC_Body__c, relatedCase);

      try {
          FEC_MobileAppNotificationCallout.SendNotificationResponse res =
            FEC_MobileAppNotificationCallout.sendNotificationWithoutLogging(
              mobileContent,
              nationalId,
              phoneNumber,
              mobileTitle
            );

          Boolean isSuccess = res != null && res.code == '1';
          String errorMessage = isSuccess ? null : (res != null ? res.description : 'Empty response from Mobile App API');

          historiesToInsert.add(
              FEC_NotificationHistoryService.buildRow(
                  relatedCase.Id,
                  matchedNotification.Id,
                  relatedCase.FEC_Stage_Name__c,
                  template.Name,
                  matchedNotification.Name,
                  channelName,
                  matchedNotification.FEC_Target_Group__c,
                  FEC_NotificationHistoryService.SEND_TYPE_AUTO,
                  isSuccess ? FEC_NotificationHistoryService.SEND_STATUS_SUCCESS : FEC_NotificationHistoryService.SEND_STATUS_FAILURE,
                  errorMessage,
                  FEC_NotificationHistoryService.SEND_USER_SYSTEM,
                  null,
                  System.now()
              )
          );
      } catch (Exception ex) {
          historiesToInsert.add(
              FEC_NotificationHistoryService.buildRow(
                  relatedCase.Id,
                  matchedNotification.Id,
                  relatedCase.FEC_Stage_Name__c,
                  template.Name,
                  matchedNotification.Name,
                  channelName,
                  matchedNotification.FEC_Target_Group__c,
                  FEC_NotificationHistoryService.SEND_TYPE_AUTO,
                  FEC_NotificationHistoryService.SEND_STATUS_FAILURE,
                  ex.getMessage(),
                  FEC_NotificationHistoryService.SEND_USER_SYSTEM,
                  null,
                  System.now()
              )
          );
      }
  }

  /**
   * Xử lý build thông tin gửi thông báo qua kênh Email cho 1 cặp (case, notification, template) đã match.
   * Khác với ZNS, method này KHÔNG gửi email ngay - chỉ build EmailInfo + RoutingEmailHistoryInput
   * và add vào 2 list output truyền vào. Việc gửi thực tế (bulk, 1 lần) do executeSendEmailsBulk
   * thực hiện sau khi đã xử lý xong toàn bộ historyToChannelsMap.
   *
   * @param relatedCase          Case liên quan, dùng để xác định email người nhận
   * @param matchedNotification  Notification rule đã match với history/case
   * @param template             Template Email tương ứng (subject, body, header/footer letterhead)
   * @param channelName          Tên channel (Email), dùng để ghi log lịch sử
   * @param listEmailsToProcess  List EmailInfo (output) - method này append email cần gửi vào list này
   * @param routingHistories     List RoutingEmailHistoryInput (output) - dùng ghi log sau khi gửi bulk
   */
  private static void processEmailNotification(
    Case relatedCase,
    FEC_Notification__c matchedNotification,
    FEC_Template__c template,
    String channelName,
    List<FEC_Notification.EmailInfo> listEmailsToProcess,
    List<FEC_Notification.RoutingEmailHistoryInput> routingHistories
  ) {
      String targetEmailAddress = null;
      String accType = relatedCase.FEC_Account_or_Contract__r?.FEC_Customer_Type__c;
      if (accType == FEC_ConstantCommon.CUSTOMER_HISTORY_EXISTING_CUSTOMER) {
          targetEmailAddress = relatedCase.FEC_Account_or_Contract__r?.FEC_Email__c;
      } else {
          targetEmailAddress = String.isNotBlank(relatedCase.FEC_Interaction__r?.FEC_Interaction_Email__c)
              ? relatedCase.FEC_Interaction__r.FEC_Interaction_Email__c
              : relatedCase.FEC_Case_Email__c;
      }

      if (String.isNotBlank(targetEmailAddress) && template != null) {
          listEmailsToProcess.add(new FEC_Notification.EmailInfo(
              relatedCase.Id,
              targetEmailAddress,
              String.isNotBlank(template.FEC_Subject_Line__c) ? template.FEC_Subject_Line__c : 'Notification',
              template.FEC_Enhanced_Letterhead__r?.FEC_Header__c,
              template.FEC_Body__c,
              template.FEC_Enhanced_Letterhead__r?.FEC_Footer__c,
              template.Id
          ));

          FEC_Notification.RoutingEmailHistoryInput hi = new FEC_Notification.RoutingEmailHistoryInput();
          hi.caseId = relatedCase.Id;
          hi.notificationRuleId = matchedNotification.Id;
          hi.stageName = relatedCase.FEC_Stage_Name__c;
          hi.templateDisplayName = template.Name;
          hi.channelName = String.isNotBlank(channelName) ? channelName : FEC_ConstantCommon.EMAIL;
          hi.targetGroup = matchedNotification.FEC_Target_Group__c;
          hi.notificationRuleName = matchedNotification.Name;
          routingHistories.add(hi);
      }
  }

  // SOQL 101: bulk merge FEC_Team__c — cache Case, preload owner→team qua FEC_OwnerTeamLookupSvc.
  private void handleUpdateCaseTeamsOnInsert(
    List<FEC_Routing_Action_History__c> newRecords
  ) {
    Map<Id, Case> caseById = loadCachedCaseTeamRows(newRecords);
    if (caseById.isEmpty()) {
      return;
    }

    Set<Id> ownerIds = new Set<Id>();
    for (FEC_Routing_Action_History__c history : newRecords) {
      if (!isCaseLevelRoutingHistory(history)) {
        continue;
      }
      Id updId = parseOwnerIdField(history.FEC_Updated_User_Queue_ID__c);
      if (updId != null) {
        ownerIds.add(updId);
      }
    }
    Map<Id, String> teamByOwnerId = FEC_OwnerTeamLookupSvc.getByOwnerIds(ownerIds);

    for (FEC_Routing_Action_History__c history : newRecords) {
      if (!isCaseLevelRoutingHistory(history)) {
        continue;
      }

      Case caseRecord = caseById.get(history.FEC_Case__c);
      if (caseRecord == null) {
        continue;
      }

      updateCaseTeams(parseOwnerIdField(history.FEC_Updated_User_Queue_ID__c), caseRecord, history, teamByOwnerId);
    }

    // SOQL 101: isSystemUpdate — Case trigger bỏ qua syncChannel khi update FEC_Team__c.
    Boolean priorSystem = FEC_CaseTriggerHandler.isSystemUpdate;
    FEC_CaseTriggerHandler.isSystemUpdate = true;
    try {
      Database.update(caseById.values(), AccessLevel.SYSTEM_MODE);
    } finally {
      FEC_CaseTriggerHandler.isSystemUpdate = priorSystem;
    }
  }

  private static Boolean isCaseLevelRoutingHistory(FEC_Routing_Action_History__c history) {
    return history != null && history.FEC_Case__c != null && history.FEC_Routing_Action_Type__c == 'Case' && history.FEC_Assignment__c == null;
  }

  // SOQL 101: mỗi Case Id chỉ SELECT FEC_Team__c một lần/transaction.
  private static Map<Id, Case> loadCachedCaseTeamRows(
    List<FEC_Routing_Action_History__c> histories
  ) {
    Set<Id> caseIds = new Set<Id>();
    for (FEC_Routing_Action_History__c history : histories) {
      if (isCaseLevelRoutingHistory(history)) {
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
        SELECT Id, FEC_Team__c, FEC_Assignment_Count__c
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
      FEC_RoutingHistTatSvc.queueCaseFullProcessTatAfterSave(newRecords, oldMap);
      FEC_RoutingHistTatSvc.commitPendingCaseFullProcessTatSync();
      sendNotificationEmails(newRecords);
      // Moved from trigger body into handler (separation of concerns)
      FEC_AssignmentController.handle(newRecords);
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

  /** @param teamByOwnerId map preload từ getTeamsFromIds (bulk); null = query theo owner trên history. */
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
    Map<Id, String> teamMap = teamByOwnerId != null ? teamByOwnerId : FEC_OwnerTeamLookupSvc.getByOwnerIds(idSet);
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
    Id updatedUserQueueId,
    Case caseRecord,
    FEC_Routing_Action_History__c history
  ) {
    updateCaseTeams(updatedUserQueueId, caseRecord, history, null);
  }

  public static void updateCaseTeams(Id updatedUserQueueId, Case caseRecord, FEC_Routing_Action_History__c history, Map<Id, String> teamByOwnerId) {
    if (caseRecord == null || history == null) {
      return;
    }
    FEC_CaseBusinessService.Method actionMethod = FEC_CaseBusinessService.METHOD_MAP.get(history?.FEC_Routing_Action__c);
    switch on actionMethod {
      when CANCEL {
        caseRecord.FEC_Team__c = null;
      }
      when REJECT, RESOLVE {
        if (caseRecord.FEC_Assignment_Count__c > 0) {
          caseRecord.FEC_Team__c = null;
        } else {
          updateTeamFromQueue(updatedUserQueueId, caseRecord, history, teamByOwnerId);
        }
      }
      when UPDATEACTION {
        if (caseRecord.FEC_Assignment_Count__c == 0) {
          updateTeamForUpdateAction(caseRecord, history);
        }
      }
      when else {
        if (caseRecord.FEC_Assignment_Count__c == 0) {
          updateTeamFromQueue(updatedUserQueueId, caseRecord, history, teamByOwnerId);
        }
      }
    }
  }

  private static void updateTeamForUpdateAction(Case caseRecord, FEC_Routing_Action_History__c history) {
    if (history.FEC_Decision__c != FEC_ConstantCommon.CASE_DECISION_VALUE) {
      Map<String, String> decisionToTeamMap = FEC_ConstantCommon.decisionToTeamMap;
      String updatedTeamOnly = decisionToTeamMap.get(history.FEC_Decision__c);
      if (String.isNotBlank(updatedTeamOnly)) {
        caseRecord.FEC_Team__c = FEC_CommonUltils.sortTeamField(updatedTeamOnly);
      } else {
        caseRecord.FEC_Team__c = null;
      }
    } else {
      caseRecord.FEC_Team__c = null;
      caseRecord.Status = 'Resolved-CannotContactCustomer';

      FEC_Routing_Action_History__c clonedHistory = history.clone(false, true, false, false);
      clonedHistory.FEC_Routing_Action__c = FEC_CaseBusinessService.RESOLVE;
      clonedHistory.FEC_Decision__c = null;
      insert clonedHistory;
    }
  }

  private static void updateTeamFromQueue(Id updatedUserQueueId, Case caseRecord, FEC_Routing_Action_History__c history) {
    updateTeamFromQueue(updatedUserQueueId, caseRecord, history, null);
  }

  private static void updateTeamFromQueue(Id updatedUserQueueId, Case caseRecord, FEC_Routing_Action_History__c history, Map<Id, String> teamByOwnerId) {
    Set<Id> idSet = new Set<Id>();
    if (updatedUserQueueId != null) {
      idSet.add(updatedUserQueueId);
    }
    // SOQL 101: teamByOwnerId preload từ handleUpdateCaseTeamsOnInsert; fallback FEC_OwnerTeamLookupSvc.
    Map<Id, String> teamMap = teamByOwnerId != null ? teamByOwnerId : FEC_OwnerTeamLookupSvc.getByOwnerIds(idSet);
    Map<String, String> decisionToTeamMap = FEC_ConstantCommon.decisionToTeamMap;
    String updatedTeamOnly = teamMap.get(updatedUserQueueId);
    updatedTeamOnly = FEC_CommonUltils.cleanNonWordCharacters(updatedTeamOnly);
    if (String.isNotBlank(updatedTeamOnly)) {
      caseRecord.FEC_Team__c = FEC_CommonUltils.sortTeamField(updatedTeamOnly);
    } else {
      caseRecord.FEC_Team__c = null;
    }

    // if (originalUserQueueId != null)
    //   idSet.add(originalUserQueueId);
    

    
    //String updatedTeam = history.FEC_Routing_Action__c == FEC_CaseBusinessService.UPDATEACTION ? decisionToTeamMap.get(history.FEC_Decision__c) : teamMap.get(updatedUserQueueId)?.replaceAll('\\W+', '').trim();

    // String currentTeamsStr = caseRecord.FEC_Team__c;
    // Set<String> teamSet = new Set<String>();
    // if (String.isNotBlank(currentTeamsStr)) {
    //   for (
    //     String t : currentTeamsStr.split(FEC_ConstantCommon.DELIMITER_UNDERSCORE)
    //   ) {
    //     if (String.isNotBlank(t)) {
    //       teamSet.add(t.replaceAll('\\W+', '').trim());
    //     }
    //   }
    // }
    // if (teamSet.contains(originalTeam)) {
    //   teamSet.remove(originalTeam);
    // }

    // Add updated team if not exists
    // if (String.isNotBlank(updatedTeam)) {
    //   teamSet.add(updatedTeam);
    // }

    // if (teamSet.isEmpty()) {
    //   caseRecord.FEC_Team__c = null;
    // } else {
    //   caseRecord.FEC_Team__c = FEC_CommonUltils.sortTeamField(String.join(
    //     new List<String>(teamSet),
    //     FEC_ConstantCommon.DELIMITER_UNDERSCORE
    //   ));
    // }
  }

  /** Gom Id owner từ nhiều routing history — dùng trước getTeamsFromIds khi xử lý bulk. */
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