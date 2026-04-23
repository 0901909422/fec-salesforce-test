/**
 * FEC_UIConstants
 * Centralized constants for UI-related values used across the FEC module:
 * labels, error messages, CSS classes, icons, status values, placeholders,
 * tree map keys, payload keys, and display prefixes.
 * Extracted from FEC_Constants for better organization and maintainability.
 */
public class FEC_UIConstants {
    // Prevent instantiation
    private FEC_UIConstants() {}

    // ── Success / Error messages (Custom Labels) ──────────────────────────
    public static final String OPERATION_SUCCESS = System.Label.FEC_Operation_Success;
    public static final String ERROR_DELETE_RECORD_PREFIX = System.Label.FEC_Error_Delete_Record_Prefix;
    public static final String ERROR_DELETE_FIELDLIST_PREFIX = System.Label.FEC_Error_Delete_FieldList_Prefix;
    public static final String ERROR_GENERIC_PREFIX = System.Label.FEC_Error_Title;
    public static final String ERROR_CANNOT_START_SYNC = System.Label.FEC_Error_Title;
    public static final String ERROR_CANNOT_START_PUSH = System.Label.FEC_Error_Title;
    public static final String ERROR_INVALID_ID = System.Label.FEC_Error_Title;
    public static final String ERROR_NO_UPDATE_PERMISSION = System.Label.FEC_Error_No_Update_Permission;
    public static final String ERROR_INVALID_FIELD = System.Label.FEC_Error_Invalid_Field;
    public static final String ERROR_NO_FIELD_UPDATE_PERMISSION = System.Label.FEC_Error_No_Field_Update_Permission;
    public static final String ERROR_INVALID_SOBJECT_PREFIX = System.Label.FEC_Error_Invalid_SObject_Prefix;
    public static final String ERROR_DML_PREFIX = System.Label.FEC_Error_DML_Prefix;
    public static final String ERROR_SYSTEM = 'System Error';
    public static final String ERROR_LOOKUP_PREFIX = 'Lookup Error: ';
    public static final String ERROR_COMMON_FIELD_PREFIX = 'commonFieldMap Error ';
    public static final String ERROR_DATA_PREFIX = 'Data Error: ';
    public static final String ERROR_SYNC_FAILED_PREFIX = 'Sync Failed: \n';

    // ── UI labels (Custom Labels) ─────────────────────────────────────────
    public static final String LABEL_NONE = System.Label.FEC_Label_None;
    public static final String LABEL_CHANNEL = System.Label.FEC_Label_Channel;
    public static final String LABEL_SECTION = System.Label.FEC_Label_Section;
    public static final String LABEL_MANDATORY = System.Label.FEC_Label_Mandatory;
    public static final String LABEL_PROPERTY_NAME = System.Label.FEC_Label_Property_Name;
    public static final String LABEL_PRODUCT_TYPE = System.Label.FEC_Label_Product_Type;
    public static final String LABEL_BUSINESS_PROCESS = System.Label.FEC_Label_Business_Process;
    public static final String LABEL_CATEGORY = System.Label.FEC_Label_Category;
    public static final String LABEL_SUB_CATEGORY = System.Label.FEC_Label_Sub_Category;
    public static final String LABEL_SUB_CODE = System.Label.FEC_Label_Sub_Code;
    public static final String LABEL_STAGE_NAME = System.Label.FEC_Label_Stage_Name;
    public static final String LABEL_FIELD_STATUS = System.Label.FEC_Label_Field_Status;
    public static final String LABEL_READONLY = System.Label.FEC_Label_ReadOnly;
    public static final String LABEL_ORDER_DISPLAY = System.Label.FEC_Label_Order_Display;
    public static final String LABEL_APPLICABLE_ROLE = System.Label.FEC_Label_Applicable_Role;
    public static final String LABEL_EDITABLE = System.Label.FEC_Label_Editable;
    public static final String LABEL_EDITABLE_ROLE = System.Label.FEC_Label_Editable_Role;
    public static final String LABEL_MASKING = System.Label.FEC_Label_Masking;
    public static final String LABEL_MASKING_TYPE = System.Label.FEC_Label_Masking_Type;
    public static final String LABEL_REVERTED = System.Label.FEC_Label_Reverted;
    public static final String LABEL_SUB_SECTION = System.Label.FEC_Label_Sub_Section;
    public static final String LABEL_SUB_SECTION_ORDER = System.Label.FEC_Label_Sub_Section_Order;
    public static final String LABEL_SUB_SECTION_LAYOUT = System.Label.FEC_Label_Sub_Section_Layout;
    public static final String LABEL_SUB_SECTION_FIELD_LAYOUT = System.Label.FEC_Label_Sub_Section_Field_Layout;
    public static final String LABEL_CASE_CHANNEL = System.Label.FEC_Label_Case_Channel;
    public static final String LABEL_DATA_INTEGRATION = System.Label.FEC_Label_Data_Integration;
    public static final String LABEL_EDITABLE_USER_GROUP = System.Label.FEC_Label_Editable_User_Group;

    // ── Process status values ─────────────────────────────────────────────
    public static final String PROCESS_STATUS_NEW = 'New';
    public static final String PROCESS_STATUS_UPDATE = 'Update';
    public static final String PROCESS_STATUS_SYNCED = 'Synced';

    // ── CSS classes ───────────────────────────────────────────────────────
    public static final String CSS_WARN = 'slds-theme_warning';

    // ── Icons ─────────────────────────────────────────────────────────────
    public static final String ICON_RECORD = 'utility:record';
    public static final String ICON_LOCK = 'utility:lock';

    // ── Placeholders ──────────────────────────────────────────────────────
    public static final String PLACEHOLDER_EMPTY = '--';

    // ── Tree / Map keys (used in UI tree-building responses) ──────────────
    public static final String MAP_LABEL = 'label';
    public static final String MAP_NAME = 'name';
    public static final String MAP_EXPANDED = 'expanded';
    public static final String MAP_ITEMS = 'items';
    public static final String MAP_PROPERTY_REF = 'propertyRef';
    public static final String MAP_PARENT_NAME = 'parentName';
    public static final String MAP_FIELD_LABEL = 'fieldLabel';
    public static final String MAP_FIELD_API_NAME = 'fieldApiName';
    public static final String MAP_VALUE = 'value';

    // ── Display prefixes (used in UI tree node naming) ────────────────────
    public static final String PT_PREFIX = 'PT_';
    public static final String BP_PREFIX = 'BP_';
    public static final String CAT_PREFIX = 'CAT_';
    public static final String SCAT_PREFIX = 'SCAT_';
    public static final String SCODE_PREFIX = 'SCODE_';

    // ── Payload keys (client-server communication) ────────────────────────
    public static final String PAYLOAD_TYPE = 'type';
    public static final String PAYLOAD_IDTYPE = 'idType';
    public static final String PAYLOAD_NAMEEN = 'NameEN';
    public static final String PAYLOAD_NAMEVN = 'nameVN';
    public static final String PAYLOAD_ALIAS = 'Alias';
    public static final String PAYLOAD_CODE = 'Code';
    public static final String PAYLOAD_POSORDER = 'PosOrder';
    public static final String PAYLOAD_STATUS = 'Status';
    public static final String PAYLOAD_ID = 'id';
}