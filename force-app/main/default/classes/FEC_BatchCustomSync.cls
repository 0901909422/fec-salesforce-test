/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Create Queue Sync Data To
Test Class:     FEC_CustomSyncAllInOneTest
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/03/31     Duan Nguyen          Init
------------------------------------------------------------*/ 
global class FEC_BatchCustomSync implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
     
    private String query;
	private CustomSync__c cus;
	private Integer countSuccess = 0;
	private Integer countFail = 0;
	private Integer totalSize = 0;
    private DateTime toDate ;
    private DateTime startTime ;
    private Boolean isEndJob = false ;
    private List<FEC_API_Log__c> logs = new List<FEC_API_Log__c>();
    public FEC_BatchCustomSync(CustomSync__c recordCustom,Boolean isEndd) { 
        this.cus = recordCustom;
        this.isEndJob = isEndd; // noti
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {  

        DateTime currentNow = System.now();
 
        toDate = DateTime.newInstance(
            currentNow.year(), 
            currentNow.month(), 
            currentNow.day(), 
            currentNow.hour(), 
            0, 
            0 
        );  
        startTime  = cus.EndAt__c ?? toDate.addHours(-1);
        String whatName = cus.WhatSync__c; 
        return Database.getQueryLocator(getFields(cus));
    } 
    global void execute(Database.BatchableContext bc, List<sObject> scope) { 
        FEC_API_Log__c log = new FEC_API_Log__c();  
        log.FEC_Custom_Sync__c = cus.id;
        try{
            totalSize = totalSize + scope.size();
            if(scope == null || scope.isEmpty()){
                log.FEC_Error_Message__c = 'Record not found'; 
            }else{
                List<String> recordIDs = new List<String>();
                for(Id reId : new Map<Id, sObject>(scope).keySet()) {
                    recordIDs.add(String.valueOf(reId));
                }
                log.Records__c = JSON.serialize(recordIDs);   
                List<FEC_API_Log__c> resultLogs = FEC_CustomSyncCallout.sendRequest(cus,log,scope);  
                for (FEC_API_Log__c rLog : resultLogs) {
                    if (rLog.FEC_Is_Success__c ?? false) { 
                         countSuccess = countSuccess + countIdsFromJsonString(rLog.Records__c); 
                    } else {  
                         countFail = countFail + countIdsFromJsonString(rLog.Records__c); 
                    }
                    logs.add(rLog);
                }
                return;
            }
        }Catch(Exception e){ 
            log.FEC_Error_Message__c = 'Exception FEC_BatchCustomSync: Line ' + e.getLineNumber() + ' - '+e.getMessage();
        }
        logs.add(log);
    }
 
    global void finish(Database.BatchableContext bc) { 
        cus.StartAt__c = cus.EndAt__c ?? toDate.addHours(-1);
        cus.EndAt__c = toDate;
        cus.SyncSuccessFully__c = countSuccess;
        cus.SyncFailed__c = countFail;
        cus.TotalRecordSync__c = totalSize;
        update cus; 
        if(!logs.isEmpty()){
            upsert logs;
        }
        if(isEndJob) System.enqueueJob(new FEC_QueueReportCustomSyncBix());   
    }
    public static Integer countIdsFromJsonString(String jsonStringInput) { 
        if (String.isBlank(jsonStringInput)) return 0; 
        try { 
            List<String> idList = (List<String>) JSON.deserialize(jsonStringInput, List<String>.class);
            return idList.size(); 
        } catch (Exception e) { 
            System.debug('Đã có lỗi xảy ra khi parse JSON: ' + e.getMessage());
            return 0;
        }
    }

    public static String getFields(CustomSync__c cus) { 
        String fieldList = extractFieldsFromMapping(cus.RequestBodyMapping__c);
        if (Test.isRunningTest()) return 'SELECT ' + fieldList + ' FROM ' + cus.TargetObject__c; 

        String wherePart = ' WHERE ((LastModifiedDate > :startTime AND LastModifiedDate <= :toDate) ' +
                           ' OR (CreatedDate > :startTime AND CreatedDate <= :toDate) )' + 
                           ' and FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c = :whatName ';  
        return 'SELECT ' + fieldList + ' FROM ' + cus.TargetObject__c + wherePart;
    }

    public static String extractFieldsFromMapping(String mappingJson) {
        Map<String, Object> mapping = (Map<String, Object>) JSON.deserializeUntyped(mappingJson);
        Set<String> fields = new Set<String>();
        for (String key : mapping.keySet()) {
            Object val = mapping.get(key);
            if (val instanceof String) {
                fields.add((String) val);
            }
        }
        return String.join(new List<String>(fields), ', ');
    }
}