@IsTest
private class FEC_EnhancedLetterheadTrigHandler_Test {

    @IsTest
    static void testValidateFolderDeletion_Blocked() {
        // 1. Tạo Folder (Letterhead)
        FEC_Enhanced_Letterhead__c folder = new FEC_Enhanced_Letterhead__c(Name = 'Folder Active');
        insert folder;

        // 2. Tạo Template Active liên kết với Folder
        FEC_Template__c template = new FEC_Template__c(
            Name = 'Template Active',
            FEC_Enhanced_Letterhead__c = folder.Id,
            FEC_Active__c = true
        );
        insert template;

        // 3. Thực hiện hành động xóa và kiểm tra lỗi
        Test.startTest();
        try {
            delete folder;
            System.assert(false, 'Hệ thống phải chặn xóa vì có Template Active.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains(System.Label.FEC_Cannot_Delete_Enhanced_Letterhead), 
                'Lỗi trả về phải là System.Label.FEC_Cannot_Delete_Enhanced_Letterhead');
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateFolderDeletion_Allowed() {
        // 1. Tạo Folder
        FEC_Enhanced_Letterhead__c folder = new FEC_Enhanced_Letterhead__c(Name = 'Folder Inactive');
        insert folder;

        // 2. Tạo Template nhưng không Active
        FEC_Template__c template = new FEC_Template__c(
            Name = 'Template Inactive',
            FEC_Enhanced_Letterhead__c = folder.Id,
            FEC_Active__c = false
        );
        insert template;

        // 3. Thực hiện hành động xóa và xác nhận thành công
        Test.startTest();
        delete folder;
        Test.stopTest();

        List<FEC_Enhanced_Letterhead__c> results = [SELECT Id FROM FEC_Enhanced_Letterhead__c WHERE Id = :folder.Id];
        System.assertEquals(0, results.size(), 'Folder phải bị xóa thành công vì template không Active.');
    }
}