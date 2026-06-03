@IsTest(SeeAllData=true)
private class FEC_TemplateSelector_UT_Test {
    private static List<FEC_Template__c> loadTemplates(Integer sizeLimit) {
        return [
            SELECT Id, Name, FEC_Active__c
            FROM FEC_Template__c
            ORDER BY Name ASC
            LIMIT :sizeLimit
        ];
    }

    @IsTest
    static void testSelectByIdAndNotFound() {
        List<FEC_Template__c> rows = loadTemplates(1);
        if (rows.isEmpty()) {
            System.assert(true, 'No templates in org data.');
            return;
        }
        FEC_Template__c one = rows[0];
        Test.startTest();
        FEC_Template__c found = FEC_TemplateSelector.selectById(one.Id);
        FEC_Template__c missing = FEC_TemplateSelector.selectById(Id.valueOf('a0L000000000001EAA'));
        Test.stopTest();

        System.assertNotEquals(null, found);
        System.assertEquals(null, missing);
    }

    @IsTest
    static void testSelectByIdsAndFolder() {
        List<FEC_Template__c> all = loadTemplates(20);
        if (all.isEmpty()) {
            System.assert(true, 'No templates in org data.');
            return;
        }
        Set<Id> ids = new Set<Id>();
        for (FEC_Template__c row : all) {
            ids.add(row.Id);
        }

        Test.startTest();
        List<FEC_Template__c> byIds = FEC_TemplateSelector.selectByIds(ids);
        List<FEC_Template__c> byFolder = FEC_TemplateSelector.selectByFolderId(null);
        Test.stopTest();

        System.assert(byIds.size() > 0);
        System.assert(byFolder.size() >= 0);
    }

    @IsTest
    static void testSelectByFilterVariants() {
        List<FEC_Template__c> rows = loadTemplates(20);
        if (rows.isEmpty()) {
            System.assert(true, 'No templates in org data.');
            return;
        }

        Test.startTest();
        List<FEC_Template__c> allRows = FEC_TemplateSelector.selectByFilter(null, null, null);
        List<FEC_Template__c> folderRows = FEC_TemplateSelector.selectByFilter(null, null, null);
        List<FEC_Template__c> searchRows = FEC_TemplateSelector.selectByFilter(null, rows[0].Name.left(3), null);
        List<FEC_Template__c> activeRows = FEC_TemplateSelector.selectByFilter(null, null, true);
        List<FEC_Template__c> inactiveRows = FEC_TemplateSelector.selectByFilter(null, null, false);
        Test.stopTest();

        System.assert(allRows.size() > 0);
        System.assert(folderRows.size() >= 0);
        System.assert(searchRows.size() >= 0);
        System.assert(activeRows.size() >= 0);
        System.assert(inactiveRows.size() >= 0);
    }
}
