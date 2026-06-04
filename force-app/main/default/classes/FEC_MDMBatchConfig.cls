/**
 * FEC_MDMBatchConfig
 * Centralized configuration for MDM Sync and Push batches.
 * Contains all shared maps, sets, and lists used by both
 * FEC_SyncMasterDataBatch (Live → MDM) and FEC_PushMDMToLiveBatch (MDM → Live).
 *
 * When adding a new MDM object or field, update ONLY this class.
 * Both batches will automatically pick up the changes.
 *
 * @author DAT NGO
 */
public class FEC_MDMBatchConfig {
    private FEC_MDMBatchConfig() {}

    // ── Common constants used by both batches ──
    public static final String FIELD_CODE                  = FEC_FieldConstants.FIELD_CODE;
    public static final String FIELD_NAME                  = FEC_FieldConstants.FIELD_NAME;
    public static final String FIELD_PROCESS_CHANGE_STATUS = FEC_FieldConstants.FIELD_PROCESS_CHANGE_STATUS;
    public static final String PROCESS_STATUS_NEW          = FEC_UIConstants.PROCESS_STATUS_NEW;
    public static final String PROCESS_STATUS_UPDATE       = FEC_UIConstants.PROCESS_STATUS_UPDATE;
    public static final String PROCESS_STATUS_SYNCED       = FEC_UIConstants.PROCESS_STATUS_SYNCED;
    public static final String PROCESS_STATUS_DELETED      = FEC_UIConstants.PROCESS_STATUS_DELETED;
    public static final String MDM_FIELD_KEY               = 'mdmField';
    public static final String MDM_OBJ_KEY                 = 'mdmObj';

