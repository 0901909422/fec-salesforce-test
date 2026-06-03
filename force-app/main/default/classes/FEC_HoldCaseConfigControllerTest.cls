/**
 * @description Unit tests for FEC_HoldCaseConfigController.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_HoldCaseConfigControllerTest {

    @testSetup
    static void setupData() {
        // NOC requires linked product type, business process, etc. — minimal NOC for tests
        FEC_MDM_Product_Type__c pt = new FEC_MDM_Product_Type__c(FEC_Code__c = 'PT_HC1');
        insert pt;

        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Code__c = 'NOC_HC_001'
        );
        insert noc;

        // NFU Code
        insert new FEC_MDM_NFU_Code__c(Name = 'CS_NFU_TEST', FEC_Reason_VN__c = 'Test reason', FEC_Active__c = true);

        // MDM Channel
        insert new FEC_MDM_Channel__c(
            Name = 'TestCh',
            FEC_Code__c = 'CH_HC_T',
            FEC_Channel_ID__c = 'TID',
            FEC_Channel_Vietnamese_name__c = 'Test',
            FEC_Channel_Status__c = true,
            FEC_Self_Service_Flag__c = false
        );

        // 1 Hold Case Config
        insert new FEC_MDM_Hold_Case_Config__c(
            FEC_Nature_of_Case__c = noc.Id,
            FEC_Active__c = true,
            FEC_Channel__c = 'TestCh',
            FEC_NFU_Code__c = 'CS_NFU_TEST',
            Hold_Case_Type__c = 'Auto'
        );
    }

    @IsTest
    static void testGetConfigsByNoc_ReturnsRows() {
        Id nocId = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1].Id;
        Test.startTest();
        List<Map<String, Object>> rows = FEC_HoldCaseConfigController.getConfigsByNoc(nocId);
        Test.stopTest();
        Assert.isFalse(rows.isEmpty(), 'Phải có config record');
        Assert.areEqual(1, rows.size(), '1 config trong setup');
    }

    @IsTest
    static void testGetConfigsByNoc_NullId() {
        Test.startTest();
        List<Map<String, Object>> rows = FEC_HoldCaseConfigController.getConfigsByNoc(null);
        Test.stopTest();
        Assert.isTrue(rows.isEmpty(), 'null nocId → empty list');
    }

    @IsTest
    static void testSaveConfig_Insert() {
        Id nocId = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1].Id;
        FEC_MDM_Hold_Case_Config__c cfg = new FEC_MDM_Hold_Case_Config__c(
            FEC_Nature_of_Case__c = nocId,
            FEC_Active__c = true,
            Hold_Case_Type__c = 'Manual'
        );

        Test.startTest();
        Id newId = FEC_HoldCaseConfigController.saveConfig(cfg);
        Test.stopTest();

        Assert.isNotNull(newId, 'Phải return Id mới');
    }

    @IsTest
    static void testSaveConfig_Update() {
        FEC_MDM_Hold_Case_Config__c cfg = [SELECT Id, FEC_Active__c FROM FEC_MDM_Hold_Case_Config__c LIMIT 1];
        cfg.FEC_Active__c = false;

        Test.startTest();
        Id updatedId = FEC_HoldCaseConfigController.saveConfig(cfg);
        Test.stopTest();

        Assert.areEqual(cfg.Id, updatedId);
        FEC_MDM_Hold_Case_Config__c reloaded = [SELECT FEC_Active__c FROM FEC_MDM_Hold_Case_Config__c WHERE Id = :cfg.Id];
        Assert.isFalse(reloaded.FEC_Active__c);
    }

    @IsTest
    static void testDeleteConfig_Success() {
        Id cfgId = [SELECT Id FROM FEC_MDM_Hold_Case_Config__c LIMIT 1].Id;

        Test.startTest();
        FEC_HoldCaseConfigController.deleteConfig(cfgId);
        Test.stopTest();

        Integer remaining = [SELECT COUNT() FROM FEC_MDM_Hold_Case_Config__c WHERE Id = :cfgId];
        Assert.areEqual(0, remaining);
    }

    @IsTest
    static void testDeleteConfig_NullThrows() {
        Boolean caught = false;
        try {
            FEC_HoldCaseConfigController.deleteConfig(null);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'null Id phải throw');
    }

    @IsTest
    static void testGetNfuCodes() {
        Test.startTest();
        List<Map<String, String>> codes = FEC_HoldCaseConfigController.getNfuCodes();
        Test.stopTest();
        Assert.isFalse(codes.isEmpty(), 'Phải có NFU codes');
        Assert.isTrue(codes[0].containsKey('code'), 'Có key "code"');
        Assert.isTrue(codes[0].containsKey('reasonVN'), 'Có key "reasonVN"');
    }

    @IsTest
    static void testGetCaseStatusOptions() {
        Test.startTest();
        List<Map<String, String>> opts = FEC_HoldCaseConfigController.getCaseStatusOptions();
        Test.stopTest();
        Assert.isFalse(opts.isEmpty(), 'Status options không rỗng');
        // First option = ALL
        Assert.areEqual('ALL', opts[0].get('value'), 'First option phải là ALL');
    }

    @IsTest
    static void testGetChannelNameOptions() {
        Test.startTest();
        List<Map<String, String>> opts = FEC_HoldCaseConfigController.getChannelNameOptions();
        Test.stopTest();
        Assert.isFalse(opts.isEmpty(), 'Channel options không rỗng');
    }
}