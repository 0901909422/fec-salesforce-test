@IsTest
private class FEC_RecordTypeDAO_Test {

    @IsTest
    static void testGetRecordsById() {
        // 1. Lấy một vài RecordType có sẵn trong hệ thống để test
        // Chúng ta lấy tối đa 5 bản ghi để không vượt quá giới hạn hoặc query dư thừa
        List<RecordType> existingRTs = [SELECT Id FROM RecordType WHERE IsActive = TRUE LIMIT 5];
        
        if (existingRTs.isEmpty()) {
            System.debug('Không có RecordType active để test.');
            return;
        }

        // 2. Chuẩn bị đầu vào cho DAO
        Set<String> rtIds = new Set<String>();
        for (RecordType rt : existingRTs) {
            rtIds.add(rt.Id);
        }

        Test.startTest();
        // 3. Gọi phương thức DAO
        List<RecordType> results = FEC_RecordTypeDAO.getRecordsById(rtIds);
        Test.stopTest();

        // 4. Kiểm tra kết quả
        System.assertNotEquals(0, results.size(), 'Danh sách kết quả không được rỗng.');
        System.assertEquals(rtIds.size(), results.size(), 'Số lượng bản ghi trả về phải khớp với đầu vào.');
        
        // Kiểm tra tính toàn vẹn của dữ liệu trả về
        for (RecordType rt : results) {
            System.assert(rtIds.contains(rt.Id), 'ID trả về phải nằm trong tập ID đã truyền vào.');
        }
    }

    @IsTest
    static void testGetRecordsById_Empty() {
        // Test trường hợp truyền vào Set rỗng
        Test.startTest();
        List<RecordType> results = FEC_RecordTypeDAO.getRecordsById(new Set<String>());
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Truyền danh sách ID rỗng phải trả về kết quả rỗng.');
    }
}