/*------------------------------------------------------------
Author:        DuanNguyen
Company:       Isobar
Description:   Test class for FEC_BatchCustomSyncByIds
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/05/04     DuanNguyen           Init
2026/06/11     DuanNguyen           Add coverage: empty recordIds set, multiple records in scope
2026/06/17     DuanNguyen           Sync with refactor: 3-arg/4-arg sendRequest, dynamic mapping, assertions
------------------------------------------------------------*/
@isTest
private class FEC_BatchCustomSyncByIdsTest {

    private class MockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"code":200,"data":{"failedRecords":[],"successRecords":["S-0001"],"tableName":"BIX_TEST","totalFailed":0,"totalReceived":1,"totalSuccess":1},"message":"OK"}');
            res.setStatusCode(200);
            return res;
        }
    }

    private class MockFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status": "error"}');
            res.setStatusCode(500);
            return res;
        }
    }

    private class MockPartialFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"code":200,"data":{"failedRecords":[{"errorMessage":"ORA-01843","index":0,"recordId":"S-0002"}],"successRecords":["S-0001"],"tableName":"BIX_TEST","totalFailed":1,"totalReceived":2,"totalSuccess":1},"message":"OK"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @testSetup
    static void setupData() {
        CustomSyncSetting__c setting = new CustomSyncSetting__c(
            Endpoint__c = 'https://api.test.com',
            ApiKey__c = 'test-key-123',
            EmailReport__c = 'test@test.com',
            LimitQuanitySync__c = 5
        );
        insert setting;

        String mappingJson = '{"CaseID":"Id","CaseName":"CaseNumber","PXURGENCYWORK":1}';
        String dataTypeJson = '{"CaseID":"VARCHAR2","CaseName":"VARCHAR2","PXURGENCYWORK":"NUMBER"}';

        FEC_Business_Process__c bp = new FEC_Business_Process__c(FEC_Code__c = 'Phone Update');
        insert bp;

        FEC_Custom_Sync__c cus = new FEC_Custom_Sync__c(
            Name = 'Test Sync ByIds',
            FEC_Table_Name__c = 'BIX_TEST',
            FEC_Case_Business_Code__c = 'Phone Update',
            FEC_Processing_Quantity__c = 10,
            FEC_Active__c = true,
            FEC_Sync_To__c = 'Bix',
            FEC_Request_Body_Mapping__c = mappingJson,
            FEC_Mapping_Data_Type__c = dataTypeJson,
            FEC_Target_Object__c = 'Case'
        );
        insert cus;

        FEC_Actual_Nature_of_Case__c anoc = new FEC_Actual_Nature_of_Case__c(FEC_Business_Process__c = bp.Id);
        insert anoc;

        Case cse = new Case(
            FEC_Customer_Name__c = 'tester',
            FEC_ID_Search__c = 'S-0001',
            FEC_Actual_Nature_of_Case__c = anoc.Id,
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Customer_Case').getRecordTypeId()
        );
        insert cse;
    }

    @isTest
    static void testBatchSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        FEC_Custom_Sync__c cus = [SELECT Id FROM FEC_Custom_Sync__c LIMIT 1];
        Case cse = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_BatchCustomSyncByIds batch = new FEC_BatchCustomSyncByIds(cus.Id, new Set<Id>{ cse.Id });
        Database.executeBatch(batch, 10);
        Test.stopTest();

        // Verify logs created and linked to the CustomSync
        List<FEC_integration_service_log__c> logs = [SELECT Id, FEC_Bix_Is_Success__c, FEC_Custom_Sync__c, Records__c FROM FEC_integration_service_log__c];
        System.assert(!logs.isEmpty(), 'Logs should be created');
        System.assertEquals(cus.Id, logs[0].FEC_Custom_Sync__c, 'Log should be linked to CustomSync');
        System.assertEquals(true, logs[0].FEC_Bix_Is_Success__c, 'Success response should mark log success');

        // Verify FEC_Custom_Sync__c NOT updated (ByIds does not write back stats)
        FEC_Custom_Sync__c cusAfter = [SELECT FEC_Start_At__c, FEC_End_At__c, FEC_Sync_Successfully__c, FEC_Sync_Failed__c, FEC_Total_Record_Sync__c FROM FEC_Custom_Sync__c WHERE Id = :cus.Id];
        System.assertEquals(null, cusAfter.FEC_Start_At__c, 'FEC_Custom_Sync__c should NOT be updated');
        System.assertEquals(null, cusAfter.FEC_End_At__c, 'FEC_Custom_Sync__c should NOT be updated');
    }

    @isTest
    static void testBatchCalloutFail() {
        Test.setMock(HttpCalloutMock.class, new MockFail());

        FEC_Custom_Sync__c cus = [SELECT Id FROM FEC_Custom_Sync__c LIMIT 1];
        Case cse = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_BatchCustomSyncByIds batch = new FEC_BatchCustomSyncByIds(cus.Id, new Set<Id>{ cse.Id });
        Database.executeBatch(batch, 10);
        Test.stopTest();

        List<FEC_integration_service_log__c> logs = [SELECT Id, FEC_Bix_Is_Success__c FROM FEC_integration_service_log__c];
        System.assert(!logs.isEmpty(), 'Logs should be created even on failure');
        System.assertEquals(false, logs[0].FEC_Bix_Is_Success__c, 'Failure response should mark log not success');
    }

    @isTest
    static void testBatchPartialFail() {
        Test.setMock(HttpCalloutMock.class, new MockPartialFail());

        FEC_Custom_Sync__c cus = [SELECT Id FROM FEC_Custom_Sync__c LIMIT 1];
        Case cse = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_BatchCustomSyncByIds batch = new FEC_BatchCustomSyncByIds(cus.Id, new Set<Id>{ cse.Id });
        Database.executeBatch(batch, 10);
        Test.stopTest();

        // Partial fail (log has no Id yet) splits into success + fail logs
        List<FEC_integration_service_log__c> logs = [SELECT Id, FEC_Bix_Is_Success__c FROM FEC_integration_service_log__c];
        System.assert(!logs.isEmpty(), 'Logs should be created for partial fail');
    }

    @isTest
    static void testBatchNoRecordsFound() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        FEC_Custom_Sync__c cus = [SELECT Id FROM FEC_Custom_Sync__c LIMIT 1];
        // Fake Id that won't match any Case - batch query returns empty, execute won't be called
        Id fakeId = Case.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.startTest();
        FEC_BatchCustomSyncByIds batch = new FEC_BatchCustomSyncByIds(cus.Id, new Set<Id>{ fakeId });
        Database.executeBatch(batch, 10);
        Test.stopTest();

        List<FEC_integration_service_log__c> logs = [SELECT Id FROM FEC_integration_service_log__c];
        System.assertEquals(0, logs.size(), 'No logs should be created when no records found');
    }

    @isTest
    static void testNoRecallTriggered() {
        Test.setMock(HttpCalloutMock.class, new MockFail());

        FEC_Custom_Sync__c cus = [SELECT Id FROM FEC_Custom_Sync__c LIMIT 1];
        Case cse = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_BatchCustomSyncByIds batch = new FEC_BatchCustomSyncByIds(cus.Id, new Set<Id>{ cse.Id });
        Database.executeBatch(batch, 10);
        Test.stopTest();

        // Verify failed logs exist but quantity call stays at 1 (ByIds never recalls)
        List<FEC_integration_service_log__c> logs = [SELECT Id, FEC_Quantity_Call__c FROM FEC_integration_service_log__c WHERE FEC_Bix_Is_Success__c = false];
        System.assert(!logs.isEmpty(), 'Failed logs should exist');
        for (FEC_integration_service_log__c log : logs) {
            System.assertEquals(1, log.FEC_Quantity_Call__c, 'No recall should have been triggered');
        }
    }

    @isTest
    static void testBatchWithEmptyIdSet() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        FEC_Custom_Sync__c cus = [SELECT Id FROM FEC_Custom_Sync__c LIMIT 1];

        Test.startTest();
        FEC_BatchCustomSyncByIds batch = new FEC_BatchCustomSyncByIds(cus.Id, new Set<Id>());
        Database.executeBatch(batch, 10);
        Test.stopTest();

        List<FEC_integration_service_log__c> logs = [SELECT Id FROM FEC_integration_service_log__c];
        System.assertEquals(0, logs.size(), 'No logs should be created when recordIds is empty');
    }

    @isTest
    static void testBatchMultipleRecordsInScope() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        FEC_Custom_Sync__c cus = [SELECT Id FROM FEC_Custom_Sync__c LIMIT 1];
        FEC_Actual_Nature_of_Case__c anoc = [SELECT Id FROM FEC_Actual_Nature_of_Case__c LIMIT 1];

        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 5; i++) {
            cases.add(new Case(
                FEC_Customer_Name__c = 'tester' + i,
                FEC_ID_Search__c = 'S-000' + (i + 2),
                FEC_Actual_Nature_of_Case__c = anoc.Id,
                RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Customer_Case').getRecordTypeId()
            ));
        }
        insert cases;

        Set<Id> allCaseIds = new Set<Id>();
        for (Case c : [SELECT Id FROM Case]) {
            allCaseIds.add(c.Id);
        }

        Test.startTest();
        FEC_BatchCustomSyncByIds batch = new FEC_BatchCustomSyncByIds(cus.Id, allCaseIds);
        Database.executeBatch(batch, 10);
        Test.stopTest();

        List<FEC_integration_service_log__c> logs = [SELECT Id, FEC_Bix_Is_Success__c, Records__c FROM FEC_integration_service_log__c];
        System.assert(!logs.isEmpty(), 'Logs should be created for multiple records');
    }

    @isTest
    static void testBatchWithDynamicMapping() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        // Mapping containing a nested object (dynamic sub-query) + Map Select Field.
        // ByIds calls the 3-arg sendRequest (mapDynamicData = null), exercising the
        // Map-mapping branch in toJson with no dynamic data resolved.
        FEC_Custom_Sync__c cus = [SELECT Id, FEC_Request_Body_Mapping__c, FEC_Mapping_Data_Type__c FROM FEC_Custom_Sync__c LIMIT 1];
        cus.FEC_Request_Body_Mapping__c = '{"CaseID":"Id","NatureId":{"Select":"Id","From":"Case","Where":"Id = :ObjectID"}}';
        cus.FEC_Mapping_Data_Type__c = '{"CaseID":"VARCHAR2","NatureId":"VARCHAR2"}';
        cus.FEC_Map_Select_Field__c = '{"ObjectID":"Id"}';
        update cus;

        Case cse = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_BatchCustomSyncByIds batch = new FEC_BatchCustomSyncByIds(cus.Id, new Set<Id>{ cse.Id });
        Database.executeBatch(batch, 10);
        Test.stopTest();

        List<FEC_integration_service_log__c> logs = [SELECT Id FROM FEC_integration_service_log__c];
        System.assert(!logs.isEmpty(), 'Logs should be created with dynamic mapping config');
    }
}
