/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Test class of DeleteArchiveCaseBatch
Test Class:    
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/01     Thanh Van          Init
------------------------------------------------------------*/
@IsTest
global with sharing class DeleteArchiveCaseBatch_Test {

    @isTest
    public static void DeleteArchiveCaseBatchTest() {
        Case localCase = new Case(ArchiveExternalId__c = 'EXAMPLE-999');
        insert localCase;
        
        Test.startTest();
            DeleteArchiveCaseBatch delArchiveCaseBatchTest = new DeleteArchiveCaseBatch();
            Database.executeBatch(delArchiveCaseBatchTest);
            String sch = '0 0 23 * * ?';
            system.schedule('Test Del Cust', sch, delArchiveCaseBatchTest);
        Test.stopTest();
    }

    @isTest
    public static void DeleteArchiveCaseBatchWithIdTest() {
        Case caseIns = new Case(ArchiveExternalId__c = 'EXAMPLE-999');
        insert caseIns;
        
        Test.startTest();
            DeleteArchiveCaseBatch delArchiveCaseBatchTest = new DeleteArchiveCaseBatch(new List<String>{caseIns.Id});
            Database.executeBatch(delArchiveCaseBatchTest);
        Test.stopTest();
    }
}