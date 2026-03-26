/**
 * FEC_CheckCampaignStatusBatchTest
 * Tests for FEC_CheckCampaignStatusBatch.
 * Validates: Requirements 9.1, 9.4, 9.5
 */
@isTest
private class FEC_CheckCampaignStatusBatchTest {

    @testSetup
    static void setupData() {
        FEC_Campaign__c campaign = new FEC_Campaign__c(
            FEC_CampaignId__c = 'CCAMP001',
            FEC_CampaignCallingList__c = 'CL001',
            FEC_MaxCallingAttempt__c = 3,
            FEC_RecordLifeTime__c = 2
        );
        insert campaign;

        FEC_CS_Campaign__c csMapping = new FEC_CS_Campaign__c(
            Name = 'CCAMP001',
            FEC_Campaign__c = campaign.Id,
            FEC_IsActive__c = true,
            FEC_PushInstant__c = false,
            FEC_ScheduleCampaign__c = true
        );
        insert csMapping;

        List<FEC_DataCampaign__c> records = new List<FEC_DataCampaign__c>();
        for (Integer i = 0; i < 5; i++) {
            records.add(new FEC_DataCampaign__c(
                FEC_CS_Campaign__c = csMapping.Id,
                FEC_AppId__c = 'CAPP' + i,
                FEC_AccountOrContractNumber__c = 'CACC' + i,
                FEC_ProductLine__c = 'Loan',
                FEC_RecordStatus__c = FEC_Constants.CAMPAIGN_STATUS_NEW,
                FEC_IsPushed__c = true,
                FEC_CampaignCallingList__c = 'CL001',
                FEC_MaxCallAttempt__c = 3,
                FEC_RecordLifetime__c = 2,
                FEC_CurrentCallAttempt__c = 0,
                FEC_RecordCurrentLifetime__c = 0
            ));
        }
        insert records;
    }

    @isTest
    static void testBatchExecution_HappyPath() {
        // API caller returns null in test context, so batch handles gracefully
        Test.startTest();
        FEC_CheckCampaignStatusBatch batch = new FEC_CheckCampaignStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<FEC_Batch_Log__c> logs = [
            SELECT FEC_Batch_Name__c, FEC_Status__c
            FROM FEC_Batch_Log__c
            WHERE FEC_Batch_Name__c = 'FEC_CheckCampaignStatusBatch'
        ];
        Assert.isTrue(logs.size() >= 1, 'Batch log should be created');
    }

    @isTest
    static void testBatchExecution_ApiReturnsNull() {
        // checkCampaignStatus returns null in test context (doPost returns null)
        // Batch should handle this as an API error
        Test.startTest();
        FEC_CheckCampaignStatusBatch batch = new FEC_CheckCampaignStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Records should remain unchanged since API returned null
        List<FEC_DataCampaign__c> records = [
            SELECT FEC_RecordStatus__c FROM FEC_DataCampaign__c
            WHERE FEC_RecordStatus__c = :FEC_Constants.CAMPAIGN_STATUS_NEW
        ];
        Assert.isTrue(records.size() >= 1,
            'Records should remain in New status when API returns null');
    }

    @isTest
    static void testBatchLog_RecordCreated() {
        Test.startTest();
        FEC_CheckCampaignStatusBatch batch = new FEC_CheckCampaignStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<FEC_Batch_Log__c> logs = [
            SELECT FEC_Batch_Name__c, FEC_Status__c, FEC_Total_Job_Items__c,
                   FEC_Error_Count__c
            FROM FEC_Batch_Log__c
            WHERE FEC_Batch_Name__c = 'FEC_CheckCampaignStatusBatch'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        Assert.isFalse(logs.isEmpty(), 'Should have batch log');
        Assert.areEqual('FEC_CheckCampaignStatusBatch', logs[0].FEC_Batch_Name__c);
    }

    @isTest
    static void testBatchExecution_EmptyScope() {
        // Delete all records to test empty scope
        delete [SELECT Id FROM FEC_DataCampaign__c];

        Test.startTest();
        FEC_CheckCampaignStatusBatch batch = new FEC_CheckCampaignStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<FEC_Batch_Log__c> logs = [
            SELECT FEC_Batch_Name__c, FEC_Status__c, FEC_Total_Job_Items__c
            FROM FEC_Batch_Log__c
            WHERE FEC_Batch_Name__c = 'FEC_CheckCampaignStatusBatch'
        ];
        Assert.isTrue(logs.size() >= 1, 'Batch log should still be created');
    }
}
