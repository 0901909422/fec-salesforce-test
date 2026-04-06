/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Test class Sync Data 
Test Class:     
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/03/31     Duan Nguyen          Init
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
            SyncTo__c = 'Bix'
        );
        insert cus;
        
        CustomSync__c cus2 = new CustomSync__c(
            Name = 'Test Sync',
            TableName__c = 'Table Case', 
            WhatSync__c = 'Phone Update',
            ProcessingQuantity__c = 1,
            Active__c = true,
            SyncTo__c = 'Bix'
        );
        insert cus2;
        
        FEC_Business_Process__c codeType = new FEC_Business_Process__c();
        codeType.FEC_Code__c = 'Phone Update';
        insert codeType;
        FEC_Actual_Nature_of_Case__c fec = new FEC_Actual_Nature_of_Case__c();
        fec.FEC_Business_Process__c = codeType.id;
        insert fec;
        
        Case cse = new Case();
        cse.FEC_Customer_Name__c = 'tester'; 
        cse.FEC_Actual_Nature_of_Case__c = fec.id;
        cse.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Customer_Case').getRecordTypeId();
        insert cse;
 
        FEC_API_Log__c log = new FEC_API_Log__c(
            FEC_Custom_Sync__c = cus.Id,
            FEC_Is_Success__c = false,
            FEC_Quantity_Call__c = 1,
            FEC_Request_String__c = JSON.serialize(new List<String>{cse.Id})
        );
        insert log;
    }
 @isTest
    static void testCompleteScheduleFlow() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMock()); 
        Integer nextYear = Date.today().year() + 1;
        String cronExp = '0 0 0 15 3 ? ' + nextYear;
        
        Test.startTest();
        System.schedule('Test Job', cronExp, new FEC_ScheduledSyncDataToBix());
        Test.stopTest();    
    } 
    @isTest
    static void testQueueableAndBatch() { 
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMock());
        
        List<CustomSync__c> cusList = [SELECT Id, TableName__c,  WhatSync__c, 
                                            ProcessingQuantity__c, EndAt__c FROM CustomSync__c];

        Test.startTest();
        FEC_QueueRunBatchSync queueJob = new FEC_QueueRunBatchSync(cusList);
        System.enqueueJob(queueJob);
        Test.stopTest(); 
    }

    @isTest
    static void testRecallBatch() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMock());
        
        Map<Id, CustomSync__c> mCus = new Map<Id, CustomSync__c>([SELECT Id, WhatSync__c, TableName__c FROM CustomSync__c]);
         
        Map<String, CustomSyncField__mdt> mMetaData = new Map<String, CustomSyncField__mdt>();
        for(CustomSyncField__mdt mdt : [SELECT DeveloperName, Fields__c,ObjecTarget__c FROM CustomSyncField__mdt]) {
            mMetaData.put(mdt.DeveloperName, mdt);
        }

        Test.startTest();
        if(!mMetaData.isEmpty()) {
            FEC_BatchReCallCustomSync recallBatch = new FEC_BatchReCallCustomSync(mCus, mMetaData);
            Database.executeBatch(recallBatch);
        }
        Test.stopTest();
 
    }

    @isTest
    static void testUtilityDirectly() {
        Test.setMock(HttpCalloutMock.class, new FEC_CustomSyncMock());
        
        CustomSync__c cus = [SELECT Id, TableName__c FROM CustomSync__c LIMIT 1];
        FEC_API_Log__c log = new FEC_API_Log__c();
        List<Account> scope = [SELECT Id, Name FROM Account];

        Test.startTest();
        FEC_API_Log__c result = FEC_CustomSyncCallout.sendRequest(cus, log, scope);
        Test.stopTest(); 
    }
}