/**
 * @description Test class cho FEC_FecServiceTypeMappingController.
 * Bao phủ logic tạo Tree Data phân cấp và cập nhật Mapping.
 * @author DAT NGO
 * @date 2026-01-27
 */
@isTest
private class FEC_FecServiceTypeMappingControllerTest {

    @testSetup
    static void setup() {
        // 1. Khởi tạo Business Process (Cấp cha trong Tree)
        FEC_MDM_Business_Process__c bp = new FEC_MDM_Business_Process__c(
            Name = 'Test Business Process',
            FEC_Code__c = 'BP001'
        );
        insert bp;

        // 2. Khởi tạo Nature of Case liên kết với BP
        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(
            FEC_Business_Process__c = bp.Id
        );
        insert noc;

        // 3. Khởi tạo Additional Field (Bắt buộc để Setting xuất hiện trong Tree)
        FEC_MDM_Additional_Field__c field = new FEC_MDM_Additional_Field__c(
            FEC_Unique_ID__c = 'FLD_TEST',
            FEC_Name_VN__c = 'Test Field Property'
        );
        insert field;

        // 4. Khởi tạo Master Data Settings (Cấp con trong Tree)
        FEC_MDM_Master_Data_Setting__c setting = new FEC_MDM_Master_Data_Setting__c(
            FEC_Nature_Of_Case__c = noc.Id,
            FEC_Additional_Field__c = field.Id,
            Property_Reference__c = 'OLD_REF'
        );
        insert setting;
    }

    /**
     * @description Test hàm getServiceTypeTree để đảm bảo dữ liệu cây được xây dựng đúng.
     */
    @isTest
    static void testGetServiceTypeTree() {
        Test.startTest();
        // Gọi hàm lấy cấu trúc cây
        List<Map<String, Object>> treeData = FEC_FecServiceTypeMappingController.getServiceTypeTree();
        Test.stopTest();

        // Kiểm tra kết quả
        Assert.isFalse(treeData.isEmpty(), 'Tree data không được rỗng');
        
        Map<String, Object> parentNode = treeData[0];
        Assert.areEqual('Test Business Process', parentNode.get('label'), 'Tên cấp cha không đúng');
        
        List<Map<String, Object>> children = (List<Map<String, Object>>)parentNode.get('items');
        Assert.isFalse(children.isEmpty(), 'Business Process phải có items con');
        Assert.areEqual('OLD_REF', children[0].get('propertyRef'), 'Giá trị Property Reference không khớp');
    }

    /**
     * @description Test logic lưu cập nhật Property Mapping.
     */
    @isTest
    static void testSavePropertyMapping() {
        FEC_MDM_Master_Data_Setting__c setting = [SELECT Id FROM FEC_MDM_Master_Data_Setting__c LIMIT 1];
        String newReferenceValue = 'NEW_REF_V1';

        Test.startTest();
        // Thực hiện cập nhật
        FEC_FecServiceTypeMappingController.savePropertyMapping(setting.Id, newReferenceValue);
        Test.stopTest();

        // Kiểm tra dữ liệu sau khi cập nhật
        FEC_MDM_Master_Data_Setting__c updatedSetting = [SELECT Property_Reference__c FROM FEC_MDM_Master_Data_Setting__c WHERE Id = :setting.Id];
        Assert.areEqual(newReferenceValue, updatedSetting.Property_Reference__c, 'Giá trị Mapping không được cập nhật đúng');
    }

    /**
     * @description Test lưu chuỗi rỗng '' để xóa Property Reference.
     * Validates: Requirements 1.4
     */
    @isTest
    static void testSavePropertyMappingEmptyRef() {
        FEC_MDM_Master_Data_Setting__c setting = [SELECT Id FROM FEC_MDM_Master_Data_Setting__c LIMIT 1];

        Test.startTest();
        FEC_FecServiceTypeMappingController.savePropertyMapping(setting.Id, '');
        Test.stopTest();

        FEC_MDM_Master_Data_Setting__c updatedSetting = [SELECT Property_Reference__c FROM FEC_MDM_Master_Data_Setting__c WHERE Id = :setting.Id];
        Assert.areEqual('', updatedSetting.Property_Reference__c, 'Property_Reference__c phải được cập nhật thành chuỗi rỗng');
    }

    /**
     * @description Test lưu chuỗi chỉ chứa khoảng trắng '   ' và verify giá trị được lưu đúng.
     * Validates: Requirements 1.4
     */
    @isTest
    static void testSavePropertyMappingWhitespaceRef() {
        FEC_MDM_Master_Data_Setting__c setting = [SELECT Id FROM FEC_MDM_Master_Data_Setting__c LIMIT 1];

        Test.startTest();
        FEC_FecServiceTypeMappingController.savePropertyMapping(setting.Id, '   ');
        Test.stopTest();

        FEC_MDM_Master_Data_Setting__c updatedSetting = [SELECT Property_Reference__c FROM FEC_MDM_Master_Data_Setting__c WHERE Id = :setting.Id];
        Assert.areEqual('   ', updatedSetting.Property_Reference__c, 'Property_Reference__c phải được cập nhật thành chuỗi chỉ chứa khoảng trắng');
    }

