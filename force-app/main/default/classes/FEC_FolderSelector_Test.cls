/**
 * Test Class: FEC_FolderSelector_Test
 * Covers all Selector methods for FEC_Folder__c.
 * @created  : 2026/03/12
 */
@IsTest
private class FEC_FolderSelector_Test {

    @TestSetup
    static void setupData() {
        FEC_Folder__c root1 = new FEC_Folder__c(FEC_Folder_Label__c = 'Marketing');
        FEC_Folder__c root2 = new FEC_Folder__c(FEC_Folder_Label__c = 'Support');
        insert new List<FEC_Folder__c>{ root1, root2 };

        FEC_Folder__c child = new FEC_Folder__c(
            FEC_Folder_Label__c = 'Promotions',
            FEC_Parent_Folder__c = root1.Id
        );
        insert child;
    }

    @IsTest
    static void testSelectById() {
        FEC_Folder__c folder = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Marketing' LIMIT 1];

        Test.startTest();
        FEC_Folder__c result = FEC_FolderSelector.selectById(folder.Id);
        Test.stopTest();

        Assert.isNotNull(result);
        Assert.areEqual('Marketing', result.FEC_Folder_Label__c);
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
        FEC_Folder__c parent = [SELECT Id FROM FEC_Folder__c WHERE FEC_Folder_Label__c = 'Marketing' LIMIT 1];

        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderSelector.selectByParentId(parent.Id);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Marketing should have 1 child folder');
        Assert.areEqual('Promotions', results[0].FEC_Folder_Label__c);
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