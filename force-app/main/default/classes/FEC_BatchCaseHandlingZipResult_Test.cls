@IsTest
private class FEC_BatchCaseHandlingZipResult_Test {

    /**
     * Kịch bản 1: Kiểm tra việc khởi tạo đối tượng, gán giá trị và đọc lại tất cả các trường dữ liệu.
     * Mong đợi: Toàn bộ các thuộc tính AuraEnabled hoạt động bình thường, lưu trữ và trả về đúng giá trị.
     */
    @IsTest
    static void testZipResult_PropertiesAssignment_Success() {
        // 1. Khởi tạo thực thể lớp bọc dữ liệu Zip Result
        FEC_BatchCaseHandlingZipResult zipResult = new FEC_BatchCaseHandlingZipResult();

        Test.startTest();
        // 2. Thực hiện gán dữ liệu mẫu cho toàn bộ các trường thành viên
        zipResult.success     = true;
        zipResult.message     = 'Quá trình nén tập tin đính kèm hàng loạt hoàn tất thành công.';
        zipResult.downloadUrl = '/sfc/servlet.shepherd/version/download/068xxxxxxxxxxxxAAA';
        zipResult.fileName    = 'Batch_Attachments_20260519.zip';
        Test.stopTest();

        // 3. Sử dụng các câu lệnh khẳng định (Assert) để kiểm tra tính chính xác của dữ liệu trong RAM
        System.assertEquals(true, zipResult.success, 'Trường success phải trả về đúng giá trị boolean đã gán.');
        System.assertEquals('Quá trình nén tập tin đính kèm hàng loạt hoàn tất thành công.', zipResult.message, 'Trường message phải lưu đúng chuỗi thông báo.');
        System.assertEquals('/sfc/servlet.shepherd/version/download/068xxxxxxxxxxxxAAA', zipResult.downloadUrl, 'Trường downloadUrl phải giữ đúng đường dẫn tải file.');
        System.assertEquals('Batch_Attachments_20260519.zip', zipResult.fileName, 'Trường fileName phải hiển thị chính xác tên tệp tin nén.');
    }

    /**
     * Kịch bản 2: Kiểm tra trạng thái mặc định ban đầu của thực thể khi vừa mới khởi tạo (Edge Case).
     * Mong đợi: Ngoại trừ kiểu dữ liệu nguyên thủy Boolean (mặc định là null trong Apex nếu không gán), tất cả các trường khác phải bằng null.
     */
    @IsTest
    static void testZipResult_EmptyInstance_ReturnsNull() {
        Test.startTest();
        FEC_BatchCaseHandlingZipResult emptyResult = new FEC_BatchCaseHandlingZipResult();
        Test.stopTest();

        // Xác minh trạng thái rỗng ban đầu để đảm bảo tính an toàn hệ thống (Guard Clause)
        System.assertEquals(null, emptyResult.success, 'Mặc định thuộc tính kiểu Boolean chưa gán phải là null.');
        System.assertEquals(null, emptyResult.message, 'Mặc định thuộc tính kiểu String chưa gán phải là null.');
        System.assertEquals(null, emptyResult.downloadUrl, 'Mặc định thuộc tính kiểu String chưa gán phải là null.');
        System.assertEquals(null, emptyResult.fileName, 'Mặc định thuộc tính kiểu String chưa gán phải là null.');
    }
}