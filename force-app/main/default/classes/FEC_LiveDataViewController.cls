/**
 * @description Facade for Live Data View — delegates to specialized services.
 *              Refactored in Phase 2.4 from Fat Controller (1,006 LOC) to thin Facade (~120 LOC).
 *              LWC import paths preserved (no breaking change).
 *
 *              Service map:
 *              - NOC tree + MDS queries     → FEC_LiveNOCQueryService
 *              - Channels + Fields + BP     → FEC_LiveChannelFieldService
 *              - Review tab cascading       → FEC_LiveReviewService
 *              - Aggregation + Service Tree → FEC_LiveMasterDataAggregatorService
 *
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.4
 */
public with sharing class FEC_LiveDataViewController {

    // ════════════════════════════════════════════════════════
    // NOC TREE + MASTER DATA SETTINGS (delegate to FEC_LiveNOCQueryService)
    // ════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<FEC_NatureOfCaseTreeItem> getLiveNocTreeData() {
        return FEC_LiveNOCQueryService.getLiveNocTreeData();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveCaseStagesByBP(String businessProcessId) {
        return FEC_LiveNOCQueryService.getLiveCaseStagesByBP(businessProcessId);
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_Master_Data_Setting__c> getLiveMasterDataSettings(String nocId, String stageId, Boolean isIntegration) {
        return FEC_LiveNOCQueryService.getLiveMasterDataSettings(nocId, stageId, isIntegration);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveStageChangeRules(String businessProcessId) {
        return FEC_LiveNOCQueryService.getLiveStageChangeRules(businessProcessId);
    }

    // ════════════════════════════════════════════════════════
    // CHANNELS + FIELDS + BP OPTIONS (delegate to FEC_LiveChannelFieldService)
    // ════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<FEC_Channel__c> getLiveChannels() {
        return FEC_LiveChannelFieldService.getLiveChannels();
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_Case_Channel__c> getLiveCaseChannels() {
        return FEC_LiveChannelFieldService.getLiveCaseChannels();
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_Additional_Field__c> getLiveAdditionalFields() {
        return FEC_LiveChannelFieldService.getLiveAdditionalFields();
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_Additional_Field_List_Value__c> getLiveFieldListValues(String fieldId) {
        return FEC_LiveChannelFieldService.getLiveFieldListValues(fieldId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveBusinessProcessOptions() {
        return FEC_LiveChannelFieldService.getLiveBusinessProcessOptions();
    }

    // ════════════════════════════════════════════════════════
    // REVIEW TAB CASCADING (delegate to FEC_LiveReviewService)
    // ════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveReviewCustomerTypes() {
        return FEC_LiveReviewService.getLiveReviewCustomerTypes();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveReviewProductOptions(String customerType) {
        return FEC_LiveReviewService.getLiveReviewProductOptions(customerType);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveReviewBizOptions(String productId) {
        return FEC_LiveReviewService.getLiveReviewBizOptions(productId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveReviewCategoryOptions(String productId, String bizId) {
        return FEC_LiveReviewService.getLiveReviewCategoryOptions(productId, bizId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveReviewSubCatOptions(String productId, String bizId, String catId) {
        return FEC_LiveReviewService.getLiveReviewSubCatOptions(productId, bizId, catId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveReviewSubCodeOptions(String productId, String bizId, String catId, String subCatId) {
        return FEC_LiveReviewService.getLiveReviewSubCodeOptions(productId, bizId, catId, subCatId);
    }

    @AuraEnabled(cacheable=true)
    public static FEC_MasterDataReviewController.ComparisonResult getLiveReviewComparison(
        String productId, String bizId, String catId, String subCatId, String subCodeId
    ) {
        return FEC_LiveReviewService.getLiveReviewComparison(productId, bizId, catId, subCatId, subCodeId);
    }

    // ════════════════════════════════════════════════════════
    // AGGREGATION + DECISION TABLE (delegate to FEC_LiveMasterDataAggregatorService)
    // ════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Object>> getAllLiveMasterData() {
        return FEC_LiveMasterDataAggregatorService.getAllLiveMasterData();
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Object>> getAllMdmMasterData() {
        return FEC_LiveMasterDataAggregatorService.getAllMdmMasterData();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getLiveServiceTypeTree() {
        return FEC_LiveMasterDataAggregatorService.getLiveServiceTypeTree();
    }

    @AuraEnabled(cacheable=true)
    public static FEC_DecisionTableController.TableWrapper getLiveDynamicDecisionTable(String businessProcessId) {
        return FEC_LiveMasterDataAggregatorService.getLiveDynamicDecisionTable(businessProcessId);
    }
}