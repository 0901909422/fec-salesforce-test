/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Create Schedule Sync Data To Bix
Test Class:     
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/03/31     Duan Nguyen          Init
------------------------------------------------------------*/
global class FEC_ScheduledSyncDataToBix implements  Schedulable {
    global void execute(SchedulableContext sc) { 
        Try{
             List<CustomSync__c> lst = [Select id, Name,
                                        SyncFailed__c,
                                        SyncSuccessFully__c,
                                        SyncTo__c,
                                        Active__c,
                                        TargetObject__c,
                                        StartAt__c,
                                        EndAt__c,
                                        ProcessingQuantity__c,
                                        WhatSync__c,
                                        FieldSetsTarget__c, 
                                        TableName__c
                                        from CustomSync__c
                                        where SyncTo__c = 'Bix' and Active__c = true];
            if(!lst.isEmpty()){ 
                FEC_QueueRunBatchSync nextJob = new FEC_QueueRunBatchSync(lst);  
                System.enqueueJob(nextJob, 1);   
            }  
        }Catch(Exception e){
            System.debug('Schedule Sync Data To bix Error: Line '+e.getLineNumber() + ' - ' + e.getMessage());
        }
    }
 
} 