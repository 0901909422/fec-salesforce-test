@IsTest
private class FEC_MapAPropsToMDItemCtrl_Test {

    @TestSetup
    static void setupData() {
        FEC_Channel__c channel = new FEC_Channel__c(
            FEC_Code__c = FEC_FraudConstantCommon.DEFAULT_CHANNEL_INTEGRATION_CODE,
            FEC_Channel_Status__c = true
        );
        insert channel;

        FEC_Additional_Field__c field = new FEC_Additional_Field__c(
            FEC_Unique_ID__c = 'MAP_FIELD_01',
            FEC_Field_Status__c = true,
            FEC_Type__c = 'string',
            FEC_Data_Type__c = 'text'
        );
        insert field;
    }

    @IsTest
    static void test_getRecords() {
        Test.startTest();
        Map<String, Object> result = FEC_MapAPropertiesToMasterDataItemCtrl.getRecords('NOC_001');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('records'));
        System.assert(result.containsKey('totalRecords'));
    }

    @IsTest
    static void test_createAndDeleteRecord() {
        FEC_Channel__c channel = [SELECT Id FROM FEC_Channel__c LIMIT 1];
        FEC_Additional_Field__c field = [SELECT Id FROM FEC_Additional_Field__c LIMIT 1];

        FEC_Map_A_Properties_To_Master_Data_Item__c rec = new FEC_Map_A_Properties_To_Master_Data_Item__c(
            FEC_Channel__c = channel.Id,
            FEC_Additional_Field__c = field.Id,
            FEC_Nature_of_Case_Code__c = 'NOC_001',
            FEC_Is_Mandatory__c = true,
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false,
            FEC_Sync_Status__c = FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_NEW
        );

        Test.startTest();
        FEC_Map_A_Properties_To_Master_Data_Item__c created =
            FEC_MapAPropertiesToMasterDataItemCtrl.createRecord(rec);
        System.assertNotEquals(null, created.Id);

        FEC_MapAPropertiesToMasterDataItemCtrl.deleteRecord(created.Id);
        Test.stopTest();

        FEC_Map_A_Properties_To_Master_Data_Item__c deleted = [
            SELECT FEC_Is_Deleted__c FROM FEC_Map_A_Properties_To_Master_Data_Item__c WHERE Id = :created.Id
        ];
        System.assertEquals(true, deleted.FEC_Is_Deleted__c);
    }

    @IsTest
    static void test_updateRecord() {
        FEC_Channel__c channel = [SELECT Id FROM FEC_Channel__c LIMIT 1];
        FEC_Additional_Field__c field = [SELECT Id FROM FEC_Additional_Field__c LIMIT 1];

        FEC_Map_A_Properties_To_Master_Data_Item__c rec = new FEC_Map_A_Properties_To_Master_Data_Item__c(
            FEC_Channel__c = channel.Id,
            FEC_Additional_Field__c = field.Id,
            FEC_Nature_of_Case_Code__c = 'NOC_002',
            FEC_Is_Mandatory__c = false,
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false
        );
        insert rec;

        rec.FEC_Is_Mandatory__c = true;

        Test.startTest();
        FEC_Map_A_Properties_To_Master_Data_Item__c updated =
            FEC_MapAPropertiesToMasterDataItemCtrl.updateRecord(rec);
        Test.stopTest();

        System.assertEquals(true, updated.FEC_Is_Mandatory__c);
    }

    @IsTest
    static void test_createRecord_duplicate() {
        FEC_Channel__c channel = [SELECT Id FROM FEC_Channel__c LIMIT 1];
        FEC_Additional_Field__c field = [SELECT Id FROM FEC_Additional_Field__c LIMIT 1];

        FEC_Map_A_Properties_To_Master_Data_Item__c rec1 = new FEC_Map_A_Properties_To_Master_Data_Item__c(
            FEC_Channel__c = channel.Id,
            FEC_Additional_Field__c = field.Id,
            FEC_Nature_of_Case_Code__c = 'DUP_NOC',
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false
        );
        insert rec1;

        FEC_Map_A_Properties_To_Master_Data_Item__c rec2 = new FEC_Map_A_Properties_To_Master_Data_Item__c(
            FEC_Channel__c = channel.Id,
            FEC_Additional_Field__c = field.Id,
            FEC_Nature_of_Case_Code__c = 'DUP_NOC',
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false
        );

        Test.startTest();
        try {
            FEC_MapAPropertiesToMasterDataItemCtrl.createRecord(rec2);
            System.assert(false, 'Should throw duplicate error');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void test_getChannels() {
        Test.startTest();
        List<FEC_Channel__c> channels = FEC_MapAPropertiesToMasterDataItemCtrl.getChannels();
        Test.stopTest();

        System.assert(channels.size() >= 1);
    }

    @IsTest
    static void test_getUserTypes() {
        Test.startTest();
        List<FEC_User_Type__c> userTypes = FEC_MapAPropertiesToMasterDataItemCtrl.getUserTypes();
        Test.stopTest();

        System.assertNotEquals(null, userTypes);
    }

    @IsTest
    static void test_searchAdditionalFields() {
        Test.startTest();
        List<FEC_Additional_Field__c> fields =
            FEC_MapAPropertiesToMasterDataItemCtrl.searchAdditionalFields('MAP_FIELD');
        Test.stopTest();

        System.assert(fields.size() >= 1);
    }

    @IsTest
    static void test_autoSyncMapAPropertiesToMasterDataItemtoApply() {
        FEC_Channel__c channel = [SELECT Id FROM FEC_Channel__c LIMIT 1];
        FEC_Additional_Field__c field = [SELECT Id, FEC_Unique_ID__c FROM FEC_Additional_Field__c LIMIT 1];

        FEC_Map_A_Properties_To_Master_Data_Item__c rec = new FEC_Map_A_Properties_To_Master_Data_Item__c(
            FEC_Channel__c = channel.Id,
            FEC_Additional_Field__c = field.Id,
            FEC_Additional_Field_Unique_ID__c = field.FEC_Unique_ID__c,
            FEC_Nature_of_Case_Code__c = 'SYNC_NOC',
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false,
            FEC_Sync_Status__c = FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_NEW
        );
        insert rec;

        Test.startTest();
        Map<String, Integer> result =
            FEC_MapAPropertiesToMasterDataItemCtrl.autoSyncMapAPropertiesToMasterDataItemtoApply();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.get('totalToUpdate') >= 1);
    }
}