    // ── Shorthand aliases (keep private, used only within this class) ──
    private static final String F_CODE                  = FEC_FieldConstants.FIELD_CODE;
    private static final String F_NAME                  = FEC_FieldConstants.FIELD_NAME;
    private static final String F_ALIAS                 = FEC_FieldConstants.FIELD_ALIAS;
    private static final String F_NAME_VN               = FEC_FieldConstants.FIELD_NAME_VN;
    private static final String F_STATUS                = FEC_FieldConstants.FIELD_STATUS;
    private static final String F_ACTIVE                = FEC_FieldConstants.FIELD_ACTIVE;
    private static final String F_POS_ORDER             = FEC_FieldConstants.FIELD_POS_ORDER;
    private static final String F_UNIQUE_ID             = FEC_FieldConstants.FIELD_FEC_UNIQUE_ID;
    private static final String F_TYPE                  = FEC_FieldConstants.FIELD_FEC_TYPE;
    private static final String F_ORDER                 = FEC_FieldConstants.FIELD_FEC_ORDER;
    private static final String F_FIELD_MANDATORY       = FEC_FieldConstants.FIELD_FIELD_MANDATORY;
    private static final String F_FIELD_STATUS          = FEC_FieldConstants.FIELD_FIELD_STATUS;
    private static final String F_FIELD_READONLY        = FEC_FieldConstants.FIELD_FIELD_READONLY;
    private static final String F_FIELD_OBJ_NAME        = FEC_FieldConstants.FIELD_FIELD_OBJECT_NAME;
    private static final String F_FIELD_ORDER_DISPLAY   = FEC_FieldConstants.FIELD_FIELD_ORDER_DISPLAY;
    private static final String F_PROPERTY_REF          = FEC_FieldConstants.FIELD_PROPERTY_REFERENCE;
    private static final String F_SECTION               = FEC_FieldConstants.FIELD_SECTION;
    private static final String F_APPLICABLE_ROLE       = FEC_FieldConstants.FIELD_APPLICABLE_ROLE;
    private static final String F_DATA_INT_MAPPING      = FEC_FieldConstants.FIELD_DATA_INTEGRATION_MAPPING;
    private static final String F_CHANNEL_ID            = FEC_FieldConstants.FIELD_CHANNEL_ID;
    private static final String F_CHANNEL_STATUS        = FEC_FieldConstants.FIELD_CHANNEL_STATUS;
    private static final String F_CHANNEL_VI_NAME       = FEC_FieldConstants.FIELD_CHANNEL_VI_NAME;
    private static final String F_SELF_SERVICE_FLAG     = FEC_FieldConstants.FIELD_SELF_SERVICE_FLAG;
    private static final String F_CHANNEL               = FEC_FieldConstants.FIELD_CHANNEL;
    private static final String F_NOC                   = FEC_FieldConstants.FIELD_NATURE_OF_CASE;
    private static final String F_NOCS                  = FEC_FieldConstants.FIELD_NATURE_OF_CASES;
    private static final String F_STAGE_NAME            = FEC_FieldConstants.FIELD_STAGE_NAME;
    private static final String F_ADDITIONAL_FIELD      = FEC_FieldConstants.FIELD_ADDITIONAL_FIELD;
    private static final String F_CUSTOMER_TYPE         = FEC_FieldConstants.FIELD_CUSTOMER_TYPE;
    private static final String F_BP                    = FEC_FieldConstants.FIELD_BUSINESS_PROCESS;
    private static final String F_PT                    = FEC_FieldConstants.FIELD_PRODUCT_TYPE;
    private static final String F_PT_STATUS              = FEC_FieldConstants.FIELD_PRODUCT_TYPE_STATUS;
    private static final String F_CAT                   = FEC_FieldConstants.FIELD_CATEGORY;
    private static final String F_CAT_STATUS            = FEC_FieldConstants.FIELD_CATEGORY_STATUS;
    private static final String F_SUBCAT                = FEC_FieldConstants.FIELD_SUB_CATEGORY;
    private static final String F_SUBCAT_STATUS         = FEC_FieldConstants.FIELD_SUB_CATEGORY_STATUS;
    private static final String F_SUBCODE               = FEC_FieldConstants.FIELD_SUB_CODE;
    private static final String F_SUBCODE_STATUS        = FEC_FieldConstants.FIELD_SUB_CODE_STATUS;
    private static final String F_USER_GROUP            = FEC_FieldConstants.FIELD_USER_GROUP;
    private static final String F_DEFAULT_STAGE         = FEC_FieldConstants.FIELD_DEFAULT_STAGE;
    private static final String F_END_STAGE             = FEC_FieldConstants.FIELD_END_STAGE;
    private static final String F_STATUS_NAME           = FEC_FieldConstants.FIELD_STATUS_NAME;
    private static final String F_FIELD_MASKING         = FEC_FieldConstants.FIELD_FIELD_MASKING;
    private static final String F_MASKING_TYPE          = FEC_FieldConstants.FIELD_MASKING_TYPE;
    private static final String F_FIELD_REVERTED        = FEC_FieldConstants.FIELD_FIELD_REVERTED;
    private static final String F_SUB_SECTION           = FEC_FieldConstants.FIELD_SUB_SECTION;
    private static final String F_SUB_SECTION_FL        = FEC_FieldConstants.FIELD_SUB_SECTION_FIELD_LAYOUT;
    private static final String F_SUB_SECTION_L         = FEC_FieldConstants.FIELD_SUB_SECTION_LAYOUT;
    private static final String F_SUB_SECTION_O         = FEC_FieldConstants.FIELD_SUB_SECTION_ORDER;
    private static final String F_EDIT_UG               = FEC_FieldConstants.FIELD_EDITABLE_USER_GROUP;
    private static final String F_FIELD_EDITABLE        = FEC_FieldConstants.FIELD_FIELD_EDITABLE;
    private static final String F_EDIT_ROLE             = FEC_FieldConstants.FIELD_EDITABLE_ROLE;
    private static final String F_FIELD_LABEL_NAME      = FEC_FieldConstants.FIELD_FIELD_LABEL_NAME;
    private static final String F_FIELD_API_NAME        = FEC_FieldConstants.FIELD_FIELD_API_NAME;
    // NOC Sub-Process
    private static final String F_DNB                   = FEC_FieldConstants.FIELD_DO_NOT_BOTHER;
    private static final String F_TRANSFER_CALL         = FEC_FieldConstants.FIELD_TRANSFER_CALL_TO_COLLECTION;
    private static final String F_REMOVE_PHONE          = FEC_FieldConstants.FIELD_REMOVE_PHONE;
    // Stage Change
    private static final String F_PREV_STAGE            = FEC_FieldConstants.FIELD_PREVIOUS_STAGE;
    private static final String F_ACTION_BTN            = FEC_FieldConstants.FIELD_ACTION_BUTTON;
    private static final String F_NEXT_STAGE            = FEC_FieldConstants.FIELD_NEXT_STAGE;
    private static final String F_NEXT_QUEUE            = FEC_FieldConstants.FIELD_NEXT_QUEUE;
    private static final String F_TEAM_UG               = FEC_FieldConstants.FIELD_TEAM_USER_GROUP;
    // Stage Change Condition
    private static final String F_STAGE_CHANGE          = FEC_FieldConstants.FIELD_STAGE_CHANGE;
    private static final String F_MDS                   = FEC_FieldConstants.FIELD_MASTER_DATA_SETTING;
    private static final String F_OPERATOR              = FEC_FieldConstants.FIELD_OPERATOR;
    private static final String F_VALUE                 = FEC_FieldConstants.FIELD_VALUE;
    private static final String F_VALUE_TYPE            = FEC_FieldConstants.FIELD_VALUE_TYPE;
    // Decision Rule/Condition
    private static final String F_PRIORITY              = FEC_FieldConstants.FIELD_PRIORITY;
    private static final String F_TABLE_KEY             = FEC_FieldConstants.FIELD_TABLE_KEY;
    private static final String F_KEY_ID                = FEC_FieldConstants.FIELD_KEY_ID;
    private static final String F_DECISION_RULE         = FEC_FieldConstants.FIELD_DECISION_RULE;
    private static final String F_LABEL                 = FEC_FieldConstants.FIELD_LABEL;
    private static final String F_EXPRESSION            = FEC_FieldConstants.FIELD_EXPRESSION;
    // Hold Case Config
    private static final String F_HCC_TYPE              = FEC_FieldConstants.FIELD_HOLD_CASE_TYPE;
    private static final String F_NFU_CODE              = FEC_FieldConstants.FIELD_NFU_CODE;
    private static final String F_CHANGED_STATUS        = FEC_FieldConstants.FIELD_CHANGED_STATUS;
    private static final String F_CURRENT_STATUS        = FEC_FieldConstants.FIELD_CURRENT_STATUS;
    private static final String F_USER                  = FEC_FieldConstants.FIELD_USER;
    private static final String F_CASE_STAGE            = FEC_FieldConstants.FIELD_CASE_STAGE;
    private static final String F_HCC_NOC              = FEC_FieldConstants.FIELD_HOLD_CASE_NOC;
    private static final String F_REASON_VN            = FEC_FieldConstants.FIELD_REASON_VN;

