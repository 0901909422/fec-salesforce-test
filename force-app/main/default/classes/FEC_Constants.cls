/**
 * FEC_Constants
 * Centralized constants for FEC module.
 */
public class FEC_Constants {
    // Prevent instantiation
    private FEC_Constants() {}
    
    // Messages (moved to Custom Labels for i18n)
    public static final String OPERATION_SUCCESS = System.Label.FEC_Operation_Success;
    public static final String ERROR_DELETE_RECORD_PREFIX = System.Label.FEC_Error_Delete_Record_Prefix;
    public static final String ERROR_DELETE_FIELDLIST_PREFIX = System.Label.FEC_Error_Delete_FieldList_Prefix;
    
    // Additional message labels (use generic error title label as fallback)
    public static final String ERROR_GENERIC_PREFIX = System.Label.FEC_Error_Title;
    public static final String ERROR_CANNOT_START_SYNC = System.Label.FEC_Error_Title;
    public static final String ERROR_CANNOT_START_PUSH = System.Label.FEC_Error_Title;
    public static final String ERROR_INVALID_ID = System.Label.FEC_Error_Title;
    
    // Additional permission/field error labels
    public static final String ERROR_NO_UPDATE_PERMISSION = System.Label.FEC_Error_No_Update_Permission;
    public static final String ERROR_INVALID_FIELD = System.Label.FEC_Error_Invalid_Field;
    public static final String ERROR_NO_FIELD_UPDATE_PERMISSION = System.Label.FEC_Error_No_Field_Update_Permission;
    
    // UI labels (moved to Custom Labels for i18n)
    public static final String LABEL_NONE = System.Label.FEC_Label_None;
    public static final String ERROR_INVALID_SOBJECT_PREFIX = System.Label.FEC_Error_Invalid_SObject_Prefix;
    public static final String ERROR_DML_PREFIX = System.Label.FEC_Error_DML_Prefix;
    public static final String PROCESS_STATUS_NEW = 'New';
    public static final String PROCESS_STATUS_UPDATE = 'Update';
    public static final String PROCESS_STATUS_SYNCED = 'Synced';
    
    // Field API names
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
    public static final String FIELD_CHANNEL_ID = 'FEC_Channel_ID__c';
    public static final String FIELD_CHANNEL_STATUS = 'FEC_Channel_Status__c';
    public static final String FIELD_CHANNEL_VI_NAME = 'FEC_Channel_Vietnamese_name__c';
    public static final String FIELD_PROPERTY_REFERENCE = 'Property_Reference__c';
    public static final String FIELD_ACTIVE = 'FEC_Active__c';
    
    // Object API name constants (centralized)
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
    public static final String KEY_PRODUCT_TYPE_PRODUCT = 'Product';
    public static final String KEY_CASE_TYPE = 'CaseType';
    public static final String KEY_CODE_SUCCESS = 'SUCCESS';
    public static final String KEY_GET_CS_DATA_SUCCESS = 'Get CS Master Data successfully';
    
    // Debug / log prefixes
    public static final String DEBUG_NOC_LIST_PREFIX = 'NOC Wrapper List nocList: ';
    public static final String DEBUG_NOC_WRAPPER_PREFIX = 'NOC Wrapper List nocWrapperList: ';
    public static final String DEBUG_SERVICE_TYPE_TREE_PREFIX = 'Service Type Tree Data: ';
    
    // Map keys used in controllers for tree/building responses
    public static final String MAP_LABEL = 'label';
    public static final String MAP_NAME = 'name';
    public static final String MAP_EXPANDED = 'expanded';
    public static final String MAP_ITEMS = 'items';
    public static final String MAP_PROPERTY_REF = 'propertyRef';
    public static final String MAP_PARENT_NAME = 'parentName';
    public static final String MAP_VALUE = 'value';
    
    // UI labels used in comparisons
    public static final String LABEL_CHANNEL = System.Label.FEC_Label_Channel;
    public static final String LABEL_SECTION = System.Label.FEC_Label_Section;
    public static final String LABEL_MANDATORY = System.Label.FEC_Label_Mandatory;
    public static final String LABEL_PROPERTY_NAME = System.Label.FEC_Label_Property_Name;
    
    // UI placeholders / css
    public static final String PLACEHOLDER_EMPTY = '--';
    public static final String CSS_WARN = 'slds-theme_warning';
    
    // Misc errors
    public static final String ERROR_SYSTEM = 'System Error';
    
    // Test flags
    @TestVisible public static Boolean forceException = false;
    
    // AggregateResult alias keys
    public static final String ALIAS_CT = 'ct';
    public static final String ALIAS_P_ID = 'pId';
    public static final String ALIAS_P_CODE = 'pCode';
    public static final String ALIAS_B_ID = 'bId';
    public static final String ALIAS_B_CODE = 'bCode';
    public static final String ALIAS_C_ID = 'cId';
    public static final String ALIAS_C_CODE = 'cCode';
    public static final String ALIAS_SC_ID = 'scId';
    public static final String ALIAS_SC_CODE = 'scCode';
    public static final String ALIAS_SCC_ID = 'sccId';
    public static final String ALIAS_SCC_CODE = 'sccCode';
    
