/**
 * FEC_GetCallingListResultBatchTest
 * Tests for FEC_GetCallingListResultBatch.
 * Validates: Requirements 9.1, 9.4, 9.5
 */
@isTest
private class FEC_GetCallingListResultBatchTest {

    @testSetup
    static void setupData() {
        FEC_Campaign__c campaign = new FEC_Campaign__c(
            FEC_CampaignId__c = 'GCAMP001',
            FEC_CampaignCallingList__c = 'CL001',
            FEC_MaxCallingAttempt__c = 3,
            FEC_RecordLifeTime__c = 2
        );
        insert campaign;

        FEC_CS_Campaign__c csMapping = new FEC_CS_Campaign__c(
            Name = 'GCAMP001',
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
                FEC_AppId__c = 'GAPP' + i,
                FEC_AccountOrContractNumber__c = 'GACC' + i,
                FEC_ProductLine__c = 'Card',
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
        // API caller returns null in test context
        Test.startTest();
        FEC_GetCallingListResultBatch batch = new FEC_GetCallingListResultBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<FEC_Batch_Log__c> logs = [
            SELECT FEC_Batch_Name__c, FEC_Status__c
            FROM FEC_Batch_Log__c
            WHERE FEC_Batch_Name__c = 'FEC_GetCallingListResultBatch'
        ];
        Assert.isTrue(logs.size() >= 1, 'Batch log should be created');
    }

    @isTest
    static void testBatchExecution_ApiReturnsNull() {
        Test.startTest();
        FEC_GetCallingListResultBatch batch = new FEC_GetCallingListResultBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Records should remain unchanged since API returned null
        List<FEC_DataCampaign__c> records = [
            SELECT FEC_CallStatus__c FROM FEC_DataCampaign__c
            WHERE FEC_CallStatus__c = null
        ];
        Assert.isTrue(records.size() >= 1,
            'Records should have no call status when API returns null');
    }

    @isTest
    static void testBatchLog_RecordCreated() {
        Test.startTest();
        FEC_GetCallingListResultBatch batch = new FEC_GetCallingListResultBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<FEC_Batch_Log__c> logs = [
            SELECT FEC_Batch_Name__c, FEC_Status__c, FEC_Total_Job_Items__c,
                   FEC_Error_Count__c
            FROM FEC_Batch_Log__c
            WHERE FEC_Batch_Name__c = 'FEC_GetCallingListResultBatch'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        Assert.isFalse(logs.isEmpty(), 'Should have batch log');
        Assert.areEqual('FEC_GetCallingListResultBatch', logs[0].FEC_Batch_Name__c);
    }

    @isTest
    static void testEvaluateCallStatus_ThroughBatch() {
        // Verify evaluateCallStatus mapping is correct (unit test via service)
        Assert.areEqual(FEC_Constants.CAMPAIGN_STATUS_RESOLVED_COMPLETED,
            FEC_CampaignBatchService.evaluateCallStatus('33'));
        Assert.areEqual(FEC_Constants.CAMPAIGN_STATUS_RESOLVED_COMPLETED,
            FEC_CampaignBatchService.evaluateCallStatus('9'));
        Assert.areEqual(FEC_Constants.CAMPAIGN_STATUS_RESOLVED_CANCELLED,
            FEC_CampaignBatchService.evaluateCallStatus('52'));
        Assert.areEqual(FEC_Constants.CAMPAIGN_STATUS_RESOLVED_CANCELLED,
            FEC_CampaignBatchService.evaluateCallStatus('51'));
        Assert.areEqual(FEC_Constants.CAMPAIGN_STATUS_PENDING_CALLBACK,
            FEC_CampaignBatchService.evaluateCallStatus('47'));
        Assert.areEqual(FEC_Constants.CAMPAIGN_STATUS_PENDING_CALLBACK,
            FEC_CampaignBatchService.evaluateCallStatus('48'));
        Assert.areEqual(FEC_Constants.CAMPAIGN_STATUS_PENDING_CALLBACK,
            FEC_CampaignBatchService.evaluateCallStatus('4'));
        Assert.areEqual(FEC_Constants.CAMPAIGN_STATUS_PENDING_RETRY,
            FEC_CampaignBatchService.evaluateCallStatus('21'));
        Assert.areEqual(FEC_Constants.CAMPAIGN_STATUS_PENDING_RETRY,
            FEC_CampaignBatchService.evaluateCallStatus('999'));
    }

    @isTest
    static void testBatchExecution_EmptyScope() {
        delete [SELECT Id FROM FEC_DataCampaign__c];

        Test.startTest();
        FEC_GetCallingListResultBatch batch = new FEC_GetCallingListResultBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<FEC_Batch_Log__c> logs = [
            SELECT FEC_Batch_Name__c FROM FEC_Batch_Log__c
            WHERE FEC_Batch_Name__c = 'FEC_GetCallingListResultBatch'
        ];
        Assert.isTrue(logs.size() >= 1, 'Batch log should still be created');
    }
}
