import LABEL_COL_CHANNEL from '@salesforce/label/c.FEC_Col_Channel';
import LABEL_COL_APPLICABLE_ROLE from '@salesforce/label/c.FEC_Col_Applicable_Role';
import LABEL_COL_PROPERTY_NAME from '@salesforce/label/c.FEC_Col_Property_Name';
import LABEL_COL_SECTION from '@salesforce/label/c.FEC_Col_Section';
import LABEL_COL_ORDER from '@salesforce/label/c.FEC_Col_Order';
import LABEL_COL_STATUS from '@salesforce/label/c.FEC_Col_Status';
import LABEL_LABEL_READONLY from '@salesforce/label/c.FEC_Label_ReadOnly';
import LABEL_LABEL_MANDATORY from '@salesforce/label/c.FEC_Label_Mandatory';
import LABEL_ACTION_EDIT from '@salesforce/label/c.FEC_Action_Edit';
import LABEL_ACTION_DELETE from '@salesforce/label/c.FEC_Action_Delete';
import LABEL_COL_CHANNEL_ID from '@salesforce/label/c.FEC_Col_Channel_ID';
import LABEL_COL_CHANNEL_VN_NAME from '@salesforce/label/c.FEC_Col_Channel_VN_Name';
import LABEL_COL_CHANNEL_STATUS from '@salesforce/label/c.FEC_Col_Channel_Status';
import LABEL_COL_NAME from '@salesforce/label/c.FEC_Col_Name';
import LABEL_BUTTON_SAVE_CHANNEL from '@salesforce/label/c.FEC_Button_Save_Channel';
import LABEL_BUTTON_ADD_CHANNEL from '@salesforce/label/c.FEC_Button_Add_Channel';
import LABEL_BUTTON_CANCEL_EDIT from '@salesforce/label/c.FEC_Button_Cancel_Edit';
import LABEL_BUTTON_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_CONFIRM_DELETE_CHANNEL from '@salesforce/label/c.FEC_Confirm_Delete_Channel';
import LABEL_TOAST_SAVE_SUCCESS from '@salesforce/label/c.FEC_Toast_Save_Success';
import LABEL_TOAST_DELETE_SUCCESS from '@salesforce/label/c.FEC_Toast_Delete_Success';
import LABEL_TOAST_ERROR_GENERIC from '@salesforce/label/c.FEC_Toast_Error_Generic';
import LABEL_ERROR_INVALID_RECORD_ID from '@salesforce/label/c.LABEL_ERROR_INVALID_RECORD_ID';

// Export Labels for shared usage
export {
    LABEL_ACTION_EDIT,
    LABEL_ACTION_DELETE,
    LABEL_COL_CHANNEL_ID,
    LABEL_COL_CHANNEL_VN_NAME,
    LABEL_COL_CHANNEL_STATUS,
    LABEL_COL_NAME,
    LABEL_BUTTON_SAVE_CHANNEL,
    LABEL_BUTTON_ADD_CHANNEL,
    LABEL_BUTTON_CANCEL_EDIT,
    LABEL_BUTTON_CANCEL,
    LABEL_CONFIRM_DELETE_CHANNEL,
    LABEL_TOAST_SAVE_SUCCESS,
    LABEL_TOAST_DELETE_SUCCESS,
    LABEL_TOAST_ERROR_GENERIC,
    LABEL_ERROR_INVALID_RECORD_ID
};

// Field API name constants
export const FIELD_SECTION = 'FEC_Section__c';
export const FIELD_FIELD_ORDER_DISPLAY = 'FEC_Field_Order_Display__c';
export const FIELD_CHANNEL = 'FEC_Channel__c';
export const FIELD_APPLICABLE_ROLE = 'FEC_Applicable_Role__c';
export const FIELD_ADDITIONAL_FIELD = 'FEC_Additional_Field__c';
export const FIELD_FIELD_STATUS = 'FEC_Field_Status__c';
export const FIELD_FIELD_READONLY = 'FEC_Field_ReadOnly__c';
export const FIELD_FIELD_MANDATORY = 'FEC_Field_Mandatory__c';
export const FIELD_NATURE_OF_CASE = 'FEC_Nature_Of_Case__c';
export const FIELD_STAGE_NAME = 'FEC_Stage_Name__c';
export const DATA_NAME_CHANNELS = 'channels';
export const DATA_NAME_ROLES = 'roles';

