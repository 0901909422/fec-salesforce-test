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
    
    // @isTest
    // static void testFetchAndRedirect_Success() {
    //     // Create test Case
    //     Case testCase = new Case(
    //         Subject = 'Test Case',
    //         FEC_Interaction_External_ID__c = 'TEST-EXT-001',
    //         ArchiveExternalId__c = 'CASE-001'
    //     );
    //     insert testCase;
        
    //     // Mock external object
    //     AthenaCases__x mockExternal = new AthenaCases__x(
    //         ExternalId = 'TEST-EXT-001'
    //     );
    //     ArchiveCaseController.mockExternalRecords = new List<AthenaCases__x>{ mockExternal };
        
    //     // Setup page parameters
    //     PageReference pageRef = Page.FetchInteraction;
    //     pageRef.getParameters().put('id', testCase.Id);
    //     Test.setCurrentPage(pageRef);
        
    //     Test.startTest();
    //     FetchInteractionController controller = new FetchInteractionController();
    //     PageReference result = controller.fetchAndRedirect();
    //     Test.stopTest();
        
    //     // Verify redirect occurred (result will be null in test context due to callout)
    //     System.assertNotEquals(null, controller.caseId);
    // }
    
    // @isTest
    // static void testFetchAndRedirect_NoCaseId() {
    //     PageReference pageRef = Page.FetchInteraction;
    //     Test.setCurrentPage(pageRef);
        
    //     Test.startTest();
    //     FetchInteractionController controller = new FetchInteractionController();
    //     PageReference result = controller.fetchAndRedirect();
    //     Test.stopTest();
        
    //     System.assertEquals(true, controller.hasError);
    //     System.assert(controller.errorMessage.contains('Case ID'));
    // }
    
    // @isTest
    // static void testFetchAndRedirect_NoExternalId() {
    //     Case testCase = new Case(
    //         Subject = 'Test Case'
    //     );
    //     insert testCase;
        
    //     PageReference pageRef = Page.FetchInteraction;
    //     pageRef.getParameters().put('id', testCase.Id);
    //     Test.setCurrentPage(pageRef);
        
    //     Test.startTest();
    //     FetchInteractionController controller = new FetchInteractionController();
    //     PageReference result = controller.fetchAndRedirect();
    //     Test.stopTest();
        
    //     System.assertEquals(true, controller.hasError);
    //     System.assert(controller.errorMessage.contains('External ID'));
    // }

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
        AthenaCases__x mockExt = new AthenaCases__x(ExternalId = 'EXT-999');
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