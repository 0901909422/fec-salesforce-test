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

    @IsTest
    static void clearCaseNOC_skipsImportedCase() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);
        FEC_Product_Type__c productType = new FEC_Product_Type__c(
            Name = 'Card Import Test',
            FEC_Code__c = 'CIMP' + suffix,
            FEC_Active__c = true
        );
        insert productType;

        Case testCase = new Case(
            Subject = 'Clear NOC Imported Test',
            FEC_IsImported__c = true,
            FEC_Product_Type__c = productType.Id
        );
        insert testCase;

        Test.startTest();
        FEC_CaseEditNOCController.clearCaseNOC(testCase.Id);
        Test.stopTest();

        Case refreshed = [
            SELECT FEC_IsImported__c, FEC_Product_Type__c
            FROM Case
            WHERE Id = :testCase.Id
        ];
        System.assertEquals(true, refreshed.FEC_IsImported__c);
        System.assertEquals(productType.Id, refreshed.FEC_Product_Type__c);
    }
}