// Additional field constants used by modal
export const FIELD_FIELD_OBJECT_NAME = 'FEC_Field_Object_Name__c';
export const FIELD_FIELD_API_NAME = 'FEC_Field_API_Name__c';
export const FIELD_FIELD_LABEL_NAME = 'FEC_Field_Label_Name__c';
export const FIELD_EDITABLE_ROLE = 'FEC_Editable_Role__c';
export const FIELD_CASE_CHANNEL = 'FEC_Case_Channel__c';
export const FIELD_FIELD_EDITABLE = 'FEC_Field_Editable__c';
export const FIELD_DATA_INTEGRATION_MAPPING = 'FEC_Data_Integration_Mapping__c';
export const FIELD_FIELD_MASKING = 'FEC_Field_Masking__c';
export const FIELD_MASKING_TYPE = 'FEC_Masking_Type__c';
export const FIELD_FIELD_REVERTED = 'FEC_Field_Reverted__c';
export const FIELD_SUB_SECTION = 'FEC_Sub_Section__c';
export const FIELD_SUB_SECTION_FIELD_LAYOUT = 'FEC_Sub_Section_Field_Layout__c';
export const FIELD_SUB_SECTION_LAYOUT = 'FEC_Sub_Section_Layout__c';
export const FIELD_SUB_SECTION_ORDER = 'FEC_Sub_Section_Order__c';
export const FIELD_EDITABLE_USER_GROUP = 'FEC_Editable_User_Group__c';
export const DATA_NAME_EDITABLE_USER_GROUPS = 'editableUserGroups';

// Default Integration Channel Code (must match FEC_FraudConstantCommon.DEFAULT_CHANNEL_INTEGRATION_CODE in Apex)
export const DEFAULT_CHANNEL_INTEGRATION_CODE = 'FIMA';

// sObject API name constants for lookup calls
export const SOBJECT_CASE_STAGE = 'FEC_Case_Stage__c';
export const SOBJECT_ADDITIONAL_FIELD = 'FEC_MDM_Additional_Field__c';

// FEC MDM Additional Field constants
export const OBJECT_MDM_ADDITIONAL_FIELD = 'FEC_MDM_Additional_Field__c';
export const FIELD_FEC_UNIQUE_ID = 'FEC_Unique_ID__c';

// Data types
export const TYPE_TEXT = 'text';
export const TYPE_BOOLEAN = 'boolean';
export const TYPE_NUMBER = 'number';

// Icons
export const ICON_CHEVRON_RIGHT = 'utility:chevronright';
export const ICON_CHEVRON_DOWN = 'utility:chevrondown';
export const ICON_ARROW_UP = 'utility:arrowup';
export const ICON_ARROW_DOWN = 'utility:arrowdown';
export const ICON_FALLBACK = 'utility:info';

// Icons used by Master Data Review
export const ICON_NEW = 'utility:new';
export const ICON_UPDATED = 'utility:change_record_type';
export const ICON_SYNCED = 'utility:check';

// Status values
export const STATUS_NEW = 'New';
export const STATUS_UPDATE = 'Update';

// Customer type values
export const CUST_TYPE_NON_EXISTING = 'Non-existing';
export const CUST_TYPE_EXISTING = 'Existing';
export const CUST_TYPE_ALL = 'All';

// CSS class constants
export const CSS_BASE_SML_LEFT = 'slds-m-left_xx-small';
export const CSS_STAGE_BOX = 'stage-box';
export const CSS_STAGE_BOX_ACTIVE = 'stage-box active';
export const CUST_CLASS_ALL = 'cust-all';
export const CUST_CLASS_NON_EXISTING = 'cust-non-existing';
export const CUST_CLASS_EXISTING = 'cust-existing';

// Default sorting
export const DEFAULT_SORT_FIELD = FIELD_FIELD_ORDER_DISPLAY;
export const DEFAULT_SORT_DIRECTION_ASC = 'asc';
export const DEFAULT_SORT_DIRECTION_DESC = 'desc';

// Computed/flattened field name for Additional Field display
export const FIELD_ADDITIONAL_FIELD_NAME = 'FEC_Additional_Field_Name';

// Title CSS classes for section headers
export const TITLE_CLASS_SUCCESS = 'slds-text-color_success';
export const TITLE_CLASS_ERROR = 'slds-text-color_error';
export const TITLE_CLASS_WEAK = 'slds-text-color_weak';

// Misc constants
export const FIELD_OBJECT_FRAUD_INTEGRATION = 'Fraud Integration';

// Event and variant names (used by components)
export const EVENT_REFRESH_ALL = 'refreshall';
export const EVENT_HANDLE_STAGE_CLICK = 'handlestageclick';
export const EVENT_SAVE_CONFIG = 'saveconfig';
export const VARIANT_SUCCESS = 'success';
export const VARIANT_ERROR = 'error';
export const VARIANT_INFO = 'info';

