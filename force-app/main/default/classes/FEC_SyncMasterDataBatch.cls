public class FEC_SyncMasterDataBatch implements Database.Batchable<String>, Database.Stateful {
    
    // Constants - aliases for FEC_Constants fields used in this class
    private static final String FIELD_CODE                     = FEC_Constants.FIELD_CODE;
    private static final String FIELD_NAME                     = FEC_Constants.FIELD_NAME;
    private static final String FIELD_PROCESS_CHANGE_STATUS    = FEC_Constants.FIELD_PROCESS_CHANGE_STATUS;
    private static final String FIELD_ALIAS                    = FEC_Constants.FIELD_ALIAS;
    private static final String FIELD_NAME_VN                  = FEC_Constants.FIELD_NAME_VN;
    private static final String FIELD_STATUS                   = FEC_Constants.FIELD_STATUS;
    private static final String FIELD_ACTIVE                   = FEC_Constants.FIELD_ACTIVE;
    private static final String FIELD_POS_ORDER                = FEC_Constants.FIELD_POS_ORDER;
    private static final String FIELD_FEC_UNIQUE_ID            = FEC_Constants.FIELD_FEC_UNIQUE_ID;
    private static final String FIELD_FEC_TYPE                 = FEC_Constants.FIELD_FEC_TYPE;
    private static final String FIELD_FEC_ORDER                = FEC_Constants.FIELD_FEC_ORDER;
    private static final String FIELD_FIELD_MANDATORY          = FEC_Constants.FIELD_FIELD_MANDATORY;
    private static final String FIELD_FIELD_STATUS             = FEC_Constants.FIELD_FIELD_STATUS;
    private static final String FIELD_FIELD_READONLY           = FEC_Constants.FIELD_FIELD_READONLY;
    private static final String FIELD_FIELD_OBJECT_NAME        = FEC_Constants.FIELD_FIELD_OBJECT_NAME;
    private static final String FIELD_FIELD_ORDER_DISPLAY      = FEC_Constants.FIELD_FIELD_ORDER_DISPLAY;
    private static final String FIELD_PROPERTY_REFERENCE       = FEC_Constants.FIELD_PROPERTY_REFERENCE;
    private static final String FIELD_SECTION                  = FEC_Constants.FIELD_SECTION;
    private static final String FIELD_APPLICABLE_ROLE          = FEC_Constants.FIELD_APPLICABLE_ROLE;
    private static final String FIELD_DATA_INTEGRATION_MAPPING = FEC_Constants.FIELD_DATA_INTEGRATION_MAPPING;
    private static final String FIELD_CHANNEL_ID               = FEC_Constants.FIELD_CHANNEL_ID;
    private static final String FIELD_CHANNEL_STATUS           = FEC_Constants.FIELD_CHANNEL_STATUS;
    private static final String FIELD_CHANNEL_VI_NAME          = FEC_Constants.FIELD_CHANNEL_VI_NAME;
    private static final String FIELD_CHANNEL                  = FEC_Constants.FIELD_CHANNEL;
    private static final String FIELD_NATURE_OF_CASE           = FEC_Constants.FIELD_NATURE_OF_CASE;
    private static final String FIELD_STAGE_NAME               = FEC_Constants.FIELD_STAGE_NAME;
    private static final String FIELD_CUSTOMER_TYPE            = FEC_Constants.FIELD_CUSTOMER_TYPE;
    private static final String FIELD_BUSINESS_PROCESS         = FEC_Constants.FIELD_BUSINESS_PROCESS;
    private static final String FIELD_PRODUCT_TYPE             = FEC_Constants.FIELD_PRODUCT_TYPE;
    private static final String FIELD_PRODUCT_TYPE_STATUS      = FEC_Constants.FIELD_PRODUCT_TYPE_STATUS;
    private static final String FIELD_CATEGORY                 = FEC_Constants.FIELD_CATEGORY;
    private static final String FIELD_CATEGORY_STATUS          = FEC_Constants.FIELD_CATEGORY_STATUS;
    private static final String FIELD_SUB_CATEGORY             = FEC_Constants.FIELD_SUB_CATEGORY;
    private static final String FIELD_SUB_CATEGORY_STATUS      = FEC_Constants.FIELD_SUB_CATEGORY_STATUS;
    private static final String FIELD_SUB_CODE                 = FEC_Constants.FIELD_SUB_CODE;
    private static final String FIELD_SUB_CODE_STATUS          = FEC_Constants.FIELD_SUB_CODE_STATUS;
    private static final String FIELD_USER_GROUP               = FEC_Constants.FIELD_USER_GROUP;
    private static final String FIELD_ROLE_NAMES               = FEC_Constants.FIELD_ROLE_NAMES;
    private static final String FIELD_ADDITIONAL_FIELD         = FEC_Constants.FIELD_ADDITIONAL_FIELD;
    private static final String PROCESS_STATUS_SYNCED          = FEC_Constants.PROCESS_STATUS_SYNCED;
    private static final String OBJ_MDM_PRODUCT_TYPE = FEC_Constants.OBJ_MDM_PRODUCT_TYPE;
    private static final String OBJ_MDM_BUSINESS_PROCESS = FEC_Constants.OBJ_MDM_BUSINESS_PROCESS;
    private static final String OBJ_MDM_CATEGORY = FEC_Constants.OBJ_MDM_CATEGORY;
    private static final String OBJ_MDM_SUB_CATEGORY = FEC_Constants.OBJ_MDM_SUB_CATEGORY;
    private static final String OBJ_MDM_SUB_CODE = FEC_Constants.OBJ_MDM_SUB_CODE;
    private static final String OBJ_MDM_NATURE_OF_CASE = FEC_Constants.OBJ_MDM_NATURE_OF_CASE;
    private static final String OBJ_MDM_CHANNEL = FEC_Constants.OBJ_MDM_CHANNEL;
    private static final String OBJ_MDM_CASE_STAGE = FEC_Constants.OBJ_MDM_CASE_STAGE;
    private static final String OBJ_MDM_ADDITIONAL_FIELD = FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD;
    private static final String OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE = FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE;
    private static final String OBJ_MDM_MASTER_DATA_SETTING = FEC_Constants.OBJ_MDM_MASTER_DATA_SETTING;
    private static final String OBJ_PRODUCT_TYPE = FEC_Constants.OBJ_PRODUCT_TYPE;
    private static final String OBJ_BUSINESS_PROCESS = FEC_Constants.OBJ_BUSINESS_PROCESS;
    private static final String OBJ_CATEGORY = FEC_Constants.OBJ_CATEGORY;
    private static final String OBJ_SUB_CATEGORY = FEC_Constants.OBJ_SUB_CATEGORY;
    private static final String OBJ_SUB_CODE = FEC_Constants.OBJ_SUB_CODE;
    private static final String OBJ_NATURE_OF_CASE = FEC_Constants.OBJ_NATURE_OF_CASE;
    private static final String OBJ_CHANNEL = FEC_Constants.OBJ_CHANNEL;
    private static final String OBJ_ADDITIONAL_FIELD = FEC_Constants.OBJ_ADDITIONAL_FIELD;
    private static final String OBJ_ADDITIONAL_FIELD_LIST_VALUE = FEC_Constants.OBJ_ADDITIONAL_FIELD_LIST_VALUE;
    private static final String OBJ_CASE_STAGE = FEC_Constants.OBJ_CASE_STAGE;
    private static final String OBJ_MASTER_DATA_SETTING = FEC_Constants.OBJ_MASTER_DATA_SETTING;
    
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
        FIELD_CHANNEL => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_CHANNEL,
            MDM_OBJ_KEY   => OBJ_MDM_CHANNEL
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
            FIELD_BUSINESS_PROCESS
        },
        OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE => new List<String>{
            FIELD_ADDITIONAL_FIELD
        },
        OBJ_MDM_MASTER_DATA_SETTING => new List<String>{
            FIELD_STAGE_NAME,
            FIELD_NATURE_OF_CASE,
            FIELD_ADDITIONAL_FIELD
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
        OBJ_MDM_MASTER_DATA_SETTING
    };
    
    // Map object types that have special handling (lookups that need remapping)
    private static final Set<String> OBJECTS_WITH_LOOKUP_REMAPPING = new Set<String>{
        OBJ_MDM_NATURE_OF_CASE,
        OBJ_MDM_CASE_STAGE,
        OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE,
        OBJ_MDM_MASTER_DATA_SETTING
    };
    
    // Objects whose Name field is auto-number (not editable) - skip Name when copying
    private static final Set<String> OBJECTS_WITH_AUTONUMBER_NAME = new Set<String>{
        OBJ_MDM_MASTER_DATA_SETTING
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
        OBJ_MDM_MASTER_DATA_SETTING => OBJ_MASTER_DATA_SETTING
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
        //FEC_MDM_Master_Data_Setting__c Fields
        FIELD_APPLICABLE_ROLE => FIELD_APPLICABLE_ROLE,
        FIELD_FIELD_MANDATORY => FIELD_FIELD_MANDATORY,
        FIELD_FIELD_OBJECT_NAME => FIELD_FIELD_OBJECT_NAME,
        FIELD_FIELD_ORDER_DISPLAY => FIELD_FIELD_ORDER_DISPLAY,
        FIELD_FIELD_READONLY => FIELD_FIELD_READONLY,
        FIELD_FIELD_STATUS => FIELD_FIELD_STATUS,
        FIELD_PROPERTY_REFERENCE => FIELD_PROPERTY_REFERENCE,
        FIELD_SECTION => FIELD_SECTION,
        FIELD_CHANNEL => FIELD_CHANNEL,
        FIELD_DATA_INTEGRATION_MAPPING => FIELD_DATA_INTEGRATION_MAPPING,
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
        FIELD_STAGE_NAME => FIELD_STAGE_NAME
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
            // STEP 0: Populate FEC_Code__c from Name if it's null
            populateMissingCodes(targetObjName);
            // STEP 1: Build query fields - only fields that exist on both source and MDM
            Map<String, Schema.SObjectField> targetFields = gd.get(targetObjName).getDescribe().fields.getMap();
            Map<String, Schema.SObjectField> mdmFieldsMap = gd.get(mdmObjName).getDescribe().fields.getMap();
            Set<String> validQueryFields = new Set<String>();
            validQueryFields.add('Id');
            
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
            String sourceQuery = 'SELECT ' + String.join(new List<String>(validQueryFields), ', ') + ' FROM ' + targetObjName;
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
    
    public void finish(Database.BatchableContext bc) { }
    
    private void populateMissingCodes(String objectName) {
        try {
            List<SObject> recordsToUpdate = Database.query(
                'SELECT Id, Name, ' + FIELD_CODE + ' FROM ' + objectName + ' WHERE ' + FIELD_CODE + ' = null'
                );
            if (recordsToUpdate.isEmpty()) return;
            for (SObject record : recordsToUpdate) {
                String name = (String) record.get('Name');
                if (String.isNotBlank(name)) {
                    record.put(FIELD_CODE, name);
                }
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
}