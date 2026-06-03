@IsTest
private class FEC_COFFraudRelatedHandler_Test {

    private static final String INITIAL_COMPLAIN_TYPE = 'Normal';
    private static final String INITIAL_COMPLAINT_SOURCE = 'SBV';
    private static final String UPDATED_COMPLAIN_TYPE = 'Urgent';
    private static final String UPDATED_COMPLAINT_SOURCE = 'CIC';

    @TestSetup
    static void setupData() {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'Fraud Case Test',
                Status = 'New',
                FEC_Complain_Type__c = INITIAL_COMPLAIN_TYPE,
                FEC_Complaint_Source__c = INITIAL_COMPLAINT_SOURCE,
                FEC_ID_Search__c = 'COF-' + String.valueOf(System.currentTimeMillis())
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Category__c(
            Name = 'Fraud Category',
            FEC_Code__c = 'FRAUD-CAT',
            FEC_Active__c = true
        );
    }

    @IsTest
    static void testGetCaseInfo() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        Case result = FEC_COFFraudRelatedHandler.getCaseInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Case info không được null');
        System.assertEquals(INITIAL_COMPLAIN_TYPE, result.FEC_Complain_Type__c);
    }

    @IsTest
    static void testGetCategory() {
        FEC_Category__c cat = [SELECT Id FROM FEC_Category__c LIMIT 1];

        Test.startTest();
        String catName = FEC_COFFraudRelatedHandler.getCategory(cat.Id);
        String nullCat = FEC_COFFraudRelatedHandler.getCategory(null);
        Test.stopTest();

        System.assertEquals('Fraud Category', catName, 'Tên category phải khớp');
        System.assertEquals(null, nullCat, 'Truyền id null phải trả về null');
    }

    @IsTest
    static void testUpdateCase() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_COFFraudRelatedHandler.updateCase(
            c.Id,
            UPDATED_COMPLAIN_TYPE,
            UPDATED_COMPLAINT_SOURCE
        );
        Test.stopTest();

        Case updatedCase = [
            SELECT FEC_Complain_Type__c, FEC_Complaint_Source__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals(UPDATED_COMPLAIN_TYPE, updatedCase.FEC_Complain_Type__c);
        System.assertEquals(UPDATED_COMPLAINT_SOURCE, updatedCase.FEC_Complaint_Source__c);
    }

    @IsTest
    static void testUpdateCase_Exception() {
        Boolean thrown = false;
        Test.startTest();
        try {
            FEC_COFFraudRelatedHandler.updateCase('', UPDATED_COMPLAIN_TYPE, UPDATED_COMPLAINT_SOURCE);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, thrown, 'Phải ném AuraHandledException khi thiếu Case ID');
    }
}
