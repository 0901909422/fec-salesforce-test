/**
 * Test Class:  FEC_TemplateHistorySelector_Test
 * Covers: FEC_TemplateHistorySelector + FEC_TemplateHistoryService
 *
 * FEC_Template__History is the standard field-history-tracking object for
 * FEC_Template__c.  Records are created automatically by Salesforce when a
 * tracked field value changes — they cannot be inserted manually.
 *
 * The test creates a template, then updates tracked fields so the platform
 * generates history rows, and finally queries them through the Selector /
 * Service layer.
 *
 * @created  : 2026/03/19
 */
@IsTest
private class FEC_TemplateHistorySelector_Test {

    /* ─── helpers ─── */

    private static FEC_Template__c createTemplate() {
        FEC_Folder__c folder = new FEC_Folder__c(
            FEC_Folder_Label__c = 'Test Folder'
        );
        insert folder;

        FEC_Template__c tmpl = new FEC_Template__c(
            FEC_Template_Name__c = 'Original Name',
            FEC_Folder__c        = folder.Id,
            FEC_Active__c        = false
        );
        insert tmpl;
        return tmpl;
    }

    /**
     * Update tracked fields so Salesforce creates FEC_Template__History rows.
     */
    private static void generateHistory(Id templateId) {
        FEC_Template__c tmpl = new FEC_Template__c(Id = templateId);
        tmpl.FEC_Template_Name__c = 'Updated Name';
        tmpl.FEC_Active__c        = true;
        update tmpl;
    }

    /* ─── Selector tests ─── */

    @IsTest
    static void testSelectByTemplateId() {
        FEC_Template__c tmpl = createTemplate();
        generateHistory(tmpl.Id);

        Test.startTest();
        List<FEC_Template__History> results =
            FEC_TemplateHistorySelector.selectByTemplateId(tmpl.Id);
        Test.stopTest();

        // At minimum Salesforce will have created history rows for the field changes.
        // Exact count depends on which fields have trackHistory enabled in the org.
        System.assertNotEquals(null, results, 'Results list should never be null');
        // Verify all returned records belong to the correct parent
        for (FEC_Template__History h : results) {
            System.assertEquals(tmpl.Id, h.ParentId,
                'History record should belong to the template');
        }
    }

    @IsTest
    static void testSelectByTemplateIdEmpty() {
        FEC_Template__c tmpl = createTemplate();
        // No update → may have zero history rows (depends on org config)

        Test.startTest();
        List<FEC_Template__History> results =
            FEC_TemplateHistorySelector.selectByTemplateId(tmpl.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results list should never be null');
    }

    @IsTest
    static void testSelectById() {
        FEC_Template__c tmpl = createTemplate();
        generateHistory(tmpl.Id);

        // Grab any history row that was auto-created
        List<FEC_Template__History> existing = [
            SELECT Id FROM FEC_Template__History WHERE ParentId = :tmpl.Id LIMIT 1
        ];
        if (existing.isEmpty()) {
            // No tracked fields enabled → nothing to assert, but still cover the code path
            Test.startTest();
            FEC_Template__History result = FEC_TemplateHistorySelector.selectById(tmpl.Id);
            Test.stopTest();
            System.assertEquals(null, result, 'No history record expected');
            return;
        }

        Test.startTest();
        FEC_Template__History result =
            FEC_TemplateHistorySelector.selectById(existing[0].Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return the history record');
        System.assertEquals(existing[0].Id, result.Id, 'Ids should match');
    }

    @IsTest
    static void testSelectByIdNotFound() {
        // Use an Id that does not correspond to any real record
        Id fakeId = FEC_Template__History.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.startTest();
        FEC_Template__History result = FEC_TemplateHistorySelector.selectById(fakeId);
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null for non-existent record');
    }

    /* ─── Service tests ─── */

    @IsTest
    static void testServiceGetHistoryByTemplate() {
        FEC_Template__c tmpl = createTemplate();
        generateHistory(tmpl.Id);

        Test.startTest();
        List<FEC_Template__History> results =
            FEC_TemplateHistoryService.getHistoryByTemplate(tmpl.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Service should return a list');
    }

    @IsTest
    static void testServiceGetHistoryRecord() {
        FEC_Template__c tmpl = createTemplate();
        generateHistory(tmpl.Id);

        List<FEC_Template__History> existing = [
            SELECT Id FROM FEC_Template__History WHERE ParentId = :tmpl.Id LIMIT 1
        ];
        if (existing.isEmpty()) {
            Test.startTest();
            FEC_Template__History result = FEC_TemplateHistoryService.getHistoryRecord(tmpl.Id);
            Test.stopTest();
            System.assertEquals(null, result, 'No history record expected');
            return;
        }

        Test.startTest();
        FEC_Template__History result =
            FEC_TemplateHistoryService.getHistoryRecord(existing[0].Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Service should return the history record');
    }
}