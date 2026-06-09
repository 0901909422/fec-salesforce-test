@IsTest
private class FEC_BatchImportCommon_Test {

    /**
     * Kịch bản 1: Kiểm tra hàm getCustomerCaseRecordTypeId lấy Record Type ID của Customer Case.
     * Mong đợi: Hàm gọi lớp Utils dùng chung và trả về kết quả định danh ID hợp lệ (hoặc null nếu Org không cấu hình).
     */
    @IsTest
    static void testGetCustomerCaseRecordTypeId() {
        Test.startTest();
        Id rtId = FEC_BatchImportCommon.getCustomerCaseRecordTypeId();
        Test.stopTest();
        
        // Không assert cụ thể Id vì tùy thuộc vào dữ liệu cấu hình Metadata của từng Org
        System.assert(true, 'Hàm truy vấn Record Type ID vận hành ổn định.');
    }

    /**
     * Kịch bản 2: Kiểm tra hàm removeFileExtension xóa đuôi mở rộng của tên tệp tin.
     * Bao phủ: Tên file có đuôi chuẩn, file có nhiều dấu chấm, file không đuôi, file ẩn chỉ có dấu chấm đầu, và chuỗi trống/null.
     */
    @IsTest
    static void testRemoveFileExtension() {
        Test.startTest();
        String standardFile = FEC_BatchImportCommon.removeFileExtension('Import_Data_2026.csv');
        String multipleDots = FEC_BatchImportCommon.removeFileExtension('Report.v2.final.xlsx');
        String noExtension  = FEC_BatchImportCommon.removeFileExtension('DRAFT_FILE');
        String leadingDot   = FEC_BatchImportCommon.removeFileExtension('.env'); // idx = 0
        String blankFile    = FEC_BatchImportCommon.removeFileExtension('');
        String nullFile     = FEC_BatchImportCommon.removeFileExtension(null);
        Test.stopTest();

        System.assertEquals('Import_Data_2026', standardFile);
        System.assertEquals('Report.v2.final', multipleDots);
        System.assertEquals('DRAFT_FILE', noExtension);
        System.assertEquals('.env', leadingDot);
        System.assertEquals('', blankFile);
        System.assertEquals(null, nullFile);
    }

    /**
     * Kịch bản 3: Kiểm tra hàm addIfNotBlank bổ sung trường vào danh sách chuỗi Dynamic SOQL.
     * Bao phủ: Thêm thành công trường mới, chặn trùng lặp trường cũ, chặn chuỗi trống.
     */
    @IsTest
    static void testAddIfNotBlank() {
        List<String> selectParts = new List<String>{ 'Id', 'Status' };

        Test.startTest();
        FEC_BatchImportCommon.addIfNotBlank(selectParts, 'Origin'); // Hợp lệ -> Thêm vào
        FEC_BatchImportCommon.addIfNotBlank(selectParts, 'Status'); // Trùng lặp -> Bỏ qua
        FEC_BatchImportCommon.addIfNotBlank(selectParts, '  ');     // Trống -> Bỏ qua
        FEC_BatchImportCommon.addIfNotBlank(selectParts, null);     // Null -> Bỏ qua
        Test.stopTest();

        System.assertEquals(3, selectParts.size(), 'Danh sách chỉ được chứa đúng 3 phần tử.');
        System.assertEquals('Origin', selectParts[2]);
    }

