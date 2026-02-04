public class FEC_SyncMasterDataBatch implements Database.Batchable<String>, Database.Stateful {
    
    private List<String> executionOrder = new List<String>{
        'FEC_MDM_Product_Type__c',
        'FEC_MDM_Business_Process__c',
        'FEC_MDM_Category__c',
        'FEC_MDM_Sub_Category__c',
        'FEC_MDM_Sub_Code__c',
        'FEC_MDM_Channel__c',
        'FEC_MDM_Master_Data_Setting__c',
        'FEC_MDM_Case_Stage__c',
        'FEC_MDM_Additional_Field__c',
        'FEC_MDM_Additional_Field_List_Value__c',
        'FEC_MDM_Nature_Of_Case__c'
    };
    
    private Map<String, String> mdmToOriginalMap = new Map<String, String>{
        'FEC_MDM_Product_Type__c'   => 'FEC_Product_Type__c',
        'FEC_MDM_Business_Process__c' => 'FEC_Business_Process__c',
        'FEC_MDM_Category__c'       => 'FEC_Category__c',
        'FEC_MDM_Sub_Category__c'   => 'FEC_Sub_Category__c',
        'FEC_MDM_Sub_Code__c'       => 'FEC_Sub_Code__c',
        'FEC_MDM_Channel__c'        => 'FEC_Channel__c',
        'FEC_MDM_Master_Data_Setting__c' => 'FEC_Master_Data_Setting__c',
        'FEC_MDM_Case_Stage__c'     => 'FEC_Case_Stage__c',
        'FEC_MDM_Additional_Field__c'    => 'FEC_Additional_Field__c',
        'FEC_MDM_Additional_Field_List_Value__c' => 'FEC_Additional_Field_List_Value__c',
        'FEC_MDM_Nature_Of_Case__c' => 'FEC_Nature_Of_Case__c'
    };
    
    private Map<String, String> commonFieldMap = new Map<String, String>{
        //Common Fields
        'Name'           => 'Name',
        'ExternalID__c'  => 'ExternalID__c',
        //Additional Field Fields
        'FEC_Unique_ID__c'  => 'FEC_Unique_ID__c',
        'FEC_Type__c'  => 'FEC_Type__c',
        'FEC_Field_Mandatory__c'  => 'FEC_Field_Mandatory__c',
        'FEC_Field_Status__c'  => 'FEC_Field_Status__c',
        //Additional Field Fields List Value
        'FEC_Order__c'  => 'FEC_Order__c',
        //Channel Fields
        'FEC_Channel_ID__c'  => 'FEC_Channel_ID__c',
        'FEC_Channel_Status__c'  => 'FEC_Channel_Status__c',
        'FEC_Channel_Vietnamese_name__c'  => 'FEC_Channel_Vietnamese_name__c',
        //FEC_MDM_Master_Data_Setting__c Fields
        'FEC_Applicable_Role__c'  => 'FEC_Applicable_Role__c',
        'FEC_Field_Mandatory__c'  => 'FEC_Field_Mandatory__c',
        'FEC_Field_Object_Name__c'  => 'FEC_Field_Object_Name__c',
        'FEC_Field_Order_Display__c'  => 'FEC_Field_Order_Display__c',
        'FEC_Field_ReadOnly__c'  => 'FEC_Field_ReadOnly__c',
        'FEC_Field_Status__c'  => 'FEC_Field_Status__c',
        'Property_Reference__c'  => 'Property_Reference__c',
        'FEC_Section__c'  => 'FEC_Section__c',
        'FEC_Channel__c'  => 'FEC_Channel__c',
        'FEC_Data_Integration_Mapping__c'  => 'FEC_Data_Integration_Mapping__c',
        //NOC Lookup Fields
        'FEC_Alias__c'   => 'FEC_Alias__c',
        'FEC_Code__c'    => 'FEC_Code__c',
        'FEC_Name_VN__c' => 'FEC_Name_VN__c',
        'FEC_Pos_Order__c' => 'FEC_Pos_Order__c',
        'FEC_Status__c'  => 'FEC_Status__c'
    };
    
    public Iterable<String> start(Database.BatchableContext bc) {
        return executionOrder;
    }
    
    public void execute(Database.BatchableContext bc, List<String> scope) {
        for (String mdmObjName : scope) {
            String targetObjName = mdmToOriginalMap.get(mdmObjName);
            
            // 1. Lấy danh sách MDM đang chờ Reset (Status = New hoặc Update)
            String mdmQuery = 'SELECT Id, ExternalID__c, Process_Change_Status__c FROM ' + mdmObjName +
                ' WHERE Process_Change_Status__c IN (\'New\', \'Update\')';
            List<SObject> mdmList = Database.query(mdmQuery);
            if (mdmList.isEmpty()) continue;
            
            // Phân loại list
            List<SObject> listToDelete = new List<SObject>();
            Map<String, SObject> mdmToUpdateMap = new Map<String, SObject>();
            for (SObject m : mdmList) {
                if ((String)m.get('Process_Change_Status__c') == 'New') listToDelete.add(m);
                else mdmToUpdateMap.put((String)m.get('ExternalID__c'), m);
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
                    when 'FEC_MDM_Nature_Of_Case__c' {
                        queryFieldsSet.add('FEC_Product_Type_Name__r.ExternalID__c');
                        queryFieldsSet.add('FEC_Business_Process_Name__r.ExternalID__c');
                        queryFieldsSet.add('FEC_Category_Name__r.ExternalID__c');
                        queryFieldsSet.add('FEC_Sub_Category_Name__r.ExternalID__c');
                        queryFieldsSet.add('FEC_Sub_Code__r.ExternalID__c');
                    }
                    when 'FEC_MDM_Case_Stage__c' {
                        queryFieldsSet.add('FEC_Business_Process__r.ExternalID__c');
                    }
                    when 'FEC_MDM_Master_Data_Setting__c' {
                        // queryFieldsSet.add('FEC_Channel__r.ExternalID__c');
                        queryFieldsSet.add('FEC_Nature_Of_Case__r.ExternalID__c');
                        queryFieldsSet.add('FEC_Additional_Field__r.ExternalID__c');
                        queryFieldsSet.add('FEC_Stage_Name__r.ExternalID__c');
                    }
                    when 'FEC_MDM_Additional_Field_List_Value__c' {
                        queryFieldsSet.add('FEC_Additional_Field__r.ExternalID__c');
                    }
                }
                String liveQuery = 'SELECT ' + String.join(new List<String>(queryFieldsSet), ', ') +
                    ' FROM ' + targetObjName +
                    ' WHERE ExternalID__c IN :mdmIds'; // Dùng biến bind để an toàn hơn
                
                Set<String> mdmIds = mdmToUpdateMap.keySet();
                List<SObject> liveRecords = Database.query(liveQuery);
                
                List<SObject> mdmToUpdate = new List<SObject>();
                
                for (SObject live : liveRecords) {
                    SObject mdm = mdmToUpdateMap.get((String)live.get('ExternalID__c'));
                    mdm.put('Process_Change_Status__c', 'Synced');
                    
                    // Mapping trường chung
                    copyFieldsToMDM(mdm, live, mdmFields);
                    
                    // Mapping Lookup đặc thù (Revert)
                    switch on mdmObjName {
                        when 'FEC_MDM_Nature_Of_Case__c' {
                            revertLookup(mdm, live, 'FEC_Product_Type_Name__r', 'FEC_MDM_Product_Type__c');
                            revertLookup(mdm, live, 'FEC_Business_Process__r', 'FEC_MDM_Business_Process__c');
                            revertLookup(mdm, live, 'FEC_Category__r', 'FEC_MDM_Category__c');
                            revertLookup(mdm, live, 'FEC_Sub_Category__r', 'FEC_MDM_Sub_Category__c');
                            revertLookup(mdm, live, 'FEC_Sub_Code__r', 'FEC_MDM_Sub_Code__c');
                        }
                        when 'FEC_MDM_Case_Stage__c' {
                            revertLookup(mdm, live, 'FEC_Business_Process__r', 'FEC_MDM_Business_Process__c');
                        }
                        when 'FEC_MDM_Master_Data_Setting__c' {
                            revertLookup(mdm, live, 'FEC_Nature_Of_Case__r', 'FEC_MDM_Nature_Of_Case__c');
                            revertLookup(mdm, live, 'FEC_Additional_Field__r', 'FEC_MDM_Additional_Field__c');
                            revertLookup(mdm, live, 'FEC_Stage_Name__r', 'FEC_MDM_Case_Stage__c');
                        }
                        when 'FEC_MDM_Additional_Field_List_Value__c' {
                            revertLookup(mdm, live, 'FEC_Additional_Field__r', 'FEC_MDM_Additional_Field__c');
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
                String extId = (String)parentLive.get('ExternalID__c');
                if (String.isNotBlank(extId)) {
                    SObject parentMdmRef = Schema.getGlobalDescribe().get(parentMdmObjName).newSObject();
                    parentMdmRef.put('ExternalID__c', extId);
                    mdm.putSObject(relName, parentMdmRef);
                }
            }
        } catch(Exception e) { }
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('>>> MDM Reset Sync Completed.');
    }
}
