/**
 * FEC_ScheduledPushCampaignDataScheduler
 * Schedulable wrapper that enqueues the Queueable batch job.
 * Usage: System.schedule('Push Campaign Data', cronExp, new FEC_ScheduledPushCampaignDataScheduler());
 */
public with sharing class FEC_ScheduledPushCampaignDataScheduler implements Schedulable {
    public void execute(SchedulableContext SC) {
        System.enqueueJob(new FEC_ScheduledPushCampaignDataBatch());
    }
}