    // Field name constants used as keys in mapping requests (unique declarations only)
    public static final String FIELD_NATURE_OF_CASE = 'FEC_Nature_Of_Case__c';
    public static final String FIELD_STAGE_NAME = 'FEC_Stage_Name__c';
    public static final String FIELD_FIELD_MANDATORY = 'FEC_Field_Mandatory__c';
    public static final String FIELD_FIELD_READONLY = 'FEC_Field_ReadOnly__c';
    public static final String FIELD_SECTION = 'FEC_Section__c';
    public static final String FIELD_FIELD_OBJECT_NAME = 'FEC_Field_Object_Name__c';
    public static final String FIELD_ADDITIONAL_FIELD = 'FEC_Additional_Field__c';
    public static final String FIELD_APPLICABLE_ROLE = 'FEC_Applicable_Role__c';
    public static final String FIELD_CHANNEL = 'FEC_Channel__c';
    public static final String FIELD_CASE_CHANNEL = 'FEC_Case_Channel__c';
    public static final String FIELD_DATA_INTEGRATION_MAPPING = 'FEC_Data_Integration_Mapping__c';
    public static final String FIELD_FIELD_ORDER_DISPLAY = 'FEC_Field_Order_Display__c';
    public static final String FIELD_FIELD_STATUS = 'FEC_Field_Status__c';
    
    // Nature of Case field constants
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
    public static final String FIELD_ROLE_NAMES = 'FEC_Role_Names__c';
    
    // Additional UI labels (use Custom Labels)
    public static final String LABEL_PRODUCT_TYPE = System.Label.FEC_Label_Product_Type;
    public static final String LABEL_BUSINESS_PROCESS = System.Label.FEC_Label_Business_Process;
    public static final String LABEL_CATEGORY = System.Label.FEC_Label_Category;
    public static final String LABEL_SUB_CATEGORY = System.Label.FEC_Label_Sub_Category;
    public static final String LABEL_SUB_CODE = System.Label.FEC_Label_Sub_Code;
    
    // Prefixes
    public static final String PT_PREFIX = 'PT_';
    public static final String BP_PREFIX = 'BP_';
    public static final String CAT_PREFIX = 'CAT_';
    public static final String SCAT_PREFIX = 'SCAT_';
    public static final String SCODE_PREFIX = 'SCODE_';
    
    // Icons
    public static final String ICON_RECORD = 'utility:record';
    public static final String ICON_LOCK = 'utility:lock';
    
    // SQL fragments used in controllers
    public static final String SQL_SELECT_COUNT_DISTINCT = 'SELECT COUNT_DISTINCT(';
    public static final String SQL_FROM_NOC = ') FROM FEC_MDM_Nature_Of_Case__c';
    public static final String SQL_SELECT_NOC_FIELDS = 'SELECT FEC_Product_Type__c, FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c FROM FEC_MDM_Nature_Of_Case__c WHERE ';
    
    // NOC lookup field API names
    public static final String NOC_FIELD_PRODUCT_TYPE = 'FEC_Product_Type__c';
    public static final String NOC_FIELD_BUSINESS_PROCESS = 'FEC_Business_Process__c';
    public static final String NOC_FIELD_CATEGORY = 'FEC_Category__c';
    public static final String NOC_FIELD_SUB_CATEGORY = 'FEC_Sub_Category__c';
    public static final String NOC_FIELD_SUB_CODE = 'FEC_Sub_Code__c';
    
    // Payload keys used in client-server map
    public static final String PAYLOAD_TYPE = 'type';
    public static final String PAYLOAD_IDTYPE = 'idType';
    public static final String PAYLOAD_NAMEEN = 'NameEN';
    public static final String PAYLOAD_NAMEVN = 'nameVN';
    public static final String PAYLOAD_ALIAS = 'Alias';
    public static final String PAYLOAD_CODE = 'Code';
    public static final String PAYLOAD_POSORDER = 'PosOrder';
    public static final String PAYLOAD_STATUS = 'Status';
    public static final String PAYLOAD_ID = 'id';
    
    // Aggregate result alias used for COUNT_DISTINCT
    public static final String AGG_EXPR0 = 'expr0';
    
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
    
    // Specific error prefixes used in batch
    public static final String ERROR_LOOKUP_PREFIX = 'Lookup Error: ';
    public static final String ERROR_COMMON_FIELD_PREFIX = 'commonFieldMap Error ';
    public static final String ERROR_DATA_PREFIX = 'Data Error: ';
    public static final String ERROR_SYNC_FAILED_PREFIX = 'Sync Failed: \n';

    // Call api FEC_GetCSMasterDataService
    public static final String KEY_PICKLIST = 'Picklist';
    public static final String KEY_CHECKBOX = 'Checkbox';
    public static final String KEY_DATE = 'Date';
    public static final String KEY_DATETIME = 'DateTime';
    public static final String KEY_NUMBER = 'Number';
    public static final String KEY_TEXT = 'Text';
    
    // Stage Change & Action Button Objects
    public static final String OBJ_STAGE_CHANGE              = 'FEC_Stage_Change__c';
    public static final String OBJ_ACTION_BUTTON             = 'FEC_Action_Button__c';
    public static final String OBJ_MDM_STAGE_CHANGE          = 'FEC_MDM_Stage_Change__c';
    public static final String OBJ_MDM_ACTION_BUTTON         = 'FEC_MDM_Action_Button__c';

    // Stage Change Fields
    public static final String FIELD_PREVIOUS_STAGE          = 'FEC_Previous_Stage__c';
    public static final String FIELD_ACTION_BUTTON           = 'FEC_Action_Button__c';
    public static final String FIELD_NEXT_STAGE              = 'FEC_Next_Stage__c';
    public static final String FIELD_NEXT_QUEUE              = 'FEC_Next_Queue__c';
    public static final String FIELD_TEAM_USER_GROUP         = 'FEC_Team_User_Group__c';
}