public class FEC_PushMDMToLiveBatch implements Database.Batchable<String>, Database.Stateful {
    
    // Constants - aliases for FEC_Constants used in this class
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
    private static final String FIELD_EXTERNAL_ID              = FEC_Constants.FIELD_EXTERNAL_ID;
    private static final String FIELD_NATURE_OF_CASE           = FEC_Constants.FIELD_NATURE_OF_CASE;
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
    private static final String FIELD_STAGE_NAME               = FEC_Constants.FIELD_STAGE_NAME;
    private static final String FIELD_ADDITIONAL_FIELD         = FEC_Constants.FIELD_ADDITIONAL_FIELD;
    
    private static final String PROCESS_STATUS_NEW             = FEC_Constants.PROCESS_STATUS_NEW;
    private static final String PROCESS_STATUS_UPDATE          = FEC_Constants.PROCESS_STATUS_UPDATE;
    private static final String PROCESS_STATUS_SYNCED          = FEC_Constants.PROCESS_STATUS_SYNCED;
    
    private static final String OBJ_MDM_PRODUCT_TYPE                = FEC_Constants.OBJ_MDM_PRODUCT_TYPE;
    private static final String OBJ_MDM_BUSINESS_PROCESS            = FEC_Constants.OBJ_MDM_BUSINESS_PROCESS;
    private static final String OBJ_MDM_CATEGORY                    = FEC_Constants.OBJ_MDM_CATEGORY;
    private static final String OBJ_MDM_SUB_CATEGORY                = FEC_Constants.OBJ_MDM_SUB_CATEGORY;
    private static final String OBJ_MDM_SUB_CODE                    = FEC_Constants.OBJ_MDM_SUB_CODE;
    private static final String OBJ_MDM_NATURE_OF_CASE              = FEC_Constants.OBJ_MDM_NATURE_OF_CASE;
    private static final String OBJ_MDM_CHANNEL                     = FEC_Constants.OBJ_MDM_CHANNEL;
    private static final String OBJ_MDM_CASE_STAGE                  = FEC_Constants.OBJ_MDM_CASE_STAGE;
    private static final String OBJ_MDM_ADDITIONAL_FIELD            = FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD;
    private static final String OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE = FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE;
    private static final String OBJ_MDM_MASTER_DATA_SETTING         = FEC_Constants.OBJ_MDM_MASTER_DATA_SETTING;
    
    private static final String OBJ_PRODUCT_TYPE                = FEC_Constants.OBJ_PRODUCT_TYPE;
    private static final String OBJ_BUSINESS_PROCESS            = FEC_Constants.OBJ_BUSINESS_PROCESS;
    private static final String OBJ_CATEGORY                    = FEC_Constants.OBJ_CATEGORY;
    private static final String OBJ_SUB_CATEGORY                = FEC_Constants.OBJ_SUB_CATEGORY;
    private static final String OBJ_SUB_CODE                    = FEC_Constants.OBJ_SUB_CODE;
    private static final String OBJ_NATURE_OF_CASE              = FEC_Constants.OBJ_NATURE_OF_CASE;
    private static final String OBJ_CHANNEL                     = FEC_Constants.OBJ_CHANNEL;
    private static final String OBJ_CASE_STAGE                  = FEC_Constants.OBJ_CASE_STAGE;
    private static final String OBJ_ADDITIONAL_FIELD            = FEC_Constants.OBJ_ADDITIONAL_FIELD;
    private static final String OBJ_ADDITIONAL_FIELD_LIST_VALUE = FEC_Constants.OBJ_ADDITIONAL_FIELD_LIST_VALUE;
    private static final String OBJ_MASTER_DATA_SETTING         = FEC_Constants.OBJ_MASTER_DATA_SETTING;
    
