/**
 * FEC_CampaignControllerTest
 * Tests for FEC_CampaignController @AuraEnabled methods.
 * Validates: Requirements 9.2, 9.4, 9.5
 */
@isTest
private class FEC_CampaignControllerTest {

    @testSetup
    static void setupData() {
        FEC_Campaign__c campaign = new FEC_Campaign__c(
            FEC_CampaignId__c = 'CTRL001',
            FEC_CampaignCallingList__c = 'CL001',
            FEC_MaxCallingAttempt__c = 3,
            FEC_RecordLifeTime__c = 2
        );
        insert campaign;

        FEC_CS_Campaign__c csMapping = new FEC_CS_Campaign__c(
            Name = 'CTRL001',
            FEC_Campaign__c = campaign.Id,
            FEC_IsActive__c = true,
            FEC_PushInstant__c = true,
            FEC_ScheduleCampaign__c = false,
            FEC_SaturdaySchedule__c = false,
            FEC_SundaySchedule__c = false
        );
        insert csMapping;
    }

    @isTest
    static void testGetCampaignMappings() {
        Test.startTest();
        List<FEC_CS_Campaign__c> mappings = FEC_CampaignController.getCampaignMappings();
        Test.stopTest();

        Assert.isTrue(mappings.size() >= 1, 'Should return at least one mapping');
    }

    @isTest
    static void testGetCampaignConfigs() {
        Test.startTest();
        List<FEC_Campaign__c> configs = FEC_CampaignController.getCampaignConfigs();
        Test.stopTest();

        Assert.isTrue(configs.size() >= 1, 'Should return at least one config');
        Assert.areEqual('CTRL001', configs[0].FEC_CampaignId__c);
    }

    @isTest
    static void testGetInProgressSummary() {
        FEC_CS_Campaign__c csMapping = [SELECT Id FROM FEC_CS_Campaign__c LIMIT 1];

        // Insert a data record
        insert new FEC_DataCampaign__c(
            FEC_CS_Campaign__c = csMapping.Id,
            FEC_AppId__c = 'APP001',
            FEC_AccountOrContractNumber__c = 'ACC001',
            FEC_ProductLine__c = 'Loan',
            FEC_RecordStatus__c = 'New',
            FEC_Number1__c = 100,
            FEC_CampaignCallingList__c = 'CL001',
            FEC_MaxCallAttempt__c = 3,
            FEC_RecordLifetime__c = 2,
            FEC_CurrentCallAttempt__c = 0,
            FEC_RecordCurrentLifetime__c = 0
        );

        Test.startTest();
        Map<String, Object> result = FEC_CampaignController.getInProgressSummary(csMapping.Id);
        Test.stopTest();

        Assert.isTrue(result.containsKey('count'), 'Result should contain count');
        Assert.isTrue(result.containsKey('data'), 'Result should contain data');
        Assert.areEqual(1, (Integer) result.get('count'));
    }

    @isTest
    static void testSaveMapping_NewMapping() {
        FEC_Campaign__c campaign = [SELECT Id FROM FEC_Campaign__c LIMIT 1];

        Map<String, Object> mappingData = new Map<String, Object>{
            'Name' => 'NewMapping',
            'FEC_Campaign__c' => campaign.Id,
            'FEC_IsActive__c' => false
        };

        Test.startTest();
        String result = FEC_CampaignController.saveMapping(mappingData);
        Test.stopTest();

        Assert.areEqual(FEC_ConstantCommon.SUCCESS_MESSAGE, result);
    }

    @isTest
    static void testSaveMapping_UpdateExisting() {
        FEC_CS_Campaign__c existing = [SELECT Id FROM FEC_CS_Campaign__c LIMIT 1];
        FEC_Campaign__c campaign = [SELECT Id FROM FEC_Campaign__c LIMIT 1];

        Map<String, Object> mappingData = new Map<String, Object>{
            'Id' => existing.Id,
            'Name' => 'UpdatedMapping',
            'FEC_Campaign__c' => campaign.Id,
            'FEC_IsActive__c' => true
        };

        Test.startTest();
        String result = FEC_CampaignController.saveMapping(mappingData);
        Test.stopTest();

        Assert.areEqual(FEC_ConstantCommon.SUCCESS_MESSAGE, result);
    }

    @isTest
    static void testDeleteMapping() {
        // Create a mapping to delete
        FEC_Campaign__c campaign = [SELECT Id FROM FEC_Campaign__c LIMIT 1];
        FEC_CS_Campaign__c toDelete = new FEC_CS_Campaign__c(
            Name = 'ToDelete',
            FEC_Campaign__c = campaign.Id,
            FEC_IsActive__c = false
        );
        insert toDelete;

        Test.startTest();
        FEC_CampaignController.deleteMapping(toDelete.Id);
        Test.stopTest();

        List<FEC_CS_Campaign__c> remaining = [
            SELECT Id FROM FEC_CS_Campaign__c WHERE Id = :toDelete.Id
        ];
        Assert.areEqual(0, remaining.size(), 'Mapping should be deleted');
    }

