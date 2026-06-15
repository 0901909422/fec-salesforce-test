public class FEC_CustomSyncValidator {

    public static void validate(List<FEC_Custom_Sync__c> records, Map<Id, FEC_Custom_Sync__c> oldMap) {
        // Filter records that need validation:
        // Only validate when Active is being set to true:
        // - Insert with Active = true
        // - Update: Active changed from false to true, OR Active is already true
        List<FEC_Custom_Sync__c> recordsToValidate = new List<FEC_Custom_Sync__c>();
        for (FEC_Custom_Sync__c rec : records) {
            Boolean isActive = rec.FEC_Active__c == true;

            if (oldMap == null) {
                // Insert: only validate if Active = true
                if (isActive) {
                    recordsToValidate.add(rec);
                }
            } else {
                // Update: validate if Active is true (either already true or changing to true)
                Boolean wasActive = oldMap.containsKey(rec.Id) && oldMap.get(rec.Id).FEC_Active__c == true;
                Boolean activating = isActive && !wasActive;
                if (isActive || activating) {
                    recordsToValidate.add(rec);
                }
            }
        }

        if (recordsToValidate.isEmpty()) {
            return;
        }

        // Collect CaseBusinessCodes to validate against FEC_Business_Process__c
        Set<String> caseBusinessCodes = new Set<String>();
        Set<String> targetObjects = new Set<String>();
        Map<String, Set<String>> fieldsByTargetObject = new Map<String, Set<String>>();

        for (FEC_Custom_Sync__c rec : recordsToValidate) {
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
                        if (val != null && val instanceof String && (String) val != 'DateTimeNow') {
                            String strVal = (String) val;
                            // Skip static map keys (suffix __g) — they are not SF fields
                            if (!strVal.endsWith('__g')) {
                                fieldsByTargetObject.get(rec.FEC_Target_Object__c).add(strVal);
                            }
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
        Map<String, String> queryErrorByObject = new Map<String, String>();
        if (!targetObjects.isEmpty()) {
            for (String objName : targetObjects) {
                Set<String> fields = fieldsByTargetObject.get(objName);
                if (fields == null || fields.isEmpty()) continue;

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
        for (FEC_Custom_Sync__c rec : recordsToValidate) {
            // Rule 1: CaseBusinessCode != null => TargetObject must be 'Case'
            if (String.isNotBlank(rec.FEC_Case_Business_Code__c) 
                && rec.FEC_Target_Object__c != 'Case' && rec.FEC_Target_Object__c != 'case') {
                rec.addError('CaseBusinessCode is only applicable when Target Object is "Case".');
            }

            // Rule 2: ProcessingQuantity must be > 0
            if (rec.FEC_Processing_Quantity__c == null || rec.FEC_Processing_Quantity__c <= 0) {
                rec.addError('ProcessingQuantity must be greater than 0.');
            }

            // Rule 3: Validate JSON format for RequestBodyMapping, MappingDataType, StaticMapValue
            if (String.isNotBlank(rec.FEC_Request_Body_Mapping__c)) {
                try {
                    JSON.deserializeUntyped(rec.FEC_Request_Body_Mapping__c);
                } catch (Exception e) {
                    rec.addError('Invalid JSON format in Request Body Mapping: ' + e.getMessage());
                }
            }
            if (String.isNotBlank(rec.FEC_Mapping_Data_Type__c)) {
                try {
                    JSON.deserializeUntyped(rec.FEC_Mapping_Data_Type__c);
                } catch (Exception e) {
                    rec.addError('Invalid JSON format in Mapping Data Type: ' + e.getMessage());
                }
            }
            if (String.isNotBlank(rec.FEC_Static_Map_Value__c)) {
                try {
                    Map<String, Object> staticMap = (Map<String, Object>) JSON.deserializeUntyped(rec.FEC_Static_Map_Value__c);
                    for (String key : staticMap.keySet()) {
                        if (!key.endsWith('__g')) {
                            rec.addError('Static Map Value key "' + key + '" must end with "__g" suffix.');
                            break;
                        }
                    }
                } catch (Exception e) {
                    rec.addError('Invalid JSON format in Static Map Value: ' + e.getMessage());
                }
            }

            // Rule 3b: Compare keys between RequestBodyMapping and MappingDataType
            if (String.isNotBlank(rec.FEC_Request_Body_Mapping__c) && String.isNotBlank(rec.FEC_Mapping_Data_Type__c)) {
                try {
                    Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(rec.FEC_Request_Body_Mapping__c);
                    Map<String, Object> typeMap = (Map<String, Object>) JSON.deserializeUntyped(rec.FEC_Mapping_Data_Type__c);

                    Set<String> bodyKeys = bodyMap.keySet();
                    Set<String> typeKeys = typeMap.keySet();

                    Set<String> extraInType = new Set<String>(typeKeys);
                    extraInType.removeAll(bodyKeys);

                    Set<String> missingInType = new Set<String>(bodyKeys);
                    missingInType.removeAll(typeKeys);

                    if (!extraInType.isEmpty()) {
                        rec.addError('MappingDataType has extra keys not in RequestBodyMapping: ' + String.join(new List<String>(extraInType), ', '));
                    }
                    if (!missingInType.isEmpty()) {
                        rec.addError('MappingDataType is missing keys from RequestBodyMapping: ' + String.join(new List<String>(missingInType), ', '));
                    }
                } catch (Exception e) {
                    // JSON parse errors already caught above
                }
            }

            // Rule 3c: Validate __g static values are compatible with MappingDataType
            if (String.isNotBlank(rec.FEC_Request_Body_Mapping__c) 
                && String.isNotBlank(rec.FEC_Static_Map_Value__c) 
                && String.isNotBlank(rec.FEC_Mapping_Data_Type__c)) {
                try {
                    Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(rec.FEC_Request_Body_Mapping__c);
                    Map<String, Object> staticMap = (Map<String, Object>) JSON.deserializeUntyped(rec.FEC_Static_Map_Value__c);
                    Map<String, Object> typeMap = (Map<String, Object>) JSON.deserializeUntyped(rec.FEC_Mapping_Data_Type__c);

                    for (String jsonKey : bodyMap.keySet()) {
                        Object mappingVal = bodyMap.get(jsonKey);
                        if (!(mappingVal instanceof String) || !((String) mappingVal).endsWith('__g')) continue;

                        String staticKey = (String) mappingVal;
                        if (!staticMap.containsKey(staticKey)) continue;

                        Object staticVal = staticMap.get(staticKey);
                        if (staticVal == null) continue;

                        String targetType = typeMap.containsKey(jsonKey) ? ((String) typeMap.get(jsonKey)).toUpperCase() : null;
                        if (String.isBlank(targetType)) continue;

                        if (targetType == 'NUMBER') {
                            if (!(staticVal instanceof Decimal) && !(staticVal instanceof Integer)) {
                                try {
                                    Decimal.valueOf(String.valueOf(staticVal));
                                } catch (Exception e) {
                                    rec.addError('Static Map Value "' + staticKey + '" = "' + staticVal + '" is not compatible with DataType NUMBER for key "' + jsonKey + '".');
                                }
                            }
                        } else if (targetType.startsWith('TIMESTAMP')) {
                            if (!(staticVal instanceof String)) {
                                rec.addError('Static Map Value "' + staticKey + '" must be a date/time string for DataType TIMESTAMP for key "' + jsonKey + '".');
                            } else {
                                // Validate format: try to parse as DateTime or Date
                                String dateStr = (String) staticVal;
                                Boolean validDate = false;
                                // Try ISO format: yyyy-MM-dd'T'HH:mm:ss
                                try {
                                    Datetime.valueOf(dateStr.replace('T', ' ').replace('Z', ''));
                                    validDate = true;
                                } catch (Exception e) {}
                                // Try date-only format: yyyy-MM-dd
                                if (!validDate) {
                                    try {
                                        Date.valueOf(dateStr);
                                        validDate = true;
                                    } catch (Exception e) {}
                                }
                                // Try dd/MM/yyyy format
                                if (!validDate) {
                                    Pattern p = Pattern.compile('^\\d{1,2}[/\\-]\\d{1,2}[/\\-]\\d{4}(\\s\\d{1,2}:\\d{2}(:\\d{2})?)?$');
                                    validDate = p.matcher(dateStr).matches();
                                }
                                if (!validDate) {
                                    rec.addError('Static Map Value "' + staticKey + '" = "' + dateStr + '" is not a valid date/time format for DataType TIMESTAMP for key "' + jsonKey + '".');
                                }
                            }
                        }
                    }
                } catch (Exception e) {
                    // JSON parse errors already caught above
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

            // Rule 6: Additional Conditions must start with AND or OR
            if (String.isNotBlank(rec.FEC_Additional_Conditions__c)) {
                String trimmed = rec.FEC_Additional_Conditions__c.trim().toUpperCase();
                if (!trimmed.startsWith('AND') && !trimmed.startsWith('OR')) {
                    rec.addError('Additional Conditions must start with "AND" or "OR".');
                }
            }
        }
    }
}