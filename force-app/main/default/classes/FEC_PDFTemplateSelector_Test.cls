@IsTest
private class FEC_PDFTemplateSelector_Test {

    @IsTest
    static void testGetByCode() {
        // Lấy một bản ghi từ metadata để làm dữ liệu test
        // Nếu không có dữ liệu thật, hãy đảm bảo query trả về null và hàm xử lý đúng
        List<FEC_PDFTemplate__mdt> allMdt = [SELECT FEC_TemplateCode__c FROM FEC_PDFTemplate__mdt WHERE FEC_IsActive__c = true LIMIT 1];
        
        Test.startTest();
        // Case 1: Lấy với code hợp lệ (nếu có dữ liệu)
        if (!allMdt.isEmpty()) {
            FEC_PDFTemplate__mdt t = FEC_PDFTemplateSelector.getByCode(allMdt[0].FEC_TemplateCode__c);
            System.assertNotEquals(null, t, 'Phải tìm thấy template theo code.');
        }
        
        // Case 2: Code rỗng/null
        System.assertEquals(null, FEC_PDFTemplateSelector.getByCode(null), 'Phải trả về null khi code là null.');
        System.assertEquals(null, FEC_PDFTemplateSelector.getByCode('INVALID_CODE_999'), 'Phải trả về null khi code không tồn tại.');
        Test.stopTest();
    }

    @IsTest
    static void testGetByCategory() {
        Test.startTest();
        // Test trường hợp rỗng
        List<FEC_PDFTemplate__mdt> results = FEC_PDFTemplateSelector.getByCategory('');
        System.assertEquals(0, results.size(), 'List phải rỗng khi category rỗng.');
        
        // Test logic truy vấn (không kỳ vọng dữ liệu cụ thể vì phụ thuộc org)
        List<FEC_PDFTemplate__mdt> resultsReal = FEC_PDFTemplateSelector.getByCategory('Thanh Lý');
        System.assertNotEquals(null, resultsReal);
        Test.stopTest();
    }

    @IsTest
    static void testGetAllActive() {
        Test.startTest();
        List<FEC_PDFTemplate__mdt> all = FEC_PDFTemplateSelector.getAllActive();
        Test.stopTest();
        
        System.assertNotEquals(null, all, 'Kết quả không được null.');
    }

    @IsTest
    static void testGetTemplateOptions() {
        Test.startTest();
        List<FEC_PDFTemplateSelector.TemplateOption> options = FEC_PDFTemplateSelector.getTemplateOptions();
        Test.stopTest();

        // Kiểm tra cấu trúc dữ liệu Wrapper
        if (!options.isEmpty()) {
            FEC_PDFTemplateSelector.TemplateOption opt = options[0];
            System.assert(String.isNotBlank(opt.label), 'Label option không được trống.');
            System.assert(String.isNotBlank(opt.value), 'Value option không được trống.');
        }
    }
}