public class FEC_CustomSyncValidator {

    public static void validate(List<FEC_Custom_Sync__c> records) {
        // Collect CaseBusinessCodes to validate against FEC_Business_Process__c
        Set<String> caseBusinessCodes = new Set<String>();
        Set<String> targetObjects = new Set<String>();
        Map<String, Set<String>> fieldsByTargetObject = new Map<String, Set<String>>();

        for (FEC_Custom_Sync__c rec : records) {
            if (String.isNotBlank(rec.FEC_Case_Business_Code__c)) {
                caseBusinessCodes.add(rec.FEC_Case_Business_Code__c);
            }
            // Collect target objects and their RequestBodyMapping values for field validation
            if (String.isNotBlank(rec.FEC_Target_Object__c) && String.isNotBlank(rec.FEC_Request_Body_Mapping__c)) {
                targetObjects.add(rec.FEC_Target_Object__c);
                try {
                    Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(rec.FEC_Request_Body_Mapping__c);
                    if (!fieldsByTargetObject.containsKey(rec.FEC_Target_Object__c)) {
                        fieldsByTargetObject.put(rec.FEC_Target_Object__c, new Set<String>());
                    }
                    for (Object val : bodyMap.values()) {
                        if (val != null && val instanceof String) {
                            fieldsByTargetObject.get(rec.FEC_Target_Object__c).add((String) val);
                        }
                    }
                } catch (Exception e) {
                    // Will be caught in per-record validation
                }
            }
        }

        // Query valid FEC_Business_Process__c codes
        Set<String> validCodes = new Set<String>();
        if (!caseBusinessCodes.isEmpty()) {
            for (FEC_Business_Process__c bp : [
                SELECT Id, FEC_Code__c FROM FEC_Business_Process__c WHERE FEC_Code__c IN :caseBusinessCodes
            ]) {
                validCodes.add(bp.FEC_Code__c);
            }
        }

        // Rule 4: Validate fields by building a dynamic SOQL query per TargetObject
        // This approach supports relationship fields (e.g. Owner.Name, Account.Name)
        Map<String, String> queryErrorByObject = new Map<String, String>();
        if (!targetObjects.isEmpty()) {
            for (String objName : targetObjects) {
                Set<String> fields = fieldsByTargetObject.get(objName);
                if (fields == null || fields.isEmpty()) continue;

                // Build SELECT field list (only non-null values)
                List<String> fieldList = new List<String>(fields);
                String soql = 'SELECT ' + String.join(fieldList, ', ') + ' FROM ' + objName + ' LIMIT 0';
                try {
                    Database.query(soql);
                } catch (QueryException e) {
                    queryErrorByObject.put(objName, e.getMessage());
                }
            }
        }

        // Per-record validation
        for (FEC_Custom_Sync__c rec : records) {
            // Rule 1: CaseBusinessCode != null => TargetObject must be 'Case'
            if (String.isNotBlank(rec.FEC_Case_Business_Code__c) 
                && rec.FEC_Target_Object__c != 'Case' && rec.FEC_Target_Object__c != 'case') {
                rec.addError('CaseBusinessCode is only applicable when Target Object is "Case".');
            }

            // Rule 2: ProcessingQuantity must be > 0
            if (rec.FEC_Processing_Quantity__c == null || rec.FEC_Processing_Quantity__c <= 0) {
                rec.addError('ProcessingQuantity must be greater than 0.');
            }

            // Rule 3: Compare keys between RequestBodyMapping and MappingDataType
            if (String.isNotBlank(rec.FEC_Request_Body_Mapping__c) && String.isNotBlank(rec.FEC_Mapping_Data_Type__c)) {
                try {
                    Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(rec.FEC_Request_Body_Mapping__c);
                    Map<String, Object> typeMap = (Map<String, Object>) JSON.deserializeUntyped(rec.FEC_Mapping_Data_Type__c);

                    Set<String> bodyKeys = bodyMap.keySet();
                    Set<String> typeKeys = typeMap.keySet();

                    // Keys in MappingDataType but missing in RequestBodyMapping (dư)
                    Set<String> extraInType = new Set<String>(typeKeys);
                    extraInType.removeAll(bodyKeys);

                    // Keys in RequestBodyMapping but missing in MappingDataType (thiếu)
                    Set<String> missingInType = new Set<String>(bodyKeys);
                    missingInType.removeAll(typeKeys);

                    if (!extraInType.isEmpty()) {
                        rec.addError('MappingDataType has extra keys not in RequestBodyMapping: ' + String.join(new List<String>(extraInType), ', '));
                    }
                    if (!missingInType.isEmpty()) {
                        rec.addError('MappingDataType is missing keys from RequestBodyMapping: ' + String.join(new List<String>(missingInType), ', '));
                    }
                } catch (Exception e) {
                    rec.addError('Invalid JSON format in RequestBodyMapping or MappingDataType: ' + e.getMessage());
                }
            }

            // Rule 4: Check if dynamic SOQL query failed for this record's TargetObject
            if (String.isNotBlank(rec.FEC_Target_Object__c) && queryErrorByObject.containsKey(rec.FEC_Target_Object__c)) {
                rec.addError('Invalid fields in RequestBodyMapping for object "' + rec.FEC_Target_Object__c + '": ' + queryErrorByObject.get(rec.FEC_Target_Object__c));
            }

            // Rule 5: CaseBusinessCode must exist in FEC_Business_Process__c
            if (String.isNotBlank(rec.FEC_Case_Business_Code__c) && !validCodes.contains(rec.FEC_Case_Business_Code__c)) {
                rec.addError('Case Business Code "' + rec.FEC_Case_Business_Code__c + '" does not exist in FEC_Business_Process__c.');
            }
        }
    }
}
