/**
 * FEC_CheckCampaignStatusBatchTest
 * Tests for FEC_CheckCampaignStatusBatch.
 * Validates: Requirements 9.1, 9.4, 9.5, 1.1, 1.2, 1.3, 1.5, 1.6, 1.7, 1.8
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

    // ─── Bug Condition Exploration Tests ───────────────────────────
    // These tests demonstrate the bug on UNFIXED code.
    // They call @TestVisible methods directly with mock data containing
    // lowercase field names (the correct OData schema).
    // EXPECTED: FAIL on unfixed code (proves bug exists).
    // Validates: Requirements 1.1, 1.2, 1.3, 1.5, 1.6, 1.7, 1.8

    @isTest
    static void testProcessODataResults_CompositeKeyMatching() {
        // Build mock scope record with known account + record ID
        FEC_CS_Campaign__c csMapping = [SELECT Id FROM FEC_CS_Campaign__c LIMIT 1];
        FEC_DataCampaign__c scopeRec = new FEC_DataCampaign__c(
            FEC_CS_Campaign__c = csMapping.Id,
            FEC_AppId__c = 'APP_EXPLORE',
            FEC_AccountOrContractNumber__c = 'ACC001',
            FEC_RecordId__c = 'REC001',
            FEC_ProductLine__c = 'Loan',
            FEC_RecordStatus__c = FEC_Constants.CAMPAIGN_STATUS_NEW,
            FEC_IsPushed__c = true,
            FEC_CampaignCallingList__c = 'CL001',
            FEC_MaxCallAttempt__c = 3,
            FEC_RecordLifetime__c = 2,
            FEC_CurrentCallAttempt__c = 0,
            FEC_RecordCurrentLifetime__c = 0
        );
        insert scopeRec;

        // Build mock OData SObject using the external object type
        // The external object uses lowercase field names per PostgreSQL schema
        SObject mockOData = Schema.getGlobalDescribe()
            .get('PostgresCampaignLog__x').newSObject();
        mockOData.put('account_or_contract_number__c', 'ACC001');
        mockOData.put('record_id__c', 'REC001');
        mockOData.put('number4__c', 42);
        mockOData.put('number5__c', 99);
        mockOData.put('record_current_lifetime__c', 1);
        mockOData.put('insertion_date__c', DateTime.now());
        mockOData.put('callback_requested__c', 'Yes');
        mockOData.put('current_call_attempt__c', 2);
        mockOData.put('send_to_commsdb__c', 'true');
        mockOData.put('sent_instantly__c', 'false');
        mockOData.put('is_max_attempt__c', 'true');

        List<SObject> mockODataResults = new List<SObject>{ mockOData };
        List<FEC_DataCampaign__c> scope = new List<FEC_DataCampaign__c>{ scopeRec };

        Test.startTest();
        FEC_CheckCampaignStatusBatch batch = new FEC_CheckCampaignStatusBatch();
        List<FEC_DataCampaign__c> recordsToUpdate = batch.processODataResults(
            mockODataResults, scope
        );
        Test.stopTest();

        // Bug condition: unfixed code keys map by CONTRACT_NUMBER__c (null on mock)
        // so resultMap lookup fails and returns empty list
        Assert.isFalse(recordsToUpdate.isEmpty(),
            'processODataResults should match OData results to scope records ' +
            'using account_or_contract_number__c + record_id__c composite key');
    }

    @isTest
    static void testApplyODataUpdate_LowercaseFieldMapping() {
        // Build a target FEC_DataCampaign__c record
        FEC_CS_Campaign__c csMapping = [SELECT Id FROM FEC_CS_Campaign__c LIMIT 1];
        FEC_DataCampaign__c rec = new FEC_DataCampaign__c(
            FEC_CS_Campaign__c = csMapping.Id,
            FEC_AppId__c = 'APP_FIELD_MAP',
            FEC_AccountOrContractNumber__c = 'ACC002',
            FEC_RecordId__c = 'REC002',
            FEC_ProductLine__c = 'Loan',
            FEC_RecordStatus__c = FEC_Constants.CAMPAIGN_STATUS_NEW,
            FEC_IsPushed__c = true,
            FEC_CampaignCallingList__c = 'CL001',
            FEC_MaxCallAttempt__c = 3,
            FEC_RecordLifetime__c = 2,
            FEC_CurrentCallAttempt__c = 0,
            FEC_RecordCurrentLifetime__c = 0
        );
        insert rec;

        // Build mock OData SObject with all 9 lowercase field names
        DateTime testInsertionDate = DateTime.newInstance(2025, 6, 15, 10, 0, 0);
        SObject mockOData = Schema.getGlobalDescribe()
            .get('PostgresCampaignLog__x').newSObject();
        mockOData.put('account_or_contract_number__c', 'ACC002');
        mockOData.put('record_id__c', 'REC002');
        mockOData.put('number4__c', 42);
        mockOData.put('number5__c', 99);
        mockOData.put('record_current_lifetime__c', 1);
        mockOData.put('insertion_date__c', testInsertionDate);
        mockOData.put('callback_requested__c', 'Yes');
        mockOData.put('current_call_attempt__c', 2);
        mockOData.put('send_to_commsdb__c', 'true');
        mockOData.put('sent_instantly__c', 'false');
        mockOData.put('is_max_attempt__c', 'true');

        Test.startTest();
        FEC_CheckCampaignStatusBatch batch = new FEC_CheckCampaignStatusBatch();
        Boolean result = batch.applyODataUpdate(rec, mockOData);
        Test.stopTest();

        // Bug condition: unfixed code reads UPPERCASE field names (NUMBER4__c, etc.)
        // which return null from the mock SObject that has lowercase field names
        Assert.isTrue(result, 'applyODataUpdate should return true');
        Assert.areEqual(42, rec.FEC_Number4__c,
            'FEC_Number4__c should be mapped from number4__c');
        Assert.areEqual(99, rec.FEC_Number5__c,
            'FEC_Number5__c should be mapped from number5__c');
        Assert.areEqual(1, rec.FEC_RecordCurrentLifetime__c,
            'FEC_RecordCurrentLifetime__c should be mapped from record_current_lifetime__c');
        Assert.areEqual(testInsertionDate, rec.FEC_InsertionDate__c,
            'FEC_InsertionDate__c should be mapped from insertion_date__c');
        Assert.areEqual('Yes', rec.FEC_CallbackRequested__c,
            'FEC_CallbackRequested__c should be mapped from callback_requested__c');
        Assert.areEqual(2, rec.FEC_CurrentCallAttempt__c,
            'FEC_CurrentCallAttempt__c should be mapped from current_call_attempt__c');
        Assert.areEqual('true', rec.FEC_SendToCommsDB__c,
            'FEC_SendToCommsDB__c should be mapped from send_to_commsdb__c');
        Assert.areEqual('false', rec.FEC_SentInstantly__c,
            'FEC_SentInstantly__c should be mapped from sent_instantly__c');
        Assert.areEqual('true', rec.FEC_IsMaxAttempt__c,
            'FEC_IsMaxAttempt__c should be mapped from is_max_attempt__c');
    }

    // ─── Preservation Property Tests ───────────────────────────────
    // These tests verify existing behavior that must remain unchanged after the fix.
    // EXPECTED: PASS on UNFIXED code (confirms baseline behavior to preserve).
    // Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6

    @isTest
    static void testCollectAccountNumbers_SkipsBlanks() {
        // collectAccountNumbers is private, so we test indirectly via processODataResults.
        // Scope records with blank FEC_AccountOrContractNumber__c should never match
        // any OData result, and processODataResults should handle them gracefully.
        FEC_CS_Campaign__c csMapping = [SELECT Id FROM FEC_CS_Campaign__c LIMIT 1];

        // Record with blank account number
        FEC_DataCampaign__c blankRec = new FEC_DataCampaign__c(
            FEC_CS_Campaign__c = csMapping.Id,
            FEC_AppId__c = 'APP_BLANK',
            FEC_AccountOrContractNumber__c = '',
            FEC_ProductLine__c = 'Loan',
            FEC_RecordStatus__c = FEC_Constants.CAMPAIGN_STATUS_NEW,
            FEC_IsPushed__c = true,
            FEC_CampaignCallingList__c = 'CL001',
            FEC_MaxCallAttempt__c = 3,
            FEC_RecordLifetime__c = 2,
            FEC_CurrentCallAttempt__c = 0,
            FEC_RecordCurrentLifetime__c = 0
        );

        // Record with null account number
        FEC_DataCampaign__c nullRec = new FEC_DataCampaign__c(
            FEC_CS_Campaign__c = csMapping.Id,
            FEC_AppId__c = 'APP_NULL',
            FEC_AccountOrContractNumber__c = null,
            FEC_ProductLine__c = 'Loan',
            FEC_RecordStatus__c = FEC_Constants.CAMPAIGN_STATUS_NEW,
            FEC_IsPushed__c = true,
            FEC_CampaignCallingList__c = 'CL001',
            FEC_MaxCallAttempt__c = 3,
            FEC_RecordLifetime__c = 2,
            FEC_CurrentCallAttempt__c = 0,
            FEC_RecordCurrentLifetime__c = 0
        );

        // Record with valid account number
        FEC_DataCampaign__c validRec = new FEC_DataCampaign__c(
            FEC_CS_Campaign__c = csMapping.Id,
            FEC_AppId__c = 'APP_VALID',
            FEC_AccountOrContractNumber__c = 'VALID_ACC',
            FEC_ProductLine__c = 'Loan',
            FEC_RecordStatus__c = FEC_Constants.CAMPAIGN_STATUS_NEW,
            FEC_IsPushed__c = true,
            FEC_CampaignCallingList__c = 'CL001',
            FEC_MaxCallAttempt__c = 3,
            FEC_RecordLifetime__c = 2,
            FEC_CurrentCallAttempt__c = 0,
            FEC_RecordCurrentLifetime__c = 0
        );
        insert new List<FEC_DataCampaign__c>{ blankRec, nullRec, validRec };

        List<FEC_DataCampaign__c> scope = new List<FEC_DataCampaign__c>{
            blankRec, nullRec, validRec
        };

        // Call processODataResults with empty OData list — blank/null account records
        // should be skipped gracefully, no exceptions thrown
        Test.startTest();
        FEC_CheckCampaignStatusBatch batch = new FEC_CheckCampaignStatusBatch();
        List<FEC_DataCampaign__c> result = batch.processODataResults(
            new List<SObject>(), scope
        );
        Test.stopTest();

        // With no OData results, no records should be updated — including blank ones
        Assert.isTrue(result.isEmpty(),
            'processODataResults should return empty list when scope has blank ' +
            'account numbers and no OData results match');
    }

    @isTest
    static void testProcessODataResults_NoMatchSkipped() {
        // Scope records with account numbers that don't match any OData results
        // should be skipped without error — returned update list must be empty.
        // Validates: Requirements 3.3, 3.5
        FEC_CS_Campaign__c csMapping = [SELECT Id FROM FEC_CS_Campaign__c LIMIT 1];

        FEC_DataCampaign__c rec1 = new FEC_DataCampaign__c(
            FEC_CS_Campaign__c = csMapping.Id,
            FEC_AppId__c = 'APP_NOMATCH1',
            FEC_AccountOrContractNumber__c = 'NO_MATCH_ACC_1',
            FEC_ProductLine__c = 'Loan',
            FEC_RecordStatus__c = FEC_Constants.CAMPAIGN_STATUS_NEW,
            FEC_IsPushed__c = true,
            FEC_CampaignCallingList__c = 'CL001',
            FEC_MaxCallAttempt__c = 3,
            FEC_RecordLifetime__c = 2,
            FEC_CurrentCallAttempt__c = 0,
            FEC_RecordCurrentLifetime__c = 0
        );

        FEC_DataCampaign__c rec2 = new FEC_DataCampaign__c(
            FEC_CS_Campaign__c = csMapping.Id,
            FEC_AppId__c = 'APP_NOMATCH2',
            FEC_AccountOrContractNumber__c = 'NO_MATCH_ACC_2',
            FEC_ProductLine__c = 'Loan',
            FEC_RecordStatus__c = FEC_Constants.CAMPAIGN_STATUS_NEW,
            FEC_IsPushed__c = true,
            FEC_CampaignCallingList__c = 'CL001',
            FEC_MaxCallAttempt__c = 3,
            FEC_RecordLifetime__c = 2,
            FEC_CurrentCallAttempt__c = 0,
            FEC_RecordCurrentLifetime__c = 0
        );
        insert new List<FEC_DataCampaign__c>{ rec1, rec2 };

        List<FEC_DataCampaign__c> scope = new List<FEC_DataCampaign__c>{ rec1, rec2 };

        // Empty OData results — simulates no matching records from external object
        List<SObject> emptyODataResults = new List<SObject>();

        Test.startTest();
        FEC_CheckCampaignStatusBatch batch = new FEC_CheckCampaignStatusBatch();
        List<FEC_DataCampaign__c> recordsToUpdate = batch.processODataResults(
            emptyODataResults, scope
        );
        Test.stopTest();

        Assert.isTrue(recordsToUpdate.isEmpty(),
            'processODataResults should return empty list when no OData results ' +
            'match scope records — no error should be thrown');
    }

    @isTest
    static void testBatchLifecycle_LoggingPreserved() {
        // Execute the batch and verify FEC_Batch_Log__c records are created
        // with the correct batch name, confirming logging lifecycle is preserved.
        // Validates: Requirements 3.4, 3.6
        Test.startTest();
        FEC_CheckCampaignStatusBatch batch = new FEC_CheckCampaignStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<FEC_Batch_Log__c> logs = [
            SELECT FEC_Batch_Name__c, FEC_Status__c, FEC_Total_Job_Items__c,
                   FEC_Processed_Items__c, FEC_Error_Count__c
            FROM FEC_Batch_Log__c
            WHERE FEC_Batch_Name__c = 'FEC_CheckCampaignStatusBatch'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        Assert.isFalse(logs.isEmpty(),
            'Batch log record should be created during batch execution');
        Assert.areEqual('FEC_CheckCampaignStatusBatch', logs[0].FEC_Batch_Name__c,
            'Batch log should have correct batch name');
        Assert.isNotNull(logs[0].FEC_Status__c,
            'Batch log should have a status set after finish');
    }
}
