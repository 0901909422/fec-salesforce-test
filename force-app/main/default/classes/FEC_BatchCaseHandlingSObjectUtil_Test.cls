@IsTest
private class FEC_BatchCaseHandlingSObjectUtil_Test {

    /**
     * Kịch bản 1: Kiểm tra hàm addIfNotBlank.
     * Bao phủ: Thêm trường mới thành công, bỏ qua trường bị trùng lặp, và bỏ qua chuỗi trống.
     */
    @IsTest
    static void testAddIfNotBlank() {
        List<String> selectParts = new List<String>{ 'Id', 'Name' };

        Test.startTest();
        // Nhánh 1: Thêm trường hợp lệ chưa tồn tại
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, 'CreatedDate');
        // Nhánh 2: Thêm trường đã tồn tại sẵn trong danh sách (Trùng lặp)
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, 'Name');
        // Nhánh 3: Thêm trường trống/null
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, '');
        FEC_BatchCaseHandlingSObjectUtil.addIfNotBlank(selectParts, null);
        Test.stopTest();

        System.assertEquals(3, selectParts.size(), 'Danh sách chỉ được chứa 3 phần tử duy nhất.');
        System.assertEquals('CreatedDate', selectParts[2], 'Trường mới phải được chèn vào cuối danh sách.');
    }

    /**
     * Kịch bản 2: Kiểm tra hàm pickField so khớp trường ưu tiên từ Field Map.
     * Bao phủ: Tìm thấy trường ưu tiên đầu tiên, tìm thấy trường ưu tiên thay thế phía sau, và trả về null nếu không có trường nào khớp.
     */
    @IsTest
    static void testPickField() {
        Map<String, Schema.SObjectField> fieldMap = Case.SObjectType.getDescribe().fields.getMap();

        Test.startTest();
        // Nhánh 1: Khớp ngay trường ưu tiên số 1
        String matchFirst = FEC_BatchCaseHandlingSObjectUtil.pickField(fieldMap, new List<String>{ 'Subject', 'Status' });
        // Nhánh 2: Trường đầu không có, khớp trường thay thế phía sau
        String matchFallback = FEC_BatchCaseHandlingSObjectUtil.pickField(fieldMap, new List<String>{ 'NON_EXIST_FIELD__c', 'Status' });
        // Nhánh 3: Không khớp bất kỳ trường nào trong Map
        String matchNull = FEC_BatchCaseHandlingSObjectUtil.pickField(fieldMap, new List<String>{ 'FAKE_FIELD_1__c', 'FAKE_FIELD_2__c' });
        Test.stopTest();

        System.assertEquals('Subject', matchFirst);
        System.assertEquals('Status', matchFallback);
        System.assertEquals(null, matchNull);
    }

    /**
     * Kịch bản 3: Kiểm tra hàm chuyển đổi văn bản asString.
     * Bao phủ: Giá trị thông thường và giá trị null.
     */
    @IsTest
    static void testAsString() {
        Test.startTest();
        String validString = FEC_BatchCaseHandlingSObjectUtil.asString('Hello');
        String integerString = FEC_BatchCaseHandlingSObjectUtil.asString(123);
        String nullString = FEC_BatchCaseHandlingSObjectUtil.asString(null);
        Test.stopTest();

        System.assertEquals('Hello', validString);
        System.assertEquals('123', integerString);
        System.assertEquals(null, nullString);
    }

    /**
     * Kịch bản 4: Kiểm tra hàm chuyển đổi thời gian asDatetime.
     * Bao phủ: Truyền đối tượng Datetime chuẩn, truyền sai kiểu dữ liệu, và truyền giá trị null.
     */
    @IsTest
    static void testAsDatetime() {
        Datetime now = Datetime.now();

        Test.startTest();
        Datetime validDt = FEC_BatchCaseHandlingSObjectUtil.asDatetime(now);
        Datetime invalidDt = FEC_BatchCaseHandlingSObjectUtil.asDatetime('2026-05-19 00:00:00'); // Sai kiểu dữ liệu (String)
        Datetime nullDt = FEC_BatchCaseHandlingSObjectUtil.asDatetime(null);
        Test.stopTest();

        System.assertEquals(now, validDt);
        System.assertEquals(null, invalidDt);
        System.assertEquals(null, nullDt);
    }

    /**
     * Kịch bản 5: Kiểm tra hàm chuyển đổi số thập phân asDecimal bao phủ toàn bộ các kiểu số.
     * Bao phủ: Trực tiếp kiểu Decimal, chuyển đổi từ Integer, chuyển đổi từ Long, sai kiểu dữ liệu, và nhận giá trị null.
     */
    @IsTest
    static void testAsDecimal_AllTypes() {
        Decimal decVal = 10.5;
        Integer intVal = 100;
        Long longVal = 999999999L;

        Test.startTest();
        Decimal fromDecimal = FEC_BatchCaseHandlingSObjectUtil.asDecimal(decVal);
        Decimal fromInteger = FEC_BatchCaseHandlingSObjectUtil.asDecimal(intVal);
        Decimal fromLong = FEC_BatchCaseHandlingSObjectUtil.asDecimal(longVal);
        Decimal fromInvalid = FEC_BatchCaseHandlingSObjectUtil.asDecimal('NotANumber');
        Decimal fromNull = FEC_BatchCaseHandlingSObjectUtil.asDecimal(null);
        Test.stopTest();

        System.assertEquals(10.5, fromDecimal);
        System.assertEquals(100.0, fromInteger);
        System.assertEquals(999999999.0, fromLong);
        System.assertEquals(null, fromInvalid);
        System.assertEquals(null, fromNull);
    }

    /**
     * Kịch bản 6: Kiểm tra hàm điền dữ liệu động putIfFieldExists vào SObject.
     * Bao phủ: 
     * - Trường không tồn tại -> Bỏ qua (continue)
     * - Trường không thể khởi tạo / AutoNumber / Formula (Calculated) -> Bỏ qua (continue)
     * - Trường hợp lệ -> Điền dữ liệu thành công và ngắt hàm ngay (return)
     */
    @IsTest
    static void testPutIfFieldExists_AllBranches() {
        Map<String, Schema.SObjectField> fieldMap = Case.SObjectType.getDescribe().fields.getMap();
        Case record = new Case();

        // Chuẩn bị danh sách các tên trường đi từ sai/không được ghi đến đúng để ép phủ toàn bộ nhánh `continue`
        List<String> testFields = new List<String>{
            'NON_EXISTENT_FIELD__c', // Thỏa mãn nhánh !fieldMap.containsKey
            'CaseNumber',            // Thỏa mãn nhánh dfr.isAutoNumber() hoặc !isCreateable()
            'Subject'                // Thỏa mãn điều kiện ghi thành công -> kích hoạt lệnh `return` ngắt hàm
        };

        Test.startTest();
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, record, testFields, 'Test Batch Subject');
        Test.stopTest();

        // Xác minh xem trường hợp lệ cuối cùng 'Subject' đã được ghi vào bản ghi thành công chưa
        System.assertEquals('Test Batch Subject', record.Subject, 'Trường Subject hợp lệ phải được điền dữ liệu.');
    }

    /**
     * Kịch bản 7: Kiểm tra hàm xóa đuôi mở rộng của tên tệp tin removeFileExtension.
     * Bao phủ: Tệp tin có đuôi chuẩn, tệp tin không có dấu chấm, tệp tin bắt đầu bằng dấu chấm ẩn, tên tệp tin nhận giá trị null.
     */
    @IsTest
    static void testRemoveFileExtension() {
        Test.startTest();
        String standardFile = FEC_BatchCaseHandlingSObjectUtil.removeFileExtension('Data_Report_2026.xlsx');
        String multipleDots = FEC_BatchCaseHandlingSObjectUtil.removeFileExtension('Backup.v1.csv');
        String noExtension = FEC_BatchCaseHandlingSObjectUtil.removeFileExtension('README');
        String leadingDotOnly = FEC_BatchCaseHandlingSObjectUtil.removeFileExtension('.gitignore'); // Dấu chấm ở vị trí index 0
        String nullFile = FEC_BatchCaseHandlingSObjectUtil.removeFileExtension(null);
        Test.stopTest();

        System.assertEquals('Data_Report_2026', standardFile);
        System.assertEquals('Backup.v1', multipleDots);
        System.assertEquals('README', noExtension);
        System.assertEquals('.gitignore', leadingDotOnly);
        System.assertEquals(null, nullFile);
    }
}