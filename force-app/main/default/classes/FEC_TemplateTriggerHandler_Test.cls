/**
 * Test Class: FEC_TemplateTriggerHandler_Test
 * Covers:  ① Auto-generate FEC_API_Name__c
 *          ② Duplicate check – same folder → error
 *          ③ Duplicate check – different folder → OK
 *          ④ Update rename → re-generate API Name
 *          ⑤ Batch-internal duplicate check
 * @created  : 2026/03/12
 */
@IsTest
private class FEC_TemplateTriggerHandler_Test {

    /**
     * Setup: Create test folders
     */
    @TestSetup
    static void setupData() {
        List<FEC_Folder__c> folders = new List<FEC_Folder__c>();
        folders.add(new FEC_Folder__c(
            FEC_Folder_Label__c = 'Marketing',
            FEC_Folder_Unique_Name__c = 'Marketing'
        ));
        folders.add(new FEC_Folder__c(
            FEC_Folder_Label__c = 'Support',
            FEC_Folder_Unique_Name__c = 'Support'
        ));
        insert folders;
    }

    /**
     * Test: Auto-generate API Name from Template Name
     */
    @IsTest
    static void testAutoGenerateApiName() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Marketing' LIMIT 1];

        FEC_Template__c tmpl = new FEC_Template__c(
            FEC_Template_Name__c = 'Welcome Email Template',
            FEC_Folder__c = folder.Id
        );

        Test.startTest();
        insert tmpl;
        Test.stopTest();

        FEC_Template__c result = [
            SELECT FEC_API_Name__c
            FROM FEC_Template__c
            WHERE Id = :tmpl.Id
        ];
        Assert.areEqual('Welcome_Email_Template', result.FEC_API_Name__c,
            'API Name should be auto-generated from Template Name');
    }

    /**
     * Test: Special characters in Template Name → replaced with underscores
     */
    @IsTest
    static void testApiNameSpecialCharacters() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Marketing' LIMIT 1];

        FEC_Template__c tmpl = new FEC_Template__c(
            FEC_Template_Name__c = 'OTP & Verification (V2)',
            FEC_Folder__c = folder.Id
        );

        Test.startTest();
        insert tmpl;
        Test.stopTest();

        FEC_Template__c result = [
            SELECT FEC_API_Name__c
            FROM FEC_Template__c
            WHERE Id = :tmpl.Id
        ];
        Assert.areEqual('OTP_Verification_V2', result.FEC_API_Name__c,
            'Special characters should be replaced with underscores and collapsed');
    }

    /**
     * Test: Duplicate template name in same folder → should fail
     */
    @IsTest
    static void testDuplicateSameFolder() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Marketing' LIMIT 1];

        // Insert first template
        insert new FEC_Template__c(
            FEC_Template_Name__c = 'Promo Email',
            FEC_Folder__c = folder.Id
        );

        // Insert duplicate in same folder
        FEC_Template__c duplicate = new FEC_Template__c(
            FEC_Template_Name__c = 'Promo Email',
            FEC_Folder__c = folder.Id
        );

        Test.startTest();
        try {
            insert duplicate;
            Assert.fail('Expected DmlException for duplicate template in same folder');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('already exists in the same folder'),
                'Error message should mention duplicate in same folder. Actual: ' + e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * Test: Same template name in different folders → should succeed
     */
    @IsTest
    static void testDuplicateDifferentFolder() {
        FEC_Folder__c folder1 = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Marketing' LIMIT 1];
        FEC_Folder__c folder2 = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Support' LIMIT 1];

        insert new FEC_Template__c(
            FEC_Template_Name__c = 'Welcome Email',
            FEC_Folder__c = folder1.Id
        );

        FEC_Template__c tmpl2 = new FEC_Template__c(
            FEC_Template_Name__c = 'Welcome Email',
            FEC_Folder__c = folder2.Id
        );

        Test.startTest();
        insert tmpl2;
        Test.stopTest();

        // Both should exist
        Integer count = [
            SELECT COUNT()
            FROM FEC_Template__c
            WHERE FEC_API_Name__c = 'Welcome_Email'
        ];
        Assert.areEqual(2, count, 'Same name in different folders should be allowed');
    }

    /**
     * Test: Update template name → should re-generate API Name
     */
    @IsTest
    static void testUpdateRegeneratesApiName() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Marketing' LIMIT 1];

        FEC_Template__c tmpl = new FEC_Template__c(
            FEC_Template_Name__c = 'Old Name',
            FEC_Folder__c = folder.Id
        );
        insert tmpl;

        Test.startTest();
        tmpl.FEC_Template_Name__c = 'New Name Updated';
        update tmpl;
        Test.stopTest();

        FEC_Template__c result = [
            SELECT FEC_API_Name__c
            FROM FEC_Template__c
            WHERE Id = :tmpl.Id
        ];
        Assert.areEqual('New_Name_Updated', result.FEC_API_Name__c,
            'API Name should be re-generated after template name update');
    }

    /**
     * Test: Update template to conflict with existing → should fail
     */
    @IsTest
    static void testUpdateCausesDuplicate() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Marketing' LIMIT 1];

        insert new FEC_Template__c(
            FEC_Template_Name__c = 'Existing Template',
            FEC_Folder__c = folder.Id
        );

        FEC_Template__c tmpl2 = new FEC_Template__c(
            FEC_Template_Name__c = 'Another Template',
            FEC_Folder__c = folder.Id
        );
        insert tmpl2;

        Test.startTest();
        tmpl2.FEC_Template_Name__c = 'Existing Template';
        try {
            update tmpl2;
            Assert.fail('Expected DmlException when updating to duplicate name in same folder');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('already exists in the same folder'),
                'Error should mention duplicate. Actual: ' + e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * Test: Batch-internal duplicate – inserting 2 templates with same name in same folder in one batch
     */
    @IsTest
    static void testBatchInternalDuplicate() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Marketing' LIMIT 1];

        List<FEC_Template__c> batch = new List<FEC_Template__c>();
        batch.add(new FEC_Template__c(
            FEC_Template_Name__c = 'Batch Template',
            FEC_Folder__c = folder.Id
        ));
        batch.add(new FEC_Template__c(
            FEC_Template_Name__c = 'Batch Template',
            FEC_Folder__c = folder.Id
        ));

        Test.startTest();
        try {
            insert batch;
            Assert.fail('Expected DmlException for batch-internal duplicate');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('already exists'),
                'Error should mention duplicate. Actual: ' + e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * Test: Template with null folder (no folder assigned)
     */
    @IsTest
    static void testNullFolderDuplicate() {
        // Insert template without folder
        insert new FEC_Template__c(
            FEC_Template_Name__c = 'No Folder Template'
        );

        // Insert duplicate without folder
        FEC_Template__c duplicate = new FEC_Template__c(
            FEC_Template_Name__c = 'No Folder Template'
        );

        Test.startTest();
        try {
            insert duplicate;
            Assert.fail('Expected DmlException for duplicate template with null folder');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('already exists'),
                'Error should mention duplicate. Actual: ' + e.getMessage());
        }
        Test.stopTest();
    }
}