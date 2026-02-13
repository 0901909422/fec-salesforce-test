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
            FEC_Product_Type_Name__c = prod.Id,
            FEC_Business_Process_Name__c = biz.Id,
            FEC_Category_Name__c = cat.Id,
            FEC_Sub_Category_Name__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            ExternalID__c = 'NOC_EXT_01'
        );
        insert noc;

        // 3. Tạo Additional Field (Required: FEC_Name_VN__c, FEC_Type__c)
        FEC_MDM_Additional_Field__c addField = new FEC_MDM_Additional_Field__c(
            FEC_Unique_ID__c = 'ADD_01',
            FEC_Name_VN__c = 'Trường Test',
            FEC_Type__c = 'String'
        );
        insert addField;

        // 4. Tạo Setting Live (Bản cũ - Non MDM Object)
        FEC_Master_Data_Setting__c live = new FEC_Master_Data_Setting__c(
            FEC_Channel__c = 'Web',
            FEC_Field_Mandatory__c = false
        );
        insert live;

        // 5. Tạo Setting MDM (Bản mới - MDM Object)
        List<FEC_MDM_Master_Data_Setting__c> mdmList = new List<FEC_MDM_Master_Data_Setting__c>{
            // Record test updateList (Web -> App)
            new FEC_MDM_Master_Data_Setting__c(
                ExternalID__c = 'EXT_SYNC', 
                FEC_Channel__c = 'App', 
                FEC_Nature_Of_Case__c = noc.Id, 
                FEC_Additional_Field__c = addField.Id,
                FEC_Field_Mandatory__c = true,
                Process_Change_Status__c = 'Changed'
            ),
            // Record test newList
            new FEC_MDM_Master_Data_Setting__c(
                ExternalID__c = 'EXT_NEW', 
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
        FEC_MDM_Nature_Of_Case__c noc = [SELECT FEC_Product_Type_Name__c, FEC_Business_Process_Name__c, 
                                               FEC_Category_Name__c, FEC_Sub_Category_Name__c, FEC_Sub_Code__c 
                                        FROM FEC_MDM_Nature_Of_Case__c LIMIT 1];

        Test.startTest();
        // Thực thi logic so sánh dữ liệu
        FEC_MasterDataReviewController.ComparisonResult result = FEC_MasterDataReviewController.getComparisonData(
            noc.FEC_Product_Type_Name__c, 
            noc.FEC_Business_Process_Name__c, 
            noc.FEC_Category_Name__c, 
            noc.FEC_Sub_Category_Name__c, 
            noc.FEC_Sub_Code__c
        );
        Test.stopTest();

        // Kiểm tra phân loại danh sách so sánh
        Assert.isFalse(result.newList.isEmpty(), 'newList không được rỗng');
        Assert.isFalse(result.updateList.isEmpty(), 'updateList không được rỗng');
        Assert.areEqual('App', result.updateList[0].diffs[0].newVal, 'Giá trị channel mới phải là App');
    }
}
