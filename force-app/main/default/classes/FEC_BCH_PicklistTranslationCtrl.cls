/**
 * Visualforce controller: picklist label -> API value for a given page language (lang parameter).
 */
public with sharing class FEC_BCH_PicklistTranslationCtrl {
    public String jsonPayload { get; private set; }

    public FEC_BCH_PicklistTranslationCtrl() {
        String objectName = ApexPages.currentPage().getParameters().get('objectName');
        String fieldName = ApexPages.currentPage().getParameters().get('fieldName');
        jsonPayload = JSON.serialize(buildLabelToValueMap(objectName, fieldName));
    }

    private static Map<String, String> buildLabelToValueMap(String objectName, String fieldName) {
        Map<String, String> out = new Map<String, String>();
        if (String.isBlank(objectName) || String.isBlank(fieldName)) {
            return out;
        }
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
        if (sObjectType == null) {
            return out;
        }
        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
        String fieldKey = fieldName.toLowerCase();
        if (!fieldMap.containsKey(fieldKey)) {
            return out;
        }
        Schema.DescribeFieldResult dfr = fieldMap.get(fieldKey).getDescribe();
        if (dfr.getType() != Schema.DisplayType.PICKLIST && dfr.getType() != Schema.DisplayType.MULTIPICKLIST) {
            return out;
        }
        for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
            if (entry == null || !entry.isActive()) {
                continue;
            }
            String apiValue = entry.getValue();
            if (String.isBlank(apiValue)) {
                continue;
            }
            String label = entry.getLabel();
            if (String.isNotBlank(label)) {
                out.put(label, apiValue);
            }
            out.put(apiValue, apiValue);
        }
        return out;
    }
}