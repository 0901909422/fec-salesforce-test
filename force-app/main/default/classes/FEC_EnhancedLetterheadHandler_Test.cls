@isTest
private class FEC_EnhancedLetterheadHandler_Test {

    @testSetup
    static void setupData() {
        // Create a Parent letterhead
        FEC_Enhanced_Letterhead__c letter = new FEC_Enhanced_Letterhead__c(Name = 'Test', FEC_Header__c = 'Header', FEC_Footer__c = 'Footer');
        insert letter;

        // Create a Parent Folder
        FEC_Folder__c parent = new FEC_Folder__c(FEC_Folder_Unique_Name__c = 'Parent Folder', Name = 'Parent Folder');
        insert parent;
    }

    /**
     * Tests that a letterhead cannot be deleted if it contains an active template.
     */
    @isTest
    static void testDeleteFolderWithActiveTemplateFail() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Unique_Name__c = 'Parent Folder' LIMIT 1];
        FEC_Enhanced_Letterhead__c letter = [SELECT Id FROM FEC_Enhanced_Letterhead__c WHERE Name = 'Test' LIMIT 1];
        
        // Create active template
        FEC_Template__c activeTemplate = new FEC_Template__c(
            FEC_Folder__c = folder.Id, 
            FEC_Enhanced_Letterhead__c = letter.id,
            FEC_Active__c = true
        );
        insert activeTemplate;

        Test.startTest();
        Database.DeleteResult result = Database.delete(letter, false);
        Test.stopTest();

        System.assert(!result.isSuccess(), 'Deletion should have failed');
    }
}