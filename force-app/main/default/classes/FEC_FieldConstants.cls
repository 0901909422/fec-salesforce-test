/**
 * FEC_FieldConstants
 * Centralized constants for field API names used across the FEC module.
 * Extracted from FEC_Constants for better organization and maintainability.
 */
public class FEC_FieldConstants {
    // Prevent instantiation
    private FEC_FieldConstants() {}

    // Common field API names
    public static final String FIELD_ALIAS = 'FEC_Alias__c';
    public static final String FIELD_CODE = 'FEC_Code__c';
    public static final String FIELD_NAME_VN = 'FEC_Name_VN__c';
    public static final String FIELD_STATUS = 'FEC_Status__c';
    public static final String FIELD_POS_ORDER = 'FEC_Pos_Order__c';
    public static final String FIELD_NAME = 'Name';
    public static final String FIELD_ID = 'Id';
    public static final String FIELD_EXTERNAL_ID = 'ExternalID__c';
    public static final String FIELD_PROCESS_CHANGE_STATUS = 'Process_Change_Status__c';
    public static final String FIELD_FEC_UNIQUE_ID = 'FEC_Unique_ID__c';
    public static final String FIELD_FEC_TYPE = 'FEC_Type__c';
    public static final String FIELD_FEC_ORDER = 'FEC_Order__c';
    public static final String FIELD_ACTIVE = 'FEC_Active__c';

    // Channel field API names
    public static final String FIELD_CHANNEL_ID = 'FEC_Channel_ID__c';
    public static final String FIELD_CHANNEL_STATUS = 'FEC_Channel_Status__c';
    public static final String FIELD_CHANNEL_VI_NAME = 'FEC_Channel_Vietnamese_name__c';
    public static final String FIELD_CHANNEL = 'FEC_Channel__c';
    public static final String FIELD_CASE_CHANNEL = 'FEC_Case_Channel__c';
    public static final String FIELD_SELF_SERVICE_FLAG = 'FEC_Self_Service_Flag__c';

    // Property / misc field API names
    public static final String FIELD_PROPERTY_REFERENCE = 'Property_Reference__c';
    public static final String FIELD_DATA_INTEGRATION_MAPPING = 'FEC_Data_Integration_Mapping__c';

    // Master Data Setting / Case Stage field API names
    public static final String FIELD_NATURE_OF_CASE = 'FEC_Nature_Of_Case__c';
    public static final String FIELD_STAGE_NAME = 'FEC_Stage_Name__c';
    public static final String FIELD_FIELD_MANDATORY = 'FEC_Field_Mandatory__c';
    public static final String FIELD_FIELD_READONLY = 'FEC_Field_ReadOnly__c';
    public static final String FIELD_SECTION = 'FEC_Section__c';
    public static final String FIELD_FIELD_OBJECT_NAME = 'FEC_Field_Object_Name__c';
    public static final String FIELD_FIELD_API_NAME = 'FEC_Field_API_Name__c';
    public static final String FIELD_FIELD_LABEL_NAME = 'FEC_Field_Label_Name__c';
    public static final String FIELD_ADDITIONAL_FIELD = 'FEC_Additional_Field__c';
    public static final String FIELD_APPLICABLE_ROLE = 'FEC_Applicable_Role__c';
    public static final String FIELD_FIELD_ORDER_DISPLAY = 'FEC_Field_Order_Display__c';
    public static final String FIELD_FIELD_STATUS = 'FEC_Field_Status__c';
    public static final String FIELD_FIELD_MASKING = 'FEC_Field_Masking__c';
    public static final String FIELD_MASKING_TYPE = 'FEC_Masking_Type__c';
    public static final String FIELD_FIELD_REVERTED = 'FEC_Field_Reverted__c';
    public static final String FIELD_SUB_SECTION = 'FEC_Sub_Section__c';
    public static final String FIELD_SUB_SECTION_FIELD_LAYOUT = 'FEC_Sub_Section_Field_Layout__c';
    public static final String FIELD_SUB_SECTION_LAYOUT = 'FEC_Sub_Section_Layout__c';
    public static final String FIELD_SUB_SECTION_ORDER = 'FEC_Sub_Section_Order__c';
    public static final String FIELD_EDITABLE_USER_GROUP = 'FEC_Editable_User_Group__c';
    public static final String FIELD_FIELD_EDITABLE = 'FEC_Field_Editable__c';
    public static final String FIELD_EDITABLE_ROLE = 'FEC_Editable_Role__c';

