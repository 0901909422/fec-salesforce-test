/**
 * Resolves Excel picklist text (Vietnamese label or English API) to Case picklist API values.
 * Uses Visualforce page locale rendering for Vietnamese when running in a synchronous context.
 */
public with sharing class FEC_BatchCaseHandlingPicklistResolver {

    private static final String OBJECT_API_CASE = 'Case';
    private static final String LOCALE_VI = 'vi';
    private static final String LOCALE_EN = 'en_US';

    private static Map<String, Map<String, String>> normalizedToApiByFieldCache =
        new Map<String, Map<String, String>>();

    public static Map<String, Map<String, String>> buildNormalizedToApiValueByField(
        List<String> caseFieldApis
    ) {
        Map<String, Map<String, String>> out = new Map<String, Map<String, String>>();
        if (caseFieldApis == null || caseFieldApis.isEmpty()) {
            return out;
        }
        for (String fieldApi : caseFieldApis) {
            if (String.isBlank(fieldApi)) {
                continue;
            }
            out.put(fieldApi, getNormalizedToApiValueMap(fieldApi));
        }
        return out;
    }

    public static String resolveApiValue(
        String caseFieldApi,
        String userInput,
        Map<String, Map<String, String>> normalizedToApiByField
    ) {
        if (String.isBlank(caseFieldApi) || String.isBlank(userInput) || normalizedToApiByField == null) {
            return null;
        }
        Map<String, String> lookup = normalizedToApiByField.get(caseFieldApi);
        if (lookup == null || lookup.isEmpty()) {
            lookup = getNormalizedToApiValueMap(caseFieldApi);
        }
        if (lookup == null || lookup.isEmpty()) {
            return null;
        }
        String direct = lookup.get(normalizeToken(userInput));
        if (String.isNotBlank(direct)) {
            return direct;
        }
        return lookup.get(normalizeTokenAccentInsensitive(userInput));
    }

    public static Map<String, String> getNormalizedToApiValueMap(String caseFieldApi) {
        if (String.isBlank(caseFieldApi)) {
            return new Map<String, String>();
        }
        if (normalizedToApiByFieldCache.containsKey(caseFieldApi)) {
            return normalizedToApiByFieldCache.get(caseFieldApi);
        }
        Map<String, String> normalizedToApi = new Map<String, String>();
        registerDescribePicklistEntries(caseFieldApi, normalizedToApi);
        if (canLoadVisualforceLocalePicklists()) {
            mergeLocalePicklistEntries(caseFieldApi, LOCALE_VI, normalizedToApi);
            mergeLocalePicklistEntries(caseFieldApi, LOCALE_EN, normalizedToApi);
        }
        normalizedToApiByFieldCache.put(caseFieldApi, normalizedToApi);
        return normalizedToApi;
    }

    public static void clearCache() {
        normalizedToApiByFieldCache.clear();
    }

    private static void registerDescribePicklistEntries(
        String caseFieldApi,
        Map<String, String> normalizedToApi
    ) {
        Map<String, Schema.SObjectField> fieldMap = Case.SObjectType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(caseFieldApi)) {
            return;
        }
        Schema.DescribeFieldResult dfr = fieldMap.get(caseFieldApi).getDescribe();
        if (dfr.getType() != Schema.DisplayType.PICKLIST && dfr.getType() != Schema.DisplayType.MULTIPICKLIST) {
            return;
        }
        for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
            if (entry == null || !entry.isActive()) {
                continue;
            }
            registerPicklistEntry(normalizedToApi, entry.getValue(), entry.getLabel());
        }
    }

    private static void mergeLocalePicklistEntries(
        String caseFieldApi,
        String localeKey,
        Map<String, String> normalizedToApi
    ) {
        Map<String, String> labelToApi = loadLabelToApiViaVisualforce(caseFieldApi, localeKey);
        if (labelToApi == null || labelToApi.isEmpty()) {
            return;
        }
        for (String label : labelToApi.keySet()) {
            registerPicklistEntry(normalizedToApi, labelToApi.get(label), label);
        }
    }

    private static Map<String, String> loadLabelToApiViaVisualforce(String caseFieldApi, String localeKey) {
        if (String.isBlank(caseFieldApi) || String.isBlank(localeKey)) {
            return new Map<String, String>();
        }
        try {
            PageReference pageRef = Page.FEC_BCH_PicklistTranslation;
            pageRef.getParameters().put('lang', localeKey);
            pageRef.getParameters().put('objectName', OBJECT_API_CASE);
            pageRef.getParameters().put('fieldName', caseFieldApi);
            String body = pageRef.getContent().toString();
            if (String.isBlank(body)) {
                return new Map<String, String>();
            }
            return (Map<String, String>) JSON.deserialize(body, Map<String, String>.class);
        } catch (Exception ex) {
            return new Map<String, String>();
        }
    }

    private static void registerPicklistEntry(
        Map<String, String> normalizedToApi,
        String apiValue,
        String label
    ) {
        if (normalizedToApi == null || String.isBlank(apiValue)) {
            return;
        }
        putNormalizedKey(normalizedToApi, apiValue, apiValue);
        if (String.isNotBlank(label)) {
            putNormalizedKey(normalizedToApi, label, apiValue);
        }
    }

    private static void putNormalizedKey(
        Map<String, String> normalizedToApi,
        String inputKey,
        String apiValue
    ) {
        if (String.isBlank(inputKey)) {
            return;
        }
        normalizedToApi.put(normalizeToken(inputKey), apiValue);
        String accentKey = normalizeTokenAccentInsensitive(inputKey);
        if (String.isNotBlank(accentKey) && !normalizedToApi.containsKey(accentKey)) {
            normalizedToApi.put(accentKey, apiValue);
        }
    }

    private static Boolean canLoadVisualforceLocalePicklists() {
        return !System.isBatch() && !System.isQueueable() && !Test.isRunningTest();
    }

    public static String normalizeToken(String value) {
        if (String.isBlank(value)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return value.trim().toLowerCase().replaceAll('\\s+', FEC_ConstantCommon.STR_EMPTY);
    }

    public static String normalizeTokenAccentInsensitive(String value) {
        if (String.isBlank(value)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String upperNoAccent = FEC_CommonUltils.toUpperNoVietnameseAccent(value.trim());
        return upperNoAccent == null
            ? FEC_ConstantCommon.STR_EMPTY
            : upperNoAccent.toLowerCase().replaceAll('\\s+', FEC_ConstantCommon.STR_EMPTY);
    }
}