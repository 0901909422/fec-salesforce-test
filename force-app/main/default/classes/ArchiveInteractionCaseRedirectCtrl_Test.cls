/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Test class for FetchInteractionController
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/16     Thanh Van          Init
------------------------------------------------------------*/
@isTest
private class ArchiveInteractionCaseRedirectCtrl_Test {
    
    @isTest
    static void testFetchAndRedirect_ExistingInteraction() {
        // 1. Setup Data: Create a Case that already has a matching Interaction Case in Salesforce
        Case interactionCase = new Case(Subject = 'Interaction Case', ArchiveExternalId__c = 'EXT-001');
        insert interactionCase;

        Case currentCase = new Case(Subject = 'Current Case', ArchiveInteractionId__c = 'EXT-001');
        insert currentCase;

        Test.startTest();
            // Set VF Page Parameter
            ApexPages.currentPage().getParameters().put('id', currentCase.Id);
            
            ArchiveInteractionCaseController ctrl = new ArchiveInteractionCaseController();
            PageReference result = ctrl.fetchAndRedirect();
        Test.stopTest();
    }

    @isTest
    static void testFetchAndRedirect_FromArchive() {
        // 1. Setup Data: Current case exists, but matching interaction is ONLY in the external object
        Case currentCase = new Case(Subject = 'Current Case', ArchiveInteractionId__c = 'EXT-999');
        insert currentCase;

        // 2. Mock the External Object record (AthenaCases__x)
        // Note: We use the @TestVisible variable from your controller
        AthenaCases__x mockExt = new AthenaCases__x(ExternalId = 'EXT-999', 
                                                    case_id__c = 'EXT-999', 
                                                    s3_path__c = 'test', 
                                                    migration_source__c = 'test');
        ArchiveInteractionCaseController.mockExternalRecords = new List<AthenaCases__x>{ mockExt };

        Test.startTest();
            ApexPages.currentPage().getParameters().put('id', currentCase.Id);
            ArchiveInteractionCaseController ctrl = new ArchiveInteractionCaseController();
            PageReference result = ctrl.fetchAndRedirect();
        Test.stopTest();
    }

    @isTest
    static void testFetchAndRedirect_Errors() {
        Test.startTest();
        
            // Scenario A: Missing ID parameter
            ArchiveInteractionCaseController ctrlNoId = new ArchiveInteractionCaseController();
            ctrlNoId.fetchAndRedirect();

            // Scenario B: Record not found in SF or Archive
            Case currentCase = new Case(Subject = 'Lost Case', ArchiveInteractionId__c = 'NOT_FOUND');
            insert currentCase;
            
            ArchiveInteractionCaseController.mockExternalRecords = new List<AthenaCases__x>(); // Empty archive
            
            ApexPages.currentPage().getParameters().put('id', currentCase.Id);
            ArchiveInteractionCaseController ctrlMissing = new ArchiveInteractionCaseController();
            ctrlMissing.fetchAndRedirect();
        
        Test.stopTest();
    }

    @isTest
    static void testFetchAndRedirect_NotFoundCase() {
        Test.startTest();
            ApexPages.currentPage().getParameters().put('id', 'test');
            ArchiveInteractionCaseController ctrl = new ArchiveInteractionCaseController();
            PageReference result = ctrl.fetchAndRedirect();
        Test.stopTest();
    }

    @isTest
    static void testFetchAndRedirect_Exception() {
        ArchiveInteractionCaseController.isTestWithError = true;

        Test.startTest();
            ApexPages.currentPage().getParameters().put('id', 'test');
            ArchiveInteractionCaseController ctrl = new ArchiveInteractionCaseController();
            PageReference result = ctrl.fetchAndRedirect();
        Test.stopTest();
    }
}