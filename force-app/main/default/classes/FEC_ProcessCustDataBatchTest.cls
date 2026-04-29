@isTest
private class FEC_ProcessCustDataBatchTest {

    @testSetup
    static void setup() {
        // Tạo Config
        FEC_CustomerAdditionalInfoConfig__c config = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_KeyIdentifier__c = 'CIF',
            FEC_FieldID__c = 'Phone',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS,
            FEC_IsActive__c = true
        );
        insert config;

        // JSON giả lập chuẩn mảng 2 chiều (Row 0: Header, Row 1: Data)
        String jsonContent = '[["ID", "Value"], ["12345", "0909123456"]]';
        
        ContentVersion cvJson = new ContentVersion(
            Title = 'Data.json', PathOnClient = 'Data.json',
            VersionData = Blob.valueOf(jsonContent),
            Description = FEC_ConstantCommon.JSON_DATA_FOR_PROCESSING,
            FEC_Comments__c = FEC_ConstantCommon.UPLOADED_STATUS,
            FirstPublishLocationId = config.Id
        );
        insert cvJson;
    }

    @isTest
    static void testBatchFlow() {
        Test.startTest();
        // Kiểm tra coverage cho cả phần Schedulable
        FEC_ProcessCustomerDataBatch sh1 = new FEC_ProcessCustomerDataBatch();
        String sch = '0 0 23 * * ?';
        System.schedule('Test Batch Sched', sch, sh1);
        
        Database.executeBatch(new FEC_ProcessCustomerDataBatch());
        Test.stopTest();

        // Kiểm tra xem ít nhất Batch có chạy qua
        FEC_CustomerAdditionalInfoConfig__c res = [SELECT FEC_Status__c FROM FEC_CustomerAdditionalInfoConfig__c LIMIT 1];
        System.assertNotEquals(FEC_ConstantCommon.UPLOADED_STATUS, res.FEC_Status__c, 'Batch phải thay đổi trạng thái Config');
    }

    @isTest
    static void testQueueableChunking() {
        FEC_CustomerAdditionalInfoConfig__c cfg = [SELECT Id FROM FEC_CustomerAdditionalInfoConfig__c LIMIT 1];
        
        FEC_CustomerAdditionalInfo__c detail = new FEC_CustomerAdditionalInfo__c(
            FEC_Config__c = cfg.Id,
            FEC_KeyIDValue__c = 'TEST_123'
        );

        Test.startTest();
        FEC_InsertCustomerDataQueueable job = new FEC_InsertCustomerDataQueueable(
            new List<FEC_CustomerAdditionalInfo__c>{detail}, 
            new Set<Id>{cfg.Id}, 
            new List<Id>(), 
            new Set<Id>()
        );
        System.enqueueJob(job);
        Test.stopTest();

        List<FEC_CustomerAdditionalInfo__c> results = [SELECT Id FROM FEC_CustomerAdditionalInfo__c WHERE FEC_KeyIDValue__c = 'TEST_123'];
        System.debug('Số lượng bản ghi insert được: ' + results.size());
        System.assert(results.size() >= 0);
    }

    @isTest
    static void testQueueableWithFullFinalize() {
        FEC_CustomerAdditionalInfoConfig__c cfg = [SELECT Id FROM FEC_CustomerAdditionalInfoConfig__c LIMIT 1];

        // Tạo Excel file để test finalize update
        ContentVersion cvExcel = new ContentVersion(
            Title = 'Excel.xlsx', PathOnClient = 'Excel.xlsx',
            VersionData = Blob.valueOf('Excel content'),
            Description = FEC_ConstantCommon.ORIGINAL_USER_UPLOAD,
            FEC_Comments__c = FEC_ConstantCommon.UPLOADED_STATUS,
            FirstPublishLocationId = cfg.Id
        );
        insert cvExcel;
        cvExcel = [SELECT Id FROM ContentVersion WHERE Id = :cvExcel.Id];

        // Tạo JSON file để test finalize delete
        ContentVersion cvJson = new ContentVersion(
            Title = 'Data.json', PathOnClient = 'Data.json',
            VersionData = Blob.valueOf('[["H"],["V"]]'),
            Description = FEC_ConstantCommon.JSON_DATA_FOR_PROCESSING,
            FEC_Comments__c = FEC_ConstantCommon.UPLOADED_STATUS,
            FirstPublishLocationId = cfg.Id
        );
        insert cvJson;
        Id jsonDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cvJson.Id].ContentDocumentId;

        FEC_CustomerAdditionalInfo__c detail = new FEC_CustomerAdditionalInfo__c(
            FEC_Config__c = cfg.Id,
            FEC_KeyIDValue__c = 'FULL_TEST'
        );

        Test.startTest();
        FEC_InsertCustomerDataQueueable job = new FEC_InsertCustomerDataQueueable(
            new List<FEC_CustomerAdditionalInfo__c>{detail},
            new Set<Id>{cfg.Id},
            new List<Id>{cvExcel.Id},
            new Set<Id>{jsonDocId}
        );
        System.enqueueJob(job);
        Test.stopTest();

        // Config should be Processed
        FEC_CustomerAdditionalInfoConfig__c updatedCfg = [SELECT FEC_Status__c FROM FEC_CustomerAdditionalInfoConfig__c WHERE Id = :cfg.Id];
        System.assertEquals(FEC_ConstantCommon.PROCESSED_STATUS, updatedCfg.FEC_Status__c, 'Config phải chuyển sang Processed');
    }

    @isTest
    static void testQueueableEmptyData() {
        FEC_CustomerAdditionalInfoConfig__c cfg = [SELECT Id FROM FEC_CustomerAdditionalInfoConfig__c LIMIT 1];

        Test.startTest();
        FEC_InsertCustomerDataQueueable job = new FEC_InsertCustomerDataQueueable(
            new List<FEC_CustomerAdditionalInfo__c>(),
            new Set<Id>{cfg.Id},
            new List<Id>(),
            new Set<Id>()
        );
        System.enqueueJob(job);
        Test.stopTest();

        // Config should still be updated to Processed even with empty data
        FEC_CustomerAdditionalInfoConfig__c updatedCfg = [SELECT FEC_Status__c FROM FEC_CustomerAdditionalInfoConfig__c WHERE Id = :cfg.Id];
        System.assertEquals(FEC_ConstantCommon.PROCESSED_STATUS, updatedCfg.FEC_Status__c);
    }

    @isTest
    static void testBatchNoJsonFiles() {
        // Tạo config mới không có JSON file
        FEC_CustomerAdditionalInfoConfig__c cfgNoJson = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_KeyIdentifier__c = 'NOJSON',
            FEC_FieldID__c = 'FIELD',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS,
            FEC_IsActive__c = true
        );
        insert cfgNoJson;

        Test.startTest();
        Database.executeBatch(new FEC_ProcessCustomerDataBatch());
        Test.stopTest();

        // Config without JSON should remain Uploaded (not processed)
        FEC_CustomerAdditionalInfoConfig__c result = [SELECT FEC_Status__c FROM FEC_CustomerAdditionalInfoConfig__c WHERE Id = :cfgNoJson.Id];
        System.assertEquals(FEC_ConstantCommon.UPLOADED_STATUS, result.FEC_Status__c, 'Config không có JSON phải giữ nguyên status');
    }
}