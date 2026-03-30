/**
 * Test Class: FEC_FolderService_Test
 * Covers Service-layer logic for folders: CRUD, hierarchy validation,
 * and children guard on delete.
 * @created  : 2026/03/12
 */
@IsTest
private class FEC_FolderService_Test {

    @TestSetup
    static void setupData() {
        FEC_Folder__c root = new FEC_Folder__c(Name = 'Root Folder', FEC_Folder_Unique_Name__c= 'Root Folder');
        insert root;

        FEC_Folder__c child = new FEC_Folder__c(
            Name = 'Child Folder',
            FEC_Folder_Unique_Name__c= 'Child Folder',
            FEC_Parent_Folder__c = root.Id
        );
        insert child;

        // Template inside root folder
        FEC_Template__c tmpl = new FEC_Template__c(
            Name = 'Root Template',
            FEC_API_Name__c = 'Root_Template',
            FEC_Folder__c = root.Id,
            FEC_Active__c = true
        );
        insert tmpl;
    }

    @IsTest
    static void testGetFolder() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        FEC_Folder__c result = FEC_FolderService.getFolder(folder.Id);
        Test.stopTest();

        Assert.isNotNull(result);
        Assert.areEqual('Root Folder', result.Name);
    }

    @IsTest
    static void testGetAllFolders() {
        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderService.getAllFolders();
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Should return all 2 folders');
    }

    @IsTest
    static void testGetTopLevelFolders() {
        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderService.getTopLevelFolders();
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 root-level folder');
        Assert.areEqual('Root Folder', results[0].Name);
    }

    @IsTest
    static void testGetFolderContents() {
        FEC_Folder__c root = [SELECT Id FROM FEC_Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        Map<String, Object> contents = FEC_FolderService.getFolderContents(root.Id);
        Test.stopTest();

        List<FEC_Folder__c> childFolders = (List<FEC_Folder__c>) contents.get('folders');
        List<FEC_Template__c> childTemplates = (List<FEC_Template__c>) contents.get('templates');

        Assert.areEqual(1, childFolders.size(), 'Root should have 1 child folder');
        Assert.areEqual(1, childTemplates.size(), 'Root should have 1 template');
    }

    @IsTest
    static void testSaveFolderInsert() {
        FEC_Folder__c newFolder = new FEC_Folder__c(Name = 'New Folder', FEC_Folder_Unique_Name__c= 'New Folder');

        Test.startTest();
        Id savedId = FEC_FolderService.saveFolder(newFolder);
        Test.stopTest();

        Assert.isNotNull(savedId);
        FEC_Folder__c saved = [SELECT Name FROM FEC_Folder__c WHERE Id = :savedId];
        Assert.areEqual('New Folder', saved.Name);
    }

    @IsTest
    static void testSaveFolderUpdate() {
        FEC_Folder__c folder = [SELECT Id, Name FROM FEC_Folder__c WHERE Name = 'Child Folder' LIMIT 1];
        folder.Name = 'Updated Child';

        Test.startTest();
        FEC_FolderService.saveFolder(folder);
        Test.stopTest();

        FEC_Folder__c updated = [SELECT Name FROM FEC_Folder__c WHERE Id = :folder.Id];
        Assert.areEqual('Updated Child', updated.Name);
    }

    @IsTest
    static void testDeleteFolderWithChildFolders() {
        FEC_Folder__c root = [SELECT Id FROM FEC_Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        try {
            FEC_FolderService.deleteFolder(root.Id);
            Assert.fail('Expected exception when deleting folder with child folders');
        } catch (FEC_APIServiceException e) {
            Assert.isTrue(e.getMessage().contains('sub-folder'),
                'Error should mention child folders. Actual: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteFolderWithTemplates() {
        // Remove child folder first to isolate template guard test
        FEC_Folder__c child = [SELECT Id FROM FEC_Folder__c WHERE Name = 'Child Folder' LIMIT 1];
        delete child;

        FEC_Folder__c root = [SELECT Id FROM FEC_Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        try {
            FEC_FolderService.deleteFolder(root.Id);
            Assert.fail('Expected exception when deleting folder with templates');
        } catch (FEC_APIServiceException e) {
            Assert.isTrue(e.getMessage().contains('template'),
                'Error should mention child templates. Actual: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteFolderSuccess() {
        // Delete child folder (has no children of its own)
        FEC_Folder__c child = [SELECT Id FROM FEC_Folder__c WHERE Name = 'Child Folder' LIMIT 1];

        Test.startTest();
        FEC_FolderService.deleteFolder(child.Id);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM FEC_Folder__c WHERE Id = :child.Id];
        Assert.areEqual(0, count, 'Child folder should be deleted');
    }

    @IsTest
    static void testSearchFolders() {
        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderService.searchFolders('Root');
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.areEqual('Root Folder', results[0].Name);
    }
}