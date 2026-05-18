/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Test class Sync Data 
Test Class:     
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/03/31     Duan Nguyen          Init
2026/04/08     Duan Nguyen          Rewrite - increase coverage FEC_BatchCustomSync
2026/04/21     Duan Nguyen          Update for List<FEC_integration_service_log__c> return, Records__c, MappingDataType__c
2026/04/29     Kiro                 Add coverage: FEC_QueueReportCustomSyncBix, Recall partial fail, extractFieldsFromMapping
------------------------------------------------------------*/
@isTest
private class FEC_CustomSyncAllInOneTest {

    private class FEC_CustomSyncMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"code":200,"data":{"failedRecords":[],"successRecords":["S-0001"],"tableName":"BIX_TEST","totalFailed":0,"totalReceived":1,"totalSuccess":1},"message":"OK"}');
            res.setStatusCode(200);
            return res;
        }
    }

    private class FEC_CustomSyncMockFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status": "error"}');
            res.setStatusCode(500);
            return res;
        }
    }

    private class FEC_CustomSyncMockPartialFail implements HttpCalloutMock {
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

        FEC_Business_Process__c codeType = new FEC_Business_Process__c();
        codeType.FEC_Code__c = 'Phone Update';
        insert codeType;

        CustomSync__c cus = new CustomSync__c(
            Name = 'Test Sync',
            TableName__c = 'BIX_TEST',
            CaseBusinessCode__c = 'Phone Update',
            ProcessingQuantity__c = 1,
            Active__c = true,
            SyncTo__c = 'Bix',
            RequestBodyMapping__c = mappingJson,
            MappingDataType__c = dataTypeJson,
            TargetObject__c = 'Case'
        );
        insert cus;

        CustomSync__c cus2 = new CustomSync__c(
            Name = 'Test Sync 2',
            TableName__c = 'BIX_TEST',
            CaseBusinessCode__c = 'Phone Update',
            ProcessingQuantity__c = 1,
            Active__c = true,
            SyncTo__c = 'Bix',
            RequestBodyMapping__c = mappingJson,
            MappingDataType__c = dataTypeJson,
            TargetObject__c = 'Case'
        );
        insert cus2;

        FEC_Actual_Nature_of_Case__c fec = new FEC_Actual_Nature_of_Case__c();
        fec.FEC_Business_Process__c = codeType.Id;
        insert fec;

        Case cse = new Case();
        cse.FEC_Customer_Name__c = 'tester';
        cse.FEC_ID_Search__c = 'S-0001';
        cse.FEC_Actual_Nature_of_Case__c = fec.Id;
        cse.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Customer_Case').getRecordTypeId();
        insert cse;

        FEC_integration_service_log__c log = new FEC_integration_service_log__c(
            FEC_Custom_Sync__c = cus.Id,
            FEC_Bix_Is_Success__c = false,
            FEC_Quantity_Call__c = 1,
            Records__c = JSON.serialize(new List<String>{ cse.Id })
        );
        insert log;
    }

    // ─── FEC_ScheduledSyncDataToBix ───────────────────────────────────────────

    @isTest
    static void testCompleteScheduleFlow() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMock());
        Integer nextYear = Date.today().year() + 1;
        String cronExp = '0 0 0 15 3 ? ' + nextYear;

        Test.startTest();
        System.schedule('Test Job', cronExp, new FEC_ScheduledSyncDataToBix());
        Test.stopTest();
    }

    // ─── FEC_QueueRunBatchSync ────────────────────────────────────────────────

    @isTest
    static void testQueueableAndBatch() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMock());

        List<CustomSync__c> cusList = [
            SELECT Id, TableName__c, CaseBusinessCode__c, RequestBodyMapping__c, MappingDataType__c,
                   TargetObject__c, ProcessingQuantity__c, EndAt__c
            FROM CustomSync__c
        ];

        Test.startTest();
        FEC_QueueRunBatchSync queueJob = new FEC_QueueRunBatchSync(cusList);
        System.enqueueJob(queueJob);
        Test.stopTest();
    }

    @isTest
    static void testQueueableEmptyList() {
        Test.startTest();
        FEC_QueueRunBatchSync queueJob = new FEC_QueueRunBatchSync(new List<CustomSync__c>());
        System.enqueueJob(queueJob);
        Test.stopTest();
    }

    // ─── FEC_BatchReCallCustomSync ────────────────────────────────────────────

    @isTest
    static void testRecallBatch() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMock());

        Map<Id, CustomSync__c> mCus = new Map<Id, CustomSync__c>([
            SELECT Id, CaseBusinessCode__c, TableName__c, TargetObject__c, RequestBodyMapping__c,
                   MappingDataType__c
            FROM CustomSync__c
        ]);

        Test.startTest();
        FEC_BatchReCallCustomSync recallBatch = new FEC_BatchReCallCustomSync(mCus);
        Database.executeBatch(recallBatch, 1);
        Test.stopTest();
    }

    @isTest
    static void testRecallBatchFailResponse() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMockFail());

        Map<Id, CustomSync__c> mCus = new Map<Id, CustomSync__c>([
            SELECT Id, CaseBusinessCode__c, TableName__c, TargetObject__c, RequestBodyMapping__c,
                   MappingDataType__c
            FROM CustomSync__c
        ]);

        Test.startTest();
        FEC_BatchReCallCustomSync recallBatch = new FEC_BatchReCallCustomSync(mCus);
        Database.executeBatch(recallBatch, 1);
        Test.stopTest();
    }

    @isTest
    static void testRecallBatchPartialFail() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMockPartialFail());

        Map<Id, CustomSync__c> mCus = new Map<Id, CustomSync__c>([
            SELECT Id, CaseBusinessCode__c, TableName__c, TargetObject__c, RequestBodyMapping__c,
                   MappingDataType__c
            FROM CustomSync__c
        ]);

        Test.startTest();
        FEC_BatchReCallCustomSync recallBatch = new FEC_BatchReCallCustomSync(mCus);
        Database.executeBatch(recallBatch, 1);
        Test.stopTest();
    }

    // ─── FEC_BatchCustomSync ──────────────────────────────────────────────────

    @isTest
    static void testBatchCustomSyncSuccess() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMock());

        CustomSync__c cus = [
            SELECT Id, Name, TableName__c, CaseBusinessCode__c, ProcessingQuantity__c,
                   EndAt__c, TargetObject__c, RequestBodyMapping__c, MappingDataType__c,
                   SyncTo__c, Active__c,
                   SyncSuccessFully__c, SyncFailed__c, TotalRecordSync__c, StartAt__c
            FROM CustomSync__c
            LIMIT 1
        ];

        Test.startTest();
        FEC_BatchCustomSync batch = new FEC_BatchCustomSync(cus, true);
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }

    @isTest
    static void testBatchCustomSyncWithEndAt() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMock());

        CustomSync__c cus = [
            SELECT Id, Name, TableName__c, CaseBusinessCode__c, ProcessingQuantity__c,
                   EndAt__c, TargetObject__c, RequestBodyMapping__c, MappingDataType__c,
                   SyncTo__c, Active__c,
                   SyncSuccessFully__c, SyncFailed__c, TotalRecordSync__c, StartAt__c
            FROM CustomSync__c
            LIMIT 1
        ];
        cus.EndAt__c = DateTime.now().addHours(-2);
        update cus;

        cus = [
            SELECT Id, Name, TableName__c, CaseBusinessCode__c, ProcessingQuantity__c,
                   EndAt__c, TargetObject__c, RequestBodyMapping__c, MappingDataType__c,
                   SyncTo__c, Active__c,
                   SyncSuccessFully__c, SyncFailed__c, TotalRecordSync__c, StartAt__c
            FROM CustomSync__c
            WHERE Id = :cus.Id
        ];

        Test.startTest();
        FEC_BatchCustomSync batch = new FEC_BatchCustomSync(cus, false);
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }

    @isTest
    static void testBatchCustomSyncCalloutFail() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMockFail());

        CustomSync__c cus = [
            SELECT Id, Name, TableName__c, CaseBusinessCode__c, ProcessingQuantity__c,
                   EndAt__c, TargetObject__c, RequestBodyMapping__c, MappingDataType__c,
                   SyncTo__c, Active__c,
                   SyncSuccessFully__c, SyncFailed__c, TotalRecordSync__c, StartAt__c
            FROM CustomSync__c
            LIMIT 1
        ];

        Test.startTest();
        FEC_BatchCustomSync batch = new FEC_BatchCustomSync(cus, true);
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }

    @isTest
    static void testBatchCustomSyncPartialFail() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMockPartialFail());

        CustomSync__c cus = [
            SELECT Id, Name, TableName__c, CaseBusinessCode__c, ProcessingQuantity__c,
                   EndAt__c, TargetObject__c, RequestBodyMapping__c, MappingDataType__c,
                   SyncTo__c, Active__c,
                   SyncSuccessFully__c, SyncFailed__c, TotalRecordSync__c, StartAt__c
            FROM CustomSync__c
            LIMIT 1
        ];

        Test.startTest();
        FEC_BatchCustomSync batch = new FEC_BatchCustomSync(cus, true);
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }

    @isTest
    static void testGetFields() {
        CustomSync__c cus = new CustomSync__c(
            RequestBodyMapping__c = '{"CaseID":"Id","CaseName":"CaseNumber","PXURGENCYWORK":1}',
            TargetObject__c = 'Case'
        );
        String query = FEC_BatchCustomSync.getFields(cus);
        System.assert(query.contains('Id'));
        System.assert(query.contains('CaseNumber'));
    }

    @isTest
    static void testExtractFieldsFromMapping() {
        String mappingJson = '{"CaseID":"Id","CaseName":"CaseNumber","StaticVal":1,"BoolVal":true}';
        String fields = FEC_BatchCustomSync.extractFieldsFromMapping(mappingJson);
        System.assert(fields.contains('Id'));
        System.assert(fields.contains('CaseNumber'));
        // Static values (Integer, Boolean) should NOT appear as fields
        System.assert(!fields.contains('1'));
        System.assert(!fields.contains('true'));
    }

    // ─── FEC_CustomSyncCallout ────────────────────────────────────────────────

    @isTest
    static void testCalloutSuccess() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMock());

        CustomSync__c cus = [
            SELECT Id, TableName__c, TargetObject__c, RequestBodyMapping__c,
                   MappingDataType__c
            FROM CustomSync__c LIMIT 1
        ];
        FEC_integration_service_log__c log = new FEC_integration_service_log__c();
        List<Case> scope = [SELECT Id, CaseNumber, FEC_ID_Search__c FROM Case];

        Test.startTest();
        List<FEC_integration_service_log__c> results = FEC_CustomSyncCallout.sendRequest(cus, log, scope);
        Test.stopTest();

        System.assert(!results.isEmpty());
    }

    @isTest
    static void testCalloutFail() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMockFail());

        CustomSync__c cus = [
            SELECT Id, TableName__c, TargetObject__c, RequestBodyMapping__c,
                   MappingDataType__c
            FROM CustomSync__c LIMIT 1
        ];
        FEC_integration_service_log__c log = new FEC_integration_service_log__c();
        List<Case> scope = [SELECT Id, CaseNumber, FEC_ID_Search__c FROM Case];

        Test.startTest();
        List<FEC_integration_service_log__c> results = FEC_CustomSyncCallout.sendRequest(cus, log, scope);
        Test.stopTest();

        System.assertEquals(false, results[0].FEC_Bix_Is_Success__c);
    }

    @isTest
    static void testCalloutPartialFail() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMockPartialFail());

        CustomSync__c cus = [
            SELECT Id, TableName__c, TargetObject__c, RequestBodyMapping__c,
                   MappingDataType__c
            FROM CustomSync__c LIMIT 1
        ];
        FEC_integration_service_log__c log = new FEC_integration_service_log__c();
        log.FEC_Custom_Sync__c = cus.Id;
        List<Case> scope = [SELECT Id, CaseNumber, FEC_ID_Search__c FROM Case];

        Test.startTest();
        List<FEC_integration_service_log__c> results = FEC_CustomSyncCallout.sendRequest(cus, log, scope);
        Test.stopTest();

        // First call path: log.Id == null => success log + fail log
        System.assertEquals(2, results.size());
        System.assertEquals(true, results[0].FEC_Bix_Is_Success__c);
        System.assertEquals(false, results[1].FEC_Bix_Is_Success__c);
    }

    @isTest
    static void testCalloutPartialFailRecallPath() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMockPartialFail());

        CustomSync__c cus = [
            SELECT Id, TableName__c, TargetObject__c, RequestBodyMapping__c,
                   MappingDataType__c
            FROM CustomSync__c LIMIT 1
        ];

        // Use existing log (has Id) to trigger the Recall path
        FEC_integration_service_log__c existingLog = [
            SELECT Id, FEC_Custom_Sync__c, FEC_Quantity_Call__c, Records__c
            FROM FEC_integration_service_log__c LIMIT 1
        ];

        List<Case> scope = [SELECT Id, CaseNumber, FEC_ID_Search__c FROM Case];

        Test.startTest();
        List<FEC_integration_service_log__c> results = FEC_CustomSyncCallout.sendRequest(cus, existingLog, scope);
        Test.stopTest();

        // Recall path: log.Id != null => original log kept as fail + new success log
        System.assertEquals(2, results.size());
        System.assertEquals(false, results[0].FEC_Bix_Is_Success__c);
        System.assertEquals(true, results[1].FEC_Bix_Is_Success__c);
    }

    @isTest
    static void testCalloutEmptyScope() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMock());

        CustomSync__c cus = [
            SELECT Id, TableName__c, TargetObject__c, RequestBodyMapping__c,
                   MappingDataType__c
            FROM CustomSync__c LIMIT 1
        ];
        FEC_integration_service_log__c log = new FEC_integration_service_log__c();

        Test.startTest();
        List<FEC_integration_service_log__c> results = FEC_CustomSyncCallout.sendRequest(cus, log, new List<Case>());
        Test.stopTest();

        System.assert(!results.isEmpty());
    }

    // ─── FEC_QueueReportCustomSyncBix ─────────────────────────────────────────

    @isTest
    static void testQueueReportCustomSyncBix() {
        // Update CustomSync records with sync stats so the report has data
        List<CustomSync__c> cusList = [SELECT Id FROM CustomSync__c];
        for (CustomSync__c c : cusList) {
            c.SyncSuccessFully__c = 10;
            c.SyncFailed__c = 2;
            c.TotalRecordSync__c = 12;
            c.StartAt__c = DateTime.now().addHours(-1);
            c.EndAt__c = DateTime.now();
        }
        update cusList;

        Test.startTest();
        System.enqueueJob(new FEC_QueueReportCustomSyncBix());
        Test.stopTest();
    }

    @isTest
    static void testQueueReportAllSuccess() {
        List<CustomSync__c> cusList = [SELECT Id FROM CustomSync__c];
        for (CustomSync__c c : cusList) {
            c.SyncSuccessFully__c = 5;
            c.SyncFailed__c = 0;
            c.TotalRecordSync__c = 5;
            c.StartAt__c = DateTime.now().addHours(-1);
            c.EndAt__c = DateTime.now();
        }
        update cusList;

        Test.startTest();
        System.enqueueJob(new FEC_QueueReportCustomSyncBix());
        Test.stopTest();
    }

    @isTest
    static void testQueueReportNoRecords() {
        // Deactivate all CustomSync records so report query returns empty
        List<CustomSync__c> cusList = [SELECT Id FROM CustomSync__c];
        for (CustomSync__c c : cusList) {
            c.Active__c = false;
        }
        update cusList;

        Test.startTest();
        System.enqueueJob(new FEC_QueueReportCustomSyncBix());
        Test.stopTest();
    }
}
