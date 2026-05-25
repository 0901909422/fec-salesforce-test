public without sharing class FEC_Notification {

    // Compile Pattern 1 lần ở class level để tái sử dụng
    private static final Pattern PATTERN_MERGE  = Pattern.compile(FEC_ConstantCommon.PATTERN_MERGE_FIELD);
    private static final Pattern PATTERN_FLEXIBLE = Pattern.compile(FEC_ConstantCommon.PATTERN_FLEXIBLE_BRACES);

    public class EmailInfo {
        public Id caseId;
        public String toEmail;
        public String subject;
        public String header;
        public String body;
        public String footer;
        public Id templateId;

        public EmailInfo(Id caseId, String toEmail, String subject, String header, String body, String footer) {
            this.caseId = caseId;
            this.toEmail = toEmail;
            this.subject = subject;
            this.header = header;
            this.body = body;
            this.footer = footer;
        }

        public EmailInfo(Id caseId, String toEmail, String subject, String header, String body, String footer, Id templateId) {
            this.caseId = caseId;
            this.toEmail = toEmail;
            this.subject = subject;
            this.header = header;
            this.body = body;
            this.footer = footer;
            this.templateId = templateId;
        }
    }

    /** Đồng bộ thứ tự với từng phần tử EmailInfo khi gửi bulk từ routing. */
    public class RoutingEmailHistoryInput {
        public Id caseId;
        public Id notificationRuleId;
        public String stageName;
        public String templateDisplayName;
        public String channelName;
        public String targetGroup;
        public String notificationRuleName;
    }
    
    @AuraEnabled
    public static RecordType getRecordTypeName(String recordTypeId) {
    try {
      List<RecordType> recordTypelst = FEC_RecordTypeDAO.getRecordsById(
        new Set<String>{ recordTypeId }
      );

      if (!recordTypelst.isEmpty()) {
        RecordType temp = recordTypelst.get(0);

        return new RecordType(
          Id = temp.Id,
          Name = temp.Name,
          DeveloperName = temp.DeveloperName
        );
      }

      return null;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
    public static Map<String, Object> getNotificationById(Id recordId) {
        try {
            Map<String, Object> result = new Map<String, Object>();
            
            // 1. Fetch the main record and related names for single-select lookups
            FEC_Notification__c noti = [
                SELECT Id, Name, RecordType.Name, RecordTypeId, RecordType.DeveloperName, 
                       FEC_Target_Group__c, //FEC_Notification_Channel__c, 
                       FEC_Channel__c, 
                       FEC_Product_Type__c, FEC_Product_Type__r.Name,
                       FEC_Category__c, FEC_Category__r.Name,
                       FEC_SubCategory__c,
                       FEC_SubCode__c,
                       FEC_Current_Status__c, FEC_Changed_Status__c,
                       //FEC_Notification_Template__c,
                       FEC_Assigned_to_Queue__c,
                       FEC_Case_Stage__c
                FROM FEC_Notification__c
                WHERE Id = :recordId
            ];
            result.put('record', noti);

            // 2. Fetch Channel names for the Multi-Select Channel lookup
            if (String.isNotBlank(noti.FEC_Channel__c)) {
                List<String> tokens = noti.FEC_Channel__c.split(',');
                List<String> ids = new List<String>();
                List<String> names = new List<String>();
                for (String t : tokens) {
                    t = t.trim();
                    if (String.isNotBlank(t)) {
                        if (t.length() == 15 || t.length() == 18) {
                            // Check if it's alphanumeric id format
                            if (t.isAlphanumeric()) {
                                ids.add(t);
                            } else {
                                names.add(t);
                            }
                        } else {
                            names.add(t);
                        }
                    }
                }
                result.put('channels', [SELECT Id, Name FROM FEC_Channel__c WHERE Id IN :ids OR Name IN :names]);
            }

            // 2. Fetch the Group (Queue) Name to display in the UI Pill
            if (String.isNotBlank(noti.FEC_Assigned_to_Queue__c)) {
                List<Group> queues = [SELECT Id, Name, DeveloperName FROM Group WHERE DeveloperName = :noti.FEC_Assigned_to_Queue__c AND Type = 'Queue' LIMIT 1];
                if (!queues.isEmpty()) {
                    result.put('queue', queues[0]);
                }
            }

            result.put('currentStatusPills', buildCaseStatusPills(noti.FEC_Current_Status__c));
            result.put('changedStatusPills', buildCaseStatusPills(noti.FEC_Changed_Status__c));
            result.put('subCategoryPills', buildLookupPillsByNamesOrIds(noti.FEC_SubCategory__c, 'FEC_Sub_Category__c'));
            result.put('subCodePills', buildLookupPillsByNamesOrIds(noti.FEC_SubCode__c, 'FEC_Sub_Code__c'));
            result.put('caseStagePills', buildLookupPillsByNamesOrIds(noti.FEC_Case_Stage__c, 'FEC_Case_Stage__c'));

            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Builds lookup pill payloads for FEC_Case_Status__c: Id = record Id when found, else Name (legacy/orphan).
     * Stored CSV uses Name values separated by ','.
     */
    private static List<Map<String, String>> buildCaseStatusPills(String csv) {
        List<Map<String, String>> pills = new List<Map<String, String>>();
        if (String.isBlank(csv)) {
            return pills;
        }
        List<String> orderedNames = new List<String>();
        for (String raw : csv.split(',')) {
            String n = raw == null ? '' : raw.trim();
            if (String.isNotBlank(n)) {
                orderedNames.add(n);
            }
        }
        if (orderedNames.isEmpty()) {
            return pills;
        }
        Set<String> nameSet = new Set<String>(orderedNames);
        Map<String, Id> nameToId = new Map<String, Id>();
        for (FEC_Case_Status__c row : [
            SELECT Id, Name FROM FEC_Case_Status__c WHERE Name IN :nameSet
        ]) {
            nameToId.put(row.Name, row.Id);
        }
        for (String n : orderedNames) {
            Map<String, String> m = new Map<String, String>();
            if (nameToId.containsKey(n)) {
                m.put('id', String.valueOf(nameToId.get(n)));
            } else {
                m.put('id', n);
            }
            m.put('title', n);
            m.put('subtitle', 'FEC Case Status');
            pills.add(m);
        }
        return pills;
    }

    private static List<Map<String, String>> buildLookupPillsByNamesOrIds(String csv, String objectApiName) {
        List<Map<String, String>> pills = new List<Map<String, String>>();
        if (String.isBlank(csv)) return pills;
        
        List<String> names = new List<String>();
        List<String> ids = new List<String>();
        for (String t : csv.split(',')) {
            t = t.trim();
            if (String.isNotBlank(t)) {
                if ((t.length() == 15 || t.length() == 18) && t.isAlphanumeric()) {
                    ids.add(t);
                } else {
                    names.add(t);
                }
            }
        }
        if (names.isEmpty() && ids.isEmpty()) return pills;
        
        Boolean hasCodeField = (objectApiName == FEC_ConstantCommon.FEC_SUB_CATEGORY || objectApiName == FEC_ConstantCommon.FEC_SUB_CODE);
        String query = 'SELECT Id, Name' + (hasCodeField ? ', FEC_Code__c' : '') + ' FROM ' + String.escapeSingleQuotes(objectApiName);
        if (hasCodeField) {
            query += ' WHERE Name IN :names OR Id IN :ids OR FEC_Code__c IN :names';
        } else {
            query += ' WHERE Name IN :names OR Id IN :ids';
        }
        try {
            for (SObject row : Database.query(query)) {
                Map<String, String> m = new Map<String, String>();
                m.put('id', (String)row.get('Id'));
                m.put('title', (String)row.get('Name'));
                if (hasCodeField && row.get('FEC_Code__c') != null) {
                    m.put('subtitle', (String)row.get('FEC_Code__c'));
                } else {
                    m.put('subtitle', objectApiName);
                }
                pills.add(m);
            }
        } catch (Exception e) {
            System.debug('Error building pills for ' + objectApiName + ': ' + e.getMessage());
        }
        return pills;
    }

    /**
     * Helper method to determine the target email based on Case
     */
    private static String getTargetEmailFromCase(Case c) {
        String targetEmail = '';
        if(c.FEC_Customer_Type__c == FEC_ConstantCommon.CASE_EXISTING_CUSTOMER) {
            targetEmail = c.FEC_Account_or_Contract__r.FEC_Email__c;
        } else if (c.FEC_Customer_Type__c == FEC_ConstantCommon.CASE_NON_EXISTING_CUSTOMER) {
            if(String.isNotBlank(c.FEC_Interaction__r.FEC_Interaction_Email__c)) {
                targetEmail = c.FEC_Interaction__r.FEC_Interaction_Email__c;
            } else {
                targetEmail = c.FEC_Case_Email__c;
            }
        }
        return targetEmail;
    }

    /**
     * Parse FEC_Customer_Type__c (multi-select lưu dạng "a;b;c" hoặc một giá trị picklist đơn).
     */
    private static Set<String> parseCustomerTypeTokens(String raw) {
        Set<String> out = new Set<String>();
        if (String.isBlank(raw)) {
            return out;
        }
        for (String p : raw.split(';')) {
            String t = p == null ? '' : p.trim();
            if (String.isNotBlank(t)) {
                out.add(t);
            }
        }
        return out;
    }

    /**
     * Hiển thị notification nếu Customer Type của cấu hình chứa giá trị Customer Type trên Case,
     * hoặc chứa token "All" (áp dụng mọi loại KH).
     */
    private static Boolean notificationMatchesCaseCustomerType(String notifCustomerTypeRaw, String caseCustomerType) {
        Set<String> notifTokens = parseCustomerTypeTokens(notifCustomerTypeRaw);
        if (notifTokens.isEmpty()) {
            return false;
        }
        if (notifTokens.contains(FEC_ConstantCommon.CASE_ALL_REQUEST)) {
            return true;
        }
        if (String.isBlank(caseCustomerType)) {
            return false;
        }
        return notifTokens.contains(caseCustomerType.trim());
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAvailableNotifications(Id caseId, String productTypeId, String categoryId, String subCategoryId, String subCodeId, String stageId) {
        // System.debug('--- [getAvailableNotifications] caseId: ' + caseId);
        // System.debug('--- [getAvailableNotifications] productTypeId: ' + productTypeId);
        // System.debug('--- [getAvailableNotifications] categoryId: ' + categoryId);
        // System.debug('--- [getAvailableNotifications] subCategoryId: ' + subCategoryId);
        // System.debug('--- [getAvailableNotifications] subCodeId: ' + subCodeId);
        // 1. Fetch current Case with required fields for Notification and Email logic
        Case currentCase = [SELECT Id, FEC_Customer_Type__c, FEC_Product_Type__c, 
                                   FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c, 
                                   FEC_Current_Case_Stage__c,
                                   FEC_SubCategory__r.Name, FEC_SubCode__r.Name,
                                   FEC_SubCategory__r.FEC_Code__c, FEC_SubCode__r.FEC_Code__c,
                                   FEC_Current_Case_Stage__r.Name,
                                   FEC_Account_or_Contract__r.FEC_Email__c,
                                   FEC_Interaction__r.FEC_Interaction_Email__c,
                                   FEC_Case_Email__c 
                            FROM Case WHERE Id = :caseId LIMIT 1];

        // System.debug('--- [getAvailableNotifications] currentCase: ' + currentCase);
                            
        // 2. Use helper method to calculate Target Email
        String targetEmail = getTargetEmailFromCase(currentCase);
        String caseCustomerType = currentCase.FEC_Customer_Type__c;
        // 3. Query Notification satisfying conditions
        //String emailChannel = FEC_ConstantCommon.EMAIL;
        
        // System.debug('--- [getAvailableNotifications] currentStage: ' + currentStage);
        // System.debug('--- [getAvailableNotifications] emailChannel: ' + emailChannel);
        String query = 'SELECT Id, Name, FEC_Customer_Type__c, ' +
                       //'FEC_Notification_Template__r.Name, ' +
                       'FEC_Target_Group__c ' +
                       'FROM FEC_Notification__c ' +
                       'WHERE FEC_Notification_Status__c = true ';
        
        String stageName = currentCase?.FEC_Current_Case_Stage__r?.Name;
        String subCategoryCode = currentCase?.FEC_SubCategory__r?.FEC_Code__c;
        String subCodeCode = currentCase?.FEC_SubCode__r?.FEC_Code__c;

        String stagePattern = String.isNotBlank(stageName) ? '%' + stageName + '%' : '';
        String subCategoryPattern = String.isNotBlank(subCategoryCode) ? '%' + subCategoryCode + '%' : '';
        String subCodePattern = String.isNotBlank(subCodeCode) ? '%' + subCodeCode + '%' : '';

        if (String.isNotBlank(stageId)) {
            query += ' AND FEC_Case_Stage__c LIKE :stagePattern';
        }         
        if (String.isNotBlank(productTypeId)) {
            query += ' AND FEC_Product_Type__c = :productTypeId';
        }
        if (String.isNotBlank(categoryId)) {
            query += ' AND FEC_Category__c = :categoryId';
        }
        if (String.isNotBlank(subCategoryId)) {
            query += ' AND FEC_SubCategory__c LIKE :subCategoryPattern';
        }
        if (String.isNotBlank(subCodeId)) {
            query += ' AND FEC_SubCode__c LIKE :subCodePattern';
        }

        List<FEC_Notification__c> queried = Database.query(query);
        System.debug('--- [getAvailableNotifications] queried: ' + queried);
        List<FEC_Notification__c> validNotifs = new List<FEC_Notification__c>();
        for (FEC_Notification__c notif : queried) {
            if (notificationMatchesCaseCustomerType(notif.FEC_Customer_Type__c, caseCustomerType)) {
                validNotifs.add(notif);
            }
        }
        System.debug('--- [getAvailableNotifications] validNotifs: ' + validNotifs);
        
        Set<Id> validNotifIds = new Set<Id>();
        for (FEC_Notification__c notif : validNotifs) {
            validNotifIds.add(notif.Id);
        }

        List<FEC_Notification_Template_Channel__c> templateChannels = new List<FEC_Notification_Template_Channel__c>();
        if (!validNotifIds.isEmpty()) {
            templateChannels = [
                SELECT Id, FEC_Notification__c, 
                       FEC_Notification_Channel__c, FEC_Notification_Channel__r.Name, 
                       FEC_Notification_Template__c, FEC_Notification_Template__r.Name 
                FROM FEC_Notification_Template_Channel__c 
                WHERE FEC_Notification__c IN :validNotifIds
            ];
        }

        Map<Id, List<Map<String, String>>> channelsByNotifId = new Map<Id, List<Map<String, String>>>();
        for (FEC_Notification_Template_Channel__c tc : templateChannels) {
            if (!channelsByNotifId.containsKey(tc.FEC_Notification__c)) {
                channelsByNotifId.put(tc.FEC_Notification__c, new List<Map<String, String>>());
            }
            channelsByNotifId.get(tc.FEC_Notification__c).add(new Map<String, String>{
                'channelId' => tc.FEC_Notification_Channel__c,
                'channelName' => tc.FEC_Notification_Channel__r.Name,
                'templateId' => tc.FEC_Notification_Template__c,
                'templateName' => tc.FEC_Notification_Template__r.Name
            });
        }
        
        List<Map<String, Object>> options = new List<Map<String, Object>>();
        
        for(FEC_Notification__c notif : validNotifs) {
                options.add(new Map<String, Object>{
                    'label' => notif.Name, 
                    'value' => notif.Id, 
                    'targetGroup' => notif.FEC_Target_Group__c, 
                    'targetEmail' => targetEmail,
                    'channels' => channelsByNotifId.containsKey(notif.Id) ? channelsByNotifId.get(notif.Id) : new List<Map<String, String>>()
                });
        }
        System.debug('--- [getAvailableNotifications] options: ' + options);
        return options;
    }

    @AuraEnabled
    public static List<User> searchInternalUsers(String searchTerm) {
        // Biến tìm kiếm đặc biệt cho Email: bắt buộc chuỗi tìm kiếm phải nằm trước dấu '@'
        String emailLikeTerm = '%' + searchTerm + '%@%';
        
        return [
            SELECT Id, Name, Username, Email 
            FROM User 
            WHERE IsActive = true 
            AND Email LIKE :emailLikeTerm 
            LIMIT 20 
        ];
    }

    @AuraEnabled
    public static void sendManualNotification(Id caseId, Id templateId, String toEmail, Id fecNotificationConfigId, String selectedChannel) {
        System.debug('--- [sendManualNotification] selectedChannel: ' + selectedChannel);
        User sendingUser = [
            SELECT Email, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String manualUserLocal = FEC_NotificationHistoryService.emailLocalPart(sendingUser.Email);
        String manualUserRole = sendingUser.UserRole != null ? sendingUser.UserRole.Name : null;

        Case c = [
            SELECT
                Id,
                FEC_Customer_Type__c,
                FEC_Stage_Name__c,
                FEC_Account_or_Contract__r.FEC_Email__c,
                FEC_Interaction__r.FEC_Interaction_Email__c,
                FEC_Case_Email__c,
                ContactId
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        FEC_Notification__c notifRule;
        if (fecNotificationConfigId != null) {
            List<FEC_Notification__c> rules = [
                SELECT Id, Name, FEC_Target_Group__c //FEC_Notification_Channel__r.Name
                FROM FEC_Notification__c
                WHERE Id = :fecNotificationConfigId
                LIMIT 1
            ];
            notifRule = rules.isEmpty() ? null : rules[0];
        } else {
            notifRule = null;
        }

        String channelLabel = String.isNotBlank(selectedChannel) ? selectedChannel : FEC_ConstantCommon.NOTIFICATION_CHANNEL_EMAIL;
        String targetGrp = (notifRule != null && String.isNotBlank(notifRule.FEC_Target_Group__c))
            ? notifRule.FEC_Target_Group__c
            : '';
        String notifRuleName = notifRule != null ? notifRule.Name : '';

        String targetEmail;
        if (String.isNotBlank(toEmail)) {
            targetEmail = toEmail;
        } else {
            targetEmail = getTargetEmailFromCase(c);
        }
        if (String.isBlank(targetEmail)) {
            FEC_NotificationHistoryService.insertRow(
                FEC_NotificationHistoryService.buildRow(
                    caseId,
                  notifRule != null ? notifRule.Id : null,
                    c.FEC_Stage_Name__c,
                    null,
                    notifRuleName,
                    channelLabel,
                    targetGrp,
                    FEC_NotificationHistoryService.SEND_TYPE_MANUAL,
                    FEC_NotificationHistoryService.SEND_STATUS_FAILURE,
                    System.Label.FEC_Email_No_Valid_Address_Found,
                    manualUserLocal,
                    manualUserRole,
                    System.now()
                )
            );
            throw new AuraHandledException(System.Label.FEC_Email_No_Valid_Address_Found);
        }
        if (String.isBlank(templateId)) {
            FEC_NotificationHistoryService.insertRow(
                FEC_NotificationHistoryService.buildRow(
                    caseId,
                  notifRule != null ? notifRule.Id : null,
                    c.FEC_Stage_Name__c,
                    null,
                    notifRuleName,
                    channelLabel,
                    targetGrp,
                    FEC_NotificationHistoryService.SEND_TYPE_MANUAL,
                    FEC_NotificationHistoryService.SEND_STATUS_FAILURE,
                    System.Label.FEC_Template_Not_Found,
                    manualUserLocal,
                    manualUserRole,
                    System.now()
                )
            );
            throw new AuraHandledException(System.Label.FEC_Template_Not_Found);
        }

        FEC_Template__c template;
        try {
            template = FEC_TemplateController.getTemplate(templateId);
        } catch (Exception exLoadTpl) {
            FEC_NotificationHistoryService.insertRow(
                FEC_NotificationHistoryService.buildRow(
                    caseId,
                  notifRule != null ? notifRule.Id : null,
                    c.FEC_Stage_Name__c,
                    null,
                    notifRuleName,
                    channelLabel,
                    targetGrp,
                    FEC_NotificationHistoryService.SEND_TYPE_MANUAL,
                    FEC_NotificationHistoryService.SEND_STATUS_FAILURE,
                    exLoadTpl.getMessage(),
                    manualUserLocal,
                    manualUserRole,
                    System.now()
                )
            );
            throw new AuraHandledException(exLoadTpl.getMessage());
        }

        String senderEmail = '';
        FEC_System_Config__c systemConfig = FEC_System_Config__c.getOrgDefaults();
        if (String.isNotBlank(systemConfig?.FEC_Sender_Email__c)) {
            senderEmail = systemConfig.FEC_Sender_Email__c;
        }

        String subject = String.isNotBlank(template.FEC_Subject_Line__c)
            ? template.FEC_Subject_Line__c
            : FEC_ConstantCommon.NOTIFICATION_SUBJECT;
        System.debug('--- [sendManualNotification] channelLabel: ' + channelLabel);
        System.debug('--- [sendManualNotification]channelLabel == FEC_ConstantCommon.NOTIFICATION_CHANNEL_SF_APP: ' + (channelLabel == FEC_ConstantCommon.NOTIFICATION_CHANNEL_SF_APP));
        
        if (channelLabel == FEC_ConstantCommon.NOTIFICATION_CHANNEL_SF_APP) {
            List<User> targetUsers = [SELECT Id FROM User WHERE Email = :targetEmail AND IsActive = true LIMIT 1];
            if (targetUsers.isEmpty()) {
                FEC_NotificationHistoryService.insertRow(
                    FEC_NotificationHistoryService.buildRow(
                        caseId,
                        notifRule != null ? notifRule.Id : null,
                        c.FEC_Stage_Name__c,
                        template.Name,
                        notifRuleName,
                        channelLabel,
                        targetGrp,
                        FEC_NotificationHistoryService.SEND_TYPE_MANUAL,
                        FEC_NotificationHistoryService.SEND_STATUS_FAILURE,
                        FEC_ConstantCommon.TARGET_USER_NOT_FOUND,
                        manualUserLocal,
                        manualUserRole,
                        System.now()
                    )
                );
                throw new AuraHandledException(FEC_ConstantCommon.TARGET_USER_NOT_FOUND);
            }
            Id targetUserId = targetUsers[0].Id;

            EmailInfo previewContent = new EmailInfo(caseId, targetEmail, subject, '', template.FEC_Body__c, '');
            bulkResolveMergeFields(new List<EmailInfo>{ previewContent }, senderEmail);

            String resolvedSubject = previewContent.subject;
            String resolvedBody = previewContent.body;
            if (String.isNotBlank(resolvedBody)) {
                resolvedBody = resolvedBody.replaceAll(FEC_ConstantCommon.BR_TAG_REGEX, '\n');
                resolvedBody = resolvedBody.replaceAll(FEC_ConstantCommon.P_TAG_REGEX, '\n');
                resolvedBody = resolvedBody.replaceAll(FEC_ConstantCommon.HTML_TAG_REGEX, '');
                resolvedBody = resolvedBody.unescapeHtml4();
            }

            CustomNotificationType customNotificationType;
            try {
                customNotificationType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Custom_Notification' LIMIT 1];
            } catch (Exception e) {
                throw new AuraHandledException(FEC_ConstantCommon.CUSTOM_NOTIFICATION_TYPE_NOT_FOUND);
            }

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(resolvedSubject);
            notification.setBody(resolvedBody);
            notification.setNotificationTypeId(customNotificationType.Id);
            notification.setTargetId(caseId);

            try {
                notification.send(new Set<String>{ targetUserId });
                FEC_NotificationHistoryService.insertRow(
                    FEC_NotificationHistoryService.buildRow(
                        caseId,
                        notifRule != null ? notifRule.Id : null,
                        c.FEC_Stage_Name__c,
                        template.Name,
                        notifRuleName,
                        channelLabel,
                        targetGrp,
                        FEC_NotificationHistoryService.SEND_TYPE_MANUAL,
                        FEC_NotificationHistoryService.SEND_STATUS_SUCCESS,
                        null,
                        manualUserLocal,
                        manualUserRole,
                        System.now()
                    )
                );
            } catch (Exception e) {
                FEC_NotificationHistoryService.insertRow(
                    FEC_NotificationHistoryService.buildRow(
                        caseId,
                        notifRule != null ? notifRule.Id : null,
                        c.FEC_Stage_Name__c,
                        template.Name,
                        notifRuleName,
                        channelLabel,
                        targetGrp,
                        FEC_NotificationHistoryService.SEND_TYPE_MANUAL,
                        FEC_NotificationHistoryService.SEND_STATUS_FAILURE,
                        e.getMessage(),
                        manualUserLocal,
                        manualUserRole,
                        System.now()
                    )
                );
                throw new AuraHandledException(FEC_ConstantCommon.NOTIFICATION_SEND_FAILED + e.getMessage());
            }

        } else {
            try {
                executeSendEmail(caseId, senderEmail, targetEmail, subject, template?.FEC_Enhanced_Letterhead__r?.FEC_Header__c, template.FEC_Body__c, template?.FEC_Enhanced_Letterhead__r?.FEC_Footer__c, templateId);
                FEC_NotificationHistoryService.insertRow(
                    FEC_NotificationHistoryService.buildRow(
                        caseId,
                      notifRule != null ? notifRule.Id : null,
                        c.FEC_Stage_Name__c,
                        template.Name,
                        notifRuleName,
                        channelLabel,
                        targetGrp,
                        FEC_NotificationHistoryService.SEND_TYPE_MANUAL,
                        FEC_NotificationHistoryService.SEND_STATUS_SUCCESS,
                        null,
                        manualUserLocal,
                        manualUserRole,
                        System.now()
                    )
                );
            } catch (Exception e) {
                FEC_NotificationHistoryService.insertRow(
                    FEC_NotificationHistoryService.buildRow(
                        caseId,
                      notifRule != null ? notifRule.Id : null,
                        c.FEC_Stage_Name__c,
                        template != null ? template.Name : null,
                        notifRuleName,
                        channelLabel,
                        targetGrp,
                        FEC_NotificationHistoryService.SEND_TYPE_MANUAL,
                        FEC_NotificationHistoryService.SEND_STATUS_FAILURE,
                        e.getMessage(),
                        manualUserLocal,
                        manualUserRole,
                        System.now()
                    )
                );
                throw new AuraHandledException(System.Label.FEC_Email_Send_Error + ': ' + e.getMessage());
            }
        }
    }

    /**
     * Resolves {{{Object.Field}}} merge fields for manual and bulk emails dynamically.
     * Extracts tokens securely across ALL emails and builds single bulk SOQL queries to avoid DML limits!
     */
    private static void bulkResolveMergeFields(List<EmailInfo> emailsToSend, String fromEmail) {
        Set<String> caseFields = new Set<String>();
        Set<String> userFields = new Set<String>();
        Set<String> addInfoFields = new Set<String>();
        Set<String> custHistoryFields = new Set<String>();
        Set<Id> caseIds = new Set<Id>();

        // Pass 1: Extract all fields and Case Ids
        for (EmailInfo info : emailsToSend) {
            if (info.caseId != null) caseIds.add(info.caseId);
            // Sanitize and Normalize ANY variation: {{...}}, {{{...}}}, {{{{...}}}} → exactly {{{...}}}
            if (String.isNotBlank(info.body)) {
                info.body = PATTERN_FLEXIBLE.matcher(info.body).replaceAll(FEC_ConstantCommon.MERGE_FIELD_NORMALIZE_REPLACEMENT);
                
            }
            if (String.isNotBlank(info.subject)) {
                info.subject = PATTERN_FLEXIBLE.matcher(info.subject).replaceAll(FEC_ConstantCommon.MERGE_FIELD_NORMALIZE_REPLACEMENT);
            }
            
            if (String.isNotBlank(info.body) && info.body.contains(FEC_ConstantCommon.MERGE_FIELD_OPEN)) {
                Matcher m = PATTERN_MERGE.matcher(info.body);
                while (m.find()) {
                    List<String> parts = m.group(1).split('\\.');
                    if (parts.size() == 2) {
                        String objName = parts[0]; String fieldName = parts[1];
                        if (objName.equalsIgnoreCase('Case')) caseFields.add(fieldName);
                        else if (objName.equalsIgnoreCase('User')) userFields.add(fieldName);
                        else if (objName.equalsIgnoreCase('FEC_Additional_Info__c')) addInfoFields.add(fieldName);
                        else if (objName.equalsIgnoreCase('FEC_Customer_History__c')) custHistoryFields.add(fieldName);
                    }
                }
            }
            if (String.isNotBlank(info.subject) && info.subject.contains(FEC_ConstantCommon.MERGE_FIELD_OPEN)) {
                Matcher m = PATTERN_MERGE.matcher(info.subject);
                while (m.find()) {
                    List<String> parts = m.group(1).split('\\.');
                    if (parts.size() == 2) {
                        String objName = parts[0]; String fieldName = parts[1];
                        if (objName.equalsIgnoreCase('Case')) caseFields.add(fieldName);
                        else if (objName.equalsIgnoreCase('User')) userFields.add(fieldName);
                        else if (objName.equalsIgnoreCase('FEC_Additional_Info__c')) addInfoFields.add(fieldName);
                        else if (objName.equalsIgnoreCase('FEC_Customer_History__c')) custHistoryFields.add(fieldName);
                    }
                }
            }
        }

        if (caseFields.isEmpty() && userFields.isEmpty() && addInfoFields.isEmpty() && custHistoryFields.isEmpty()) {
            return;
        }

        // Phase 2: DML Grouping
        Map<Id, Case> caseMap = new Map<Id, Case>();
        User senderUser = null;
        Map<Id, FEC_Additional_Info__c> addInfoMap = new Map<Id, FEC_Additional_Info__c>();
        Map<Id, FEC_Customer_History__c> custHistoryMap = new Map<Id, FEC_Customer_History__c>();

        if (!caseFields.isEmpty() && !caseIds.isEmpty()) {
            String qCase = 'SELECT Id, ' + String.join(new List<String>(caseFields), ', ') + ' FROM Case WHERE Id IN :caseIds';
            try {
                for(Case c : Database.query(qCase)) { caseMap.put(c.Id, c); }
            } catch (Exception e) {}
        }

        if (!userFields.isEmpty() && String.isNotBlank(fromEmail)) {
            String qUser = 'SELECT Id, ' + String.join(new List<String>(userFields), ', ') + ' FROM User WHERE Email = :fromEmail LIMIT 1';
            try {
                List<User> usList = Database.query(qUser);
                if (!usList.isEmpty()) senderUser = usList[0];
            } catch (Exception e) {}
        }

        if (!addInfoFields.isEmpty() && !caseIds.isEmpty()) {
            String qAddInfo = 'SELECT Id, FEC_Case__c, ' + String.join(new List<String>(addInfoFields), ', ') + ' FROM FEC_Additional_Info__c WHERE FEC_Case__c IN :caseIds ORDER BY CreatedDate ASC';
            try {
                for(FEC_Additional_Info__c info : Database.query(qAddInfo)) {
                    addInfoMap.put(info.FEC_Case__c, info); 
                }
            } catch (Exception e) {}
        }

        if (!custHistoryFields.isEmpty() && !caseIds.isEmpty()) {
            String qCustHist = 'SELECT Id, FEC_Case__c, ' + String.join(new List<String>(custHistoryFields), ', ') + ' FROM FEC_Customer_History__c WHERE FEC_Case__c IN :caseIds ORDER BY CreatedDate ASC';
            try {
                for(FEC_Customer_History__c hist : Database.query(qCustHist)) {
                    custHistoryMap.put(hist.FEC_Case__c, hist); 
                }
            } catch (Exception e) {}
        }

        // Phase 3: Replace
        for (EmailInfo info : emailsToSend) {
            if(String.isNotBlank(info.body) && info.body.contains(FEC_ConstantCommon.MERGE_FIELD_OPEN)) {
                info.body = performReplacements(info.body, info.caseId, caseMap, senderUser, addInfoMap, custHistoryMap);
            }
            if(String.isNotBlank(info.subject) && info.subject.contains(FEC_ConstantCommon.MERGE_FIELD_OPEN)) {
                info.subject = performReplacements(info.subject, info.caseId, caseMap, senderUser, addInfoMap, custHistoryMap);
            }
        }
    }

    private static String performReplacements(String text, Id caseId, Map<Id, Case> caseMap, User senderUser, Map<Id, FEC_Additional_Info__c> addInfoMap, Map<Id, FEC_Customer_History__c> custHistoryMap) {
        Matcher m = PATTERN_MERGE.matcher(text);
        Set<String> uniqueTokens = new Set<String>();
        while(m.find()) { uniqueTokens.add(m.group(1)); }

        for(String token : uniqueTokens) {
            String fullToken = FEC_ConstantCommon.MERGE_FIELD_OPEN + token + FEC_ConstantCommon.MERGE_FIELD_CLOSE;
            List<String> parts = token.split('\\.');
            String resolvedValue = '';
            
            if(parts.size() == 2) {
                String objName = parts[0];
                String fieldName = parts[1];
                sObject targetRef = null;

                if (objName.equalsIgnoreCase('Case') && caseMap.containsKey(caseId)) targetRef = caseMap.get(caseId);
                else if (objName.equalsIgnoreCase('User') && senderUser != null) targetRef = senderUser;
                else if (objName.equalsIgnoreCase('FEC_Additional_Info__c') && addInfoMap.containsKey(caseId)) targetRef = addInfoMap.get(caseId);
                else if (objName.equalsIgnoreCase('FEC_Customer_History__c') && custHistoryMap.containsKey(caseId)) targetRef = custHistoryMap.get(caseId);

                if (targetRef != null) {
                    try {
                        Object val = targetRef.get(fieldName);
                        resolvedValue = val != null ? String.valueOf(val) : '';
                    } catch (Exception e) {}
                }
            }
            text = text.replace(fullToken, resolvedValue);
        }
        return text;
    }

    // =========================================================
    // 2. HÀM XỬ LÝ GỬI EMAIL BULK CHUẨN BEST PRACTICE (Dùng cho Trigger)
    // =========================================================
    public static void executeSendEmailsBulk(List<EmailInfo> emailsToSend, String fromEmail) {
        executeSendEmailsBulk(emailsToSend, fromEmail, null);
    }

    public static void executeSendEmailsBulk(
        List<EmailInfo> emailsToSend,
        String fromEmail,
        List<RoutingEmailHistoryInput> historyInputs
    ) {

        if (emailsToSend == null || emailsToSend.isEmpty()) return;

        // NEW: Resolve Merge Fields natively for the entire Bulk!
        bulkResolveMergeFields(emailsToSend, fromEmail);

        // 1. Chỉ Query OrgWideEmailAddress 1 LẦN DUY NHẤT
        Id orgWideEmailId = null;
        if (String.isNotBlank(fromEmail)) {
            List<OrgWideEmailAddress> orgEmails = [
                SELECT Id FROM OrgWideEmailAddress 
                WHERE Address = :fromEmail LIMIT 1
            ];
            if (!orgEmails.isEmpty()) {
                orgWideEmailId = orgEmails[0].Id;
            }
        }

        // Bulk query ContentDocumentLink for template attachments
        Set<Id> templateIds = new Set<Id>();
        for (EmailInfo info : emailsToSend) {
            if (info.templateId != null) templateIds.add(info.templateId);
        }
        Map<Id, List<ContentVersion>> templateAttachments = new Map<Id, List<ContentVersion>>();
        if (!templateIds.isEmpty()) {
            Map<Id, Id> docToTemplate = new Map<Id, Id>();
            for (ContentDocumentLink link : [
                SELECT ContentDocumentId, LinkedEntityId, ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink WHERE LinkedEntityId IN :templateIds
            ]) {
                docToTemplate.put(link.ContentDocument.LatestPublishedVersionId, link.LinkedEntityId);
            }
            if (!docToTemplate.isEmpty()) {
                for (ContentVersion cv : [
                    SELECT Id, Title, FileExtension, VersionData
                    FROM ContentVersion WHERE Id IN :docToTemplate.keySet()
                ]) {
                    Id tId = docToTemplate.get(cv.Id);
                    if (!templateAttachments.containsKey(tId)) templateAttachments.put(tId, new List<ContentVersion>());
                    templateAttachments.get(tId).add(cv);
                }
            }
        }

        List<Messaging.SingleEmailMessage> mailList = new List<Messaging.SingleEmailMessage>();
        List<EmailMessage> emailMessageLogs = new List<EmailMessage>();

        // 2. Gom dữ liệu vào List thay vì thực thi ngay
        for (EmailInfo info : emailsToSend) {
            // Build Email
            String header = FEC_NotificationService.inlineImages(info.header);
            //System.debug('--- [executeSendEmailsBulk] header=' + header);
            String footer = FEC_NotificationService.inlineImages(info.footer);
            //System.debug('--- [executeSendEmailsBulk] footer=' + footer);
            String fullBody = header + info.body + footer;
            //System.debug('--- [executeSendEmailsBulk] fullBody=' + fullBody);
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(info.toEmail.split(','));
            mail.setSubject(info.subject);
            mail.setHtmlBody(info.body != null ? fullBody?.replace('\n', '<br/>') : '');
            mail.setWhatId(info.caseId);
            mail.setSaveAsActivity(false); 
            
            if (orgWideEmailId != null) {
                mail.setOrgWideEmailAddressId(orgWideEmailId);
            }

            // Attach files from template
            if (info.templateId != null && templateAttachments.containsKey(info.templateId)) {
                List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
                for (ContentVersion cv : templateAttachments.get(info.templateId)) {
                    Messaging.EmailFileAttachment att = new Messaging.EmailFileAttachment();
                    att.setFileName(cv.Title + (String.isNotBlank(cv.FileExtension) ? '.' + cv.FileExtension : ''));
                    att.setBody(cv.VersionData);
                    attachments.add(att);
                }
                if (!attachments.isEmpty()) mail.setFileAttachments(attachments);
            }

            mailList.add(mail);

            // Build Audit Log (EmailMessage)
            EmailMessage em = new EmailMessage();
            em.ParentId = info.caseId;
            em.FromAddress = fromEmail;
            em.ToAddress = info.toEmail;
            em.Subject = info.subject;
            em.HtmlBody = info.body;
            em.TextBody = info.body != null ? info.body.replaceAll('<[^>]+>', '') : '';
            em.Incoming = false;
            em.Status = '3'; // 3 = Sent
            em.MessageDate = Datetime.now();
            emailMessageLogs.add(em);
        }

        // 3. Thực thi DML và Callout 1 LẦN DUY NHẤT
        List<Messaging.SendEmailResult> sendResults = new List<Messaging.SendEmailResult>();
        if (!mailList.isEmpty()) {
            // false: Gửi các email không lỗi ngay cả khi có 1 email bị lỗi
            sendResults = Messaging.sendEmail(mailList, false);
        }

        if (
            historyInputs != null &&
            historyInputs.size() == mailList.size() &&
            !mailList.isEmpty()
        ) {
            List<FEC_Notification_History__c> histRows = new List<FEC_Notification_History__c>();
            for (Integer i = 0; i < historyInputs.size(); i++) {
                RoutingEmailHistoryInput hi = historyInputs[i];
                Boolean ok = (i < sendResults.size()) && sendResults[i].isSuccess();
                String failMsg = ok ? null : ((i < sendResults.size()) ? FEC_NotificationHistoryService.joinSendEmailErrors(sendResults[i]) : null);
                if (!ok && String.isBlank(failMsg)) {
                    failMsg = 'Email send failed';
                }
                histRows.add(
                    FEC_NotificationHistoryService.buildRow(
                        hi.caseId,
                        hi.notificationRuleId,
                        hi.stageName,
                        hi.templateDisplayName,
                        hi.notificationRuleName,
                        hi.channelName,
                        hi.targetGroup,
                        FEC_NotificationHistoryService.SEND_TYPE_AUTO,
                        ok ? FEC_NotificationHistoryService.SEND_STATUS_SUCCESS : FEC_NotificationHistoryService.SEND_STATUS_FAILURE,
                        failMsg,
                        FEC_NotificationHistoryService.SEND_USER_SYSTEM,
                        null,
                        System.now()
                    )
                );
            }
            FEC_NotificationHistoryService.insertRows(histRows);
        }

        if (!emailMessageLogs.isEmpty()) {
            try {
                insert emailMessageLogs;
            } catch (Exception e) {
                System.debug('Lỗi tạo EmailMessage bulk log: ' + e.getMessage());
            }
        }
    }

    // =========================================================
    // 3. HÀM CHO LWC (Cập nhật để gọi chung hàm Bulk ở trên)
    // =========================================================
    public static void executeSendEmail(Id caseId, String fromEmail, String toEmail, String subject, String header, String body, String footer, Id templateId) {
        EmailInfo singleEmail = new EmailInfo(caseId, toEmail, subject, header, body, footer, templateId);
        executeSendEmailsBulk(new List<EmailInfo>{ singleEmail }, fromEmail);
    }

    @AuraEnabled
    public static FEC_Template__c previewTemplate(Id caseId, Id templateId) {
        FEC_Template__c template = FEC_TemplateController.getTemplate(templateId);
        if (template != null && String.isNotBlank(caseId)) {
            String subject = String.isNotBlank(template.FEC_Subject_Line__c) ? template.FEC_Subject_Line__c : FEC_ConstantCommon.NOTIFICATION_SUBJECT;
            String body = template.FEC_Body__c;

            String senderEmail = '';
            FEC_System_Config__c systemConfig = FEC_System_Config__c.getOrgDefaults();
            if (String.isNotBlank(systemConfig?.FEC_Sender_Email__c)) {
                senderEmail = systemConfig.FEC_Sender_Email__c;
            }

            EmailInfo previewEmail = new EmailInfo(caseId, '', subject, '', body, '');
            bulkResolveMergeFields(new List<EmailInfo>{ previewEmail }, senderEmail);

            template.FEC_Subject_Line__c = previewEmail.subject;
            template.FEC_Body__c = previewEmail.body;
        }
        return template;
    }
}