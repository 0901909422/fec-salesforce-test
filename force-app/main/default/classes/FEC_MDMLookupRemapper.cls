/**
 * @description Utility class for remapping lookup fields and text-typed Id fields
 *              from MDM staging records to Live target records, by matching FEC_Code__c.
 *              Extracted from FEC_PushMDMToLiveBatch as part of MDM Refactor Phase 2.5.
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.5
 */
public with sharing class FEC_MDMLookupRemapper {

    /**
     * Build a map: srcLookupField → (mdmId → liveId) for all standard lookup fields
     * on this object, by matching FEC_Code__c between MDM and Live.
     */
    public static Map<String, Map<Id, Id>> buildLookupRemapMaps(
        String mdmObjName,
        List<SObject> mdmRecords,
        Map<String, Schema.SObjectField> targetFields,
        Map<String, Schema.SObjectType> gd
    ) {
        Map<String, Map<Id, Id>> lookupRemapMaps = new Map<String, Map<Id, Id>>();
        List<String> objectLookupFields = FEC_MDMBatchConfig.OBJECT_LOOKUP_FIELDS.get(mdmObjName);
        if (objectLookupFields == null || objectLookupFields.isEmpty()) return lookupRemapMaps;

        for (String srcLookupField : objectLookupFields) {
            if (!targetFields.containsKey(srcLookupField)) {
                lookupRemapMaps.put(srcLookupField, new Map<Id, Id>());
                continue;
            }
            Map<String, String> mdmRefMap = FEC_MDMBatchConfig.LOOKUP_FIELD_MDM_MAP.get(srcLookupField);
            String mdmLookupObj = mdmRefMap.get(FEC_MDMBatchConfig.MDM_OBJ_KEY);
            String mdmLookupField = mdmRefMap.get(FEC_MDMBatchConfig.MDM_FIELD_KEY);

            if (!gd.containsKey(mdmLookupObj)) {
                lookupRemapMaps.put(srcLookupField, new Map<Id, Id>());
                continue;
            }
            String srcObjName = FEC_MDMBatchConfig.MDM_TO_LIVE_MAP.get(mdmLookupObj);

            Map<Id, Id> mdmToSrcIdMap = buildSingleLookupMap(
                mdmRecords, mdmLookupField, mdmLookupObj, srcObjName, gd
            );
            lookupRemapMaps.put(srcLookupField, mdmToSrcIdMap);
        }
        return lookupRemapMaps;
    }

    /**
     * Apply lookup field remapping: read MDM lookup Id from source record,
     * look up corresponding Live Id from remap map, write to target record.
     */
    public static void remapLookupFields(
        SObject mdm,
        SObject target,
        Map<String, Map<Id, Id>> lookupRemapMaps,
        String mdmObjName
    ) {
        List<String> objectLookupFields = FEC_MDMBatchConfig.OBJECT_LOOKUP_FIELDS.get(mdmObjName);
        if (objectLookupFields == null || objectLookupFields.isEmpty()) return;

        for (String srcLookupField : objectLookupFields) {
            String mdmLookupField = FEC_MDMBatchConfig.LOOKUP_FIELD_MDM_MAP
                .get(srcLookupField)
                .get(FEC_MDMBatchConfig.MDM_FIELD_KEY);
            Id mdmId = (Id) mdm.get(mdmLookupField);
            if (mdmId == null) continue;

            Map<Id, Id> remapMap = lookupRemapMaps.get(srcLookupField);
            if (remapMap != null && remapMap.containsKey(mdmId)) {
                target.put(srcLookupField, remapMap.get(mdmId));
            }
        }
    }

    /**
     * Build a map: textFieldName → (mdmRefId → liveRefId) for all text-typed
     * Id fields on this object, by matching FEC_Code__c between MDM and Live.
     */
    public static Map<String, Map<Id, Id>> buildTextIdRemapMaps(
        String mdmObjName,
        List<SObject> mdmRecords,
        Map<String, Schema.SObjectType> gd
    ) {
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
            Set<Id> referencedIds = collectReferencedTextIds(mdmRecords, fieldName);
            if (referencedIds.isEmpty()) {
                result.put(fieldName, new Map<Id, Id>());
                continue;
            }
            Map<Id, Id> idMap = buildIdToLiveIdMap(mdmRefObj, liveRefObj, referencedIds);
            result.put(fieldName, idMap);
        }
        return result;
    }

    /**
     * Apply text-typed Id field remapping: read MDM Id stored as String,
     * look up corresponding Live Id, write back as String.
     */
    public static void remapTextIdFields(
        SObject mdm,
        SObject target,
        String mdmObjName,
        Map<String, Map<Id, Id>> textIdRemapMaps
    ) {
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

    // ════════════════════════════════════════════════════════
    // PRIVATE HELPERS
    // ════════════════════════════════════════════════════════

    /**
     * Build single lookup map: mdmId → liveId by matching FEC_Code__c.
     */
    private static Map<Id, Id> buildSingleLookupMap(
        List<SObject> mdmRecords,
        String mdmLookupField,
        String mdmLookupObj,
        String srcObjName,
        Map<String, Schema.SObjectType> gd
    ) {
        Map<Id, Id> mdmToSrcIdMap = new Map<Id, Id>();
        if (srcObjName == null || !gd.containsKey(srcObjName)) return mdmToSrcIdMap;

        Set<Id> usedMdmIds = collectLookupIds(mdmRecords, mdmLookupField);
        if (usedMdmIds.isEmpty()) return mdmToSrcIdMap;

        Map<Id, String> mdmIdToCode = queryIdToCode(mdmLookupObj, usedMdmIds);
        Map<String, Id> srcCodeToId = queryCodeToId(srcObjName);

        for (Id mdmId : mdmIdToCode.keySet()) {
            String code = mdmIdToCode.get(mdmId);
            if (srcCodeToId.containsKey(code)) {
                mdmToSrcIdMap.put(mdmId, srcCodeToId.get(code));
            }
        }
        return mdmToSrcIdMap;
    }

    private static Set<Id> collectLookupIds(List<SObject> mdmRecords, String mdmLookupField) {
        Set<Id> ids = new Set<Id>();
        for (SObject mdm : mdmRecords) {
            Id lookupId = (Id) mdm.get(mdmLookupField);
            if (lookupId != null) ids.add(lookupId);
        }
        return ids;
    }

    private static Set<Id> collectReferencedTextIds(List<SObject> mdmRecords, String fieldName) {
        Set<Id> ids = new Set<Id>();
        for (SObject m : mdmRecords) {
            String raw = (String) m.get(fieldName);
            if (String.isBlank(raw)) continue;
            try {
                ids.add((Id) raw);
            } catch (Exception ignored) {
                // skip invalid Id
            }
        }
        return ids;
    }

    private static Map<Id, String> queryIdToCode(String objName, Set<Id> ids) {
        Map<Id, String> codeMap = new Map<Id, String>();
        String soql = 'SELECT Id, ' + FEC_MDMBatchConfig.FIELD_CODE
                    + ' FROM ' + objName + ' WHERE Id IN :ids';
        for (SObject rec : Database.query(soql)) {
            String code = (String) rec.get(FEC_MDMBatchConfig.FIELD_CODE);
            if (String.isNotBlank(code)) codeMap.put(rec.Id, code);
        }
        return codeMap;
    }

    private static Map<String, Id> queryCodeToId(String objName) {
        Map<String, Id> codeMap = new Map<String, Id>();
        String soql = 'SELECT Id, ' + FEC_MDMBatchConfig.FIELD_CODE + ' FROM ' + objName;
        for (SObject rec : Database.query(soql)) {
            String code = (String) rec.get(FEC_MDMBatchConfig.FIELD_CODE);
            if (String.isNotBlank(code)) codeMap.put(code, rec.Id);
        }
        return codeMap;
    }

    private static Map<Id, Id> buildIdToLiveIdMap(
        String mdmRefObj,
        String liveRefObj,
        Set<Id> referencedIds
    ) {
        Map<Id, String> mdmIdToCode = queryIdToCode(mdmRefObj, referencedIds);
        Map<String, Id> codeToLiveId = queryCodeToId(liveRefObj);

        Map<Id, Id> idMap = new Map<Id, Id>();
        for (Id mdmId : mdmIdToCode.keySet()) {
            Id liveId = codeToLiveId.get(mdmIdToCode.get(mdmId));
            if (liveId != null) idMap.put(mdmId, liveId);
        }
        return idMap;
    }
}