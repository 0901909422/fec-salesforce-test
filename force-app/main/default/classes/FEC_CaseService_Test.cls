@IsTest
private class FEC_CaseService_Test {

    @TestSetup
    static void setupData() {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'Test Service Case',
                Status = 'New',
                FEC_ID_Search__c = 'SVC-CASE-' + String.valueOf(System.currentTimeMillis())
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    /**
     * Kịch bản 1: Kiểm tra hàm getById với SOQL tĩnh (Chỉ truyền Set<Id>)
     * Mong đợi: Trả về danh sách Case với các trường được định nghĩa cứng trong query.
     */
    @IsTest
    static void testGetById_StaticSOQL() {
        // Lấy Id của Case vừa tạo
        Case c = [SELECT Id FROM Case LIMIT 1];
        Set<Id> caseIds = new Set<Id>{ c.Id };

        Test.startTest();
        List<Case> results = FEC_CaseService.getById(caseIds);
        Test.stopTest();

        // Khẳng định kết quả
        System.assertNotEquals(null, results, 'Danh sách trả về không được rỗng.');
        System.assertEquals(1, results.size(), 'Hệ thống phải trả về chính xác 1 bản ghi Case.');
        System.assertEquals(c.Id, results[0].Id, 'ID của Case trả về phải khớp với ID truyền vào.');
    }

    /**
     * Kịch bản 2: Kiểm tra hàm getById với SOQL động (Truyền Set<Id> và Set<String> tên trường)
     * Mong đợi: Câu lệnh SOQL động ghép đúng tên trường và trả về dữ liệu tương ứng.
     */
    @IsTest
    static void testGetById_DynamicSOQL() {
        // Lấy Id của Case
        Case c = [SELECT Id FROM Case LIMIT 1];
        Set<Id> caseIds = new Set<Id>{ c.Id };
        
        // Cấu hình các trường cần query động
        Set<String> fieldsToQuery = new Set<String>{ 'Subject', 'Status' };

        Test.startTest();
        List<Case> results = FEC_CaseService.getById(caseIds, fieldsToQuery);
        Test.stopTest();

        // Khẳng định kết quả
        System.assertNotEquals(null, results, 'Danh sách trả về không được rỗng.');
        System.assertEquals(1, results.size(), 'Hệ thống phải trả về chính xác 1 bản ghi Case.');
        System.assertEquals(c.Id, results[0].Id, 'ID của Case trả về phải khớp với ID truyền vào.');
        
        // Khẳng định các trường truy vấn động bốc đúng dữ liệu
        System.assertEquals('Test Service Case', results[0].Subject, 'Trường Subject phải được query và khớp dữ liệu.');
        System.assertEquals('New', results[0].Status, 'Trường Status phải được query và khớp dữ liệu.');
    }
    
    /**
     * Kịch bản 3: Truyền Set rỗng vào hàm getById.
     * Mong đợi: Xử lý an toàn và trả về mảng rỗng thay vì ném ngoại lệ SOQL.
     */
    @IsTest
    static void testGetById_EmptySet() {
        Set<Id> emptyIds = new Set<Id>();
        Set<String> emptyFields = new Set<String>();

        Test.startTest();
        List<Case> resultsStatic = FEC_CaseService.getById(emptyIds);
        List<Case> resultsDynamic = FEC_CaseService.getById(emptyIds, emptyFields);
        Test.stopTest();

        System.assertEquals(0, resultsStatic.size(), 'Set ID rỗng phải trả về danh sách rỗng (Static SOQL).');
        System.assertEquals(0, resultsDynamic.size(), 'Set ID rỗng phải trả về danh sách rỗng (Dynamic SOQL).');
    }
}