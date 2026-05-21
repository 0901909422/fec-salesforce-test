/**
 * Test class for FEC_ChatHistoryController
 * Covers: getChatMessages, saveManualChatHistory
 */
@isTest
private class FEC_ChatHistoryControllerTest {

    @testSetup
    static void setupTestData() {
        // Case có chat automation
        Case chatAutoCase = new Case(
            Subject = 'Chat Automation Case',
            Status = 'New',
            FEC_Is_Chat_Automation__c = true,
            FEC_Chat_History__c = 'Manual history content'
        );
        insert chatAutoCase;

        // Case thường (không có chat automation)
        Case normalCase = new Case(
            Subject = 'Normal Case',
            Status = 'New',
            FEC_Is_Chat_Automation__c = false
        );
        insert normalCase;

        // Tạo Chat History records cho chatAutoCase
        List<FEC_ChatHistory__c> histories = new List<FEC_ChatHistory__c>();
        histories.add(new FEC_ChatHistory__c(
            FEC_Case__c = chatAutoCase.Id,
            FEC_SessionID__c = 'session-auto-001',
            FEC_Message__c = 'Xin chào',
            FEC_MessageType__c = 'text',
            FEC_SenderName__c = 'Customer',
            FEC_IsAgent__c = false,
            FEC_CreatedAt__c = Datetime.now().addMinutes(-5)
        ));
        histories.add(new FEC_ChatHistory__c(
            FEC_Case__c = chatAutoCase.Id,
            FEC_SessionID__c = 'session-auto-001',
            FEC_Message__c = 'Tôi có thể giúp gì?',
            FEC_MessageType__c = 'text',
            FEC_SenderName__c = 'Agent',
            FEC_IsAgent__c = true,
            FEC_CreatedAt__c = Datetime.now()
        ));
        histories.add(new FEC_ChatHistory__c(
            FEC_Case__c = chatAutoCase.Id,
            FEC_SessionID__c = 'session-auto-001',
            FEC_Message__c = 'document.pdf',
            FEC_MessageType__c = 'attachment',
            FEC_SenderName__c = 'Customer',
            FEC_IsAgent__c = false,
            FEC_CreatedAt__c = Datetime.now().addMinutes(-3)
        ));
        insert histories;

        // Tạo ContentVersion (file đính kèm) cho chatAutoCase
        ContentVersion cv1 = new ContentVersion(
            Title = 'document',
            PathOnClient = 'document.pdf',
            VersionData = Blob.valueOf('PDF content here'),
            FirstPublishLocationId = chatAutoCase.Id,
            IsMajorVersion = true
        );
        ContentVersion cv2 = new ContentVersion(
            Title = 'screenshot',
            PathOnClient = 'screenshot.png',
            VersionData = Blob.valueOf('PNG content here'),
            FirstPublishLocationId = chatAutoCase.Id,
            IsMajorVersion = true
        );
        insert new List<ContentVersion>{ cv1, cv2 };
    }

    // ---------------------------------------------------------
    // TEST: getChatMessages
    // ---------------------------------------------------------

    @isTest
    static void testGetChatMessages_WithChatAutomation() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Chat Automation Case' LIMIT 1];

        Test.startTest();
        FEC_ChatHistoryController.ChatDataWrapper result = FEC_ChatHistoryController.getChatMessages(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(3, result.messages.size(), 'Should return 3 chat messages');
        System.assertEquals(true, result.isChatAutomation, 'Should be chat automation case');
        System.assertEquals(true, result.hasManualChatHistory, 'Should have manual chat history');
        System.assertEquals('Manual history content', result.manualChatHistoryContent, 'Manual chat history content should match');
        
        // Verify file map
        System.assertNotEquals(null, result.fileMap, 'File map should not be null');
        System.assert(
            result.fileMap.containsKey('document') || result.fileMap.containsKey('document.pdf'),
            'File map should contain document file'
        );
        System.assert(
            result.fileMap.containsKey('screenshot') || result.fileMap.containsKey('screenshot.png'),
            'File map should contain screenshot file'
        );
    }

    @isTest
    static void testGetChatMessages_NormalCase_NoMessages() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Normal Case' LIMIT 1];

        Test.startTest();
        FEC_ChatHistoryController.ChatDataWrapper result = FEC_ChatHistoryController.getChatMessages(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.messages.size(), 'Should return 0 messages for normal case');
        System.assertEquals(false, result.isChatAutomation, 'Should not be chat automation');
        System.assertEquals(false, result.hasManualChatHistory, 'Should not have manual chat history');
        System.assertEquals(null, result.manualChatHistoryContent, 'Manual chat history content should be null');
        System.assert(result.fileMap.isEmpty(), 'File map should be empty');
    }

    @isTest
    static void testGetChatMessages_MessagesOrderedByCreatedAt() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Chat Automation Case' LIMIT 1];

        Test.startTest();
        FEC_ChatHistoryController.ChatDataWrapper result = FEC_ChatHistoryController.getChatMessages(testCase.Id);
        Test.stopTest();

        // Verify messages are ordered by FEC_CreatedAt__c ASC
        for (Integer i = 1; i < result.messages.size(); i++) {
            System.assert(
                result.messages[i].FEC_CreatedAt__c >= result.messages[i - 1].FEC_CreatedAt__c,
                'Messages should be ordered by CreatedAt ascending'
            );
        }
    }

    // ---------------------------------------------------------
    // TEST: saveManualChatHistory
    // ---------------------------------------------------------

    @isTest
    static void testSaveManualChatHistory_Success() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Normal Case' LIMIT 1];
        String message = 'Đây là nội dung chat history thủ công';

        Test.startTest();
        FEC_ChatHistoryController.saveManualChatHistory(testCase.Id, message);
        Test.stopTest();

        Case updatedCase = [SELECT FEC_Chat_History__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(message, updatedCase.FEC_Chat_History__c, 'Chat history should be saved to Case');
    }

    @isTest
    static void testSaveManualChatHistory_OverwriteExisting() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Chat Automation Case' LIMIT 1];
        String newMessage = 'Nội dung mới thay thế';

        Test.startTest();
        FEC_ChatHistoryController.saveManualChatHistory(testCase.Id, newMessage);
        Test.stopTest();

        Case updatedCase = [SELECT FEC_Chat_History__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(newMessage, updatedCase.FEC_Chat_History__c, 'Chat history should be overwritten');
    }

    @isTest
    static void testSaveManualChatHistory_BlankMessage() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Normal Case' LIMIT 1];

        Test.startTest();
        try {
            FEC_ChatHistoryController.saveManualChatHistory(testCase.Id, '');
            System.assert(false, 'Expected AuraHandledException for blank message');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Message cannot be blank'), 'Error message should indicate blank message');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveManualChatHistory_NullMessage() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Normal Case' LIMIT 1];

        Test.startTest();
        try {
            FEC_ChatHistoryController.saveManualChatHistory(testCase.Id, null);
            System.assert(false, 'Expected AuraHandledException for null message');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Message cannot be blank'), 'Error message should indicate blank message');
        }
        Test.stopTest();
    }
}
