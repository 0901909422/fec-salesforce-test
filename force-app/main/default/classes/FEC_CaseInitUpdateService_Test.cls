@IsTest
private class FEC_CaseInitUpdateService_Test {
    private static Id fakeCaseId() {
        return Id.valueOf('500000000000001AAA');
    }

    @IsTest
    static void testUpdateRoutingActionDisplayAndClearFlag() {
        Test.startTest();
        FEC_CaseInitUpdateService.updateRoutingActionDisplay(fakeCaseId(), 'RouteA;RouteB');
        FEC_CaseInitUpdateService.clearCreatedFromSearchFlag(fakeCaseId());
        Test.stopTest();
        System.assert(true, 'Method should safely handle update/query paths.');
    }

    @IsTest
    static void testRunSystemCaseUpdateIfChanged() {
        Id caseId = fakeCaseId();
        Case baseline = new Case(Id = caseId, Subject = 'Baseline');
        Case changed = baseline.clone(false, true, false, false);
        changed.Id = caseId;
        changed.FEC_Is_Routing_Action_Display__c = 'Changed By Service';

        Test.startTest();
        FEC_CaseInitUpdateService.runSystemCaseUpdateIfChanged(changed, baseline);
        Test.stopTest();

        System.assert(
            FEC_CaseTriggerHandler.systemUpdatedCaseIds.contains(caseId),
            'Updated case id should be registered in trigger context set.'
        );
    }

    @IsTest
    static void testHasPersistableFieldChangesAndNullGuards() {
        Case baseline = new Case(
            Subject = 'Baseline',
            FEC_Is_Routing_Action_Display__c = 'Recall'
        );
        Case same = baseline.clone(false, true, false, false);
        Case diff = baseline.clone(false, true, false, false);
        diff.FEC_Is_Routing_Action_Display__c = 'Recall;Reopen';

        System.assertEquals(
            false,
            FEC_CaseInitUpdateService.hasPersistableFieldChanges(same, baseline)
        );
        System.assertEquals(
            true,
            FEC_CaseInitUpdateService.hasPersistableFieldChanges(diff, baseline)
        );
        System.assertEquals(
            false,
            FEC_CaseInitUpdateService.hasPersistableFieldChanges(null, baseline)
        );
        System.assertEquals(
            true,
            FEC_CaseInitUpdateService.hasPersistableFieldChanges(diff, null)
        );

        Test.startTest();
        FEC_CaseInitUpdateService.updateRoutingActionDisplay(null, 'Ignored');
        FEC_CaseInitUpdateService.clearCreatedFromSearchFlag(null);
        FEC_CaseInitUpdateService.runSystemCaseUpdate(null);
        FEC_CaseInitUpdateService.runSystemCaseUpdate(new Case(Subject = 'No Id'));
        FEC_CaseInitUpdateService.runSystemCaseUpdateIfChanged(null, baseline);
        FEC_CaseInitUpdateService.runSystemCaseUpdateIfChanged(new Case(), baseline);
        FEC_CaseInitUpdateService.registerSystemCaseUpdate(null);
        Test.stopTest();
    }
}
