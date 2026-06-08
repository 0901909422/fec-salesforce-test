@IsTest
private class FEC_AutoIntPropMapCtl_Test {

    @TestSetup
    static void setupTestData() {
        FEC_Channel__c channel = new FEC_Channel__c(
            Name = 'Test Channel',
            FEC_Channel_ID__c = 'CH001',
            FEC_Channel_Status__c = true,
            FEC_Channel_Vietnamese_name__c = 'Kênh Test'
        );
        insert channel;

        FEC_Additional_Field__c addField = new FEC_Additional_Field__c(
            Name = 'Test Field',
            FEC_Unique_ID__c = 'PROP001',
            FEC_Field_Status__c = true,
            FEC_Type__c = 'string',
            FEC_Data_Type__c = 'TEXT'
        );
        insert addField;

        FEC_Auto_Intetgrating_Property_Mapping__c rec = new FEC_Auto_Intetgrating_Property_Mapping__c(
            Name = 'Test Mapping',
            FEC_Property_ID__c = 'PROP001',
            FEC_Channel__c = channel.Id,
            FEC_Soure_Property_ID__c = 'SOURCE001',
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false,
            FEC_Sync_Status__c = FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_NEW
        );
        insert rec;
    }

    @IsTest
    static void test_getRecords_WithData() {
        Test.startTest();
        Map<String, Object> result = FEC_AutoIntegratingPropertyMappingCtrl.getRecords('SOURCE001');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(1, result.get('totalRecords'));
    }

    @IsTest
    static void test_getRecords_Empty() {
        Test.startTest();
        Map<String, Object> result = FEC_AutoIntegratingPropertyMappingCtrl.getRecords('NOTEXIST');
        Test.stopTest();

        System.assertEquals(0, result.get('totalRecords'));
    }

    @IsTest
    static void test_createRecord() {
        FEC_Channel__c channel = [SELECT Id FROM FEC_Channel__c LIMIT 1];

        FEC_Auto_Intetgrating_Property_Mapping__c rec = new FEC_Auto_Intetgrating_Property_Mapping__c(
            Name = 'New Mapping',
            FEC_Property_ID__c = 'PROP002',
            FEC_Channel__c = channel.Id,
            FEC_Soure_Property_ID__c = 'SOURCE002',
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false
        );

        Test.startTest();
        FEC_Auto_Intetgrating_Property_Mapping__c result = 
            FEC_AutoIntegratingPropertyMappingCtrl.createRecord(rec);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Record should be created');
    }

    @IsTest
    static void test_createRecord_Duplicate() {
        FEC_Channel__c channel = [SELECT Id FROM FEC_Channel__c LIMIT 1];

        // Try to create a duplicate of the existing record from setup
        FEC_Auto_Intetgrating_Property_Mapping__c dup = new FEC_Auto_Intetgrating_Property_Mapping__c(
            Name = 'Duplicate',
            FEC_Property_ID__c = 'PROP001',
            FEC_Channel__c = channel.Id,
            FEC_Soure_Property_ID__c = 'SOURCE001',
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false
        );

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            FEC_AutoIntegratingPropertyMappingCtrl.createRecord(dup);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Should throw on duplicate');
    }

    @IsTest
    static void test_updateRecord() {
        FEC_Auto_Intetgrating_Property_Mapping__c rec = [
            SELECT Id, FEC_Property_ID__c, FEC_Channel__c, FEC_Soure_Property_ID__c, FEC_Status__c
            FROM FEC_Auto_Intetgrating_Property_Mapping__c LIMIT 1
        ];
        rec.FEC_Status__c = false;

        Test.startTest();
        FEC_Auto_Intetgrating_Property_Mapping__c result = 
            FEC_AutoIntegratingPropertyMappingCtrl.updateRecord(rec);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(false, result.FEC_Status__c);
    }

    @IsTest
    static void test_deleteRecord() {
        FEC_Auto_Intetgrating_Property_Mapping__c rec = [
            SELECT Id FROM FEC_Auto_Intetgrating_Property_Mapping__c LIMIT 1
        ];

        Test.startTest();
        FEC_AutoIntegratingPropertyMappingCtrl.deleteRecord(rec.Id);
        Test.stopTest();

        FEC_Auto_Intetgrating_Property_Mapping__c deleted = [
            SELECT FEC_Is_Deleted__c FROM FEC_Auto_Intetgrating_Property_Mapping__c WHERE Id = :rec.Id
        ];
        System.assertEquals(true, deleted.FEC_Is_Deleted__c, 'Should be soft-deleted');
    }

    @IsTest
    static void test_getChannels() {
        Test.startTest();
        List<FEC_Channel__c> channels = FEC_AutoIntegratingPropertyMappingCtrl.getChannels();
        Test.stopTest();

        System.assertNotEquals(null, channels);
        System.assert(channels.size() > 0);
    }

    @IsTest
    static void test_searchAdditionalInfo() {
        Test.startTest();
        List<FEC_Additional_Field__c> result = 
            FEC_AutoIntegratingPropertyMappingCtrl.searchAdditionalInfo('PROP');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.size() > 0);
    }

    @IsTest
    static void test_searchAdditionalInfo_NoMatch() {
        Test.startTest();
        List<FEC_Additional_Field__c> result = 
            FEC_AutoIntegratingPropertyMappingCtrl.searchAdditionalInfo('XYZ_NOTEXIST');
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void test_getAdditionalFieldByUniqueID_Found() {
        Test.startTest();
        FEC_Additional_Field__c result = 
            FEC_AutoIntegratingPropertyMappingCtrl.getAdditionalFieldByUniqueID('PROP001');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('PROP001', result.FEC_Unique_ID__c);
    }

    @IsTest
    static void test_getAdditionalFieldByUniqueID_NotFound() {
        Test.startTest();
        FEC_Additional_Field__c result = 
            FEC_AutoIntegratingPropertyMappingCtrl.getAdditionalFieldByUniqueID('NOTEXIST');
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void test_autoSyncIntegratingPropertyMappingtoApply() {
        Test.startTest();
        Map<String, Integer> result = 
            FEC_AutoIntegratingPropertyMappingCtrl.autoSyncIntegratingPropertyMappingtoApply();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(1, result.get('totalToUpdate'));
        System.assertEquals(1, result.get('totalUpdated'));
    }
}