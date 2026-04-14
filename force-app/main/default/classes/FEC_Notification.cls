public without sharing class FEC_Notification {

    // Compile Pattern 1 lần ở class level để tái sử dụng
    private static final Pattern PATTERN_MERGE  = Pattern.compile(FEC_ConstantCommon.PATTERN_MERGE_FIELD);
    private static final Pattern PATTERN_DOUBLE = Pattern.compile(FEC_ConstantCommon.PATTERN_DOUBLE_BRACE);

    public class EmailInfo {
        public Id caseId;
        public String toEmail;
        public String subject;
        public String body;

        public EmailInfo(Id caseId, String toEmail, String subject, String body) {
            this.caseId = caseId;
            this.toEmail = toEmail;
            this.subject = subject;
            this.body = body;
        }
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
                       FEC_Target_Group__c, FEC_Notification_Channel__c, 
                       FEC_Channel__c, 
                       FEC_Product_Type__c, FEC_Product_Type__r.Name,
                       FEC_Category__c, FEC_Category__r.Name,
                       FEC_SubCategory__c, FEC_SubCategory__r.Name,
                       FEC_SubCode__c, FEC_SubCode__r.Name,
                       FEC_Current_Status__c, FEC_Changed_Status__c,
                       FEC_Notification_Template__c,
                       FEC_Assigned_to_Queue__c
                FROM FEC_Notification__c
                WHERE Id = :recordId
            ];
            result.put('record', noti);

            // 2. Fetch Channel names for the Multi-Select Channel lookup
            if (String.isNotBlank(noti.FEC_Channel__c)) {
                List<String> channelIds = noti.FEC_Channel__c.split(',');
                result.put('channels', [SELECT Id, Name FROM FEC_Channel__c WHERE Id IN :channelIds]);
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

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailableNotifications(Id caseId, String productTypeId, String categoryId, String subCategoryId, String subCodeId) {
        // 1. Fetch current Case with required fields for Notification and Email logic
        Case currentCase = [SELECT Id, FEC_Customer_Type__c, FEC_Product_Type__c, 
                                   FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c, 
                                   FEC_Current_Case_Stage__c,
                                   FEC_Account_or_Contract__r.FEC_Email__c,
                                   FEC_Interaction__r.FEC_Interaction_Email__c,
                                   FEC_Case_Email__c 
                            FROM Case WHERE Id = :caseId LIMIT 1];
                            
        // 2. Use helper method to calculate Target Email
        String targetEmail = getTargetEmailFromCase(currentCase);

        String finalProductType = String.isNotBlank(productTypeId) ? productTypeId : currentCase.FEC_Product_Type__c;
        String finalCategory = String.isNotBlank(categoryId) ? categoryId : currentCase.FEC_Category__c;
        String finalSubCategory = String.isNotBlank(subCategoryId) ? subCategoryId : currentCase.FEC_SubCategory__c;
        String finalSubCode = String.isNotBlank(subCodeId) ? subCodeId : currentCase.FEC_SubCode__c;

        // 3. Query Notification satisfying conditions
        List<FEC_Notification__c> validNotifs = [SELECT Id, Name, FEC_Notification_Template__c, 
                                                    FEC_Notification_Template__r.Name,
                                                    FEC_Notification_Channel__r.Name,
                                                    FEC_Target_Group__c
                                             FROM FEC_Notification__c 
                                             WHERE FEC_Product_Type__c = :finalProductType
                                             AND FEC_Category__c = :finalCategory
                                             AND FEC_SubCategory__c = :finalSubCategory
                                             AND FEC_SubCode__c = :finalSubCode
                                             AND FEC_Case_Stage__c = :currentCase.FEC_Current_Case_Stage__c
                                             AND FEC_Notification_Status__c = true 
                                             AND FEC_Notification_Channel__r.Name = :FEC_ConstantCommon.EMAIL];
        
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        for(FEC_Notification__c notif : validNotifs) {
                options.add(new Map<String, String>{
                    'label' => notif.Name, 
                    'value' => notif.Id, 
                    'templateId' => notif.FEC_Notification_Template__c, 
                    'channel' => notif.FEC_Notification_Channel__r.Name,
                    'targetGroup' => notif.FEC_Target_Group__c, 
                    'targetEmail' => targetEmail 
                });
        }
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
    public static void sendManualEmail(Id caseId, Id templateId, String toEmail) {
        // 1. Query Case
        Case c = [SELECT Id, FEC_Customer_Type__c, 
                         FEC_Account_or_Contract__r.FEC_Email__c,
                         FEC_Interaction__r.FEC_Interaction_Email__c,
                         FEC_Case_Email__c, ContactId
                  FROM Case WHERE Id = :caseId LIMIT 1];
                  
        // 2. Use helper method to extract email
        String targetEmail;
        if (String.isNotBlank(toEmail)) {
            targetEmail = toEmail;
        } else {
            targetEmail = getTargetEmailFromCase(c);
        }
        if(String.isBlank(targetEmail)) {
            throw new AuraHandledException(System.Label.FEC_Email_No_Valid_Address_Found);
        }
        if(String.isBlank(templateId)) {
            throw new AuraHandledException(System.Label.FEC_Template_Not_Found);
        }

        FEC_Template__c template = FEC_TemplateController.getTemplate(templateId);  
        String senderEmail = '';
        FEC_System_Config__c systemConfig = FEC_System_Config__c.getOrgDefaults();
        if (String.isNotBlank(systemConfig?.FEC_Sender_Email__c)) {
            senderEmail = systemConfig.FEC_Sender_Email__c;
        }

        String subject = String.isNotBlank(template.FEC_Subject_Line__c) ? template.FEC_Subject_Line__c : FEC_ConstantCommon.NOTIFICATION_SUBJECT;

        try {
            executeSendEmail(caseId, senderEmail, targetEmail, subject, template.FEC_Body__c);
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Email_Send_Error + ': ' + e.getMessage());
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
            // Normalize {{...}} → {{{...}}} để xử lý chung
            if (String.isNotBlank(info.body)) {
                info.body = PATTERN_DOUBLE.matcher(info.body).replaceAll(FEC_ConstantCommon.MERGE_FIELD_NORMALIZE_REPLACEMENT);
            }
            if (String.isNotBlank(info.subject)) {
                info.subject = PATTERN_DOUBLE.matcher(info.subject).replaceAll(FEC_ConstantCommon.MERGE_FIELD_NORMALIZE_REPLACEMENT);
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

        List<Messaging.SingleEmailMessage> mailList = new List<Messaging.SingleEmailMessage>();
        List<EmailMessage> emailMessageLogs = new List<EmailMessage>();

        // 2. Gom dữ liệu vào List thay vì thực thi ngay
        for (EmailInfo info : emailsToSend) {
            // Build Email
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(info.toEmail.split(','));
            mail.setSubject(info.subject);
            mail.setHtmlBody(info.body != null ? info.body.replace('\n', '<br/>') : '');
            mail.setWhatId(info.caseId);
            mail.setSaveAsActivity(false); 
            
            if (orgWideEmailId != null) {
                mail.setOrgWideEmailAddressId(orgWideEmailId);
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
        if (!mailList.isEmpty()) {
            // false: Gửi các email không lỗi ngay cả khi có 1 email bị lỗi
            Messaging.sendEmail(mailList, false); 
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
    public static void executeSendEmail(Id caseId, String fromEmail, String toEmail, String subject, String body) {
        EmailInfo singleEmail = new EmailInfo(caseId, toEmail, subject, body);
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

            EmailInfo previewEmail = new EmailInfo(caseId, '', subject, body);
            bulkResolveMergeFields(new List<EmailInfo>{ previewEmail }, senderEmail);

            template.FEC_Subject_Line__c = previewEmail.subject;
            template.FEC_Body__c = previewEmail.body;
        }
        return template;
    }
}