    private static final String REL_NATURE_OF_CASE       = FEC_Constants.REL_NATURE_OF_CASE;
    private static final String REL_ADDITIONAL_FIELD     = FEC_Constants.REL_ADDITIONAL_FIELD;
    private static final String REL_STAGE_NAME           = FEC_Constants.REL_STAGE_NAME;
    private static final String REL_PRODUCT_TYPE_NAME    = FEC_Constants.REL_PRODUCT_TYPE_NAME;
    private static final String REL_BUSINESS_PROCESS_NAME= FEC_Constants.REL_BUSINESS_PROCESS_NAME;
    private static final String REL_CATEGORY_NAME        = FEC_Constants.REL_CATEGORY_NAME;
    private static final String REL_SUB_CATEGORY_NAME    = FEC_Constants.REL_SUB_CATEGORY_NAME;
    private static final String REL_SUB_CODE_NAME        = FEC_Constants.REL_SUB_CODE_NAME;
    
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
        FIELD_CHANNEL => new Map<String, String>{
            MDM_FIELD_KEY => FIELD_CHANNEL,
            MDM_OBJ_KEY   => OBJ_MDM_CHANNEL
        }
    };
    
    // Map object-specific lookup fields that need remapping
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
            FIELD_STAGE_NAME, FIELD_NATURE_OF_CASE, FIELD_CHANNEL
        }
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
        OBJ_MDM_MASTER_DATA_SETTING,
        OBJ_MDM_NATURE_OF_CASE
    };
    
    private Set<String> uniqueErrors = new Set<String>();
    
    private List<String> executionOrder = new List<String>{
        OBJ_MDM_PRODUCT_TYPE,
        OBJ_MDM_BUSINESS_PROCESS,
        OBJ_MDM_CATEGORY,
        OBJ_MDM_SUB_CATEGORY,
        OBJ_MDM_SUB_CODE,
        OBJ_MDM_CHANNEL,
        OBJ_MDM_MASTER_DATA_SETTING,
        OBJ_MDM_CASE_STAGE,
        OBJ_MDM_ADDITIONAL_FIELD,
        OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE,
        OBJ_MDM_NATURE_OF_CASE
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
        OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE => OBJ_ADDITIONAL_FIELD_LIST_VALUE
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
        //Additional Field Fields List Value
        FIELD_FEC_ORDER             => FIELD_FEC_ORDER,
        //Channel Fields
        FIELD_CHANNEL_ID            => FIELD_CHANNEL_ID,
        FIELD_CHANNEL_STATUS        => FIELD_CHANNEL_STATUS,
        FIELD_CHANNEL_VI_NAME       => FIELD_CHANNEL_VI_NAME,
        //FEC_MDM_Master_Data_Setting__c Fields
        FIELD_APPLICABLE_ROLE       => FIELD_APPLICABLE_ROLE,
        FIELD_FIELD_OBJECT_NAME     => FIELD_FIELD_OBJECT_NAME,
        FIELD_FIELD_ORDER_DISPLAY   => FIELD_FIELD_ORDER_DISPLAY,
        FIELD_FIELD_READONLY        => FIELD_FIELD_READONLY,
        FIELD_PROPERTY_REFERENCE    => FIELD_PROPERTY_REFERENCE,
        FIELD_SECTION               => FIELD_SECTION,
        FIELD_CHANNEL               => FIELD_CHANNEL,
        FIELD_DATA_INTEGRATION_MAPPING => FIELD_DATA_INTEGRATION_MAPPING,
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
        FIELD_STAGE_NAME            => FIELD_STAGE_NAME
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
            List<SObject> insertList = buildTargetList(mdmNew, mdmObjName, targetObjName, filteredFieldMap, lookupRemapMaps, gd);
            List<SObject> updateList = buildTargetList(mdmUpdate, mdmObjName, targetObjName, filteredFieldMap, lookupRemapMaps, gd);
            
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
    
    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed,
                        TotalJobItems, CreatedBy.Email, CreatedById
                        FROM AsyncApexJob WHERE Id = :bc.getJobId()];
        
        // Create email using email template
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] {job.CreatedBy.Email});
        
        // Get the email template - you can customize the developer name
        List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate 
                                  WHERE DeveloperName = 'FEC_PushMDM_Batch_Completion' 
                                  LIMIT 1];
        
        if (!templates.isEmpty()) {
            // Use email template
            mail.setTemplateId(templates[0].Id);
            mail.setTargetObjectId(job.CreatedById);
            mail.setWhatId(null);
        } else {
            // Fallback: Create plain text email if template doesn't exist
            mail.setSubject('FEC PushMDM Batch Job Completion Report');
            
            String emailBody = 'Batch Job Status Report\n\n';
            emailBody += 'Job Status: ' + job.Status + '\n';
            emailBody += 'Job Items Processed: ' + job.JobItemsProcessed + '\n';
            emailBody += 'Total Job Items: ' + job.TotalJobItems + '\n';
            emailBody += 'Number of Errors: ' + job.NumberOfErrors + '\n';
            
            if (!uniqueErrors.isEmpty()) {
                emailBody += '\nErrors Encountered:\n';
                emailBody += String.join(new List<String>(uniqueErrors), '\n');
            }
            
            mail.setPlainTextBody(emailBody);
        }
        
        // Send email
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
        
        if (!uniqueErrors.isEmpty()) {
            String allErrors = String.join(new List<String>(uniqueErrors), '\n');
            throw new FEC_BatchException(FEC_Constants.ERROR_SYNC_FAILED_PREFIX + allErrors);
        }
    }
}