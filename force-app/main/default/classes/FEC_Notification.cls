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
}