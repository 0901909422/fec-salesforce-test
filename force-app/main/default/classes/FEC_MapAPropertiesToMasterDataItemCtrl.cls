public with sharing class FEC_MapAPropertiesToMasterDataItemCtrl {

    @AuraEnabled
    public static Map<String, Object> getRecords(String  natureOfCaseCode) {
        List<FEC_Map_A_Properties_To_Master_Data_Item__c> records = [
            SELECT Id, Name, FEC_Channel__c, FEC_Nature_of_Case_Code__c,
                   FEC_User_Type__c, FEC_Is_Mandatory__c,
                   FEC_Additional_Field__c, FEC_Additional_Field__r.FEC_Unique_ID__c,
                   FEC_Additional_Field_Unique_ID__c,
                   FEC_Status__c,
                   FEC_Sync_Status__c, CreatedDate, LastModifiedDate
            FROM FEC_Map_A_Properties_To_Master_Data_Item__c
            WHERE FEC_Nature_of_Case_Code__c = :natureOfCaseCode
              AND FEC_Is_Deleted__c = false
            ORDER BY CreatedDate DESC
        ];

        Map<String, Object> result = new Map<String, Object>();
        result.put('records', records);
        result.put('totalRecords', records.size());
        return result;
    }

    @AuraEnabled
    public static FEC_Map_A_Properties_To_Master_Data_Item__c createRecord(FEC_Map_A_Properties_To_Master_Data_Item__c record) {
        checkDuplicate(record.FEC_Additional_Field__c, record.FEC_Channel__c, record.FEC_Nature_of_Case_Code__c, null);
        insert record;
        return record;
    }

    @AuraEnabled
    public static FEC_Map_A_Properties_To_Master_Data_Item__c updateRecord(FEC_Map_A_Properties_To_Master_Data_Item__c record) {
        checkDuplicate(record.FEC_Additional_Field__c, record.FEC_Channel__c, record.FEC_Nature_of_Case_Code__c, record.Id);
        update record;
        return record;
    }

    private static void checkDuplicate(Id additionalField, Id channel, String natureOfCaseCode, Id excludeId) {
        List<FEC_Map_A_Properties_To_Master_Data_Item__c> existing = [
            SELECT Id FROM FEC_Map_A_Properties_To_Master_Data_Item__c
            WHERE FEC_Additional_Field__c = :additionalField
              AND FEC_Channel__c = :channel
              AND FEC_Nature_of_Case_Code__c = :natureOfCaseCode
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
        FEC_Map_A_Properties_To_Master_Data_Item__c rec = [
            SELECT Id FROM FEC_Map_A_Properties_To_Master_Data_Item__c WHERE Id = :recordId LIMIT 1
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
    public static List<FEC_User_Type__c> getUserTypes() {
        return [
            SELECT Id, FEC_Code__c, FEC_Name_VN__c, FEC_Alias__c
            FROM FEC_User_Type__c
            WHERE FEC_Status__c = true
            ORDER BY FEC_Pos_Order__c ASC
        ];
    }

    @AuraEnabled
    public static List<FEC_Additional_Field__c> searchAdditionalFields(String searchTerm) {
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
}