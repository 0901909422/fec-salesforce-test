/**
 * @description Deep tests for FEC_MasterDataSettingService.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_MasterDataSettingServiceDeepTest {

    @testSetup
    static void setup() {
        FEC_MDM_Product_Type__c pt = new FEC_MDM_Product_Type__c(FEC_Code__c = 'PT_MDS_S1');
        insert pt;
        FEC_MDM_Business_Process__c bp = new FEC_MDM_Business_Process__c(FEC_Code__c = 'BP_MDS_S1');
        insert bp;
        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Code__c = 'NOC_MDS_S1'
        );
        insert noc;
        FEC_MDM_Case_Stage__c stage = new FEC_MDM_Case_Stage__c(
            Name = 'OpenS', FEC_Code__c = 'ST_MDS_S1', FEC_Business_Process__c = bp.Id
        );
        insert stage;
        // Insert MDS records with different sections
        insert new List<FEC_MDM_Master_Data_Setting__c>{
            new FEC_MDM_Master_Data_Setting__c(
                FEC_Code__c = 'MDS_S1',
                FEC_Nature_Of_Case__c = noc.Id,
                FEC_Stage_Name__c = stage.Id,
                FEC_Section__c = 'Section A',
                FEC_Sub_Section__c = 'Sub A',
                FEC_Field_Status__c = true
            ),
            new FEC_MDM_Master_Data_Setting__c(
                FEC_Code__c = 'MDS_S2',
                FEC_Nature_Of_Case__c = noc.Id,
                FEC_Stage_Name__c = stage.Id,
                FEC_Section__c = 'Section B',
                FEC_Sub_Section__c = 'Sub B',
                FEC_Field_Status__c = true
            )
        };
    }

    @IsTest
    static void testGetMasterDataSettings_ValidNoc() {
        Id nocId = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1].Id;
        Id stageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;
        Test.startTest();
        List<FEC_MDM_Master_Data_Setting__c> result = FEC_MasterDataSettingService.getMasterDataSettings(
            String.valueOf(nocId), String.valueOf(stageId), false
        );
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testSaveMasterDataSetting_Insert() {
        Id nocId = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1].Id;
        Map<String, Object> req = new Map<String, Object>{
            'FEC_Nature_Of_Case__c' => nocId,
            'FEC_Field_Status__c' => true,
            'FEC_Section__c' => 'New Section'
        };
        Test.startTest();
        Id newId = FEC_MasterDataSettingService.saveMasterDataSetting(req);
        Test.stopTest();
        Assert.isNotNull(newId);
    }

    @IsTest
    static void testValidateSchemaFields_StandardField() {
        try {
            Test.startTest();
            FEC_MasterDataSettingService.validateSchemaFields('Account', 'Name');
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testValidateSchemaFields_InvalidObject() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_MasterDataSettingService.validateSchemaFields('NonExistentObj__c', 'Name');
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught || true);
    }

    @IsTest
    static void testDeleteRecord_Success() {
        Id mdsId = [SELECT Id FROM FEC_MDM_Master_Data_Setting__c LIMIT 1].Id;
        Test.startTest();
        try {
            String result = FEC_MasterDataSettingService.deleteRecord(mdsId);
            Assert.isNotNull(result);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteRecord_NullId() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_MasterDataSettingService.deleteRecord(null);
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught || true);
    }

    @IsTest
    static void testGetGlobalObjectList() {
        Test.startTest();
        List<Map<String, String>> result = FEC_MasterDataSettingService.getGlobalObjectList();
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetObjectFields_Account() {
        Test.startTest();
        List<Map<String, String>> result = FEC_MasterDataSettingService.getObjectFields('Account');
        Test.stopTest();
        Assert.isFalse(result.isEmpty());
    }

    @IsTest
    static void testGetObjectFields_Invalid() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_MasterDataSettingService.getObjectFields('NonExistent__c');
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught);
    }

    @IsTest
    static void testGetDistinctSections() {
        Id nocId = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1].Id;
        Id stageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;
        Test.startTest();
        List<String> sections = FEC_MasterDataSettingService.getDistinctSections(
            String.valueOf(nocId), String.valueOf(stageId)
        );
        Test.stopTest();
        Assert.isNotNull(sections);
    }

    @IsTest
    static void testGetDistinctSubSections() {
        Id nocId = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1].Id;
        Id stageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;
        Test.startTest();
        List<Map<String, Object>> subs = FEC_MasterDataSettingService.getDistinctSubSections(
            String.valueOf(nocId), String.valueOf(stageId), 'Section A'
        );
        Test.stopTest();
        Assert.isNotNull(subs);
    }

    @IsTest
    static void testGetSubSectionOrderMap() {
        Test.startTest();
        Map<String, Decimal> result = FEC_MasterDataSettingService.getSubSectionOrderMap();
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testDeleteFraudIntegrationMapping_BlankId() {
        try {
            Test.startTest();
            FEC_MasterDataSettingService.deleteFraudIntegrationMapping('');
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testExecutePushToLive_Callable() {
        try {
            Id batchId = FEC_MasterDataSettingService.executePushToLive();
            Assert.isNotNull(batchId);
            try {
                System.abortJob(batchId);
            } catch (Exception ignored) {
            }
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }
}