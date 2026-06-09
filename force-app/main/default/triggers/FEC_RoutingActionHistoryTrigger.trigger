trigger FEC_RoutingActionHistoryTrigger on FEC_Routing_Action_History__c (before insert, after insert, before update, after update) {
    FEC_RoutingActionHistoryTriggerHandler.run();
}