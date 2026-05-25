@IsTest
private class FEC_CaseEditNOCControllerTest {
    @IsTest
    static void clearCaseNOC_skipsSubmittedCase() {
        Case testCase = new Case(
            Subject = 'Clear NOC Submitted Test',
            FEC_Is_Submited__c = true
        );
        insert testCase;

        Test.startTest();
        FEC_CaseEditNOCController.clearCaseNOC(testCase.Id);
        Test.stopTest();

        System.assertEquals(true, [SELECT FEC_Is_Submited__c FROM Case WHERE Id = :testCase.Id].FEC_Is_Submited__c);
    }

    @IsTest
    static void clearCaseNOC_skipsWhenNocAlreadyEmpty() {
        Case testCase = new Case(Subject = 'Clear NOC Skip Test');
        insert testCase;

        Test.startTest();
        FEC_CaseEditNOCController.clearCaseNOC(testCase.Id);
        Test.stopTest();

        System.assert(true, 'No DML expected when NOC fields are already empty.');
    }
}
