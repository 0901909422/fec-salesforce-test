trigger FEC_RoutingActionHistoryTrigger on FEC_Routing_Action_History__c (before insert, after insert, before update, after update) {
    FEC_RoutingActionHistoryTriggerHandler.run();

    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        FEC_AssignmentController.handle(Trigger.new);
    }
}