    // ── Object shorthand ──
    private static final String MDM_PT   = FEC_ObjectConstants.OBJ_MDM_PRODUCT_TYPE;
    private static final String MDM_BP   = FEC_ObjectConstants.OBJ_MDM_BUSINESS_PROCESS;
    private static final String MDM_CAT  = FEC_ObjectConstants.OBJ_MDM_CATEGORY;
    private static final String MDM_SCAT = FEC_ObjectConstants.OBJ_MDM_SUB_CATEGORY;
    private static final String MDM_SC   = FEC_ObjectConstants.OBJ_MDM_SUB_CODE;
    private static final String MDM_NOC  = FEC_ObjectConstants.OBJ_MDM_NATURE_OF_CASE;
    private static final String MDM_CH   = FEC_ObjectConstants.OBJ_MDM_CHANNEL;
    private static final String MDM_CS   = FEC_ObjectConstants.OBJ_MDM_CASE_STAGE;
    private static final String MDM_AF   = FEC_ObjectConstants.OBJ_MDM_ADDITIONAL_FIELD;
    private static final String MDM_AFLV = FEC_ObjectConstants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE;
    private static final String MDM_MDS  = FEC_ObjectConstants.OBJ_MDM_MASTER_DATA_SETTING;
    private static final String MDM_AB   = FEC_ObjectConstants.OBJ_MDM_ACTION_BUTTON;
    private static final String MDM_STCH = FEC_ObjectConstants.OBJ_MDM_STAGE_CHANGE;
    private static final String MDM_SCC  = FEC_ObjectConstants.OBJ_MDM_STAGE_CHANGE_CONDITION;
    private static final String MDM_DR   = FEC_ObjectConstants.OBJ_MDM_DECISION_RULE;
    private static final String MDM_DC   = FEC_ObjectConstants.OBJ_MDM_DECISION_CONDITION;
    private static final String MDM_HCC  = FEC_ObjectConstants.OBJ_MDM_HOLD_CASE_CONFIG;
    private static final String MDM_NFU  = FEC_ObjectConstants.OBJ_MDM_NFU_CODE;

