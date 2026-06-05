/**
 * @description Facade for MDM Master Data Setting LWC operations — delegates to specialized services.
 *              Refactored in Phase 2.1 from Fat Controller (1,222 LOC) to thin Facade (~140 LOC).
 *              LWC import paths preserved (no breaking change for 5 LWC dependencies):
 *              fecMasterDataSetting, fecMasterDataSettingForm, fecFlowConfiguration,
 *              fecAutoFieldCreator, fecMasterDataReview.
 *
 *              Service map:
 *              - MDS CRUD + Schema + Push       → FEC_MasterDataSettingService
 *              - Case Stage + Stage Screen CRUD → FEC_CaseStageService
 *              - Options/Lookups/Picklists      → FEC_MDMOptionService
 *
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.1
 */
public with sharing class FEC_MasterDataSettingController {

    // ════════════════════════════════════════════════════════
    // MDS QUERIES (delegate to FEC_MasterDataSettingService)
    // ════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<FEC_MDM_Master_Data_Setting__c> getMasterDataSettings(String selectedNodeId, String selectedStageId, Boolean isIntegration) {
        return FEC_MasterDataSettingService.getMasterDataSettings(selectedNodeId, selectedStageId, isIntegration);
    }

    @AuraEnabled
    public static List<FEC_MDM_Master_Data_Setting__c> getMasterDataSettingsFresh(String selectedNodeId, String selectedStageId, Boolean isIntegration) {
        return FEC_MasterDataSettingService.getMasterDataSettings(selectedNodeId, selectedStageId, isIntegration);
    }

    @AuraEnabled
    public static Id saveMasterDataSetting(Map<String, Object> mappingReq) {
        return FEC_MasterDataSettingService.saveMasterDataSetting(mappingReq);
    }

    @AuraEnabled
    public static String deleteRecord(Id recordId) {
        return FEC_MasterDataSettingService.deleteRecord(recordId);
    }

    @AuraEnabled
    public static void deleteFraudIntegrationMapping(String recordId) {
        FEC_MasterDataSettingService.deleteFraudIntegrationMapping(recordId);
    }

    @AuraEnabled
    public static String checkParentDuplicateProperty(
        String nocId, String stageId, String additionalFieldId,
        String channelId, String applicableRole
    ) {
        return FEC_MasterDataSettingService.checkParentDuplicateProperty(nocId, stageId, additionalFieldId, channelId, applicableRole);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getSubSectionOrderMap() {
        return FEC_MasterDataSettingService.getSubSectionOrderMap();
    }

    // ════════════════════════════════════════════════════════
    // SCHEMA INTROSPECTION + PUSH (delegate to FEC_MasterDataSettingService)
    // ════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getGlobalObjectList() {
        return FEC_MasterDataSettingService.getGlobalObjectList();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getObjectFields(String objectName) {
        return FEC_MasterDataSettingService.getObjectFields(objectName);
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getDistinctSections(String natureOfCaseId, String stageId) {
        return FEC_MasterDataSettingService.getDistinctSections(natureOfCaseId, stageId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getDistinctSubSections(String natureOfCaseId, String stageId, String section) {
        return FEC_MasterDataSettingService.getDistinctSubSections(natureOfCaseId, stageId, section);
    }

    @AuraEnabled
    public static Id executePushToLive() {
        return FEC_MasterDataSettingService.executePushToLive();
    }

    // ════════════════════════════════════════════════════════
    // CASE STAGE CRUD (delegate to FEC_CaseStageService)
    // ════════════════════════════════════════════════════════

    @AuraEnabled
    public static void updateCaseStageName(Id stageId, String newName) {
        FEC_CaseStageService.updateCaseStageName(stageId, newName);
    }

    @AuraEnabled
    public static void updateCaseStage(
        Id stageId, String name, String nameVN, String alias,
        Boolean status, Boolean active, Boolean defaultStage,
        String natureOfCasesId, String userGroup, Integer posOrder,
        String statusName, Boolean endStage
    ) {
        FEC_CaseStageService.updateCaseStage(stageId, name, nameVN, alias, status, active,
            defaultStage, natureOfCasesId, userGroup, posOrder, statusName, endStage);
    }

    @AuraEnabled
    public static void deleteCaseStage(Id stageId) {
        FEC_CaseStageService.deleteCaseStage(stageId);
    }

    @AuraEnabled
    public static Id createCaseStage(
        String name, String code, String businessProcessId, String nameVN,
        Boolean status, String alias, Integer posOrder, Boolean defaultStage,
        String natureOfCasesId, String userGroup, Boolean active,
        String statusName, Boolean endStage
    ) {
        return FEC_CaseStageService.createCaseStage(name, code, businessProcessId, nameVN, status,
            alias, posOrder, defaultStage, natureOfCasesId, userGroup, active, statusName, endStage);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCaseStageOptionsByBP(String businessProcessId) {
        return FEC_CaseStageService.getCaseStageOptionsByBP(businessProcessId);
    }

    @AuraEnabled
    public static Map<String, String> getCaseStageDetail(Id stageId) {
        return FEC_CaseStageService.getCaseStageDetail(stageId);
    }

    // ════════════════════════════════════════════════════════
    // STAGE SCREEN CRUD (delegate to FEC_CaseStageService)
    // ════════════════════════════════════════════════════════

    @AuraEnabled
    public static List<Map<String, String>> getStageScreensByStage(Id stageId) {
        return FEC_CaseStageService.getStageScreensByStage(stageId);
    }

    @AuraEnabled
    public static Id createStageScreen(Id stageId, Id actionButtonId, String userGroup, Boolean active) {
        return FEC_CaseStageService.createStageScreen(stageId, actionButtonId, userGroup, active);
    }

    @AuraEnabled
    public static void deleteStageScreen(Id stageScreenId) {
        FEC_CaseStageService.deleteStageScreen(stageScreenId);
    }

    @AuraEnabled
    public static void toggleStageScreenActive(Id stageScreenId, Boolean active) {
        FEC_CaseStageService.toggleStageScreenActive(stageScreenId, active);
    }

    // ════════════════════════════════════════════════════════
    // OPTIONS / LOOKUPS / PICKLISTS (delegate to FEC_MDMOptionService)
    // ════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getChannels() {
        return FEC_MDMOptionService.getChannels();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getUserRoles() {
        return FEC_MDMOptionService.getUserRoles();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getStageOptions() {
        return FEC_MDMOptionService.getStageOptions();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getLookupOptions(String sObjectName) {
        return FEC_MDMOptionService.getLookupOptions(sObjectName);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getUserGroupOptions() {
        return FEC_MDMOptionService.getUserGroupOptions();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAdditionalFieldOptions() {
        return FEC_MDMOptionService.getAdditionalFieldOptions();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getNatureOfCaseOptions() {
        return FEC_MDMOptionService.getNatureOfCaseOptions();
    }

    @AuraEnabled(cacheable=true)
    public static String getUserTypeIdByName(String customerTypeName) {
        return FEC_MDMOptionService.getUserTypeIdByName(customerTypeName);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getActionButtonOptions() {
        return FEC_MDMOptionService.getActionButtonOptions();
    }

    // ════════════════════════════════════════════════════════
    // BACKWARD-COMPAT @TestVisible (FEC_MasterDataSettingControllerTest)
    // ════════════════════════════════════════════════════════

    @TestVisible
    private static void validateSchemaFields(String objectName, String fieldApiName) {
        FEC_MasterDataSettingService.validateSchemaFields(objectName, fieldApiName);
    }

    @TestVisible
    private static final Set<String> ALLOWED_LOOKUP_OBJECTS = new Set<String>{
        FEC_ObjectConstants.OBJ_CASE_STAGE,
        FEC_ObjectConstants.OBJ_MDM_ADDITIONAL_FIELD,
        FEC_ObjectConstants.OBJ_USER_ROLE
    };
}