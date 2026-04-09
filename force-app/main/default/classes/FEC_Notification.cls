public without sharing class FEC_Notification {
    
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
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
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
    public static List<Map<String, String>> getAvailableNotifications(Id caseId) {
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

        // 3. Query Notification satisfying conditions
        List<FEC_Notification__c> validNotifs = [SELECT Id, Name, FEC_Notification_Template__c, 
                                                    FEC_Notification_Template__r.Name,
                                                    FEC_Notification_Channel__r.Name,
                                                    FEC_Target_Group__c
                                             FROM FEC_Notification__c 
                                             WHERE FEC_Customer_Type__c = :currentCase.FEC_Customer_Type__c
                                             AND FEC_Product_Type__c = :currentCase.FEC_Product_Type__c
                                             AND FEC_Category__c = :currentCase.FEC_Category__c
                                             AND FEC_SubCategory__c = :currentCase.FEC_SubCategory__c
                                             AND FEC_SubCode__c = :currentCase.FEC_SubCode__c
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

    // =========================================================
    // 2. HÀM XỬ LÝ GỬI EMAIL BULK CHUẨN BEST PRACTICE (Dùng cho Trigger)
    // =========================================================
    public static void executeSendEmailsBulk(List<EmailInfo> emailsToSend, String fromEmail) {
        if (emailsToSend == null || emailsToSend.isEmpty()) return;

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

}