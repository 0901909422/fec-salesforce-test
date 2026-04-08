/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Test class Sync Data 
Test Class:     
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/03/31     Duan Nguyen          Init
2026/04/08     Duan Nguyen          Rewrite - increase coverage FEC_BatchCustomSync
------------------------------------------------------------*/
@isTest
private class FEC_CustomSyncAllInOneTest {

    private class FEC_CustomSyncMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status": "success", "message": "Data received"}');
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

    @testSetup
    static void setupData() {
        CustomSyncSetting__c setting = new CustomSyncSetting__c(
            Endpoint__c = 'https://api.test.com',
            ApiKey__c = 'test-key-123',
            LimitQuanitySync__c = 5
        );
        insert setting;

        CustomSync__c cus = new CustomSync__c(
            Name = 'Test Sync',
            TableName__c = 'Table Case',
            WhatSync__c = 'Phone Update',
            ProcessingQuantity__c = 1,
            Active__c = true,
            SyncTo__c = 'Bix',
            Fields__c = 'Id, CaseNumber',
            TargetObject__c = 'Case'
        );
        insert cus;

        CustomSync__c cus2 = new CustomSync__c(
            Name = 'Test Sync 2',
            TableName__c = 'Table Case',
            WhatSync__c = 'Phone Update',
            ProcessingQuantity__c = 1,
            Active__c = true,
            SyncTo__c = 'Bix',
            Fields__c = 'Id, CaseNumber',
            TargetObject__c = 'Case'
        );
        insert cus2;

        FEC_Business_Process__c codeType = new FEC_Business_Process__c();
        codeType.FEC_Code__c = 'Phone Update';
        insert codeType;

        FEC_Actual_Nature_of_Case__c fec = new FEC_Actual_Nature_of_Case__c();
        fec.FEC_Business_Process__c = codeType.Id;
        insert fec;

        Case cse = new Case();
        cse.FEC_Customer_Name__c = 'tester';
        cse.FEC_Actual_Nature_of_Case__c = fec.Id;
        cse.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Customer_Case').getRecordTypeId();
        insert cse;

        FEC_API_Log__c log = new FEC_API_Log__c(
            FEC_Custom_Sync__c = cus.Id,
            FEC_Is_Success__c = false,
            FEC_Quantity_Call__c = 1,
            FEC_Request_String__c = JSON.serialize(new List<String>{ cse.Id })
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
            SELECT Id, TableName__c, WhatSync__c, Fields__c, TargetObject__c,
                   ProcessingQuantity__c, EndAt__c
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
            SELECT Id, WhatSync__c, TableName__c, TargetObject__c, Fields__c
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
            SELECT Id, WhatSync__c, TableName__c, TargetObject__c, Fields__c
            FROM CustomSync__c
        ]);

        Test.startTest();
        FEC_BatchReCallCustomSync recallBatch = new FEC_BatchReCallCustomSync(mCus);
        Database.executeBatch(recallBatch, 1);
        Test.stopTest();
    }

    // ─── FEC_BatchCustomSync ──────────────────────────────────────────────────

    // Cover: start() với EndAt__c = null → startTime = toDate.addHours(-1)
    // Cover: execute() với records có data + callout success → countSuccess++
    // Cover: finish() với EndAt__c = null → cus.StartAt__c = toDate.addHours(-1)
    @isTest
    static void testBatchCustomSyncSuccess() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMock());

        CustomSync__c cus = [
            SELECT Id, Name, TableName__c, WhatSync__c, ProcessingQuantity__c,
                   EndAt__c, TargetObject__c, Fields__c, SyncTo__c, Active__c,
                   SyncSuccessFully__c, SyncFailed__c, TotalRecordSync__c, StartAt__c
            FROM CustomSync__c
            LIMIT 1
        ];
        // EndAt__c = null → nhánh startTime = toDate.addHours(-1)

        Test.startTest();
        FEC_BatchCustomSync batch = new FEC_BatchCustomSync(cus);
        Database.executeBatch(batch, 200);
        Test.stopTest(); 
    }

    // Cover: start() với EndAt__c có giá trị → startTime = cus.EndAt__c
    // Cover: finish() với EndAt__c có giá trị → cus.StartAt__c = cus.EndAt__c
    @isTest
    static void testBatchCustomSyncWithEndAt() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMock());

        CustomSync__c cus = [
            SELECT Id, Name, TableName__c, WhatSync__c, ProcessingQuantity__c,
                   EndAt__c, TargetObject__c, Fields__c, SyncTo__c, Active__c,
                   SyncSuccessFully__c, SyncFailed__c, TotalRecordSync__c, StartAt__c
            FROM CustomSync__c
            LIMIT 1
        ];
        // Set EndAt__c để cover nhánh startTime = cus.EndAt__c
        cus.EndAt__c = DateTime.now().addHours(-2);
        update cus;

        cus = [
            SELECT Id, Name, TableName__c, WhatSync__c, ProcessingQuantity__c,
                   EndAt__c, TargetObject__c, Fields__c, SyncTo__c, Active__c,
                   SyncSuccessFully__c, SyncFailed__c, TotalRecordSync__c, StartAt__c
            FROM CustomSync__c
            WHERE Id = :cus.Id
        ];

        Test.startTest();
        FEC_BatchCustomSync batch = new FEC_BatchCustomSync(cus);
        Database.executeBatch(batch, 200);
        Test.stopTest(); 
    }

    // Cover: execute() callout fail → countFail++
    @isTest
    static void testBatchCustomSyncCalloutFail() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMockFail());

        CustomSync__c cus = [
            SELECT Id, Name, TableName__c, WhatSync__c, ProcessingQuantity__c,
                   EndAt__c, TargetObject__c, Fields__c, SyncTo__c, Active__c,
                   SyncSuccessFully__c, SyncFailed__c, TotalRecordSync__c, StartAt__c
            FROM CustomSync__c
            LIMIT 1
        ];

        Test.startTest();
        FEC_BatchCustomSync batch = new FEC_BatchCustomSync(cus);
        Database.executeBatch(batch, 200);
        Test.stopTest(); 
    }

    // Cover: getFields() static method trực tiếp
    @isTest
    static void testGetFields() {
        CustomSync__c cus = new CustomSync__c(
            Fields__c = 'Id, CaseNumber',
            TargetObject__c = 'Case'
        );
        String query = FEC_BatchCustomSync.getFields(cus); 
    }

    // ─── FEC_CustomSyncCallout ────────────────────────────────────────────────

    @isTest
    static void testCalloutSuccess() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMock());

        CustomSync__c cus = [SELECT Id, TableName__c, TargetObject__c, Fields__c FROM CustomSync__c LIMIT 1];
        FEC_API_Log__c log = new FEC_API_Log__c();
        List<Case> scope = [SELECT Id, CaseNumber FROM Case];

        Test.startTest();
        FEC_API_Log__c result = FEC_CustomSyncCallout.sendRequest(cus, log, scope);
        Test.stopTest(); 
    }

    @isTest
    static void testCalloutFail() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMockFail());

        CustomSync__c cus = [SELECT Id, TableName__c, TargetObject__c, Fields__c FROM CustomSync__c LIMIT 1];
        FEC_API_Log__c log = new FEC_API_Log__c();
        List<Case> scope = [SELECT Id, CaseNumber FROM Case];

        Test.startTest();
        FEC_API_Log__c result = FEC_CustomSyncCallout.sendRequest(cus, log, scope);
        Test.stopTest(); 
    }
}
