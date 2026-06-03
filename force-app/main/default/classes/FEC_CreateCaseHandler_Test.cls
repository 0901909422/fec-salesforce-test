@IsTest
private class FEC_CreateCaseHandler_Test {

    @TestSetup
    static void setupData() {
        insert new List<FEC_Category__c>{
            new FEC_Category__c(
                Name = FEC_ConstantCommon.FEC_CATEGORY_REQUEST,
                FEC_Code__c = 'Request',
                FEC_Active__c = true
            ),
            new FEC_Category__c(
                Name = FEC_ConstantCommon.FEC_CATEGORY_COMPLAINT,
                FEC_Code__c = 'Complaint',
                FEC_Active__c = true
            )
        };

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

    private static Id getInteractionCaseId() {
        return [
            SELECT Id
            FROM Case
            WHERE RecordType.DeveloperName = :FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
            LIMIT 1
        ].Id;
    }

    @IsTest
    static void testCreateInteractionCase() {
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto = new FEC_CreateCaseHandler.FEC_InteractionCaseDTO();
        dto.channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        dto.subChannel = FEC_ConstantCommon.CHANNEL_INBOUND_SUBCHANNEL_NAME;
        dto.phoneNumber = '0901234567';
        dto.externalInteractionId = 'EXT-001';
        dto.campaignName = 'Campaign A';
        dto.transcription = 'Transcript';

        Test.startTest();
        FEC_CreateCaseHandler.FEC_InteractionCaseResponse res = FEC_CreateCaseHandler.createInteractionCase(dto);
        Test.stopTest();

        System.assertNotEquals(null, res.caseId);
        Case created = [SELECT Status, FEC_Channel__c FROM Case WHERE Id = :res.caseId];
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_OPEN, created.Status);
    }