// Section keys used in review component
export const SECTION_NEW = 'newList';
export const SECTION_UPDATED = 'updateList';
export const SECTION_SYNCED = 'syncedList';

// Object type name constants (used across components)
export const OBJ_PRODUCT_TYPE = 'Product Type';
export const OBJ_BUSINESS_PROCESS = 'Business Process';
export const OBJ_CATEGORY = 'Category';
export const OBJ_SUB_CATEGORY = 'Sub Category';
export const OBJ_SUB_CODE = 'Sub Code';

// Component tags
export const TAG_NATURE_TREE = 'fecNatureOfCaseTree';

// Prefix constants for tree nodes
export const PREFIX_PT = 'PT';
export const PREFIX_BP = 'BP';
export const PREFIX_CAT = 'CAT';
export const PREFIX_SCAT = 'SCAT';
export const PREFIX_SC = 'SCODE';

// Icons for tree item toggle
export const ICON_TOGGLE_ADD = 'utility:add';
export const ICON_TOGGLE_DASH = 'utility:dash';

// Status CSS classes
export const STATUS_CLASS_BLUE = 'blue-record-icon';
export const STATUS_CLASS_RED = 'red-record-icon';
export const STATUS_CLASS_YELLOW = 'yellow-record-icon';

// Display field constants
export const DISPLAY_FIELD_CODE = 'Code';
export const DISPLAY_FIELD_ALIAS = 'Alias';
export const DISPLAY_FIELD_NAME_VN = 'nameVN';
export const DISPLAY_FIELD_NAME_EN = 'NameEN';

// Status filter constants
export const STATUS_ALL = 'ALL';
export const STATUS_ACTIVE = 'ACTIVE';
export const STATUS_INACTIVE = 'INACTIVE';

// Title class constants
export const TITLE_CLASS_BASE = 'card-title-clickable';
export const TITLE_CLASS_SELECTED_SUFFIX = ' is-selected';

// Tree item UI constants
export const ITEM_CLASS_BASE = 'slds-tree__item';
export const ICON_BASE_CLASS = 'slds-m-right_x-small';
export const NODE_SELECTED_CLASS = 'node-selected';

// Status value constants
export const STATUS_VALUE_NEW = 'New';
export const STATUS_VALUE_UPDATE = 'Update';

// NatureOfCase specific field constants
export const FIELD_CODE = 'FEC_Code__c';
export const FIELD_ALIAS = 'FEC_Alias__c';
export const FIELD_NAME = 'Name';
export const FIELD_NAME_VN = 'FEC_Name_VN__c';
export const FIELD_POS_ORDER = 'FEC_Pos_Order__c';
export const FIELD_STATUS = 'FEC_Status__c';
export const FIELD_CUSTOMER_TYPE = 'FEC_Customer_Type__c';

// Lookup field API name constants for parent-child relations
export const FIELD_PRODUCT_TYPE_NAME = 'FEC_Product_Type__c';
export const FIELD_BUSINESS_PROCESS_NAME = 'FEC_Business_Process__c';
export const FIELD_CATEGORY_NAME = 'FEC_Category__c';
export const FIELD_SUB_CATEGORY_NAME = 'FEC_Sub_Category__c';
export const FIELD_FEC_TYPE = 'FEC_Type__c';
// Flattened/computed field constants from NatureOfCaseMDMWrapper API response
export const FIELD_FEC_PRODUCT_TYPE_NAME = 'FEC_Product_Type_Name';
export const FIELD_FEC_BUSINESS_PROCESS_NAME = 'FEC_Business_Process_Name';
export const FIELD_FEC_CATEGORY_NAME = 'FEC_Category_Name';
export const FIELD_FEC_SUB_CATEGORY_NAME = 'FEC_Sub_Category_Name';
export const FIELD_FEC_SUB_CODE = 'FEC_Sub_Code';
export const FIELD_FEC_CUSTOMER_TYPE = 'FEC_Customer_Type';
export const FIELD_PROCESS_STATUS_NAME = 'Process_Change_Status';

// Row Action constants
export const ACTION_EDIT = 'edit';
export const ACTION_DELETE = 'delete';

// Field ID constant
export const FIELD_ID = 'Id';
// Field External ID constant
export const FIELD_EXTERNAL_ID = 'ExternalID';

