/**
 * Test Class: FEC_FolderSelector_Test
 * Covers all Selector methods for FEC_Folder__c.
 * @created  : 2026/03/12
 */
@IsTest
private class FEC_FolderSelector_Test {

    @TestSetup
    static void setupData() {
        FEC_Folder__c root1 = new FEC_Folder__c(Name = 'Marketing',FEC_Folder_Unique_Name__c = 'Marketing');
        FEC_Folder__c root2 = new FEC_Folder__c(Name = 'Support', FEC_Folder_Unique_Name__c = 'Support');
        insert new List<FEC_Folder__c>{ root1, root2 };

        FEC_Folder__c child = new FEC_Folder__c(
            Name = 'Promotions',
            FEC_Folder_Unique_Name__c = 'Promotions',
            FEC_Parent_Folder__c = root1.Id
        );
        insert child;
    }

    @IsTest
    static void testSelectById() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c WHERE Name = 'Marketing' LIMIT 1];

        Test.startTest();
        FEC_Folder__c result = FEC_FolderSelector.selectById(folder.Id);
        Test.stopTest();

        Assert.isNotNull(result);
        Assert.areEqual('Marketing', result.Name);
    }

    @IsTest
    static void testSelectAll() {
        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderSelector.selectAll();
        Test.stopTest();

        Assert.areEqual(3, results.size(), 'Should return all 3 folders');
    }

    @IsTest
    static void testSelectTopLevel() {
        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderSelector.selectTopLevel();
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Should return 2 root-level folders');
    }

    @IsTest
    static void testSelectByParentId() {
        FEC_Folder__c parent = [SELECT Id FROM FEC_Folder__c WHERE Name = 'Marketing' LIMIT 1];

        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderSelector.selectByParentId(parent.Id);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Marketing should have 1 child folder');
        Assert.areEqual('Promotions', results[0].Name);
    }

    @IsTest
    static void testSelectBySearch() {
        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderSelector.selectBySearch('Market');
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Search "Market" should return Marketing folder');
    }

    @IsTest
    static void testSelectBySearchBlank() {
        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderSelector.selectBySearch('');
        Test.stopTest();

        Assert.areEqual(3, results.size(), 'Blank search should return all folders');
    }
}