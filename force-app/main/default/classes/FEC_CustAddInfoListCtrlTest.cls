@isTest
private class FEC_CustAddInfoListCtrlTest {

    @testSetup
    static void setup() {
        // Tạo 1 Config đã Processed để test hàm getExistingConfigs
        FEC_CustomerAdditionalInfoConfig__c config = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_KeyIdentifier__c = 'OLD',
            FEC_FieldID__c = 'ID',
            FEC_Status__c = FEC_ConstantCommon.PROCESSED_STATUS
        );
        insert config;
    }

    @isTest
    static void testSaveController() {
        // Chuẩn bị data cho hàm Save
        FEC_CustomerAdditionalInfoConfig__c newConfig = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_KeyIdentifier__c = 'NEW', FEC_FieldID__c = 'PHONE'
        );
        
        FEC_FileInfo file = new FEC_FileInfo();
        file.name = 'TestFile';
        file.base64Data = EncodingUtil.base64Encode(Blob.valueOf('Fake Content'));
        file.sheetXml = '[["Header"],["Value"]]'; // Giả lập nội dung JSON cho file thứ 2
        
        Test.startTest();
        String res = FEC_CustomerAdditionalInfoListController.saveCustomerData(newConfig, new List<FEC_FileInfo>{file});
        Test.stopTest();
        
        System.assertEquals(FEC_ConstantCommon.SUCCESS_MESSAGE, res);
        
        // Kiểm tra xem file đã được tạo chưa
        FEC_CustomerAdditionalInfoConfig__c savedCfg = [SELECT Id FROM FEC_CustomerAdditionalInfoConfig__c WHERE FEC_KeyIdentifier__c = 'NEW' LIMIT 1];
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :savedCfg.Id];
        System.assert(links.size() > 0, 'File phải được đính kèm vào Config');
    }

    @isTest
    static void testGetAndDelete() {
        FEC_CustomerAdditionalInfoConfig__c cfg = [SELECT Id FROM FEC_CustomerAdditionalInfoConfig__c LIMIT 1];
        
        // Test các hàm Get
        System.assertNotEquals(null, FEC_CustomerAdditionalInfoListController.getExistingConfigs());
        System.assertNotEquals(null, FEC_CustomerAdditionalInfoListController.getUploadedConfigs());
        System.assertNotEquals(null, FEC_CustomerAdditionalInfoListController.getConfigHistory(cfg.Id));
        
        // Test Check Duplicate
        Boolean isDup = FEC_CustomerAdditionalInfoListController.checkDuplicateConfig('OLD', 'ID', null);
        System.assertEquals(true, isDup);
        
        // Test Delete File
        ContentVersion cv = new ContentVersion(
            Title = 'TestDelete', PathOnClient = 'Test.txt', VersionData = Blob.valueOf('A'), FirstPublishLocationId = cfg.Id
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        
        Test.startTest();
        FEC_CustomerAdditionalInfoListController.deleteFile(docId);
        Test.stopTest();
        
        List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE Id = :docId];
        System.assertEquals(0, docs.size(), 'File phải bị xóa');
    }
    
    @isTest
    static void testException() {
        // Test trường hợp lỗi
        Boolean caught = false;
        try {
            FEC_CustomerAdditionalInfoListController.saveCustomerData(null, null);
        } catch(Exception e) { caught = true; }
        System.assert(caught, 'Phải bắt được lỗi');
    }

    @isTest
    static void testGetRelatedFiles() {
        FEC_CustomerAdditionalInfoConfig__c cfg = [SELECT Id FROM FEC_CustomerAdditionalInfoConfig__c LIMIT 1];
        
        // Tạo file với Description = ORIGINAL_USER_UPLOAD
        ContentVersion cv = new ContentVersion(
            Title = 'TestExcel.xlsx',
            PathOnClient = 'TestExcel.xlsx',
            VersionData = Blob.valueOf('Excel content'),
            Description = FEC_ConstantCommon.ORIGINAL_USER_UPLOAD,
            FEC_Comments__c = FEC_ConstantCommon.UPLOADED_STATUS,
            FirstPublishLocationId = cfg.Id
        );
        insert cv;

        Test.startTest();
        List<Map<String, Object>> files = FEC_CustomerAdditionalInfoListController.getRelatedFiles(cfg.Id);
        Test.stopTest();

        System.assert(files.size() > 0, 'Phải trả về ít nhất 1 file');
        System.assertNotEquals(null, files[0].get(FEC_ConstantCommon.KEY_ID));
        System.assertEquals('TestExcel.xlsx', files[0].get(FEC_ConstantCommon.KEY_NAME));
    }

    @isTest
    static void testDeleteConfig() {
        // Tạo config mới với file và detail records
        FEC_CustomerAdditionalInfoConfig__c cfg = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_KeyIdentifier__c = 'DEL_TEST',
            FEC_FieldID__c = 'DEL_FIELD',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
        );
        insert cfg;

        ContentVersion cv = new ContentVersion(
            Title = 'ToDelete.xlsx',
            PathOnClient = 'ToDelete.xlsx',
            VersionData = Blob.valueOf('content'),
            FirstPublishLocationId = cfg.Id
        );
        insert cv;

        FEC_CustomerAdditionalInfo__c detail = new FEC_CustomerAdditionalInfo__c(
            FEC_Config__c = cfg.Id,
            FEC_KeyIDValue__c = 'DEL_KEY'
        );
        insert detail;

        FEC_CustomerDataConfigHistory__c history = new FEC_CustomerDataConfigHistory__c(
            FEC_Customers_Data_Config__c = cfg.Id,
            FEC_KeyIdentifier__c = 'DEL_TEST',
            FEC_FieldID__c = 'DEL_FIELD',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
        );
        insert history;

        Test.startTest();
        FEC_CustomerAdditionalInfoListController.deleteConfig(cfg.Id);
        Test.stopTest();

        List<FEC_CustomerAdditionalInfoConfig__c> remaining = [SELECT Id FROM FEC_CustomerAdditionalInfoConfig__c WHERE Id = :cfg.Id];
        System.assertEquals(0, remaining.size(), 'Config phải bị xóa');
    }

    @isTest
    static void testDeleteConfigException() {
        Boolean caught = false;
        try {
            // Dùng fake ID để trigger exception
            FEC_CustomerAdditionalInfoListController.deleteConfig('a0000000000FAKE');
        } catch(Exception e) { caught = true; }
        System.assert(caught, 'Phải bắt được lỗi khi xóa config không tồn tại');
    }

    @isTest
    static void testCheckDuplicateNotFound() {
        Boolean isDup = FEC_CustomerAdditionalInfoListController.checkDuplicateConfig('NONEXIST', 'NONE', null);
        System.assertEquals(false, isDup, 'Không nên tìm thấy duplicate');
    }

    @isTest
    static void testDeleteFileNull() {
        // Test deleteFile với null ID
        Boolean caught = false;
        try {
            FEC_CustomerAdditionalInfoListController.deleteFile(null);
        } catch(Exception e) { caught = true; }
        // Không nên throw vì có null check
        System.assert(!caught, 'Không nên throw lỗi khi ID null');
    }
}