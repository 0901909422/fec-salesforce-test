@IsTest
private class FEC_BatchException_Test {

    /**
     * Kịch bản 1: Kiểm tra việc ném và bắt ngoại lệ với thông báo chuỗi văn bản (String Message).
     * Mong đợi: Khối catch bắt được đúng loại ngoại lệ và nội dung thông báo trùng khớp.
     */
    @IsTest
    static void testBatchException_WithMessage_Success() {
        String errMsg = 'Lỗi nghiêm trọng phát sinh trong quá trình xử lý lô dữ liệu hàng loạt.';
        Boolean isExceptionCaught = false;

        Test.startTest();
        try {
            // Chủ động ném ngoại lệ Custom để kiểm tra luồng bẫy lỗi
            throw new FEC_BatchException(errMsg);
        } catch (FEC_BatchException ex) {
            isExceptionCaught = true;
            System.assertEquals(errMsg, ex.getMessage(), 'Nội dung thông báo lỗi bên trong Exception phải trùng khớp.');
        } catch (Exception ex) {
            System.assert(false, 'Hệ thống ném sai loại Exception, kỳ vọng phải là FEC_BatchException.');
        }
        Test.stopTest();

        System.assertEquals(true, isExceptionCaught, 'Khối lệnh catch bắt ngoại lệ phải được kích hoạt.');
    }

    /**
     * Kịch bản 2: Kiểm tra việc ném ngoại lệ đi kèm nguyên nhân gốc từ một lỗi khác (Chaining Exception Cause).
     * Mong đợi: Ngoại lệ bọc ngoài giữ được vết thông tin lỗi của ngoại lệ gốc bên trong phục vụ truy vết log.
     */
    @IsTest
    static void testBatchException_WithCause_Success() {
        String rawDmlMessage = 'Insert failed. First exception on row 0; REQUIRED_FIELD_MISSING.';
        Boolean isExceptionCaught = false;

        Test.startTest();
        try {
            try {
                // 1. Giả lập phát sinh một lỗi hệ thống cơ sở dữ liệu hoặc lỗi tính toán thô ban đầu
                throw new CalloutException(rawDmlMessage);
            } catch (Exception causeEx) {
                // 2. Bọc lỗi gốc đó vào trong lớp ngoại lệ Custom FEC_BatchException của bạn
                throw new FEC_BatchException('Phát sinh sự cố tích hợp hệ thống.', causeEx);
            }
        } catch (FEC_BatchException ex) {
            isExceptionCaught = true;
            System.assertEquals('Phát sinh sự cố tích hợp hệ thống.', ex.getMessage());
            System.assert(ex.getCause() != null, 'Ngoại lệ Custom bắt được bắt buộc phải chứa vết của lỗi gốc.');
            System.assertEquals(rawDmlMessage, ex.getCause().getMessage(), 'Thông điệp lỗi gốc bên trong phải chính xác.');
        }
        Test.stopTest();

        System.assertEquals(true, isExceptionCaught, 'Hệ thống phải bắt được ngoại lệ dạng chuỗi liên kết lỗi.');
    }

    /**
     * Kịch bản 3: Kiểm tra hàm khởi tạo mặc định không tham số (No-Arg Constructor).
     * Mong đợi: Khởi tạo thực thể thành công mà không phát sinh crash hệ thống.
     */
    @IsTest
    static void testBatchException_NoArgConstructor_Success() {
        Test.startTest();
        FEC_BatchException emptyEx = new FEC_BatchException();
        Test.stopTest();

        System.assert(emptyEx != null, 'Hệ thống phải khởi tạo thành công thực thể lớp ngoại lệ mặc định.');
    }
}