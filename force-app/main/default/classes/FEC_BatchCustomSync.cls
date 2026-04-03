/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Create Queue Sync Data To
Test Class:     
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/03/31     Duan Nguyen          Init
------------------------------------------------------------*/ 
global class FEC_BatchCustomSync implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
     
    private String query;
	private CustomSync__c cus;
	private Integer countSuccess = 0;
	private Integer countFail = 0;
    private List<FEC_API_Log__c> logs = new List<FEC_API_Log__c>();
    public FEC_BatchCustomSync(CustomSync__c recordCustom) { 
        this.cus = recordCustom;
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {  
        DateTime toDate = System.now();
        DateTime startTime = (cus != null && cus.EndAt__c != null) ? cus.EndAt__c : toDate.addHours(-1);
        String whatName = cus.WhatSync__c;
        
        system.debug('-- LOG WIHAT:'+ cus.WhatSync__c);
        system.debug('-- LOG Size:'+ cus);
        return Database.getQueryLocator(getFields(cus));
    } 
    global void execute(Database.BatchableContext bc, List<sObject> scope) { 
        FEC_API_Log__c log = new FEC_API_Log__c();  
        log.FEC_Custom_Sync__c = cus.id;
        try{
            if(scope == null || scope.isEmpty()){
                log.FEC_Error_Message__c = 'Record not found'; 
            }else{
                List<String> recordIDs = new List<String>();
                for(Id reId : new Map<Id, sObject>(scope).keySet()) {
                    recordIDs.add(String.valueOf(reId));
                }
                log.FEC_Request_String__c = JSON.serialize(recordIDs);   
                log = FEC_CustomSyncCallout.sendRequest(cus,log,scope);  
                if (log.FEC_Is_Success__c ?? false) { 
                    countSuccess++;
                } else{ 
                    countFail++;
                } 
            }
        }Catch(Exception e){ 
            log.FEC_Error_Message__c = 'Exception FEC_BatchCustomSync: Line ' + e.getLineNumber() + ' - '+e.getMessage();
        }
        logs.add(log);
    }
 
    global void finish(Database.BatchableContext bc) { 
        cus.StartAt__c = cus.EndAt__c ?? System.now().addHours(-1);
        cus.EndAt__c = System.now();
        cus.SyncSuccessFully__c = countSuccess;
        cus.SyncFailed__c = countFail;
        update cus;
        system.debug('-- LOG Size:'+logs.size());
        if(!logs.isEmpty()){
            upsert logs;
        }
    }

    public static String getFields(CustomSync__c cus) { 
     String wherePart = ' WHERE ((LastModifiedDate > :startTime AND LastModifiedDate <= :toDate) ' +
                        ' OR (CreatedDate > :startTime AND CreatedDate <= :toDate) )' + 
                        ' and FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c = :whatName'; // test
        CustomSyncField__mdt setting = [Select id, Fields__c  from CustomSyncField__mdt
             WHERE DeveloperName = :cus.TargetObject__c limit 1];
  
        return 'SELECT ' + setting.Fields__c + ' FROM ' + cus.TargetObject__c + wherePart;
    }
}