/**
 * FEC_ObjectConstants
 * Centralized constants for SObject API names used across the FEC module.
 * Extracted from FEC_Constants for better organization and maintainability.
 */
public class FEC_ObjectConstants {
    // Prevent instantiation
    private FEC_ObjectConstants() {}

    // Live Object API names
    public static final String OBJ_PRODUCT_TYPE = 'FEC_Product_Type__c';
    public static final String OBJ_BUSINESS_PROCESS = 'FEC_Business_Process__c';
    public static final String OBJ_CATEGORY = 'FEC_Category__c';
    public static final String OBJ_SUB_CATEGORY = 'FEC_Sub_Category__c';
    public static final String OBJ_SUB_CODE = 'FEC_Sub_Code__c';
    public static final String OBJ_CHANNEL = 'FEC_Channel__c';
    public static final String OBJ_MASTER_DATA_SETTING = 'FEC_Master_Data_Setting__c';
    public static final String OBJ_NATURE_OF_CASE = 'FEC_Nature_Of_Case__c';
    public static final String OBJ_ADDITIONAL_FIELD = 'FEC_Additional_Field__c';
    public static final String OBJ_ADDITIONAL_FIELD_LIST_VALUE = 'FEC_Additional_Field_List_Value__c';
    public static final String OBJ_CASE_STAGE = 'FEC_Case_Stage__c';
    public static final String OBJ_STAGE_CHANGE = 'FEC_Stage_Change__c';
    public static final String OBJ_ACTION_BUTTON = 'FEC_Action_Button__c';
    public static final String OBJ_STAGE_CHANGE_CONDITION = 'FEC_Stage_Change_Condition__c';
    public static final String OBJ_DECISION_RULE = 'FEC_Decision_Rule__c';
    public static final String OBJ_DECISION_CONDITION = 'FEC_Decision_Condition__c';
    public static final String OBJ_HOLD_CASE_CONFIG = 'FEC_Hold_Case_Config__c';
    public static final String OBJ_NFU_CODE = 'FEC_NFU_Code__c';

    // MDM Object API names
    public static final String OBJ_MDM_PRODUCT_TYPE = 'FEC_MDM_Product_Type__c';
    public static final String OBJ_MDM_BUSINESS_PROCESS = 'FEC_MDM_Business_Process__c';
    public static final String OBJ_MDM_CATEGORY = 'FEC_MDM_Category__c';
    public static final String OBJ_MDM_SUB_CATEGORY = 'FEC_MDM_Sub_Category__c';
    public static final String OBJ_MDM_SUB_CODE = 'FEC_MDM_Sub_Code__c';
    public static final String OBJ_MDM_CHANNEL = 'FEC_MDM_Channel__c';
    public static final String OBJ_MDM_MASTER_DATA_SETTING = 'FEC_MDM_Master_Data_Setting__c';
    public static final String OBJ_MDM_CASE_STAGE = 'FEC_MDM_Case_Stage__c';
    public static final String OBJ_MDM_ADDITIONAL_FIELD = 'FEC_MDM_Additional_Field__c';
    public static final String OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE = 'FEC_MDM_Additional_Field_List_Value__c';
    public static final String OBJ_MDM_NATURE_OF_CASE = 'FEC_MDM_Nature_Of_Case__c';
    public static final String OBJ_MDM_STAGE_CHANGE = 'FEC_MDM_Stage_Change__c';
    public static final String OBJ_MDM_ACTION_BUTTON = 'FEC_MDM_Action_Button__c';
    public static final String OBJ_MDM_STAGE_CHANGE_CONDITION = 'FEC_MDM_Stage_Change_Condition__c';
    public static final String OBJ_MDM_DECISION_RULE = 'FEC_MDM_Decision_Rule__c';
    public static final String OBJ_MDM_DECISION_CONDITION = 'FEC_MDM_Decision_Condition__c';
    public static final String OBJ_MDM_HOLD_CASE_CONFIG = 'FEC_MDM_Hold_Case_Config__c';
    public static final String OBJ_MDM_NFU_CODE = 'FEC_MDM_NFU_Code__c';

    // Uppercase keys (used when mapping uses uppercase API names)
    public static final String KEY_MDM_PRODUCT_TYPE = 'FEC_MDM_PRODUCT_TYPE__C';
    public static final String KEY_MDM_BUSINESS_PROCESS = 'FEC_MDM_BUSINESS_PROCESS__C';
    public static final String KEY_MDM_CATEGORY = 'FEC_MDM_CATEGORY__C';
    public static final String KEY_MDM_SUB_CATEGORY = 'FEC_MDM_SUB_CATEGORY__C';
    public static final String KEY_MDM_SUB_CODE = 'FEC_MDM_SUB_CODE__C';

    // Master data response keys
    public static final String KEY_PRODUCT_TYPE = 'ProductType';
    public static final String KEY_BUSINESS_PROCESS = 'BusinessProcess';
    public static final String KEY_CATEGORY = 'Category';
    public static final String KEY_SUB_CATEGORY = 'SubCategory';
    public static final String KEY_SUB_CODE = 'SubCode';
    public static final String KEY_MASTER_SETTING = 'MasterSetting';
    public static final String KEY_CHANNEL = 'Channel';
    public static final String KEY_NATURE_OF_CASE = 'NatureOfCase';
    public static final String KEY_ADDITIONAL_FIELD = 'AdditionalField';
    public static final String KEY_ADDITIONAL_FIELD_LIST = 'AdditionalFieldList';
    public static final String KEY_CASE_STAGE = 'CaseStage';
}