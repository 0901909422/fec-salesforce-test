/**
 * @description Deep tests for FEC_LiveMasterDataReviewController.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      Live Layer
 */
@IsTest
private class FEC_LiveMDReviewDeepTest {

    @testSetup
    static void setup() {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'PT_LMR', FEC_Code__c = 'PT_LMR_1', FEC_Active__c = true
        );
        insert pt;
        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'BP_LMR', FEC_Code__c = 'BP_LMR_1'
        );
        insert bp;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'CAT_LMR', FEC_Code__c = 'CAT_LMR_1', FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'SCAT_LMR', FEC_Code__c = 'SCAT_LMR_1', FEC_Active__c = true
        );
        insert subCat;
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'SC_LMR', FEC_Code__c = 'SC_LMR_1', FEC_Active__c = true
        );
        insert subCode;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Customer_Type__c = 'Existing',
            FEC_Code__c = 'NOC_LMR_1'
        );
        insert noc;

        // Live MDS setting
        insert new FEC_Master_Data_Setting__c(
            FEC_Code__c = 'MDS_LMR_1',
            FEC_Nature_Of_Case__c = noc.Id,
            FEC_Field_Status__c = true,
            FEC_Section__c = 'Section A'
        );
    }

    @IsTest
    static void testGetCustomerTypeOptions_HasData() {
        Test.startTest();
        List<Map<String, String>> opts = FEC_LiveMasterDataReviewController.getCustomerTypeOptions();
        Test.stopTest();
        Assert.isFalse(opts.isEmpty(), 'Customer types phải có');
    }

    @IsTest
    static void testGetProductOptions_ValidCustomerType() {
        Test.startTest();
        List<Map<String, String>> opts = FEC_LiveMasterDataReviewController.getProductOptions('Existing');
        Test.stopTest();
        Assert.isFalse(opts.isEmpty(), 'Products phải có');
    }

    @IsTest
    static void testGetBizOptions_ValidProduct() {
        Id ptId = [SELECT Id FROM FEC_Product_Type__c LIMIT 1].Id;
        Test.startTest();
        List<Map<String, String>> opts = FEC_LiveMasterDataReviewController.getBizOptions(String.valueOf(ptId));
        Test.stopTest();
        Assert.isFalse(opts.isEmpty());
    }

    @IsTest
    static void testGetCategoryOptions_ValidIds() {
        Id ptId = [SELECT Id FROM FEC_Product_Type__c LIMIT 1].Id;
        Id bpId = [SELECT Id FROM FEC_Business_Process__c LIMIT 1].Id;
        Test.startTest();
        List<Map<String, String>> opts = FEC_LiveMasterDataReviewController.getCategoryOptions(
            String.valueOf(ptId), String.valueOf(bpId)
        );
        Test.stopTest();
        Assert.isFalse(opts.isEmpty());
    }

    @IsTest
    static void testGetSubCatOptions_ValidIds() {
        Id ptId = [SELECT Id FROM FEC_Product_Type__c LIMIT 1].Id;
        Id bpId = [SELECT Id FROM FEC_Business_Process__c LIMIT 1].Id;
        Id catId = [SELECT Id FROM FEC_Category__c LIMIT 1].Id;
        Test.startTest();
        List<Map<String, String>> opts = FEC_LiveMasterDataReviewController.getSubCatOptions(
            String.valueOf(ptId), String.valueOf(bpId), String.valueOf(catId)
        );
        Test.stopTest();
        Assert.isFalse(opts.isEmpty());
    }

    @IsTest
    static void testGetSubCodeOptions_ValidIds() {
        Id ptId = [SELECT Id FROM FEC_Product_Type__c LIMIT 1].Id;
        Id bpId = [SELECT Id FROM FEC_Business_Process__c LIMIT 1].Id;
        Id catId = [SELECT Id FROM FEC_Category__c LIMIT 1].Id;
        Id subCatId = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1].Id;
        Test.startTest();
        List<Map<String, String>> opts = FEC_LiveMasterDataReviewController.getSubCodeOptions(
            String.valueOf(ptId), String.valueOf(bpId), String.valueOf(catId), String.valueOf(subCatId)
        );
        Test.stopTest();
        Assert.isNotNull(opts);
    }

    @IsTest
    static void testGetComparisonData_LiveOnly_ToNew() {
        Id ptId = [SELECT Id FROM FEC_Product_Type__c LIMIT 1].Id;
        Id bpId = [SELECT Id FROM FEC_Business_Process__c LIMIT 1].Id;
        Id catId = [SELECT Id FROM FEC_Category__c LIMIT 1].Id;
        Id subCatId = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1].Id;
        Id subCodeId = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1].Id;

        Test.startTest();
        FEC_MasterDataReviewController.ComparisonResult result = FEC_LiveMasterDataReviewController.getComparisonData(
            String.valueOf(ptId), String.valueOf(bpId), String.valueOf(catId),
            String.valueOf(subCatId), String.valueOf(subCodeId)
        );
        Test.stopTest();
        Assert.isNotNull(result);
        // Live exists but no MDM → newList should have entry
        Assert.isFalse(result.newList.isEmpty(), 'Live MDS without MDM → newList');
    }

    @IsTest
    static void testGetComparisonData_NoMatch() {
        Test.startTest();
        FEC_MasterDataReviewController.ComparisonResult result = FEC_LiveMasterDataReviewController.getComparisonData(
            'a0X000000000000', 'a0X000000000001', 'a0X000000000002', 'a0X000000000003', 'a0X000000000004'
        );
        Test.stopTest();
        Assert.isNotNull(result);
        Assert.isTrue(result.newList.isEmpty());
        Assert.isTrue(result.updateList.isEmpty());
    }
}