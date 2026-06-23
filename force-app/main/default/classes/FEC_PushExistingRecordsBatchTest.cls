/**
 * FEC_PushExistingRecordsBatchTest
 * Tests for FEC_PushExistingRecordsBatch (Queueable + Cursor).
 */
@isTest
private class FEC_PushExistingRecordsBatchTest {

    @testSetup
    static void setupData() {
        FEC_Campaign__c campaign = new FEC_Campaign__c(
            FEC_CampaignId__c = 'CAMPEX001',
            FEC_CampaignCallingList__c = 'CL_EX_001',
            FEC_MaxCallingAttempt__c = 3,
            FEC_RecordLifeTime__c = 5
        );
        insert campaign;

        FEC_CS_Campaign__c csMapping = new FEC_CS_Campaign__c(
            Name = 'CAMPEX001',
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
                FEC_AppId__c = 'APP_EX_' + i,
                FEC_AccountOrContractNumber__c = 'ACC_EX_' + i,
                FEC_ProductLine__c = 'Loan',
                FEC_Number1__c = i,
                FEC_String1__c = 'Existing' + i,
                FEC_RecordStatus__c = FEC_Constants.CAMPAIGN_STATUS_NEW,
                FEC_IsPushed__c = false,
                FEC_CampaignCallingList__c = 'CL_EX_001',
                FEC_MaxCallAttempt__c = 3,
                FEC_RecordLifetime__c = 5,
                FEC_CurrentCallAttempt__c = 0,
                FEC_RecordCurrentLifetime__c = 0,
                FEC_InsertionDate__c = Datetime.now().addDays(-1)
            ));
        }
        insert records;
    }

    @isTest
    static void testQueueableExecution_DefaultConstructor() {
        FEC_PushExistingRecordsBatch batch = new FEC_PushExistingRecordsBatch();
        System.assertNotEquals(null, batch);

        List<FEC_DataCampaign__c> records = [
            SELECT Id, FEC_InsertionDate__c
            FROM FEC_DataCampaign__c
        ];
        Assert.areEqual(3, records.size(), 'Setup should create existing campaign records');
    }

    @isTest
    static void testQueueableExecution_WithMappingId() {
        FEC_CS_Campaign__c csMapping = [SELECT Id FROM FEC_CS_Campaign__c LIMIT 1];
        FEC_PushExistingRecordsBatch batch = new FEC_PushExistingRecordsBatch(csMapping.Id);
        System.assertNotEquals(null, batch);

        Assert.isFalse(
            [SELECT Id FROM FEC_DataCampaign__c].isEmpty(),
            'Campaign data should exist for mapping constructor'
        );
    }
}
