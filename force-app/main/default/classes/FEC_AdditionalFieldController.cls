/**
 * @description Controller để xử lý logic truy vấn dữ liệu từ FEC_MDM_Additional_Field__c.
 * @date 2025-12-04
 * @author DAT NGO
 */
public with sharing class FEC_AdditionalFieldController {
    // Centralized constants used from FEC_Constants
    
    @AuraEnabled
    public static String deleteRecord(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_DELETE_RECORD_PREFIX + ' Invalid Id');
        }
        try {
            Schema.SObjectType t = FEC_MDM_Additional_Field__c.SObjectType;
            if (!t.getDescribe().isDeletable()) {
                throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
            }
            delete new FEC_MDM_Additional_Field__c(Id = recordId);
            return FEC_UIConstants.OPERATION_SUCCESS;
        } catch (Exception e) {
            System.debug('FEC_AdditionalFieldController.deleteRecord error: ' + e);
            throw new AuraHandledException(FEC_UIConstants.ERROR_DELETE_RECORD_PREFIX + ' ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FEC_MDM_Additional_Field__c> getAdditionalFields() {
        List<FEC_MDM_Additional_Field__c> fields = [
            SELECT Id, Name, FEC_Unique_ID__c, FEC_Name_VN__c, FEC_Type__c,
                   FEC_Field_Status__c, FEC_Field_Mandatory__c, Process_Change_Status__c, CreatedDate
            FROM FEC_MDM_Additional_Field__c
            ORDER BY CreatedDate DESC
        ];
        // Enforce field-level security before returning
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, fields).getRecords();
        return (List<FEC_MDM_Additional_Field__c>) safe;
    }
    
    /**
     * @description Non-cacheable version for edit form — always fetches fresh data from DB.
     * Use this after DML operations on List Values to avoid stale cache.
     */
    @AuraEnabled
    public static List<FEC_MDM_Additional_Field_List_Value__c> getFieldListValuesFresh(Id selectedFieldId) {
        return getFieldListValuesInternal(selectedFieldId);
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_MDM_Additional_Field_List_Value__c> getFieldListValues(Id selectedFieldId) {
        return getFieldListValuesInternal(selectedFieldId);
    }

    private static List<FEC_MDM_Additional_Field_List_Value__c> getFieldListValuesInternal(Id selectedFieldId) {
        System.debug('FEC_AdditionalFieldController.getFieldListValues selectedFieldId: ' + selectedFieldId);
        if (selectedFieldId == null) return new List<FEC_MDM_Additional_Field_List_Value__c>();
        
        List<FEC_MDM_Additional_Field_List_Value__c> values = [
            SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c, FEC_Order__c, FEC_Additional_Field__c, Process_Change_Status__c
            FROM FEC_MDM_Additional_Field_List_Value__c
            WHERE FEC_Additional_Field__c = :selectedFieldId
            ORDER BY FEC_Order__c ASC NULLS LAST
        ];
        System.debug('FEC_AdditionalFieldController.getFieldListValues found: ' + values.size());
        
        // Re-enable Security.stripInaccessible after confirming FLS in Permission Set
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, values).getRecords();
        return (List<FEC_MDM_Additional_Field_List_Value__c>) safe;
    }
    
    @AuraEnabled
    public static String deleteFieldListValue(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_DELETE_FIELDLIST_PREFIX + ' Invalid Id');
        }
        try {
            Schema.SObjectType t = FEC_MDM_Additional_Field_List_Value__c.SObjectType;
            if (!t.getDescribe().isDeletable()) {
                throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
            }
            delete [SELECT Id FROM FEC_MDM_Additional_Field_List_Value__c WHERE Id = :recordId];
            return FEC_UIConstants.OPERATION_SUCCESS;
        } catch (Exception e) {
            System.debug('FEC_AdditionalFieldController.deleteFieldListValue error: ' + e);
            throw new AuraHandledException(FEC_UIConstants.ERROR_DELETE_FIELDLIST_PREFIX + ' ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAdditionalFieldOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_MDM_Additional_Field__c> fields = [
            SELECT Id, Name 
            FROM FEC_MDM_Additional_Field__c 
            WHERE FEC_Field_Status__c = true
            ORDER BY Name ASC
        ];
        
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, fields).getRecords();
        for (FEC_MDM_Additional_Field__c field : (List<FEC_MDM_Additional_Field__c>) safe) {
            options.add(new Map<String, String>{
                'label' => field.Name,
                'value' => field.Id
            });
        }
        return options;
    }

    /**
     * @description Lưu Property record và List Value records trong một transaction.
     * Sử dụng Savepoint để rollback nếu List Value insert thất bại.
     * @param propertyData Map chứa thông tin Property (Name, FEC_Unique_ID__c, FEC_Type__c, FEC_Name_VN__c, FEC_Field_Mandatory__c, Field_API_Name__c)
     * @param listValuesRaw String textarea content (mỗi dòng: Code|Name EN|Name VN)
     * @return Map { propertyId: Id, success: Boolean, message: String }
     */
    @AuraEnabled
    public static Map<String, Object> savePropertyWithListValues(
        Map<String, Object> propertyData,
        String listValuesRaw
    ) {
        String existingId = (String) propertyData.get('Id');
        Boolean isEditMode = String.isNotBlank(existingId);

        // CRUD check
        if (!isEditMode && !FEC_MDM_Additional_Field__c.SObjectType.getDescribe().isCreateable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Create_Permission);
        }

        String propertyType = (String) propertyData.get('FEC_Type__c');

        // Edit mode: just replace List Values (delete old, insert new)
        if (isEditMode) {
            return replaceListValues(existingId, listValuesRaw);
        }

        // Validate: if Type = List, must have list values
        if (propertyType == 'List' && String.isBlank(listValuesRaw)) {
            throw new AuraHandledException(System.Label.FEC_Error_Required_Fields + ': List Values are required for Type "List"');
        }

        // Parse list values first (validates format before any DML)
        List<Map<String, String>> parsedValues = new List<Map<String, String>>();
        if (String.isNotBlank(listValuesRaw) && propertyType == 'List') {
            parsedValues = parseListValues(listValuesRaw);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            // 1. Create Property record
            FEC_MDM_Additional_Field__c prop = new FEC_MDM_Additional_Field__c();
            prop.Name = (String) propertyData.get('Name');
            prop.FEC_Unique_ID__c = (String) propertyData.get('FEC_Unique_ID__c');
            prop.FEC_Type__c = propertyType;
            prop.FEC_Name_VN__c = (String) propertyData.get('FEC_Name_VN__c');
            prop.FEC_Field_Mandatory__c = propertyData.containsKey('FEC_Field_Mandatory__c')
                ? (Boolean) propertyData.get('FEC_Field_Mandatory__c') : false;
            prop.FEC_Field_Status__c = true;
            prop.Field_API_Name__c = (String) propertyData.get('Field_API_Name__c');
            prop.Process_Change_Status__c = FEC_UIConstants.PROCESS_STATUS_NEW;

            // FLS enforcement
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<FEC_MDM_Additional_Field__c>{ prop }
            );
            FEC_MDM_Additional_Field__c sanitizedProp = (FEC_MDM_Additional_Field__c) decision.getRecords()[0];
            insert sanitizedProp;

            // Auto-assign FEC_Code__c = Record Id
            sanitizedProp.FEC_Code__c = sanitizedProp.Id;
            update sanitizedProp;

            // 2. Create List Value records (if any)
            if (!parsedValues.isEmpty()) {
                if (!FEC_MDM_Additional_Field_List_Value__c.SObjectType.getDescribe().isCreateable()) {
                    Database.rollback(sp);
                    throw new AuraHandledException(System.Label.FEC_Error_No_Create_Permission + ' (List Values)');
                }

                List<FEC_MDM_Additional_Field_List_Value__c> listValuesToInsert = new List<FEC_MDM_Additional_Field_List_Value__c>();
                Integer order = 1;
                for (Map<String, String> pv : parsedValues) {
                    FEC_MDM_Additional_Field_List_Value__c lv = new FEC_MDM_Additional_Field_List_Value__c();
                    lv.FEC_Code__c = pv.get('code');
                    lv.Name = pv.get('nameEN');
                    lv.FEC_Name_VN__c = pv.get('nameVN');
                    lv.FEC_Additional_Field__c = sanitizedProp.Id;
                    lv.FEC_Order__c = order;
                    lv.Process_Change_Status__c = FEC_UIConstants.PROCESS_STATUS_NEW;
                    listValuesToInsert.add(lv);
                    order++;
                }

                SObjectAccessDecision lvDecision = Security.stripInaccessible(
                    AccessType.CREATABLE,
                    listValuesToInsert
                );
                try {
                    insert lvDecision.getRecords();
                } catch (Exception lvEx) {
                    Database.rollback(sp);
                    throw new AuraHandledException(System.Label.FEC_Error_DML_Prefix + ' List Values: ' + lvEx.getMessage());
                }
            }

            // 3. Deploy field to FEC_Additional_Info__c via Metadata API
            String deployedFieldApiName;
            try {
                List<String> picklistVals = new List<String>();
                if (propertyType == 'List') {
                    for (Map<String, String> pv : parsedValues) {
                        picklistVals.add(pv.get('nameEN'));
                    }
                }
                deployedFieldApiName = FEC_MetadataFieldCreator.deployFieldFromProperty(
                    (String) propertyData.get('FEC_Unique_ID__c'),
                    (String) propertyData.get('Name'),
                    propertyType,
                    picklistVals
                );
                // Update Property with deployed field API name
                if (String.isNotBlank(deployedFieldApiName)) {
                    sanitizedProp.Field_API_Name__c = deployedFieldApiName;
                    update sanitizedProp;
                }
            } catch (Exception deployEx) {
                // Deploy failed but Property + List Values already saved
                System.debug('FEC_DEBUG deploy failed: ' + deployEx.getMessage());
                return new Map<String, Object>{
                    'propertyId' => sanitizedProp.Id,
                    'success' => true,
                    'message' => 'Property saved. Deploy field failed: ' + deployEx.getMessage(),
                    'deployError' => deployEx.getMessage()
                };
            }

            return new Map<String, Object>{
                'propertyId' => sanitizedProp.Id,
                'success' => true,
                'message' => 'Property created and field deployed successfully',
                'fieldApiName' => deployedFieldApiName
            };
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (DmlException dml) {
            Database.rollback(sp);
            AuraHandledException ex = new AuraHandledException(dml.getDmlMessage(0));
            ex.setMessage(dml.getDmlMessage(0));
            throw ex;
        } catch (Exception e) {
            Database.rollback(sp);
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    /**
     * @description Parse textarea content thành List<Map> cho List Values.
     * Format mỗi dòng: Code|Name EN|Name VN
     * @param rawText Textarea content
     * @return List<Map<String, String>> parsed values with keys: code, nameEN, nameVN
     * @throws AuraHandledException nếu format không hợp lệ hoặc có duplicate Code
     */
    @TestVisible
    private static List<Map<String, String>> parseListValues(String rawText) {
        List<Map<String, String>> result = new List<Map<String, String>>();
        Set<String> seenCodes = new Set<String>();
        List<String> formatErrors = new List<String>();
        List<String> duplicateErrors = new List<String>();

        if (String.isBlank(rawText)) {
            return result;
        }

        List<String> lines = rawText.split('\n');
        for (Integer i = 0; i < lines.size(); i++) {
            String line = lines[i].trim();
            if (String.isBlank(line)) {
                continue; // Skip empty lines
            }

            List<String> parts = line.split('\\|');
            if (parts.size() != 3) {
                formatErrors.add(System.Label.FEC_Error_Title + ': Line ' + (i + 1) + ' - Expected format: Code|Name EN|Name VN');
                continue;
            }

            String code = parts[0].trim();
            String nameEN = parts[1].trim();
            String nameVN = parts[2].trim();

            if (String.isBlank(code) || String.isBlank(nameEN)) {
                formatErrors.add(System.Label.FEC_Error_Title + ': Line ' + (i + 1) + ' - Code and Name EN are required');
                continue;
            }

            if (seenCodes.contains(code.toLowerCase())) {
                duplicateErrors.add(System.Label.FEC_Error_Title + ': Line ' + (i + 1) + ' - Duplicate Code: ' + code);
            } else {
                seenCodes.add(code.toLowerCase());
            }

            result.add(new Map<String, String>{
                'code' => code,
                'nameEN' => nameEN,
                'nameVN' => nameVN
            });
        }

        if (!formatErrors.isEmpty() || !duplicateErrors.isEmpty()) {
            List<String> allErrors = new List<String>();
            allErrors.addAll(formatErrors);
            allErrors.addAll(duplicateErrors);
            String errorMsg = String.join(allErrors, '; ');
            AuraHandledException ex = new AuraHandledException(errorMsg);
            ex.setMessage(errorMsg);
            throw ex;
        }

        return result;
    }

    /**
     * @description Replace all List Values for an existing Property.
     * Deletes old List Values and inserts new ones from raw text.
     */
    private static Map<String, Object> replaceListValues(String propertyId, String listValuesRaw) {
        // Parse new values
        List<Map<String, String>> parsedValues = String.isNotBlank(listValuesRaw)
            ? parseListValues(listValuesRaw)
            : new List<Map<String, String>>();

        Savepoint sp = Database.setSavepoint();
        try {
            // Delete existing List Values
            List<FEC_MDM_Additional_Field_List_Value__c> existing = [
                SELECT Id FROM FEC_MDM_Additional_Field_List_Value__c
                WHERE FEC_Additional_Field__c = :propertyId
            ];
            if (!existing.isEmpty()) {
                FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
                try {
                    delete existing;
                } finally {
                    FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
                }
            }

            // Insert new List Values
            if (!parsedValues.isEmpty()) {
                List<FEC_MDM_Additional_Field_List_Value__c> newValues = new List<FEC_MDM_Additional_Field_List_Value__c>();
                Integer order = 1;
                for (Map<String, String> pv : parsedValues) {
                    FEC_MDM_Additional_Field_List_Value__c lv = new FEC_MDM_Additional_Field_List_Value__c();
                    lv.FEC_Code__c = pv.get('code');
                    lv.Name = pv.get('nameEN');
                    lv.FEC_Name_VN__c = pv.get('nameVN');
                    lv.FEC_Additional_Field__c = propertyId;
                    lv.FEC_Order__c = order;
                    lv.Process_Change_Status__c = FEC_UIConstants.PROCESS_STATUS_NEW;
                    newValues.add(lv);
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