    private static final String LIVE_PT   = FEC_ObjectConstants.OBJ_PRODUCT_TYPE;
    private static final String LIVE_BP   = FEC_ObjectConstants.OBJ_BUSINESS_PROCESS;
    private static final String LIVE_CAT  = FEC_ObjectConstants.OBJ_CATEGORY;
    private static final String LIVE_SCAT = FEC_ObjectConstants.OBJ_SUB_CATEGORY;
    private static final String LIVE_SC   = FEC_ObjectConstants.OBJ_SUB_CODE;
    private static final String LIVE_NOC  = FEC_ObjectConstants.OBJ_NATURE_OF_CASE;
    private static final String LIVE_CH   = FEC_ObjectConstants.OBJ_CHANNEL;
    private static final String LIVE_CS   = FEC_ObjectConstants.OBJ_CASE_STAGE;
    private static final String LIVE_AF   = FEC_ObjectConstants.OBJ_ADDITIONAL_FIELD;
    private static final String LIVE_AFLV = FEC_ObjectConstants.OBJ_ADDITIONAL_FIELD_LIST_VALUE;
    private static final String LIVE_MDS  = FEC_ObjectConstants.OBJ_MASTER_DATA_SETTING;
    private static final String LIVE_AB   = FEC_ObjectConstants.OBJ_ACTION_BUTTON;
    private static final String LIVE_STCH = FEC_ObjectConstants.OBJ_STAGE_CHANGE;
    private static final String LIVE_SCC  = FEC_ObjectConstants.OBJ_STAGE_CHANGE_CONDITION;
    private static final String LIVE_DR   = FEC_ObjectConstants.OBJ_DECISION_RULE;
    private static final String LIVE_DC   = FEC_ObjectConstants.OBJ_DECISION_CONDITION;
    private static final String LIVE_HCC  = FEC_ObjectConstants.OBJ_HOLD_CASE_CONFIG;
    private static final String LIVE_NFU  = FEC_ObjectConstants.OBJ_NFU_CODE;

    // ═══════════════════════════════════════════════════════
    // PUBLIC API — accessed by both Push and Sync batches
    // ═══════════════════════════════════════════════════════