    // Nature of Case field API names
    public static final String FIELD_CUSTOMER_TYPE = 'FEC_Customer_Type__c';
    public static final String FIELD_BUSINESS_PROCESS = 'FEC_Business_Process__c';
    public static final String FIELD_PRODUCT_TYPE = 'FEC_Product_Type__c';
    public static final String FIELD_PRODUCT_TYPE_STATUS = 'FEC_Product_Type_Status__c';
    public static final String FIELD_CATEGORY = 'FEC_Category__c';
    public static final String FIELD_CATEGORY_STATUS = 'FEC_Category_Status__c';
    public static final String FIELD_SUB_CATEGORY = 'FEC_Sub_Category__c';
    public static final String FIELD_SUB_CATEGORY_STATUS = 'FEC_Sub_Category_Status__c';
    public static final String FIELD_SUB_CODE = 'FEC_Sub_Code__c';
    public static final String FIELD_SUB_CODE_STATUS = 'FEC_Sub_Code_Status__c';
    public static final String FIELD_USER_GROUP = 'FEC_User_Group__c';
    public static final String FIELD_DEFAULT_STAGE = 'FEC_Default_Stage__c';
    public static final String FIELD_STATUS_NAME = 'FEC_Status_Name__c';
    public static final String FIELD_NATURE_OF_CASES = 'FEC_Nature_of_Cases__c';

    // Stage Change field API names
    public static final String FIELD_PREVIOUS_STAGE = 'FEC_Previous_Stage__c';
    public static final String FIELD_ACTION_BUTTON = 'FEC_Action_Button__c';
    public static final String FIELD_NEXT_STAGE = 'FEC_Next_Stage__c';
    public static final String FIELD_NEXT_QUEUE = 'FEC_Next_Queue__c';
    public static final String FIELD_TEAM_USER_GROUP = 'FEC_Team_User_Group__c';

    // Stage Change Condition field API names
    public static final String FIELD_STAGE_CHANGE = 'FEC_Stage_Change__c';
    public static final String FIELD_MASTER_DATA_SETTING = 'FEC_Master_Data_Setting__c';
    public static final String FIELD_OPERATOR = 'FEC_Operator__c';
    public static final String FIELD_VALUE = 'FEC_Value__c';
    public static final String FIELD_VALUE_TYPE = 'FEC_Value_Type__c';

    // Decision Rule field API names
    public static final String FIELD_PRIORITY = 'FEC_Priority__c';
    public static final String FIELD_TABLE_KEY = 'FEC_Table_Key__c';
    public static final String FIELD_KEY_ID = 'FEC_Key_ID__c';

    // Decision Condition field API names
    public static final String FIELD_DECISION_RULE = 'FEC_Decision_Rule__c';
    public static final String FIELD_LABEL = 'FEC_Label__c';
    public static final String FIELD_EXPRESSION = 'FEC_Expression__c';

    // Nature of Case — Sub-Process checkbox fields
    public static final String FIELD_DO_NOT_BOTHER = 'FEC_Do_Not_Bother__c';
    public static final String FIELD_TRANSFER_CALL_TO_COLLECTION = 'FEC_Transfer_Call_To_Collection__c';
    public static final String FIELD_REMOVE_PHONE = 'FEC_Remove_Phone__c';

    // Hold Case Config field API names
    public static final String FIELD_HOLD_CASE_TYPE = 'Hold_Case_Type__c';
    public static final String FIELD_NFU_CODE = 'FEC_NFU_Code__c';
    public static final String FIELD_CHANGED_STATUS = 'FEC_Changed_Status__c';
    public static final String FIELD_CURRENT_STATUS = 'FEC_Current_Status__c';
    public static final String FIELD_USER = 'FEC_User__c';
    public static final String FIELD_CASE_STAGE = 'FEC_Case_Stage__c';
    public static final String FIELD_HOLD_CASE_NOC = 'FEC_Nature_of_Case__c';
    public static final String FIELD_REASON_VN = 'FEC_Reason_VN__c';

    // NOC lookup field API names
    public static final String NOC_FIELD_PRODUCT_TYPE = 'FEC_Product_Type__c';
    public static final String NOC_FIELD_BUSINESS_PROCESS = 'FEC_Business_Process__c';
    public static final String NOC_FIELD_CATEGORY = 'FEC_Category__c';
    public static final String NOC_FIELD_SUB_CATEGORY = 'FEC_Sub_Category__c';
    public static final String NOC_FIELD_SUB_CODE = 'FEC_Sub_Code__c';

    // Relationship names for lookups (SObject.Rel__r)
    public static final String REL_NATURE_OF_CASE = 'FEC_Nature_Of_Case__r';
    public static final String REL_ADDITIONAL_FIELD = 'FEC_Additional_Field__r';
    public static final String REL_STAGE_NAME = 'FEC_Stage_Name__r';
    public static final String REL_PRODUCT_TYPE_NAME = 'FEC_Product_Type__r';
    public static final String REL_BUSINESS_PROCESS_NAME = 'FEC_Business_Process__r';
    public static final String REL_CATEGORY_NAME = 'FEC_Category__r';
    public static final String REL_SUB_CATEGORY_NAME = 'FEC_Sub_Category__r';
    public static final String REL_SUB_CODE_NAME = 'FEC_Sub_Code__r';
    public static final String REL_ADDITIONAL_FIELD_LIST = 'FEC_Additional_Field__r';
}