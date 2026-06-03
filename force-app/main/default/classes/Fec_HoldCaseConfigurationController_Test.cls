@IsTest
private class Fec_HoldCaseConfigurationController_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Hold PT',
            FEC_Code__c = 'HPT' + suffix.right(4),
            FEC_Active__c = true
        );
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Hold Cat',
            FEC_Code__c = 'HCT' + suffix.right(4),
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Hold SubCat',
            FEC_Code__c = 'HSC' + suffix,
            FEC_Active__c = true
        );
        insert new List<SObject>{ pt, cat, subCat };

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Active__c = true
        );
        insert noc;

        insert new FEC_Hold_Case_Config__c(
            FEC_Nature_of_Cases__c = noc.Id,
            Hold_Case_Type__c = 'Auto',
            FEC_Channel__c = 'Inbound',
            FEC_Current_Status__c = 'Open',
            FEC_Changed_Status__c = 'Pending',
            FEC_Active__c = true
        );

        insert new FEC_Channel__c(
            Name = 'Hold Channel',
            FEC_Code__c = 'CH' + suffix,
            FEC_Channel_ID__c = 'CHID' + suffix,
            FEC_Channel_Vietnamese_name__c = 'Tổng đài',
            FEC_Channel_Status__c = true
        );

        insert new FEC_Case_Status__c(Name = 'Hold Status Open');

        insert new FEC_Hold_Case__c(
            FEC_NFU_Code__c = 'NFU01',
            FEC_NFU_Reason_VN__c = 'Reason test'
        );
    }

    @IsTest
    static void testGetHoldCaseConfigurations() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];

        Test.startTest();
        List<Fec_HoldCaseConfigurationController.HoldCaseWrapper> configs =
            Fec_HoldCaseConfigurationController.getHoldCaseConfigurations(noc.Id);
        Test.stopTest();

        System.assertEquals(1, configs.size());
        System.assertEquals('Auto', configs[0].holdCaseType);
        System.assertEquals('Open', configs[0].currentStatus);
    }

    @IsTest
    static void testGetHoldCaseConfigurations_NullId() {
        Test.startTest();
        List<Fec_HoldCaseConfigurationController.HoldCaseWrapper> configs =
            Fec_HoldCaseConfigurationController.getHoldCaseConfigurations(null);
        Test.stopTest();

        System.assertEquals(0, configs.size());
    }

    @IsTest
    static void testSaveHoldCaseConfig_Create() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];

        String payload = JSON.serialize(new Map<String, Object>{
            'natureOfCaseId' => noc.Id,
            'holdCaseType' => 'Manual',
            'channel' => 'Email',
            'active' => true
        });

        Test.startTest();
        Id configId = Fec_HoldCaseConfigurationController.saveHoldCaseConfig(payload);
        Test.stopTest();

        System.assertNotEquals(null, configId);
        FEC_Hold_Case_Config__c saved = [
            SELECT Hold_Case_Type__c, FEC_Channel__c
            FROM FEC_Hold_Case_Config__c
            WHERE Id = :configId
            LIMIT 1
        ];
        System.assertEquals('Manual', saved.Hold_Case_Type__c);
    }

    @IsTest
    static void testSaveHoldCaseConfig_Update() {
        FEC_Hold_Case_Config__c existing = [SELECT Id FROM FEC_Hold_Case_Config__c LIMIT 1];
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];

        String payload = JSON.serialize(new Map<String, Object>{
            'id' => existing.Id,
            'natureOfCaseId' => noc.Id,
            'holdCaseType' => 'Manual',
            'channel' => 'Outbound',
            'active' => false
        });

        Test.startTest();
        Id configId = Fec_HoldCaseConfigurationController.saveHoldCaseConfig(payload);
        Test.stopTest();

        FEC_Hold_Case_Config__c updated = [
            SELECT Hold_Case_Type__c, FEC_Active__c
            FROM FEC_Hold_Case_Config__c
            WHERE Id = :configId
            LIMIT 1
        ];
        System.assertEquals('Manual', updated.Hold_Case_Type__c);
        System.assertEquals(false, updated.FEC_Active__c);
    }

    @IsTest
    static void testSaveHoldCaseConfig_BlankPayload() {
        Test.startTest();
        try {
            Fec_HoldCaseConfigurationController.saveHoldCaseConfig('');
            System.assert(false, 'Blank payload phải throw.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSearchChannels() {
        Test.startTest();
        List<Fec_HoldCaseConfigurationController.ChannelWrapper> channels =
            Fec_HoldCaseConfigurationController.searchChannels('Tổng');
        List<Fec_HoldCaseConfigurationController.ChannelWrapper> empty =
            Fec_HoldCaseConfigurationController.searchChannels('');
        Test.stopTest();

        System.assertEquals(1, channels.size());
        System.assertEquals(0, empty.size());
    }

    @IsTest
    static void testSearchCaseStatus() {
        Test.startTest();
        List<FEC_Case_Status__c> statuses =
            Fec_HoldCaseConfigurationController.searchCaseStatus('Hold');
        Test.stopTest();

        System.assert(statuses.size() > 0);
    }

    @IsTest
    static void testGetNfuCodesAndSearch() {
        Test.startTest();
        List<FEC_Hold_Case__c> allCodes = Fec_HoldCaseConfigurationController.getNfuCodes();
        List<FEC_Hold_Case__c> searched = Fec_HoldCaseConfigurationController.searchNfuCodes('NFU');
        Test.stopTest();

        System.assert(allCodes.size() > 0);
        System.assert(searched.size() > 0);
    }

    @IsTest
    static void testGetHoldCaseConfigurationDetail() {
        FEC_Hold_Case_Config__c config = [SELECT Id FROM FEC_Hold_Case_Config__c LIMIT 1];

        Test.startTest();
        FEC_Hold_Case_Config__c detail =
            Fec_HoldCaseConfigurationController.getHoldCaseConfigurationDetail(config.Id);
        FEC_Hold_Case_Config__c nullDetail =
            Fec_HoldCaseConfigurationController.getHoldCaseConfigurationDetail(null);
        Test.stopTest();

        System.assertNotEquals(null, detail);
        System.assertEquals(config.Id, detail.Id);
        System.assertEquals(null, nullDetail);
    }

    @IsTest
    static void testGetHoldCaseConfigHistory() {
        FEC_Hold_Case_Config__c config = [SELECT Id FROM FEC_Hold_Case_Config__c LIMIT 1];
        config.FEC_Active__c = false;
        update config;

        Test.startTest();
        List<Fec_HoldCaseConfigurationController.HoldCaseConfigHistoryWrapper> history =
            Fec_HoldCaseConfigurationController.getHoldCaseConfigHistory(config.Id);
        List<Fec_HoldCaseConfigurationController.HoldCaseConfigHistoryWrapper> emptyHistory =
            Fec_HoldCaseConfigurationController.getHoldCaseConfigHistory(null);
        Test.stopTest();

        System.assertNotEquals(null, history);
        System.assertEquals(0, emptyHistory.size());
    }

    @IsTest
    static void testGetParentHoldCaseConfigurations() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];

        Test.startTest();
        List<Fec_HoldCaseConfigurationController.HoldCaseWrapper> parentConfigs =
            Fec_HoldCaseConfigurationController.getParentHoldCaseConfigurations(noc.Id);
        List<Fec_HoldCaseConfigurationController.HoldCaseWrapper> emptyParent =
            Fec_HoldCaseConfigurationController.getParentHoldCaseConfigurations(null);
        Test.stopTest();

        System.assert(parentConfigs.size() > 0);
        System.assertEquals(0, emptyParent.size());
    }

    @IsTest
    static void testGetHoldCaseConfigurations_ManualType() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
        insert new FEC_Hold_Case_Config__c(
            FEC_Nature_of_Cases__c = noc.Id,
            Hold_Case_Type__c = 'Manual',
            FEC_Channel__c = 'Email',
            FEC_Current_Status__c = 'Open',
            FEC_Changed_Status__c = 'Pending',
            FEC_Active__c = true
        );

        Test.startTest();
        List<Fec_HoldCaseConfigurationController.HoldCaseWrapper> configs =
            Fec_HoldCaseConfigurationController.getHoldCaseConfigurations(noc.Id);
        Test.stopTest();

        Boolean foundManual = false;
        for (Fec_HoldCaseConfigurationController.HoldCaseWrapper w : configs) {
            if (w.holdCaseType == 'Manual') {
                foundManual = true;
                System.assertEquals('', w.currentStatus);
                System.assertEquals('', w.changedStatus);
            }
        }
        System.assert(foundManual, 'Manual hold case phải clear status fields.');
    }

    @IsTest
    static void testGetHoldCaseConfigHistory_FieldLabels() {
        FEC_Hold_Case_Config__c config = [SELECT Id FROM FEC_Hold_Case_Config__c LIMIT 1];
        config.Hold_Case_Type__c = 'Manual';
        update config;

        Test.startTest();
        List<Fec_HoldCaseConfigurationController.HoldCaseConfigHistoryWrapper> history =
            Fec_HoldCaseConfigurationController.getHoldCaseConfigHistory(config.Id);
        Test.stopTest();

        System.assertNotEquals(null, history);
    }

    @IsTest
    static void testSaveHoldCaseConfig_AllFields() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
        FEC_Case_Stage__c stage;
        List<FEC_Case_Stage__c> stages = [SELECT Id FROM FEC_Case_Stage__c LIMIT 1];
        if (!stages.isEmpty()) {
            stage = stages[0];
        }

        String payload = JSON.serialize(new Map<String, Object>{
            'natureOfCaseId' => noc.Id,
            'holdCaseType' => 'Auto',
            'channel' => 'Inbound',
            'caseStage' => stage != null ? stage.Id : null,
            'currentStatus' => 'Open',
            'changedStatus' => 'Pending',
            'nfuCode' => 'NFU01',
            'active' => true
        });

        Test.startTest();
        Id configId = Fec_HoldCaseConfigurationController.saveHoldCaseConfig(payload);
        Test.stopTest();

        FEC_Hold_Case_Config__c saved = [
            SELECT FEC_NFU_Code__c, FEC_Current_Status__c
            FROM FEC_Hold_Case_Config__c
            WHERE Id = :configId
            LIMIT 1
        ];
        System.assertEquals('NFU01', saved.FEC_NFU_Code__c);
        System.assertEquals('Open', saved.FEC_Current_Status__c);
    }

    @IsTest
    static void testSearchCaseStatus_BlankKeyword() {
        Test.startTest();
        List<FEC_Case_Status__c> statuses =
            Fec_HoldCaseConfigurationController.searchCaseStatus('');
        Test.stopTest();

        System.assertNotEquals(null, statuses);
    }
}
