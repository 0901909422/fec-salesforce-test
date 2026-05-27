/**
 * @description Batch class đồng bộ Property records từ metadata FEC_Additional_Info__c.
 * Xóa dữ liệu Property/List Value cũ, đọc Schema metadata, tạo lại Property + List Value tương ứng,
 * rồi chain FEC_PushMDMToLiveBatch để đẩy sang Live layer.
 * Chạy một lần khi cần reset thư viện Property.
 * @date 2026-04-21
 */
public with sharing class FEC_SyncPropertyFromSchemaBatch implements Database.Batchable<String>, Database.Stateful {

    // ── Type Mapping: Salesforce DisplayType → Property FEC_Type__c ──
    @TestVisible
    private static final Map<String, String> TYPE_MAPPING = new Map<String, String>{
        'PICKLIST'       => 'List',
        'MULTIPICKLIST'  => 'List',
        'STRING'         => 'String',
        'TEXTAREA'       => 'String',
        'DOUBLE'         => 'Number',
        'CURRENCY'       => 'Number',
        'PERCENT'        => 'Number',
        'INTEGER'        => 'Number',
        'BOOLEAN'        => 'Boolean',
        'DATE'           => 'Date',
        'DATETIME'       => 'DateTime',
        'TIME'           => 'Time',
        'PHONE'          => 'Phone number'
    };

    // ── System fields to skip ──
    @TestVisible
    private static final Set<String> SYSTEM_FIELDS = new Set<String>{
        'id', 'createddate', 'lastmodifieddate', 'systemmodstamp',
        'isdeleted', 'createdbyid', 'lastmodifiedbyid', 'ownerid',
        'fec_case__c', 'name', 'lastvieweddate', 'lastreferenceddate',
        'fec_sync_error__c'
    };

    private static final String TARGET_OBJECT = 'FEC_Additional_Info__c';

    // ── Stateful counters ──
    private Integer totalFieldsRead = 0;
    private Integer propertiesCreated = 0;
    private Integer propertiesFailed = 0;
    private Integer listValuesCreated = 0;
    private Integer listValuesFailed = 0;
    private Integer deletedProperties = 0;
    private Integer deletedListValues = 0;
    private List<String> errors = new List<String>();

    // Stateful map: fieldApiName (lowercase) → Property Id (for List Value creation step)
    private Map<String, Id> fieldApiNameToPropertyIdMap = new Map<String, Id>();

    // ── Execution steps ──
    private List<String> steps = new List<String>{ 'DELETE', 'CREATE_PROPERTIES', 'CREATE_LIST_VALUES' };

    public Iterable<String> start(Database.BatchableContext bc) {
        System.debug('FEC_DEBUG SyncPropertyFromSchema: START batch');
        return steps;
    }

    public void execute(Database.BatchableContext bc, List<String> scope) {
        String step = scope[0];
        System.debug('FEC_DEBUG SyncPropertyFromSchema: executing step = ' + step);

        if (step == 'DELETE') {
            deleteExistingRecords();
        } else if (step == 'CREATE_PROPERTIES') {
            createPropertiesFromSchema();
        } else if (step == 'CREATE_LIST_VALUES') {
            createListValuesFromPicklists();
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('FEC_DEBUG SyncPropertyFromSchema: FINISH batch');
        sendSummaryEmail();
        // Chain Push to Live batch
        Database.executeBatch(new FEC_PushMDMToLiveBatch(), 1);
    }

    // ══════════════════════════════════════════════════════════════════════
    // STEP 1: DELETE existing records
    // ══════════════════════════════════════════════════════════════════════
    private void deleteExistingRecords() {
        // Delete List Values first (child) to avoid referential integrity issues
        List<FEC_MDM_Additional_Field_List_Value__c> listValues = [
            SELECT Id FROM FEC_MDM_Additional_Field_List_Value__c LIMIT 50000
        ];
        if (!listValues.isEmpty()) {
            FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
            try {
                Database.DeleteResult[] lvResults = Database.delete(listValues, false);
                for (Database.DeleteResult dr : lvResults) {
                    if (dr.isSuccess()) {
                        deletedListValues++;
                    } else {
                        for (Database.Error err : dr.getErrors()) {
                            errors.add('[Delete ListValue] ' + err.getMessage());
                        }
                    }
                }
            } finally {
                FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
            }
        }
        System.debug('FEC_DEBUG SyncPropertyFromSchema: deleted ' + deletedListValues + ' List Values');

        // Then delete Properties (parent)
        List<FEC_MDM_Additional_Field__c> properties = [
            SELECT Id FROM FEC_MDM_Additional_Field__c LIMIT 50000
        ];
        if (!properties.isEmpty()) {
            FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
            try {
                Database.DeleteResult[] propResults = Database.delete(properties, false);
                for (Database.DeleteResult dr : propResults) {
                    if (dr.isSuccess()) {
                        deletedProperties++;
                    } else {
                        for (Database.Error err : dr.getErrors()) {
                            errors.add('[Delete Property] ' + err.getMessage());
                        }
                    }
                }
            } finally {
                FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
            }
        }
        System.debug('FEC_DEBUG SyncPropertyFromSchema: deleted ' + deletedProperties + ' Properties');
    }

    // ══════════════════════════════════════════════════════════════════════
    // STEP 2: CREATE Properties from Schema metadata
    // ══════════════════════════════════════════════════════════════════════
    private void createPropertiesFromSchema() {
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(TARGET_OBJECT);
        if (objType == null) {
            errors.add('[Schema] Object ' + TARGET_OBJECT + ' not found in Schema');
            return;
        }

        Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();
        List<FEC_MDM_Additional_Field__c> propertiesToInsert = new List<FEC_MDM_Additional_Field__c>();

        for (String fieldName : fieldsMap.keySet()) {
            // Skip system fields (compare lowercase)
            if (SYSTEM_FIELDS.contains(fieldName.toLowerCase())) {
                continue;
            }

            Schema.DescribeFieldResult fieldDesc = fieldsMap.get(fieldName).getDescribe();

            // Skip non-custom fields that are not useful (formula, auto-number, etc.)
            if (!fieldDesc.isCustom()) {
                continue;
            }

            totalFieldsRead++;

            String fieldApiName = fieldDesc.getName();
            String fieldLabel = fieldDesc.getLabel();
            String mappedType = mapFieldType(fieldDesc.getType());

            FEC_MDM_Additional_Field__c prop = new FEC_MDM_Additional_Field__c();
            prop.Name = fieldLabel.length() > 80 ? fieldLabel.substring(0, 80) : fieldLabel;
            prop.FEC_Unique_ID__c = fieldApiName;
            prop.FEC_Type__c = mappedType;
            prop.FEC_Field_Status__c = true;
            prop.Field_API_Name__c = fieldApiName;
            prop.Process_Change_Status__c = FEC_UIConstants.PROCESS_STATUS_NEW;

            propertiesToInsert.add(prop);
        }

        if (!propertiesToInsert.isEmpty()) {
            FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
            try {
                Database.SaveResult[] results = Database.insert(propertiesToInsert, false);
                for (Integer i = 0; i < results.size(); i++) {
                    if (results[i].isSuccess()) {
                        propertiesCreated++;
                        // Auto-assign FEC_Code__c = Record Id (required for Push to Live upsert)
                        propertiesToInsert[i].FEC_Code__c = results[i].getId();
                        // Store mapping for List Value creation step
                        String apiName = propertiesToInsert[i].Field_API_Name__c;
                        fieldApiNameToPropertyIdMap.put(apiName.toLowerCase(), results[i].getId());
                    } else {
                        propertiesFailed++;
                        for (Database.Error err : results[i].getErrors()) {
                            errors.add('[Insert Property ' + propertiesToInsert[i].FEC_Unique_ID__c + '] ' + err.getMessage());
                        }
                    }
                }
                // Persist FEC_Code__c = Id for successful inserts
                List<FEC_MDM_Additional_Field__c> toUpdateCode = new List<FEC_MDM_Additional_Field__c>();
                for (FEC_MDM_Additional_Field__c p : propertiesToInsert) {
                    if (p.Id != null && p.FEC_Code__c != null) {
                        toUpdateCode.add(new FEC_MDM_Additional_Field__c(Id = p.Id, FEC_Code__c = p.FEC_Code__c));
                    }
                }
                if (!toUpdateCode.isEmpty()) {
                    Database.update(toUpdateCode, false);
                }
            } finally {
                FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
            }
        }

        System.debug('FEC_DEBUG SyncPropertyFromSchema: read ' + totalFieldsRead + ' fields, created ' + propertiesCreated + ' Properties, failed ' + propertiesFailed);
    }

    // ══════════════════════════════════════════════════════════════════════
    // STEP 3: CREATE List Values from picklist metadata
    // ══════════════════════════════════════════════════════════════════════
    private void createListValuesFromPicklists() {
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(TARGET_OBJECT);
        if (objType == null) {
            errors.add('[Schema] Object ' + TARGET_OBJECT + ' not found in Schema (List Values step)');
            return;
        }

        Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();
        List<FEC_MDM_Additional_Field_List_Value__c> listValuesToInsert = new List<FEC_MDM_Additional_Field_List_Value__c>();

        for (String fieldName : fieldsMap.keySet()) {
            Schema.DescribeFieldResult fieldDesc = fieldsMap.get(fieldName).getDescribe();

            // Only process Picklist and MultiPicklist fields
            if (fieldDesc.getType() != Schema.DisplayType.Picklist &&
                fieldDesc.getType() != Schema.DisplayType.MultiPicklist) {
                continue;
            }

            String fieldApiName = fieldDesc.getName();
            Id propertyId = fieldApiNameToPropertyIdMap.get(fieldApiName.toLowerCase());

            if (propertyId == null) {
                // Property was not created (maybe failed or was a system field)
                continue;
            }

            List<Schema.PicklistEntry> entries = fieldDesc.getPicklistValues();
            Integer order = 1;

            for (Schema.PicklistEntry entry : entries) {
                if (!entry.isActive()) {
                    continue;
                }

                FEC_MDM_Additional_Field_List_Value__c lv = new FEC_MDM_Additional_Field_List_Value__c();
                lv.Name = entry.getLabel().length() > 80 ? entry.getLabel().substring(0, 80) : entry.getLabel();
                lv.FEC_Code__c = entry.getValue();
                lv.FEC_Additional_Field__c = propertyId;
                lv.FEC_Order__c = order;
                lv.Process_Change_Status__c = FEC_UIConstants.PROCESS_STATUS_NEW;

                listValuesToInsert.add(lv);
                order++;
            }
        }

        if (!listValuesToInsert.isEmpty()) {
            FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
            try {
                Database.SaveResult[] results = Database.insert(listValuesToInsert, false);
                for (Integer i = 0; i < results.size(); i++) {
                    if (results[i].isSuccess()) {
                        listValuesCreated++;
                    } else {
                        listValuesFailed++;
                        for (Database.Error err : results[i].getErrors()) {
                            errors.add('[Insert ListValue] ' + err.getMessage());
                        }
                    }
                }
            } finally {
                FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
            }
        }

        System.debug('FEC_DEBUG SyncPropertyFromSchema: created ' + listValuesCreated + ' List Values, failed ' + listValuesFailed);
    }

    // ══════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @description Map Salesforce DisplayType to Property FEC_Type__c value.
     * Returns "String" as default for unmapped types.
     */
    @TestVisible
    private static String mapFieldType(Schema.DisplayType sfType) {
        String typeName = sfType.name().toUpperCase();
        return TYPE_MAPPING.containsKey(typeName) ? TYPE_MAPPING.get(typeName) : 'String';
    }

    /**
     * @description Send summary email to admin with sync results.
     */
    private void sendSummaryEmail() {
        String adminEmails = System.Label.FEC_MDM_Sync_Admin_Emails;
        if (String.isBlank(adminEmails)) {
            System.debug('FEC_DEBUG SyncPropertyFromSchema: No admin emails configured');
            return;
        }

        List<String> toAddresses = adminEmails.split(',');
        for (Integer i = 0; i < toAddresses.size(); i++) {
            toAddresses[i] = toAddresses[i].trim();
        }

        String subject = 'FEC Property Sync from Schema — Summary Report';
        String body = 'Property Sync from ' + TARGET_OBJECT + ' Schema completed.\n\n'
            + '── Delete Phase ──\n'
            + 'Properties deleted: ' + deletedProperties + '\n'
            + 'List Values deleted: ' + deletedListValues + '\n\n'
            + '── Create Phase ──\n'
            + 'Total fields read: ' + totalFieldsRead + '\n'
            + 'Properties created: ' + propertiesCreated + '\n'
            + 'Properties failed: ' + propertiesFailed + '\n'
            + 'List Values created: ' + listValuesCreated + '\n'
            + 'List Values failed: ' + listValuesFailed + '\n';

        if (!errors.isEmpty()) {
            body += '\n── Errors ──\n';
            for (String err : errors) {
                body += '• ' + err + '\n';
            }
        }

        body += '\nPush to Live batch has been chained and will run next.';

        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(toAddresses);
            mail.setSubject(subject);
            mail.setPlainTextBody(body);
            mail.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug('FEC_DEBUG SyncPropertyFromSchema: Failed to send email: ' + e.getMessage());
        }
    }
}