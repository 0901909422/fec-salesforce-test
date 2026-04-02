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
        DateTime toDate = DateTime.now();
        DateTime startTime = (cus != null && cus.EndAt__c != null) ? cus.EndAt__c : toDate.addHours(-1);
        return Database.getQueryLocator(getFieldSet(cus));
    } 
    global void execute(Database.BatchableContext bc, List<Case> scope) { 
        FEC_API_Log__c log = new FEC_API_Log__c();  
        try{
            if(scope == null || scope.isEmpty()){
                log.FEC_Error_Message__c = 'Record not found'; 
            }else{
                List<String> caseIds = new List<String>();
                for(Id caseId : new Map<Id, Case>(scope).keySet()) {
                    caseIds.add(String.valueOf(caseId));
                }
                log.FEC_Record_Data__c = JSON.serialize(scope);   
                log.FEC_Custom_Sync__c = cus.id;
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
        if(!logs.isEmpty()){
            upsert logs;
        }
    }

    private String getFieldSet(CustomSync__c cus) {  
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(cus.TargetObject__c); 
        Map<String, Schema.FieldSet> fieldSetMap = targetType.getDescribe().fieldSets.getMap();
        Set<String> queryFields = new Set<String>{}; 
        Integer index = 1;
        while (fieldSetMap.containsKey(cus.FieldSetsTarget__c + index)) {
            for (Schema.FieldSetMember f : fieldSetMap.get(cus.FieldSetsTarget__c + index).getFields()) {
                queryFields.add(f.getFieldPath());
            }
            index++;
        }
        if(queryFields.isEmpty())  return 'Select Id from '+ cus.TargetObject__c + ' limit 0'; 
        String fieldsPart = String.join(new List<String>(queryFields), ', ');

        // String wherePart = ' WHERE (LastModifiedDate > :startTime AND LastModifiedDate <= :toDate) ' +
        //                 ' OR (CreatedDate > :startTime AND CreatedDate <= :toDate) limit 300'; // test
        
        String wherePart = ' limit 300'; // test
        
        return 'SELECT ' + fieldsPart + ' FROM ' + cus.TargetObject__c + wherePart;
    }
}