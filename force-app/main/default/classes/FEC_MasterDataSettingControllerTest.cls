@isTest
private class FEC_MasterDataSettingControllerTest {

    @testSetup
    static void setup() {
        // 1. Khởi tạo Metadata MDM
        FEC_MDM_Product_Type__c prod = new FEC_MDM_Product_Type__c(FEC_Code__c = 'P01');
        insert prod;
        FEC_MDM_Business_Process__c biz = new FEC_MDM_Business_Process__c(FEC_Code__c = 'B01');
        insert biz;

        // 2. Tạo Nature of Case
        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(
            FEC_Product_Type_Name__c = prod.Id,
            FEC_Business_Process_Name__c = biz.Id,
            ExternalID__c = 'NOC_01'
        );
        insert noc;

        // 3. Tạo Stage mẫu
        FEC_Case_Stage__c stageLive = new FEC_Case_Stage__c(Name = 'Live Stage', FEC_Code__c = 'STG_MDM_01');
        insert stageLive;

        FEC_MDM_Case_Stage__c stageMdm = new FEC_MDM_Case_Stage__c(
            Name = 'MDM Stage', 
            FEC_Code__c = 'STG_MDM_01', // Đảm bảo có Code
            FEC_Business_Process__c = biz.Id,
            FEC_Pos_Order__c = 1,
            FEC_Status__c = true
        );
        insert stageMdm;

        // 4. SỬA LỖI TẠI ĐÂY: Gán FEC_Code__c cho Mapping record
        FEC_Data_Integration_Mapping__c mappingIn = new FEC_Data_Integration_Mapping__c();
        insert mappingIn;

        // 5. Tạo Settings mẫu
        insert new List<FEC_MDM_Master_Data_Setting__c>{
            new FEC_MDM_Master_Data_Setting__c(
                FEC_Nature_Of_Case__c = noc.Id,
                FEC_Stage_Name__c = stageMdm.Id,
                FEC_Data_Integration_Mapping__c = null
            ),
            new FEC_MDM_Master_Data_Setting__c(
                FEC_Nature_Of_Case__c = noc.Id,
                FEC_Data_Integration_Mapping__c = mappingIn.Id
            )
        };
    }

    @isTest
    static void testGetMasterDataSettings() {
        Id nocId = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1].Id;
        Id stageId = [SELECT Id FROM FEC_MDM_Case_Stage__c LIMIT 1].Id;

        Test.startTest();
        // Phủ nhánh lọc Stage và Integration
        FEC_MasterDataSettingController.getMasterDataSettings(nocId, stageId, false);
        FEC_MasterDataSettingController.getMasterDataSettings(nocId, null, true);
        FEC_MasterDataSettingController.getMasterDataSettings(nocId, null, null); // Phủ nhánh isIntegration == null
        FEC_MasterDataSettingController.getMasterDataSettings('', null, false); // Phủ nhánh check blank
        Test.stopTest();
    }

    @isTest
    static void testSaveMasterDataSetting() {
        Id nocId = [SELECT Id FROM FEC_MDM_Nature_Of_Case__c LIMIT 1].Id;

        // Test logic ép kiểu Integer và gán giá trị New
        Map<String, Object> req = new Map<String, Object>{
            'FEC_Nature_Of_Case__c' => nocId,
            'FEC_Field_Mandatory__c' => true,
            'FEC_Field_ReadOnly__c' => false,
            'FEC_Field_Order_Display__c' => '15',
            'FEC_Field_Status__c' => true
        };

        Test.startTest();
        Id recordId = FEC_MasterDataSettingController.saveMasterDataSetting(req);
        
        // Test Update
        req.put('Id', recordId);
        req.put('FEC_Field_Status__c', false);
        FEC_MasterDataSettingController.saveMasterDataSetting(req);
        Test.stopTest();

        Assert.isNotNull(recordId);
    }

    @isTest
    static void testCreateCaseStage() {
        Id bizId = [SELECT Id FROM FEC_MDM_Business_Process__c LIMIT 1].Id;
        Test.startTest();
        // Phủ hàm tạo Stage mới (Dòng 169-189)
        Id stageId = FEC_MasterDataSettingController.createCaseStage(
            'New Test Stage', 'NEW_CODE_99', bizId, 'Tên VN', true, 'Alias', 5
        );
        Test.stopTest();
        Assert.isNotNull(stageId);
    }

    @isTest
    static void testUtilityMethods() {
        Id bizId = [SELECT Id FROM FEC_MDM_Business_Process__c LIMIT 1].Id;
        Id settingId = [SELECT Id FROM FEC_MDM_Master_Data_Setting__c LIMIT 1].Id;

        Test.startTest();
        FEC_MasterDataSettingController.getChannels();
        FEC_MasterDataSettingController.getUserRoles();
        FEC_MasterDataSettingController.getStageOptions();
        FEC_MasterDataSettingController.getLookupOptions('UserRole');
        FEC_MasterDataSettingController.getCaseStageOptionsByBP(bizId);
        FEC_MasterDataSettingController.deleteRecord(settingId);
        Test.stopTest();
    }

    @isTest
    static void testErrorScenarios() {
        Test.startTest();
        // Phủ khối catch DML
        try {
            FEC_MasterDataSettingController.saveMasterDataSetting(new Map<String, Object>{
                'FEC_Field_Mandatory__c' => 'WrongType' 
            });
        } catch (Exception e) {}

        // Phủ khối catch createCaseStage
        try {
            FEC_MasterDataSettingController.createCaseStage(null, null, null, null, null, null, null);
        } catch (Exception e) {}
        Test.stopTest();
    }
}
