@IsTest
private class FEC_AutoIntPropMappingCtrl_Test {

    @TestSetup
    static void setupData() {
        FEC_Channel__c channel = new FEC_Channel__c(
            FEC_Code__c = FEC_FraudConstantCommon.DEFAULT_CHANNEL_INTEGRATION_CODE,
            FEC_Channel_Status__c = true
        );
        insert channel;

        FEC_Additional_Field__c field = new FEC_Additional_Field__c(
            FEC_Unique_ID__c = 'TEST_FIELD_01',
            FEC_Field_Status__c = true,
            FEC_Type__c = 'string',
            FEC_Data_Type__c = 'text'
        );
        insert field;
    }

    @IsTest
    static void test_getRecords() {
        Test.startTest();
        Map<String, Object> result = FEC_AutoIntegratingPropertyMappingCtrl.getRecords('SOURCE_001');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('records'));
        System.assert(result.containsKey('totalRecords'));
    }

    @IsTest
    static void test_createAndDeleteRecord() {
        FEC_Channel__c channel = [SELECT Id FROM FEC_Channel__c LIMIT 1];

        FEC_Auto_Intetgrating_Property_Mapping__c rec = new FEC_Auto_Intetgrating_Property_Mapping__c(
            FEC_Property_ID__c = 'PROP_001',
            FEC_Soure_Property_ID__c = 'SOURCE_001',
            FEC_Channel__c = channel.Id,
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false,
            FEC_Sync_Status__c = FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_NEW
        );

        Test.startTest();
        FEC_Auto_Intetgrating_Property_Mapping__c created =
            FEC_AutoIntegratingPropertyMappingCtrl.createRecord(rec);
        System.assertNotEquals(null, created.Id);

        // Delete
        FEC_AutoIntegratingPropertyMappingCtrl.deleteRecord(created.Id);
        Test.stopTest();

        FEC_Auto_Intetgrating_Property_Mapping__c deleted = [
            SELECT FEC_Is_Deleted__c FROM FEC_Auto_Intetgrating_Property_Mapping__c WHERE Id = :created.Id
        ];
        System.assertEquals(true, deleted.FEC_Is_Deleted__c);
    }

    @IsTest
    static void test_updateRecord() {
        FEC_Channel__c channel = [SELECT Id FROM FEC_Channel__c LIMIT 1];

        FEC_Auto_Intetgrating_Property_Mapping__c rec = new FEC_Auto_Intetgrating_Property_Mapping__c(
            FEC_Property_ID__c = 'PROP_002',
            FEC_Soure_Property_ID__c = 'SOURCE_002',
            FEC_Channel__c = channel.Id,
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false,
            FEC_Sync_Status__c = FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_NEW
        );
        insert rec;

        rec.FEC_Property_Name_VN__c = 'Updated Name';

        Test.startTest();
        FEC_Auto_Intetgrating_Property_Mapping__c updated =
            FEC_AutoIntegratingPropertyMappingCtrl.updateRecord(rec);
        Test.stopTest();

        System.assertEquals('Updated Name', updated.FEC_Property_Name_VN__c);
    }

    @IsTest
    static void test_createRecord_duplicate() {
        FEC_Channel__c channel = [SELECT Id FROM FEC_Channel__c LIMIT 1];

        FEC_Auto_Intetgrating_Property_Mapping__c rec1 = new FEC_Auto_Intetgrating_Property_Mapping__c(
            FEC_Property_ID__c = 'DUP_PROP',
            FEC_Soure_Property_ID__c = 'DUP_SRC',
            FEC_Channel__c = channel.Id,
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false
        );
        insert rec1;

        FEC_Auto_Intetgrating_Property_Mapping__c rec2 = new FEC_Auto_Intetgrating_Property_Mapping__c(
            FEC_Property_ID__c = 'DUP_PROP',
            FEC_Soure_Property_ID__c = 'DUP_SRC',
            FEC_Channel__c = channel.Id,
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false
        );

        Test.startTest();
        try {
            FEC_AutoIntegratingPropertyMappingCtrl.createRecord(rec2);
            System.assert(false, 'Should throw duplicate error');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void test_getChannels() {
        Test.startTest();
        List<FEC_Channel__c> channels = FEC_AutoIntegratingPropertyMappingCtrl.getChannels();
        Test.stopTest();

        System.assert(channels.size() >= 1);
    }

    @IsTest
    static void test_searchAdditionalInfo() {
        Test.startTest();
        List<FEC_Additional_Field__c> fields =
            FEC_AutoIntegratingPropertyMappingCtrl.searchAdditionalInfo('TEST_FIELD');
        Test.stopTest();

        System.assert(fields.size() >= 1);
    }

    @IsTest
    static void test_getAdditionalFieldByUniqueID() {
        Test.startTest();
        FEC_Additional_Field__c field =
            FEC_AutoIntegratingPropertyMappingCtrl.getAdditionalFieldByUniqueID('TEST_FIELD_01');
        Test.stopTest();

        System.assertNotEquals(null, field);
        System.assertEquals('TEST_FIELD_01', field.FEC_Unique_ID__c);
    }

    @IsTest
    static void test_getAdditionalFieldByUniqueID_notFound() {
        Test.startTest();
        FEC_Additional_Field__c field =
            FEC_AutoIntegratingPropertyMappingCtrl.getAdditionalFieldByUniqueID('NONEXIST');
        Test.stopTest();

        System.assertEquals(null, field);
    }

    @IsTest
    static void test_autoSyncIntegratingPropertyMappingtoApply() {
        FEC_Channel__c channel = [SELECT Id FROM FEC_Channel__c LIMIT 1];

        FEC_Auto_Intetgrating_Property_Mapping__c rec = new FEC_Auto_Intetgrating_Property_Mapping__c(
            FEC_Property_ID__c = 'SYNC_PROP',
            FEC_Soure_Property_ID__c = 'SYNC_SRC',
            FEC_Channel__c = channel.Id,
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false,
            FEC_Sync_Status__c = FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_NEW
        );
        insert rec;

        Test.startTest();
        Map<String, Integer> result =
            FEC_AutoIntegratingPropertyMappingCtrl.autoSyncIntegratingPropertyMappingtoApply();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.get('totalToUpdate') >= 1);
    }
}
