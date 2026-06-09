/**
 * @description Test class cho FEC_MasterDataReviewController.
 * Đã sửa lỗi tham chiếu ID (Lookup) sang các Object MDM tương ứng.
 */
@isTest
private class FEC_MasterDataReviewControllerTest {

    @testSetup
    static void setup() {
        // 1. Khởi tạo bộ Master Data theo đúng Object MDM (Tiền tố FEC_MDM_)
        FEC_MDM_Product_Type__c prod = new FEC_MDM_Product_Type__c(FEC_Code__c = 'P01');
        insert prod;

        FEC_MDM_Business_Process__c biz = new FEC_MDM_Business_Process__c(FEC_Code__c = 'B01');
        insert biz;

        FEC_MDM_Category__c cat = new FEC_MDM_Category__c(FEC_Code__c = 'C01');
        insert cat;

        FEC_MDM_Sub_Category__c subCat = new FEC_MDM_Sub_Category__c(FEC_Code__c = 'SC01');
        insert subCat;

        FEC_MDM_Sub_Code__c subCode = new FEC_MDM_Sub_Code__c(FEC_Code__c = 'SCC01');
        insert subCode;

        // 2. Tạo Nature of Case (NOC) tham chiếu đến bộ MDM trên
        FEC_MDM_Nature_Of_Case__c noc = new FEC_MDM_Nature_Of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Business_Process__c = biz.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Code__c = 'NOC_EXT_01'
        );
        insert noc;

        // 3. Tạo Additional Field (Required: FEC_Name_VN__c, FEC_Type__c)
        FEC_MDM_Additional_Field__c addField = new FEC_MDM_Additional_Field__c(
            FEC_Unique_ID__c = 'ADD_01',
            FEC_Name_VN__c = 'Trường Test',
            FEC_Type__c = 'String'
        );
        insert addField;

        // 4. Tạo Channel records (Live + MDM) — FEC_Channel__c là Lookup
        FEC_Channel__c chWeb = new FEC_Channel__c(
            Name = 'Web', FEC_Code__c = 'CH_WEB',
            FEC_Channel_ID__c = 'WEB', FEC_Channel_Vietnamese_name__c = 'Web',
            FEC_Channel_Status__c = true,
            FEC_Self_Service_Flag__c = false,
            FEC_Cancel_Case__c = false,
            FEC_Get_Nature_Of_Case__c = false,
            FEC_Update_Case_Status__c = false
        );
        FEC_Channel__c chApp = new FEC_Channel__c(
            Name = 'App', FEC_Code__c = 'CH_APP',
            FEC_Channel_ID__c = 'APP', FEC_Channel_Vietnamese_name__c = 'Ứng dụng',
            FEC_Channel_Status__c = true,
            FEC_Self_Service_Flag__c = false,
            FEC_Cancel_Case__c = false,
            FEC_Get_Nature_Of_Case__c = false,
            FEC_Update_Case_Status__c = false
        );
        insert new List<FEC_Channel__c>{chWeb, chApp};

        FEC_MDM_Channel__c mdmChWeb = new FEC_MDM_Channel__c(
            Name = 'Web', FEC_Code__c = 'CH_WEB',
            FEC_Channel_ID__c = 'WEB', FEC_Channel_Vietnamese_name__c = 'Web',
            FEC_Channel_Status__c = true, FEC_Self_Service_Flag__c = false
        );
        FEC_MDM_Channel__c mdmChApp = new FEC_MDM_Channel__c(
            Name = 'App', FEC_Code__c = 'CH_APP',
            FEC_Channel_ID__c = 'APP', FEC_Channel_Vietnamese_name__c = 'Ứng dụng',
            FEC_Channel_Status__c = true, FEC_Self_Service_Flag__c = false
        );
        insert new List<FEC_MDM_Channel__c>{mdmChWeb, mdmChApp};

        // 5. Tạo Setting Live (Bản cũ - Non MDM Object)
        // FEC_Code__c = 'EXT_SYNC' để match với MDM record bên dưới → verify updateList
        FEC_Master_Data_Setting__c live = new FEC_Master_Data_Setting__c(
            FEC_Code__c = 'EXT_SYNC',
            FEC_Channel__c = chWeb.Id,
            FEC_Field_Mandatory__c = false
        );
        insert live;

