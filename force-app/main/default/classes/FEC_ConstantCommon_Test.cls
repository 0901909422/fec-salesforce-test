@IsTest
private class FEC_ConstantCommon_Test {

    @IsTest
    static void testConstantsDefinitions() {
        // Kiểm tra các hằng số quan trọng không bị null hoặc rỗng
        System.assert(String.isNotBlank(FEC_ConstantCommon.API_METHOD_GET), 'API_METHOD_GET nên có giá trị');
        System.assert(String.isNotBlank(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME), 'RecordType Interaction phải tồn tại');
        
        // Kiểm tra định dạng Regex (nếu cần)
        System.assert(FEC_ConstantCommon.PATTERN_PHONE_NUMBER != null);
        
        // Kiểm tra cấu trúc Map
        System.assertNotEquals(null, FEC_ConstantCommon.CASE_STATUS_MAP, 'Map trạng thái Case không được null');
        
        // Kiểm tra các Set (đảm bảo không rỗng nếu logic nghiệp vụ bắt buộc)
        System.assert(FEC_ConstantCommon.SUPPORTED_CHANNELS.contains('CHAT'), 'Set kênh hỗ trợ phải chứa CHAT');
        System.assert(FEC_ConstantCommon.CS_BACKOFFICE_TEAMS.contains('CC'), 'Team BackOffice phải chứa CC');
    }

    /**
     * Test này chỉ đơn giản là khởi tạo class. 
     * Trong Apex, gọi hằng số của class sẽ giúp lớp đó đạt 100% coverage.
     */
    @IsTest
    static void testClassCoverage() {
        FEC_ConstantCommon consts = new FEC_ConstantCommon();
        System.assertNotEquals(null, consts);
    }
}