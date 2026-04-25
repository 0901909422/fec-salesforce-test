public with sharing class FEC_AutoIntegratingPropertyMappingCtrl {

    @AuraEnabled
    public static Map<String, Object> getRecords(Id recordId) {
        // Resolve FEC_Unique_ID__c from the Additional Field record
        String uniqueId = null;
        if (recordId != null) {
            String sObjName = recordId.getSObjectType().getDescribe().getName();
            if (sObjName == 'FEC_MDM_Additional_Field__c') {
                List<FEC_MDM_Additional_Field__c> fields = [
                    SELECT FEC_Unique_ID__c FROM FEC_MDM_Additional_Field__c WHERE Id = :recordId LIMIT 1
                ];
                if (!fields.isEmpty()) uniqueId = fields[0].FEC_Unique_ID__c;
            } else if (sObjName == 'FEC_Additional_Field__c') {
                List<FEC_Additional_Field__c> fields = [
                    SELECT FEC_Unique_ID__c FROM FEC_Additional_Field__c WHERE Id = :recordId LIMIT 1
                ];
                if (!fields.isEmpty()) uniqueId = fields[0].FEC_Unique_ID__c;
            }
        }

        List<FEC_Auto_Intetgrating_Property_Mapping__c> records;
        if (uniqueId != null) {
            records = [
                SELECT Id, Name, FEC_Is_Mandatory__c, FEC_Property_ID__c,
                       FEC_Property_Name_VN__c, FEC_Property_Type__c,
                       FEC_Soure_Property_ID__c, FEC_Status__c, FEC_Channel__c,
                       FEC_Sync_Status__c, CreatedDate, LastModifiedDate
                FROM FEC_Auto_Intetgrating_Property_Mapping__c
                WHERE FEC_Soure_Property_ID__c = :uniqueId
                  AND FEC_Is_Deleted__c = false
                ORDER BY CreatedDate DESC
            ];
        } else {
            records = new List<FEC_Auto_Intetgrating_Property_Mapping__c>();
        }

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
        rec.FEC_Sync_Status__c = FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_DELETED;
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
    public static FEC_Additional_Field__c getAdditionalFieldById(Id fieldId) {
        String sObjName = fieldId.getSObjectType().getDescribe().getName();
        if (sObjName == 'FEC_MDM_Additional_Field__c') {
            List<FEC_MDM_Additional_Field__c> mdmFields = [
                SELECT Id, Name, FEC_Field_Mandatory__c, FEC_Unique_ID__c, FEC_Type__c, FEC_Name_VN__c
                FROM FEC_MDM_Additional_Field__c
                WHERE Id = :fieldId
                LIMIT 1
            ];
            if (mdmFields.isEmpty()) return null;
            FEC_MDM_Additional_Field__c m = mdmFields[0];
            FEC_Additional_Field__c result = new FEC_Additional_Field__c();
            result.Name = m.Name;
            result.FEC_Field_Mandatory__c = m.FEC_Field_Mandatory__c;
            result.FEC_Unique_ID__c = m.FEC_Unique_ID__c;
            result.FEC_Type__c = m.FEC_Type__c;
            result.FEC_Name_VN__c = m.FEC_Name_VN__c;
            return result;
        }
        List<FEC_Additional_Field__c> fields = [
            SELECT Id, Name, FEC_Field_Mandatory__c, FEC_Unique_ID__c, FEC_Type__c, FEC_Data_Type__c, FEC_Name_VN__c
            FROM FEC_Additional_Field__c
            WHERE Id = :fieldId
            LIMIT 1
        ];
        return fields.isEmpty() ? null : fields[0];
    }
}