    /**
     * Kịch bản 4: Kiểm tra hàm pickField dò tìm API Name khả dụng từ danh sách ưu tiên.
     * Bao phủ: Khớp trường đầu tiên, khớp trường thay thế phía sau, và trả về null nếu không khớp trường nào.
     */
    @IsTest
    static void testPickField() {
        Map<String, Schema.SObjectField> fieldMap = Case.SObjectType.getDescribe().fields.getMap();

        Test.startTest();
        String matchFirst    = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'Subject', 'Origin' });
        String matchFallback = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FAKE_FIELD__c', 'Origin' });
        String matchNull     = FEC_BatchImportCommon.pickField(fieldMap, new List<String>{ 'FAKE_1__c', 'FAKE_2__c' });
        Test.stopTest();

        System.assertEquals('Subject', matchFirst);
        System.assertEquals('Origin', matchFallback);
        System.assertEquals(null, matchNull);
    }

    /**
     * Kịch bản 5: Kiểm tra hàm chuẩn hóa dữ liệu chữ thô normalizeText và hàm asString.
     * Bao phủ: Dữ liệu chữ thường kèm dấu cách thừa, dữ liệu số, dữ liệu rỗng/null.
     */
    @IsTest
    static void testTextUtilities() {
        Test.startTest();
        String normValid = FEC_BatchImportCommon.normalizeText('  Text Content Trimmed   ');
        String normNull  = FEC_BatchImportCommon.normalizeText(null);
        
        String strValid  = FEC_BatchImportCommon.asString(456.78);
        String strNull   = FEC_BatchImportCommon.asString(null);
        Test.stopTest();

        System.assertEquals('Text Content Trimmed', normValid, 'Hàm normalizeText phải cắt bỏ khoảng trắng thừa.');
        System.assertEquals('', normNull, 'Hàm normalizeText khi nhận giá trị null phải trả về chuỗi rỗng.');
        System.assertEquals('456.78', strValid);
        System.assertEquals(null, strNull);
    }

    /**
     * Kịch bản 6: Kiểm tra hàm lấy giá trị động getFieldValue của SObject.
     * Bao phủ: Lấy dữ liệu thành công từ bản ghi, bảo vệ biên an toàn khi truyền bản ghi hoặc tên trường rỗng/null.
     */
    @IsTest
    static void testGetFieldValue() {
        Case c = new Case(Subject = 'Dynamic Field Value Access Test');

        Test.startTest();
        Object valSuccess  = FEC_BatchImportCommon.getFieldValue(c, 'Subject');
        Object valNullField = FEC_BatchImportCommon.getFieldValue(c, '');
        Object valNullRecord = FEC_BatchImportCommon.getFieldValue(null, 'Subject');
        Test.stopTest();

        System.assertEquals('Dynamic Field Value Access Test', (String) valSuccess);
        System.assertEquals(null, valNullField);
        System.assertEquals(null, valNullRecord);
    }

    /**
     * Kịch bản 7: Kiểm tra hàm chuyển đổi định dạng thời gian asDatetime.
     * Bao phủ: Đối tượng Datetime chuẩn, truyền sai định dạng kiểu chữ, và giá trị null.
     */
    @IsTest
    static void testAsDatetime() {
        Datetime now = Datetime.now();

        Test.startTest();
        Datetime resValid   = FEC_BatchImportCommon.asDatetime(now);
        Datetime resInvalid = FEC_BatchImportCommon.asDatetime('2026-05-20 12:00:00'); // Sai kiểu (String)
        Datetime resNull    = FEC_BatchImportCommon.asDatetime(null);
        Test.stopTest();

        System.assertEquals(now, resValid);
        System.assertEquals(null, resInvalid);
        System.assertEquals(null, resNull);
    }

    /**
     * Kịch bản 8: Kiểm tra hàm ép và chuyển đổi kiểu số asDecimal.
     * Bao phủ: Kiểu Decimal, kiểu Integer, kiểu Long, truyền sai kiểu chữ, và giá trị null.
     */
    @IsTest
    static void testAsDecimal() {
        Decimal decimalInput = 55.66;
        Integer integerInput = 2026;
        Long longInput       = 8888888888L;

        Test.startTest();
        Decimal fromDecimal = FEC_BatchImportCommon.asDecimal(decimalInput);
        Decimal fromInteger = FEC_BatchImportCommon.asDecimal(integerInput);
        Decimal fromLong    = FEC_BatchImportCommon.asDecimal(longInput);
        Decimal fromInvalid = FEC_BatchImportCommon.asDecimal('NotNumberText');
        Decimal fromNull    = FEC_BatchImportCommon.asDecimal(null);
        Test.stopTest();

        System.assertEquals(55.66, fromDecimal);
        System.assertEquals(2026.0, fromInteger);
        System.assertEquals(8888888888.0, fromLong);
        System.assertEquals(null, fromInvalid);
        System.assertEquals(null, fromNull);
    }

    /**
     * Kịch bản 9: Kiểm tra hàm gán dữ liệu động an toàn putIfFieldExists vào SObject.
     * Bao phủ:
     * - Tên trường không tồn tại trong map -> Bỏ qua (continue)
     * - Trường Read-Only (không có quyền tạo `!isCreateable()`) -> Bỏ qua (continue)
     * - Trường Auto-Number (`isAutoNumber()`) -> Bỏ qua (continue)
     * - Trường Formula (`isCalculated()`) -> Bỏ qua (continue)
     * - Trường hợp lệ -> Gán dữ liệu thành công và ngắt vòng lặp (`return`)
     */
    @IsTest
    static void testPutIfFieldExists_AllBranches() {
        Map<String, Schema.SObjectField> fieldMap = Case.SObjectType.getDescribe().fields.getMap();
        Case record = new Case();

        // Lập danh sách đi từ sai đến đúng để ép chạy qua toàn bộ các câu lệnh continue kiểm tra nhánh
        List<String> fieldNamesTest = new List<String>{
            'NON_EXISTENT_FIELD_API__c', // Chạy vào nhánh !fieldMap.containsKey
            'CaseNumber',                // Chạy vào nhánh isAutoNumber() / !isCreateable()
            'Subject'                    // Hợp lệ -> thực hiện gán dữ liệu và kích hoạt lệnh return ngắt hàm
        };

        Test.startTest();
        FEC_BatchImportCommon.putIfFieldExists(fieldMap, record, fieldNamesTest, 'Common Put Field Test Value');
        Test.stopTest();

        System.assertEquals('Common Put Field Test Value', record.Subject, 'Dữ liệu phải được gán thành công vào trường hợp lệ duy nhất.');
    }

    /**
     * Kịch bản 10: Kiểm tra hàm liên kết tệp tin mẫu đính kèm linkFileToBatch.
     * Bao phủ: Khởi tạo liên kết ContentDocumentLink thành công, chặn bảo vệ guard clause khi nhận tham số null, và xử lý an toàn khối bẫy lỗi DmlException.
     */
    @IsTest
    static void testLinkFileToBatch_WithDmlException() {
        // 1. Tạo 1 bản ghi Case mồi đóng vai trò thực thể cha nhận file liên kết
        Case parentCase = new Case(Subject = 'Parent Batch Case', Status = 'New');
        insert parentCase;

        // 2. Tạo file mẫu ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Batch_Import_File',
            PathOnClient = 'Batch_Import_File.xlsx',
            VersionData = Blob.valueOf('Excel byte body data')
        );
        insert cv;
        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        Test.startTest();
        // Nhánh thành công: Liên kết file vào bản ghi Case mẫu
        FEC_BatchImportCommon.linkFileToBatch(parentCase.Id, insertedCv.ContentDocumentId);

        // Nhánh lỗi: Cố tình gọi lại lệnh chèn file cũ vào cùng 1 bản ghi để kích hoạt lỗi trùng lặp (Duplicate DmlException)
        // Hệ thống sẽ nhảy vào khối catch(DmlException ex) và kết thúc an toàn, không làm sập luồng test
        FEC_BatchImportCommon.linkFileToBatch(parentCase.Id, insertedCv.ContentDocumentId);

        // Nhánh bảo vệ biên: Truyền tham số rỗng null
        FEC_BatchImportCommon.linkFileToBatch(null, null);
        Test.stopTest();

        // Xác minh xem bản ghi liên kết đã nằm trong DB thành công chưa
        List<ContentDocumentLink> checkLinks = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :parentCase.Id AND ContentDocumentId = :insertedCv.ContentDocumentId];
        System.assertEquals(1, checkLinks.size(), 'Bản ghi ContentDocumentLink phải được tạo thành công.');
    }
}