    /** Execution order — determines batch scope sequence. */
    public static final List<String> EXECUTION_ORDER = new List<String>{
        MDM_BP, MDM_AF, MDM_PT, MDM_CAT, MDM_SCAT, MDM_SC,
        MDM_CH, MDM_CS, MDM_NOC, MDM_AFLV, MDM_MDS,
        MDM_AB, MDM_STCH, MDM_SCC,
        MDM_DR, MDM_DC,
        MDM_HCC, MDM_NFU
    };

    /** MDM object → Live object mapping. */
    public static final Map<String, String> MDM_TO_LIVE_MAP = new Map<String, String>{
        MDM_PT   => LIVE_PT,   MDM_BP   => LIVE_BP,
        MDM_CAT  => LIVE_CAT,  MDM_SCAT => LIVE_SCAT,
        MDM_SC   => LIVE_SC,   MDM_NOC  => LIVE_NOC,
        MDM_CH   => LIVE_CH,   MDM_CS   => LIVE_CS,
        MDM_AF   => LIVE_AF,   MDM_AFLV => LIVE_AFLV,
        MDM_MDS  => LIVE_MDS,  MDM_AB   => LIVE_AB,
        MDM_STCH => LIVE_STCH, MDM_SCC  => LIVE_SCC,
        MDM_DR   => LIVE_DR,   MDM_DC   => LIVE_DC,
        MDM_HCC  => LIVE_HCC,
        MDM_NFU  => LIVE_NFU
    };

    /** Field mapping: source field → target field (same API name on both sides). */
    public static final Map<String, String> COMMON_FIELD_MAP = new Map<String, String>{
        // Common
        F_NAME => F_NAME, F_CODE => F_CODE,
        // Additional Field
        F_UNIQUE_ID => F_UNIQUE_ID, F_TYPE => F_TYPE,
        F_FIELD_MANDATORY => F_FIELD_MANDATORY, F_FIELD_STATUS => F_FIELD_STATUS,
        F_FIELD_API_NAME => F_FIELD_API_NAME,
        // Additional Field List Value
        F_ORDER => F_ORDER,
        // Channel
        F_CHANNEL_ID => F_CHANNEL_ID, F_CHANNEL_STATUS => F_CHANNEL_STATUS,
        F_CHANNEL_VI_NAME => F_CHANNEL_VI_NAME, F_SELF_SERVICE_FLAG => F_SELF_SERVICE_FLAG,
        // Master Data Setting
        F_APPLICABLE_ROLE => F_APPLICABLE_ROLE, F_FIELD_OBJ_NAME => F_FIELD_OBJ_NAME,
        F_FIELD_ORDER_DISPLAY => F_FIELD_ORDER_DISPLAY, F_FIELD_READONLY => F_FIELD_READONLY,
        F_PROPERTY_REF => F_PROPERTY_REF, F_SECTION => F_SECTION,
        F_DATA_INT_MAPPING => F_DATA_INT_MAPPING,
        F_FIELD_MASKING => F_FIELD_MASKING, F_MASKING_TYPE => F_MASKING_TYPE,
        F_FIELD_REVERTED => F_FIELD_REVERTED,
        F_SUB_SECTION => F_SUB_SECTION, F_SUB_SECTION_FL => F_SUB_SECTION_FL,
        F_SUB_SECTION_L => F_SUB_SECTION_L, F_SUB_SECTION_O => F_SUB_SECTION_O,
        F_EDIT_UG => F_EDIT_UG, F_FIELD_EDITABLE => F_FIELD_EDITABLE,
        F_EDIT_ROLE => F_EDIT_ROLE, F_FIELD_LABEL_NAME => F_FIELD_LABEL_NAME,
        // NOC Lookup hierarchy
        F_ALIAS => F_ALIAS, F_NAME_VN => F_NAME_VN,
        F_STATUS => F_STATUS, F_ACTIVE => F_ACTIVE,
        // Nature of Case
        F_CUSTOMER_TYPE => F_CUSTOMER_TYPE, F_BP => F_BP, F_PT => F_PT,
        F_PT_STATUS => F_PT_STATUS,
        F_CAT => F_CAT, F_CAT_STATUS => F_CAT_STATUS,
        F_SUBCAT => F_SUBCAT, F_SUBCAT_STATUS => F_SUBCAT_STATUS,
        F_SUBCODE => F_SUBCODE, F_SUBCODE_STATUS => F_SUBCODE_STATUS,
        F_USER_GROUP => F_USER_GROUP, F_DEFAULT_STAGE => F_DEFAULT_STAGE,
        F_END_STAGE => F_END_STAGE,
        F_STATUS_NAME => F_STATUS_NAME, F_STAGE_NAME => F_STAGE_NAME,
        // NOC Sub-Process checkboxes
        F_DNB => F_DNB, F_TRANSFER_CALL => F_TRANSFER_CALL, F_REMOVE_PHONE => F_REMOVE_PHONE,
        // Stage Change
        F_NEXT_QUEUE => F_NEXT_QUEUE, F_TEAM_UG => F_TEAM_UG,
        // Stage Change Condition
        F_OPERATOR => F_OPERATOR, F_VALUE => F_VALUE, F_VALUE_TYPE => F_VALUE_TYPE,
        // Decision Rule
        F_PRIORITY => F_PRIORITY, F_TABLE_KEY => F_TABLE_KEY, F_KEY_ID => F_KEY_ID,
        // Decision Condition
        F_LABEL => F_LABEL, F_EXPRESSION => F_EXPRESSION,
        // Hold Case Config
        F_HCC_TYPE => F_HCC_TYPE, F_NFU_CODE => F_NFU_CODE,
        F_CHANGED_STATUS => F_CHANGED_STATUS, F_CURRENT_STATUS => F_CURRENT_STATUS,
        F_USER => F_USER, F_CASE_STAGE => F_CASE_STAGE, F_HCC_NOC => F_HCC_NOC,
        // NFU Code
        F_REASON_VN => F_REASON_VN
    };

