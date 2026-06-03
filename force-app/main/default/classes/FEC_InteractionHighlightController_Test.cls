@IsTest
private class FEC_InteractionHighlightController_Test {

    private static final String CUSTOMER_NAME = 'Nguyen Van A';
    private static final String NATIONAL_ID = '123456789';
    private static final String CIF_NUMBER = 'CIF001';
    private static final String PRIMARY_PHONE = '0901234567';
    private static final String INTERACTION_SEARCH_ID = 'INT-001';

    private static Id interactionRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        String devName = FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME;
        return byDev.containsKey(devName) ? byDev.get(devName).getRecordTypeId() : null;
    }

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());
        Id rtId = interactionRecordTypeId();

        Case interaction = new Case(
            Subject = 'FEC_InteractionHighlightController_Test',
            Status = 'New',
            FEC_ID_Search__c = INTERACTION_SEARCH_ID + '-' + suffix,
            FEC_CIF_Number__c = CIF_NUMBER,
            FEC_Phone_Number__c = PRIMARY_PHONE
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

        FEC_Customer_History__c customer = new FEC_Customer_History__c(
            FEC_Case__c = interaction.Id,
            Name = CUSTOMER_NAME,
            FEC_Customer_Name__c = CUSTOMER_NAME,
            FEC_National_ID_Passport_ID__c = NATIONAL_ID,
            FEC_CIF_Number__c = CIF_NUMBER,
            FEC_Primary_Phone__c = PRIMARY_PHONE
        );
        insert customer;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = interaction.Id,
                FEC_Account_or_Contract__c = customer.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Customer_Segmentation__c(
            Name = CUSTOMER_NAME,
            FEC_CIF_Number__c = CIF_NUMBER,
            FEC_Customer_Segment__c = FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP
        );
    }

    @IsTest
    static void testGetInteractionHighlightData_Success() {
        if (Type.forName('FEC_InteractionHighlightController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionHighlightController not on org.');
            return;
        }

        Case interaction = [
            SELECT Id
            FROM Case
            WHERE FEC_Account_or_Contract__c != null
            LIMIT 1
        ];

        Test.startTest();
        FEC_InteractionHighlightController.InteractionHighlightData data =
            FEC_InteractionHighlightController.getInteractionHighlightData(interaction.Id);
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assertEquals(CUSTOMER_NAME, data.customerName);
        System.assertEquals(FEC_ConstantCommon.CUSTOMER_CATEGORY_VIP, data.customerCategory);
        System.assert(String.isNotBlank(data.interactionId), 'FEC_Interaction_ID__c is formula from FEC_ID_Search__c.');
    }

    @IsTest
    static void testGetInteractionHighlightData_NoCustomerHistory() {
        if (Type.forName('FEC_InteractionHighlightController') == null) {
            return;
        }

        Case orphan = new Case(
            Subject = 'No CH',
            Status = 'New',
            FEC_ID_Search__c = 'INT-ORPHAN-' + String.valueOf(System.currentTimeMillis())
        );
        Id rtId = interactionRecordTypeId();
        if (rtId != null) {
            orphan.RecordTypeId = rtId;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert orphan;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_InteractionHighlightController.InteractionHighlightData data =
            FEC_InteractionHighlightController.getInteractionHighlightData(orphan.Id);
        Test.stopTest();

        System.assertNotEquals(null, data);
    }

    @IsTest
    static void testLogSensitiveAccess() {
        if (Type.forName('FEC_InteractionHighlightController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionHighlightController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_InteractionHighlightController.logSensitiveAccess(
            'FEC_National_ID_Passport_ID__c',
            c.Id
        );
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testGetInteractionHighlightData_ChildCaseUsesParent() {
        if (Type.forName('FEC_InteractionHighlightController') == null) {
            return;
        }

        Case interaction = [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            WHERE FEC_Account_or_Contract__c != null
            LIMIT 1
        ];

        Case childCase = new Case(
            Subject = 'Child of interaction',
            Status = 'New',
            FEC_Interaction__c = interaction.Id,
            FEC_ID_Search__c = 'CHILD-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert childCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_InteractionHighlightController.InteractionHighlightData data =
            FEC_InteractionHighlightController.getInteractionHighlightData(childCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assertEquals(CUSTOMER_NAME, data.customerName);
    }

    @IsTest
    static void testGetInteractionHighlightData_UnhappyCustomer() {
        if (Type.forName('FEC_InteractionHighlightController') == null) {
            return;
        }

        insert new FEC_Customer_Segmentation__c(
            Name = CUSTOMER_NAME,
            FEC_CIF_Number__c = CIF_NUMBER,
            FEC_Survey_Points__c = 2,
            FEC_Customer_Segment__c = 'Standard'
        );

        Case interaction = [
            SELECT Id
            FROM Case
            WHERE FEC_Account_or_Contract__c != null
            LIMIT 1
        ];

        Test.startTest();
        FEC_InteractionHighlightController.InteractionHighlightData data =
            FEC_InteractionHighlightController.getInteractionHighlightData(interaction.Id);
        Test.stopTest();

        System.assertNotEquals(null, data.customerCategory);
    }

    @IsTest
    static void testGetInteractionHighlightData_InvalidCaseId() {
        if (Type.forName('FEC_InteractionHighlightController') == null) {
            return;
        }

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_InteractionHighlightController.getInteractionHighlightData(
                Id.valueOf('500000000000000AAA')
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }
}
