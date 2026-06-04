public with sharing class FEC_SyncMasterDataBatch implements Database.Batchable<String>, Database.Stateful {
    
    public Iterable<String> start(Database.BatchableContext bc) {
        // In test context, return only 1 element (xem ghi chú ở FEC_PushMDMToLiveBatch.start)
        if (Test.isRunningTest()) {
            return new List<String>{ FEC_MDMBatchConfig.EXECUTION_ORDER[0] };
        }
        return FEC_MDMBatchConfig.EXECUTION_ORDER;
    }
    
    public void execute(Database.BatchableContext bc, List<String> scope) {
        String mdmObjName = scope[0];
        String targetObjName = FEC_MDMBatchConfig.MDM_TO_LIVE_MAP.get(mdmObjName);
        
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(mdmObjName) || !gd.containsKey(targetObjName)) return;
        
        try {
            // STEP 0: Populate FEC_Code__c from Name/Id if it's null on Source object
            populateMissingCodes(targetObjName);
            
            // Build filtered field map - only fields that exist on both objects
            Map<String, Schema.SObjectField> targetFields = gd.get(targetObjName).getDescribe().fields.getMap();
            Map<String, Schema.SObjectField> mdmFieldsMap = gd.get(mdmObjName).getDescribe().fields.getMap();

            // Ensure FEC_Code__c is populated on existing MDM records if they came from Name
            if (mdmFieldsMap.containsKey(FEC_MDMBatchConfig.FIELD_CODE)) {
                List<SObject> emptyMdmCodes = Database.query('SELECT Id, Name FROM ' + mdmObjName + ' WHERE ' + FEC_MDMBatchConfig.FIELD_CODE + ' = null');
                if (!emptyMdmCodes.isEmpty()) {
                    for(SObject m : emptyMdmCodes) m.put(FEC_MDMBatchConfig.FIELD_CODE, m.get('Id'));
                    update emptyMdmCodes;
                }
            }
            
            Set<String> validQueryFields = new Set<String>();
            validQueryFields.add('Id');
            if (targetFields.containsKey(FEC_MDMBatchConfig.FIELD_CODE)) {
                validQueryFields.add(FEC_MDMBatchConfig.FIELD_CODE);
            }
            
            // Build filtered field map - only fields that exist on both objects
            Map<String, String> filteredFieldMap = new Map<String, String>();
            for (String liveField : FEC_MDMBatchConfig.COMMON_FIELD_MAP.keySet()) {
                String mdmField = FEC_MDMBatchConfig.COMMON_FIELD_MAP.get(liveField);
                if (targetFields.containsKey(liveField) && mdmFieldsMap.containsKey(mdmField)) {
                    validQueryFields.add(liveField);
                    filteredFieldMap.put(liveField, mdmField);
                }
            }
            
            // Also query source lookup fields so we can remap them
            if (FEC_MDMBatchConfig.OBJECTS_WITH_LOOKUP_REMAPPING.contains(mdmObjName)) {
                List<String> objLookupFields = FEC_MDMBatchConfig.OBJECT_LOOKUP_FIELDS.get(mdmObjName);
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
                String codeValue = (String)source.get(FEC_MDMBatchConfig.FIELD_CODE);
                if (String.isNotBlank(codeValue)) sourceCodes.add(codeValue);
            }
            
            // STEP 3: Query MDM records
            List<SObject> existingMdmRecords = Database.query('SELECT Id, ' + FEC_MDMBatchConfig.FIELD_CODE + ' FROM ' + mdmObjName);
            Map<String, Id> mdmCodeToIdMap = new Map<String, Id>();
            for (SObject mdmRecord : existingMdmRecords) {
                String mdmCode = (String)mdmRecord.get(FEC_MDMBatchConfig.FIELD_CODE);
                if (String.isNotBlank(mdmCode)) mdmCodeToIdMap.put(mdmCode, mdmRecord.Id);
            }
            
            // STEP 3b: Build lookup remap maps
            Map<String, Map<Id, Id>> lookupRemapMaps = new Map<String, Map<Id, Id>>();
            if (FEC_MDMBatchConfig.OBJECTS_WITH_LOOKUP_REMAPPING.contains(mdmObjName)) {
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
                String codeValue = (String)source.get(FEC_MDMBatchConfig.FIELD_CODE);
                if (String.isNotBlank(codeValue)) {
                    target.put(FEC_MDMBatchConfig.FIELD_CODE, codeValue);
                }
                List<String> thisObjLookupFields = FEC_MDMBatchConfig.OBJECT_LOOKUP_FIELDS.containsKey(mdmObjName)
                    ? FEC_MDMBatchConfig.OBJECT_LOOKUP_FIELDS.get(mdmObjName)
                    : new List<String>();
                Boolean skipName = FEC_MDMBatchConfig.OBJECTS_WITH_AUTONUMBER_NAME.contains(mdmObjName);
                for (String liveField : filteredFieldMap.keySet()) {
                    if (thisObjLookupFields.contains(liveField)) continue;
                    if (skipName && liveField == FEC_MDMBatchConfig.FIELD_NAME) continue;
                    String mdmField = filteredFieldMap.get(liveField);
                    if (source.get(liveField) != null) {
                        // Handle type mismatch: Boolean (Live) → Picklist/String (MDM)
                        Object sourceValue = source.get(liveField);
                        Schema.DescribeFieldResult mdmFieldDescribe = gd.get(mdmObjName).getDescribe().fields.getMap()
                            .get(mdmField.toLowerCase())?.getDescribe();
                        Schema.DisplayType mdmFieldType = mdmFieldDescribe?.getType();
                        if (sourceValue instanceof Boolean && mdmFieldType != Schema.DisplayType.Boolean) {
                            // For restricted picklists, skip Boolean→String mapping (incompatible values)
                            if (mdmFieldDescribe != null && mdmFieldDescribe.isRestrictedPicklist()) {
                                continue; // Skip this field entirely — cannot map true/false to picklist values
                            }
                            target.put(mdmField, String.valueOf(sourceValue));
                        } else {
                            target.put(mdmField, sourceValue);
                        }
                    }
                }
                if (FEC_MDMBatchConfig.OBJECTS_WITH_LOOKUP_REMAPPING.contains(mdmObjName)) {
                    remapLookupFields(source, target, targetFields, mdmFieldsMap, lookupRemapMaps, mdmObjName);
                }
                if (FEC_MDMBatchConfig.OBJECTS_WITH_TEXT_ID_REMAPPING.contains(mdmObjName)) {
                    remapTextIdFieldsLiveToMdm(source, target, mdmObjName, textIdRemapMaps);
                }
                targetRecords.add(target);
            }
            
            // STEP 6: UPSERT records to MDM
            if (!targetRecords.isEmpty()) {
                Schema.SObjectField externalIdField = mdmFieldsMap.get(FEC_MDMBatchConfig.FIELD_CODE);
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
                        record.put(FEC_MDMBatchConfig.FIELD_PROCESS_CHANGE_STATUS, FEC_MDMBatchConfig.PROCESS_STATUS_SYNCED);
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
            if (!fieldsMap.containsKey(FEC_MDMBatchConfig.FIELD_CODE)) return;

            List<SObject> recordsToUpdate = Database.query(
                'SELECT Id, ' + FEC_MDMBatchConfig.FIELD_CODE + ' FROM ' + objectName + ' WHERE ' + FEC_MDMBatchConfig.FIELD_CODE + ' = null'
                );
            if (recordsToUpdate.isEmpty()) return;
            for (SObject record : recordsToUpdate) {
                String Id = (String) record.get('Id');
                String code = Id;
                record.put(FEC_MDMBatchConfig.FIELD_CODE, code);
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
        
        List<String> objectLookupFields = FEC_MDMBatchConfig.OBJECT_LOOKUP_FIELDS.get(mdmObjName);
        if (objectLookupFields == null || objectLookupFields.isEmpty()) return;
        
        for (String srcLookupField : objectLookupFields) {
            if (!targetFields.containsKey(srcLookupField)) {
                lookupRemapMaps.put(srcLookupField, new Map<Id, Id>());
                continue;
            }
            String mdmLookupObj = FEC_MDMBatchConfig.LOOKUP_FIELD_MDM_MAP.get(srcLookupField).get(FEC_MDMBatchConfig.MDM_OBJ_KEY);
            if (!gd.containsKey(mdmLookupObj)) {
                lookupRemapMaps.put(srcLookupField, new Map<Id, Id>());
                continue;
            }
            String srcObjName = FEC_MDMBatchConfig.MDM_TO_LIVE_MAP.containsKey(mdmLookupObj)
                ? FEC_MDMBatchConfig.MDM_TO_LIVE_MAP.get(mdmLookupObj)
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
                        'SELECT Id, ' + FEC_MDMBatchConfig.FIELD_CODE + ' FROM ' + srcObjName + ' WHERE Id IN :usedSourceIds'
                    )) {
                        String code = (String)srcLookupRecord.get(FEC_MDMBatchConfig.FIELD_CODE);
                        if (String.isNotBlank(code)) srcIdToCode.put(srcLookupRecord.Id, code);
                    }
                    Map<String, Id> mdmCodeToId = new Map<String, Id>();
                    for (SObject mdmLookupRecord : Database.query(
                        'SELECT Id, ' + FEC_MDMBatchConfig.FIELD_CODE + ' FROM ' + mdmLookupObj
                    )) {
                        String code = (String)mdmLookupRecord.get(FEC_MDMBatchConfig.FIELD_CODE);
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
        
        List<String> objectLookupFields = FEC_MDMBatchConfig.OBJECT_LOOKUP_FIELDS.get(mdmObjName);
        if (objectLookupFields == null || objectLookupFields.isEmpty()) return;
        for (String srcLookupField : objectLookupFields) {
            if (!targetFields.containsKey(srcLookupField)) continue;
            String mdmLookupField = FEC_MDMBatchConfig.LOOKUP_FIELD_MDM_MAP.get(srcLookupField).get(FEC_MDMBatchConfig.MDM_FIELD_KEY);
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