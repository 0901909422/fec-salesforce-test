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

    @AuraEnabled
    public static FEC_Notification__c getNotificationById(Id recordId) {
    try {
      FEC_Notification__c noti = [
        SELECT Id, Name, RecordType.Name, RecordTypeId, RecordType.DeveloperName, FEC_Target_Group__c, FEC_Notification_Channel__c FROM FEC_Notification__c
        WHERE Id = :recordId
      ];

      if (noti != null) {
        return noti;
      }

      return null;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
}