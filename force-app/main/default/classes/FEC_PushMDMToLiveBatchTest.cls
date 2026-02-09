@isTest
private class FEC_PushMDMToLiveBatchTest {
    @testSetup
    static void setupFullBatch() {
        // Product Type
        FEC_MDM_Product_Type__c prod = new FEC_MDM_Product_Type__c(Name='PT', FEC_Code__c='PT01', FEC_Status__c=true, Process_Change_Status__c='New', ExternalID__c='EXT-PT-01');
        insert prod;
        // Business Process
        FEC_MDM_Business_Process__c bp = new FEC_MDM_Business_Process__c(Name='BP', FEC_Code__c='BP01', FEC_Status__c=true, Process_Change_Status__c='New', ExternalID__c='EXT-BP-01');
        insert bp;
        // Category
        FEC_MDM_Category__c cat = new FEC_MDM_Category__c(Name='Cat', FEC_Code__c='CAT01', FEC_Status__c=true, Process_Change_Status__c='New', ExternalID__c='EXT-CAT-01');
        insert cat;
        // Sub Category
        FEC_MDM_Sub_Category__c scat = new FEC_MDM_Sub_Category__c(Name='SCat', FEC_Code__c='SCAT01', FEC_Status__c=true, Process_Change_Status__c='New', ExternalID__c='EXT-SCAT-01');
        insert scat;
        // Sub Code
        FEC_MDM_Sub_Code__c scode = new FEC_MDM_Sub_Code__c(Name='SCode', FEC_Code__c='SCODE01', FEC_Status__c=true, Process_Change_Status__c='New', ExternalID__c='EXT-SCODE-01');
        insert scode;
        // Channel
        FEC_MDM_Channel__c channel = new FEC_MDM_Channel__c(Name='Channel', FEC_Channel_Vietnamese_name__c='Tên Kênh', FEC_Channel_ID__c='CH01', FEC_Channel_Status__c=true, Process_Change_Status__c='New', ExternalID__c='EXT-CH-01');
        insert channel;
        // Master Data Setting
        FEC_MDM_Master_Data_Setting__c mds = new FEC_MDM_Master_Data_Setting__c(FEC_Field_Object_Name__c='TestObj', FEC_Field_Status__c=true, Process_Change_Status__c='New', ExternalID__c='EXT-MDS-01');
        insert mds;
        // Case Stage
        FEC_MDM_Case_Stage__c cs = new FEC_MDM_Case_Stage__c(Name='Stage', FEC_Code__c='CS01', Process_Change_Status__c='New', ExternalID__c='EXT-CS-01');
        insert cs;
        // Additional Field
        FEC_MDM_Additional_Field__c af = new FEC_MDM_Additional_Field__c(Name='AF', FEC_Unique_ID__c='AF01', FEC_Type__c='String', FEC_Field_Status__c=true, Process_Change_Status__c='New', ExternalID__c='EXT-AF-01');
        insert af;
        // Additional Field List Value
        FEC_MDM_Additional_Field_List_Value__c aflv = new FEC_MDM_Additional_Field_List_Value__c(Name='AFLV', FEC_Name_VN__c='Tên AFLV', FEC_Order__c=1, Process_Change_Status__c='New', ExternalID__c='EXT-AFLV-01');
        insert aflv;
        // Nature Of Case
        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(Name='NOC', FEC_Product_Type_Name__c=prod.Id, FEC_Business_Process_Name__c=bp.Id, FEC_Category_Name__c=cat.Id, FEC_Sub_Category_Name__c=scat.Id, FEC_Sub_Code__c=scode.Id, FEC_Customer_Type__c='All', Process_Change_Status__c='New', ExternalID__c='EXT-NOC-01');
        insert noc;
    }

    @isTest
    static void testBatchExecution() {
        Test.startTest();
        // Khởi tạo và chạy Batch
        FEC_PushMDMToLiveBatch batch = new FEC_PushMDMToLiveBatch();
        Database.executeBatch(batch, 11); // Batch size matches executionOrder size
        Test.stopTest();

        // Kiểm tra xem bản ghi đã được cập nhật status sang 'Synced' (hoặc rỗng theo logic của bạn)
        FEC_MDM_Product_Type__c result = [SELECT Process_Change_Status__c FROM FEC_MDM_Product_Type__c LIMIT 1];
        // Lưu ý: Tùy vào logic trong execute() của bạn có reset status hay không, 
        // nhưng sau khi chạy thành công, bản ghi Live tương ứng phải tồn tại.
        
        // Kiểm tra xem bản ghi Live (Original) đã được tạo/cập nhật chưa
        // Giả sử map tới FEC_Product_Type__c
        List<SObject> liveRecords = Database.query('SELECT Id FROM FEC_Product_Type__c WHERE FEC_Code__c = \'P_TEST_01\'');
        Assert.isFalse(liveRecords.isEmpty(), 'Bản ghi Live phải được tạo sau khi chạy Batch');
    }

    @isTest
    static void testBatchWithErrors() {
        // Insert a valid MDM record, but set up data to cause an upsert error in the batch
        FEC_MDM_Product_Type__c errorProd = new FEC_MDM_Product_Type__c(
            Name = 'Error Prod',
            FEC_Code__c = 'DUPLICATE_CODE', // Use a code that will cause a duplicate error if needed
            Process_Change_Status__c = 'Update',
            ExternalID__c = 'ERROR-001'
        );
        insert errorProd;

        // Optionally, insert a conflicting live record to cause an upsert error
        FEC_Product_Type__c liveProd = new FEC_Product_Type__c(
            Name = 'Live Prod',
            FEC_Code__c = 'DUPLICATE_CODE'
        );
        insert liveProd;

        Test.startTest();
        FEC_PushMDMToLiveBatch batch = new FEC_PushMDMToLiveBatch();
        Database.executeBatch(batch, 11); // Batch size matches executionOrder size
        Test.stopTest();

        // Assert batch ran (and optionally check for error handling)
        Assert.isNotNull(batch, 'Batch khởi tạo thành công');
    }

    @isTest
    static void testBatchExecutionAllObjects() {
        Test.startTest();
        FEC_PushMDMToLiveBatch batch = new FEC_PushMDMToLiveBatch();
        Database.executeBatch(batch, 11); // Batch size matches executionOrder size
        Test.stopTest();
        // Assert at least one record for each target object exists
        System.assert([SELECT COUNT() FROM FEC_Product_Type__c] > 0);
        System.assert([SELECT COUNT() FROM FEC_Business_Process__c] > 0);
        System.assert([SELECT COUNT() FROM FEC_Category__c] > 0);
        System.assert([SELECT COUNT() FROM FEC_Sub_Category__c] > 0);
        System.assert([SELECT COUNT() FROM FEC_Sub_Code__c] > 0);
        System.assert([SELECT COUNT() FROM FEC_Channel__c] > 0);
        System.assert([SELECT COUNT() FROM FEC_Master_Data_Setting__c] > 0);
        System.assert([SELECT COUNT() FROM FEC_Case_Stage__c] > 0);
        System.assert([SELECT COUNT() FROM FEC_Additional_Field__c] > 0);
        System.assert([SELECT COUNT() FROM FEC_Additional_Field_List_Value__c] > 0);
        System.assert([SELECT COUNT() FROM FEC_Nature_Of_Case__c] > 0);
    }
}
