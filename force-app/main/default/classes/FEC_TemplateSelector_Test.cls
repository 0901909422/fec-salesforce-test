/**
 * Test Class: FEC_TemplateSelector_Test
 * Covers all Selector methods for FEC_Template__c.
 * @created  : 2026/03/12
 */
@IsTest
private class FEC_TemplateSelector_Test {

    @TestSetup
    static void setupData() {
        // Create folders
        FEC_Folder__c folder1 = new FEC_Folder__c(FEC_Folder_Label__c = 'Marketing');
        FEC_Folder__c folder2 = new FEC_Folder__c(FEC_Folder_Label__c = 'Transactional');
        insert new List<FEC_Folder__c>{ folder1, folder2 };

        // Create templates
        List<FEC_Template__c> templates = new List<FEC_Template__c>();
        templates.add(new FEC_Template__c(
            Name = 'Welcome Email',
            FEC_Description__c = 'Welcome new customers',
            FEC_Folder__c = folder1.Id,
            FEC_Active__c = true,
            FEC_Subject_Line__c = 'Welcome!'
        ));
        templates.add(new FEC_Template__c(
            Name = 'Password Reset',
            FEC_Description__c = 'Reset password link',
            FEC_Folder__c = folder2.Id,
            FEC_Active__c = true
        ));
        templates.add(new FEC_Template__c(
            Name = 'Inactive Template',
            FEC_Description__c = 'Old archived template',
            FEC_Folder__c = folder1.Id,
            FEC_Active__c = false
        ));
        insert templates;
    }

    @IsTest
    static void testSelectById() {
        FEC_Template__c tmpl = [SELECT Id FROM FEC_Template__c WHERE Name = 'Welcome Email' LIMIT 1];

        Test.startTest();
        FEC_Template__c result = FEC_TemplateSelector.selectById(tmpl.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Should return the template record');
        Assert.areEqual('Welcome Email', result.Name);
    }

    @IsTest
    static void testSelectByIdNotFound() {
        // Use a fabricated Id that doesn't exist
        Id fakeId = FEC_Template__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.startTest();
        FEC_Template__c result = FEC_TemplateSelector.selectById(fakeId);
        Test.stopTest();

        Assert.isNull(result, 'Should return null for non-existent record');
    }

    @IsTest
    static void testSelectByIds() {
        List<FEC_Template__c> all = [SELECT Id FROM FEC_Template__c];
        Set<Id> ids = new Set<Id>();
        for (FEC_Template__c t : all) { ids.add(t.Id); }

        Test.startTest();
        List<FEC_Template__c> results = FEC_TemplateSelector.selectByIds(ids);
        Test.stopTest();

        Assert.areEqual(3, results.size(), 'Should return all 3 templates');
    }

    @IsTest
    static void testSelectByFilterNoFilter() {
        Test.startTest();
        List<FEC_Template__c> results = FEC_TemplateSelector.selectByFilter(null, null, false);
        Test.stopTest();

        Assert.areEqual(3, results.size(), 'Should return all templates when no filters applied');
    }

    @IsTest
    static void testSelectByFilterFolderId() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Marketing' LIMIT 1];

        Test.startTest();
        List<FEC_Template__c> results = FEC_TemplateSelector.selectByFilter(folder.Id, null, false);
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Marketing folder should have 2 templates');
    }

    @IsTest
    static void testSelectByFilterSearchText() {
        Test.startTest();
        List<FEC_Template__c> results = FEC_TemplateSelector.selectByFilter(null, 'Welcome', false);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Search "Welcome" should return 1 template');
        Assert.areEqual('Welcome Email', results[0].Name);
    }

    @IsTest
    static void testSelectByFilterActiveOnly() {
        Test.startTest();
        List<FEC_Template__c> results = FEC_TemplateSelector.selectByFilter(null, null, true);
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Active-only filter should return 2 active templates');
    }

    @IsTest
    static void testSelectByFolderId() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Transactional' LIMIT 1];

        Test.startTest();
        List<FEC_Template__c> results = FEC_TemplateSelector.selectByFolderId(folder.Id);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Transactional folder should have 1 template');
    }
}