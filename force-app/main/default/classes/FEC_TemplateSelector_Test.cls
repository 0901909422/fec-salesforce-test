/**
 * Test Class: FEC_TemplateSelector_Test
 * Covers all Selector methods for FEC_Template__c.
 * @created  : 2026/03/12
 */
@IsTest
private class FEC_TemplateSelector_Test {

    private static User runAsAdmin() {
        return [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
    }

    @TestSetup
    static void setupData() {
        String sfx = String.valueOf(System.currentTimeMillis());
        // Create folders
        FEC_Folder__c folder1 = new FEC_Folder__c(
            FEC_Folder_Label__c = 'Marketing ' + sfx,
            FEC_Folder_Unique_Name__c = 'Marketing_' + sfx
        );
        FEC_Folder__c folder2 = new FEC_Folder__c(
            FEC_Folder_Label__c = 'Transactional ' + sfx,
            FEC_Folder_Unique_Name__c = 'Transactional_' + sfx
        );
        insert new List<FEC_Folder__c>{ folder1, folder2 };

        // Create templates
        List<FEC_Template__c> templates = new List<FEC_Template__c>();
        templates.add(new FEC_Template__c(
            Name = 'Welcome Email ' + sfx,
            FEC_Description__c = 'Welcome new customers',
            FEC_Folder__c = folder1.Id,
            FEC_Active__c = true,
            FEC_Subject_Line__c = 'Welcome!'
        ));
        templates.add(new FEC_Template__c(
            Name = 'Password Reset ' + sfx,
            FEC_Description__c = 'Reset password link',
            FEC_Folder__c = folder2.Id,
            FEC_Active__c = true
        ));
        templates.add(new FEC_Template__c(
            Name = 'Inactive Template ' + sfx,
            FEC_Description__c = 'Old archived template',
            FEC_Folder__c = folder1.Id,
            FEC_Active__c = false
        ));
        insert templates;
    }

    @IsTest
    static void testSelectById() {
        System.runAs(runAsAdmin()) {
        FEC_Template__c tmpl = [
            SELECT Id, Name FROM FEC_Template__c WHERE Name LIKE 'Welcome Email %' ORDER BY CreatedDate DESC LIMIT 1
        ];

        Test.startTest();
        FEC_Template__c result = FEC_TemplateSelector.selectById(tmpl.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Should return the template record');
        System.assert(result.Name.startsWith('Welcome Email'), 'Name phải là Welcome Email test record.');
        }
    }

    @IsTest
    static void testSelectByIdNotFound() {
        System.runAs(runAsAdmin()) {
        // Use a fabricated Id that doesn't exist
        Id fakeId = FEC_Template__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.startTest();
        FEC_Template__c result = FEC_TemplateSelector.selectById(fakeId);
        Test.stopTest();

        Assert.isNull(result, 'Should return null for non-existent record');
        }
    }

    @IsTest
    static void testSelectByIds() {
        System.runAs(runAsAdmin()) {
        List<FEC_Template__c> all = [SELECT Id FROM FEC_Template__c];
        Set<Id> ids = new Set<Id>();
        for (FEC_Template__c t : all) { ids.add(t.Id); }

        Test.startTest();
        List<FEC_Template__c> results = FEC_TemplateSelector.selectByIds(ids);
        Test.stopTest();

        Integer expected = [SELECT COUNT() FROM FEC_Template__c];
        Assert.areEqual(expected, results.size(), 'Should return all templates');
        }
    }

    @IsTest
    static void testSelectByFilterNoFilter() {
        System.runAs(runAsAdmin()) {
        Test.startTest();
        List<FEC_Template__c> results = FEC_TemplateSelector.selectByFilter(null, null, null);
        Test.stopTest();

        Integer expected = [SELECT COUNT() FROM FEC_Template__c];
        Assert.areEqual(expected, results.size(), 'Should return all templates when no filters applied');
        }
    }

    @IsTest
    static void testSelectByFilterFolderId() {
        System.runAs(runAsAdmin()) {
        FEC_Folder__c folder = [
            SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c LIKE 'Marketing %' ORDER BY CreatedDate DESC LIMIT 1
        ];

        Test.startTest();
        List<FEC_Template__c> results = FEC_TemplateSelector.selectByFilter(folder.Id, null, null);
        Test.stopTest();

        Integer expected = [SELECT COUNT() FROM FEC_Template__c WHERE FEC_Folder__c = :folder.Id];
        Assert.areEqual(expected, results.size(), 'Marketing folder should return its templates');
        }
    }

    @IsTest
    static void testSelectByFilterSearchText() {
        System.runAs(runAsAdmin()) {
            FEC_Template__c tmpl = [
                SELECT Name FROM FEC_Template__c WHERE Name LIKE 'Welcome Email %' ORDER BY CreatedDate DESC LIMIT 1
            ];
            String searchKey = tmpl.Name.substring(0, 7);

            Test.startTest();
            List<FEC_Template__c> results = FEC_TemplateSelector.selectByFilter(null, searchKey, null);
            Test.stopTest();

            Assert.isTrue(results.size() >= 1, 'Search should return at least one template');
            Assert.isTrue(results[0].Name.contains(searchKey), 'Search result should match template name');
        }
    }

    @IsTest
    static void testSelectByFilterActiveOnly() {
        System.runAs(runAsAdmin()) {
        Test.startTest();
        List<FEC_Template__c> results = FEC_TemplateSelector.selectByFilter(null, null, true);
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Active-only filter should return 2 active templates');
        }
    }

    @IsTest
    static void testSelectByFolderId() {
        System.runAs(runAsAdmin()) {
        FEC_Folder__c folder = [
            SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c LIKE 'Transactional %' ORDER BY CreatedDate DESC LIMIT 1
        ];

        Test.startTest();
        List<FEC_Template__c> results = FEC_TemplateSelector.selectByFolderId(folder.Id);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Transactional folder should have 1 template');
        }
    }
}