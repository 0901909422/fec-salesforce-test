public class FEC_SyncMasterDataBatch implements Database.Batchable<String>, Database.Stateful {
    
    private List<String> executionOrder = new List<String>{
        FEC_Constants.OBJ_MDM_PRODUCT_TYPE,
        FEC_Constants.OBJ_MDM_BUSINESS_PROCESS,
        FEC_Constants.OBJ_MDM_CATEGORY,
        FEC_Constants.OBJ_MDM_SUB_CATEGORY,
        FEC_Constants.OBJ_MDM_SUB_CODE,
        FEC_Constants.OBJ_MDM_CHANNEL,
        FEC_Constants.OBJ_MDM_MASTER_DATA_SETTING,
        FEC_Constants.OBJ_MDM_CASE_STAGE,
        FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD,
        FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE,
        FEC_Constants.OBJ_MDM_NATURE_OF_CASE
    };
    
    private Map<String, String> mdmToOriginalMap = new Map<String, String>{
        FEC_Constants.OBJ_MDM_PRODUCT_TYPE   => FEC_Constants.OBJ_PRODUCT_TYPE,
        FEC_Constants.OBJ_MDM_BUSINESS_PROCESS => FEC_Constants.OBJ_BUSINESS_PROCESS,
        FEC_Constants.OBJ_MDM_CATEGORY       => FEC_Constants.OBJ_CATEGORY,
        FEC_Constants.OBJ_MDM_SUB_CATEGORY   => FEC_Constants.OBJ_SUB_CATEGORY,
        FEC_Constants.OBJ_MDM_SUB_CODE       => FEC_Constants.OBJ_SUB_CODE,
        FEC_Constants.OBJ_MDM_CHANNEL        => FEC_Constants.OBJ_MDM_CHANNEL,
        FEC_Constants.OBJ_MDM_MASTER_DATA_SETTING => FEC_Constants.OBJ_MASTER_DATA_SETTING,
        FEC_Constants.OBJ_MDM_CASE_STAGE     => FEC_Constants.OBJ_CASE_STAGE,
        FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD    => FEC_Constants.OBJ_ADDITIONAL_FIELD,
        FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE => FEC_Constants.OBJ_ADDITIONAL_FIELD_LIST_VALUE,
        FEC_Constants.OBJ_MDM_NATURE_OF_CASE => FEC_Constants.OBJ_NATURE_OF_CASE
    };
    
    private Map<String, String> commonFieldMap = new Map<String, String>{
        //Common Fields
        FEC_Constants.FIELD_NAME => FEC_Constants.FIELD_NAME,
        FEC_Constants.FIELD_EXTERNAL_ID => FEC_Constants.FIELD_EXTERNAL_ID,
        //Additional Field Fields
        FEC_Constants.FIELD_FEC_UNIQUE_ID => FEC_Constants.FIELD_FEC_UNIQUE_ID,
        FEC_Constants.FIELD_FEC_TYPE => FEC_Constants.FIELD_FEC_TYPE,
        FEC_Constants.FIELD_FIELD_MANDATORY => FEC_Constants.FIELD_FIELD_MANDATORY,
        FEC_Constants.FIELD_FIELD_STATUS => FEC_Constants.FIELD_FIELD_STATUS,
        //Additional Field Fields List Value
        FEC_Constants.FIELD_FEC_ORDER => FEC_Constants.FIELD_FEC_ORDER,
        //Channel Fields
        FEC_Constants.FIELD_CHANNEL_ID => FEC_Constants.FIELD_CHANNEL_ID,
        FEC_Constants.FIELD_CHANNEL_STATUS => FEC_Constants.FIELD_CHANNEL_STATUS,
        FEC_Constants.FIELD_CHANNEL_VI_NAME => FEC_Constants.FIELD_CHANNEL_VI_NAME,
        //FEC_MDM_Master_Data_Setting__c Fields
        FEC_Constants.FIELD_APPLICABLE_ROLE => FEC_Constants.FIELD_APPLICABLE_ROLE,
        FEC_Constants.FIELD_FIELD_MANDATORY => FEC_Constants.FIELD_FIELD_MANDATORY,
        FEC_Constants.FIELD_FIELD_OBJECT_NAME => FEC_Constants.FIELD_FIELD_OBJECT_NAME,
        FEC_Constants.FIELD_FIELD_ORDER_DISPLAY => FEC_Constants.FIELD_FIELD_ORDER_DISPLAY,
        FEC_Constants.FIELD_FIELD_READONLY => FEC_Constants.FIELD_FIELD_READONLY,
        FEC_Constants.FIELD_FIELD_STATUS => FEC_Constants.FIELD_FIELD_STATUS,
        FEC_Constants.FIELD_PROPERTY_REFERENCE => FEC_Constants.FIELD_PROPERTY_REFERENCE,
        FEC_Constants.FIELD_SECTION => FEC_Constants.FIELD_SECTION,
        FEC_Constants.FIELD_CHANNEL => FEC_Constants.FIELD_CHANNEL,
        FEC_Constants.FIELD_DATA_INTEGRATION_MAPPING => FEC_Constants.FIELD_DATA_INTEGRATION_MAPPING,
        //NOC Lookup Fields
        FEC_Constants.FIELD_ALIAS => FEC_Constants.FIELD_ALIAS,
        FEC_Constants.FIELD_CODE => FEC_Constants.FIELD_CODE,
        FEC_Constants.FIELD_NAME_VN => FEC_Constants.FIELD_NAME_VN,
        FEC_Constants.FIELD_POS_ORDER => FEC_Constants.FIELD_POS_ORDER,
        FEC_Constants.FIELD_STATUS => FEC_Constants.FIELD_STATUS
    };
    
    public Iterable<String> start(Database.BatchableContext bc) {
        return executionOrder;
    }
    
    public void execute(Database.BatchableContext bc, List<String> scope) {
        for (String mdmObjName : scope) {
            String targetObjName = mdmToOriginalMap.get(mdmObjName);
            
            // 1. Lấy danh sách MDM đang chờ Reset (Status = New hoặc Update)
            String mdmQuery = 'SELECT Id, ' + FEC_Constants.FIELD_EXTERNAL_ID + ', ' + FEC_Constants.FIELD_PROCESS_CHANGE_STATUS + ' FROM ' + mdmObjName +
                ' WHERE ' + FEC_Constants.FIELD_PROCESS_CHANGE_STATUS + ' IN (\'' + FEC_Constants.PROCESS_STATUS_NEW + '\', \'' + FEC_Constants.PROCESS_STATUS_UPDATE + '\')';
            List<SObject> mdmList = Database.query(mdmQuery);
            if (mdmList.isEmpty()) continue;
            
            // Phân loại list
            List<SObject> listToDelete = new List<SObject>();
            Map<String, SObject> mdmToUpdateMap = new Map<String, SObject>();
            for (SObject m : mdmList) {
                if ((String)m.get(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS) == FEC_Constants.PROCESS_STATUS_NEW) listToDelete.add(m);
                else mdmToUpdateMap.put((String)m.get(FEC_Constants.FIELD_EXTERNAL_ID), m);
            }
            
            // 2. Xử lý XÓA bản ghi New
            if (!listToDelete.isEmpty()) delete listToDelete;
            
            // 3. Xử lý CẬP NHẬT bản ghi Update từ Live về MDM
            if (!mdmToUpdateMap.isEmpty()) {
                // Kiểm tra Schema MDM để build query Live an toàn
                Map<String, Schema.SObjectField> mdmFields = Schema.getGlobalDescribe().get(mdmObjName).getDescribe().fields.getMap();
                Set<String> queryFieldsSet = new Set<String>();
                for(String mdmF : commonFieldMap.keySet()) {
                    if(mdmFields.containsKey(mdmF)) queryFieldsSet.add(commonFieldMap.get(mdmF));
                }
                
                switch on mdmObjName {
                    when FEC_Constants.OBJ_MDM_NATURE_OF_CASE {
                        queryFieldsSet.add(FEC_Constants.REL_PRODUCT_TYPE_NAME + '.' + FEC_Constants.FIELD_EXTERNAL_ID);
                        queryFieldsSet.add(FEC_Constants.REL_BUSINESS_PROCESS_NAME + '.' + FEC_Constants.FIELD_EXTERNAL_ID);
                        queryFieldsSet.add(FEC_Constants.REL_CATEGORY_NAME + '.' + FEC_Constants.FIELD_EXTERNAL_ID);
                        queryFieldsSet.add(FEC_Constants.REL_SUB_CATEGORY_NAME + '.' + FEC_Constants.FIELD_EXTERNAL_ID);
                        queryFieldsSet.add(FEC_Constants.REL_SUB_CODE_NAME + '.' + FEC_Constants.FIELD_EXTERNAL_ID);
                    }
                    when FEC_Constants.OBJ_MDM_CASE_STAGE {
                        queryFieldsSet.add('FEC_Business_Process__r.' + FEC_Constants.FIELD_EXTERNAL_ID);
                    }
                    when FEC_Constants.OBJ_MDM_MASTER_DATA_SETTING {
                        // queryFieldsSet.add('FEC_Channel__r.ExternalID__c');
                        queryFieldsSet.add(FEC_Constants.REL_NATURE_OF_CASE + '.' + FEC_Constants.FIELD_EXTERNAL_ID);
                        queryFieldsSet.add(FEC_Constants.REL_ADDITIONAL_FIELD + '.' + FEC_Constants.FIELD_EXTERNAL_ID);
                        queryFieldsSet.add(FEC_Constants.REL_STAGE_NAME + '.' + FEC_Constants.FIELD_EXTERNAL_ID);
                    }
                    when FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE {
                        queryFieldsSet.add(FEC_Constants.REL_ADDITIONAL_FIELD + '.' + FEC_Constants.FIELD_EXTERNAL_ID);
                    }
                }
                String liveQuery = 'SELECT ' + String.join(new List<String>(queryFieldsSet), ', ') +
                    ' FROM ' + targetObjName +
                    ' WHERE ' + FEC_Constants.FIELD_EXTERNAL_ID + ' IN :mdmIds'; // Dùng biến bind để an toàn hơn
                
                Set<String> mdmIds = mdmToUpdateMap.keySet();
                List<SObject> liveRecords = Database.query(liveQuery);
                
                List<SObject> mdmToUpdate = new List<SObject>();
                
                for (SObject live : liveRecords) {
                    SObject mdm = mdmToUpdateMap.get((String)live.get(FEC_Constants.FIELD_EXTERNAL_ID));
                    mdm.put(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS, FEC_Constants.PROCESS_STATUS_SYNCED);
                    
                    // Mapping trường chung
                    copyFieldsToMDM(mdm, live, mdmFields);
                    
                    // Mapping Lookup đặc thù (Revert)
                    switch on mdmObjName {
                        when FEC_Constants.OBJ_MDM_NATURE_OF_CASE {
                            revertLookup(mdm, live, FEC_Constants.REL_PRODUCT_TYPE_NAME, FEC_Constants.OBJ_MDM_PRODUCT_TYPE);
                            revertLookup(mdm, live, FEC_Constants.REL_BUSINESS_PROCESS_NAME, FEC_Constants.OBJ_MDM_BUSINESS_PROCESS);
                            revertLookup(mdm, live, FEC_Constants.REL_CATEGORY_NAME, FEC_Constants.OBJ_MDM_CATEGORY);
                            revertLookup(mdm, live, FEC_Constants.REL_SUB_CATEGORY_NAME, FEC_Constants.OBJ_MDM_SUB_CATEGORY);
                            revertLookup(mdm, live, FEC_Constants.REL_SUB_CODE_NAME, FEC_Constants.OBJ_MDM_SUB_CODE);
                        }
                        when FEC_Constants.OBJ_MDM_CASE_STAGE {
                            revertLookup(mdm, live, FEC_Constants.REL_BUSINESS_PROCESS_NAME.replace('_Name__r','__r'), FEC_Constants.OBJ_MDM_BUSINESS_PROCESS);
                        }
                        when FEC_Constants.OBJ_MDM_MASTER_DATA_SETTING {
                            revertLookup(mdm, live, FEC_Constants.REL_NATURE_OF_CASE, FEC_Constants.OBJ_MDM_NATURE_OF_CASE);
                            revertLookup(mdm, live, FEC_Constants.REL_ADDITIONAL_FIELD, FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD);
                            revertLookup(mdm, live, FEC_Constants.REL_STAGE_NAME, FEC_Constants.OBJ_MDM_CASE_STAGE);
                        }
                        when FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE {
                            revertLookup(mdm, live, FEC_Constants.REL_ADDITIONAL_FIELD, FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD);
                        }
                     }
                     mdmToUpdate.add(mdm);
                 }
                
                if (!mdmToUpdate.isEmpty()) {
                    FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
                    update mdmToUpdate;
                    FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
                }
            }
        }
    }
    
    private void copyFieldsToMDM(SObject mdm, SObject live, Map<String, Schema.SObjectField> mdmFields) {
        for (String mdmF : commonFieldMap.keySet()) {
            String liveF = commonFieldMap.get(mdmF);
            // Kiểm tra MDM có field đó và có quyền Edit không (tránh lỗi Auto-number trên MDM nếu có)
            if (mdmFields.containsKey(mdmF) && mdmFields.get(mdmF).getDescribe().isUpdateable()) {
                try {
                    mdm.put(mdmF, live.get(liveF));
                } catch(Exception e) { }
            }
        }
    }
    
    private void revertLookup(SObject mdm, SObject live, String relName, String parentMdmObjName) {
        try {
            SObject parentLive = live.getSObject(relName);
            if (parentLive != null) {
                String extId = (String)parentLive.get(FEC_Constants.FIELD_EXTERNAL_ID);
                if (String.isNotBlank(extId)) {
                    SObject parentMdmRef = Schema.getGlobalDescribe().get(parentMdmObjName).newSObject();
                    parentMdmRef.put(FEC_Constants.FIELD_EXTERNAL_ID, extId);
                    mdm.putSObject(relName, parentMdmRef);
                }
            }
        } catch(Exception e) { }
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('>>> MDM Reset Sync Completed.');
    }
}