    @IsTest
    static void testCreateInteractionCase_ChatPendingStatus() {
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto = new FEC_CreateCaseHandler.FEC_InteractionCaseDTO();
        dto.channel = FEC_ConstantCommon.CHANNEL_CHAT;
        dto.subChannel = 'WebChat';

        Test.startTest();
        FEC_CreateCaseHandler.FEC_InteractionCaseResponse res = FEC_CreateCaseHandler.createInteractionCase(dto);
        Test.stopTest();

        Case created = [SELECT Status FROM Case WHERE Id = :res.caseId];
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_PENDING, created.Status);
    }

    @IsTest
    static void testCreateInteractionCase_OtherSubChannel() {
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto = new FEC_CreateCaseHandler.FEC_InteractionCaseDTO();
        dto.channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        dto.subChannel = FEC_ConstantCommon.CHANNEL_EXTERNAL_SUBCHANNEL_OTHER_NAME;
        dto.otherSubChannel = 'Custom Sub';

        Test.startTest();
        FEC_CreateCaseHandler.FEC_InteractionCaseResponse res = FEC_CreateCaseHandler.createInteractionCase(dto);
        Test.stopTest();

        Case created = [
            SELECT FEC_Other_Subchannel__c
            FROM Case
            WHERE Id = :res.caseId
        ];
        System.assertEquals('Custom Sub', created.FEC_Other_Subchannel__c);
    }

    @IsTest
    static void testCreateInteractionCase_NullDto() {
        Test.startTest();
        try {
            FEC_CreateCaseHandler.createInteractionCase(null);
            System.assert(false, 'Phải throw khi DTO null.');
        } catch (IllegalArgumentException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateInteractionCaseMyCaseAPI() {
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto = new FEC_CreateCaseHandler.FEC_InteractionCaseDTO();
        dto.channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        dto.subChannel = FEC_ConstantCommon.CHANNEL_INBOUND_SUBCHANNEL_NAME;
        dto.phoneNumber = '0901111222';
        dto.email = 'mycase@example.com';
        dto.externalInteractionId = 'MYCASE-INT-1';
        dto.ownerUserId = UserInfo.getUserId();

        Test.startTest();
        FEC_CreateCaseHandler.FEC_InteractionCaseResponse res =
            FEC_CreateCaseHandler.createInteractionCaseMyCaseAPI(dto);
        Test.stopTest();

        System.assertNotEquals(null, res.caseId);
        Case created = [
            SELECT FEC_Is_Submited__c, FEC_Is_MyCaseAPI_Interaction__c, FEC_Interaction_Email__c
            FROM Case
            WHERE Id = :res.caseId
        ];
        System.assertEquals(true, created.FEC_Is_Submited__c);
        System.assertEquals(true, created.FEC_Is_MyCaseAPI_Interaction__c);
        System.assertEquals('mycase@example.com', created.FEC_Interaction_Email__c);
    }

    @IsTest
    static void testCreateInteractionCaseManual() {
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto = new FEC_CreateCaseHandler.FEC_InteractionCaseDTO();
        dto.channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        dto.subChannel = ' Manual ';

        Test.startTest();
        FEC_CreateCaseHandler.FEC_InteractionCaseResponse res =
            FEC_CreateCaseHandler.createInteractionCaseManual(dto);
        Test.stopTest();

        System.assertNotEquals(null, res.caseId);
        Case created = [
            SELECT FEC_Interaction_View_Mode__c, FEC_Interaction_Subchannel__c
            FROM Case
            WHERE Id = :res.caseId
        ];
        System.assertEquals(FEC_ConstantCommon.INTERACTION_HANDLING_MODE, created.FEC_Interaction_View_Mode__c);
        System.assertEquals('Manual', created.FEC_Interaction_Subchannel__c);
    }

    @IsTest
    static void testCreateInteractionCaseGenesys_Inbound() {
        FEC_CreateCaseHandler.FEC_InteractionCaseGenesysDTO dto =
            new FEC_CreateCaseHandler.FEC_InteractionCaseGenesysDTO();
        dto.type = FEC_ConstantCommon.CHANNEL_INBOUND_API;
        dto.genesysInteractionID = 'GEN-IN-1';
        dto.phoneNumber = '0903333444';
        dto.nationalId = '123456789';
        dto.contractNum = 'CONTRACT-1';
        dto.cardAccountNum = 'ACC-1';
        dto.campaignName = 'Genesys Campaign';
        dto.method = FEC_ConstantCommon.AUTO_METHOD;

        Test.startTest();
        Case created = FEC_CreateCaseHandler.createInteractionCaseGenesys(dto);
        Test.stopTest();

        System.assertNotEquals(null, created.Id);
        System.assertEquals(FEC_ConstantCommon.CHANNEL_INBOUND_NAME, created.FEC_Channel__c);
        Case reloaded = [
            SELECT FEC_Interaction_View_Mode__c
            FROM Case
            WHERE Id = :created.Id
        ];
        System.assertEquals(FEC_ConstantCommon.INTERACTION_HANDLING_MODE, reloaded.FEC_Interaction_View_Mode__c);
    }

    @IsTest
    static void testCreateInteractionCaseGenesys_OutboundWithAgent() {
        FEC_CreateCaseHandler.FEC_InteractionCaseGenesysDTO dto =
            new FEC_CreateCaseHandler.FEC_InteractionCaseGenesysDTO();
        dto.type = FEC_ConstantCommon.CHANNEL_OUTBOUND_API;
        dto.genesysInteractionID = 'GEN-OUT-1';
        dto.phoneNumber = '0905555666';
        dto.agentId = 'AGENT-TEST-001';

        Test.startTest();
        Case created = FEC_CreateCaseHandler.createInteractionCaseGenesys(dto);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME, created.FEC_Channel__c);
        User ownerUser = [
            SELECT FEC_Agent_ID__c
            FROM User
            WHERE Id = :created.OwnerId
            LIMIT 1
        ];
        System.assertEquals('AGENT-TEST-001', ownerUser.FEC_Agent_ID__c);
    }

    @IsTest
    static void testCreateCustomerCase() {
        Id interactionId = getInteractionCaseId();
        FEC_Category__c cat = [
            SELECT Id
            FROM FEC_Category__c
            WHERE Name = :FEC_ConstantCommon.FEC_CATEGORY_REQUEST
            LIMIT 1
        ];

        FEC_CreateCaseHandler.FEC_CustomerCaseDTO dto = new FEC_CreateCaseHandler.FEC_CustomerCaseDTO();
        dto.customerName = 'Test Customer';
        dto.categoryId = cat.Id;
        dto.phoneNumber = '0901234567';

        Test.startTest();
        Case c = FEC_CreateCaseHandler.createCustomerCase(dto, interactionId);
        Test.stopTest();

        System.assertNotEquals(null, c.Id);
        System.assertEquals(interactionId, c.FEC_Interaction__c);
    }

    @IsTest
    static void testCreateCustomerCase_ComplaintCategory() {
        Id interactionId = getInteractionCaseId();
        FEC_Category__c cat = [
            SELECT Id
            FROM FEC_Category__c
            WHERE Name = :FEC_ConstantCommon.FEC_CATEGORY_COMPLAINT
            LIMIT 1
        ];

        FEC_CreateCaseHandler.FEC_CustomerCaseDTO dto = new FEC_CreateCaseHandler.FEC_CustomerCaseDTO();
        dto.customerName = 'Complaint Customer';
        dto.categoryId = cat.Id;

        Test.startTest();
        Case c = FEC_CreateCaseHandler.createCustomerCase(dto, interactionId);
        Test.stopTest();

        System.assertNotEquals(null, c.Id);
        System.assertEquals(cat.Id, c.FEC_Category__c);
    }

    @IsTest
    static void testCreateCustomerCaseMyCaseAPI() {
        Id interactionId = getInteractionCaseId();
        FEC_Category__c cat = [
            SELECT Id
            FROM FEC_Category__c
            WHERE Name = :FEC_ConstantCommon.FEC_CATEGORY_REQUEST
            LIMIT 1
        ];

        FEC_CreateCaseHandler.FEC_CustomerCaseDTO dto = new FEC_CreateCaseHandler.FEC_CustomerCaseDTO();
        dto.customerName = 'MyCase Customer';
        dto.categoryId = cat.Id;
        dto.ownerUserId = UserInfo.getUserId();

        Test.startTest();
        Case c = FEC_CreateCaseHandler.createCustomerCaseMyCaseAPI(
            dto,
            interactionId,
            FEC_ConstantCommon.CHANNEL_INBOUND_NAME
        );
        Test.stopTest();

        System.assertEquals(true, c.FEC_Is_Submited__c);
        System.assertEquals(FEC_ConstantCommon.CHANNEL_INBOUND_NAME, c.FEC_Channel__c);
    }

    @IsTest
    static void testCreateInternalCase() {
        Test.startTest();
        Id caseId = FEC_CreateCaseHandler.createInternalCase('Test Internal', '123456789');
        Test.stopTest();

        Case c = [SELECT Status, FEC_Customer_Name__c FROM Case WHERE Id = :caseId];
        System.assertEquals('Test Internal', c.FEC_Customer_Name__c);
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_NEW, c.Status);
        System.assert(
            [SELECT COUNT() FROM FEC_Additional_Info__c WHERE FEC_Case__c = :caseId] > 0,
            'Phải tạo Additional Info.'
        );
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

        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = interaction.Id,
            FEC_Customer_Name__c = 'Hist Customer'
        );
        insert hist;

        Test.startTest();
        FEC_CreateCaseHandler.updateInteractionCaseWithCustomerHistory(interaction.Id, hist.Id);
        Test.stopTest();

        Case updated = [
            SELECT Status, FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :interaction.Id
        ];
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_AUTO_CLOSED, updated.Status);
        System.assertEquals(hist.Id, updated.FEC_Account_or_Contract__c);
    }

    @IsTest
    static void testGetCaseRecordTypeDevName() {
        Id interactionId = getInteractionCaseId();

        Test.startTest();
        String devName = FEC_CreateCaseHandler.getCaseRecordTypeDevName(interactionId);
        String nullName = FEC_CreateCaseHandler.getCaseRecordTypeDevName(null);
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME, devName);
        System.assertEquals(null, nullName);
    }

    @IsTest
    static void testCreateInteractionCaseChat() {
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto = new FEC_CreateCaseHandler.FEC_InteractionCaseDTO();
        dto.channel = FEC_ConstantCommon.CHANNEL_CHAT;
        dto.subChannel = FEC_ConstantCommon.CHANNEL_EXTERNAL_SUBCHANNEL_OTHER_NAME;
        dto.otherSubChannel = 'Chat Other';
        dto.customerName = 'Chat User';
        dto.phoneNumber = '0909999888';

        Test.startTest();
        FEC_CreateCaseHandler.FEC_InteractionCaseResponse res =
            FEC_CreateCaseHandler.createInteractionCaseChat(dto);
        Test.stopTest();

        System.assertNotEquals(null, res.caseId);
        Case created = [
            SELECT FEC_Channel__c, FEC_Customer_Username__c
            FROM Case
            WHERE Id = :res.caseId
        ];
        System.assertEquals(FEC_ConstantCommon.CHANNEL_CHAT, created.FEC_Channel__c);
        System.assertEquals('Chat User', created.FEC_Customer_Username__c);
    }

    @IsTest
    static void testCreateInteractionCaseChat_InvalidChannel() {
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto = new FEC_CreateCaseHandler.FEC_InteractionCaseDTO();
        dto.channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;

        Test.startTest();
        try {
            FEC_CreateCaseHandler.createInteractionCaseChat(dto);
            System.assert(false, 'Channel không phải CHAT phải throw exception.');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('CHAT'));
        }
        Test.stopTest();
    }
}
