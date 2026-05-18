/*------------------------------------------------------------
Author:        DuanNguyen
Company:       Isobar
Description:   Test class for FEC_BatchCustomSyncByIds
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/05/04     DuanNguyen           Init
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

        CustomSync__c cus = new CustomSync__c(
            Name = 'Test Sync ByIds',
            TableName__c = 'BIX_TEST',
            CaseBusinessCode__c = 'Phone Update',
            ProcessingQuantity__c = 10,
            Active__c = true,
            SyncTo__c = 'Bix',
            RequestBodyMapping__c = mappingJson,
            MappingDataType__c = dataTypeJson,
            TargetObject__c = 'Case'
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

        CustomSync__c cus = [SELECT Id FROM CustomSync__c LIMIT 1];
        Case cse = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_BatchCustomSyncByIds batch = new FEC_BatchCustomSyncByIds(cus.Id, new Set<Id>{ cse.Id });
        Database.executeBatch(batch, 10);
        Test.stopTest();

        // Verify logs created
        List<FEC_integration_service_log__c> logs = [SELECT Id, FEC_Bix_Is_Success__c, FEC_Custom_Sync__c FROM FEC_integration_service_log__c];
        System.assert(!logs.isEmpty(), 'Logs should be created');
        System.assertEquals(cus.Id, logs[0].FEC_Custom_Sync__c);

        // Verify CustomSync__c NOT updated
        CustomSync__c cusAfter = [SELECT StartAt__c, EndAt__c, SyncSuccessFully__c, SyncFailed__c, TotalRecordSync__c FROM CustomSync__c WHERE Id = :cus.Id];
        System.assertEquals(null, cusAfter.StartAt__c, 'CustomSync__c should NOT be updated');
        System.assertEquals(null, cusAfter.EndAt__c, 'CustomSync__c should NOT be updated');
    }

    @isTest
    static void testBatchCalloutFail() {
        Test.setMock(HttpCalloutMock.class, new MockFail());

        CustomSync__c cus = [SELECT Id FROM CustomSync__c LIMIT 1];
        Case cse = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_BatchCustomSyncByIds batch = new FEC_BatchCustomSyncByIds(cus.Id, new Set<Id>{ cse.Id });
        Database.executeBatch(batch, 10);
        Test.stopTest();

        List<FEC_integration_service_log__c> logs = [SELECT Id, FEC_Bix_Is_Success__c FROM FEC_integration_service_log__c];
        System.assert(!logs.isEmpty(), 'Logs should be created even on failure');
        System.assertEquals(false, logs[0].FEC_Bix_Is_Success__c);
    }

    @isTest
    static void testBatchPartialFail() {
        Test.setMock(HttpCalloutMock.class, new MockPartialFail());

        CustomSync__c cus = [SELECT Id FROM CustomSync__c LIMIT 1];
        Case cse = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_BatchCustomSyncByIds batch = new FEC_BatchCustomSyncByIds(cus.Id, new Set<Id>{ cse.Id });
        Database.executeBatch(batch, 10);
        Test.stopTest();

        List<FEC_integration_service_log__c> logs = [SELECT Id, FEC_Bix_Is_Success__c FROM FEC_integration_service_log__c];
        System.assert(!logs.isEmpty(), 'Logs should be created for partial fail');
    }

    @isTest
    static void testBatchNoRecordsFound() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        CustomSync__c cus = [SELECT Id FROM CustomSync__c LIMIT 1];
        // Fake Id that won't match any Case - batch query returns empty, execute won't be called
        Id fakeId = Case.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.startTest();
        FEC_BatchCustomSyncByIds batch = new FEC_BatchCustomSyncByIds(cus.Id, new Set<Id>{ fakeId });
        Database.executeBatch(batch, 10);
        Test.stopTest();

        // No records matched so execute() never fires, no logs created
        List<FEC_integration_service_log__c> logs = [SELECT Id FROM FEC_integration_service_log__c];
        System.assertEquals(0, logs.size(), 'No logs should be created when no records found');
    }

    @isTest
    static void testNoRecallTriggered() {
        Test.setMock(HttpCalloutMock.class, new MockFail());

        CustomSync__c cus = [SELECT Id FROM CustomSync__c LIMIT 1];
        Case cse = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_BatchCustomSyncByIds batch = new FEC_BatchCustomSyncByIds(cus.Id, new Set<Id>{ cse.Id });
        Database.executeBatch(batch, 10);
        Test.stopTest();

        // Verify failed logs exist but no recall incremented beyond 1
        List<FEC_integration_service_log__c> logs = [SELECT Id, FEC_Quantity_Call__c FROM FEC_integration_service_log__c WHERE FEC_Bix_Is_Success__c = false];
        for (FEC_integration_service_log__c log : logs) {
            System.assertEquals(1, log.FEC_Quantity_Call__c, 'No recall should have been triggered');
        }
    }
}
