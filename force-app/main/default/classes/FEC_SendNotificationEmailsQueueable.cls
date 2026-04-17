public without sharing class FEC_SendNotificationEmailsQueueable implements Queueable, Database.AllowsCallouts {

    private List<FEC_Routing_Action_History__c> records;

    public FEC_SendNotificationEmailsQueueable(List<FEC_Routing_Action_History__c> records) {
        this.records = records;
    }

    public void execute(QueueableContext context) {
        FEC_RoutingActionHistoryTriggerHandler.processNotificationEmails(this.records);
    }
}
