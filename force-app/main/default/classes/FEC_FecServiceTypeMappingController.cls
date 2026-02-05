public with sharing class FEC_FecServiceTypeMappingController {
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getServiceTypeTree() {
        Map<Id, FEC_MDM_Business_Process__c> bpMap = new Map<Id, FEC_MDM_Business_Process__c>(
            [SELECT Id, Name FROM FEC_MDM_Business_Process__c ORDER BY Name LIMIT :FEC_Constants.QUERY_LIMIT]
            );
        
        List<FEC_MDM_Master_Data_Setting__c> allSettings = [
            SELECT Id, Name,FEC_Additional_Field__r.Name, Property_Reference__c, 
                   FEC_Nature_Of_Case__r.FEC_Business_Process_Name__c 
            FROM FEC_MDM_Master_Data_Setting__c
            WHERE FEC_Nature_Of_Case__r.FEC_Business_Process_Name__c IN :bpMap.keySet()
            AND FEC_Additional_Field__c != null
            ORDER BY Name
            LIMIT :FEC_Constants.QUERY_LIMIT
        ];
        
        Map<Id, List<Map<String, Object>>> bpToProperties = new Map<Id, List<Map<String, Object>>>();
        for(FEC_MDM_Master_Data_Setting__c setting : allSettings) {
            Id bpId = setting.FEC_Nature_Of_Case__r.FEC_Business_Process_Name__c;
            if(!bpToProperties.containsKey(bpId)) {
                bpToProperties.put(bpId, new List<Map<String, Object>>());
            }
            String displayLabel = setting.FEC_Additional_Field__r != null ? setting.FEC_Additional_Field__r.Name : setting.Name;
            bpToProperties.get(bpId).add(new Map<String, Object>{
                FEC_Constants.MAP_LABEL => displayLabel,
                FEC_Constants.MAP_NAME => setting.Id,
                FEC_Constants.MAP_PROPERTY_REF => setting.Property_Reference__c,
                FEC_Constants.MAP_PARENT_NAME => bpMap.get(bpId).Name
             });
        }
        
        List<Map<String, Object>> treeData = new List<Map<String, Object>>();
        for(FEC_MDM_Business_Process__c bp : bpMap.values()) {
            List<Map<String, Object>> children = bpToProperties.containsKey(bp.Id)
                ? bpToProperties.get(bp.Id)
                : new List<Map<String, Object>>();
            treeData.add(new Map<String, Object>{
                FEC_Constants.MAP_LABEL => bp.Name,
                FEC_Constants.MAP_NAME => bp.Id,
                FEC_Constants.MAP_EXPANDED => false,
                FEC_Constants.MAP_ITEMS => children
             });
        }
        System.debug(FEC_Constants.DEBUG_SERVICE_TYPE_TREE_PREFIX + treeData);
        return treeData;
    }
    
    @AuraEnabled
    public static void savePropertyMapping(Id settingId, String newRef) {
        if (settingId == null) throw new AuraHandledException(FEC_Constants.ERROR_INVALID_ID);
         try {
             update new FEC_MDM_Master_Data_Setting__c(
                 Id = settingId,
             Property_Reference__c = newRef
                 );
         } catch (Exception e) {
             System.debug('FEC_FecServiceTypeMappingController.savePropertyMapping error: ' + e);
            throw new AuraHandledException(FEC_Constants.ERROR_SYSTEM);
         }
     }
 }
