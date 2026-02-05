public class FEC_PushMDMToLiveBatch implements Database.Batchable<String>, Database.Stateful {
    
    private Set<String> uniqueErrors = new Set<String>();
    
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
        FEC_Constants.OBJ_MDM_CASE_STAGE     => FEC_Constants.OBJ_CASE_STAGE,
        FEC_Constants.OBJ_MDM_NATURE_OF_CASE => FEC_Constants.OBJ_NATURE_OF_CASE,
        FEC_Constants.OBJ_MDM_CHANNEL        => FEC_Constants.OBJ_MDM_CHANNEL,
        FEC_Constants.OBJ_MDM_MASTER_DATA_SETTING => FEC_Constants.OBJ_MASTER_DATA_SETTING,
        FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD    => FEC_Constants.OBJ_ADDITIONAL_FIELD,
        FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE => FEC_Constants.OBJ_ADDITIONAL_FIELD_LIST_VALUE
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
                when FEC_Constants.OBJ_MDM_NATURE_OF_CASE {
                    query += ', FEC_Product_Type_Name__r.ExternalID__c, ' +
                        'FEC_Business_Process_Name__r.ExternalID__c, ' +
                        'FEC_Category_Name__r.ExternalID__c, ' +
                        'FEC_Sub_Category_Name__r.ExternalID__c, ' +
                        'FEC_Sub_Code__r.ExternalID__c';
                }
                when FEC_Constants.OBJ_MDM_MASTER_DATA_SETTING {
                    query += ', FEC_Nature_Of_Case__r.ExternalID__c, ' +
                    'FEC_Additional_Field__r.ExternalID__c, ' +
                        'FEC_Stage_Name__r.ExternalID__c';
                }
                when FEC_Constants.OBJ_MDM_CASE_STAGE {
                    query += ', FEC_Business_Process__r.ExternalID__c';
                }
                when FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE {
                    query += ', FEC_Additional_Field__r.ExternalID__c';
                }
            }
            query += ' FROM ' + mdmObjName + ' WHERE ' + FEC_Constants.FIELD_PROCESS_CHANGE_STATUS + ' != \'" + FEC_Constants.PROCESS_STATUS_SYNCED + "\'';
            
            List<SObject> mdmRecords = Database.query(query);
            if (mdmRecords.isEmpty()) continue;
            
            List<SObject> targetList = new List<SObject>();
            
            // --- BƯỚC 3: MAPPING DÙNG SWITCH ON ---
            for (SObject mdm : mdmRecords) {
                SObject target = Schema.getGlobalDescribe().get(targetObjName).newSObject();
                target.put(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS, FEC_Constants.PROCESS_STATUS_SYNCED);
                
                switch on mdmObjName {
                    when FEC_Constants.OBJ_MDM_MASTER_DATA_SETTING {
                        copyValidFields(target, mdm, validFieldsForThisObj, fieldMap);
                        setLookup(target, mdm, FEC_Constants.REL_NATURE_OF_CASE, FEC_Constants.OBJ_NATURE_OF_CASE);
                        setLookup(target, mdm, FEC_Constants.REL_ADDITIONAL_FIELD, FEC_Constants.OBJ_ADDITIONAL_FIELD);
                        setLookup(target, mdm, FEC_Constants.REL_STAGE_NAME, FEC_Constants.OBJ_CASE_STAGE);
                    }
                    when FEC_Constants.OBJ_MDM_NATURE_OF_CASE {
                        copyValidFields(target, mdm, validFieldsForThisObj, fieldMap);
                        setLookup(target, mdm, FEC_Constants.REL_PRODUCT_TYPE_NAME, FEC_Constants.OBJ_PRODUCT_TYPE);
                        setLookup(target, mdm, FEC_Constants.REL_BUSINESS_PROCESS_NAME, FEC_Constants.OBJ_BUSINESS_PROCESS);
                        setLookup(target, mdm, FEC_Constants.REL_CATEGORY_NAME, FEC_Constants.OBJ_CATEGORY);
                        setLookup(target, mdm, FEC_Constants.REL_SUB_CATEGORY_NAME, FEC_Constants.OBJ_SUB_CATEGORY);
                        setLookup(target, mdm, FEC_Constants.REL_SUB_CODE_NAME, FEC_Constants.OBJ_SUB_CODE);
                    }
                    when FEC_Constants.OBJ_MDM_CASE_STAGE {
                        copyValidFields(target, mdm, validFieldsForThisObj, fieldMap);
                        setLookup(target, mdm, FEC_Constants.REL_BUSINESS_PROCESS_NAME.replace('_Name__r','__r'), FEC_Constants.OBJ_BUSINESS_PROCESS);
                    }
                    when FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE {
                        copyValidFields(target, mdm, validFieldsForThisObj, fieldMap);
                        setLookup(target, mdm, FEC_Constants.REL_ADDITIONAL_FIELD, FEC_Constants.OBJ_ADDITIONAL_FIELD);
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
                Schema.SObjectField extIdField = Schema.getGlobalDescribe().get(targetObjName).getDescribe().fields.getMap().get(FEC_Constants.FIELD_EXTERNAL_ID);
                Database.UpsertResult[] results = Database.upsert(targetList, extIdField, false);
                
                List<SObject> mdmToUpdate = new List<SObject>();
                for (Integer i = 0; i < results.size(); i++) {
                    if (results[i].isSuccess()) {
                        mdmRecords[i].put(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS, FEC_Constants.PROCESS_STATUS_SYNCED);
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
                String extId = (String)parentMDM.get(FEC_Constants.FIELD_EXTERNAL_ID);
                if (String.isNotBlank(extId)) {
                    SObject parentLive = Schema.getGlobalDescribe().get(parentObjName).newSObject();
                    parentLive.put(FEC_Constants.FIELD_EXTERNAL_ID, extId);
                    target.putSObject(relName, parentLive);
                }
            }
        } catch(Exception e) {
            uniqueErrors.add(FEC_Constants.ERROR_LOOKUP_PREFIX + relName + ': ' + e.getMessage());
        }
    }
    
    private void copyCommonFields(SObject target, SObject mdm, String targetObjName) {
        for (String f : commonFieldMap.keySet()) {
            try {
                // Chỉ gán nếu trường đó tồn tại trên bản ghi MDM vừa query được
                target.put(commonFieldMap.get(f), mdm.get(f));
            } catch(Exception ex) {
                uniqueErrors.add(FEC_Constants.ERROR_COMMON_FIELD_PREFIX + f + ': ' + ex.getMessage());
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
                        uniqueErrors.add(FEC_Constants.ERROR_DATA_PREFIX + mdmField + ' - ' + ex.getMessage());
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
            throw new FEC_BatchException(FEC_Constants.ERROR_SYNC_FAILED_PREFIX + allErrors);
        }
    }
}
