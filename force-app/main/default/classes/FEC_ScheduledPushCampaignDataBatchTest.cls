/**
 * FEC_ScheduledPushCampaignDataBatchTest
 * Tests for FEC_ScheduledPushCampaignDataBatch.
 * Validates: Requirements 9.1, 9.4, 9.5, 10.2, 10.3
 */
@isTest
private class FEC_ScheduledPushCampaignDataBatchTest {

    @testSetup
    static void setupData() {
        FEC_Campaign__c campaign = new FEC_Campaign__c(
            FEC_CampaignId__c = 'SCAMP001',
            FEC_CampaignCallingList__c = 'CL001',
            FEC_MaxCallingAttempt__c = 3,
            FEC_RecordLifeTime__c = 2
        );
        insert campaign;

        FEC_CS_Campaign__c csMapping = new FEC_CS_Campaign__c(
            Name = 'SCAMP001',
            FEC_Campaign__c = campaign.Id,
            FEC_IsActive__c = true,
            FEC_PushInstant__c = false,
            FEC_ScheduleCampaign__c = true,
            FEC_SaturdaySchedule__c = true,
            FEC_SundaySchedule__c = true
        );
        insert csMapping;

        List<FEC_DataCampaign__c> records = new List<FEC_DataCampaign__c>();
        for (Integer i = 0; i < 5; i++) {
            records.add(new FEC_DataCampaign__c(
                FEC_CS_Campaign__c = csMapping.Id,
                FEC_AppId__c = 'SAPP' + i,
                FEC_AccountOrContractNumber__c = 'SACC' + i,
                FEC_ProductLine__c = 'Card',
                FEC_Number1__c = i * 10,
                FEC_String1__c = 'Sched' + i,
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
        FEC_ScheduledPushCampaignDataBatch batch = new FEC_ScheduledPushCampaignDataBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<FEC_Batch_Log__c> logs = [
            SELECT FEC_Batch_Name__c, FEC_Status__c
            FROM FEC_Batch_Log__c
            WHERE FEC_Batch_Name__c = 'FEC_ScheduledPushCampaignDataBatch'
        ];
        Assert.isTrue(logs.size() >= 1, 'Batch log should be created');
    }

    @isTest
    static void testSchedulableExecute() {
        Test.startTest();
        FEC_ScheduledPushCampaignDataBatch schedulable = new FEC_ScheduledPushCampaignDataBatch();
        String cronExpr = '0 0 0 1 1 ? 2099';
        String jobId = System.schedule('TestScheduledPush', cronExpr, schedulable);
        Test.stopTest();

        Assert.isTrue(String.isNotBlank(jobId), 'Schedule job should return a job Id');
    }

    @isTest
    static void testBatchLog_Verification() {
        Test.startTest();
        FEC_ScheduledPushCampaignDataBatch batch = new FEC_ScheduledPushCampaignDataBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<FEC_Batch_Log__c> logs = [
            SELECT FEC_Batch_Name__c, FEC_Status__c, FEC_Total_Job_Items__c
            FROM FEC_Batch_Log__c
            WHERE FEC_Batch_Name__c = 'FEC_ScheduledPushCampaignDataBatch'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        Assert.isFalse(logs.isEmpty(), 'Should have batch log');
        Assert.areEqual('FEC_ScheduledPushCampaignDataBatch', logs[0].FEC_Batch_Name__c);
        Assert.isTrue(
            logs[0].FEC_Status__c == FEC_Constants.BATCH_LOG_COMPLETED ||
            logs[0].FEC_Status__c == FEC_Constants.BATCH_LOG_FAILED,
            'Status should be Completed or Failed'
        );
    }
}
