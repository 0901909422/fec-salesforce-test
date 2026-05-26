@IsTest
private class FEC_CreateCaseHandler_Test {

    @TestSetup
    static void setupData() {
        insert new FEC_Category__c(
            Name = FEC_ConstantCommon.FEC_CATEGORY_REQUEST,
            FEC_Code__c = 'Request',
            FEC_Active__c = true
        );

        Id interactionRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();
        String suffix = String.valueOf(System.currentTimeMillis());

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                RecordTypeId = interactionRtId,
                Subject = 'Setup Interaction',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
                FEC_Interaction_Subchannel__c = FEC_ConstantCommon.CHANNEL_INBOUND_SUBCHANNEL_NAME,
                FEC_ID_Search__c = 'CCH-' + suffix
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testCreateInteractionCase() {
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto = new FEC_CreateCaseHandler.FEC_InteractionCaseDTO();
        dto.channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        dto.subChannel = FEC_ConstantCommon.CHANNEL_INBOUND_SUBCHANNEL_NAME;
        dto.phoneNumber = '0901234567';

        Test.startTest();
        FEC_CreateCaseHandler.FEC_InteractionCaseResponse res = FEC_CreateCaseHandler.createInteractionCase(dto);
        Test.stopTest();

        System.assertNotEquals(null, res.caseId, 'Case Id phải được tạo.');
    }

    @IsTest
    static void testCreateCustomerCase() {
        Id interactionId = [
            SELECT Id FROM Case
            WHERE RecordType.DeveloperName = :FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
            LIMIT 1
        ].Id;
        FEC_Category__c cat = [SELECT Id FROM FEC_Category__c LIMIT 1];

        FEC_CreateCaseHandler.FEC_CustomerCaseDTO dto = new FEC_CreateCaseHandler.FEC_CustomerCaseDTO();
        dto.customerName = 'Test Customer';
        dto.categoryId = cat.Id;

        Test.startTest();
        Case c = FEC_CreateCaseHandler.createCustomerCase(dto, interactionId);
        Test.stopTest();

        System.assertNotEquals(null, c.Id, 'Customer Case phải được tạo.');
        System.assertEquals(interactionId, c.FEC_Interaction__c);
    }

    @IsTest
    static void testCreateInternalCase() {
        Test.startTest();
        Id caseId = FEC_CreateCaseHandler.createInternalCase('Test Internal', '123456789');
        Test.stopTest();

        Case c = [SELECT Status, FEC_Customer_Name__c FROM Case WHERE Id = :caseId];
        System.assertEquals('Test Internal', c.FEC_Customer_Name__c);
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_NEW, c.Status);
    }

    @IsTest
    static void testUpdateInteractionCaseWithCustomerHistory() {
        Id interactionRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();

        Case interaction;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            interaction = new Case(
                RecordTypeId = interactionRtId,
                Subject = 'Interaction Auto Close',
                FEC_ID_Search__c = 'CCH-AC-' + String.valueOf(System.currentTimeMillis())
            );
            insert interaction;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_CreateCaseHandler.updateInteractionCaseWithCustomerHistory(interaction.Id, null);
        Test.stopTest();

        Case updated = [SELECT Status FROM Case WHERE Id = :interaction.Id];
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_AUTO_CLOSED, updated.Status);
    }

    @IsTest
    static void testCreateInteractionCaseChat() {
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto = new FEC_CreateCaseHandler.FEC_InteractionCaseDTO();
        dto.channel = FEC_ConstantCommon.CHANNEL_CHAT;

        Test.startTest();
        FEC_CreateCaseHandler.FEC_InteractionCaseResponse res = FEC_CreateCaseHandler.createInteractionCaseChat(dto);
        Test.stopTest();

        System.assertNotEquals(null, res.caseId);
    }
}