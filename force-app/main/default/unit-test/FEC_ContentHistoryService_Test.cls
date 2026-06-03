@IsTest
private class FEC_ContentHistoryService_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());
        FEC_Folder__c folder = new FEC_Folder__c(
            FEC_Folder_Label__c = 'HistoryServiceFolder',
            FEC_Folder_Unique_Name__c = 'HistSvc_' + suffix
        );
        insert folder;

        FEC_Template__c template = new FEC_Template__c(
            Name = 'History Service Template',
            FEC_Folder__c = folder.Id,
            FEC_Active__c = true,
            FEC_Subject_Line__c = 'Test Subject',
            FEC_Body__c = '<p>Test body</p>'
        );
        insert template;

        insert new FEC_Content_History_Tracking__c(
            Name = 'History Log 1',
            FEC_Template__c = template.Id,
            FEC_Date__c = Datetime.now()
        );
    }

    @IsTest
    static void testGetHistoryByTemplate() {
        FEC_Template__c template = [SELECT Id FROM FEC_Template__c LIMIT 1];

        Test.startTest();
        List<FEC_Content_History_Tracking__c> results =
            FEC_ContentHistoryService.getHistoryByTemplate(template.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Service phải trả về danh sách lịch sử của template.');
        System.assertEquals(template.Id, results[0].FEC_Template__c);
    }

    @IsTest
    static void testGetHistoryRecord() {
        FEC_Content_History_Tracking__c history = [
            SELECT Id FROM FEC_Content_History_Tracking__c LIMIT 1
        ];

        Test.startTest();
        FEC_Content_History_Tracking__c result =
            FEC_ContentHistoryService.getHistoryRecord(history.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Service phải trả về bản ghi lịch sử.');
        System.assertEquals(history.Id, result.Id);
    }

    @IsTest
    static void testGetHistoryRecord_NotFound() {
        Id fakeId = Id.valueOf(
            FEC_Content_History_Tracking__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000'
        );

        Test.startTest();
        FEC_Content_History_Tracking__c result =
            FEC_ContentHistoryService.getHistoryRecord(fakeId);
        Test.stopTest();

        System.assertEquals(null, result, 'Khi không tìm thấy, Service phải trả về null.');
    }
}
