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
}