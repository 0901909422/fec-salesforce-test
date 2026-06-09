@IsTest
private class FEC_MapAPropToMDItemCtl_Test {

    @TestSetup
    static void setupTestData() {
        FEC_Channel__c channel = new FEC_Channel__c(
            Name = 'Test Channel',
            FEC_Channel_ID__c = 'CH001',
            FEC_Channel_Status__c = true,
            FEC_Channel_Vietnamese_name__c = 'Kênh Test'
        );
        insert channel;

        FEC_User_Type__c userType = new FEC_User_Type__c(
            Name = 'Test User Type',
            FEC_Code__c = 'UT001',
            FEC_Status__c = true
        );
        insert userType;

        FEC_Additional_Field__c addField = new FEC_Additional_Field__c(
            Name = 'Test Field',
            FEC_Unique_ID__c = 'FIELD001',
            FEC_Field_Status__c = true,
            FEC_Type__c = 'string',
            FEC_Data_Type__c = 'TEXT'
        );
        insert addField;

        FEC_Map_A_Properties_To_Master_Data_Item__c rec = new FEC_Map_A_Properties_To_Master_Data_Item__c(
            Name = 'Test Mapping',
            FEC_Channel__c = channel.Id,
            FEC_Nature_of_Case_Code__c = 'NOC001',
            FEC_Additional_Field__c = addField.Id,
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false,
            FEC_Sync_Status__c = FEC_FraudConstantCommon.CONFIG_SYNC_STATUS_NEW
        );
        insert rec;
    }

    @IsTest
    static void test_getRecords_WithData() {
        Test.startTest();
        Map<String, Object> result = FEC_MapAPropertiesToMasterDataItemCtrl.getRecords('NOC001');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(1, result.get('totalRecords'));
    }

    @IsTest
    static void test_getRecords_Empty() {
        Test.startTest();
        Map<String, Object> result = FEC_MapAPropertiesToMasterDataItemCtrl.getRecords('NOTEXIST');
        Test.stopTest();

        System.assertEquals(0, result.get('totalRecords'));
    }

    @IsTest
    static void test_createRecord() {
        FEC_Channel__c channel = [SELECT Id FROM FEC_Channel__c LIMIT 1];

        FEC_Additional_Field__c newField = new FEC_Additional_Field__c(
            Name = 'New Field',
            FEC_Unique_ID__c = 'FIELD002',
            FEC_Field_Status__c = true,
            FEC_Type__c = 'string',
            FEC_Data_Type__c = 'TEXT'
        );
        insert newField;

        FEC_Map_A_Properties_To_Master_Data_Item__c rec = new FEC_Map_A_Properties_To_Master_Data_Item__c(
            Name = 'New Mapping',
            FEC_Channel__c = channel.Id,
            FEC_Nature_of_Case_Code__c = 'NOC002',
            FEC_Additional_Field__c = newField.Id,
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false
        );

        Test.startTest();
        FEC_Map_A_Properties_To_Master_Data_Item__c result = 
            FEC_MapAPropertiesToMasterDataItemCtrl.createRecord(rec);
        Test.stopTest();

        System.assertNotEquals(null, result.Id);
    }

    @IsTest
    static void test_createRecord_Duplicate() {
        FEC_Channel__c channel = [SELECT Id FROM FEC_Channel__c LIMIT 1];
        FEC_Additional_Field__c addField = [SELECT Id FROM FEC_Additional_Field__c LIMIT 1];

        FEC_Map_A_Properties_To_Master_Data_Item__c dup = new FEC_Map_A_Properties_To_Master_Data_Item__c(
            Name = 'Duplicate',
            FEC_Channel__c = channel.Id,
            FEC_Nature_of_Case_Code__c = 'NOC001',
            FEC_Additional_Field__c = addField.Id,
            FEC_Status__c = true,
            FEC_Is_Deleted__c = false
        );

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            FEC_MapAPropertiesToMasterDataItemCtrl.createRecord(dup);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Should throw on duplicate');
    }

    @IsTest
    static void test_updateRecord() {
        FEC_Map_A_Properties_To_Master_Data_Item__c rec = [
            SELECT Id, FEC_Additional_Field__c, FEC_Channel__c, FEC_Nature_of_Case_Code__c, FEC_Status__c
            FROM FEC_Map_A_Properties_To_Master_Data_Item__c LIMIT 1
        ];
        rec.FEC_Status__c = false;

        Test.startTest();
        FEC_Map_A_Properties_To_Master_Data_Item__c result = 
            FEC_MapAPropertiesToMasterDataItemCtrl.updateRecord(rec);
        Test.stopTest();

        System.assertEquals(false, result.FEC_Status__c);
    }

    @IsTest
    static void test_deleteRecord() {
        FEC_Map_A_Properties_To_Master_Data_Item__c rec = [
            SELECT Id FROM FEC_Map_A_Properties_To_Master_Data_Item__c LIMIT 1
        ];

        Test.startTest();
        FEC_MapAPropertiesToMasterDataItemCtrl.deleteRecord(rec.Id);
        Test.stopTest();

        FEC_Map_A_Properties_To_Master_Data_Item__c deleted = [
            SELECT FEC_Is_Deleted__c FROM FEC_Map_A_Properties_To_Master_Data_Item__c WHERE Id = :rec.Id
        ];
        System.assertEquals(true, deleted.FEC_Is_Deleted__c);
    }

    @IsTest
    static void test_getChannels() {
        Test.startTest();
        List<FEC_Channel__c> channels = FEC_MapAPropertiesToMasterDataItemCtrl.getChannels();
        Test.stopTest();

        System.assertNotEquals(null, channels);
        System.assert(channels.size() > 0);
    }

    @IsTest
    static void test_getUserTypes() {
        Test.startTest();
        List<FEC_User_Type__c> result = FEC_MapAPropertiesToMasterDataItemCtrl.getUserTypes();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_searchAdditionalFields() {
        Test.startTest();
        List<FEC_Additional_Field__c> result = 
            FEC_MapAPropertiesToMasterDataItemCtrl.searchAdditionalFields('FIELD');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.size() > 0);
    }

    @IsTest
    static void test_searchAdditionalFields_NoMatch() {
        Test.startTest();
        List<FEC_Additional_Field__c> result = 
            FEC_MapAPropertiesToMasterDataItemCtrl.searchAdditionalFields('NOTEXIST_XYZ');
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void test_autoSyncMapAPropertiesToMasterDataItemtoApply() {
        Test.startTest();
        Map<String, Integer> result = 
            FEC_MapAPropertiesToMasterDataItemCtrl.autoSyncMapAPropertiesToMasterDataItemtoApply();
        Test.stopTest();

        System.assertNotEquals(null, result);
        // totalToUpdate may be 0 if FEC_Additional_Field_Unique_ID__c isn't auto-populated in test
    }
}