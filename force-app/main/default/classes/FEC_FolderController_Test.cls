/**
 * Test Class: FEC_FolderController_Test
 * Covers @AuraEnabled controller methods for folders.
 * @created  : 2026/03/12
 */
@IsTest
private class FEC_FolderController_Test {

    @TestSetup
    static void setupData() {
        FEC_Folder__c root = new FEC_Folder__c(FEC_Folder_Label__c = 'Controller Root');
        insert root;

        FEC_Folder__c child = new FEC_Folder__c(
            FEC_Folder_Label__c = 'Controller Child',
            FEC_Parent_Folder__c = root.Id
        );
        insert child;

        FEC_Template__c tmpl = new FEC_Template__c(
            FEC_Template_Name__c = 'Inside Root',
            FEC_Folder__c = root.Id,
            FEC_Active__c = true
        );
        insert tmpl;
    }

    @IsTest
    static void testGetFolder() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Controller Root' LIMIT 1];

        Test.startTest();
        FEC_Folder__c result = FEC_FolderController.getFolder(folder.Id);
        Test.stopTest();

        Assert.isNotNull(result);
        Assert.areEqual('Controller Root', result.FEC_Folder_Label__c);
    }

    @IsTest
    static void testGetAllFolders() {
        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderController.getAllFolders();
        Test.stopTest();

        Assert.areEqual(2, results.size());
    }

    @IsTest
    static void testGetTopLevelFolders() {
        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderController.getTopLevelFolders();
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.areEqual('Controller Root', results[0].FEC_Folder_Label__c);
    }

    @IsTest
    static void testGetFolderContents() {
        FEC_Folder__c root = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Controller Root' LIMIT 1];

        Test.startTest();
        Map<String, Object> contents = FEC_FolderController.getFolderContents(root.Id);
        Test.stopTest();

        Assert.isNotNull(contents);
        Assert.isTrue(contents.containsKey('folders'));
        Assert.isTrue(contents.containsKey('templates'));
    }

    @IsTest
    static void testSaveFolder() {
        FEC_Folder__c newFolder = new FEC_Folder__c(FEC_Folder_Label__c = 'New Via Controller');
        String json = JSON.serialize(newFolder);

        Test.startTest();
        Id savedId = FEC_FolderController.saveFolder(json);
        Test.stopTest();

        Assert.isNotNull(savedId);
        FEC_Folder__c saved = [SELECT FEC_Folder_Label__c FROM FEC_Folder__c WHERE Id = :savedId];
        Assert.areEqual('New Via Controller', saved.FEC_Folder_Label__c);
    }

    @IsTest
    static void testDeleteFolderBlocked() {
        FEC_Folder__c root = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Controller Root' LIMIT 1];

        Test.startTest();
        try {
            FEC_FolderController.deleteFolder(root.Id);
            Assert.fail('Expected AuraHandledException for folder with children');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('sub-folder') || e.getMessage().contains('Script-thrown'),
                'Error should be propagated. Actual: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteFolderSuccess() {
        FEC_Folder__c child = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Controller Child' LIMIT 1];

        Test.startTest();
        FEC_FolderController.deleteFolder(child.Id);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM FEC_Folder__c WHERE Id = :child.Id];
        Assert.areEqual(0, count);
    }

    @IsTest
    static void testSearchFolders() {
        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderController.searchFolders('Controller');
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Both folders contain "Controller" in label');
    }
}