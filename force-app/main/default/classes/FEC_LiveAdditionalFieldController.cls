/**
 * @description Live mirror of FEC_AdditionalFieldController.
 *              Provides CRUD on Live FEC_Additional_Field__c and FEC_Additional_Field_List_Value__c.
 * @date   2026
 */
public with sharing class FEC_LiveAdditionalFieldController {

    @AuraEnabled(cacheable=true)
    public static List<FEC_Additional_Field__c> getAdditionalFields() {
        List<FEC_Additional_Field__c> fields = [
            SELECT Id, Name, FEC_Unique_ID__c, FEC_Name_VN__c, FEC_Type__c,
                   FEC_Field_Status__c, FEC_Field_Mandatory__c, CreatedDate
            FROM FEC_Additional_Field__c
            ORDER BY CreatedDate DESC
        ];
        return (List<FEC_Additional_Field__c>) Security.stripInaccessible(AccessType.READABLE, fields).getRecords();
    }

    @AuraEnabled
    public static String deleteRecord(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_DELETE_RECORD_PREFIX + ' Invalid Id');
        }
        try {
            if (!FEC_Additional_Field__c.SObjectType.getDescribe().isDeletable()) {
                throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
            }
            delete new FEC_Additional_Field__c(Id = recordId);
            return FEC_UIConstants.OPERATION_SUCCESS;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_DELETE_RECORD_PREFIX + ' ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_Additional_Field_List_Value__c> getFieldListValues(Id selectedFieldId) {
        if (selectedFieldId == null) return new List<FEC_Additional_Field_List_Value__c>();
        List<FEC_Additional_Field_List_Value__c> values = [
            SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c, FEC_Order__c, FEC_Additional_Field__c
            FROM FEC_Additional_Field_List_Value__c
            WHERE FEC_Additional_Field__c = :selectedFieldId
            ORDER BY FEC_Order__c ASC NULLS LAST
        ];
        return (List<FEC_Additional_Field_List_Value__c>) Security.stripInaccessible(AccessType.READABLE, values).getRecords();
    }

    @AuraEnabled
    public static List<FEC_Additional_Field_List_Value__c> getFieldListValuesFresh(Id selectedFieldId) {
        return getFieldListValues(selectedFieldId);
    }

    @AuraEnabled
    public static String deleteFieldListValue(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_DELETE_FIELDLIST_PREFIX + ' Invalid Id');
        }
        try {
            if (!FEC_Additional_Field_List_Value__c.SObjectType.getDescribe().isDeletable()) {
                throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
            }
            delete [SELECT Id FROM FEC_Additional_Field_List_Value__c WHERE Id = :recordId];
            return FEC_UIConstants.OPERATION_SUCCESS;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_DELETE_FIELDLIST_PREFIX + ' ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAdditionalFieldOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_Additional_Field__c> fields = [
            SELECT Id, Name FROM FEC_Additional_Field__c
            WHERE FEC_Field_Status__c = true ORDER BY Name ASC
        ];
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, fields).getRecords();
        for (FEC_Additional_Field__c f : (List<FEC_Additional_Field__c>) safe) {
            options.add(new Map<String, String>{ 'label' => f.Name, 'value' => f.Id });
        }
        return options;
    }

    /**
     * @description Save Property + List Values in one transaction.
     *              Mirrors FEC_AdditionalFieldController.savePropertyWithListValues but for Live objects.
     *              Does NOT deploy metadata fields (Live objects already have fields deployed).
     */
    @AuraEnabled
    public static Map<String, Object> savePropertyWithListValues(
        Map<String, Object> propertyData, String listValuesRaw
    ) {
        String existingId = (String) propertyData.get('Id');
        Boolean isEditMode = String.isNotBlank(existingId);

        if (!isEditMode && !FEC_Additional_Field__c.SObjectType.getDescribe().isCreateable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Create_Permission);
        }

        String propertyType = (String) propertyData.get('FEC_Type__c');

        if (isEditMode) {
            return replaceListValues(existingId, listValuesRaw);
        }

        if (propertyType == 'List' && String.isBlank(listValuesRaw)) {
            throw new AuraHandledException(System.Label.FEC_Error_Required_Fields + ': List Values are required for Type "List"');
        }

        List<Map<String, String>> parsedValues = new List<Map<String, String>>();
        if (String.isNotBlank(listValuesRaw) && propertyType == 'List') {
            parsedValues = parseListValues(listValuesRaw);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            FEC_Additional_Field__c prop = new FEC_Additional_Field__c();
            prop.Name = (String) propertyData.get('Name');
            prop.FEC_Unique_ID__c = (String) propertyData.get('FEC_Unique_ID__c');
            prop.FEC_Type__c = propertyType;
            prop.FEC_Name_VN__c = (String) propertyData.get('FEC_Name_VN__c');
            prop.FEC_Field_Mandatory__c = propertyData.containsKey('FEC_Field_Mandatory__c')
                ? (Boolean) propertyData.get('FEC_Field_Mandatory__c') : false;
            prop.FEC_Field_Status__c = true;

            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE, new List<FEC_Additional_Field__c>{ prop }
            );
            FEC_Additional_Field__c sanitized = (FEC_Additional_Field__c) decision.getRecords()[0];
            insert sanitized;

            // Auto-assign FEC_Code__c = Id
            sanitized.FEC_Code__c = sanitized.Id;
            update sanitized;

            if (!parsedValues.isEmpty()) {
                if (!FEC_Additional_Field_List_Value__c.SObjectType.getDescribe().isCreateable()) {
                    Database.rollback(sp);
                    throw new AuraHandledException(System.Label.FEC_Error_No_Create_Permission + ' (List Values)');
                }
                List<FEC_Additional_Field_List_Value__c> lvs = new List<FEC_Additional_Field_List_Value__c>();
                Integer order = 1;
                for (Map<String, String> pv : parsedValues) {
                    lvs.add(new FEC_Additional_Field_List_Value__c(
                        FEC_Code__c = pv.get('code'),
                        Name = pv.get('nameEN'),
                        FEC_Name_VN__c = pv.get('nameVN'),
                        FEC_Additional_Field__c = sanitized.Id,
                        FEC_Order__c = order
                    ));
                    order++;
                }
                SObjectAccessDecision lvDecision = Security.stripInaccessible(AccessType.CREATABLE, lvs);
                try {
                    insert lvDecision.getRecords();
                } catch (Exception lvEx) {
                    Database.rollback(sp);
                    throw new AuraHandledException(System.Label.FEC_Error_DML_Prefix + ' List Values: ' + lvEx.getMessage());
                }
            }

            return new Map<String, Object>{
                'propertyId' => sanitized.Id,
                'success' => true,
                'message' => 'Property created successfully'
            };
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (DmlException dml) {
            Database.rollback(sp);
            throw new AuraHandledException(dml.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    @TestVisible
    private static List<Map<String, String>> parseListValues(String rawText) {
        List<Map<String, String>> result = new List<Map<String, String>>();
        Set<String> seenCodes = new Set<String>();
        List<String> errors = new List<String>();

        if (String.isBlank(rawText)) return result;

        List<String> lines = rawText.split('\n');
        for (Integer i = 0; i < lines.size(); i++) {
            String line = lines[i].trim();
            if (String.isBlank(line)) continue;
            List<String> parts = line.split('\\|');
            if (parts.size() != 3) {
                errors.add('Line ' + (i + 1) + ' - Expected format: Code|Name EN|Name VN');
                continue;
            }
            String code = parts[0].trim();
            String nameEN = parts[1].trim();
            String nameVN = parts[2].trim();
            if (String.isBlank(code) || String.isBlank(nameEN)) {
                errors.add('Line ' + (i + 1) + ' - Code and Name EN are required');
                continue;
            }
            if (seenCodes.contains(code.toLowerCase())) {
                errors.add('Line ' + (i + 1) + ' - Duplicate Code: ' + code);
            } else {
                seenCodes.add(code.toLowerCase());
            }
            result.add(new Map<String, String>{ 'code' => code, 'nameEN' => nameEN, 'nameVN' => nameVN });
        }

        if (!errors.isEmpty()) {
            throw new AuraHandledException(String.join(errors, '; '));
        }
        return result;
    }

    private static Map<String, Object> replaceListValues(String propertyId, String listValuesRaw) {
        List<Map<String, String>> parsedValues = String.isNotBlank(listValuesRaw)
            ? parseListValues(listValuesRaw)
            : new List<Map<String, String>>();

        Savepoint sp = Database.setSavepoint();
        try {
            List<FEC_Additional_Field_List_Value__c> existing = [
                SELECT Id FROM FEC_Additional_Field_List_Value__c WHERE FEC_Additional_Field__c = :propertyId
            ];
            if (!existing.isEmpty()) delete existing;

            if (!parsedValues.isEmpty()) {
                List<FEC_Additional_Field_List_Value__c> newValues = new List<FEC_Additional_Field_List_Value__c>();
                Integer order = 1;
                for (Map<String, String> pv : parsedValues) {
                    newValues.add(new FEC_Additional_Field_List_Value__c(
                        FEC_Code__c = pv.get('code'),
                        Name = pv.get('nameEN'),
                        FEC_Name_VN__c = pv.get('nameVN'),
                        FEC_Additional_Field__c = propertyId,
                        FEC_Order__c = order
                    ));
                    order++;
                }
                insert newValues;
            }

            return new Map<String, Object>{
                'propertyId' => propertyId,
                'success' => true,
                'message' => 'List Values updated successfully'
            };
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Error updating List Values: ' + e.getMessage());
        }
    }
}