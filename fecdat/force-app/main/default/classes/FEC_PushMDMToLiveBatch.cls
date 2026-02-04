public class FEC_PushMDMToLiveBatch implements Database.Batchable<String>, Database.Stateful {
    
    private Set<String> uniqueErrors = new Set<String>();
    
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
        'FEC_MDM_Case_Stage__c'     => 'FEC_Case_Stage__c',
        'FEC_MDM_Nature_Of_Case__c' => 'FEC_Nature_Of_Case__c',
        'FEC_MDM_Channel__c'        => 'FEC_Channel__c',
        'FEC_MDM_Master_Data_Setting__c' => 'FEC_Master_Data_Setting__c',
        'FEC_MDM_Additional_Field__c'    => 'FEC_Additional_Field__c',
        'FEC_MDM_Additional_Field_List_Value__c' => 'FEC_Additional_Field_List_Value__c'
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
            
            // --- BƯỚC 1: LẤY DANH SÁCH TRƯỜNG THỰC TẾ TỒN TẠI TRÊN MDM ---
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(mdmObjName).getDescribe().fields.getMap();
            List<String> validFieldsForThisObj = new List<String>();
            for(String f : commonFieldMap.keySet()) {
                if(fieldMap.containsKey(f)) validFieldsForThisObj.add(f);
            }
            
            String queryFields = String.join(validFieldsForThisObj, ',');
            String query = 'SELECT ' + queryFields;
            
            // --- BƯỚC 2: XÂY DỰNG QUERY DÙNG SWITCH ON ---
            // String query = '';
            switch on mdmObjName {
                when 'FEC_MDM_Nature_Of_Case__c' {
                    query += ', FEC_Product_Type_Name__r.ExternalID__c, ' +
                        'FEC_Business_Process_Name__r.ExternalID__c, ' +
                        'FEC_Category_Name__r.ExternalID__c, ' +
                        'FEC_Sub_Category_Name__r.ExternalID__c, ' +
                        'FEC_Sub_Code__r.ExternalID__c';
                }
                when 'FEC_MDM_Master_Data_Setting__c' {
                    query += ', FEC_Nature_Of_Case__r.ExternalID__c, ' +
                        // 'FEC_Data_Integration_Mapping__r.ExternalID__c, ' +
                    // 'FEC_Nature_Of_Case__r.ExternalID__c, ' +
                    'FEC_Additional_Field__r.ExternalID__c, ' +
                        'FEC_Stage_Name__r.ExternalID__c';
                }
                when 'FEC_MDM_Case_Stage__c' {
                    query += ', FEC_Business_Process__r.ExternalID__c';
                }
                when 'FEC_MDM_Additional_Field_List_Value__c' {
                    query += ', FEC_Additional_Field__r.ExternalID__c';
                }
            }
            query += ' FROM ' + mdmObjName + ' WHERE Process_Change_Status__c != \'Synced\'';
            
            List<SObject> mdmRecords = Database.query(query);
            if (mdmRecords.isEmpty()) continue;
            
            List<SObject> targetList = new List<SObject>();
            
            // --- BƯỚC 3: MAPPING DÙNG SWITCH ON ---
            for (SObject mdm : mdmRecords) {
                SObject target = Schema.getGlobalDescribe().get(targetObjName).newSObject();
                target.put('Process_Change_Status__c', 'Synced');
                
                switch on mdmObjName {
                    when 'FEC_MDM_Master_Data_Setting__c' {
                        copyValidFields(target, mdm, validFieldsForThisObj, fieldMap);
                        setLookup(target, mdm, 'FEC_Nature_Of_Case__r', 'FEC_Nature_Of_Case__c');
                        setLookup(target, mdm, 'FEC_Additional_Field__r', 'FEC_Additional_Field__c');
                        setLookup(target, mdm, 'FEC_Stage_Name__r', 'FEC_Case_Stage__c');
                    }
                    when 'FEC_MDM_Nature_Of_Case__c' {
                        copyValidFields(target, mdm, validFieldsForThisObj, fieldMap);
                        setLookup(target, mdm, 'FEC_Product_Type_Name__r', 'FEC_Product_Type__c');
                        setLookup(target, mdm, 'FEC_Business_Process_Name__r', 'FEC_Business_Process__c');
                        setLookup(target, mdm, 'FEC_Category_Name__r', 'FEC_Category__c');
                        setLookup(target, mdm, 'FEC_Sub_Category_Name__r', 'FEC_Sub_Category__c');
                        setLookup(target, mdm, 'FEC_Sub_Code__r', 'FEC_Sub_Code__c');
                    }
                    when 'FEC_MDM_Case_Stage__c' {
                        copyValidFields(target, mdm, validFieldsForThisObj, fieldMap);
                        setLookup(target, mdm, 'FEC_Business_Process__r', 'FEC_Business_Process__c');
                    }
                    when 'FEC_MDM_Additional_Field_List_Value__c' {
                        copyValidFields(target, mdm, validFieldsForThisObj, fieldMap);
                        setLookup(target, mdm, 'FEC_Additional_Field__r', 'FEC_Additional_Field__c');
                    }
                    when else {
                        copyValidFields(target, mdm, validFieldsForThisObj, fieldMap);
                    }
                }
                targetList.add(target);
            }
            
            // --- BƯỚC 4: UPSERT ---
            if (!targetList.isEmpty()) {
                FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
                Schema.SObjectField extIdField = Schema.getGlobalDescribe().get(targetObjName).getDescribe().fields.getMap().get('ExternalID__c');
                Database.UpsertResult[] results = Database.upsert(targetList, extIdField, false);
                
                List<SObject> mdmToUpdate = new List<SObject>();
                for (Integer i = 0; i < results.size(); i++) {
                    if (results[i].isSuccess()) {
                        mdmRecords[i].put('Process_Change_Status__c', 'Synced');
                        mdmToUpdate.add(mdmRecords[i]);
                    } else {
                        uniqueErrors.add('[' + targetObjName + '] Upsert Error: ' + results[i].getErrors()[0].getMessage());
                    }
                }
                if (!mdmToUpdate.isEmpty()) update mdmToUpdate;
                FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
            }
        }
    }
    
    private void setLookup(SObject target, SObject mdm, String relName, String parentObjName) {
        try {
            SObject parentMDM = mdm.getSObject(relName);
            if (parentMDM != null) {
                String extId = (String)parentMDM.get('ExternalID__c');
                if (String.isNotBlank(extId)) {
                    SObject parentLive = Schema.getGlobalDescribe().get(parentObjName).newSObject();
                    parentLive.put('ExternalID__c', extId);
                    target.putSObject(relName, parentLive);
                }
            }
        } catch(Exception e) {
            uniqueErrors.add('Lookup Error ' + target + ' ' + mdm + ' ' + relName + ': ' + e.getMessage());
        }
    }
    
    private void copyCommonFields(SObject target, SObject mdm, String targetObjName) {
        for (String f : commonFieldMap.keySet()) {
            try {
                // Chỉ gán nếu trường đó tồn tại trên bản ghi MDM vừa query được
                target.put(commonFieldMap.get(f), mdm.get(f));
            } catch(Exception ex) {
                uniqueErrors.add('commonFieldMap Error ' + f + ': ' + ex.getMessage());
            }
        }
    }
    
    private void copyValidFields(SObject target, SObject mdm, List<String> validFields, Map<String, Schema.SObjectField> fieldMap) {
        for (String mdmField : validFields) {
            String targetField = commonFieldMap.get(mdmField);
            if (fieldMap.containsKey(targetField)) {
                // KIỂM TRA: Chỉ gán nếu trường cho phép edit (không phải Auto-number/Formula)
                if (fieldMap.get(targetField).getDescribe().isUpdateable()) {
                    try {
                        target.put(targetField, mdm.get(mdmField));
                    } catch(Exception ex) {
                        uniqueErrors.add('Data Error: ' + mdmField + ' - ' + ex.getMessage());
                    }
                }
            }
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed,
                        TotalJobItems, CreatedBy.Email
                        FROM AsyncApexJob WHERE Id = :bc.getJobId()];
        
        // 2. Tạo nội dung email
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] {job.CreatedBy.Email}); // Gửi về mail người thực hiện
        mail.setSubject('Kết quả Push MDM to Live: ' + job.Status);
        
        String body = 'Kết quả chạy Batch Push MDM To Live:\n' +
            '------------------------------------------\n' +
            'Trạng thái: ' + job.Status + '\n' +
            'Số lượng Batch Item: ' + job.JobItemsProcessed + '/' + job.TotalJobItems + '\n' +
            'Số lỗi kỹ thuật: ' + job.NumberOfErrors + '\n\n';
        
        if (!uniqueErrors.isEmpty()) {
            body += 'CHI TIẾT LỖI NGHIỆP VỤ:\n';
            body += String.join(new List<String>(uniqueErrors), '\n');
        } else {
            body += 'Chúc mừng! Không có lỗi nghiệp vụ nào xảy ra.';
        }
        
        mail.setPlainTextBody(body);
        
        
        // 3. Gửi mail
        if(!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
        
        if (!uniqueErrors.isEmpty()) {
            String allErrors = String.join(new List<String>(uniqueErrors), '\n');
            throw new FEC_BatchException('Sync Failed: \n' + allErrors);
        }
    }
}
