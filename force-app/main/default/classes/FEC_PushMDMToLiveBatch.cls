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
        // Assuming scope always contains exactly one value
        String mdmObjName = scope[0];
        String targetObjName = mdmToOriginalMap.get(mdmObjName);
        
        // --- BƯỚC 1: LẤY DANH SÁCH TRƯỜNG THỰC TẾ TỒN TẠI TRÊN MDM ---
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(mdmObjName).getDescribe().fields.getMap();
        List<String> validFieldsForThisObj = new List<String>();
        for (String f : commonFieldMap.keySet()) {
            if (fieldMap.containsKey(f)) validFieldsForThisObj.add(f);
        }
        
        String queryFields = String.join(validFieldsForThisObj, ',');
        String query = 'SELECT ' + queryFields;
        
        // --- BƯỚC 2: XÂY DỰNG QUERY DÙNG IF/ELSE ---
        if (mdmObjName == FEC_Constants.OBJ_MDM_NATURE_OF_CASE) {
            query += ', FEC_Product_Type_Name__r.FEC_Code__c, ' +
                'FEC_Business_Process_Name__r.FEC_Code__c, ' +
                'FEC_Category_Name__r.FEC_Code__c, ' +
                'FEC_Sub_Category_Name__r.FEC_Code__c, ' +
                'FEC_Sub_Code__r.FEC_Code__c';
        } else if (mdmObjName == FEC_Constants.OBJ_MDM_MASTER_DATA_SETTING) {
            query += ', FEC_Nature_Of_Case__r.FEC_Code__c, ' +
                'FEC_Additional_Field__r.FEC_Code__c, ' +
                'FEC_Stage_Name__r.FEC_Code__c';
        } else if (mdmObjName == FEC_Constants.OBJ_MDM_CASE_STAGE) {
            query += ', FEC_Business_Process__r.FEC_Code__c';
        } else if (mdmObjName == FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE) {
            query += ', FEC_Additional_Field__r.FEC_Code__c';
        }
        String statusLiteral = '\'' + String.escapeSingleQuotes(FEC_Constants.PROCESS_STATUS_SYNCED) + '\'';
        query += ' FROM ' + mdmObjName + ' WHERE ' + FEC_Constants.FIELD_PROCESS_CHANGE_STATUS + ' != ' + statusLiteral;
        
        // Prevent empty field list
        if (String.isBlank(queryFields)) return;
        List<SObject> mdmRecords = Database.query(query);
        if (mdmRecords.isEmpty()) return;
        
        List<SObject> targetList = new List<SObject>();
        
        // --- BƯỚC 3: MAPPING DÙNG IF/ELSE ---
        for (SObject mdm : mdmRecords) {
            SObject target = Schema.getGlobalDescribe().get(targetObjName).newSObject();
            target.put(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS, FEC_Constants.PROCESS_STATUS_SYNCED);
            
            if (mdmObjName == FEC_Constants.OBJ_MDM_MASTER_DATA_SETTING) {
                try {
                    FEC_BatchUtils.copyValidFields(target, mdm, validFieldsForThisObj, fieldMap, commonFieldMap, uniqueErrors);
                    FEC_BatchUtils.setLookup(target, mdm, FEC_Constants.REL_NATURE_OF_CASE, FEC_Constants.OBJ_NATURE_OF_CASE, uniqueErrors);
                    FEC_BatchUtils.setLookup(target, mdm, FEC_Constants.REL_ADDITIONAL_FIELD, FEC_Constants.OBJ_ADDITIONAL_FIELD, uniqueErrors);
                    FEC_BatchUtils.setLookup(target, mdm, FEC_Constants.REL_STAGE_NAME, FEC_Constants.OBJ_CASE_STAGE, uniqueErrors);
                } catch (Exception ex) {
                    uniqueErrors.add('[Mapping ' + mdmObjName + '] ' + ex.getMessage());
                    continue;
                }
            } else if (mdmObjName == FEC_Constants.OBJ_MDM_NATURE_OF_CASE) {
                try {
                    FEC_BatchUtils.copyValidFields(target, mdm, validFieldsForThisObj, fieldMap, commonFieldMap, uniqueErrors);
                    FEC_BatchUtils.setLookup(target, mdm, FEC_Constants.REL_PRODUCT_TYPE_NAME, FEC_Constants.OBJ_PRODUCT_TYPE, uniqueErrors);
                    FEC_BatchUtils.setLookup(target, mdm, FEC_Constants.REL_BUSINESS_PROCESS_NAME, FEC_Constants.OBJ_BUSINESS_PROCESS, uniqueErrors);
                    FEC_BatchUtils.setLookup(target, mdm, FEC_Constants.REL_CATEGORY_NAME, FEC_Constants.OBJ_CATEGORY, uniqueErrors);
                    FEC_BatchUtils.setLookup(target, mdm, FEC_Constants.REL_SUB_CATEGORY_NAME, FEC_Constants.OBJ_SUB_CATEGORY, uniqueErrors);
                    FEC_BatchUtils.setLookup(target, mdm, FEC_Constants.REL_SUB_CODE_NAME, FEC_Constants.OBJ_SUB_CODE, uniqueErrors);
                } catch (Exception ex) {
                    uniqueErrors.add('[Mapping ' + mdmObjName + '] ' + ex.getMessage());
                    continue;
                }
            } else if (mdmObjName == FEC_Constants.OBJ_MDM_CASE_STAGE) {
                try {
                    FEC_BatchUtils.copyValidFields(target, mdm, validFieldsForThisObj, fieldMap, commonFieldMap, uniqueErrors);
                    FEC_BatchUtils.setLookup(target, mdm, FEC_Constants.REL_BUSINESS_PROCESS_NAME.replace('_Name__r','__r'), FEC_Constants.OBJ_BUSINESS_PROCESS, uniqueErrors);
                } catch (Exception ex) {
                    uniqueErrors.add('[Mapping ' + mdmObjName + '] ' + ex.getMessage());
                    continue;
                }
            } else if (mdmObjName == FEC_Constants.OBJ_MDM_ADDITIONAL_FIELD_LIST_VALUE) {
                try {
                    FEC_BatchUtils.copyValidFields(target, mdm, validFieldsForThisObj, fieldMap, commonFieldMap, uniqueErrors);
                    FEC_BatchUtils.setLookup(target, mdm, FEC_Constants.REL_ADDITIONAL_FIELD, FEC_Constants.OBJ_ADDITIONAL_FIELD, uniqueErrors);
                } catch (Exception ex) {
                    uniqueErrors.add('[Mapping ' + mdmObjName + '] ' + ex.getMessage());
                    continue;
                }
            } else {
                try {
                    FEC_BatchUtils.copyValidFields(target, mdm, validFieldsForThisObj, fieldMap, commonFieldMap, uniqueErrors);
                } catch (Exception ex) {
                    uniqueErrors.add('[Mapping ' + mdmObjName + '] ' + ex.getMessage());
                    continue;
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
    
    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed,
                        TotalJobItems, CreatedBy.Email
                        FROM AsyncApexJob WHERE Id = :bc.getJobId()];
        
        // 2. Create email content using an email template
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] {job.CreatedBy.Email}); // Send to the job creator's email
        mail.setTemplateId('YOUR_EMAIL_TEMPLATE_ID'); // Replace with the actual email template ID

        // Set merge fields for the email template
        Map<String, Object> templateMergeFields = new Map<String, Object>{
            'JobStatus' => job.Status,
            'JobItemsProcessed' => job.JobItemsProcessed,
            'TotalJobItems' => job.TotalJobItems,
            'NumberOfErrors' => job.NumberOfErrors,
            'UniqueErrors' => String.join(new List<String>(uniqueErrors), '\n')
        };
        mail.setWhatId(null); // Set if the template requires a related record ID
        mail.setTemplateMergeFields(templateMergeFields);

        // 3. Send email
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }

        if (!uniqueErrors.isEmpty()) {
            String allErrors = String.join(new List<String>(uniqueErrors), '\n');
            throw new FEC_BatchException(FEC_Constants.ERROR_SYNC_FAILED_PREFIX + allErrors);
        }
    }
}
