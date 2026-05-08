public with sharing class FEC_FecServiceTypeMappingController {
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getServiceTypeTree() {
        Map<Id, FEC_MDM_Business_Process__c> bpMap = new Map<Id, FEC_MDM_Business_Process__c>(
            [SELECT Id, Name FROM FEC_MDM_Business_Process__c ORDER BY Name]
            );
        
        List<FEC_MDM_Master_Data_Setting__c> allSettings = [
            SELECT Id, Name, FEC_Additional_Field__r.Name, Property_Reference__c, 
                   FEC_Nature_Of_Case__r.FEC_Business_Process__c,
                   FEC_Field_Label_Name__c, FEC_Field_API_Name__c
            FROM FEC_MDM_Master_Data_Setting__c
            WHERE FEC_Nature_Of_Case__r.FEC_Business_Process__c IN :bpMap.keySet()
            AND (FEC_Additional_Field__c != null OR FEC_Field_API_Name__c != null)
            ORDER BY Name
        ];
        
        Map<Id, List<Map<String, Object>>> bpToProperties = new Map<Id, List<Map<String, Object>>>();
        for(FEC_MDM_Master_Data_Setting__c setting : allSettings) {
            Id bpId = setting.FEC_Nature_Of_Case__r.FEC_Business_Process__c;
            if(!bpToProperties.containsKey(bpId)) {
                bpToProperties.put(bpId, new List<Map<String, Object>>());
            }
            String fieldLabelName = setting.FEC_Field_Label_Name__c;
            String fallbackName = setting.FEC_Additional_Field__r != null ? setting.FEC_Additional_Field__r.Name : setting.Name;
            String displayLabel = String.isNotBlank(fieldLabelName) ? fieldLabelName : fallbackName;
            bpToProperties.get(bpId).add(new Map<String, Object>{
                FEC_UIConstants.MAP_LABEL => displayLabel,
                FEC_UIConstants.MAP_NAME => setting.Id,
                FEC_UIConstants.MAP_PROPERTY_REF => setting.Property_Reference__c,
                FEC_UIConstants.MAP_PARENT_NAME => bpMap.get(bpId).Name,
                FEC_UIConstants.MAP_FIELD_LABEL => displayLabel,
                FEC_UIConstants.MAP_FIELD_API_NAME => setting.FEC_Field_API_Name__c
             });
        }
        
        List<Map<String, Object>> treeData = new List<Map<String, Object>>();
        for(FEC_MDM_Business_Process__c bp : bpMap.values()) {
            List<Map<String, Object>> children = bpToProperties.containsKey(bp.Id)
                ? bpToProperties.get(bp.Id)
                : new List<Map<String, Object>>();
            treeData.add(new Map<String, Object>{
                FEC_UIConstants.MAP_LABEL => bp.Name,
                FEC_UIConstants.MAP_NAME => bp.Id,
                FEC_UIConstants.MAP_EXPANDED => false,
                FEC_UIConstants.MAP_ITEMS => children
             });
        }
        System.debug(FEC_Constants.DEBUG_SERVICE_TYPE_TREE_PREFIX + treeData);
        return treeData;
    }
    
    @AuraEnabled
    public static void savePropertyMapping(Id settingId, String newRef) {
        if (settingId == null) throw new AuraHandledException(FEC_UIConstants.ERROR_INVALID_ID);
        try {
            Schema.SObjectType t = FEC_MDM_Master_Data_Setting__c.SObjectType;
            Schema.DescribeSObjectResult dsr = t.getDescribe();
            if (!dsr.isUpdateable()) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_NO_UPDATE_PERMISSION);
            }
            Schema.SObjectField sf = dsr.fields.getMap().get(FEC_FieldConstants.FIELD_PROPERTY_REFERENCE.toLowerCase());
            if (sf == null) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_INVALID_FIELD);
            }
            if (!sf.getDescribe().isUpdateable()) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_NO_FIELD_UPDATE_PERMISSION);
            }
            update new FEC_MDM_Master_Data_Setting__c(
                Id = settingId,
                Property_Reference__c = newRef
            );
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            // Log minimal details, return friendly message
            System.debug('FEC_FecServiceTypeMappingController.savePropertyMapping error: ' + e);
            throw new AuraHandledException(System.Label.FEC_Error_Save_Property_Mapping);
        }
     }

    @AuraEnabled
    public static void savePropertyMappings(String mappingsJson) {
        if (String.isBlank(mappingsJson)) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_INVALID_ID);
        }
        try {
            List<Object> mappingsList = (List<Object>) JSON.deserializeUntyped(mappingsJson);
            if (mappingsList.isEmpty()) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_INVALID_ID);
            }

            // Validate object-level update permission
            Schema.SObjectType t = FEC_MDM_Master_Data_Setting__c.SObjectType;
            Schema.DescribeSObjectResult dsr = t.getDescribe();
            if (!dsr.isUpdateable()) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_NO_UPDATE_PERMISSION);
            }

            // Validate field-level update permission for Property_Reference__c
            Schema.SObjectField sf = dsr.fields.getMap().get(FEC_FieldConstants.FIELD_PROPERTY_REFERENCE.toLowerCase());
            if (sf == null) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_INVALID_FIELD);
            }
            if (!sf.getDescribe().isUpdateable()) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_NO_FIELD_UPDATE_PERMISSION);
            }

            // Build list of records to update
            List<FEC_MDM_Master_Data_Setting__c> recordsToUpdate = new List<FEC_MDM_Master_Data_Setting__c>();
            for (Object item : mappingsList) {
                Map<String, Object> mapping = (Map<String, Object>) item;
                String settingId = (String) mapping.get('settingId');
                String newRef = (String) mapping.get('newRef');
                recordsToUpdate.add(new FEC_MDM_Master_Data_Setting__c(
                    Id = (Id) settingId,
                    Property_Reference__c = newRef
                ));
            }

            update recordsToUpdate;
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            System.debug('FEC_FecServiceTypeMappingController.savePropertyMappings error: ' + e);
            throw new AuraHandledException(System.Label.FEC_Error_Save_Property_Mapping);
        }
    }
 }