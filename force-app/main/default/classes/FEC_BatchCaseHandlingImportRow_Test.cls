@IsTest
private class FEC_BatchCaseHandlingImportRow_Test {

    /**
     * Kịch bản 1: Kiểm tra việc khởi tạo đối tượng và gán/đọc dữ liệu cho tất cả các trường.
     * Mong đợi: Toàn bộ các thuộc tính AuraEnabled hoạt động bình thường, lưu và trả về đúng giá trị.
     */
    @IsTest
    static void testImportRow_PropertiesAssignment_Success() {
        // 1. Khởi tạo đối tượng Wrapper mẫu
        FEC_BatchCaseHandlingImportRow importRow = new FEC_BatchCaseHandlingImportRow();

        Test.startTest();
        // 2. Tiến hành gán dữ liệu trực tiếp vào toàn bộ các thuộc tính của Class
        importRow.caseIdSearch            = 'SRCH-2026-001';
        importRow.routingAction           = 'Approve';
        importRow.inputtedRemarks         = 'Lô dữ liệu xử lý hàng loạt đạt yêu cầu.';
        importRow.assignmentId            = '005000000000001AAA';
        importRow.assignmentRoutingAction = 'Forward to COF Team';
        importRow.recordId                = '500000000000002BBB';
        importRow.status                  = 'Succeeded';
        importRow.errors                  = '';
        Test.stopTest();

        // 3. Thực hiện Assert đối chiếu để khẳng định giá trị đọc ra khớp 100% với giá trị gán vào
        System.assertEquals('SRCH-2026-001', importRow.caseIdSearch, 'Trường caseIdSearch phải lưu đúng giá trị.');
        System.assertEquals('Approve', importRow.routingAction, 'Trường routingAction phải lưu đúng giá trị.');
        System.assertEquals('Lô dữ liệu xử lý hàng loạt đạt yêu cầu.', importRow.inputtedRemarks, 'Trường inputtedRemarks phải lưu đúng giá trị.');
        System.assertEquals('005000000000001AAA', importRow.assignmentId, 'Trường assignmentId phải lưu đúng giá trị.');
        System.assertEquals('Forward to COF Team', importRow.assignmentRoutingAction, 'Trường assignmentRoutingAction phải lưu đúng giá trị.');
        System.assertEquals('500000000000002BBB', importRow.recordId, 'Trường recordId phải lưu đúng giá trị.');
        System.assertEquals('Succeeded', importRow.status, 'Trường status phải lưu đúng giá trị.');
        System.assertEquals('', importRow.errors, 'Trường errors phải lưu đúng giá trị.');
    }

    /**
     * Kịch bản 2: Kiểm tra trạng thái biên khi đối tượng mới khởi tạo và chưa gán dữ liệu.
     * Mong đợi: Tất cả các thuộc tính phải mang giá trị mặc địnhban đầu là null.
     */
    @IsTest
    static void testImportRow_EmptyInstance_ReturnsNull() {
        Test.startTest();
        FEC_BatchCaseHandlingImportRow emptyRow = new FEC_BatchCaseHandlingImportRow();
        Test.stopTest();

        // Xác minh trạng thái ban đầu của một thực thể rỗng
        System.assertEquals(null, emptyRow.caseIdSearch, 'Mặc định ban đầu trường dữ liệu phải mang giá trị null.');
        System.assertEquals(null, emptyRow.routingAction, 'Mặc định ban đầu trường dữ liệu phải mang giá trị null.');
        System.assertEquals(null, emptyRow.inputtedRemarks, 'Mặc định ban đầu trường dữ liệu phải mang giá trị null.');
        System.assertEquals(null, emptyRow.assignmentId, 'Mặc định ban đầu trường dữ liệu phải mang giá trị null.');
        System.assertEquals(null, emptyRow.assignmentRoutingAction, 'Mặc định ban đầu trường dữ liệu phải mang giá trị null.');
        System.assertEquals(null, emptyRow.recordId, 'Mặc định ban đầu trường dữ liệu phải mang giá trị null.');
        System.assertEquals(null, emptyRow.status, 'Mặc định ban đầu trường dữ liệu phải mang giá trị null.');
        System.assertEquals(null, emptyRow.errors, 'Mặc định ban đầu trường dữ liệu phải mang giá trị null.');
    }
}