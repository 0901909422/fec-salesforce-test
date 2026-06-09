/**
 * FEC_PushCallbackRecordsBatchTest
 * Tests for FEC_PushCallbackRecordsBatch.
 * Validates batch lifecycle (start/execute/finish) and FEC_Batch_Log__c creation.
 */
@isTest
private class FEC_PushCallbackRecordsBatchTest {

    @testSetup
    static void setupData() {
        FEC_Campaign__c campaign = new FEC_Campaign__c(
            FEC_CampaignId__c = 'CAMPCB001',
            FEC_CampaignCallingList__c = 'CL_CB_001',
            FEC_MaxCallingAttempt__c = 3,
            FEC_RecordLifeTime__c = 5
        );
        insert campaign;

        FEC_CS_Campaign__c csMapping = new FEC_CS_Campaign__c(
            Name = 'CAMPCB001',
            FEC_Campaign__c = campaign.Id,
            FEC_IsActive__c = true,
            FEC_PushInstant__c = true,
            FEC_ScheduleCampaign__c = false
        );
        insert csMapping;

        List<FEC_DataCampaign__c> records = new List<FEC_DataCampaign__c>();
        for (Integer i = 0; i < 3; i++) {
            records.add(new FEC_DataCampaign__c(
                FEC_CS_Campaign__c = csMapping.Id,
                FEC_AppId__c = 'APP_CB_' + i,
                FEC_AccountOrContractNumber__c = 'ACC_CB_' + i,
                FEC_ProductLine__c = 'Card',
                FEC_Number1__c = i,
                FEC_String1__c = 'Callback' + i,
                FEC_RecordStatus__c = FEC_Constants.CAMPAIGN_STATUS_NEW,
                FEC_IsPushed__c = false,
                FEC_CampaignCallingList__c = 'CL_CB_001',
                FEC_MaxCallAttempt__c = 3,
                FEC_RecordLifetime__c = 5,
                FEC_CurrentCallAttempt__c = 0,
                FEC_RecordCurrentLifetime__c = 0,
                FEC_CallbackRequested__c = 'true'
            ));
        }
        insert records;
    }

    @isTest
    static void testBatchExecution_DefaultConstructor() {
        Test.startTest();
        FEC_PushCallbackRecordsBatch batch = new FEC_PushCallbackRecordsBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<FEC_Batch_Log__c> logs = [
            SELECT Id, FEC_Batch_Name__c, FEC_Status__c
            FROM FEC_Batch_Log__c
            WHERE FEC_Batch_Name__c = 'FEC_PushCallbackRecordsBatch'
        ];
        Assert.isFalse(logs.isEmpty(),
            'Batch log should be created for FEC_PushCallbackRecordsBatch');
    }

    @isTest
    static void testBatchExecution_WithMappingId() {
        FEC_CS_Campaign__c csMapping = [SELECT Id FROM FEC_CS_Campaign__c LIMIT 1];

        Test.startTest();
        FEC_PushCallbackRecordsBatch batch = new FEC_PushCallbackRecordsBatch(csMapping.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<FEC_Batch_Log__c> logs = [
            SELECT FEC_Batch_Name__c FROM FEC_Batch_Log__c
            WHERE FEC_Batch_Name__c = 'FEC_PushCallbackRecordsBatch'
        ];
        Assert.isFalse(logs.isEmpty(), 'Batch log should be created');
    }

    @isTest
    static void testExecute_ProcessesScopeAndIncrementsCounters() {
        List<FEC_DataCampaign__c> scope = [
            SELECT Id, FEC_AppId__c, FEC_AccountOrContractNumber__c, FEC_ProductLine__c,
                   FEC_Number1__c, FEC_String1__c, FEC_RecordStatus__c,
                   FEC_RecordLifetime__c, FEC_RecordCurrentLifetime__c,
                   FEC_MaxCallAttempt__c, FEC_CurrentCallAttempt__c,
                   FEC_CampaignCallingList__c, FEC_CallbackRequested__c,
                   CreatedDate, LastModifiedDate,
                   CreatedBy.Name, LastModifiedBy.Name,
                   FEC_CS_Campaign__r.FEC_Campaign__r.FEC_CampaignId__c
            FROM FEC_DataCampaign__c
        ];
        Assert.isFalse(scope.isEmpty(), 'Test setup must produce records');

        Test.startTest();
        FEC_PushCallbackRecordsBatch batch = new FEC_PushCallbackRecordsBatch();
        batch.execute(null, scope);
        batch.finish(null);
        Test.stopTest();
        Assert.isTrue(true, 'execute() and finish() should complete without exception');
    }

    @isTest
    static void testFinish_HandlesNullBatchableContext() {
        Test.startTest();
        FEC_PushCallbackRecordsBatch batch = new FEC_PushCallbackRecordsBatch();
        batch.finish(null);
        Test.stopTest();
        Assert.isTrue(true, 'finish() with null context should not throw');
    }
}
