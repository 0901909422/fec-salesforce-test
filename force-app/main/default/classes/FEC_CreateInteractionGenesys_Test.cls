@IsTest
private class FEC_CreateInteractionGenesys_Test {

    @TestSetup
    static void setupData() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            update new User(
                Id = UserInfo.getUserId(),
                FEC_Agent_ID__c = 'AGENT001'
            );
        }
    }

    @IsTest
    static void testCreateInteraction_Call() {
        FEC_CreateInteractionGenesys.GenesysRequest req = new FEC_CreateInteractionGenesys.GenesysRequest();
        req.type = FEC_ConstantCommon.CHANNEL_INBOUND_API;
        req.phoneNumber = '0901234567';
        req.genesysInteractionID = ('G123' + String.valueOf(System.currentTimeMillis()).right(16)).left(20);

        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        FEC_CreateInteractionGenesys.InteractionResult result =
            FEC_CreateInteractionGenesys.createInteraction(req);
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        System.assertEquals(
            true,
            result.isSuccess,
            'Expected success. Message: ' + result.message
        );
        System.assertNotEquals(null, result.recordId);
    }

    @IsTest
    static void testCreateInteraction_InvalidType() {
        FEC_CreateInteractionGenesys.GenesysRequest req = new FEC_CreateInteractionGenesys.GenesysRequest();
        req.type = 'INVALID';

        Test.startTest();
        FEC_CreateInteractionGenesys.InteractionResult result =
            FEC_CreateInteractionGenesys.createInteraction(req);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess);
    }

    @IsTest
    static void testCreateEmailInteraction_Success() {
        FEC_CreateInteractionGenesys.EmailGenesysRequest req = new FEC_CreateInteractionGenesys.EmailGenesysRequest();
        req.genesysInteractionID = ('E123' + String.valueOf(System.currentTimeMillis()).right(16)).left(20);
        req.fromEmail = 'customer@test.com';
        req.sendTo = 'support@fecredit.com.vn';
        req.agentID = 'AGENT001';

        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        FEC_CreateInteractionGenesys.InteractionResult result =
            FEC_CreateInteractionGenesys.createEmailInteraction(req);
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        System.assertEquals(true, result.isSuccess, result.message);

        Case createdCase = [
            SELECT Id, OwnerId
            FROM Case
            WHERE FEC_External_Interaction_ID__c = :req.genesysInteractionID
        ];
        System.assertEquals(UserInfo.getUserId(), createdCase.OwnerId, 'Owner phải là agent user.');
    }

    @IsTest
    static void testCreateInteractionFromChat_Success() {
        FEC_CreateInteractionGenesys.ChatHubCreateInteractionRequest req =
            new FEC_CreateInteractionGenesys.ChatHubCreateInteractionRequest();
        req.chatSession = new FEC_CreateInteractionGenesys.ChatSession();
        req.chatSession.sessionID = ('CHAT' + String.valueOf(System.currentTimeMillis()).right(16)).left(20);
        req.chatSession.chatChannel = 'facebook';
        req.chatSession.lastMessage = 'Xin chào, tôi cần hỗ trợ';
        req.customerInfo = new FEC_CreateInteractionGenesys.CustomerInfo();
        req.customerInfo.customerName = 'Test Chat';

        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        FEC_CreateInteractionGenesys.InteractionResult result =
            FEC_CreateInteractionGenesys.createInteractionFromChat(req);
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        System.assertEquals(true, result.isSuccess, result.message);

        Case createdCase = [
            SELECT FEC_Chat_History__c
            FROM Case
            WHERE Id = :result.recordId
        ];
        System.assertEquals('Xin chào, tôi cần hỗ trợ', createdCase.FEC_Chat_History__c);
    }

    @IsTest
    static void testCreateInteractionFromChat_PrefillsCustomerSearchFields() {
        FEC_CreateInteractionGenesys.ChatHubCreateInteractionRequest req =
            new FEC_CreateInteractionGenesys.ChatHubCreateInteractionRequest();
        req.chatSession = new FEC_CreateInteractionGenesys.ChatSession();
        req.chatSession.sessionID = ('CHF' + String.valueOf(System.currentTimeMillis()).right(17)).left(20);
        req.chatSession.chatChannel = 'webchat';
        req.customerInfo = new FEC_CreateInteractionGenesys.CustomerInfo();
        req.customerInfo.phoneNumber = '0909123456';
        req.customerInfo.decryptNationalID = '123456789';
        req.customerInfo.applicationID = 'APP123456';
        req.customerInfo.emailAddress = 'customer@test.com';
        req.customerInfo.contractNumber = '20140807-103046-0001';

        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        FEC_CreateInteractionGenesys.InteractionResult result =
            FEC_CreateInteractionGenesys.createInteractionFromChat(req);
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        System.assertEquals(true, result.isSuccess, result.message);

        Case createdCase = [
            SELECT FEC_Phone_Number__c, FEC_Search_Phone_Number__c,
                FEC_National_ID_Passport_ID__c, FEC_Search_National_ID__c,
                FEC_Application_ID__c, FEC_Search_Application_ID__c,
                FEC_Interaction_Email__c, FEC_Search_Email_Address__c,
                FEC_Contract_Number__c, FEC_Search_Contract_Number__c,
                FEC_Account_Number__c, FEC_Search_Account_Number__c
            FROM Case
            WHERE Id = :result.recordId
        ];
        System.assertEquals('0909123456', createdCase.FEC_Phone_Number__c);
        System.assertEquals('0909123456', createdCase.FEC_Search_Phone_Number__c);
        System.assertEquals('123456789', createdCase.FEC_National_ID_Passport_ID__c);
        System.assertEquals('APP123456', createdCase.FEC_Application_ID__c);
        System.assertEquals('customer@test.com', createdCase.FEC_Interaction_Email__c);
        System.assertEquals('20140807-103046-0001', createdCase.FEC_Contract_Number__c);
        System.assertEquals(null, createdCase.FEC_Account_Number__c);
    }
}