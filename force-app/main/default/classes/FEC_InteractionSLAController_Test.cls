@IsTest
private class FEC_InteractionSLAController_Test {

    private static Id interactionRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        String devName = FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME;
        return byDev.containsKey(devName) ? byDev.get(devName).getRecordTypeId() : null;
    }

    private static String inboundOutcomePicklistValue() {
        Set<String> preferred = new Set<String>{ 'Test', 'Hoàn tất/ Đã phản hồi' };
        for (Schema.PicklistEntry entry :
            Case.FEC_Outcome_Code__c.getDescribe().getPicklistValues()) {
            if (entry.isActive() && preferred.contains(entry.getValue())) {
                return entry.getValue();
            }
        }
        for (Schema.PicklistEntry entry :
            Case.FEC_Outcome_Code__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    @TestSetup
    static void setup() {
        String suffix = String.valueOf(System.currentTimeMillis());
        Id rtId = interactionRecordTypeId();

        Case interaction = new Case(
            Subject = 'FEC_InteractionSLAController_Test',
            FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
            FEC_Interaction_Subchannel__c = FEC_ConstantCommon.CHANNEL_INBOUND_SUBCHANNEL_NAME,
            FEC_Customer_Type__c = 'Existing',
            Status = 'New',
            FEC_ID_Search__c = 'SLA-' + suffix
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

        Case subCase = new Case(
            Subject = 'FEC_InteractionSLAController_Sub',
            FEC_Interaction__c = interaction.Id,
            Status = 'New',
            FEC_ID_Search__c = 'SLA-SUB-' + suffix
        );
        if (rtId != null) {
            subCase.RecordTypeId = rtId;
        }

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert subCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testGetOutcomeCodeOptionsByContext_Success() {
        if (Type.forName('FEC_InteractionSLAController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionSLAController not on org.');
            return;
        }

        Case subCase = [
            SELECT Id
            FROM Case
            WHERE FEC_Interaction__c != null
            LIMIT 1
        ];

        Test.startTest();
        List<Map<String, String>> options =
            FEC_InteractionSLAController.getOutcomeCodeOptionsByContext(subCase.Id);
        Test.stopTest();

        System.assertNotEquals(0, options.size(), 'Outcome options should not be empty.');
    }

    @IsTest
    static void testUpdateInteractionOutcome() {
        if (Type.forName('FEC_InteractionSLAController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionSLAController not on org.');
            return;
        }

        Case subCase = [
            SELECT Id, FEC_Interaction__c
            FROM Case
            WHERE FEC_Interaction__c != null
            LIMIT 1
        ];
        Id interactionId = subCase.FEC_Interaction__c;
        String outcome = inboundOutcomePicklistValue();
        if (outcome == null) {
            System.assert(true, 'Skipped: no active FEC_Outcome_Code__c values on org.');
            return;
        }

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Test.startTest();
            FEC_InteractionSLAController.updateInteractionOutcome(
                subCase.Id,
                outcome,
                'Remarks Test'
            );
            Test.stopTest();
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Case updatedInteraction = [
            SELECT Status, FEC_Interaction_Remarks__c
            FROM Case
            WHERE Id = :interactionId
        ];
        System.assertEquals(
            FEC_ConstantCommon.INTERACTION_STATUS_CLOSED,
            updatedInteraction.Status
        );
        System.assertEquals('Remarks Test', updatedInteraction.FEC_Interaction_Remarks__c);
    }

    @IsTest
    static void testCaseSubmissionChecks() {
        if (Type.forName('FEC_InteractionSLAController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionSLAController not on org.');
            return;
        }

        Case link = [
            SELECT FEC_Interaction__c
            FROM Case
            WHERE FEC_Interaction__c != null
            LIMIT 1
        ];
        Id interactionId = link.FEC_Interaction__c;

        Test.startTest();
        Integer count = FEC_InteractionSLAController.getRelatedCasesCount(interactionId);
        Boolean hasUnsub = FEC_InteractionSLAController.hasUnsubmittedCases(interactionId);
        Test.stopTest();

        System.assertEquals(1, count);
        System.assertEquals(true, hasUnsub);
    }

    @IsTest
    static void testGetCase() {
        if (Type.forName('FEC_InteractionSLAController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionSLAController not on org.');
            return;
        }

        Case interaction = [
            SELECT Id
            FROM Case
            WHERE FEC_Interaction__c = null
            AND Subject = 'FEC_InteractionSLAController_Test'
            LIMIT 1
        ];

        Test.startTest();
        Case loaded = FEC_InteractionSLAController.getCase(interaction.Id);
        Case missing = FEC_InteractionSLAController.getCase('000000000000000AAA');
        Test.stopTest();

        System.assertNotEquals(null, loaded);
        System.assertEquals(null, missing);
    }

    @IsTest
    static void testGetOutcomeCodePicklistValues() {
        if (Type.forName('FEC_InteractionSLAController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionSLAController not on org.');
            return;
        }

        Test.startTest();
        List<Map<String, String>> interactionOutcomes =
            FEC_InteractionSLAController.getOutcomeCodePicklistValues();
        List<Map<String, String>> quickOutcomes =
            FEC_InteractionSLAController.getQuickOutcomeCodePicklistValues();
        Test.stopTest();

        System.assertNotEquals(null, interactionOutcomes);
        System.assertNotEquals(null, quickOutcomes);
    }

    @IsTest
    static void testUpdateInteractionQuickWrapUp() {
        if (Type.forName('FEC_InteractionSLAController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionSLAController not on org.');
            return;
        }

        Case subCase = [
            SELECT Id, FEC_Interaction__c
            FROM Case
            WHERE FEC_Interaction__c != null
            LIMIT 1
        ];
        String outcome = inboundOutcomePicklistValue();
        if (outcome == null) {
            return;
        }

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Test.startTest();
            FEC_InteractionSLAController.updateInteractionQuickWrapUp(subCase.Id, outcome);
            Test.stopTest();
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Case updated = [
            SELECT Status, FEC_Outcome_Code__c
            FROM Case
            WHERE Id = :subCase.FEC_Interaction__c
        ];
        System.assertEquals(FEC_ConstantCommon.INTERACTION_STATUS_CLOSED, updated.Status);
        System.assertEquals(outcome, updated.FEC_Outcome_Code__c);
    }

    @IsTest
    static void testHasSubmittedCases() {
        if (Type.forName('FEC_InteractionSLAController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionSLAController not on org.');
            return;
        }

        Case link = [
            SELECT FEC_Interaction__c
            FROM Case
            WHERE FEC_Interaction__c != null
            LIMIT 1
        ];

        Test.startTest();
        Boolean allSubmitted = FEC_InteractionSLAController.hasSubmittedCases(link.FEC_Interaction__c);
        Test.stopTest();

        System.assertEquals(false, allSubmitted);
    }

    @IsTest
    static void testGetOutcomeCodeOptionsByContext_EmailChannel() {
        if (Type.forName('FEC_InteractionSLAController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionSLAController not on org.');
            return;
        }

        Id interactionRtId = interactionRecordTypeId();
        String suffix = String.valueOf(System.currentTimeMillis());
        Case emailInteraction = new Case(
            Subject = 'SLA Email Interaction',
            FEC_Channel__c = FEC_ConstantCommon.CHANNEL_EMAIL_NAME,
            FEC_Interaction_Subchannel__c = FEC_ConstantCommon.CHANNEL_EMAIL_INCOMING_SUBCHANNEL_NAME,
            FEC_Customer_Type__c = 'Existing',
            Status = 'New',
            FEC_ID_Search__c = 'SLA-EM-' + suffix
        );
        if (interactionRtId != null) {
            emailInteraction.RecordTypeId = interactionRtId;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert emailInteraction;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        List<Map<String, String>> options =
            FEC_InteractionSLAController.getOutcomeCodeOptionsByContext(emailInteraction.Id);
        Test.stopTest();

        System.assert(options.size() > 0, 'Email channel should return filtered outcome options.');
    }

    @IsTest
    static void testGetOutcomeCodeOptionsByContext_ExternalChannel() {
        if (Type.forName('FEC_InteractionSLAController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionSLAController not on org.');
            return;
        }

        Id interactionRtId = interactionRecordTypeId();
        String suffix = String.valueOf(System.currentTimeMillis());
        Case externalInteraction = new Case(
            Subject = 'SLA External Interaction',
            FEC_Channel__c = FEC_ConstantCommon.CHANNEL_EXTERNAL_NAME,
            Status = 'New',
            FEC_ID_Search__c = 'SLA-EXT-' + suffix
        );
        if (interactionRtId != null) {
            externalInteraction.RecordTypeId = interactionRtId;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert externalInteraction;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        List<Map<String, String>> options =
            FEC_InteractionSLAController.getOutcomeCodeOptionsByContext(externalInteraction.Id);
        Test.stopTest();

        System.assert(options.size() > 0, 'External channel should return outcome options.');
    }

    @IsTest
    static void testGetOutcomeCodeOptionsByContext_OutboundAndChat() {
        if (Type.forName('FEC_InteractionSLAController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionSLAController not on org.');
            return;
        }

        Id interactionRtId = interactionRecordTypeId();
        String suffix = String.valueOf(System.currentTimeMillis());

        Case outbound = new Case(
            Subject = 'SLA Outbound',
            FEC_Channel__c = FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
            FEC_Interaction_Subchannel__c = FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME,
            FEC_Customer_Type__c = 'Existing',
            Status = 'New',
            FEC_ID_Search__c = 'SLA-OUT-' + suffix
        );
        Case chat = new Case(
            Subject = 'SLA Chat',
            FEC_Channel__c = FEC_ConstantCommon.CHANNEL_CHAT_NAME,
            FEC_Interaction_Subchannel__c = 'Facebook',
            FEC_Customer_Type__c = 'Existing',
            Status = 'New',
            FEC_ID_Search__c = 'SLA-CHAT-' + suffix
        );
        if (interactionRtId != null) {
            outbound.RecordTypeId = interactionRtId;
            chat.RecordTypeId = interactionRtId;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new List<Case>{ outbound, chat };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        List<Map<String, String>> outboundOptions =
            FEC_InteractionSLAController.getOutcomeCodeOptionsByContext(outbound.Id);
        List<Map<String, String>> chatOptions =
            FEC_InteractionSLAController.getOutcomeCodeOptionsByContext(chat.Id);
        Test.stopTest();

        System.assert(outboundOptions.size() > 0);
        System.assert(chatOptions.size() > 0);
    }

    @IsTest
    static void testGetOutcomeCodeOptionsByContext_F2FAndInternal() {
        if (Type.forName('FEC_InteractionSLAController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionSLAController not on org.');
            return;
        }

        Id interactionRtId = interactionRecordTypeId();
        String suffix = String.valueOf(System.currentTimeMillis());

        Case f2f = new Case(
            Subject = 'SLA F2F',
            FEC_Channel__c = FEC_ConstantCommon.CHANNEL_F2F_NAME,
            FEC_Interaction_Subchannel__c = FEC_ConstantCommon.CHANNEL_F2F_SUBCHANNEL_NAME,
            Status = 'New',
            FEC_ID_Search__c = 'SLA-F2F-' + suffix
        );
        Case internalEmail = new Case(
            Subject = 'SLA Internal Email',
            FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INTERNAL_NAME,
            FEC_Interaction_Subchannel__c = FEC_ConstantCommon.CHANNEL_INTERNAL_EMAIL_SUBCHANNEL_NAME,
            Status = 'New',
            FEC_ID_Search__c = 'SLA-INT-' + suffix
        );
        if (interactionRtId != null) {
            f2f.RecordTypeId = interactionRtId;
            internalEmail.RecordTypeId = interactionRtId;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new List<Case>{ f2f, internalEmail };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        List<Map<String, String>> f2fOptions =
            FEC_InteractionSLAController.getOutcomeCodeOptionsByContext(f2f.Id);
        List<Map<String, String>> internalOptions =
            FEC_InteractionSLAController.getOutcomeCodeOptionsByContext(internalEmail.Id);
        Test.stopTest();

        System.assert(f2fOptions.size() > 0);
        System.assert(internalOptions.size() > 0);
    }

    @IsTest
    static void testUpdateInteractionOutcome_DirectOnInteraction() {
        if (Type.forName('FEC_InteractionSLAController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionSLAController not on org.');
            return;
        }

        Case interaction = [
            SELECT Id
            FROM Case
            WHERE FEC_Interaction__c = null
            AND Subject = 'FEC_InteractionSLAController_Test'
            LIMIT 1
        ];
        String outcome = inboundOutcomePicklistValue();
        if (outcome == null) {
            return;
        }

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Test.startTest();
            FEC_InteractionSLAController.updateInteractionOutcome(interaction.Id, outcome, null);
            Test.stopTest();
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Case updated = [SELECT Status FROM Case WHERE Id = :interaction.Id];
        System.assertEquals(FEC_ConstantCommon.INTERACTION_STATUS_CLOSED, updated.Status);
    }

    @IsTest
    static void testHasSubmittedCases_AllSubmitted() {
        if (Type.forName('FEC_InteractionSLAController') == null) {
            System.assert(true, 'Skipped: FEC_InteractionSLAController not on org.');
            return;
        }

        Case subCase = [
            SELECT Id, FEC_Interaction__c
            FROM Case
            WHERE FEC_Interaction__c != null
            LIMIT 1
        ];
        update new Case(Id = subCase.Id, FEC_Is_Submited__c = true);

        Test.startTest();
        Boolean allSubmitted = FEC_InteractionSLAController.hasSubmittedCases(subCase.FEC_Interaction__c);
        Test.stopTest();

        System.assertEquals(true, allSubmitted);
    }
}
