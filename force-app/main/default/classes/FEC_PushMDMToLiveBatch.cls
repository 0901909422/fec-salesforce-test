public with sharing class FEC_PushMDMToLiveBatch implements Database.Batchable<String>, Database.Stateful {
    
    // Push-only: email notification
    private static final String SYNC_ADMIN_EMAILS = System.Label.FEC_MDM_Sync_Admin_Emails;

    private Set<String> uniqueErrors = new Set<String>();
    
    public Iterable<String> start(Database.BatchableContext bc) {
        return FEC_MDMBatchConfig.EXECUTION_ORDER;
    }
    
    public void execute(Database.BatchableContext bc, List<String> scope) {
        String mdmObjName = scope[0];
        String targetObjName = FEC_MDMBatchConfig.MDM_TO_LIVE_MAP.get(mdmObjName);
        
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(mdmObjName) || !gd.containsKey(targetObjName)) return;
        
        try {
            // STEP 1: Build query fields - only fields that exist on both source and MDM
            Map<String, Schema.SObjectField> targetFields = gd.get(targetObjName).getDescribe().fields.getMap();
            Map<String, Schema.SObjectField> mdmFieldsMap = gd.get(mdmObjName).getDescribe().fields.getMap();
            Set<String> validQueryFields = new Set<String>();
            validQueryFields.add('Id');
            validQueryFields.add(FEC_MDMBatchConfig.FIELD_PROCESS_CHANGE_STATUS);
            validQueryFields.add(FEC_MDMBatchConfig.FIELD_CODE);
            validQueryFields.add(FEC_MDMBatchConfig.FIELD_NAME);
            
            // Build filtered field map - only fields that exist on both objects
            // and are updateable on the target (skip formula/calculated fields)
            Map<String, String> filteredFieldMap = new Map<String, String>();
            for (String liveField : FEC_MDMBatchConfig.COMMON_FIELD_MAP.keySet()) {
                String mdmField = FEC_MDMBatchConfig.COMMON_FIELD_MAP.get(liveField);
                if (targetFields.containsKey(liveField) && mdmFieldsMap.containsKey(mdmField)) {
                    // Skip formula/non-updateable fields on target object
                    Schema.DescribeFieldResult targetFieldDesc = targetFields.get(liveField).getDescribe();
                    if (!targetFieldDesc.isUpdateable() && !targetFieldDesc.isCreateable()) {
                        continue;
                    }
                    validQueryFields.add(mdmField);
                    filteredFieldMap.put(mdmField, liveField); // Reverse mapping: MDM -> Live
                }
            }
            
            // Also query MDM lookup fields so we can remap them
            if (FEC_MDMBatchConfig.OBJECTS_WITH_LOOKUP_REMAPPING.contains(mdmObjName)) {
                List<String> objLookupFields = FEC_MDMBatchConfig.OBJECT_LOOKUP_FIELDS.get(mdmObjName);
                if (objLookupFields != null) {
                    for (String srcLookupField : objLookupFields) {
                        if (targetFields.containsKey(srcLookupField)) {
                            String mdmLookupField = FEC_MDMBatchConfig.LOOKUP_FIELD_MDM_MAP.get(srcLookupField).get(FEC_MDMBatchConfig.MDM_FIELD_KEY);
                            if (mdmFieldsMap.containsKey(mdmLookupField)) {
                                validQueryFields.add(mdmLookupField);
                            }
                        }
                    }
                }
            }
            
            // STEP 2: Query MDM records
            // Normalize field names to lowercase to prevent SOQL duplicate field errors
            // (Apex Set<String> is case-sensitive but SOQL field names are case-insensitive)
            Set<String> normalizedFields = new Set<String>();
            for (String f : validQueryFields) {
                normalizedFields.add(f.toLowerCase());
            }
            String query = 'SELECT ' + String.join(new List<String>(normalizedFields), ', ')
                + ' FROM ' + mdmObjName
                + ' WHERE ' + FEC_MDMBatchConfig.FIELD_PROCESS_CHANGE_STATUS + ' != \'' + FEC_MDMBatchConfig.PROCESS_STATUS_SYNCED + '\'';
            List<SObject> mdmRecords = Database.query(query);
            if (mdmRecords.isEmpty()) return;
            
            populateMissingCodes(mdmRecords, mdmObjName);
            
            // STEP 3: Build lookup remap maps (MDM -> Live)
            Map<String, Map<Id, Id>> lookupRemapMaps = new Map<String, Map<Id, Id>>();
            if (FEC_MDMBatchConfig.OBJECTS_WITH_LOOKUP_REMAPPING.contains(mdmObjName)) {
                buildLookupRemapMaps(mdmObjName, mdmRecords, targetFields, lookupRemapMaps, gd);
            }
            
            // STEP 4: Split NEW vs UPDATE vs DELETED
            List<SObject> mdmNew    = new List<SObject>();
            List<SObject> mdmUpdate = new List<SObject>();
            List<SObject> mdmDeleted = new List<SObject>();
            for (SObject mdm : mdmRecords) {
                String status = (String) mdm.get(FEC_MDMBatchConfig.FIELD_PROCESS_CHANGE_STATUS);
                if (status == FEC_MDMBatchConfig.PROCESS_STATUS_NEW) {
                    mdmNew.add(mdm);
                } else if (status == FEC_MDMBatchConfig.PROCESS_STATUS_UPDATE) {
                    mdmUpdate.add(mdm);
                } else if (status == FEC_MDMBatchConfig.PROCESS_STATUS_DELETED) {
                    mdmDeleted.add(mdm);
                }
            }
            
            // STEP 5: Prepare records for UPSERT
            List<SObject> insertList = buildTargetList(mdmNew, mdmObjName, targetObjName, filteredFieldMap, lookupRemapMaps, gd);
            List<SObject> updateList = buildTargetList(mdmUpdate, mdmObjName, targetObjName, filteredFieldMap, lookupRemapMaps, gd);
            
            Schema.SObjectField extIdField = targetFields.get(FEC_MDMBatchConfig.FIELD_CODE);
            
            // STEP 6: UPSERT records to Live
            if (!insertList.isEmpty()) {
                processUpsert(insertList, mdmNew, extIdField, targetObjName);
            }
            if (!updateList.isEmpty()) {
                processUpsert(updateList, mdmUpdate, extIdField, targetObjName);
            }
            
            // STEP 7: DELETE Live records for soft-deleted MDM records, then delete MDM records
            if (!mdmDeleted.isEmpty()) {
                processDelete(mdmDeleted, targetObjName, gd);
            }
            
        } catch (Exception e) {
            System.debug('Error pushing ' + mdmObjName + ' to Live: ' + e.getMessage());
            uniqueErrors.add('[Error ' + mdmObjName + '] ' + e.getMessage());
        }
    }
    
    private void processUpsert(List<SObject> targetList, List<SObject> mdmRecords, Schema.SObjectField extIdField, String targetObjName) {
        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
        try {
            Database.UpsertResult[] results = Database.upsert(targetList, extIdField, false);
            List<SObject> mdmToUpdate = new List<SObject>();
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    mdmRecords[i].put(FEC_MDMBatchConfig.FIELD_PROCESS_CHANGE_STATUS, FEC_MDMBatchConfig.PROCESS_STATUS_SYNCED);
                    mdmToUpdate.add(mdmRecords[i]);
                } else {
                    uniqueErrors.add('[' + targetObjName + ' Upsert Error] ' + results[i].getErrors()[0].getMessage());
                }
            }
            if (!mdmToUpdate.isEmpty()) update mdmToUpdate;
        } finally {
            FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
        }
    }
    
    /**
     * @description Process soft-deleted MDM records: delete corresponding Live records
     * (matched via FEC_Code__c), then delete the MDM records themselves.
     */
    private void processDelete(List<SObject> mdmDeleted, String targetObjName, Map<String, Schema.SObjectType> gd) {
        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
        try {
            // Collect FEC_Code__c values from MDM records to find Live counterparts
            Set<String> codes = new Set<String>();
            for (SObject mdm : mdmDeleted) {
                String code = (String) mdm.get(FEC_MDMBatchConfig.FIELD_CODE);
                if (String.isNotBlank(code)) {
                    codes.add(code);
                }
            }
            
            // Delete Live records matching FEC_Code__c
            if (!codes.isEmpty() && gd.containsKey(targetObjName)) {
                List<SObject> liveRecords = Database.query(
                    'SELECT Id FROM ' + targetObjName + ' WHERE ' + FEC_MDMBatchConfig.FIELD_CODE + ' IN :codes'
                );
                if (!liveRecords.isEmpty()) {
                    Database.DeleteResult[] delResults = Database.delete(liveRecords, false);
                    for (Database.DeleteResult dr : delResults) {
                        if (!dr.isSuccess()) {
                            uniqueErrors.add('[' + targetObjName + ' Delete Error] ' + dr.getErrors()[0].getMessage());
                        }
                    }
                }
            }
            
            // Delete MDM records
            Database.DeleteResult[] mdmDelResults = Database.delete(mdmDeleted, false);
            for (Database.DeleteResult dr : mdmDelResults) {
                if (!dr.isSuccess()) {
                    uniqueErrors.add('[MDM Delete Error] ' + dr.getErrors()[0].getMessage());
                }
            }
        } finally {
            FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
        }
    }
    
    private void populateMissingCodes(List<SObject> records, String objectName) {
        List<SObject> recordsToUpdate = new List<SObject>();
        for (SObject record : records) {
            String code = (String) record.get(FEC_MDMBatchConfig.FIELD_CODE);
            if (String.isBlank(code)) {
                String name = (String) record.get(FEC_MDMBatchConfig.FIELD_NAME);
                if (String.isNotBlank(name)) {
                    record.put(FEC_MDMBatchConfig.FIELD_CODE, name);
                    recordsToUpdate.add(record);
                }
            }
        }
        if (!recordsToUpdate.isEmpty()) {
            FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
            try {
                update recordsToUpdate;
            } finally {
                FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
            }
        }
    }
    
    private List<SObject> buildTargetList(
        List<SObject> mdmRecords, String mdmObjName, String targetObjName,
    Map<String, String> filteredFieldMap, Map<String, Map<Id, Id>> lookupRemapMaps,
    Map<String, Schema.SObjectType> gd
    ) {
        List<SObject> targetList = new List<SObject>();
        List<String> thisObjLookupFields = FEC_MDMBatchConfig.OBJECT_LOOKUP_FIELDS.containsKey(mdmObjName)
            ? FEC_MDMBatchConfig.OBJECT_LOOKUP_FIELDS.get(mdmObjName)
            : new List<String>();
        Boolean skipName = FEC_MDMBatchConfig.OBJECTS_WITH_AUTONUMBER_NAME.contains(mdmObjName);
        
        for (SObject mdm : mdmRecords) {
            SObject target = gd.get(targetObjName).newSObject();
            
            // Copy Code field
            String codeValue = (String)mdm.get(FEC_MDMBatchConfig.FIELD_CODE);
            if (String.isNotBlank(codeValue)) {
                target.put(FEC_MDMBatchConfig.FIELD_CODE, codeValue);
            }
            
            // Copy normal fields
            for (String mdmField : filteredFieldMap.keySet()) {
                String liveField = filteredFieldMap.get(mdmField);
                if (thisObjLookupFields.contains(liveField)) continue;
                if (skipName && liveField == FEC_MDMBatchConfig.FIELD_NAME) continue;
                
                if (mdm.get(mdmField) != null) {
                    target.put(liveField, mdm.get(mdmField));
                }
            }
            
            // Remap lookup fields
            if (FEC_MDMBatchConfig.OBJECTS_WITH_LOOKUP_REMAPPING.contains(mdmObjName)) {
                remapLookupFields(mdm, target, lookupRemapMaps, mdmObjName);
            }
            
            targetList.add(target);
        }
        return targetList;
    }
    
    private void buildLookupRemapMaps(String mdmObjName, List<SObject> mdmRecords,
    Map<String, Schema.SObjectField> targetFields,
    Map<String, Map<Id, Id>> lookupRemapMaps,
    Map<String, Schema.SObjectType> gd) {
        
        List<String> objectLookupFields = FEC_MDMBatchConfig.OBJECT_LOOKUP_FIELDS.get(mdmObjName);
        if (objectLookupFields == null || objectLookupFields.isEmpty()) return;
        
        for (String srcLookupField : objectLookupFields) {
            if (!targetFields.containsKey(srcLookupField)) {
                lookupRemapMaps.put(srcLookupField, new Map<Id, Id>());
                continue;
            }
            String mdmLookupObj = FEC_MDMBatchConfig.LOOKUP_FIELD_MDM_MAP.get(srcLookupField).get(FEC_MDMBatchConfig.MDM_OBJ_KEY);
            String mdmLookupField = FEC_MDMBatchConfig.LOOKUP_FIELD_MDM_MAP.get(srcLookupField).get(FEC_MDMBatchConfig.MDM_FIELD_KEY);
            
            if (!gd.containsKey(mdmLookupObj)) {
                lookupRemapMaps.put(srcLookupField, new Map<Id, Id>());
                continue;
            }
            String srcObjName = FEC_MDMBatchConfig.MDM_TO_LIVE_MAP.containsKey(mdmLookupObj)
                ? FEC_MDMBatchConfig.MDM_TO_LIVE_MAP.get(mdmLookupObj)
                : null;
            
            Map<Id, Id> mdmToSrcIdMap = new Map<Id, Id>();
            if (srcObjName != null && gd.containsKey(srcObjName)) {
                Set<Id> usedMdmIds = new Set<Id>();
                for (SObject mdm : mdmRecords) {
                    Id lookupId = (Id)mdm.get(mdmLookupField);
                    if (lookupId != null) usedMdmIds.add(lookupId);
                }
                
                if (!usedMdmIds.isEmpty()) {
                    Map<Id, String> mdmIdToCode = new Map<Id, String>();
                    for (SObject mdmLookupRecord : Database.query(
                        'SELECT Id, ' + FEC_MDMBatchConfig.FIELD_CODE + ' FROM ' + mdmLookupObj + ' WHERE Id IN :usedMdmIds'
                    )) {
                        String code = (String)mdmLookupRecord.get(FEC_MDMBatchConfig.FIELD_CODE);
                        if (String.isNotBlank(code)) mdmIdToCode.put(mdmLookupRecord.Id, code);
                    }
                    
                    Map<String, Id> srcCodeToId = new Map<String, Id>();
                    for (SObject srcLookupRecord : Database.query(
                        'SELECT Id, ' + FEC_MDMBatchConfig.FIELD_CODE + ' FROM ' + srcObjName
                    )) {
                        String code = (String)srcLookupRecord.get(FEC_MDMBatchConfig.FIELD_CODE);
                        if (String.isNotBlank(code)) srcCodeToId.put(code, srcLookupRecord.Id);
                    }
                    
                    for (Id mdmId : mdmIdToCode.keySet()) {
                        String code = mdmIdToCode.get(mdmId);
                        if (srcCodeToId.containsKey(code)) {
                            mdmToSrcIdMap.put(mdmId, srcCodeToId.get(code));
                        }
                    }
                }
            }
            lookupRemapMaps.put(srcLookupField, mdmToSrcIdMap);
        }
    }
    
    private void remapLookupFields(SObject mdm, SObject target,
    Map<String, Map<Id, Id>> lookupRemapMaps,
    String mdmObjName) {
        
        List<String> objectLookupFields = FEC_MDMBatchConfig.OBJECT_LOOKUP_FIELDS.get(mdmObjName);
        if (objectLookupFields == null || objectLookupFields.isEmpty()) return;
        
        for (String srcLookupField : objectLookupFields) {
            String mdmLookupField = FEC_MDMBatchConfig.LOOKUP_FIELD_MDM_MAP.get(srcLookupField).get(FEC_MDMBatchConfig.MDM_FIELD_KEY);
            Id mdmId = (Id)mdm.get(mdmLookupField);
            if (mdmId == null) continue;
            
            Map<Id, Id> remapMap = lookupRemapMaps.get(srcLookupField);
            if (remapMap != null && remapMap.containsKey(mdmId)) {
                target.put(srcLookupField, remapMap.get(mdmId));
            }
        }
    }
    
    /**
     * @description Hàm xử lý hậu kỳ của Batch, tổng hợp lỗi, lưu Log vào hệ thống
     * và gửi email thông báo qua Email Template.
     * @author      DAT NGO
     * @param       bc Database.BatchableContext
     * @return      void
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('[finish] START');
        
        // 1. Lấy thông tin Batch Job từ hệ thống
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedById, CreatedBy.Email
            FROM AsyncApexJob 
            WHERE Id = :bc.getJobId()
        ];
        
        // 2. Tổng hợp dữ liệu lỗi
        String errorDetails = '';
        Integer totalErrors = job.NumberOfErrors;
        String batchStatus = 'Success';
        
        if (!uniqueErrors.isEmpty()) {
            errorDetails = String.join(new List<String>(uniqueErrors), '\n\n');
            totalErrors += uniqueErrors.size(); // Cộng dồn lỗi logic và lỗi Job
            batchStatus = 'Completed with Errors';
        } else if (job.NumberOfErrors > 0 || job.Status == 'Failed') {
            batchStatus = 'Failed';
        }
        
        // 3. Tạo bản ghi FEC_Batch_Log__c
        FEC_Batch_Log__c batchLog = new FEC_Batch_Log__c(
            FEC_Batch_Name__c      = 'FEC_PushMDMToLiveBatch',
            FEC_Job_ID__c          = job.Id,
            FEC_Status__c          = batchStatus,
            FEC_Total_Job_Items__c = job.TotalJobItems,
            FEC_Processed_Items__c = job.JobItemsProcessed,
            FEC_Error_Count__c     = totalErrors,
            FEC_Error_Details__c   = String.isNotBlank(errorDetails) ? errorDetails.abbreviate(131000) : null
        );
        
        try {
            insert batchLog;
            System.debug('[finish] Inserted Batch Log successfully. ID: ' + batchLog.Id);
        } catch (Exception ex) {
            System.debug('[finish] ERROR Insert Batch Log: ' + ex.getMessage());
        }
        
        // 4. Thiết lập danh sách người nhận từ Custom Label
        List<String> toAddresses = new List<String>();
        if (String.isNotBlank(SYNC_ADMIN_EMAILS)) {
            for (String email : SYNC_ADMIN_EMAILS.split(',')) {
                if (String.isNotBlank(email)) {
                    toAddresses.add(email.trim());
                }
            }
        }
        
        // Fallback to CreatedBy Email if label is empty
        if (toAddresses.isEmpty()) {
            toAddresses.add(job.CreatedBy.Email);
        }

        // 5. Thiết lập và gửi Email Template
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        List<EmailTemplate> templates = [
            SELECT Id FROM EmailTemplate 
            WHERE DeveloperName = 'FEC_PushMDM_Batch_Completion' 
            LIMIT 1
        ];
        
        String envPrefix = getEnvironmentPrefix();

        if (!templates.isEmpty() && batchLog.Id != null) {
            // Bypass giới hạn WhatId đối với UserId bằng tính năng render template
            Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(
                templates[0].Id, 
                null,           // whoId (Bỏ qua vì không gửi cho Contact/Lead)
                batchLog.Id     // whatId (Truyền ID Log để merge data)
            );
            
            mail.setToAddresses(toAddresses);
            mail.setSubject(envPrefix + renderedEmail.getSubject());
            mail.setHtmlBody(renderedEmail.getHtmlBody());
            mail.setSaveAsActivity(false); 
        } else {
            mail.setToAddresses(toAddresses);
            mail.setSubject(envPrefix + '[FEC MDM Sync] Fallback: Đồng bộ MDM hoàn tất - ' + batchStatus);
            mail.setPlainTextBody('Batch Job: FEC_PushMDMToLiveBatch\nStatus: ' + batchStatus + '\nErrors: ' + totalErrors + '\nLog ID: ' + batchLog.Id);
        }
        
        if (!Test.isRunningTest()) {
            try {
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                System.debug('[finish] Email sent successfully to: ' + toAddresses);
            } catch (Exception ex) {
                System.debug('[finish] Lỗi khi gửi mail: ' + ex.getMessage());
            }
        }
        
        System.debug('[finish] RETURN: ' + batchStatus);
    }

    /**
     * @description Trả về prefix môi trường để prepend vào email subject.
     *              Ví dụ: "Sandbox [SGP2S]: " hoặc "Production [AP16]: "
     *              Dùng Organization.IsSandbox + InstanceName để xác định môi trường.
     * @return      String prefix kết thúc bằng ": " (hoặc empty nếu query fail)
     */
    @TestVisible
    private static String getEnvironmentPrefix() {
        try {
            Organization org = [SELECT IsSandbox, InstanceName FROM Organization LIMIT 1];
            String envType = org.IsSandbox ? 'Sandbox' : 'Production';
            String instance = String.isNotBlank(org.InstanceName) ? ' [' + org.InstanceName + ']' : '';
            return envType + instance + ': ';
        } catch (Exception ex) {
            System.debug('[getEnvironmentPrefix] Error: ' + ex.getMessage());
            return '';
        }
    }
}