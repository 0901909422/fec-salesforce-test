/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Test class of ArchiveCaseController
Test Class:    
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/01     Thanh Van          Init
------------------------------------------------------------*/
@IsTest
global with sharing class ArchiveCaseController_Test {

    @isTest
    static void testGetOrCreateCaseWithExistedCase() {
        AthenaCases__x fakeRecord = new AthenaCases__x(ExternalId = 'EXAMPLE-999');
        ArchiveCaseController.mockExternalRecords = new List<AthenaCases__x>{ fakeRecord };
        Case localCase = new Case(ArchiveExternalId__c = 'EXAMPLE-999');
        insert localCase;
        
        Test.startTest();
            ArchiveCaseController.getOrCreateCase('test');
        Test.stopTest();
    }

    public class CaseDetailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String body = '{' +
                '"Subject": "Test Archive Case",' +
                '"Description": "This is a description from external system",' +
                '"Status": "New",' +
                '"FEC_Adjusted_Amount__c": "0",' +
                '"RecordType": { "Name": "Customer Case" }' +
            '}';
            
            res.setBody(body);
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testGetOrCreateCase_CreateNewCaseSuccess() {
        Test.setMock(HttpCalloutMock.class, new CaseDetailMock());
        AthenaCases__x fakeExternalRecord = new AthenaCases__x(ExternalId = 'EXAMPLE-999');
        ArchiveCaseController.mockExternalRecords = new List<AthenaCases__x>{ fakeExternalRecord };
        
        Test.startTest();
            ArchiveCaseController.getOrCreateCase('x00123456789ABC');
        Test.stopTest();
    }
}