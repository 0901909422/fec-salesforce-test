/**
 * FEC_BatchUtils
 * Shared helpers extracted from batch classes to avoid duplication.
 */
public with sharing class FEC_BatchUtils {

    public static void setLookup(SObject target, SObject mdm, String relName, String parentObjName, Set<String> uniqueErrors) {
        try {
            SObject parentMDM = mdm.getSObject(relName);
            if (parentMDM != null) {
                String extId = (String)parentMDM.get(FEC_Constants.FIELD_EXTERNAL_ID);
                if (String.isNotBlank(extId)) {
                    SObject parentLive = Schema.getGlobalDescribe().get(parentObjName).newSObject();
                    parentLive.put(FEC_Constants.FIELD_EXTERNAL_ID, extId);
                    target.putSObject(relName, parentLive);
                }
            }
        } catch(Exception e) {
            if (uniqueErrors != null) uniqueErrors.add(FEC_Constants.ERROR_LOOKUP_PREFIX + relName + ': ' + e.getMessage());
        }
    }

    public static void copyCommonFields(SObject target, SObject mdm, Map<String, String> commonFieldMap, Set<String> uniqueErrors) {
        for (String f : commonFieldMap.keySet()) {
            try {
                target.put(commonFieldMap.get(f), mdm.get(f));
            } catch(Exception ex) {
                if (uniqueErrors != null) uniqueErrors.add(FEC_Constants.ERROR_COMMON_FIELD_PREFIX + f + ': ' + ex.getMessage());
            }
        }
    }

    public static void copyValidFields(SObject target, SObject mdm, List<String> validFields, Map<String, Schema.SObjectField> fieldMap, Map<String, String> commonFieldMap, Set<String> uniqueErrors) {
        for (String mdmField : validFields) {
            String targetField = commonFieldMap.get(mdmField);
            if (fieldMap.containsKey(targetField)) {
                if (fieldMap.get(targetField).getDescribe().isUpdateable()) {
                    try {
                        target.put(targetField, mdm.get(mdmField));
                    } catch(Exception ex) {
                        if (uniqueErrors != null) uniqueErrors.add(FEC_Constants.ERROR_DATA_PREFIX + mdmField + ' - ' + ex.getMessage());
                    }
                }
            }
        }
    }

    public static void copyFieldsToMDM(SObject mdm, SObject live, Map<String, Schema.SObjectField> mdmFields, Map<String, String> commonFieldMap) {
        for (String mdmF : commonFieldMap.keySet()) {
            String liveF = commonFieldMap.get(mdmF);
            if (mdmFields.containsKey(mdmF) && mdmFields.get(mdmF).getDescribe().isUpdateable()) {
                try {
                    mdm.put(mdmF, live.get(liveF));
                } catch(Exception e) {
                    // swallow but could be logged if needed
                }
            }
        }
    }

    public static void revertLookup(SObject mdm, SObject live, String relName, String parentMdmObjName, Set<String> uniqueErrors) {
        try {
            SObject parentLive = live.getSObject(relName);
            if (parentLive != null) {
                String extId = (String)parentLive.get(FEC_Constants.FIELD_EXTERNAL_ID);
                if (String.isNotBlank(extId)) {
                    SObject parentMdmRef = Schema.getGlobalDescribe().get(parentMdmObjName).newSObject();
                    parentMdmRef.put(FEC_Constants.FIELD_EXTERNAL_ID, extId);
                    mdm.putSObject(relName, parentMdmRef);
                }
            }
        } catch(Exception e) {
            if (uniqueErrors != null) uniqueErrors.add('RevertLookup ' + relName + ': ' + e.getMessage());
        }
    }
}
