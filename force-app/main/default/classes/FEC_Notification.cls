public without sharing class FEC_Notification {
    
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

  //   @AuraEnabled
  //   public static FEC_Notification__c getNotificationById(Id recordId) {
  //   try {
  //     FEC_Notification__c noti = [
  //       SELECT Id, Name, RecordType.Name, RecordTypeId, RecordType.DeveloperName, FEC_Target_Group__c, FEC_Notification_Channel__c FROM FEC_Notification__c
  //       WHERE Id = :recordId
  //     ];

  //     if (noti != null) {
  //       return noti;
  //     }

  //     return null;
  //   } catch (Exception e) {
  //     throw new AuraHandledException(e.getMessage());
  //   }
  // }

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
        if(c.FEC_Customer_Type__c == 'Existing') {
            targetEmail = c.FEC_Account_or_Contract__r.FEC_Email__c;
        } else if (c.FEC_Customer_Type__c == 'Non-existing') {
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
                                             AND FEC_Notification_Channel__r.Name = 'Email'];
        
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
    public static void sendManualEmail(Id caseId, Id templateId) {
        // 1. Query Case
        Case c = [SELECT Id, FEC_Customer_Type__c, 
                         FEC_Account_or_Contract__r.FEC_Email__c,
                         FEC_Interaction__r.FEC_Interaction_Email__c,
                         FEC_Case_Email__c, ContactId
                  FROM Case WHERE Id = :caseId LIMIT 1];
                  
        // 2. Use helper method to extract email
        String targetEmail = getTargetEmailFromCase(c);
        
        if(String.isBlank(targetEmail)) {
            throw new AuraHandledException('Không tìm thấy email hợp lệ để gửi.');
        }
        if(String.isBlank(templateId)) {
            throw new AuraHandledException('Không tìm thấy template.');
        }

        FEC_Template__c template = FEC_TemplateController.getTemplate(templateId);  
        List<OrgWideEmailAddress> owaList = [
                    SELECT Id, Address 
                    FROM OrgWideEmailAddress 
                    WHERE Address = 'minhtung2108@gmail.com'
                    LIMIT 1
                ];
                
        Id emailId = owaList.isEmpty() ? null : owaList[0].Id;

        // 3. Send email
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{targetEmail});
        mail.setHtmlBody(template.FEC_Body__c);
        mail.setWhatId(caseId); 
        if (emailId != null) {
          mail.setOrgWideEmailAddressId(emailId);
        }
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}