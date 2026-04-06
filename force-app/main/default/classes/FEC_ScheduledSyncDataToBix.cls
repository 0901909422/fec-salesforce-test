/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Create Schedule Sync Data To Bix
Test Class:     FEC_CustomSyncAllInOneTest
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/03/31     Duan Nguyen          Init
------------------------------------------------------------*/
/*
    FEC_ScheduledSyncDataToBix syncJob = new FEC_ScheduledSyncDataToBix(); 
    String cronExp = '0 0 * * * ?'; 
    String jobID = System.schedule('Custom Sync Hourly', cronExp, syncJob);
*/
global class FEC_ScheduledSyncDataToBix implements  Schedulable {
    global void execute(SchedulableContext sc) { 
        Try{
             List<CustomSync__c> lst = [Select id, Name,
                                        SyncFailed__c,
                                        SyncSuccessFully__c,
                                        SyncTo__c,
                                        Active__c, 
                                        StartAt__c,
                                        EndAt__c,
                                        ProcessingQuantity__c,
                                        WhatSync__c, 
                                        TableName__c,
                                        TotalRecordSync__c
                                        from CustomSync__c
                                        where SyncTo__c = 'Bix' and Active__c = true];
            Map<String,CustomSyncField__mdt> mMetaData  = getCustomSync();
            if(!lst.isEmpty()){  
                Map<Id, CustomSync__c> mapCustomSync = new Map<Id, CustomSync__c>(lst); // ReSync
                // Sync New
                FEC_QueueRunBatchSync nextJob = new FEC_QueueRunBatchSync(lst);  
                System.enqueueJob(nextJob, 1);   
                // ReSync
                FEC_BatchReCallCustomSync batch = new FEC_BatchReCallCustomSync(mapCustomSync,mMetaData);
                Database.executeBatch(batch,1);
            }  
        }Catch(Exception e){
            System.debug('Schedule Sync Data To bix Error: Line '+e.getLineNumber() + ' - ' + e.getMessage());
        }
    }
    
    public static Map<String,CustomSyncField__mdt>  getCustomSync(){
        Map<String,CustomSyncField__mdt> mSetting = new Map<String,CustomSyncField__mdt>();
        List<CustomSyncField__mdt> lst = [Select id, Fields__c,MasterLabel,ObjecTarget__c,DeveloperName  from CustomSyncField__mdt];
        for(CustomSyncField__mdt item :lst){
                mSetting.put(item.MasterLabel, item);
        }
        return mSetting;
    }
}