    @isTest
    static void testUploadCampaignData_ValidData() {
        FEC_CS_Campaign__c csMapping = [SELECT Id, Name FROM FEC_CS_Campaign__c LIMIT 1];

        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        rows.add(new Map<String, Object>{
            'Campaign ID' => csMapping.Name,
            'ProductLine' => 'Loan',
            'App ID' => 'APP001',
            'Account or Contract number' => 'ACC001',
            'Number 1' => 100,
            'Number 2' => 200,
            'Number 3' => 300,
            'Number 4' => 400,
            'Number 5' => 500,
            'String 1' => 'S1',
            'String 2' => 'S2',
            'String 3' => 'S3',
            'String 4' => 'S4',
            'String 5' => 'S5'
        });

        String jsonString = JSON.serialize(rows);

        Test.startTest();
        String result = FEC_CampaignController.uploadCampaignData(jsonString, csMapping.Id);
        Test.stopTest();

        Assert.areEqual(FEC_ConstantCommon.SUCCESS_MESSAGE, result);

        List<FEC_DataCampaign__c> inserted = [
            SELECT FEC_AppId__c FROM FEC_DataCampaign__c
            WHERE FEC_CS_Campaign__c = :csMapping.Id
        ];
        Assert.areEqual(1, inserted.size(), 'Should insert one record');
    }

    @isTest
    static void testUploadCampaignData_InvalidData() {
        FEC_CS_Campaign__c csMapping = [SELECT Id, Name FROM FEC_CS_Campaign__c LIMIT 1];

        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        rows.add(new Map<String, Object>{
            'Campaign ID' => 'WRONG_CODE',
            'ProductLine' => 'InvalidProduct',
            'App ID' => '',
            'Account or Contract number' => '',
            'Number 1' => 'notANumber',
            'Number 2' => 100,
            'Number 3' => 100
        });

        String jsonString = JSON.serialize(rows);

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            FEC_CampaignController.uploadCampaignData(jsonString, csMapping.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw AuraHandledException for invalid data');
    }

    @isTest
    static void testUploadCampaignData_DuplicateKeys() {
        FEC_CS_Campaign__c csMapping = [SELECT Id, Name FROM FEC_CS_Campaign__c LIMIT 1];

        Map<String, Object> row = new Map<String, Object>{
            'Campaign ID' => csMapping.Name,
            'ProductLine' => 'Loan',
            'App ID' => 'APP001',
            'Account or Contract number' => 'ACC001',
            'Number 1' => 100,
            'Number 2' => 200,
            'Number 3' => 300
        };

        List<Map<String, Object>> rows = new List<Map<String, Object>>{ row, row };
        String jsonString = JSON.serialize(rows);

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            FEC_CampaignController.uploadCampaignData(jsonString, csMapping.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            Assert.isTrue(e.getMessage().contains('Duplicate composite key'),
                'Error should mention duplicate: ' + e.getMessage());
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw for duplicate keys');
    }

    @isTest
    static void testUploadCampaignData_BlankCsCampaignId() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            FEC_CampaignController.uploadCampaignData('[]', '');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw for blank csCampaignId');
    }

    @isTest
    static void testUploadCampaignData_EmptyArray() {
        FEC_CS_Campaign__c csMapping = [SELECT Id FROM FEC_CS_Campaign__c LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            FEC_CampaignController.uploadCampaignData('[]', csMapping.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw for empty data array');
    }

    @isTest
    static void testSaveConfigurationDetails() {
        FEC_CS_Campaign__c csMapping = [SELECT Id FROM FEC_CS_Campaign__c LIMIT 1];

        Test.startTest();
        FEC_CampaignController.saveConfigurationDetails(
            csMapping.Id, true, true, false
        );
        Test.stopTest();

        FEC_CS_Campaign__c updated = [
            SELECT FEC_ScheduleCampaign__c, FEC_SaturdaySchedule__c, FEC_SundaySchedule__c
            FROM FEC_CS_Campaign__c WHERE Id = :csMapping.Id
        ];
        Assert.areEqual(true, updated.FEC_ScheduleCampaign__c);
        Assert.areEqual(true, updated.FEC_SaturdaySchedule__c);
        Assert.areEqual(false, updated.FEC_SundaySchedule__c);
    }

    @isTest
    static void testPushRecords() {
        FEC_CS_Campaign__c csMapping = [SELECT Id FROM FEC_CS_Campaign__c LIMIT 1];

        Test.startTest();
        String jobId = FEC_CampaignController.pushRecords(csMapping.Id);
        Test.stopTest();

        Assert.isTrue(String.isNotBlank(jobId), 'Should return a batch job Id');
    }

    @isTest
    static void testPushRecords_NullId() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            FEC_CampaignController.pushRecords(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw for null mappingId');
    }
}
