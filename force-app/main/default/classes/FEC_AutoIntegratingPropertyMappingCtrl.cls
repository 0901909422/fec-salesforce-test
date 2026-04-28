public with sharing class FEC_AutoIntegratingPropertyMappingCtrl {

    @AuraEnabled
    public static Map<String, Object> getRecords(String sourePropertyId) {
        List<FEC_Auto_Intetgrating_Property_Mapping__c> records = [
            SELECT Id, Name, FEC_Is_Mandatory__c, FEC_Property_ID__c,
                   FEC_Property_Name_VN__c, FEC_Property_Type__c,
                   FEC_Soure_Property_ID__c, FEC_Status__c, FEC_Channel__c,
                   FEC_Sync_Status__c, CreatedDate, LastModifiedDate
            FROM FEC_Auto_Intetgrating_Property_Mapping__c
            WHERE FEC_Soure_Property_ID__c = :sourePropertyId
              AND FEC_Is_Deleted__c = false
            ORDER BY CreatedDate DESC
        ];

        Map<String, Object> result = new Map<String, Object>();
        result.put('records', records);
        result.put('totalRecords', records.size());
        return result;
    }

    @AuraEnabled
    public static FEC_Auto_Intetgrating_Property_Mapping__c createRecord(FEC_Auto_Intetgrating_Property_Mapping__c record) {
        checkDuplicate(record.FEC_Property_ID__c, record.FEC_Channel__c, record.FEC_Soure_Property_ID__c, null);
        insert record;
        return record;
    }

    @AuraEnabled
    public static FEC_Auto_Intetgrating_Property_Mapping__c updateRecord(FEC_Auto_Intetgrating_Property_Mapping__c record) {
        checkDuplicate(record.FEC_Property_ID__c, record.FEC_Channel__c, record.FEC_Soure_Property_ID__c, record.Id);
        update record;
        return record;
    }

    private static void checkDuplicate(String propertyId, Id channel, String sourcePropertyId, Id excludeId) {
        List<FEC_Auto_Intetgrating_Property_Mapping__c> existing = [
            SELECT Id FROM FEC_Auto_Intetgrating_Property_Mapping__c
            WHERE FEC_Property_ID__c = :propertyId
              AND FEC_Channel__c = :channel
              AND FEC_Soure_Property_ID__c = :sourcePropertyId
              AND FEC_Is_Deleted__c = false
            LIMIT 1
        ];
        if (!existing.isEmpty() && (excludeId == null || existing[0].Id != excludeId)) {
            String msg = Label.FEC_Duplicate_Property_Channel_Error;
            AuraHandledException e = new AuraHandledException(msg);
            e.setMessage(msg);
            throw e;
        }
    }

    @AuraEnabled
    public static void deleteRecord(Id recordId) {
        FEC_Auto_Intetgrating_Property_Mapping__c rec = [
            SELECT Id FROM FEC_Auto_Intetgrating_Property_Mapping__c WHERE Id = :recordId LIMIT 1
        ];
        //rec.FEC_Sync_Status__c = FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_DELETED;
        rec.FEC_Is_Deleted__c = true;
        update rec;
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_Channel__c> getChannels() {
        return [
            SELECT Id, FEC_Code__c, FEC_Channel_Vietnamese_name__c
            FROM FEC_Channel__c
            ORDER BY FEC_Channel_Vietnamese_name__c ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_Additional_Field__c> searchAdditionalInfo(String searchTerm) {
        String searchKey = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        return [
            SELECT Id, Name, FEC_Field_Mandatory__c, FEC_Unique_ID__c, FEC_Type__c, FEC_Data_Type__c
            FROM FEC_Additional_Field__c
            WHERE FEC_Field_Status__c = true
              AND FEC_Unique_ID__c LIKE :searchKey
            ORDER BY FEC_Unique_ID__c ASC
            LIMIT 20
        ];
    }

    @AuraEnabled
    public static FEC_Additional_Field__c getAdditionalFieldByUniqueID(String uniqueID) {
        List<FEC_Additional_Field__c> fields = [
            SELECT Id, Name, FEC_Field_Mandatory__c, FEC_Unique_ID__c, FEC_Type__c, FEC_Data_Type__c, FEC_Name_VN__c
            FROM FEC_Additional_Field__c
            WHERE FEC_Unique_ID__c = :uniqueID
            LIMIT 1
        ];
        return fields.isEmpty() ? null : fields[0];
    }

    @AuraEnabled
    public static Map<String, Integer> autoSyncIntegratingPropertyMappingtoApply() {
        String syncedStatus = FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_SYNCED;
        Set<String> pendingStatuses = new Set<String>{
            FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_NEW,
            FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_UPDATE
        };

        List<FEC_Auto_Intetgrating_Property_Mapping__c> records = [
            SELECT Id, FEC_Property_ID__c, FEC_Sync_Status__c, FEC_Property_ID_Synced__c
            FROM FEC_Auto_Intetgrating_Property_Mapping__c
            WHERE FEC_Sync_Status__c IN :pendingStatuses
              AND FEC_Status__c = true
              AND FEC_Is_Deleted__c = false
              AND FEC_Property_ID__c != null
        ];

        Integer totalToUpdate = records.size();
        Integer totalUpdated = 0;

        for (FEC_Auto_Intetgrating_Property_Mapping__c rec : records) {
            rec.FEC_Sync_Status__c = syncedStatus;
            rec.FEC_Property_ID_Synced__c = rec.FEC_Property_ID__c;
        }

        if (!records.isEmpty()) {
            List<Database.SaveResult> results = Database.update(records, false);
            for (Database.SaveResult sr : results) {
                if (sr.isSuccess()) {
                    totalUpdated++;
                }
            }
        }

        return new Map<String, Integer>{
            'totalToUpdate' => totalToUpdate,
            'totalUpdated' => totalUpdated
        };
    }
}