@IsTest
private class FEC_ContentHistorySelector_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());
        FEC_Folder__c folder = new FEC_Folder__c(
            FEC_Folder_Label__c = 'HistorySelectorFolder',
            FEC_Folder_Unique_Name__c = 'HistSel_' + suffix
        );
        insert folder;

        FEC_Template__c template = new FEC_Template__c(
            Name = 'History Selector Template',
            FEC_Folder__c = folder.Id,
            FEC_API_Name__c = 'History_Selector_Template',
            FEC_Active__c = true,
            FEC_Subject_Line__c = 'Test Subject',
            FEC_Body__c = '<p>Test body</p>'
        );
        insert template;

        insert new FEC_Content_History_Tracking__c(
            Name = 'History 001',
            FEC_Date__c = Datetime.now(),
            FEC_Template__c = template.Id,
            FEC_Original_Value__c = 'Old Value',
            FEC_New_Value__c = 'New Value'
        );
    }

    @IsTest
    static void testSelectByTemplateId() {
        FEC_Template__c template = [SELECT Id FROM FEC_Template__c LIMIT 1];

        Test.startTest();
        List<FEC_Content_History_Tracking__c> results =
            FEC_ContentHistorySelector.selectByTemplateId(template.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Phải trả về đúng 1 bản ghi lịch sử.');
        System.assertEquals('New Value', results[0].FEC_New_Value__c);
    }

    @IsTest
    static void testSelectById() {
        FEC_Content_History_Tracking__c history = [
            SELECT Id FROM FEC_Content_History_Tracking__c LIMIT 1
        ];

        Test.startTest();
        FEC_Content_History_Tracking__c result = FEC_ContentHistorySelector.selectById(history.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Bản ghi không được null.');
        System.assertEquals(history.Id, result.Id);
    }

    @IsTest
    static void testSelectById_NotFound() {
        Id fakeId = Id.valueOf(
            FEC_Content_History_Tracking__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000'
        );

        Test.startTest();
        FEC_Content_History_Tracking__c result = FEC_ContentHistorySelector.selectById(fakeId);
        Test.stopTest();

        System.assertEquals(null, result, 'Tìm kiếm ID không tồn tại phải trả về null.');
    }
}