    /**
     * @description Test kịch bản lỗi để bao phủ khối catch.
     */
    @isTest
    static void testSavePropertyMappingException() {
        Test.startTest();
        try {
            // Truyền ID không hợp lệ để gây ra lỗi
            FEC_FecServiceTypeMappingController.savePropertyMapping(null, 'SOME_REF');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Phải bắn ra lỗi AuraHandledException');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test bulk save nhiều record cùng lúc và verify tất cả Property_Reference__c được cập nhật đúng.
     * Validates: Requirements 1.4
     */
    @isTest
    static void testSavePropertyMappingsBulk() {
        // Lấy setting có sẵn từ testSetup
        FEC_MDM_Master_Data_Setting__c existingSetting = [SELECT Id FROM FEC_MDM_Master_Data_Setting__c LIMIT 1];

        // Tạo thêm settings cho bulk test
        FEC_MDM_Nature_Of_Case__c noc = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1];
        FEC_MDM_Additional_Field__c field = [SELECT Id FROM FEC_MDM_Additional_Field__c LIMIT 1];

        FEC_MDM_Master_Data_Setting__c setting2 = new FEC_MDM_Master_Data_Setting__c(
            FEC_Nature_Of_Case__c = noc.Id,
            FEC_Additional_Field__c = field.Id,
            Property_Reference__c = 'OLD_REF_2'
        );
        FEC_MDM_Master_Data_Setting__c setting3 = new FEC_MDM_Master_Data_Setting__c(
            FEC_Nature_Of_Case__c = noc.Id,
            FEC_Additional_Field__c = field.Id,
            Property_Reference__c = 'OLD_REF_3'
        );
        insert new List<FEC_MDM_Master_Data_Setting__c>{ setting2, setting3 };

        // Build JSON payload
        String mappingsJson = '[' +
            '{"settingId":"' + existingSetting.Id + '","newRef":".piID"},' +
            '{"settingId":"' + setting2.Id + '","newRef":".CaseNumber"},' +
            '{"settingId":"' + setting3.Id + '","newRef":""}' +
        ']';

        Test.startTest();
        FEC_FecServiceTypeMappingController.savePropertyMappings(mappingsJson);
        Test.stopTest();

        // Verify tất cả record được cập nhật đúng
        Map<Id, FEC_MDM_Master_Data_Setting__c> updatedMap = new Map<Id, FEC_MDM_Master_Data_Setting__c>(
            [SELECT Id, Property_Reference__c FROM FEC_MDM_Master_Data_Setting__c
             WHERE Id IN (:existingSetting.Id, :setting2.Id, :setting3.Id)]
        );
        Assert.areEqual('.piID', updatedMap.get(existingSetting.Id).Property_Reference__c, 'Setting 1 phải được cập nhật thành .piID');
        Assert.areEqual('.CaseNumber', updatedMap.get(setting2.Id).Property_Reference__c, 'Setting 2 phải được cập nhật thành .CaseNumber');
        Assert.areEqual('', updatedMap.get(setting3.Id).Property_Reference__c, 'Setting 3 phải được cập nhật thành chuỗi rỗng');
    }

    /**
     * @description Test truyền JSON không hợp lệ và verify throw AuraHandledException.
     */
    @isTest
    static void testSavePropertyMappingsInvalidJson() {
        Test.startTest();
        try {
            FEC_FecServiceTypeMappingController.savePropertyMappings('invalid json {{{');
            Assert.fail('Phải throw AuraHandledException khi JSON không hợp lệ');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Phải có message lỗi');
        }
        Test.stopTest();
    }

    /**
     * @description Test truyền danh sách rỗng và verify throw AuraHandledException.
     */
    @isTest
    static void testSavePropertyMappingsEmptyList() {
        Test.startTest();
        // Test null
        try {
            FEC_FecServiceTypeMappingController.savePropertyMappings(null);
            Assert.fail('Phải throw AuraHandledException khi mappingsJson là null');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Phải có message lỗi cho null input');
        }

        // Test empty string
        try {
            FEC_FecServiceTypeMappingController.savePropertyMappings('');
            Assert.fail('Phải throw AuraHandledException khi mappingsJson là chuỗi rỗng');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Phải có message lỗi cho chuỗi rỗng');
        }

        // Test empty array
        try {
            FEC_FecServiceTypeMappingController.savePropertyMappings('[]');
            Assert.fail('Phải throw AuraHandledException khi danh sách rỗng');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Phải có message lỗi cho danh sách rỗng');
        }
        Test.stopTest();
    }

    /**
     * @description Test trường hợp Business Process không có con (Empty items).
     */
    @isTest
    static void testTreeWithNoChildren() {
        // Xóa setting hiện tại để tạo kịch bản cha không có con
        delete [SELECT Id FROM FEC_MDM_Master_Data_Setting__c];

        Test.startTest();
        List<Map<String, Object>> treeData = FEC_FecServiceTypeMappingController.getServiceTypeTree();
        Test.stopTest();

        Assert.isFalse(treeData.isEmpty());
        List<Map<String, Object>> children = (List<Map<String, Object>>)treeData[0].get('items');
        Assert.isTrue(children.isEmpty(), 'Items phải rỗng khi không có setting tương ứng');
    }
}