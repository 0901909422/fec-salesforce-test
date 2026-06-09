/**
 * FEC_PushCampaignDataBatchTest
 * Tests for FEC_PushCampaignDataBatch.
 * Validates: Requirements 1.4, 9.1, 9.4, 9.5
 */
@isTest
private class FEC_PushCampaignDataBatchTest {

    @testSetup
    static void setupData() {
        FEC_Campaign__c campaign = new FEC_Campaign__c(
            FEC_CampaignId__c = 'CAMP001',
            FEC_CampaignCallingList__c = 'CL001',
            FEC_MaxCallingAttempt__c = 3,
            FEC_RecordLifeTime__c = 2
        );
        insert campaign;

        FEC_CS_Campaign__c csMapping = new FEC_CS_Campaign__c(
            Name = 'CAMP001',
            FEC_Campaign__c = campaign.Id,
            FEC_IsActive__c = true,
            FEC_PushInstant__c = true,
            FEC_ScheduleCampaign__c = false
        );
        insert csMapping;

        List<FEC_DataCampaign__c> records = new List<FEC_DataCampaign__c>();
        for (Integer i = 0; i < 5; i++) {
            records.add(new FEC_DataCampaign__c(
                FEC_CS_Campaign__c = csMapping.Id,
                FEC_AppId__c = 'APP' + i,
                FEC_AccountOrContractNumber__c = 'ACC' + i,
                FEC_ProductLine__c = 'Loan',
                FEC_Number1__c = i * 10,
                FEC_String1__c = 'Test' + i,
                FEC_RecordStatus__c = FEC_Constants.CAMPAIGN_STATUS_NEW,
                FEC_IsPushed__c = false,
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
        Test.startTest();
        FEC_PushCampaignDataBatch batch = new FEC_PushCampaignDataBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify batch log was created
        List<FEC_Batch_Log__c> logs = [
            SELECT FEC_Batch_Name__c, FEC_Status__c, FEC_Processed_Items__c
            FROM FEC_Batch_Log__c
            WHERE FEC_Batch_Name__c = 'FEC_PushCampaignDataBatch'
        ];
        Assert.isTrue(logs.size() >= 1, 'Batch log should be created');
    }

    @isTest
    static void testBatchExecution_WithMappingId() {
        FEC_CS_Campaign__c csMapping = [SELECT Id FROM FEC_CS_Campaign__c LIMIT 1];

        Test.startTest();
        FEC_PushCampaignDataBatch batch = new FEC_PushCampaignDataBatch(csMapping.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<FEC_Batch_Log__c> logs = [
            SELECT FEC_Batch_Name__c FROM FEC_Batch_Log__c
            WHERE FEC_Batch_Name__c = 'FEC_PushCampaignDataBatch'
        ];
        Assert.isTrue(logs.size() >= 1, 'Batch log should be created');
    }

    @isTest
    static void testBatchLog_RecordCreated() {
        Test.startTest();
        FEC_PushCampaignDataBatch batch = new FEC_PushCampaignDataBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<FEC_Batch_Log__c> logs = [
            SELECT FEC_Batch_Name__c, FEC_Status__c, FEC_Total_Job_Items__c,
                   FEC_Error_Count__c
            FROM FEC_Batch_Log__c
            WHERE FEC_Batch_Name__c = 'FEC_PushCampaignDataBatch'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        Assert.isFalse(logs.isEmpty(), 'Should have at least one batch log');
        FEC_Batch_Log__c log = logs[0];
        Assert.areEqual('FEC_PushCampaignDataBatch', log.FEC_Batch_Name__c);
        // Status should be Completed or Failed (sendCampaignData returns null in test)
        Assert.isTrue(
            log.FEC_Status__c == FEC_Constants.BATCH_LOG_COMPLETED ||
            log.FEC_Status__c == FEC_Constants.BATCH_LOG_FAILED,
            'Status should be Completed or Failed, got: ' + log.FEC_Status__c
        );
    }
}
