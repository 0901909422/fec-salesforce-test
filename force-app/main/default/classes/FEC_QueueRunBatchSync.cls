/*------------------------------------------------------------
Author:        Duan Nguyen
Company:       Isobar
Description:   Create Queue Sync Data To
Test Class:     FEC_CustomSyncAllInOneTest 
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/03/31     Duan Nguyen          Init
2026/06/09     Duan Nguyen          Optimize: fire 3 batches per execution
------------------------------------------------------------*/
public class FEC_QueueRunBatchSync implements Queueable {
    
    private static final Integer BATCH_PER_EXECUTION = 3;
    private List<FEC_Custom_Sync__c> records;
 
    public FEC_QueueRunBatchSync(List<FEC_Custom_Sync__c> datas) {
        this.records = datas;
    }

    public void execute(QueueableContext context) { 
        if (records == null || records.isEmpty()) return;

        // Nếu chỉ còn 1 record → chạy riêng với isEndJob = true để trigger report
        if (records.size() == 1) {
            FEC_Custom_Sync__c cus = records.remove(0);
            FEC_BatchCustomSync batch = new FEC_BatchCustomSync(cus, true);
            Database.executeBatch(batch, (Integer)(cus.FEC_Processing_Quantity__c ?? 10));
            return;
        }

        // Nếu còn > 1 record, giữ lại 1 record cuối để lần chain tiếp theo chạy riêng
        Integer available = records.size() - 1; // trừ 1 record cuối
        Integer count = Math.min(BATCH_PER_EXECUTION, available);

        for (Integer i = 0; i < count; i++) {
            FEC_Custom_Sync__c cus = records.remove(0);
            FEC_BatchCustomSync batch = new FEC_BatchCustomSync(cus, false);
            Database.executeBatch(batch, (Integer)(cus.FEC_Processing_Quantity__c ?? 10));
        }

        if (!records.isEmpty()) { 
            FEC_QueueRunBatchSync nextJob = new FEC_QueueRunBatchSync(records); 
            if (!Test.isRunningTest()) {
                System.enqueueJob(nextJob, 1); 
            } 
        }
    }
}