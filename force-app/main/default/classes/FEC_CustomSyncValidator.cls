public class FEC_CustomSyncValidator {

    public static void validate(List<CustomSync__c> records) {
        // 1. Check CustomSyncSetting__c
        CustomSyncSetting__c setting = CustomSyncSetting__c.getOrgDefaults();
        Boolean settingMissing = setting == null 
            || String.isBlank(setting.Endpoint__c) 
            || String.isBlank(setting.ApiKey__c)
            || setting.LimitQuanitySync__c == null;

        // 2. Check FEC_API_Config__mdt
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Custom_Sync_Bix');
        Boolean metadataMissing = apiConfig == null || String.isBlank(apiConfig.FEC_Endpoint__c);

        for (CustomSync__c rec : records) {
            if (settingMissing) {
                rec.addError('CustomSyncSetting is incomplete. Please ensure Endpoint, ApiKey, and LimitQuanitySync are configured.');
            }
            if (metadataMissing) {
                rec.addError('Custom Metadata FEC_API_Config "FEC_Custom_Sync_Bix" is missing or has no Endpoint.');
            }

            // 3. Compare keys between RequestBodyMapping__c and MappingDataType__c
            if (String.isNotBlank(rec.RequestBodyMapping__c) && String.isNotBlank(rec.MappingDataType__c)) {
                try {
                    Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(rec.RequestBodyMapping__c);
                    Map<String, Object> typeMap = (Map<String, Object>) JSON.deserializeUntyped(rec.MappingDataType__c);

                    Set<String> bodyKeys = bodyMap.keySet();
                    Set<String> typeKeys = typeMap.keySet();

                    // Keys in RequestBodyMapping but missing in MappingDataType
                    Set<String> missingInType = new Set<String>(bodyKeys);
                    missingInType.removeAll(typeKeys);

                    // Keys in MappingDataType but missing in RequestBodyMapping
                    Set<String> missingInBody = new Set<String>(typeKeys);
                    missingInBody.removeAll(bodyKeys);

                    if (!missingInType.isEmpty()) {
                        rec.addError('MappingDataType is missing keys: ' + String.join(new List<String>(missingInType), ', '));
                    }
                    if (!missingInBody.isEmpty()) {
                        rec.addError('RequestBodyMapping is missing keys: ' + String.join(new List<String>(missingInBody), ', '));
                    }
                } catch (Exception e) {
                    rec.addError('Invalid JSON format: ' + e.getMessage());
                }
            }
        }
    }
}