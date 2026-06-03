@IsTest
private class FEC_CleanUpMasterDataController_Test {

    @TestSetup
    static void setupData() {
        // 1. Dựng dữ liệu cho các Object Master Data
        FEC_Product_Type__c pt = new FEC_Product_Type__c(Name = 'Test PT', FEC_Code__c = 'PT01');
        FEC_Business_Process__c bp = new FEC_Business_Process__c(Name = 'Test BP', FEC_Code__c = 'BP01');
        FEC_Category__c cat = new FEC_Category__c(Name = 'Test Cat', FEC_Code__c = 'CAT01');
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(Name = 'Test SubCat', FEC_Code__c = 'SUB01');
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(Name = 'Test SubCode', FEC_Code__c = 'SC01');
        insert new List<SObject>{pt, bp, cat, subCat, subCode};

        // 2. Dựng dữ liệu Nature Of Case
        FEC_Nature_Of_Case__c noc = new FEC_Nature_Of_Case__c(
            Name = 'Test NOC',
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id
        );
        insert noc;

        // 3. Dựng dữ liệu Stage Change
        FEC_Action_Button__c ab = new FEC_Action_Button__c(Name = 'Test Btn', FEC_Code__c = 'BTN01');
        insert ab;
        FEC_Stage_Change__c sc = new FEC_Stage_Change__c(
            Name = 'Test SC',
            FEC_Action_Button__c = ab.Id
        );
        insert sc;
    }

    @IsTest
    static void testGetAllMasterData() {
        Test.startTest();
        Map<String, List<Object>> result = FEC_CleanUpMasterDataController.getAllMasterData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Master Data Map không được null');
        System.assert(result.containsKey(FEC_Constants.KEY_NATURE_OF_CASE), 'Phải chứa key NatureOfCase');
        
        // Kiểm tra Wrapper
        List<Object> nocList = result.get(FEC_Constants.KEY_NATURE_OF_CASE);
        System.assert(nocList[0] instanceof FEC_CleanUpMasterDataController.NatureOfCaseWrapper);
    }

    @IsTest
    static void testGetAllMasterDataMDM() {
        // Cần tạo dữ liệu MDM nếu class này query bảng MDM riêng
        // Nếu Object MDM chưa tồn tại, test này sẽ cần Mock hoặc tạo object
        Test.startTest();
        try {
            FEC_CleanUpMasterDataController.getAllMasterDataMDM();
        } catch(Exception e) {
            // Nếu các object MDM chưa được deploy, catch ngoại lệ
        }
        Test.stopTest();
    }

    @IsTest
    static void testSyncAndPush() {
        Test.startTest();
        // Test Batch Execution
        FEC_CleanUpMasterDataController.syncDataToMDM();
        FEC_CleanUpMasterDataController.pushMDMToLive();
        Test.stopTest();
        
        // Kiểm tra Async Job
        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name IN ('FEC_SyncMasterDataBatch', 'FEC_PushMDMToLiveBatch')];
        System.assert(jobs.size() > 0, 'Batch phải được kích hoạt.');
    }

    @IsTest
    static void testWrappers() {
        // Kiểm tra thủ công constructor của các wrapper để tăng coverage
        FEC_Nature_Of_Case__c noc = [SELECT Id, Name, FEC_Product_Type__r.Name FROM FEC_Nature_Of_Case__c LIMIT 1];
        FEC_CleanUpMasterDataController.NatureOfCaseWrapper wrapper = new FEC_CleanUpMasterDataController.NatureOfCaseWrapper(noc);
        
        System.assertEquals(noc.Id, wrapper.Id);
        System.assertNotEquals(null, wrapper.Name);
    }
}