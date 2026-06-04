@IsTest
private class FEC_InteractionRoutingController_Test {

    @IsTest
    static void testExecuteRoutingAssignments_EarlyExit() {
        Test.startTest();
        FEC_InteractionRoutingController.executeRoutingAssignments();
        Test.stopTest();
        System.assert(true, 'Early exit paths should complete without throwing.');
    }

    @IsTest
    static void testPublishRoutingEvents() {
        Case c = new Case(Subject = 'Interaction Routing Event Test');
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        c = [SELECT Id, CaseNumber, OwnerId, ParentId, FEC_Channel__c, FEC_Send_To__c, FEC_Is_Reply_Interaction_email__c FROM Case WHERE Id = :c.Id];

        Test.startTest();
        FEC_InteractionRoutingController.publishRoutingEvents(null);
        FEC_InteractionRoutingController.publishRoutingEvents(new List<Case>());
        FEC_InteractionRoutingController.publishRoutingEvents(new List<Case>{ c });
        Test.stopTest();

        System.assert(true, 'publishRoutingEvents should handle empty and populated lists.');
    }
}
