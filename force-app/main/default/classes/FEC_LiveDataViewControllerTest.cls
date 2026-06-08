/**
 * @description Smoke tests for FEC_LiveDataViewController (facade).
 *              Mỗi method gọi service tương ứng — verify không throw + return type đúng.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      Live Layer
 */
@IsTest
private class FEC_LiveDataViewControllerTest {

    @IsTest
    static void testGetLiveNocTreeData() {
        Test.startTest();
        List<FEC_NatureOfCaseTreeItem> items = FEC_LiveDataViewController.getLiveNocTreeData();
        Test.stopTest();
        Assert.isNotNull(items, 'Phải return list (không null)');
    }

    @IsTest
    static void testGetLiveCaseStagesByBP() {
        Test.startTest();
        List<Map<String, String>> stages = FEC_LiveDataViewController.getLiveCaseStagesByBP(null);
        Test.stopTest();
        Assert.isNotNull(stages);
    }

    @IsTest
    static void testGetLiveMasterDataSettings() {
        Test.startTest();
        List<FEC_Master_Data_Setting__c> settings = FEC_LiveDataViewController.getLiveMasterDataSettings(null, null, false);
        Test.stopTest();
        Assert.isNotNull(settings);
    }

    @IsTest
    static void testGetLiveStageChangeRules() {
        Test.startTest();
        List<Map<String, String>> rules = FEC_LiveDataViewController.getLiveStageChangeRules(null);
        Test.stopTest();
        Assert.isNotNull(rules);
    }

    @IsTest
    static void testGetLiveChannels() {
        Test.startTest();
        List<FEC_Channel__c> channels = FEC_LiveDataViewController.getLiveChannels();
        Test.stopTest();
        Assert.isNotNull(channels);
    }

    @IsTest
    static void testGetLiveCaseChannels() {
        Test.startTest();
        List<FEC_Case_Channel__c> caseChannels = FEC_LiveDataViewController.getLiveCaseChannels();
        Test.stopTest();
        Assert.isNotNull(caseChannels);
    }

    @IsTest
    static void testGetLiveAdditionalFields() {
        Test.startTest();
        List<FEC_Additional_Field__c> fields = FEC_LiveDataViewController.getLiveAdditionalFields();
        Test.stopTest();
        Assert.isNotNull(fields);
    }

    @IsTest
    static void testGetLiveFieldListValues() {
        Test.startTest();
        List<FEC_Additional_Field_List_Value__c> vals = FEC_LiveDataViewController.getLiveFieldListValues(null);
        Test.stopTest();
        Assert.isNotNull(vals);
    }

    @IsTest
    static void testGetLiveBusinessProcessOptions() {
        Test.startTest();
        List<Map<String, String>> opts = FEC_LiveDataViewController.getLiveBusinessProcessOptions();
        Test.stopTest();
        Assert.isNotNull(opts);
    }

    @IsTest
    static void testGetLiveReviewCustomerTypes() {
        Test.startTest();
        List<Map<String, String>> types = FEC_LiveDataViewController.getLiveReviewCustomerTypes();
        Test.stopTest();
        Assert.isNotNull(types);
    }

    @IsTest
    static void testGetLiveReviewProductOptions() {
        Test.startTest();
        List<Map<String, String>> opts = FEC_LiveDataViewController.getLiveReviewProductOptions(null);
        Test.stopTest();
        Assert.isNotNull(opts);
    }

    @IsTest
    static void testGetLiveReviewBizOptions() {
        Test.startTest();
        List<Map<String, String>> opts = FEC_LiveDataViewController.getLiveReviewBizOptions(null);
        Test.stopTest();
        Assert.isNotNull(opts);
    }

    @IsTest
    static void testGetLiveReviewCategoryOptions() {
        Test.startTest();
        List<Map<String, String>> opts = FEC_LiveDataViewController.getLiveReviewCategoryOptions(null, null);
        Test.stopTest();
        Assert.isNotNull(opts);
    }

    @IsTest
    static void testGetLiveReviewSubCatOptions() {
        Test.startTest();
        List<Map<String, String>> opts = FEC_LiveDataViewController.getLiveReviewSubCatOptions(null, null, null);
        Test.stopTest();
        Assert.isNotNull(opts);
    }

    @IsTest
    static void testGetLiveReviewSubCodeOptions() {
        Test.startTest();
        List<Map<String, String>> opts = FEC_LiveDataViewController.getLiveReviewSubCodeOptions(null, null, null, null);
        Test.stopTest();
        Assert.isNotNull(opts);
    }

    @IsTest
    static void testGetAllLiveMasterData() {
        Test.startTest();
        Map<String, List<Object>> data = FEC_LiveDataViewController.getAllLiveMasterData();
        Test.stopTest();
        Assert.isNotNull(data);
    }

    @IsTest
    static void testGetAllMdmMasterData() {
        Test.startTest();
        Map<String, List<Object>> data = FEC_LiveDataViewController.getAllMdmMasterData();
        Test.stopTest();
        Assert.isNotNull(data);
    }

    @IsTest
    static void testGetLiveServiceTypeTree() {
        Test.startTest();
        List<Map<String, Object>> tree = FEC_LiveDataViewController.getLiveServiceTypeTree();
        Test.stopTest();
        Assert.isNotNull(tree);
    }

    @IsTest
    static void testGetLiveDynamicDecisionTable() {
        Test.startTest();
        FEC_DecisionTableController.TableWrapper wrapper = FEC_LiveDataViewController.getLiveDynamicDecisionTable(null);
        Test.stopTest();
        // wrapper có thể là null nếu không có business process — chỉ verify không throw
        Assert.isTrue(true, 'Method called successfully');
    }
}