    /** Lookup field → { mdmField, mdmObj } for ID remapping between layers. */
    public static final Map<String, Map<String, String>> LOOKUP_FIELD_MDM_MAP = new Map<String, Map<String, String>>{
        F_BP        => new Map<String, String>{ MDM_FIELD_KEY => F_BP,        MDM_OBJ_KEY => MDM_BP },
        F_PT        => new Map<String, String>{ MDM_FIELD_KEY => F_PT,        MDM_OBJ_KEY => MDM_PT },
        F_CAT       => new Map<String, String>{ MDM_FIELD_KEY => F_CAT,       MDM_OBJ_KEY => MDM_CAT },
        F_SUBCAT    => new Map<String, String>{ MDM_FIELD_KEY => F_SUBCAT,    MDM_OBJ_KEY => MDM_SCAT },
        F_SUBCODE   => new Map<String, String>{ MDM_FIELD_KEY => F_SUBCODE,   MDM_OBJ_KEY => MDM_SC },
        F_ADDITIONAL_FIELD => new Map<String, String>{ MDM_FIELD_KEY => F_ADDITIONAL_FIELD, MDM_OBJ_KEY => MDM_AF },
        F_STAGE_NAME => new Map<String, String>{ MDM_FIELD_KEY => F_STAGE_NAME, MDM_OBJ_KEY => MDM_CS },
        F_NOC       => new Map<String, String>{ MDM_FIELD_KEY => F_NOC,       MDM_OBJ_KEY => MDM_NOC },
        F_NOCS      => new Map<String, String>{ MDM_FIELD_KEY => F_NOCS,      MDM_OBJ_KEY => MDM_NOC },
        F_CHANNEL   => new Map<String, String>{ MDM_FIELD_KEY => 'FEC_MDM_Channel__c', MDM_OBJ_KEY => MDM_CH },
        F_PREV_STAGE => new Map<String, String>{ MDM_FIELD_KEY => F_PREV_STAGE, MDM_OBJ_KEY => MDM_CS },
        F_ACTION_BTN => new Map<String, String>{ MDM_FIELD_KEY => F_ACTION_BTN, MDM_OBJ_KEY => MDM_AB },
        F_NEXT_STAGE => new Map<String, String>{ MDM_FIELD_KEY => F_NEXT_STAGE, MDM_OBJ_KEY => MDM_CS },
        F_STAGE_CHANGE => new Map<String, String>{ MDM_FIELD_KEY => F_STAGE_CHANGE, MDM_OBJ_KEY => MDM_STCH },
        F_MDS       => new Map<String, String>{ MDM_FIELD_KEY => F_MDS,       MDM_OBJ_KEY => MDM_MDS },
        F_DECISION_RULE => new Map<String, String>{ MDM_FIELD_KEY => F_DECISION_RULE, MDM_OBJ_KEY => MDM_DR },
        F_CASE_STAGE => new Map<String, String>{ MDM_FIELD_KEY => F_CASE_STAGE, MDM_OBJ_KEY => MDM_CS },
        F_HCC_NOC   => new Map<String, String>{ MDM_FIELD_KEY => F_HCC_NOC,   MDM_OBJ_KEY => MDM_NOC }
    };

