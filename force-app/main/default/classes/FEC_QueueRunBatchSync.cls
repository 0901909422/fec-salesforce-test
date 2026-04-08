/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Create Queue Sync Data To
Test Class:     FEC_CustomSyncAllInOneTest 
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/03/31     Duan Nguyen          Init
------------------------------------------------------------*/
public class FEC_QueueRunBatchSync implements Queueable {
    
    private List<CustomSync__c> records;
 
    public FEC_QueueRunBatchSync(List<CustomSync__c> datas) {
        this.records = datas;
    }

    public void execute(QueueableContext context) { 
        if (records == null || records.isEmpty()) return;
        CustomSync__c cus = records.remove(0);   
        Boolean isEndJob = records.isEmpty();
        FEC_BatchCustomSync batch = new FEC_BatchCustomSync(cus,isEndJob);
        Database.executeBatch(batch, (Integer)(cus.ProcessingQuantity__c ?? 10)); 
        if (!records.isEmpty()) { 
            FEC_QueueRunBatchSync nextJob = new FEC_QueueRunBatchSync(records); 
            if (!Test.isRunningTest()) {
                System.enqueueJob(nextJob,1); 
            } 
        }
    }
}