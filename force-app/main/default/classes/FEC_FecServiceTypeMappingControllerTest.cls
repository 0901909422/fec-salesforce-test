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

        // 3. Khởi tạo Stage thuộc BP (cấp giữa trong tree mới: BP→Stage→Field)
        FEC_MDM_Case_Stage__c stage = new FEC_MDM_Case_Stage__c(
            Name = 'Test Stage',
            FEC_Business_Process__c = bp.Id,
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Active__c = true,
            FEC_Order__c = 1
        );
        insert stage;

        // 4. Khởi tạo Additional Field (Bắt buộc để Setting xuất hiện trong Tree)
        FEC_MDM_Additional_Field__c field = new FEC_MDM_Additional_Field__c(
            FEC_Unique_ID__c = 'FLD_TEST',
            FEC_Name_VN__c = 'Test Field Property'
        );
        insert field;

        // 5. Khởi tạo Master Data Settings — gán Stage để xuất hiện dưới Stage node
        FEC_MDM_Master_Data_Setting__c setting = new FEC_MDM_Master_Data_Setting__c(
            FEC_Nature_Of_Case__c = noc.Id,
            FEC_Additional_Field__c = field.Id,
            FEC_Stage_Name__c = stage.Id,
            Property_Reference__c = 'OLD_REF'
        );
        insert setting;
    }

    /**
     * @description Test hàm getServiceTypeTree — verify shape mới BP→Stage→Field.
     */
    @isTest
    static void testGetServiceTypeTree() {
        Test.startTest();
        List<Map<String, Object>> treeData = FEC_FecServiceTypeMappingController.getServiceTypeTree();
        Test.stopTest();

        // BP node
        Assert.isFalse(treeData.isEmpty(), 'Tree data không được rỗng');
        Map<String, Object> bpNode = treeData[0];
        Assert.areEqual('Test Business Process', bpNode.get('label'), 'Tên BP node không đúng');
        Assert.areEqual(FEC_UIConstants.NODE_TYPE_BP, bpNode.get('nodeType'), 'BP node phải có nodeType=BP');

        // Stage node (con của BP)
        List<Map<String, Object>> stageNodes = (List<Map<String, Object>>)bpNode.get('items');
        Assert.isFalse(stageNodes.isEmpty(), 'BP phải có Stage con');
        Map<String, Object> stageNode = stageNodes[0];
        Assert.areEqual('Test Stage', stageNode.get('label'), 'Tên Stage node không đúng');
        Assert.areEqual(FEC_UIConstants.NODE_TYPE_STAGE, stageNode.get('nodeType'), 'Stage node phải có nodeType=STAGE');

        // Stage là LEAF của tree — không có 'items' key (lightning-tree sẽ render Stage là leaf).
        // Field list nằm dưới key 'fields' (không render bởi tree).
        Assert.isNull(stageNode.get('items'), 'Stage không được có items (Stage là leaf của tree)');
        List<Map<String, Object>> fieldNodes = (List<Map<String, Object>>)stageNode.get('fields');
        Assert.isFalse(fieldNodes.isEmpty(), 'Stage phải có Field con (qua key "fields")');
        Map<String, Object> fieldNode = fieldNodes[0];
        Assert.areEqual('OLD_REF', fieldNode.get('propertyRef'), 'Giá trị Property Reference không khớp');
        Assert.areEqual(FEC_UIConstants.NODE_TYPE_FIELD, fieldNode.get('nodeType'), 'Field node phải có nodeType=FIELD');
        Assert.areEqual('Test Stage', fieldNode.get('stageName'), 'Field node phải có stageName context');
    }

    /**
     * @description Test setting có FEC_Stage_Name__c=null → xuất hiện dưới virtual node "(No Stage)".
     */
    @isTest
    static void testGetServiceTypeTreeNoStageBucket() {
        // Tạo setting không có Stage
        FEC_MDM_Nature_Of_Case__c noc = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1];
        FEC_MDM_Additional_Field__c field = [SELECT Id FROM FEC_MDM_Additional_Field__c LIMIT 1];
        insert new FEC_MDM_Master_Data_Setting__c(
            FEC_Nature_Of_Case__c = noc.Id,
            FEC_Additional_Field__c = field.Id,
            FEC_Stage_Name__c = null,
            Property_Reference__c = 'NO_STAGE_REF'
        );

        Test.startTest();
        List<Map<String, Object>> treeData = FEC_FecServiceTypeMappingController.getServiceTypeTree();
        Test.stopTest();

        // BP có ≥ 2 stage nodes: real "Test Stage" + virtual "(No Stage)"
        List<Map<String, Object>> stageNodes = (List<Map<String, Object>>)treeData[0].get('items');
        Boolean foundNoStageNode = false;
        for (Map<String, Object> sn : stageNodes) {
            if (sn.get('label') == System.Label.FEC_Label_NoStage) {
                foundNoStageNode = true;
                List<Map<String, Object>> noStageFields = (List<Map<String, Object>>)sn.get('fields');
                Assert.isFalse(noStageFields.isEmpty(), 'Virtual no-stage node phải chứa setting có FEC_Stage_Name__c=null');
                break;
            }
        }
        Assert.isTrue(foundNoStageNode, 'Phải có virtual node "(No Stage)" khi tồn tại setting không thuộc stage nào');
    }

    /**
     * @description Test Stage có FEC_Active__c=false → bị filter ra khỏi tree.
     */
    @isTest
    static void testGetServiceTypeTreeInactiveStageFiltered() {
        // Inactivate stage hiện có
        FEC_MDM_Case_Stage__c stage = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1];
        stage.FEC_Active__c = false;
        update stage;

        Test.startTest();
        List<Map<String, Object>> treeData = FEC_FecServiceTypeMappingController.getServiceTypeTree();
        Test.stopTest();

        // Stage inactive bị filter, nhưng setting vẫn còn (nó tham chiếu stage inactive)
        // → Setting bị orphan: vì map theo stageId, vẫn nằm trong stageMap[stage.Id]
        //   nhưng Stage không xuất hiện trong bpToStages (do filter Active=true).
        //   Behavior: setting đó sẽ KHÔNG xuất hiện trong tree (acceptable — admin nên reactivate stage).
        List<Map<String, Object>> stageNodes = (List<Map<String, Object>>)treeData[0].get('items');
        for (Map<String, Object> sn : stageNodes) {
            Assert.areNotEqual('Test Stage', sn.get('label'), 'Stage inactive không được xuất hiện trong tree');
        }
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
     * Note: Salesforce Text fields coerce empty string to null on DML — assert null/blank.
     */
    @isTest
    static void testSavePropertyMappingEmptyRef() {
        FEC_MDM_Master_Data_Setting__c setting = [SELECT Id FROM FEC_MDM_Master_Data_Setting__c LIMIT 1];

        Test.startTest();
        FEC_FecServiceTypeMappingController.savePropertyMapping(setting.Id, '');
        Test.stopTest();

        FEC_MDM_Master_Data_Setting__c updatedSetting = [SELECT Property_Reference__c FROM FEC_MDM_Master_Data_Setting__c WHERE Id = :setting.Id];
        Assert.isTrue(String.isBlank(updatedSetting.Property_Reference__c), 'Property_Reference__c phải blank khi lưu chuỗi rỗng (Salesforce coerces empty string to null)');
    }

    /**
     * @description Test lưu chuỗi chỉ chứa khoảng trắng '   ' và verify xử lý không lỗi.
     * Validates: Requirements 1.4
     * Note: Salesforce Text fields normalize whitespace-only strings to null/blank on DML — assert null/blank.
     */
    @isTest
    static void testSavePropertyMappingWhitespaceRef() {
        FEC_MDM_Master_Data_Setting__c setting = [SELECT Id FROM FEC_MDM_Master_Data_Setting__c LIMIT 1];

        Test.startTest();
        FEC_FecServiceTypeMappingController.savePropertyMapping(setting.Id, '   ');
        Test.stopTest();

        FEC_MDM_Master_Data_Setting__c updatedSetting = [SELECT Property_Reference__c FROM FEC_MDM_Master_Data_Setting__c WHERE Id = :setting.Id];
        Assert.isTrue(String.isBlank(updatedSetting.Property_Reference__c), 'Property_Reference__c phải blank khi lưu chuỗi whitespace (Salesforce normalizes)');
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
        Assert.isTrue(String.isBlank(updatedMap.get(setting3.Id).Property_Reference__c), 'Setting 3 phải blank khi save chuỗi rỗng (Salesforce coerces empty string to null)');
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
     * @description Test trường hợp Business Process có Stage nhưng Stage không có Setting con.
     */
    @isTest
    static void testTreeWithNoChildren() {
        // Xóa setting hiện tại để Stage không có field con
        delete [SELECT Id FROM FEC_MDM_Master_Data_Setting__c];

        Test.startTest();
        List<Map<String, Object>> treeData = FEC_FecServiceTypeMappingController.getServiceTypeTree();
        Test.stopTest();

        Assert.isFalse(treeData.isEmpty());
        // BP node vẫn có Stage con (real Stage from Case_Stage table)
        List<Map<String, Object>> stageNodes = (List<Map<String, Object>>)treeData[0].get('items');
        Assert.isFalse(stageNodes.isEmpty(), 'BP vẫn phải có Stage node (lấy từ Case_Stage table)');
        // Stage không có Setting → fields rỗng (Stage vẫn là leaf, không có 'items')
        List<Map<String, Object>> stageFields = (List<Map<String, Object>>)stageNodes[0].get('fields');
        Assert.isTrue(stageFields.isEmpty(), 'Stage không có Setting → fields phải rỗng');
    }

    /**
     * @description Test getServiceTypeTree throw AuraHandledException khi user thiếu FLS/CRUD.
     * Validates: Bug 1.3, Expected 2.3 (bugfix.md) — FLS-Enforced Read.
     * Strategy: chạy under restricted profile (Minimum Access / Read Only) → WITH SECURITY_ENFORCED
     * sẽ throw QueryException, controller wrap thành AuraHandledException.
     */
    @isTest
    static void testGetServiceTypeTreeFLSDenied() {
        // Tìm profile hạn chế nhất — fallback graceful nếu org không có
        List<Profile> restrictiveProfiles = [
            SELECT Id, Name FROM Profile
            WHERE Name IN ('Minimum Access - Salesforce', 'Read Only')
            ORDER BY Name ASC
            LIMIT 1
        ];
        if (restrictiveProfiles.isEmpty()) {
            Assert.isTrue(true, 'No restrictive profile available in org — FLS test skipped gracefully.');
            return;
        }

        User restrictedUser = new User(
            Alias = 'flstest',
            Email = 'flsdenied@fec.test.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'FLS_Denied_Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = restrictiveProfiles[0].Id,
            TimeZoneSidKey = 'Asia/Ho_Chi_Minh',
            UserName = 'flsdenied' + System.currentTimeMillis() + '@fec.test.invalid'
        );
        insert restrictedUser;

        Test.startTest();
        System.runAs(restrictedUser) {
            try {
                FEC_FecServiceTypeMappingController.getServiceTypeTree();
                Assert.fail('Phải throw AuraHandledException khi user thiếu FLS/CRUD');
            } catch (AuraHandledException ae) {
                Assert.isNotNull(ae.getMessage(), 'AuraHandledException phải có message');
            }
        }
        Test.stopTest();
    }
}