    /** Per-object lookup fields that need ID remapping. */
    public static final Map<String, List<String>> OBJECT_LOOKUP_FIELDS = new Map<String, List<String>>{
        MDM_NOC  => new List<String>{ F_BP, F_PT, F_CAT, F_SUBCAT, F_SUBCODE },
        MDM_CS   => new List<String>{ F_BP, F_NOCS },
        MDM_AFLV => new List<String>{ F_ADDITIONAL_FIELD },
        MDM_MDS  => new List<String>{ F_STAGE_NAME, F_NOC, F_ADDITIONAL_FIELD, F_CHANNEL },
        MDM_STCH => new List<String>{ F_PREV_STAGE, F_ACTION_BTN, F_NEXT_STAGE },
        MDM_SCC  => new List<String>{ F_STAGE_CHANGE, F_MDS },
        MDM_DC   => new List<String>{ F_DECISION_RULE },
        MDM_HCC  => new List<String>{ F_CASE_STAGE, F_HCC_NOC }
    };

    /** Objects that have lookups needing remapping. */
    public static final Set<String> OBJECTS_WITH_LOOKUP_REMAPPING = new Set<String>{
        MDM_NOC, MDM_CS, MDM_AFLV, MDM_MDS,
        MDM_STCH, MDM_SCC, MDM_DC, MDM_HCC
    };

    /**
     * Text-typed ID fields that store an SObject Id as a String and must be
     * remapped between MDM ↔ Live the same way as lookup fields.
     *
     * Map shape: mdmObj → { textFieldApiName → referencedMdmObjectApiName }
     *
     * For example, FEC_MDM_Decision_Rule__c.FEC_Key_ID__c can hold a Business
     * Process Id; when syncing Live → MDM (or pushing MDM → Live) we must
     * translate the Id from the source layer to the matching Id in the
     * destination layer (matched by FEC_Code__c external Id).
     */
    public static final Map<String, Map<String, String>> TEXT_ID_REMAP_FIELDS = new Map<String, Map<String, String>>{
        MDM_DR => new Map<String, String>{ F_KEY_ID => MDM_BP }
    };

    /** Objects that have text-typed Id fields needing remapping. */
    public static final Set<String> OBJECTS_WITH_TEXT_ID_REMAPPING = new Set<String>{ MDM_DR };

    /** Objects whose Name field is auto-number (skip Name when copying). */
    public static final Set<String> OBJECTS_WITH_AUTONUMBER_NAME = new Set<String>{
        MDM_MDS, MDM_NOC, MDM_STCH, MDM_SCC,
        MDM_DR, MDM_DC, MDM_HCC
    };
}