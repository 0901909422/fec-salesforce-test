@IsTest
private class FEC_Constants_Test {

    @IsTest
    static void testConstantsIntegrity() {
        // 1. Kiểm tra việc khởi tạo class (Bao phủ hàm khởi tạo private)
        // Lưu ý: Đối với các class chỉ có private constructor, cách gọi này 
        // có thể cần sử dụng reflection hoặc đơn giản là để class được load vào bộ nhớ.
        // Cách tốt nhất là truy cập vào một hằng số để class được nạp.
        System.assertNotEquals(null, FEC_Constants.OBJ_PRODUCT_TYPE, 'Hằng số OBJ_PRODUCT_TYPE không được null');

        // 2. Kiểm tra các hằng số quan trọng (Xác thực sự tồn tại và tính đúng đắn)
        System.assertEquals('FEC_Product_Type__c', FEC_Constants.OBJ_PRODUCT_TYPE);
        System.assertEquals('ProductType', FEC_Constants.KEY_PRODUCT_TYPE);
        System.assertEquals('FEC_Alias__c', FEC_Constants.FIELD_ALIAS);
        
        // 3. Kiểm tra các Custom Label (Đảm bảo không bị trống)
        // Việc check String.isNotBlank giúp đảm bảo Label đã được định nghĩa trong Org
        System.assert(String.isNotBlank(FEC_Constants.OPERATION_SUCCESS), 'Custom Label OPERATION_SUCCESS không được trống');
    }

    @IsTest
    static void testTestFlag() {
        // Kiểm tra biến @TestVisible
        FEC_Constants.forceException = true;
        System.assertEquals(true, FEC_Constants.forceException);
        
        // Reset lại cho sạch
        FEC_Constants.forceException = false;
    }
}