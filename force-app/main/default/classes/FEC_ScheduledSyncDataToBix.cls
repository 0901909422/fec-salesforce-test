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
             run();
        }Catch(Exception e){
            System.debug('Schedule Sync Data To bix Error: Line '+e.getLineNumber() + ' - ' + e.getMessage());
        }
    }
    public static void run(){
        List<CustomSync__c> lst = [Select id, Name,
                                        SyncFailed__c,
                                        SyncSuccessFully__c,
                                        SyncTo__c,
                                        Active__c, 
                                        StartAt__c,
                                        EndAt__c,
                                        ProcessingQuantity__c,
                                        CaseBusinessCode__c, 
                                        TableName__c,
                                        TotalRecordSync__c,
                                        TargetObject__c,
                                        RequestBodyMapping__c,
                                        MappingDataType__c,
                                        PkColumn__c
                                        from CustomSync__c
                                        where SyncTo__c = 'Bix' and Active__c = true]; 
            if(!lst.isEmpty()){  
                Map<Id, CustomSync__c> mapCustomSync = new Map<Id, CustomSync__c>(lst); // ReSync
                // Sync New
                FEC_QueueRunBatchSync nextJob = new FEC_QueueRunBatchSync(lst);  
                System.enqueueJob(nextJob);   
                // ReSync
                FEC_BatchReCallCustomSync batch = new FEC_BatchReCallCustomSync(mapCustomSync);
                Database.executeBatch(batch,1);
            }  
    }
     
}