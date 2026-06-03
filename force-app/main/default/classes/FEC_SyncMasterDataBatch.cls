public with sharing class FEC_SyncMasterDataBatch implements Database.Batchable<String>, Database.Stateful {
    
    // Constants - aliases for FEC_Constants fields used in this class
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
    private static final String FIELD_NATURE_OF_CASE           = FEC_FieldConstants.FIELD_NATURE_OF_CASE;
    private static final String FIELD_STAGE_NAME               = FEC_FieldConstants.FIELD_STAGE_NAME;
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
    private static final String FIELD_NATURE_OF_CASES          = FEC_FieldConstants.FIELD_NATURE_OF_CASES;
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
    private static final String FIELD_PREVIOUS_STAGE           = 'FEC_Previous_Stage__c';
    private static final String FIELD_ACTION_BUTTON            = 'FEC_Action_Button__c';
    private static final String FIELD_NEXT_STAGE               = 'FEC_Next_Stage__c';
    private static final String FIELD_NEXT_QUEUE               = 'FEC_Next_Queue__c';
    private static final String FIELD_TEAM_USER_GROUP          = 'FEC_Team_User_Group__c';
    private static final String PROCESS_STATUS_SYNCED          = FEC_UIConstants.PROCESS_STATUS_SYNCED;
    private static final String OBJ_MDM_PRODUCT_TYPE = FEC_ObjectConstants.OBJ_MDM_PRODUCT_TYPE;
    private static final String OBJ_MDM_BUSINESS_PROCESS = FEC_ObjectConstants.OBJ_MDM_BUSINESS_PROCESS;
    private static final String OBJ_MDM_CATEGORY = FEC_ObjectConstants.OBJ_MDM_CATEGORY;
    private static final String OBJ_MDM_SUB_CATEGORY = FEC_ObjectConstants.OBJ_MDM_SUB_CATEGORY;
    private static final String OBJ_MDM_SUB_CODE = FEC_ObjectConstants.OBJ_MDM_SUB_CODE;
    private static final String OBJ_MDM_NATURE_OF_CASE = FEC_ObjectConstants.OBJ_MDM_NATURE_OF_CASE;
    private static final String OBJ_MDM_CHANNEL = FEC_ObjectConstants.OBJ_MDM_CHANNEL;
    private static final String OBJ_MDM_CASE_STAGE = FEC_ObjectConstants.OBJ_MDM_CASE_STAGE;
    private static final String OBJ_MDM_ADDITIONAL_FIELD = FEC_ObjectConstants.OBJ_MDM_ADDITIONAL_FIELD;
    private static final String OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE = FEC_ObjectConstants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE;
    private static final String OBJ_MDM_MASTER_DATA_SETTING = FEC_ObjectConstants.OBJ_MDM_MASTER_DATA_SETTING;
    private static final String OBJ_PRODUCT_TYPE = FEC_ObjectConstants.OBJ_PRODUCT_TYPE;
    private static final String OBJ_BUSINESS_PROCESS = FEC_ObjectConstants.OBJ_BUSINESS_PROCESS;
    private static final String OBJ_CATEGORY = FEC_ObjectConstants.OBJ_CATEGORY;
    private static final String OBJ_SUB_CATEGORY = FEC_ObjectConstants.OBJ_SUB_CATEGORY;
    private static final String OBJ_SUB_CODE = FEC_ObjectConstants.OBJ_SUB_CODE;
    private static final String OBJ_NATURE_OF_CASE = FEC_ObjectConstants.OBJ_NATURE_OF_CASE;
    private static final String OBJ_CHANNEL = FEC_ObjectConstants.OBJ_CHANNEL;
    private static final String OBJ_ADDITIONAL_FIELD = FEC_ObjectConstants.OBJ_ADDITIONAL_FIELD;
    private static final String OBJ_ADDITIONAL_FIELD_LIST_VALUE = FEC_ObjectConstants.OBJ_ADDITIONAL_FIELD_LIST_VALUE;
    private static final String OBJ_CASE_STAGE = FEC_ObjectConstants.OBJ_CASE_STAGE;
    private static final String OBJ_MASTER_DATA_SETTING = FEC_ObjectConstants.OBJ_MASTER_DATA_SETTING;
    private static final String OBJ_MDM_STAGE_CHANGE = 'FEC_MDM_Stage_Change__c';
    private static final String OBJ_STAGE_CHANGE = 'FEC_Stage_Change__c';
    private static final String OBJ_MDM_ACTION_BUTTON = 'FEC_MDM_Action_Button__c';
    private static final String OBJ_ACTION_BUTTON = 'FEC_Action_Button__c';
    private static final String OBJ_MDM_STAGE_CHANGE_CONDITION      = FEC_ObjectConstants.OBJ_MDM_STAGE_CHANGE_CONDITION;
    private static final String OBJ_STAGE_CHANGE_CONDITION           = FEC_ObjectConstants.OBJ_STAGE_CHANGE_CONDITION;
    private static final String FIELD_STAGE_CHANGE                   = FEC_FieldConstants.FIELD_STAGE_CHANGE;
    private static final String FIELD_MASTER_DATA_SETTING            = FEC_FieldConstants.FIELD_MASTER_DATA_SETTING;
    private static final String FIELD_OPERATOR                       = FEC_FieldConstants.FIELD_OPERATOR;
    private static final String FIELD_VALUE                          = FEC_FieldConstants.FIELD_VALUE;
    private static final String FIELD_VALUE_TYPE                     = FEC_FieldConstants.FIELD_VALUE_TYPE;
    
    // Map key constants
    private static final String MDM_FIELD_KEY = 'mdmField';
    private static final String MDM_OBJ_KEY = 'mdmObj';
    
    // Map of: source lookup field => { mdmField, mdmObjectName }
    // These fields hold IDs from source objects that need to be remapped to MDM object IDs
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
        FIELD_NEXT_STAGE => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_NEXT_STAGE,
            MDM_OBJ_KEY   => OBJ_MDM_CASE_STAGE
        },
        FIELD_ACTION_BUTTON => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_ACTION_BUTTON,
            MDM_OBJ_KEY   => OBJ_MDM_ACTION_BUTTON
        },
        // Stage Change Condition lookups
        FIELD_STAGE_CHANGE => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_STAGE_CHANGE,
            MDM_OBJ_KEY   => OBJ_MDM_STAGE_CHANGE
        },
        FIELD_MASTER_DATA_SETTING => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_MASTER_DATA_SETTING,
            MDM_OBJ_KEY   => OBJ_MDM_MASTER_DATA_SETTING
        }
    };
    
    // Map object-specific lookup fields that need remapping
    // Key: mdmObject -> List of source lookup fields
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
        // Stage Change lookups: Previous Stage, Action Button, Next Stage
        OBJ_MDM_STAGE_CHANGE => new List<String>{
            FIELD_PREVIOUS_STAGE,
            FIELD_ACTION_BUTTON,
            FIELD_NEXT_STAGE
        },
        OBJ_MDM_STAGE_CHANGE_CONDITION => new List<String>{
            FIELD_STAGE_CHANGE, FIELD_MASTER_DATA_SETTING
        }
    };
    
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
        OBJ_MDM_ACTION_BUTTON,      // Must be before Stage Change
        OBJ_MDM_STAGE_CHANGE,
        OBJ_MDM_STAGE_CHANGE_CONDITION
    };
    
    // Map object types that have special handling (lookups that need remapping)
    private static final Set<String> OBJECTS_WITH_LOOKUP_REMAPPING = new Set<String>{
        OBJ_MDM_NATURE_OF_CASE,
        OBJ_MDM_CASE_STAGE,
        OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE,
        OBJ_MDM_MASTER_DATA_SETTING,
        OBJ_MDM_STAGE_CHANGE,
        OBJ_MDM_STAGE_CHANGE_CONDITION
    };
    
    // Objects whose Name field is auto-number (not editable) - skip Name when copying
    private static final Set<String> OBJECTS_WITH_AUTONUMBER_NAME = new Set<String>{
        OBJ_MDM_MASTER_DATA_SETTING,
        OBJ_MDM_NATURE_OF_CASE,
        OBJ_MDM_STAGE_CHANGE,
        OBJ_MDM_STAGE_CHANGE_CONDITION
    };
    
    private Map<String, String> mdmToOriginalMap = new Map<String, String>{
        OBJ_MDM_PRODUCT_TYPE      => OBJ_PRODUCT_TYPE,
        OBJ_MDM_BUSINESS_PROCESS  => OBJ_BUSINESS_PROCESS,
        OBJ_MDM_CATEGORY          => OBJ_CATEGORY,
        OBJ_MDM_SUB_CATEGORY      => OBJ_SUB_CATEGORY,
        OBJ_MDM_SUB_CODE          => OBJ_SUB_CODE,
        OBJ_MDM_NATURE_OF_CASE    => OBJ_NATURE_OF_CASE,
        OBJ_MDM_CHANNEL           => OBJ_CHANNEL,
        OBJ_MDM_ADDITIONAL_FIELD  => OBJ_ADDITIONAL_FIELD,
        OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE => OBJ_ADDITIONAL_FIELD_LIST_VALUE,
        OBJ_MDM_CASE_STAGE          => OBJ_CASE_STAGE,
        OBJ_MDM_MASTER_DATA_SETTING => OBJ_MASTER_DATA_SETTING,
        OBJ_MDM_ACTION_BUTTON       => OBJ_ACTION_BUTTON,
        OBJ_MDM_STAGE_CHANGE        => OBJ_STAGE_CHANGE,
        OBJ_MDM_STAGE_CHANGE_CONDITION => OBJ_STAGE_CHANGE_CONDITION
    };
    
    private Map<String, String> commonFieldMap = new Map<String, String>{
        //Common Fields
        FIELD_NAME => FIELD_NAME,
        FIELD_CODE => FIELD_CODE,
        //Additional Field Fields
        FIELD_FEC_UNIQUE_ID => FIELD_FEC_UNIQUE_ID,
        FIELD_FEC_TYPE => FIELD_FEC_TYPE,
        FIELD_FIELD_MANDATORY => FIELD_FIELD_MANDATORY,
        FIELD_FIELD_STATUS => FIELD_FIELD_STATUS,
        //Additional Field Fields List Value
        FIELD_FEC_ORDER => FIELD_FEC_ORDER,
        //Channel Fields
        FIELD_CHANNEL_ID => FIELD_CHANNEL_ID,
        FIELD_CHANNEL_STATUS => FIELD_CHANNEL_STATUS,
        FIELD_CHANNEL_VI_NAME => FIELD_CHANNEL_VI_NAME,
        FIELD_SELF_SERVICE_FLAG => FIELD_SELF_SERVICE_FLAG,
        //FEC_MDM_Master_Data_Setting__c Fields
        FIELD_APPLICABLE_ROLE => FIELD_APPLICABLE_ROLE,
        FIELD_FIELD_MANDATORY => FIELD_FIELD_MANDATORY,
        FIELD_FIELD_OBJECT_NAME => FIELD_FIELD_OBJECT_NAME,
        FIELD_FIELD_ORDER_DISPLAY => FIELD_FIELD_ORDER_DISPLAY,
        FIELD_FIELD_READONLY => FIELD_FIELD_READONLY,
        FIELD_FIELD_STATUS => FIELD_FIELD_STATUS,
        FIELD_PROPERTY_REFERENCE => FIELD_PROPERTY_REFERENCE,
        FIELD_SECTION => FIELD_SECTION,
        // FIELD_CHANNEL => FIELD_CHANNEL, // Removed: Channel is now handled via OBJECT_LOOKUP_FIELDS remap (Lookup)
        FIELD_DATA_INTEGRATION_MAPPING => FIELD_DATA_INTEGRATION_MAPPING,
        FIELD_FIELD_MASKING => FIELD_FIELD_MASKING,
        FIELD_MASKING_TYPE => FIELD_MASKING_TYPE,
        FIELD_FIELD_REVERTED => FIELD_FIELD_REVERTED,
        FIELD_SUB_SECTION => FIELD_SUB_SECTION,
        FIELD_SUB_SECTION_FIELD_LAYOUT => FIELD_SUB_SECTION_FIELD_LAYOUT,
        FIELD_SUB_SECTION_LAYOUT => FIELD_SUB_SECTION_LAYOUT,
        FIELD_SUB_SECTION_ORDER => FIELD_SUB_SECTION_ORDER,
        FIELD_EDITABLE_USER_GROUP => FIELD_EDITABLE_USER_GROUP,
        FIELD_FIELD_EDITABLE => FIELD_FIELD_EDITABLE,
        FIELD_EDITABLE_ROLE => FIELD_EDITABLE_ROLE,
        'FEC_Field_API_Name__c' => 'FEC_Field_API_Name__c',
        'FEC_Field_Label_Name__c' => 'FEC_Field_Label_Name__c',
        //NOC Lookup Fields
        FIELD_ALIAS => FIELD_ALIAS,
        FIELD_NAME_VN => FIELD_NAME_VN,
        FIELD_POS_ORDER => FIELD_POS_ORDER,
        FIELD_STATUS => FIELD_STATUS,
        FIELD_ACTIVE => FIELD_ACTIVE,
        //Nature of Case Fields
        FIELD_CUSTOMER_TYPE => FIELD_CUSTOMER_TYPE,
        FIELD_BUSINESS_PROCESS => FIELD_BUSINESS_PROCESS,
        FIELD_PRODUCT_TYPE => FIELD_PRODUCT_TYPE,
        FIELD_PRODUCT_TYPE_STATUS => FIELD_PRODUCT_TYPE_STATUS,
        FIELD_CATEGORY => FIELD_CATEGORY,
        FIELD_CATEGORY_STATUS => FIELD_CATEGORY_STATUS,
        FIELD_SUB_CATEGORY => FIELD_SUB_CATEGORY,
        FIELD_SUB_CATEGORY_STATUS => FIELD_SUB_CATEGORY_STATUS,
        FIELD_SUB_CODE => FIELD_SUB_CODE,
        FIELD_SUB_CODE_STATUS => FIELD_SUB_CODE_STATUS,
        FIELD_USER_GROUP => FIELD_USER_GROUP,
        FIELD_ROLE_NAMES => FIELD_ROLE_NAMES,
        FIELD_DEFAULT_STAGE => FIELD_DEFAULT_STAGE,
        FIELD_STAGE_NAME => FIELD_STAGE_NAME,
        // Stage Change Fields (FEC_Stage_Change__c)
        FIELD_PREVIOUS_STAGE  => FIELD_PREVIOUS_STAGE,
        FIELD_ACTION_BUTTON   => FIELD_ACTION_BUTTON,
        FIELD_NEXT_STAGE      => FIELD_NEXT_STAGE,
        FIELD_NEXT_QUEUE      => FIELD_NEXT_QUEUE,
        FIELD_TEAM_USER_GROUP => FIELD_TEAM_USER_GROUP,
        FIELD_ACTIVE          => FIELD_ACTIVE,
        // Stage Change Condition fields
        FIELD_OPERATOR    => FIELD_OPERATOR,
        FIELD_VALUE       => FIELD_VALUE,
        FIELD_VALUE_TYPE  => FIELD_VALUE_TYPE
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
            // STEP 0: Populate FEC_Code__c from Name/Id if it's null on Source object
            populateMissingCodes(targetObjName);
            
            // Build filtered field map - only fields that exist on both objects
            Map<String, Schema.SObjectField> targetFields = gd.get(targetObjName).getDescribe().fields.getMap();
            Map<String, Schema.SObjectField> mdmFieldsMap = gd.get(mdmObjName).getDescribe().fields.getMap();

            // Ensure FEC_Code__c is populated on existing MDM records if they came from Name
            if (mdmFieldsMap.containsKey(FIELD_CODE)) {
                List<SObject> emptyMdmCodes = Database.query('SELECT Id, Name FROM ' + mdmObjName + ' WHERE ' + FIELD_CODE + ' = null');
                if (!emptyMdmCodes.isEmpty()) {
                    for(SObject m : emptyMdmCodes) m.put(FIELD_CODE, m.get('Id'));
                    update emptyMdmCodes;
                }
            }
            
            Set<String> validQueryFields = new Set<String>();
            validQueryFields.add('Id');
            if (targetFields.containsKey(FIELD_CODE)) {
                validQueryFields.add(FIELD_CODE);
            }
            
            // Build filtered field map - only fields that exist on both objects
            Map<String, String> filteredFieldMap = new Map<String, String>();
            for (String liveField : commonFieldMap.keySet()) {
                String mdmField = commonFieldMap.get(liveField);
                if (targetFields.containsKey(liveField) && mdmFieldsMap.containsKey(mdmField)) {
                    validQueryFields.add(liveField);
                    filteredFieldMap.put(liveField, mdmField);
                }
            }
            
            // Also query source lookup fields so we can remap them
            if (OBJECTS_WITH_LOOKUP_REMAPPING.contains(mdmObjName)) {
                List<String> objLookupFields = OBJECT_LOOKUP_FIELDS.get(mdmObjName);
                if (objLookupFields != null) {
                    for (String srcLookupField : objLookupFields) {
                        if (targetFields.containsKey(srcLookupField)) {
                            validQueryFields.add(srcLookupField);
                        }
                    }
                }
            }
            
            // STEP 2: Query source records
            // Normalize field names to lowercase to prevent SOQL duplicate field errors
            // (Apex Set<String> is case-sensitive but SOQL field names are case-insensitive)
            Set<String> normalizedFields = new Set<String>();
            for (String f : validQueryFields) {
                normalizedFields.add(f.toLowerCase());
            }
            String sourceQuery = 'SELECT ' + String.join(new List<String>(normalizedFields), ', ') + ' FROM ' + targetObjName;
            List<SObject> sourceRecords = Database.query(sourceQuery);
            
            // Build sourceCodes
            Set<String> sourceCodes = new Set<String>();
            for (SObject source : sourceRecords) {
                String codeValue = (String)source.get(FIELD_CODE);
                if (String.isNotBlank(codeValue)) sourceCodes.add(codeValue);
            }
            
            // STEP 3: Query MDM records
            List<SObject> existingMdmRecords = Database.query('SELECT Id, ' + FIELD_CODE + ' FROM ' + mdmObjName);
            Map<String, Id> mdmCodeToIdMap = new Map<String, Id>();
            for (SObject mdmRecord : existingMdmRecords) {
                String mdmCode = (String)mdmRecord.get(FIELD_CODE);
                if (String.isNotBlank(mdmCode)) mdmCodeToIdMap.put(mdmCode, mdmRecord.Id);
            }
            
            // STEP 3b: Build lookup remap maps
            Map<String, Map<Id, Id>> lookupRemapMaps = new Map<String, Map<Id, Id>>();
            if (OBJECTS_WITH_LOOKUP_REMAPPING.contains(mdmObjName)) {
                buildLookupRemapMaps(mdmObjName, sourceRecords, targetFields, lookupRemapMaps, gd);
            }

            // Build text-typed Id remap (Live → MDM, e.g. FEC_Decision_Rule__c.FEC_Key_ID__c)
            Map<String, Map<Id, Id>> textIdRemapMaps = new Map<String, Map<Id, Id>>();
            if (FEC_MDMBatchConfig.OBJECTS_WITH_TEXT_ID_REMAPPING.contains(mdmObjName)) {
                textIdRemapMaps = buildTextIdRemapMapsLiveToMdm(mdmObjName, sourceRecords, gd);
            }
            
            // STEP 4: DELETE obsolete MDM records
            Set<Id> mdmIdsToKeep = new Set<Id>();
            for (String mdmCode : mdmCodeToIdMap.keySet()) {
                if (sourceCodes.contains(mdmCode)) {
                    mdmIdsToKeep.add(mdmCodeToIdMap.get(mdmCode));
                }
            }
            List<SObject> recordsToDelete = new List<SObject>();
            for (SObject mdmRecord : existingMdmRecords) {
                if (!mdmIdsToKeep.contains(mdmRecord.Id)) {
                    recordsToDelete.add(mdmRecord);
                }
            }
            if (!recordsToDelete.isEmpty()) {
                delete recordsToDelete;
            }
            
            // STEP 5: Prepare records for UPSERT
            List<SObject> targetRecords = new List<SObject>();
            for (SObject source : sourceRecords) {
                SObject target = gd.get(mdmObjName).newSObject();
                String codeValue = (String)source.get(FIELD_CODE);
                if (String.isNotBlank(codeValue)) {
                    target.put(FIELD_CODE, codeValue);
                }
                List<String> thisObjLookupFields = OBJECT_LOOKUP_FIELDS.containsKey(mdmObjName)
                    ? OBJECT_LOOKUP_FIELDS.get(mdmObjName)
                    : new List<String>();
                Boolean skipName = OBJECTS_WITH_AUTONUMBER_NAME.contains(mdmObjName);
                for (String liveField : filteredFieldMap.keySet()) {
                    if (thisObjLookupFields.contains(liveField)) continue;
                    if (skipName && liveField == FIELD_NAME) continue;
                    String mdmField = filteredFieldMap.get(liveField);
                    if (source.get(liveField) != null) {
                        target.put(mdmField, source.get(liveField));
                    }
                }
                if (OBJECTS_WITH_LOOKUP_REMAPPING.contains(mdmObjName)) {
                    remapLookupFields(source, target, targetFields, mdmFieldsMap, lookupRemapMaps, mdmObjName);
                }
                if (FEC_MDMBatchConfig.OBJECTS_WITH_TEXT_ID_REMAPPING.contains(mdmObjName)) {
                    remapTextIdFieldsLiveToMdm(source, target, mdmObjName, textIdRemapMaps);
                }
                targetRecords.add(target);
            }
            
            // STEP 6: UPSERT records to MDM
            if (!targetRecords.isEmpty()) {
                Schema.SObjectField externalIdField = mdmFieldsMap.get(FIELD_CODE);
                Database.UpsertResult[] results = Database.upsert(targetRecords, externalIdField, false);
                List<Id> upsertedIds = new List<Id>();
                for (Database.UpsertResult result : results) {
                    if (result.isSuccess()) {
                        upsertedIds.add(result.getId());
                    } else {
                        for (Database.Error err : result.getErrors()) {
                            System.debug('UPSERT ERROR: ' + err.getMessage() + ' | Fields: ' + err.getFields());
                        }
                    }
                }
                
                // STEP 7: Update Process_Change_Status to SYNCED
                if (!upsertedIds.isEmpty()) {
                    List<SObject> recordsToUpdateStatus = new List<SObject>();
                    for (Id recordId : upsertedIds) {
                        SObject record = gd.get(mdmObjName).newSObject();
                        record.put('Id', recordId);
                        record.put(FIELD_PROCESS_CHANGE_STATUS, PROCESS_STATUS_SYNCED);
                        recordsToUpdateStatus.add(record);
                    }
                    Boolean prev = FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled;
                    try {
                        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
                        update recordsToUpdateStatus;
                    } finally {
                        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = prev;
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error syncing ' + mdmObjName + ': ' + e.getMessage());
            throw e;
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        try {
            AsyncApexJob job = [
                SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
                FROM AsyncApexJob WHERE Id = :bc.getJobId()
            ];

            String batchStatus = (job.NumberOfErrors > 0 || job.Status == 'Failed') ? 'Failed' : 'Success';

            FEC_Batch_Log__c batchLog = new FEC_Batch_Log__c(
                FEC_Batch_Name__c      = 'FEC_SyncMasterDataBatch',
                FEC_Job_ID__c          = job.Id,
                FEC_Status__c          = batchStatus,
                FEC_Total_Job_Items__c = job.TotalJobItems,
                FEC_Processed_Items__c = job.JobItemsProcessed,
                FEC_Error_Count__c     = job.NumberOfErrors
            );
            insert batchLog;
        } catch (Exception ex) {
            System.debug('[FEC_SyncMasterDataBatch.finish] Error logging batch: ' + ex.getMessage());
        }
    }
    
    private void populateMissingCodes(String objectName) {
        try {
            // Check if FEC_Code__c field exists on this object before querying
            Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();
            if (!fieldsMap.containsKey(FIELD_CODE)) return;

            List<SObject> recordsToUpdate = Database.query(
                'SELECT Id, ' + FIELD_CODE + ' FROM ' + objectName + ' WHERE ' + FIELD_CODE + ' = null'
                );
            if (recordsToUpdate.isEmpty()) return;
            for (SObject record : recordsToUpdate) {
                String Id = (String) record.get('Id');
                String code = Id;
                record.put(FIELD_CODE, code);
            }
            update recordsToUpdate;
        } catch (Exception e) {
            System.debug('Error populating missing codes in ' + objectName + ': ' + e.getMessage());
        }
    }
    
    private void buildLookupRemapMaps(String mdmObjName, List<SObject> sourceRecords,
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
            if (!gd.containsKey(mdmLookupObj)) {
                lookupRemapMaps.put(srcLookupField, new Map<Id, Id>());
                continue;
            }
            String srcObjName = mdmToOriginalMap.containsKey(mdmLookupObj)
                ? mdmToOriginalMap.get(mdmLookupObj)
                : null;
            Map<Id, Id> srcToMdmIdMap = new Map<Id, Id>();
            if (srcObjName != null && gd.containsKey(srcObjName)) {
                Set<Id> usedSourceIds = new Set<Id>();
                for (SObject source : sourceRecords) {
                    Id lookupId = (Id)source.get(srcLookupField);
                    if (lookupId != null) usedSourceIds.add(lookupId);
                }
                if (!usedSourceIds.isEmpty()) {
                    Map<Id, String> srcIdToCode = new Map<Id, String>();
                    for (SObject srcLookupRecord : Database.query(
                        'SELECT Id, ' + FIELD_CODE + ' FROM ' + srcObjName + ' WHERE Id IN :usedSourceIds'
                    )) {
                        String code = (String)srcLookupRecord.get(FIELD_CODE);
                        if (String.isNotBlank(code)) srcIdToCode.put(srcLookupRecord.Id, code);
                    }
                    Map<String, Id> mdmCodeToId = new Map<String, Id>();
                    for (SObject mdmLookupRecord : Database.query(
                        'SELECT Id, ' + FIELD_CODE + ' FROM ' + mdmLookupObj
                    )) {
                        String code = (String)mdmLookupRecord.get(FIELD_CODE);
                        if (String.isNotBlank(code)) mdmCodeToId.put(code, mdmLookupRecord.Id);
                    }
                    for (Id srcId : srcIdToCode.keySet()) {
                        String code = srcIdToCode.get(srcId);
                        if (mdmCodeToId.containsKey(code)) {
                            srcToMdmIdMap.put(srcId, mdmCodeToId.get(code));
                        }
                    }
                }
            }
            lookupRemapMaps.put(srcLookupField, srcToMdmIdMap);
        }
    }
    
    private void remapLookupFields(SObject source, SObject target,
    Map<String, Schema.SObjectField> targetFields,
    Map<String, Schema.SObjectField> mdmFieldsMap,
    Map<String, Map<Id, Id>> lookupRemapMaps,
    String mdmObjName) {
        
        List<String> objectLookupFields = OBJECT_LOOKUP_FIELDS.get(mdmObjName);
        if (objectLookupFields == null || objectLookupFields.isEmpty()) return;
        for (String srcLookupField : objectLookupFields) {
            if (!targetFields.containsKey(srcLookupField)) continue;
            String mdmLookupField = LOOKUP_FIELD_MDM_MAP.get(srcLookupField).get(MDM_FIELD_KEY);
            if (!mdmFieldsMap.containsKey(mdmLookupField)) continue;
            Id sourceId = (Id)source.get(srcLookupField);
            if (sourceId == null) continue;
            Map<Id, Id> remapMap = lookupRemapMaps.get(srcLookupField);
            if (remapMap != null && remapMap.containsKey(sourceId)) {
                target.put(mdmLookupField, remapMap.get(sourceId));
            }
        }
    }

    /**
     * Live → MDM remap for text-typed Id fields (e.g. FEC_Key_ID__c).
     * Source = Live record, target = MDM record.
     * Field name is shared (FEC_Key_ID__c on both sides).
     */
    private void remapTextIdFieldsLiveToMdm(SObject source, SObject target, String mdmObjName,
        Map<String, Map<Id, Id>> textIdRemapMaps) {

        Map<String, String> textFields = FEC_MDMBatchConfig.TEXT_ID_REMAP_FIELDS.get(mdmObjName);
        if (textFields == null || textFields.isEmpty()) return;

        for (String fieldName : textFields.keySet()) {
            String rawValue = (String) source.get(fieldName);
            if (String.isBlank(rawValue)) continue;
            try {
                Id liveId = (Id) rawValue;
                Map<Id, Id> remapMap = textIdRemapMaps.get(fieldName);
                if (remapMap != null && remapMap.containsKey(liveId)) {
                    target.put(fieldName, String.valueOf(remapMap.get(liveId)));
                }
            } catch (Exception ignored) {
                // Not a valid Id — leave as-is
            }
        }
    }

    /**
     * Build map: textFieldName → (liveRefId → mdmRefId) by matching FEC_Code__c.
     */
    private Map<String, Map<Id, Id>> buildTextIdRemapMapsLiveToMdm(String mdmObjName,
        List<SObject> sourceRecords, Map<String, Schema.SObjectType> gd) {

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
            Set<Id> referencedIds = new Set<Id>();
            for (SObject s : sourceRecords) {
                String raw = (String) s.get(fieldName);
                if (String.isBlank(raw)) continue;
                try { referencedIds.add((Id) raw); } catch (Exception ignored) {}
            }
            if (referencedIds.isEmpty()) {
                result.put(fieldName, new Map<Id, Id>());
                continue;
            }
            // Live Id → Code
            Map<Id, String> liveIdToCode = new Map<Id, String>();
            for (SObject r : Database.query(
                'SELECT Id, ' + FEC_MDMBatchConfig.FIELD_CODE + ' FROM ' + liveRefObj + ' WHERE Id IN :referencedIds')) {
                String code = (String) r.get(FEC_MDMBatchConfig.FIELD_CODE);
                if (String.isNotBlank(code)) liveIdToCode.put(r.Id, code);
            }
            // Code → MDM Id
            Map<String, Id> codeToMdmId = new Map<String, Id>();
            for (SObject r : Database.query(
                'SELECT Id, ' + FEC_MDMBatchConfig.FIELD_CODE + ' FROM ' + mdmRefObj)) {
                String code = (String) r.get(FEC_MDMBatchConfig.FIELD_CODE);
                if (String.isNotBlank(code)) codeToMdmId.put(code, r.Id);
            }
            Map<Id, Id> idMap = new Map<Id, Id>();
            for (Id liveId : liveIdToCode.keySet()) {
                Id mdmId = codeToMdmId.get(liveIdToCode.get(liveId));
                if (mdmId != null) idMap.put(liveId, mdmId);
            }
            result.put(fieldName, idMap);
        }
        return result;
    }
}