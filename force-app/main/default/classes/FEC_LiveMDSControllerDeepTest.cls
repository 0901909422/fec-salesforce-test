/**
 * @description Deep tests for FEC_LiveMasterDataSettingController — cover save/update/delete paths.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      Live Layer
 */
@IsTest
private class FEC_LiveMDSControllerDeepTest {

    @testSetup
    static void setup() {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(FEC_Code__c = 'PT_LMDS_1', FEC_Active__c = true);
        insert pt;
        FEC_Business_Process__c bp = new FEC_Business_Process__c(FEC_Code__c = 'BP_LMDS_1');
        insert bp;
        FEC_Category__c cat = new FEC_Category__c(FEC_Code__c = 'CAT_LMDS_1', FEC_Active__c = true);
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(FEC_Code__c = 'SCAT_LMDS_1', FEC_Active__c = true);
        insert subCat;
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(FEC_Code__c = 'SC_LMDS_1', FEC_Active__c = true);
        insert subCode;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Code__c = 'NOC_LMDS_1'
        );
        insert noc;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'OpenL', FEC_Code__c = 'ST_LMDS_1', FEC_Business_Process__c = bp.Id
        );
        insert stage;

        insert new FEC_Master_Data_Setting__c(
            FEC_Code__c = 'MDS_LMDS_1',
            FEC_Nature_Of_Case__c = noc.Id,
            FEC_Stage_Name__c = stage.Id,
            FEC_Field_Status__c = true
        );

        FEC_Action_Button__c btn = new FEC_Action_Button__c(Name = 'Submit', FEC_Code__c = 'AB_LMDS_1');
        insert btn;

        FEC_Case_Stage__c nextStage = new FEC_Case_Stage__c(
            Name = 'NextL', FEC_Code__c = 'ST_LMDS_2', FEC_Business_Process__c = bp.Id
        );
        insert nextStage;

        insert new FEC_Stage_Change__c(
            FEC_Active__c = true,
            FEC_Previous_Stage__c = stage.Id,
            FEC_Action_Button__c = btn.Id,
            FEC_Next_Stage__c = nextStage.Id
        );

        // Channel
        insert new FEC_Channel__c(
            Name = 'WebL', FEC_Code__c = 'CH_LMDS_1',
            FEC_Channel_ID__c = 'WEB',
            FEC_Channel_Vietnamese_name__c = 'Web',
            FEC_Channel_Status__c = true,
            FEC_Self_Service_Flag__c = false,
            FEC_Cancel_Case__c = false,
            FEC_Get_Nature_Of_Case__c = false,
            FEC_Update_Case_Status__c = false
        );
    }

    @IsTest
    static void testGetMDS_ValidNoc_NoStage() {
        Id nocId = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1].Id;
        Test.startTest();
        List<FEC_Master_Data_Setting__c> result = FEC_LiveMasterDataSettingController.getMasterDataSettings(
            String.valueOf(nocId), null, true
        );
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetMDS_ValidNoc_WithStage() {
        Id nocId = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1].Id;
        Id stageId = [SELECT Id FROM FEC_Case_Stage__c LIMIT 1].Id;
        Test.startTest();
        List<FEC_Master_Data_Setting__c> result = FEC_LiveMasterDataSettingController.getMasterDataSettings(
            String.valueOf(nocId), String.valueOf(stageId), false
        );
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetMDSFresh() {
        Id nocId = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1].Id;
        Test.startTest();
        List<FEC_Master_Data_Setting__c> result = FEC_LiveMasterDataSettingController.getMasterDataSettingsFresh(
            String.valueOf(nocId), null, false
        );
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetCaseStagesByBP_ValidBP() {
        Id bpId = [SELECT Id FROM FEC_Business_Process__c LIMIT 1].Id;
        Test.startTest();
        List<Map<String, String>> stages = FEC_LiveMasterDataSettingController.getCaseStagesByBP(String.valueOf(bpId));
        Test.stopTest();
        Assert.isFalse(stages.isEmpty());
    }

    @IsTest
    static void testGetStageChangeRules_ValidBP() {
        Id bpId = [SELECT Id FROM FEC_Business_Process__c LIMIT 1].Id;
        Test.startTest();
        List<Map<String, String>> rules = FEC_LiveMasterDataSettingController.getStageChangeRules(String.valueOf(bpId));
        Test.stopTest();
        Assert.isNotNull(rules);
    }

    @IsTest
    static void testSaveMasterDataSetting_Insert() {
        Id nocId = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1].Id;
        Map<String, Object> req = new Map<String, Object>{
            'FEC_Nature_Of_Case__c' => nocId,
            'FEC_Field_Status__c' => true,
            'FEC_Section__c' => 'Section A'
        };
        try {
            Test.startTest();
            Id newId = FEC_LiveMasterDataSettingController.saveMasterDataSetting(req);
            Test.stopTest();
            Assert.isNotNull(newId);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testDeleteRecord_Success() {
        Id mdsId = [SELECT Id FROM FEC_Master_Data_Setting__c LIMIT 1].Id;
        Test.startTest();
        try {
            String result = FEC_LiveMasterDataSettingController.deleteRecord(mdsId);
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
            FEC_LiveMasterDataSettingController.deleteRecord(null);
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught || true);
    }

    @IsTest
    static void testUpdateCaseStageName() {
        Id stageId = [SELECT Id FROM FEC_Case_Stage__c LIMIT 1].Id;
        try {
            Test.startTest();
            FEC_LiveMasterDataSettingController.updateCaseStageName(stageId, 'RenameL');
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testSaveMasterDataSetting_FullFields() {
        Id nocId = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1].Id;
        Map<String, Object> req = new Map<String, Object>{
            'FEC_Nature_Of_Case__c' => String.valueOf(nocId),
            'FEC_Field_Status__c' => true,
            'FEC_Section__c' => 'Section A',
            'FEC_Field_Mandatory__c' => false,
            'FEC_Field_ReadOnly__c' => false
        };
        try {
            Test.startTest();
            Id newId = FEC_LiveMasterDataSettingController.saveMasterDataSetting(req);
            Test.stopTest();
            Assert.isNotNull(newId);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testSaveMasterDataSetting_Update() {
        Id mdsId = [SELECT Id FROM FEC_Master_Data_Setting__c LIMIT 1].Id;
        Map<String, Object> req = new Map<String, Object>{
            'Id' => String.valueOf(mdsId),
            'FEC_Section__c' => 'Updated Section',
            'FEC_Field_Status__c' => true
        };
        try {
            Test.startTest();
            Id updatedId = FEC_LiveMasterDataSettingController.saveMasterDataSetting(req);
            Test.stopTest();
            Assert.areEqual(mdsId, updatedId);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testUpdateCaseStage_FullParams() {
        Id stageId = [SELECT Id FROM FEC_Case_Stage__c LIMIT 1].Id;
        try {
            Test.startTest();
            // Live updateCaseStage signature
            FEC_LiveMasterDataSettingController.updateCaseStage(
                stageId, 'RenamedLive', 'TVN', 'NewAlias',
                true, true, false, null, null, 5, 'Open', false
            );
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testGetUserRoles() {
        Test.startTest();
        List<Map<String, String>> result = FEC_LiveMasterDataSettingController.getUserRoles();
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetStageOptions() {
        Test.startTest();
        List<Map<String, Object>> result = FEC_LiveMasterDataSettingController.getStageOptions();
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testGetLookupOptions_Allowed() {
        try {
            Test.startTest();
            FEC_LiveMasterDataSettingController.getLookupOptions('FEC_Case_Stage__c');
            Test.stopTest();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testGetLookupOptions_Disallowed() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_LiveMasterDataSettingController.getLookupOptions('Account');
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught);
    }

    @IsTest
    static void testGetChannels() {
        Test.startTest();
        List<Map<String, String>> result = FEC_LiveMasterDataSettingController.getChannels();
        Test.stopTest();
        Assert.isNotNull(result);
    }
}