        // 6. Tạo Setting MDM (Bản mới - MDM Object)
        List<FEC_MDM_Master_Data_Setting__c> mdmList = new List<FEC_MDM_Master_Data_Setting__c>{
            // Record test updateList (Web -> App)
            new FEC_MDM_Master_Data_Setting__c(
                FEC_Code__c = 'EXT_SYNC',
                FEC_Channel__c = mdmChApp.Id,
                FEC_Nature_Of_Case__c = noc.Id,
                FEC_Additional_Field__c = addField.Id,
                FEC_Field_Mandatory__c = true,
                Process_Change_Status__c = 'Changed'
            ),
            // Record test newList
            new FEC_MDM_Master_Data_Setting__c(
                FEC_Code__c = 'EXT_NEW',
                FEC_Nature_Of_Case__c = noc.Id,
                Process_Change_Status__c = 'New'
            )
        };
        insert mdmList;
    }

    @isTest
    static void testGetOptions() {
        FEC_MDM_Product_Type__c prod = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1];
        FEC_MDM_Business_Process__c biz = [SELECT Id FROM FEC_MDM_Business_Process__c LIMIT 1];
        FEC_MDM_Category__c cat = [SELECT Id FROM FEC_MDM_Category__c LIMIT 1];
        FEC_MDM_Sub_Category__c subCat = [SELECT Id FROM FEC_MDM_Sub_Category__c LIMIT 1];

        Test.startTest();
        // Gọi các hàm AggregateResult
        Assert.isNotNull(FEC_MasterDataReviewController.getCustomerTypeOptions());
        Assert.isNotNull(FEC_MasterDataReviewController.getBizOptions(prod.Id));
        Assert.isNotNull(FEC_MasterDataReviewController.getCategoryOptions(prod.Id, biz.Id));
        Assert.isNotNull(FEC_MasterDataReviewController.getSubCatOptions(prod.Id, biz.Id, cat.Id));
        Assert.isNotNull(FEC_MasterDataReviewController.getSubCodeOptions(prod.Id, biz.Id, cat.Id, subCat.Id));
        Test.stopTest();
    }

    @isTest
    static void testComparisonData() {
        FEC_MDM_Nature_Of_Case__c noc = [SELECT FEC_Product_Type__c, FEC_Business_Process__c, 
                                               FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c 
                                        FROM FEC_MDM_Nature_Of_Case__c LIMIT 1];

        Test.startTest();
        FEC_MasterDataReviewController.ComparisonResult result = FEC_MasterDataReviewController.getComparisonData(
            noc.FEC_Product_Type__c, 
            noc.FEC_Business_Process__c, 
            noc.FEC_Category__c, 
            noc.FEC_Sub_Category__c, 
            noc.FEC_Sub_Code__c
        );
        Test.stopTest();

        // EXT_NEW không có Live record tương ứng → newList
        Assert.isFalse(result.newList.isEmpty(), 'newList không được rỗng — EXT_NEW phải là record mới');
        Assert.areEqual(1, result.newList.size(), 'Chỉ có 1 record mới (EXT_NEW)');
        Assert.areEqual('EXT_NEW', result.newList[0].externalId, 'Record mới phải có code EXT_NEW');
        Assert.isTrue(result.newList[0].isNew, 'Record EXT_NEW phải được đánh dấu isNew');

        // EXT_SYNC có Live record (Web) nhưng MDM đổi sang App → updateList
        Assert.isFalse(result.updateList.isEmpty(), 'updateList không được rỗng — EXT_SYNC phải có thay đổi');
        Assert.areEqual(1, result.updateList.size(), 'Chỉ có 1 record cập nhật (EXT_SYNC)');
        Assert.areEqual('EXT_SYNC', result.updateList[0].externalId, 'Record cập nhật phải có code EXT_SYNC');
        Assert.isTrue(result.updateList[0].hasChanged, 'Record EXT_SYNC phải được đánh dấu hasChanged');
        // Verify diff: ít nhất 1 diff được generate giữa Live và MDM record
        // (channel field comparison may yield placeholders or actual names depending on query relationship)
        Assert.isFalse(result.updateList[0].diffs.isEmpty(),
            'Phải có ít nhất 1 diff giữa Live và MDM record');
        Assert.isTrue(result.updateList[0].diffCount >= 1,
            'diffCount phải ≥ 1 (channel/mandatory thay đổi giữa Web/App)');

        // syncedList phải rỗng vì không có record nào giống nhau hoàn toàn
        Assert.isTrue(result.syncedList.isEmpty(), 'syncedList phải rỗng');
    }

    @isTest
    static void testComparisonDataNoMatch() {
        // Test với IDs không tồn tại → trả về ComparisonResult rỗng
        FEC_MDM_Product_Type__c prod = [SELECT Id FROM FEC_MDM_Product_Type__c LIMIT 1];
        FEC_MDM_Business_Process__c biz = [SELECT Id FROM FEC_MDM_Business_Process__c LIMIT 1];
        FEC_MDM_Category__c cat = [SELECT Id FROM FEC_MDM_Category__c LIMIT 1];
        FEC_MDM_Sub_Category__c subCat = [SELECT Id FROM FEC_MDM_Sub_Category__c LIMIT 1];

        Test.startTest();
        // Dùng subCodeId không khớp → không tìm thấy NOC
        FEC_MasterDataReviewController.ComparisonResult result = FEC_MasterDataReviewController.getComparisonData(
            prod.Id, biz.Id, cat.Id, subCat.Id, null
        );
        Test.stopTest();

        Assert.isTrue(result.newList.isEmpty(), 'newList phải rỗng khi không có NOC match');
        Assert.isTrue(result.updateList.isEmpty(), 'updateList phải rỗng khi không có NOC match');
        Assert.isTrue(result.syncedList.isEmpty(), 'syncedList phải rỗng khi không có NOC match');
    }
}