// FEC Channel Session field constants
export const OBJECT_MDM_CHANNEL = 'FEC_MDM_Channel__c';
export const FIELD_CHANNEL_ID = 'FEC_Channel_ID__c';
export const FIELD_CHANNEL_VN_NAME = 'FEC_Channel_Vietnamese_name__c'; // Note: check internal spelling
export const FIELD_CHANNEL_STATUS = 'FEC_Channel_Status__c';
export const FIELD_SELF_SERVICE_FLAG = 'FEC_Self_Service_Flag__c';

// FEC Additional Field List Value constants
export const OBJECT_MDM_ADDITIONAL_FIELD_LIST_VALUE = 'FEC_MDM_Additional_Field_List_Value__c';
export const FIELD_ORDER = 'FEC_Order__c';
export const FIELD_PARENT_FIELD = 'FEC_Additional_Field__c';
export const FIELD_PROCESS_CHANGE_STATUS = 'Process_Change_Status__c'; // Added
export const FIELD_PROCESS_STATUS = 'Process_Change_Status__c';

// Columns definition for Master Data Setting list (centralized)
export const MASTER_DATA_SETTING_COLUMNS = [
    { label: LABEL_COL_CHANNEL, fieldName: FIELD_CHANNEL, type: TYPE_TEXT, sortable: true },
    { label: LABEL_COL_APPLICABLE_ROLE, fieldName: FIELD_APPLICABLE_ROLE, type: TYPE_TEXT, sortable: true },
    { label: LABEL_COL_PROPERTY_NAME, fieldName: FIELD_ADDITIONAL_FIELD, type: TYPE_TEXT, sortable: true },
    { label: LABEL_COL_SECTION, fieldName: FIELD_SECTION, type: TYPE_TEXT, sortable: true },
    { label: 'Sub Section', fieldName: FIELD_SUB_SECTION, type: TYPE_TEXT, sortable: true },
    { label: 'Sub Section Order', fieldName: FIELD_SUB_SECTION_ORDER, type: TYPE_NUMBER, sortable: true },
    { label: 'Sub Section Layout', fieldName: FIELD_SUB_SECTION_LAYOUT, type: TYPE_NUMBER, sortable: true },
    { label: 'Sub Section Field Layout', fieldName: FIELD_SUB_SECTION_FIELD_LAYOUT, type: TYPE_NUMBER, sortable: true },
    { label: LABEL_COL_STATUS, fieldName: FIELD_FIELD_STATUS, type: TYPE_BOOLEAN, sortable: true },
    { label: LABEL_LABEL_READONLY, fieldName: FIELD_FIELD_READONLY, type: TYPE_BOOLEAN, sortable: true },
    { label: LABEL_LABEL_MANDATORY, fieldName: FIELD_FIELD_MANDATORY, type: TYPE_BOOLEAN, sortable: true },
    { label: 'Editable', fieldName: FIELD_FIELD_EDITABLE, type: TYPE_BOOLEAN, sortable: true },
    { label: 'Masking', fieldName: FIELD_FIELD_MASKING, type: TYPE_BOOLEAN, sortable: true },
    { label: 'Masking Type', fieldName: FIELD_MASKING_TYPE, type: TYPE_TEXT, sortable: true },
    { label: 'Reverted', fieldName: FIELD_FIELD_REVERTED, type: TYPE_BOOLEAN, sortable: true },
    { label: 'Editable Role', fieldName: FIELD_EDITABLE_ROLE, type: TYPE_TEXT, sortable: true },
    { label: LABEL_COL_ORDER, fieldName: FIELD_FIELD_ORDER_DISPLAY, sortable: true },
    { label: 'Process Status', fieldName: FIELD_PROCESS_CHANGE_STATUS, type: TYPE_TEXT, sortable: true },
    { type: 'action', typeAttributes: { rowActions: [ { label: LABEL_ACTION_EDIT, name: 'edit' }, { label: LABEL_ACTION_DELETE, name: 'delete' } ] } }
];

// Process and Object mapping for Detail component
export const OBJECT_MAP = {
    'PT': 'FEC_MDM_Product_Type__c',
    'BP': 'FEC_MDM_Business_Process__c',
    'CAT': 'FEC_MDM_Category__c',
    'SCAT': 'FEC_MDM_Sub_Category__c',
    'SC': 'FEC_MDM_Sub_Code__c'
};

// Icon mapping for node types
export const ICON_MAP = {
    'Product Type': 'custom:custom63',
    'Business Process': 'custom:custom14',
    'Category': 'custom:custom19',
    'Sub Category': 'custom:custom88',
    'Sub Code': 'custom:custom93'
};