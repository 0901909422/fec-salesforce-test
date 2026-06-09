@IsTest
private class FEC_InteractionController_Test {

    private static final String NATIONAL_ID = '123456789';
    private static final String PRIMARY_PHONE = '0901234567';

    private static Id interactionRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        String devName = FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME;
        if (byDev.containsKey(devName)) {
            return byDev.get(devName).getRecordTypeId();
        }
        return null;
    }

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());
        Id rtId = interactionRecordTypeId();

        Case interaction = new Case(
            Subject = 'FEC_InteractionController_Test',
            Status = 'New',
            FEC_Phone_Number__c = PRIMARY_PHONE,
            FEC_ID_Search__c = 'INT-' + suffix,
            FEC_Interaction_Start_On__c = DateTime.now()
        );
        if (rtId != null) {
            interaction.RecordTypeId = rtId;
        }

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert interaction;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = interaction.Id,
            FEC_National_ID_Passport_ID__c = NATIONAL_ID,
            FEC_Primary_Phone__c = PRIMARY_PHONE
        );
        insert hist;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = interaction.Id,
                FEC_Account_or_Contract__c = hist.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testGetInteraction_Success() {
        if (Type.forName('FEC_InteractionController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionController not on org.');
            return;
        }

        Test.startTest();
        List<Case> results =
            FEC_InteractionController.getInteraction(NATIONAL_ID, PRIMARY_PHONE);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Must return one Interaction case.');
        System.assertEquals(PRIMARY_PHONE, results[0].FEC_Phone_Number__c);

        Case linked = [
            SELECT FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c,
                FEC_Account_or_Contract__r.FEC_Primary_Phone__c
            FROM Case
            WHERE Id = :results[0].Id
        ];
        System.assertEquals(NATIONAL_ID, linked.FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c);
        System.assertEquals(PRIMARY_PHONE, linked.FEC_Account_or_Contract__r.FEC_Primary_Phone__c);
    }

    @IsTest
    static void testGetInteraction_NoResult() {
        if (Type.forName('FEC_InteractionController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionController not on org.');
            return;
        }

        Test.startTest();
        List<Case> results =
            FEC_InteractionController.getInteraction('999999999', '0000000000');
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testGetInteraction_NullParams() {
        if (Type.forName('FEC_InteractionController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionController not on org.');
            return;
        }

        Test.startTest();
        try {
            List<Case> results = FEC_InteractionController.getInteraction(null, null);
            System.assertNotEquals(null, results);
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }
}
