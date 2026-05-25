@IsTest
private class FEC_CaseInitUpdateServiceTest {
    @IsTest
    static void updateRoutingActionDisplay_setsFieldValue() {
        Case testCase = new Case(
            Subject = 'Init Update Test',
            FEC_Is_Routing_Action_Display__c = 'Recall'
        );
        insert testCase;

        Test.startTest();
        FEC_CaseInitUpdateService.updateRoutingActionDisplay(testCase.Id, 'Reopen;Recall');
        Test.stopTest();

        Case updatedCase = [
            SELECT FEC_Is_Routing_Action_Display__c
            FROM Case
            WHERE Id = :testCase.Id
        ];
        System.assertEquals('Reopen;Recall', updatedCase.FEC_Is_Routing_Action_Display__c);
    }

    @IsTest
    static void updateRoutingActionDisplay_nullValueClearsField() {
        Case testCase = new Case(
            Subject = 'Init Update Test',
            FEC_Is_Routing_Action_Display__c = 'Recall'
        );
        insert testCase;

        Test.startTest();
        FEC_CaseInitUpdateService.updateRoutingActionDisplay(testCase.Id, null);
        Test.stopTest();

        Case updatedCase = [
            SELECT FEC_Is_Routing_Action_Display__c
            FROM Case
            WHERE Id = :testCase.Id
        ];
        System.assertEquals('', updatedCase.FEC_Is_Routing_Action_Display__c);
    }

    @IsTest
    static void clearCreatedFromSearchFlag_onlyWhenTrue() {
        Case testCase = new Case(
            Subject = 'Init Update Test',
            FEC_Is_Created_From_Search__c = true
        );
        insert testCase;

        Test.startTest();
        FEC_CaseInitUpdateService.clearCreatedFromSearchFlag(testCase.Id);
        Test.stopTest();

        Case updatedCase = [
            SELECT FEC_Is_Created_From_Search__c
            FROM Case
            WHERE Id = :testCase.Id
        ];
        System.assertEquals(false, updatedCase.FEC_Is_Created_From_Search__c);
    }

    @IsTest
    static void clearCreatedFromSearchFlag_skipsWhenAlreadyFalse() {
        Case testCase = new Case(
            Subject = 'Init Update Test',
            FEC_Is_Created_From_Search__c = false
        );
        insert testCase;

        Test.startTest();
        FEC_CaseInitUpdateService.clearCreatedFromSearchFlag(testCase.Id);
        Test.stopTest();

        Case updatedCase = [
            SELECT FEC_Is_Created_From_Search__c
            FROM Case
            WHERE Id = :testCase.Id
        ];
        System.assertEquals(false, updatedCase.FEC_Is_Created_From_Search__c);
    }

    @IsTest
    static void hasPersistableFieldChanges_detectsDifference() {
        Case baseline = new Case(
            Subject = 'Baseline',
            FEC_Is_Routing_Action_Display__c = 'Recall'
        );
        Case current = baseline.clone(true, true, true, true);
        current.FEC_Is_Routing_Action_Display__c = 'Reopen';

        System.assertEquals(
            true,
            FEC_CaseInitUpdateService.hasPersistableFieldChanges(current, baseline)
        );
    }

    @IsTest
    static void hasPersistableFieldChanges_skipsWhenSame() {
        Case baseline = new Case(
            Subject = 'Baseline',
            FEC_Is_Routing_Action_Display__c = 'Recall'
        );
        Case current = baseline.clone(true, true, true, true);

        System.assertEquals(
            false,
            FEC_CaseInitUpdateService.hasPersistableFieldChanges(current, baseline)
        );
    }
}
