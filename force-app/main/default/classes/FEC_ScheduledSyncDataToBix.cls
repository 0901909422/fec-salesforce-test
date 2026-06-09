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
        List<FEC_Custom_Sync__c> lst = [Select id, Name,
                                        FEC_Sync_Failed__c,
                                        FEC_Sync_Successfully__c,
                                        FEC_Sync_To__c,
                                        FEC_Active__c, 
                                        FEC_Start_At__c,
                                        FEC_End_At__c,
                                        FEC_Processing_Quantity__c,
                                        FEC_Case_Business_Code__c, 
                                        FEC_Table_Name__c,
                                        FEC_Total_Record_Sync__c,
                                        FEC_Target_Object__c,
                                        FEC_Request_Body_Mapping__c,
                                        FEC_Mapping_Data_Type__c
                                        from FEC_Custom_Sync__c
                                        where FEC_Sync_To__c = 'Bix' and FEC_Active__c = true]; 
            if(!lst.isEmpty()){  
                Map<Id, FEC_Custom_Sync__c> mapCustomSync = new Map<Id, FEC_Custom_Sync__c>(lst); // ReSync
                // Sync New
                FEC_QueueRunBatchSync nextJob = new FEC_QueueRunBatchSync(lst);  
                System.enqueueJob(nextJob);   
                // ReSync
                FEC_BatchReCallCustomSync batch = new FEC_BatchReCallCustomSync(mapCustomSync);
                Database.executeBatch(batch,1);
            }  
    }
     
}