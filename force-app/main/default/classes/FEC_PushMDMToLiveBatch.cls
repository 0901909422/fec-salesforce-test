public with sharing class FEC_PushMDMToLiveBatch implements Database.Batchable<String>, Database.Stateful {
    
    // Constants - aliases for FEC_Constants used in this class
    private static final String FIELD_CODE                     = FEC_FieldConstants.FIELD_CODE;
    private static final String FIELD_NAME                     = FEC_FieldConstants.FIELD_NAME;
    private static final String FIELD_PROCESS_CHANGE_STATUS    = FEC_FieldConstants.FIELD_PROCESS_CHANGE_STATUS;
    private static final String FIELD_ALIAS                    = FEC_FieldConstants.FIELD_ALIAS;
    private static final String FIELD_NAME_VN                  = FEC_FieldConstants.FIELD_NAME_VN;
    private static final String FIELD_STATUS                   = FEC_FieldConstants.FIELD_STATUS;
    private static final String FIELD_ACTIVE                   = FEC_FieldConstants.FIELD_ACTIVE;
    private static final String FIELD_POS_ORDER                = FEC_FieldConstants.FIELD_POS_ORDER;
    private static final String FIELD_FEC_UNIQUE_ID            = FEC_FieldConstants.FIELD_FEC_UNIQUE_ID;
    private static final String FIELD_FEC_TYPE                 = FEC_FieldConstants.FIELD_FEC_TYPE;
    private static final String FIELD_FEC_ORDER                = FEC_FieldConstants.FIELD_FEC_ORDER;
    private static final String FIELD_FIELD_MANDATORY          = FEC_FieldConstants.FIELD_FIELD_MANDATORY;
    private static final String FIELD_FIELD_STATUS             = FEC_FieldConstants.FIELD_FIELD_STATUS;
    private static final String FIELD_FIELD_READONLY           = FEC_FieldConstants.FIELD_FIELD_READONLY;
    private static final String FIELD_FIELD_OBJECT_NAME        = FEC_FieldConstants.FIELD_FIELD_OBJECT_NAME;
    private static final String FIELD_FIELD_ORDER_DISPLAY      = FEC_FieldConstants.FIELD_FIELD_ORDER_DISPLAY;
    private static final String FIELD_PROPERTY_REFERENCE       = FEC_FieldConstants.FIELD_PROPERTY_REFERENCE;
    private static final String FIELD_SECTION                  = FEC_FieldConstants.FIELD_SECTION;
    private static final String FIELD_APPLICABLE_ROLE          = FEC_FieldConstants.FIELD_APPLICABLE_ROLE;
    private static final String FIELD_DATA_INTEGRATION_MAPPING = FEC_FieldConstants.FIELD_DATA_INTEGRATION_MAPPING;
    private static final String FIELD_CHANNEL_ID               = FEC_FieldConstants.FIELD_CHANNEL_ID;
    private static final String FIELD_CHANNEL_STATUS           = FEC_FieldConstants.FIELD_CHANNEL_STATUS;
    private static final String FIELD_CHANNEL_VI_NAME          = FEC_FieldConstants.FIELD_CHANNEL_VI_NAME;
    private static final String FIELD_SELF_SERVICE_FLAG        = FEC_FieldConstants.FIELD_SELF_SERVICE_FLAG;
    private static final String FIELD_CHANNEL                  = FEC_FieldConstants.FIELD_CHANNEL;
    private static final String FIELD_EXTERNAL_ID              = FEC_FieldConstants.FIELD_EXTERNAL_ID;
    private static final String FIELD_NATURE_OF_CASE           = FEC_FieldConstants.FIELD_NATURE_OF_CASE;
    private static final String FIELD_CUSTOMER_TYPE            = FEC_FieldConstants.FIELD_CUSTOMER_TYPE;
    private static final String FIELD_BUSINESS_PROCESS         = FEC_FieldConstants.FIELD_BUSINESS_PROCESS;
    private static final String FIELD_PRODUCT_TYPE             = FEC_FieldConstants.FIELD_PRODUCT_TYPE;
    private static final String FIELD_PRODUCT_TYPE_STATUS      = FEC_FieldConstants.FIELD_PRODUCT_TYPE_STATUS;
    private static final String FIELD_CATEGORY                 = FEC_FieldConstants.FIELD_CATEGORY;
    private static final String FIELD_CATEGORY_STATUS          = FEC_FieldConstants.FIELD_CATEGORY_STATUS;
    private static final String FIELD_SUB_CATEGORY             = FEC_FieldConstants.FIELD_SUB_CATEGORY;
    private static final String FIELD_SUB_CATEGORY_STATUS      = FEC_FieldConstants.FIELD_SUB_CATEGORY_STATUS;
    private static final String FIELD_SUB_CODE                 = FEC_FieldConstants.FIELD_SUB_CODE;
    private static final String FIELD_SUB_CODE_STATUS          = FEC_FieldConstants.FIELD_SUB_CODE_STATUS;
    private static final String FIELD_USER_GROUP               = FEC_FieldConstants.FIELD_USER_GROUP;
    private static final String FIELD_ROLE_NAMES               = FEC_FieldConstants.FIELD_ROLE_NAMES;
    private static final String FIELD_DEFAULT_STAGE            = FEC_FieldConstants.FIELD_DEFAULT_STAGE;
    private static final String FIELD_STATUS_NAME              = FEC_FieldConstants.FIELD_STATUS_NAME;
    private static final String FIELD_NATURE_OF_CASES          = FEC_FieldConstants.FIELD_NATURE_OF_CASES;
    private static final String FIELD_STAGE_NAME               = FEC_FieldConstants.FIELD_STAGE_NAME;
    private static final String FIELD_ADDITIONAL_FIELD         = FEC_FieldConstants.FIELD_ADDITIONAL_FIELD;
    private static final String FIELD_FIELD_MASKING            = FEC_FieldConstants.FIELD_FIELD_MASKING;
    private static final String FIELD_MASKING_TYPE             = FEC_FieldConstants.FIELD_MASKING_TYPE;
    private static final String FIELD_FIELD_REVERTED           = FEC_FieldConstants.FIELD_FIELD_REVERTED;
    private static final String FIELD_SUB_SECTION              = FEC_FieldConstants.FIELD_SUB_SECTION;
    private static final String FIELD_SUB_SECTION_FIELD_LAYOUT = FEC_FieldConstants.FIELD_SUB_SECTION_FIELD_LAYOUT;
    private static final String FIELD_SUB_SECTION_LAYOUT       = FEC_FieldConstants.FIELD_SUB_SECTION_LAYOUT;
    private static final String FIELD_SUB_SECTION_ORDER        = FEC_FieldConstants.FIELD_SUB_SECTION_ORDER;
    private static final String FIELD_EDITABLE_USER_GROUP      = FEC_FieldConstants.FIELD_EDITABLE_USER_GROUP;
    private static final String FIELD_FIELD_EDITABLE           = FEC_FieldConstants.FIELD_FIELD_EDITABLE;
    private static final String FIELD_EDITABLE_ROLE            = FEC_FieldConstants.FIELD_EDITABLE_ROLE;
    
    // Khai báo bổ sung trường bị thiếu gây lỗi Upsert
    private static final String FIELD_FIELD_API_NAME           = 'Field_API_Name__c';

    // Danh sách email admin được quản lý qua Custom Label FEC_MDM_Sync_Admin_Emails
    private static final String SYNC_ADMIN_EMAILS = System.Label.FEC_MDM_Sync_Admin_Emails;

    private static final String PROCESS_STATUS_NEW             = FEC_UIConstants.PROCESS_STATUS_NEW;
    private static final String PROCESS_STATUS_UPDATE          = FEC_UIConstants.PROCESS_STATUS_UPDATE;
    private static final String PROCESS_STATUS_SYNCED          = FEC_UIConstants.PROCESS_STATUS_SYNCED;
    
    private static final String OBJ_MDM_PRODUCT_TYPE                = FEC_ObjectConstants.OBJ_MDM_PRODUCT_TYPE;
    private static final String OBJ_MDM_BUSINESS_PROCESS            = FEC_ObjectConstants.OBJ_MDM_BUSINESS_PROCESS;
    private static final String OBJ_MDM_CATEGORY                    = FEC_ObjectConstants.OBJ_MDM_CATEGORY;
    private static final String OBJ_MDM_SUB_CATEGORY                = FEC_ObjectConstants.OBJ_MDM_SUB_CATEGORY;
    private static final String OBJ_MDM_SUB_CODE                    = FEC_ObjectConstants.OBJ_MDM_SUB_CODE;
    private static final String OBJ_MDM_NATURE_OF_CASE              = FEC_ObjectConstants.OBJ_MDM_NATURE_OF_CASE;
    private static final String OBJ_MDM_CHANNEL                     = FEC_ObjectConstants.OBJ_MDM_CHANNEL;
    private static final String OBJ_MDM_CASE_STAGE                  = FEC_ObjectConstants.OBJ_MDM_CASE_STAGE;
    private static final String OBJ_MDM_ADDITIONAL_FIELD            = FEC_ObjectConstants.OBJ_MDM_ADDITIONAL_FIELD;
    private static final String OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE = FEC_ObjectConstants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE;
    private static final String OBJ_MDM_MASTER_DATA_SETTING         = FEC_ObjectConstants.OBJ_MDM_MASTER_DATA_SETTING;
    
    // Stage Change objects
    private static final String OBJ_MDM_ACTION_BUTTON              = FEC_ObjectConstants.OBJ_MDM_ACTION_BUTTON;
    private static final String OBJ_ACTION_BUTTON                   = FEC_ObjectConstants.OBJ_ACTION_BUTTON;
    private static final String OBJ_MDM_STAGE_CHANGE                = FEC_ObjectConstants.OBJ_MDM_STAGE_CHANGE;
    private static final String OBJ_STAGE_CHANGE                    = FEC_ObjectConstants.OBJ_STAGE_CHANGE;
    private static final String OBJ_MDM_STAGE_CHANGE_CONDITION      = FEC_ObjectConstants.OBJ_MDM_STAGE_CHANGE_CONDITION;
    private static final String OBJ_STAGE_CHANGE_CONDITION           = FEC_ObjectConstants.OBJ_STAGE_CHANGE_CONDITION;

    // Stage Change field constants
    private static final String FIELD_PREVIOUS_STAGE                = FEC_FieldConstants.FIELD_PREVIOUS_STAGE;
    private static final String FIELD_ACTION_BUTTON                 = FEC_FieldConstants.FIELD_ACTION_BUTTON;
    private static final String FIELD_NEXT_STAGE                    = FEC_FieldConstants.FIELD_NEXT_STAGE;
    private static final String FIELD_NEXT_QUEUE                    = FEC_FieldConstants.FIELD_NEXT_QUEUE;
    private static final String FIELD_TEAM_USER_GROUP               = FEC_FieldConstants.FIELD_TEAM_USER_GROUP;
    private static final String FIELD_FIELD_LABEL_NAME              = FEC_FieldConstants.FIELD_FIELD_LABEL_NAME;

    // Stage Change Condition field constants
    private static final String FIELD_STAGE_CHANGE                  = FEC_FieldConstants.FIELD_STAGE_CHANGE;
    private static final String FIELD_MASTER_DATA_SETTING           = FEC_FieldConstants.FIELD_MASTER_DATA_SETTING;
    private static final String FIELD_OPERATOR                      = FEC_FieldConstants.FIELD_OPERATOR;
    private static final String FIELD_VALUE                         = FEC_FieldConstants.FIELD_VALUE;
    private static final String FIELD_VALUE_TYPE                    = FEC_FieldConstants.FIELD_VALUE_TYPE;

    // Decision Rule/Condition objects
    private static final String OBJ_MDM_DECISION_RULE              = FEC_ObjectConstants.OBJ_MDM_DECISION_RULE;
    private static final String OBJ_DECISION_RULE                  = FEC_ObjectConstants.OBJ_DECISION_RULE;
    private static final String OBJ_MDM_DECISION_CONDITION         = FEC_ObjectConstants.OBJ_MDM_DECISION_CONDITION;
    private static final String OBJ_DECISION_CONDITION             = FEC_ObjectConstants.OBJ_DECISION_CONDITION;

    // Decision Rule/Condition field constants
    private static final String FIELD_PRIORITY                     = FEC_FieldConstants.FIELD_PRIORITY;
    private static final String FIELD_TABLE_KEY                    = FEC_FieldConstants.FIELD_TABLE_KEY;
    private static final String FIELD_KEY_ID                       = FEC_FieldConstants.FIELD_KEY_ID;
    private static final String FIELD_DECISION_RULE                = FEC_FieldConstants.FIELD_DECISION_RULE;
    private static final String FIELD_LABEL                        = FEC_FieldConstants.FIELD_LABEL;
    private static final String FIELD_EXPRESSION                   = FEC_FieldConstants.FIELD_EXPRESSION;

    private static final String OBJ_PRODUCT_TYPE                = FEC_ObjectConstants.OBJ_PRODUCT_TYPE;
    private static final String OBJ_BUSINESS_PROCESS            = FEC_ObjectConstants.OBJ_BUSINESS_PROCESS;
    private static final String OBJ_CATEGORY                    = FEC_ObjectConstants.OBJ_CATEGORY;
    private static final String OBJ_SUB_CATEGORY                = FEC_ObjectConstants.OBJ_SUB_CATEGORY;
    private static final String OBJ_SUB_CODE                    = FEC_ObjectConstants.OBJ_SUB_CODE;
    private static final String OBJ_NATURE_OF_CASE              = FEC_ObjectConstants.OBJ_NATURE_OF_CASE;
    private static final String OBJ_CHANNEL                     = FEC_ObjectConstants.OBJ_CHANNEL;
    private static final String OBJ_CASE_STAGE                  = FEC_ObjectConstants.OBJ_CASE_STAGE;
    private static final String OBJ_ADDITIONAL_FIELD            = FEC_ObjectConstants.OBJ_ADDITIONAL_FIELD;
    private static final String OBJ_ADDITIONAL_FIELD_LIST_VALUE = FEC_ObjectConstants.OBJ_ADDITIONAL_FIELD_LIST_VALUE;
    private static final String OBJ_MASTER_DATA_SETTING         = FEC_ObjectConstants.OBJ_MASTER_DATA_SETTING;
    
    private static final String REL_NATURE_OF_CASE       = FEC_FieldConstants.REL_NATURE_OF_CASE;
    private static final String REL_ADDITIONAL_FIELD     = FEC_FieldConstants.REL_ADDITIONAL_FIELD;
    private static final String REL_STAGE_NAME           = FEC_FieldConstants.REL_STAGE_NAME;
    private static final String REL_PRODUCT_TYPE_NAME    = FEC_FieldConstants.REL_PRODUCT_TYPE_NAME;
    private static final String REL_BUSINESS_PROCESS_NAME= FEC_FieldConstants.REL_BUSINESS_PROCESS_NAME;
    private static final String REL_CATEGORY_NAME        = FEC_FieldConstants.REL_CATEGORY_NAME;
    private static final String REL_SUB_CATEGORY_NAME    = FEC_FieldConstants.REL_SUB_CATEGORY_NAME;
    private static final String REL_SUB_CODE_NAME        = FEC_FieldConstants.REL_SUB_CODE_NAME;
    
    // Map key constants
    private static final String MDM_FIELD_KEY = 'mdmField';
    private static final String MDM_OBJ_KEY = 'mdmObj';
    
    // Map of: source lookup field => { mdmField, mdmObjectName }
    private static final Map<String, Map<String, String>> LOOKUP_FIELD_MDM_MAP = new Map<String, Map<String, String>>{
        // Nature of Case lookups
        FIELD_BUSINESS_PROCESS => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_BUSINESS_PROCESS,
            MDM_OBJ_KEY   => OBJ_MDM_BUSINESS_PROCESS
        },
        FIELD_PRODUCT_TYPE => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_PRODUCT_TYPE,
            MDM_OBJ_KEY   => OBJ_MDM_PRODUCT_TYPE
        },
        FIELD_CATEGORY => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_CATEGORY,
            MDM_OBJ_KEY   => OBJ_MDM_CATEGORY
        },
        FIELD_SUB_CATEGORY => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_SUB_CATEGORY,
            MDM_OBJ_KEY   => OBJ_MDM_SUB_CATEGORY
        },
        FIELD_SUB_CODE => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_SUB_CODE,
            MDM_OBJ_KEY   => OBJ_MDM_SUB_CODE
        },
        // Additional Field List Value lookups
        FIELD_ADDITIONAL_FIELD => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_ADDITIONAL_FIELD,
            MDM_OBJ_KEY   => OBJ_MDM_ADDITIONAL_FIELD
        },
        // Master Data Setting lookups
        FIELD_STAGE_NAME => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_STAGE_NAME,
            MDM_OBJ_KEY   => OBJ_MDM_CASE_STAGE
        },
        FIELD_NATURE_OF_CASE => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_NATURE_OF_CASE,
            MDM_OBJ_KEY   => OBJ_MDM_NATURE_OF_CASE
        },
        FIELD_NATURE_OF_CASES => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_NATURE_OF_CASES,
            MDM_OBJ_KEY   => OBJ_MDM_NATURE_OF_CASE
        },
        FIELD_CHANNEL => new Map<String, String>{
            MDM_FIELD_KEY => 'FEC_MDM_Channel__c',
            MDM_OBJ_KEY   => OBJ_MDM_CHANNEL
        },
        // Stage Change lookups
        FIELD_PREVIOUS_STAGE => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_PREVIOUS_STAGE,
            MDM_OBJ_KEY   => OBJ_MDM_CASE_STAGE
        },
        FIELD_ACTION_BUTTON => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_ACTION_BUTTON,
            MDM_OBJ_KEY   => OBJ_MDM_ACTION_BUTTON
        },
        FIELD_NEXT_STAGE => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_NEXT_STAGE,
            MDM_OBJ_KEY   => OBJ_MDM_CASE_STAGE
        },
        // Stage Change Condition lookups
        FIELD_STAGE_CHANGE => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_STAGE_CHANGE,
            MDM_OBJ_KEY   => OBJ_MDM_STAGE_CHANGE
        },
        FIELD_MASTER_DATA_SETTING => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_MASTER_DATA_SETTING,
            MDM_OBJ_KEY   => OBJ_MDM_MASTER_DATA_SETTING
        },
        // Decision Condition lookups
        FIELD_DECISION_RULE => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_DECISION_RULE,
            MDM_OBJ_KEY   => OBJ_MDM_DECISION_RULE
        }
    };
    
    // Map object-specific lookup fields that need remapping
    private static final Map<String, List<String>> OBJECT_LOOKUP_FIELDS = new Map<String, List<String>>{
        OBJ_MDM_NATURE_OF_CASE => new List<String>{
            FIELD_BUSINESS_PROCESS, FIELD_PRODUCT_TYPE, FIELD_CATEGORY,
            FIELD_SUB_CATEGORY, FIELD_SUB_CODE
        },
        OBJ_MDM_CASE_STAGE => new List<String>{
            FIELD_BUSINESS_PROCESS, FIELD_NATURE_OF_CASES
        },
        OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE => new List<String>{
            FIELD_ADDITIONAL_FIELD
        },
        OBJ_MDM_MASTER_DATA_SETTING => new List<String>{
            FIELD_STAGE_NAME,
            FIELD_NATURE_OF_CASE,
            FIELD_ADDITIONAL_FIELD,
            FIELD_CHANNEL
        },
        OBJ_MDM_STAGE_CHANGE => new List<String>{
            FIELD_PREVIOUS_STAGE, FIELD_ACTION_BUTTON, FIELD_NEXT_STAGE
        },
        OBJ_MDM_STAGE_CHANGE_CONDITION => new List<String>{
            FIELD_STAGE_CHANGE, FIELD_MASTER_DATA_SETTING
        },
        OBJ_MDM_DECISION_CONDITION => new List<String>{
            FIELD_DECISION_RULE
        }
    };
    
    // Map object types that have special handling (lookups that need remapping)
    private static final Set<String> OBJECTS_WITH_LOOKUP_REMAPPING = new Set<String>{
        OBJ_MDM_NATURE_OF_CASE,
        OBJ_MDM_CASE_STAGE,
        OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE,
        OBJ_MDM_MASTER_DATA_SETTING,
        OBJ_MDM_STAGE_CHANGE,
        OBJ_MDM_STAGE_CHANGE_CONDITION,
        OBJ_MDM_DECISION_CONDITION
    };
    
    // Objects whose Name field is auto-number (not editable) - skip Name when copying
    private static final Set<String> OBJECTS_WITH_AUTONUMBER_NAME = new Set<String>{
        OBJ_MDM_MASTER_DATA_SETTING,
        OBJ_MDM_NATURE_OF_CASE,
        OBJ_MDM_STAGE_CHANGE,
        OBJ_MDM_STAGE_CHANGE_CONDITION,
        OBJ_MDM_DECISION_RULE,
        OBJ_MDM_DECISION_CONDITION
    };
    
    private Set<String> uniqueErrors = new Set<String>();
    
    private List<String> executionOrder = new List<String>{
        OBJ_MDM_BUSINESS_PROCESS,
        OBJ_MDM_ADDITIONAL_FIELD,
        OBJ_MDM_PRODUCT_TYPE,
        OBJ_MDM_CATEGORY,
        OBJ_MDM_SUB_CATEGORY,
        OBJ_MDM_SUB_CODE,
        OBJ_MDM_CHANNEL,
        OBJ_MDM_CASE_STAGE,
        OBJ_MDM_NATURE_OF_CASE,
        OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE,
        OBJ_MDM_MASTER_DATA_SETTING,
        OBJ_MDM_ACTION_BUTTON,
        OBJ_MDM_STAGE_CHANGE,
        OBJ_MDM_STAGE_CHANGE_CONDITION,
        OBJ_MDM_DECISION_RULE,
        OBJ_MDM_DECISION_CONDITION
    };
    
    private Map<String, String> mdmToOriginalMap = new Map<String, String>{
        OBJ_MDM_PRODUCT_TYPE                => OBJ_PRODUCT_TYPE,
        OBJ_MDM_BUSINESS_PROCESS            => OBJ_BUSINESS_PROCESS,
        OBJ_MDM_CATEGORY                    => OBJ_CATEGORY,
        OBJ_MDM_SUB_CATEGORY                => OBJ_SUB_CATEGORY,
        OBJ_MDM_SUB_CODE                    => OBJ_SUB_CODE,
        OBJ_MDM_CASE_STAGE                  => OBJ_CASE_STAGE,
        OBJ_MDM_NATURE_OF_CASE              => OBJ_NATURE_OF_CASE,
        OBJ_MDM_CHANNEL                     => OBJ_CHANNEL,
        OBJ_MDM_MASTER_DATA_SETTING         => OBJ_MASTER_DATA_SETTING,
        OBJ_MDM_ADDITIONAL_FIELD            => OBJ_ADDITIONAL_FIELD,
        OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE => OBJ_ADDITIONAL_FIELD_LIST_VALUE,
        OBJ_MDM_ACTION_BUTTON              => OBJ_ACTION_BUTTON,
        OBJ_MDM_STAGE_CHANGE               => OBJ_STAGE_CHANGE,
        OBJ_MDM_STAGE_CHANGE_CONDITION     => OBJ_STAGE_CHANGE_CONDITION,
        OBJ_MDM_DECISION_RULE             => OBJ_DECISION_RULE,
        OBJ_MDM_DECISION_CONDITION        => OBJ_DECISION_CONDITION
    };
    
    private Map<String, String> commonFieldMap = new Map<String, String>{
        //Common Fields
        FIELD_NAME                  => FIELD_NAME,
        FIELD_CODE                  => FIELD_CODE,
        //Additional Field Fields
        FIELD_FEC_UNIQUE_ID         => FIELD_FEC_UNIQUE_ID,
        FIELD_FEC_TYPE              => FIELD_FEC_TYPE,
        FIELD_FIELD_MANDATORY       => FIELD_FIELD_MANDATORY,
        FIELD_FIELD_STATUS          => FIELD_FIELD_STATUS,
        FIELD_FIELD_API_NAME        => FIELD_FIELD_API_NAME, // Đã bổ sung mapping Field_API_Name__c
        //Additional Field Fields List Value
        FIELD_FEC_ORDER             => FIELD_FEC_ORDER,
        //Channel Fields
        FIELD_CHANNEL_ID            => FIELD_CHANNEL_ID,
        FIELD_CHANNEL_STATUS        => FIELD_CHANNEL_STATUS,
        FIELD_CHANNEL_VI_NAME       => FIELD_CHANNEL_VI_NAME,
        FIELD_SELF_SERVICE_FLAG     => FIELD_SELF_SERVICE_FLAG,
        //FEC_MDM_Master_Data_Setting__c Fields
        FIELD_APPLICABLE_ROLE       => FIELD_APPLICABLE_ROLE,
        FIELD_FIELD_OBJECT_NAME     => FIELD_FIELD_OBJECT_NAME,
        FIELD_FIELD_ORDER_DISPLAY   => FIELD_FIELD_ORDER_DISPLAY,
        FIELD_FIELD_READONLY        => FIELD_FIELD_READONLY,
        FIELD_PROPERTY_REFERENCE    => FIELD_PROPERTY_REFERENCE,
        FIELD_SECTION               => FIELD_SECTION,
        // FIELD_CHANNEL               => FIELD_CHANNEL,
        FIELD_DATA_INTEGRATION_MAPPING => FIELD_DATA_INTEGRATION_MAPPING,
        // Missing Fields (Push)
        FIELD_FIELD_MASKING            => FIELD_FIELD_MASKING,
        FIELD_MASKING_TYPE             => FIELD_MASKING_TYPE,
        FIELD_FIELD_REVERTED           => FIELD_FIELD_REVERTED,
        FIELD_SUB_SECTION              => FIELD_SUB_SECTION,
        FIELD_SUB_SECTION_FIELD_LAYOUT => FIELD_SUB_SECTION_FIELD_LAYOUT,
        FIELD_SUB_SECTION_LAYOUT       => FIELD_SUB_SECTION_LAYOUT,
        FIELD_SUB_SECTION_ORDER        => FIELD_SUB_SECTION_ORDER,
        FIELD_EDITABLE_USER_GROUP      => FIELD_EDITABLE_USER_GROUP,
        FIELD_FIELD_EDITABLE           => FIELD_FIELD_EDITABLE,
        FIELD_EDITABLE_ROLE            => FIELD_EDITABLE_ROLE,
        //NOC Lookup Fields
        FIELD_ALIAS                 => FIELD_ALIAS,
        FIELD_NAME_VN               => FIELD_NAME_VN,
        FIELD_POS_ORDER             => FIELD_POS_ORDER,
        FIELD_STATUS                => FIELD_STATUS,
        FIELD_ACTIVE                => FIELD_ACTIVE,
        //Nature of Case Fields
        FIELD_CUSTOMER_TYPE         => FIELD_CUSTOMER_TYPE,
        FIELD_BUSINESS_PROCESS      => FIELD_BUSINESS_PROCESS,
        FIELD_PRODUCT_TYPE          => FIELD_PRODUCT_TYPE,
        FIELD_CATEGORY              => FIELD_CATEGORY,
        FIELD_SUB_CATEGORY          => FIELD_SUB_CATEGORY,
        FIELD_SUB_CODE              => FIELD_SUB_CODE,
        FIELD_USER_GROUP            => FIELD_USER_GROUP,
        FIELD_ROLE_NAMES            => FIELD_ROLE_NAMES,
        FIELD_DEFAULT_STAGE         => FIELD_DEFAULT_STAGE,
        FIELD_STATUS_NAME           => FIELD_STATUS_NAME,
        FIELD_STAGE_NAME            => FIELD_STAGE_NAME,
        // Missing MDS/NOC fields
        FIELD_FIELD_LABEL_NAME     => FIELD_FIELD_LABEL_NAME,
        FEC_FieldConstants.FIELD_FIELD_API_NAME => FEC_FieldConstants.FIELD_FIELD_API_NAME,
        // Stage Change fields
        FIELD_NEXT_QUEUE           => FIELD_NEXT_QUEUE,
        FIELD_TEAM_USER_GROUP      => FIELD_TEAM_USER_GROUP,
        // Stage Change Condition fields
        FIELD_OPERATOR             => FIELD_OPERATOR,
        FIELD_VALUE                => FIELD_VALUE,
        FIELD_VALUE_TYPE           => FIELD_VALUE_TYPE,
        // Decision Rule fields
        FIELD_PRIORITY             => FIELD_PRIORITY,
        FIELD_TABLE_KEY            => FIELD_TABLE_KEY,
        FIELD_KEY_ID               => FIELD_KEY_ID,
        // Decision Condition fields
        FIELD_LABEL                => FIELD_LABEL,
        FIELD_EXPRESSION           => FIELD_EXPRESSION
    };
    
    public Iterable<String> start(Database.BatchableContext bc) {
        return executionOrder;
    }
    
    public void execute(Database.BatchableContext bc, List<String> scope) {
        String mdmObjName = scope[0];
        String targetObjName = mdmToOriginalMap.get(mdmObjName);
        
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(mdmObjName) || !gd.containsKey(targetObjName)) return;
        
        try {
            // STEP 1: Build query fields - only fields that exist on both source and MDM
            Map<String, Schema.SObjectField> targetFields = gd.get(targetObjName).getDescribe().fields.getMap();
            Map<String, Schema.SObjectField> mdmFieldsMap = gd.get(mdmObjName).getDescribe().fields.getMap();
            Set<String> validQueryFields = new Set<String>();
            validQueryFields.add('Id');
            validQueryFields.add(FIELD_PROCESS_CHANGE_STATUS);
            
            // Build filtered field map - only fields that exist on both objects
            Map<String, String> filteredFieldMap = new Map<String, String>();
            for (String liveField : commonFieldMap.keySet()) {
                String mdmField = commonFieldMap.get(liveField);
                if (targetFields.containsKey(liveField) && mdmFieldsMap.containsKey(mdmField)) {
                    validQueryFields.add(mdmField);
                    filteredFieldMap.put(mdmField, liveField); // Reverse mapping: MDM -> Live
                }
            }
            
            // Also query MDM lookup fields so we can remap them
            if (OBJECTS_WITH_LOOKUP_REMAPPING.contains(mdmObjName)) {
                List<String> objLookupFields = OBJECT_LOOKUP_FIELDS.get(mdmObjName);
                if (objLookupFields != null) {
                    for (String srcLookupField : objLookupFields) {
                        if (targetFields.containsKey(srcLookupField)) {
                            String mdmLookupField = LOOKUP_FIELD_MDM_MAP.get(srcLookupField).get(MDM_FIELD_KEY);
                            if (mdmFieldsMap.containsKey(mdmLookupField)) {
                                validQueryFields.add(mdmLookupField);
                            }
                        }
                    }
                }
            }
            
            // STEP 2: Query MDM records
            String query = 'SELECT ' + String.join(new List<String>(validQueryFields), ', ')
                + ' FROM ' + mdmObjName
                + ' WHERE ' + FIELD_PROCESS_CHANGE_STATUS + ' != \'' + PROCESS_STATUS_SYNCED + '\'';
            List<SObject> mdmRecords = Database.query(query);
            if (mdmRecords.isEmpty()) return;
            
            populateMissingCodes(mdmRecords, mdmObjName);
            
            // STEP 3: Build lookup remap maps (MDM -> Live)
            Map<String, Map<Id, Id>> lookupRemapMaps = new Map<String, Map<Id, Id>>();
            if (OBJECTS_WITH_LOOKUP_REMAPPING.contains(mdmObjName)) {
                buildLookupRemapMaps(mdmObjName, mdmRecords, targetFields, lookupRemapMaps, gd);
            }

            // Build text-typed Id remap (e.g. FEC_Decision_Rule__c.FEC_Key_ID__c)
            Map<String, Map<Id, Id>> textIdRemapMaps = new Map<String, Map<Id, Id>>();
            if (FEC_MDMBatchConfig.OBJECTS_WITH_TEXT_ID_REMAPPING.contains(mdmObjName)) {
                textIdRemapMaps = buildTextIdRemapMaps(mdmObjName, mdmRecords, gd);
            }
            
            // STEP 4: Split NEW vs UPDATE
            List<SObject> mdmNew    = new List<SObject>();
            List<SObject> mdmUpdate = new List<SObject>();
            for (SObject mdm : mdmRecords) {
                String status = (String) mdm.get(FIELD_PROCESS_CHANGE_STATUS);
                if (status == PROCESS_STATUS_NEW) {
                    mdmNew.add(mdm);
                } else if (status == PROCESS_STATUS_UPDATE) {
                    mdmUpdate.add(mdm);
                }
            }
            
            // STEP 5: Prepare records for UPSERT
            List<SObject> insertList = buildTargetList(mdmNew, mdmObjName, targetObjName, filteredFieldMap, lookupRemapMaps, textIdRemapMaps, gd);
            List<SObject> updateList = buildTargetList(mdmUpdate, mdmObjName, targetObjName, filteredFieldMap, lookupRemapMaps, textIdRemapMaps, gd);
            
            Schema.SObjectField extIdField = targetFields.get(FIELD_CODE);
            
            // STEP 6: UPSERT records to Live
            if (!insertList.isEmpty()) {
                processUpsert(insertList, mdmNew, extIdField, targetObjName);
            }
            if (!updateList.isEmpty()) {
                processUpsert(updateList, mdmUpdate, extIdField, targetObjName);
            }
            
        } catch (Exception e) {
            System.debug('Error pushing ' + mdmObjName + ' to Live: ' + e.getMessage());
            uniqueErrors.add('[Error ' + mdmObjName + '] ' + e.getMessage());
        }
    }
    
    private void processUpsert(List<SObject> targetList, List<SObject> mdmRecords, Schema.SObjectField extIdField, String targetObjName) {
        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
        try {
            Database.UpsertResult[] results = Database.upsert(targetList, extIdField, false);
            List<SObject> mdmToUpdate = new List<SObject>();
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    mdmRecords[i].put(FIELD_PROCESS_CHANGE_STATUS, PROCESS_STATUS_SYNCED);
                    mdmToUpdate.add(mdmRecords[i]);
                } else {
                    uniqueErrors.add('[' + targetObjName + ' Upsert Error] ' + results[i].getErrors()[0].getMessage());
                }
            }
            if (!mdmToUpdate.isEmpty()) update mdmToUpdate;
        } finally {
            FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
        }
    }
    
    private void populateMissingCodes(List<SObject> records, String objectName) {
        List<SObject> recordsToUpdate = new List<SObject>();
        for (SObject record : records) {
            String code = (String) record.get(FIELD_CODE);
            if (String.isBlank(code)) {
                String name = (String) record.get(FIELD_NAME);
                if (String.isNotBlank(name)) {
                    record.put(FIELD_CODE, name);
                    recordsToUpdate.add(record);
                }
            }
        }
        if (!recordsToUpdate.isEmpty()) {
            FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
            try {
                update recordsToUpdate;
            } finally {
                FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
            }
        }
    }
    
    private List<SObject> buildTargetList(
        List<SObject> mdmRecords, String mdmObjName, String targetObjName,
    Map<String, String> filteredFieldMap, Map<String, Map<Id, Id>> lookupRemapMaps,
    Map<String, Map<Id, Id>> textIdRemapMaps,
    Map<String, Schema.SObjectType> gd
    ) {
        List<SObject> targetList = new List<SObject>();
        List<String> thisObjLookupFields = OBJECT_LOOKUP_FIELDS.containsKey(mdmObjName)
            ? OBJECT_LOOKUP_FIELDS.get(mdmObjName)
            : new List<String>();
        Boolean skipName = OBJECTS_WITH_AUTONUMBER_NAME.contains(mdmObjName);
        
        for (SObject mdm : mdmRecords) {
            SObject target = gd.get(targetObjName).newSObject();
            
            // Copy Code field
            String codeValue = (String)mdm.get(FIELD_CODE);
            if (String.isNotBlank(codeValue)) {
                target.put(FIELD_CODE, codeValue);
            }
            
            // Copy normal fields
            for (String mdmField : filteredFieldMap.keySet()) {
                String liveField = filteredFieldMap.get(mdmField);
                if (thisObjLookupFields.contains(liveField)) continue;
                if (skipName && liveField == FIELD_NAME) continue;
                
                if (mdm.get(mdmField) != null) {
                    target.put(liveField, mdm.get(mdmField));
                }
            }
            
            // Remap lookup fields
            if (OBJECTS_WITH_LOOKUP_REMAPPING.contains(mdmObjName)) {
                remapLookupFields(mdm, target, lookupRemapMaps, mdmObjName);
            }

            // Remap text-typed Id fields (FEC_Key_ID__c etc.)
            if (FEC_MDMBatchConfig.OBJECTS_WITH_TEXT_ID_REMAPPING.contains(mdmObjName)) {
                remapTextIdFields(mdm, target, mdmObjName, textIdRemapMaps);
            }
            
            targetList.add(target);
        }
        return targetList;
    }
    
    private void buildLookupRemapMaps(String mdmObjName, List<SObject> mdmRecords,
    Map<String, Schema.SObjectField> targetFields,
    Map<String, Map<Id, Id>> lookupRemapMaps,
    Map<String, Schema.SObjectType> gd) {
        
        List<String> objectLookupFields = OBJECT_LOOKUP_FIELDS.get(mdmObjName);
        if (objectLookupFields == null || objectLookupFields.isEmpty()) return;
        
        for (String srcLookupField : objectLookupFields) {
            if (!targetFields.containsKey(srcLookupField)) {
                lookupRemapMaps.put(srcLookupField, new Map<Id, Id>());
                continue;
            }
            String mdmLookupObj = LOOKUP_FIELD_MDM_MAP.get(srcLookupField).get(MDM_OBJ_KEY);
            String mdmLookupField = LOOKUP_FIELD_MDM_MAP.get(srcLookupField).get(MDM_FIELD_KEY);
            
            if (!gd.containsKey(mdmLookupObj)) {
                lookupRemapMaps.put(srcLookupField, new Map<Id, Id>());
                continue;
            }
            String srcObjName = mdmToOriginalMap.containsKey(mdmLookupObj)
                ? mdmToOriginalMap.get(mdmLookupObj)
                : null;
            
            Map<Id, Id> mdmToSrcIdMap = new Map<Id, Id>();
            if (srcObjName != null && gd.containsKey(srcObjName)) {
                Set<Id> usedMdmIds = new Set<Id>();
                for (SObject mdm : mdmRecords) {
                    Id lookupId = (Id)mdm.get(mdmLookupField);
                    if (lookupId != null) usedMdmIds.add(lookupId);
                }
                
                if (!usedMdmIds.isEmpty()) {
                    Map<Id, String> mdmIdToCode = new Map<Id, String>();
                    for (SObject mdmLookupRecord : Database.query(
                        'SELECT Id, ' + FIELD_CODE + ' FROM ' + mdmLookupObj + ' WHERE Id IN :usedMdmIds'
                    )) {
                        String code = (String)mdmLookupRecord.get(FIELD_CODE);
                        if (String.isNotBlank(code)) mdmIdToCode.put(mdmLookupRecord.Id, code);
                    }
                    
                    Map<String, Id> srcCodeToId = new Map<String, Id>();
                    for (SObject srcLookupRecord : Database.query(
                        'SELECT Id, ' + FIELD_CODE + ' FROM ' + srcObjName
                    )) {
                        String code = (String)srcLookupRecord.get(FIELD_CODE);
                        if (String.isNotBlank(code)) srcCodeToId.put(code, srcLookupRecord.Id);
                    }
                    
                    for (Id mdmId : mdmIdToCode.keySet()) {
                        String code = mdmIdToCode.get(mdmId);
                        if (srcCodeToId.containsKey(code)) {
                            mdmToSrcIdMap.put(mdmId, srcCodeToId.get(code));
                        }
                    }
                }
            }
            lookupRemapMaps.put(srcLookupField, mdmToSrcIdMap);
        }
    }
    
    private void remapLookupFields(SObject mdm, SObject target,
    Map<String, Map<Id, Id>> lookupRemapMaps,
    String mdmObjName) {
        
        List<String> objectLookupFields = OBJECT_LOOKUP_FIELDS.get(mdmObjName);
        if (objectLookupFields == null || objectLookupFields.isEmpty()) return;
        
        for (String srcLookupField : objectLookupFields) {
            String mdmLookupField = LOOKUP_FIELD_MDM_MAP.get(srcLookupField).get(MDM_FIELD_KEY);
            Id mdmId = (Id)mdm.get(mdmLookupField);
            if (mdmId == null) continue;
            
            Map<Id, Id> remapMap = lookupRemapMaps.get(srcLookupField);
            if (remapMap != null && remapMap.containsKey(mdmId)) {
                target.put(srcLookupField, remapMap.get(mdmId));
            }
        }
    }

    /**
     * Remap text-typed ID fields (e.g. FEC_Key_ID__c) from MDM record Ids to
     * the corresponding Live record Ids by matching FEC_Code__c.
     */
    private void remapTextIdFields(SObject mdm, SObject target, String mdmObjName,
        Map<String, Map<Id, Id>> textIdRemapMaps) {

        Map<String, String> textFields = FEC_MDMBatchConfig.TEXT_ID_REMAP_FIELDS.get(mdmObjName);
        if (textFields == null || textFields.isEmpty()) return;

        for (String fieldName : textFields.keySet()) {
            String rawValue = (String) mdm.get(fieldName);
            if (String.isBlank(rawValue)) continue;
            try {
                Id mdmId = (Id) rawValue;
                Map<Id, Id> remapMap = textIdRemapMaps.get(fieldName);
                if (remapMap != null && remapMap.containsKey(mdmId)) {
                    target.put(fieldName, String.valueOf(remapMap.get(mdmId)));
                }
            } catch (Exception ignored) {
                // Value is not a valid Id — leave as-is
            }
        }
    }

    /**
     * Build a map: textFieldName → (mdmRefId → liveRefId) for all text-typed
     * Id fields on this object, by matching FEC_Code__c between MDM and Live.
     */
    private Map<String, Map<Id, Id>> buildTextIdRemapMaps(String mdmObjName,
        List<SObject> mdmRecords, Map<String, Schema.SObjectType> gd) {

        Map<String, Map<Id, Id>> result = new Map<String, Map<Id, Id>>();
        Map<String, String> textFields = FEC_MDMBatchConfig.TEXT_ID_REMAP_FIELDS.get(mdmObjName);
        if (textFields == null || textFields.isEmpty()) return result;

        for (String fieldName : textFields.keySet()) {
            String mdmRefObj = textFields.get(fieldName);
            String liveRefObj = FEC_MDMBatchConfig.MDM_TO_LIVE_MAP.get(mdmRefObj);
            if (liveRefObj == null || !gd.containsKey(mdmRefObj) || !gd.containsKey(liveRefObj)) {
                result.put(fieldName, new Map<Id, Id>());
                continue;
            }
            // Collect all referenced Ids from MDM records
            Set<Id> referencedIds = new Set<Id>();
            for (SObject m : mdmRecords) {
                String raw = (String) m.get(fieldName);
                if (String.isBlank(raw)) continue;
                try { referencedIds.add((Id) raw); } catch (Exception ignored) {}
            }
            if (referencedIds.isEmpty()) {
                result.put(fieldName, new Map<Id, Id>());
                continue;
            }
            // Map MDM Id → Code → Live Id
            Map<Id, String> mdmIdToCode = new Map<Id, String>();
            for (SObject r : Database.query(
                'SELECT Id, ' + FEC_MDMBatchConfig.FIELD_CODE + ' FROM ' + mdmRefObj + ' WHERE Id IN :referencedIds')) {
                String code = (String) r.get(FEC_MDMBatchConfig.FIELD_CODE);
                if (String.isNotBlank(code)) mdmIdToCode.put(r.Id, code);
            }
            Map<String, Id> codeToLiveId = new Map<String, Id>();
            for (SObject r : Database.query(
                'SELECT Id, ' + FEC_MDMBatchConfig.FIELD_CODE + ' FROM ' + liveRefObj)) {
                String code = (String) r.get(FEC_MDMBatchConfig.FIELD_CODE);
                if (String.isNotBlank(code)) codeToLiveId.put(code, r.Id);
            }
            Map<Id, Id> idMap = new Map<Id, Id>();
            for (Id mdmId : mdmIdToCode.keySet()) {
                Id liveId = codeToLiveId.get(mdmIdToCode.get(mdmId));
                if (liveId != null) idMap.put(mdmId, liveId);
            }
            result.put(fieldName, idMap);
        }
        return result;
    }
    
    /**
     * @description Hàm xử lý hậu kỳ của Batch, tổng hợp lỗi, lưu Log vào hệ thống
     * và gửi email thông báo qua Email Template.
     * @author      DAT NGO
     * @param       bc Database.BatchableContext
     * @return      void
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('[finish] START');
        
        // 1. Lấy thông tin Batch Job từ hệ thống
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedById, CreatedBy.Email
            FROM AsyncApexJob 
            WHERE Id = :bc.getJobId()
        ];
        
        // 2. Tổng hợp dữ liệu lỗi
        String errorDetails = '';
        Integer totalErrors = job.NumberOfErrors;
        String batchStatus = 'Success';
        
        if (!uniqueErrors.isEmpty()) {
            errorDetails = String.join(new List<String>(uniqueErrors), '\n\n');
            totalErrors += uniqueErrors.size(); // Cộng dồn lỗi logic và lỗi Job
            batchStatus = 'Completed with Errors';
        } else if (job.NumberOfErrors > 0 || job.Status == 'Failed') {
            batchStatus = 'Failed';
        }
        
        // 3. Tạo bản ghi FEC_Batch_Log__c
        FEC_Batch_Log__c batchLog = new FEC_Batch_Log__c(
            FEC_Batch_Name__c      = 'FEC_PushMDMToLiveBatch',
            FEC_Job_ID__c          = job.Id,
            FEC_Status__c          = batchStatus,
            FEC_Total_Job_Items__c = job.TotalJobItems,
            FEC_Processed_Items__c = job.JobItemsProcessed,
            FEC_Error_Count__c     = totalErrors,
            FEC_Error_Details__c   = String.isNotBlank(errorDetails) ? errorDetails.abbreviate(131000) : null
        );
        
        try {
            insert batchLog;
            System.debug('[finish] Inserted Batch Log successfully. ID: ' + batchLog.Id);
        } catch (Exception ex) {
            System.debug('[finish] ERROR Insert Batch Log: ' + ex.getMessage());
        }
        
        // 4. Thiết lập danh sách người nhận từ Custom Label
        List<String> toAddresses = new List<String>();
        if (String.isNotBlank(SYNC_ADMIN_EMAILS)) {
            for (String email : SYNC_ADMIN_EMAILS.split(',')) {
                if (String.isNotBlank(email)) {
                    toAddresses.add(email.trim());
                }
            }
        }
        
        // Fallback to CreatedBy Email if label is empty
        if (toAddresses.isEmpty()) {
            toAddresses.add(job.CreatedBy.Email);
        }

        // 5. Thiết lập và gửi Email Template
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        List<EmailTemplate> templates = [
            SELECT Id FROM EmailTemplate 
            WHERE DeveloperName = 'FEC_PushMDM_Batch_Completion' 
            LIMIT 1
        ];
        
        if (!templates.isEmpty() && batchLog.Id != null) {
            // Bypass giới hạn WhatId đối với UserId bằng tính năng render template
            Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(
                templates[0].Id, 
                null,           // whoId (Bỏ qua vì không gửi cho Contact/Lead)
                batchLog.Id     // whatId (Truyền ID Log để merge data)
            );
            
            mail.setToAddresses(toAddresses);
            mail.setSubject(renderedEmail.getSubject());
            mail.setHtmlBody(renderedEmail.getHtmlBody());
            mail.setSaveAsActivity(false); 
        } else {
            mail.setToAddresses(toAddresses);
            mail.setSubject('[FEC MDM Sync] Fallback: Đồng bộ MDM hoàn tất - ' + batchStatus);
            mail.setPlainTextBody('Batch Job: FEC_PushMDMToLiveBatch\nStatus: ' + batchStatus + '\nErrors: ' + totalErrors + '\nLog ID: ' + batchLog.Id);
        }
        
        if (!Test.isRunningTest()) {
            try {
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                System.debug('[finish] Email sent successfully to: ' + toAddresses);
            } catch (Exception ex) {
                System.debug('[finish] Lỗi khi gửi mail: ' + ex.getMessage());
            }
        }

        // 6. Chain Sync (Live → MDM) để đồng bộ ngược các thay đổi
        //    do Live trigger (e.g. inheritance handler) tạo ra sau khi push.
        //    Skip khi đang chạy test hoặc khi push batch failed để tránh sync data lỗi.
        if (!Test.isRunningTest() && batchStatus != 'Failed') {
            try {
                Id syncJobId = Database.executeBatch(new FEC_SyncMasterDataBatch(), 1);
                System.debug('[finish] Chained FEC_SyncMasterDataBatch jobId=' + syncJobId);
            } catch (Exception ex) {
                System.debug('[finish] Lỗi khi chain Sync batch: ' + ex.getMessage());
            }
        }

        System.debug('[finish] RETURN: ' + batchStatus);
    }
}