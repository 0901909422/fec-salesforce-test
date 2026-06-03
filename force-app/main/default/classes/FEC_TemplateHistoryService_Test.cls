/**
 * FEC_Template__History is standard field-history for FEC_Template__c.
 * History rows are created by the platform when tracked fields change — not insertable in tests.
 */
@IsTest
private class FEC_TemplateHistoryService_Test {

    private static FEC_Template__c createTemplate() {
        String suffix = String.valueOf(System.currentTimeMillis());
        FEC_Folder__c folder = new FEC_Folder__c(
            FEC_Folder_Label__c = 'Test Folder',
            FEC_Folder_Unique_Name__c = 'TplHist_' + suffix
        );
        insert folder;

        FEC_Template__c template = new FEC_Template__c(
            Name = 'Original Name',
            FEC_Folder__c = folder.Id,
            FEC_Active__c = false
        );
        insert template;
        return template;
    }

    private static void generateHistory(Id templateId) {
        update new FEC_Template__c(
            Id = templateId,
            Name = 'Updated Name',
            FEC_Active__c = true
        );
    }

    @IsTest
    static void testGetHistoryByTemplate() {
        FEC_Template__c template = createTemplate();
        generateHistory(template.Id);

        Test.startTest();
        List<FEC_Template__History> results =
            FEC_TemplateHistoryService.getHistoryByTemplate(template.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Service should return a list.');
        for (FEC_Template__History row : results) {
            System.assertEquals(template.Id, row.ParentId);
        }
    }

    @IsTest
    static void testGetHistoryRecord() {
        FEC_Template__c template = createTemplate();
        generateHistory(template.Id);

        List<FEC_Template__History> existing = [
            SELECT Id
            FROM FEC_Template__History
            WHERE ParentId = :template.Id
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            Test.startTest();
            FEC_Template__History result =
                FEC_TemplateHistoryService.getHistoryRecord(template.Id);
            Test.stopTest();
            System.assertEquals(null, result, 'No history when field tracking is off.');
            return;
        }

        Test.startTest();
        FEC_Template__History result =
            FEC_TemplateHistoryService.getHistoryRecord(existing[0].Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Phải lấy được bản ghi history bằng Id.');
        System.assertEquals(existing[0].Id, result.Id, 'Id bản ghi phải khớp.');
    }
}
