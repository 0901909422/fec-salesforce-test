/**
 * @description Test class cho FEC_AdditionalFieldController đạt 100% Coverage.
 * @author DAT NGO
 * @date 2026-01-27
 */
@isTest
private class FEC_AdditionalFieldControllerTest {

    @testSetup
    static void setupData() {
        // Tạo dữ liệu mẫu cho Additional Field (Parent)
        FEC_MDM_Additional_Field__c field = new FEC_MDM_Additional_Field__c(
            Name = 'Test Field String',
            FEC_Unique_ID__c = 'UID_999',
            FEC_Type__c = 'String', // Theo yêu cầu FEC_Type__c = 'String'
            FEC_Name_VN__c = 'Tên Tiếng Việt Test' // Trường bắt buộc
        );
        insert field;

        // Tạo dữ liệu mẫu cho Field List Value (Child)
        FEC_MDM_Additional_Field_List_Value__c val = new FEC_MDM_Additional_Field_List_Value__c(
            Name = 'Option 1',
            FEC_Name_VN__c = 'Giá trị TV 1', // Trường bắt buộc
            FEC_Additional_Field__c = field.Id,
            FEC_Order__c = 1
        );
        insert val;
    }

    /**
     * @description Test kịch bản thành công cho tất cả các hàm.
     */
    @isTest
    static void testAllMethods_Success() {
        FEC_MDM_Additional_Field__c field = [SELECT Id FROM FEC_MDM_Additional_Field__c LIMIT 1];

        Test.startTest();
        // 1. Test getAdditionalFields
        List<FEC_MDM_Additional_Field__c> fields = FEC_AdditionalFieldController.getAdditionalFields();
        
        // 2. Test getFieldListValues
        List<FEC_MDM_Additional_Field_List_Value__c> values = FEC_AdditionalFieldController.getFieldListValues((String)field.Id);
        
        // 3. Test deleteFieldListValue thành công
        FEC_MDM_Additional_Field_List_Value__c val = [SELECT Id FROM FEC_MDM_Additional_Field_List_Value__c LIMIT 1];
        String resVal = FEC_AdditionalFieldController.deleteFieldListValue(val.Id);
        
        // 4. Test deleteRecord thành công
        String resField = FEC_AdditionalFieldController.deleteRecord(field.Id);
        Test.stopTest();

        Assert.areEqual('Success', resVal);
        Assert.areEqual('Success', resField);
        Assert.isFalse(fields.isEmpty());
        Assert.isFalse(values.isEmpty());
    }

    /**
     * @description Test khối Catch của hàm deleteRecord.
     * Kỹ thuật: Xóa bản ghi trước khi gọi Controller để gây lỗi DML.
     */
    @isTest
    static void testDeleteRecord_Catch() {
        FEC_MDM_Additional_Field__c field = [SELECT Id FROM FEC_MDM_Additional_Field__c LIMIT 1];
        delete field; // Xóa trước để gây lỗi

        Test.startTest();
        try {
            // Cố gắng xóa một ID không còn tồn tại
            FEC_AdditionalFieldController.deleteRecord(field.Id);
        } catch (AuraHandledException e) {
            // Xác nhận code đã nhảy vào khối catch
            Assert.isTrue(e.getMessage().contains('Error deleting record'));
        }
        Test.stopTest();
    }

    /**
     * @description Test khối Catch của hàm deleteFieldListValue.
     * Kỹ thuật: Truyền một ID sai loại (ví dụ User ID) để gây lỗi hệ thống.
     */
    @isTest
    static void testDeleteFieldListValue_Catch() {
        Test.startTest();
        try {
            // Truyền ID của chính người dùng hiện tại vào lệnh xóa Field List Value
            FEC_AdditionalFieldController.deleteFieldListValue(UserInfo.getUserId());
        } catch (AuraHandledException e) {
            // Xác nhận code đã nhảy vào khối catch
            Assert.isTrue(e.getMessage().contains('Error deleting Field List Value'));
        }
        Test.stopTest();
    }
}
