/**
 * Test class for FEC_ChatHubCaseController
 * Covers: createCaseOnNewSession, saveChatHistoryAndAttachment,
 *         updateOldCaseInteractionId, createInteractionCaseChat
 */
@isTest
private class FEC_ChatHubCaseControllerTest {

    // HTTP Callout Mock để giả lập việc tải file
    private class FileDownloadHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'image/png');
            res.setBodyAsBlob(Blob.valueOf('Mock File Content'));
            res.setStatusCode(200);
            return res;
        }
    }

    @testSetup
    static void setupTestData() {
        Case testCase = new Case(
            Subject = 'Test Chat Case',
            Status = 'New',
            FEC_External_Interaction_ID__c = 'session-12345'
        );
        insert testCase;

        FEC_ChatHistory__c testHistory = new FEC_ChatHistory__c(
            FEC_Case__c = testCase.Id,
            FEC_SessionID__c = 'session-12345',
            FEC_Message__c = 'Hello Agent',
            FEC_MessageType__c = 'text',
            FEC_SenderName__c = 'Customer',
            FEC_IsAgent__c = false,
            FEC_CreatedAt__c = Datetime.now()
        );
        insert testHistory;

        ContentVersion cv = new ContentVersion(
            Title = 'test_image',
            PathOnClient = 'test_image.png',
            VersionData = Blob.valueOf('Test Image Body'),
            FirstPublishLocationId = testCase.Id,
            IsMajorVersion = true
        );
        insert cv;
    }

    // ---------------------------------------------------------
    // HELPERS
    // ---------------------------------------------------------

    private static Id interactionRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        return byDev.containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            ? byDev.get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME).getRecordTypeId()
            : null;
    }

    private static Case insertReviewInteractionCase(String externalId) {
        Case c = new Case(
            Subject = 'ChatHub Review Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_External_Interaction_ID__c = externalId,
            FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE
        );
        Id rtId = interactionRecordTypeId();
        if (rtId != null) {
            c.RecordTypeId = rtId;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    // ---------------------------------------------------------
    // TEST: createCaseOnNewSession
    // ---------------------------------------------------------

    @isTest
    static void testCreateCaseOnNewSession_Success() {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        Boolean hasRecordType = rtMap.containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);

        String jsonPayload = '{' +
            '"chatSession": {"chatChannel": "Web", "sessionID": "session-99999"},' +
            '"customerInfo": {"phoneNumber": "0987654321", "nationalID": "0123456789", "customerName": "Nguyen Van A", "kYCStatus": "Success"}' +
        '}';

        Test.startTest();
        if (hasRecordType) {
            FEC_ChatHubCaseController.CaseCreationResponse response = FEC_ChatHubCaseController.createCaseOnNewSession(jsonPayload);
            Test.stopTest();

            System.assertNotEquals(null, response, 'Response should not be null');
            System.assertNotEquals(null, response.caseId, 'Created Case ID should not be null');

            Case insertedCase = [SELECT Id, FEC_External_Interaction_ID__c, FEC_Phone_Number__c FROM Case WHERE Id = :response.caseId];
            System.assertEquals('session-99999', insertedCase.FEC_External_Interaction_ID__c, 'External Interaction ID should match sessionID');
            System.assertEquals('0987654321', insertedCase.FEC_Phone_Number__c, 'Phone number should map correctly');
        } else {
            try {
                FEC_ChatHubCaseController.CaseCreationResponse response = FEC_ChatHubCaseController.createCaseOnNewSession(jsonPayload);
                System.assert(false, 'Expected AuraHandledException when Record Type is missing');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception message should not be null');
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testCreateCaseOnNewSession_BlankData() {
        Test.startTest();
        FEC_ChatHubCaseController.CaseCreationResponse response = FEC_ChatHubCaseController.createCaseOnNewSession('');
        Test.stopTest();

        System.assertEquals(null, response, 'Should return null when blank JSON is passed');
    }

    @isTest
    static void testCreateCaseOnNewSession_NullData() {
        Test.startTest();
        FEC_ChatHubCaseController.CaseCreationResponse response = FEC_ChatHubCaseController.createCaseOnNewSession(null);
        Test.stopTest();

        System.assertEquals(null, response, 'Should return null when null is passed');
    }

    @isTest
    static void testCreateCaseOnNewSession_MissingSessionID() {
        // Thiếu sessionID không bị validate -> Case vẫn được tạo,
        // chỉ là FEC_External_Interaction_ID__c để trống.
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        Boolean hasRecordType = rtMap.containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);

        String jsonPayload = '{' +
            '"chatSession": {"chatChannel": "Web"},' +
            '"customerInfo": {"phoneNumber": "0987654321"}' +
        '}';

        Test.startTest();
        if (hasRecordType) {
            FEC_ChatHubCaseController.CaseCreationResponse response = FEC_ChatHubCaseController.createCaseOnNewSession(jsonPayload);
            Test.stopTest();
            System.assertNotEquals(null, response, 'Case vẫn được tạo dù thiếu sessionID');
            System.assertNotEquals(null, response.caseId, 'Created Case ID should not be null');
        } else {
            try {
                FEC_ChatHubCaseController.createCaseOnNewSession(jsonPayload);
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception message should not be null');
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testCreateCaseOnNewSession_MissingCustomerInfo() {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        Boolean hasRecordType = rtMap.containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);

        String jsonPayload = '{' +
            '"chatSession": {"chatChannel": "Zalo", "sessionID": "session-no-customer"}' +
        '}';

        Test.startTest();
        if (hasRecordType) {
            FEC_ChatHubCaseController.CaseCreationResponse response = FEC_ChatHubCaseController.createCaseOnNewSession(jsonPayload);
            Test.stopTest();
            System.assertNotEquals(null, response, 'Should still create case without customer info');
        } else {
            try {
                FEC_ChatHubCaseController.createCaseOnNewSession(jsonPayload);
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage());
            }
            Test.stopTest();
        }
    }

    // ---------------------------------------------------------
    // TEST: saveChatHistoryAndAttachment
    // ---------------------------------------------------------

    @isTest
    static void testSaveChatHistoryAndAttachment_Success() {
        Test.setMock(HttpCalloutMock.class, new FileDownloadHttpMock());

        String jsonHistoryList = '[' +
            '{"messageID": "msg-001", "sessionID": "session-12345", "senderName": "Agent 1", "message": "Hi there", "messageType": "text", "chatChannel": "Web", "isAgent": true, "createdAt": "2025-12-03T10:00:00Z"},' +
            '{"messageID": "msg-002", "sessionID": "session-12345", "senderName": "Customer", "fileName": "bug.png", "fileUrl": "https://example.com/bug.png", "messageType": "image", "chatChannel": "Web", "isAgent": false, "createdAt": "2025-12-03T10:05:00Z"}' +
        ']';

        Test.startTest();
        Boolean isSuccess = FEC_ChatHubCaseController.saveChatHistoryAndAttachment(jsonHistoryList, false);
        Test.stopTest();

        System.assertEquals(true, isSuccess, 'Save operation should return true on success');

        List<FEC_ChatHistory__c> chatLogs = [SELECT Id, FEC_MessageID__c, FEC_MessageType__c FROM FEC_ChatHistory__c WHERE FEC_SessionID__c = 'session-12345'];
        // Setup inserts 1 legacy history (messageID null). Payload adds 2 new (msg-001 text, msg-002 image).
        System.assertEquals(3, chatLogs.size(), 'Setup history + 2 new histories should exist');

        Integer cntNew = [SELECT COUNT() FROM FEC_ChatHistory__c WHERE FEC_MessageID__c IN ('msg-001', 'msg-002')];
        System.assertEquals(2, cntNew, 'Both new messageIDs should be persisted');

        List<ContentVersion> cvs = [SELECT Id, Title FROM ContentVersion WHERE FirstPublishLocationId IN (SELECT Id FROM Case WHERE FEC_External_Interaction_ID__c = 'session-12345')];
        System.assert(!cvs.isEmpty(), 'ContentVersion should have been created for the image attachment');
    }

    @isTest
    static void testSaveChatHistoryAndAttachment_DedupSamePayload() {
        // Simulate 2 ChatHub tabs/browsers submitting the same payload sequentially.
        Test.setMock(HttpCalloutMock.class, new FileDownloadHttpMock());

        String jsonHistoryList = '[' +
            '{"messageID": "msg-dup-001", "sessionID": "session-12345", "senderName": "Agent", "message": "Hello A", "messageType": "text", "chatChannel": "Web", "isAgent": true, "createdAt": "2025-12-03T10:00:00Z"},' +
            '{"messageID": "msg-dup-002", "sessionID": "session-12345", "senderName": "Agent", "message": "Hello B", "messageType": "text", "chatChannel": "Web", "isAgent": true, "createdAt": "2025-12-03T10:00:01Z"}' +
        ']';

        Test.startTest();
        FEC_ChatHubCaseController.saveChatHistoryAndAttachment(jsonHistoryList, false);
        // Second call with the same payload must NOT create duplicates.
        FEC_ChatHubCaseController.saveChatHistoryAndAttachment(jsonHistoryList, false);
        Test.stopTest();

        Integer dupCount = [SELECT COUNT() FROM FEC_ChatHistory__c WHERE FEC_MessageID__c IN ('msg-dup-001', 'msg-dup-002')];
        System.assertEquals(2, dupCount, 'Each unique messageID should be inserted exactly once even when called twice');
    }

    @isTest
    static void testSaveChatHistoryAndAttachment_DedupFallbackCompositeKey() {
        // Payload without messageID must still dedupe via the composite-key fallback
        // (CreatedAt|SenderName|MessageType) when called twice.
        Test.setMock(HttpCalloutMock.class, new FileDownloadHttpMock());

        String jsonHistoryList = '[' +
            '{"sessionID": "session-12345", "senderName": "Legacy Agent", "message": "Legacy 1", "messageType": "text", "chatChannel": "Web", "isAgent": true, "createdAt": "2025-12-03T13:00:00Z"},' +
            '{"sessionID": "session-12345", "senderName": "Legacy Agent", "message": "Legacy 2", "messageType": "text", "chatChannel": "Web", "isAgent": true, "createdAt": "2025-12-03T13:00:05Z"}' +
        ']';

        Test.startTest();
        FEC_ChatHubCaseController.saveChatHistoryAndAttachment(jsonHistoryList, false);
        FEC_ChatHubCaseController.saveChatHistoryAndAttachment(jsonHistoryList, false);
        Test.stopTest();

        Integer cnt = [SELECT COUNT() FROM FEC_ChatHistory__c WHERE FEC_SessionID__c = 'session-12345' AND FEC_SenderName__c = 'Legacy Agent'];
        System.assertEquals(2, cnt, 'Composite-key fallback must dedupe payloads without messageID');
    }

    @isTest
    static void testSaveChatHistoryAndAttachment_DedupViaDbUniqueConstraint() {
        // Pre-insert a chat history with a known messageID directly to DB.
        // Then submit a payload containing the SAME messageID — the in-memory pre-load set
        // already covers it, but this test guarantees the unique-constraint path is exercised.
        Case caseA = [SELECT Id FROM Case WHERE FEC_External_Interaction_ID__c = 'session-12345' LIMIT 1];

        FEC_ChatHistory__c existing = new FEC_ChatHistory__c(
            FEC_Case__c = caseA.Id,
            FEC_SessionID__c = 'other-session',
            FEC_MessageID__c = 'msg-shared-001',
            FEC_SenderName__c = 'Agent',
            FEC_Message__c = 'Existing',
            FEC_MessageType__c = 'text',
            FEC_IsAgent__c = true,
            FEC_CreatedAt__c = Datetime.now()
        );
        insert existing;

        String jsonHistoryList = '[' +
            '{"messageID": "msg-shared-001", "sessionID": "session-12345", "senderName": "Agent", "message": "Duplicate attempt", "messageType": "text", "chatChannel": "Web", "isAgent": true, "createdAt": "2025-12-03T14:00:00Z"}' +
        ']';

        Test.startTest();
        Boolean isSuccess = FEC_ChatHubCaseController.saveChatHistoryAndAttachment(jsonHistoryList, false);
        Test.stopTest();

        System.assertEquals(true, isSuccess, 'Method should still return true even if all rows are duplicates');
        Integer cnt = [SELECT COUNT() FROM FEC_ChatHistory__c WHERE FEC_MessageID__c = 'msg-shared-001'];
        System.assertEquals(1, cnt, 'Unique constraint must keep exactly one record per messageID');
    }

    @isTest
    static void testSaveChatHistoryAndAttachment_AttachmentOnly() {
        Test.setMock(HttpCalloutMock.class, new FileDownloadHttpMock());

        String jsonHistoryList = '[' +
            '{"messageID": "msg-att-001", "sessionID": "session-12345", "senderName": "Customer", "fileName": "doc.pdf", "fileUrl": "https://example.com/doc.pdf", "messageType": "attachment", "chatChannel": "Web", "isAgent": false, "createdAt": "2025-12-03T11:00:00Z"},' +
            '{"messageID": "msg-att-002", "sessionID": "session-12345", "senderName": "Agent", "message": "Got it", "messageType": "text", "chatChannel": "Web", "isAgent": true, "createdAt": "2025-12-03T11:01:00Z"}' +
        ']';

        Integer countBefore = [SELECT COUNT() FROM FEC_ChatHistory__c WHERE FEC_SessionID__c = 'session-12345'];

        Test.startTest();
        Boolean isSuccess = FEC_ChatHubCaseController.saveChatHistoryAndAttachment(jsonHistoryList, true);
        Test.stopTest();

        System.assertEquals(true, isSuccess, 'Save operation should return true');

        // isAttachmentOnly = true nên không insert thêm chat history
        Integer countAfter = [SELECT COUNT() FROM FEC_ChatHistory__c WHERE FEC_SessionID__c = 'session-12345'];
        System.assertEquals(countBefore, countAfter, 'No new chat history should be inserted when isAttachmentOnly is true');
    }

    @isTest
    static void testSaveChatHistoryAndAttachment_BlankData() {
        Test.startTest();
        try {
            FEC_ChatHubCaseController.saveChatHistoryAndAttachment('', false);
            System.assert(false, 'Expected AuraHandledException for blank input');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveChatHistoryAndAttachment_EmptyList() {
        Test.startTest();
        try {
            FEC_ChatHubCaseController.saveChatHistoryAndAttachment('[]', false);
            System.assert(false, 'Expected AuraHandledException for empty list');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveChatHistoryAndAttachment_NullAttachmentOnly() {
        Test.setMock(HttpCalloutMock.class, new FileDownloadHttpMock());

        String jsonHistoryList = '[' +
            '{"messageID": "msg-null-001", "sessionID": "session-12345", "senderName": "Agent", "message": "Hello", "messageType": "text", "chatChannel": "Web", "isAgent": true, "createdAt": "2025-12-03T12:00:00Z"}' +
        ']';

        Test.startTest();
        Boolean isSuccess = FEC_ChatHubCaseController.saveChatHistoryAndAttachment(jsonHistoryList, null);
        Test.stopTest();

        System.assertEquals(true, isSuccess, 'Should handle null isAttachmentOnly gracefully');
    }

    @isTest
    static void testSaveChatHistoryAndAttachment_ChatIdLookupAndAttachmentOnly() {
        // sessionID không có trong payload -> lookup Case theo chatID.
        String externalId = 'chatid-' + String.valueOf(System.currentTimeMillis());
        Case reviewCase = insertReviewInteractionCase(externalId);
        Test.setMock(HttpCalloutMock.class, new FileDownloadHttpMock());

        String messageId = 'att-only-' + String.valueOf(System.currentTimeMillis());
        String payload = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'chatID' => externalId,
                'senderName' => 'Agent',
                'message' => 'file',
                'messageType' => 'image',
                'fileName' => 'photo.png',
                'fileUrl' => 'https://example.com/photo.png',
                'isAgent' => true,
                'createdAt' => '2026-06-17T15:00:00.000Z',
                'messageID' => messageId
            }
        });

        Test.startTest();
        Boolean ok = FEC_ChatHubCaseController.saveChatHistoryAndAttachment(payload, true);
        Test.stopTest();

        System.assertEquals(true, ok);
        System.assertEquals(
            0,
            [SELECT COUNT() FROM FEC_ChatHistory__c WHERE FEC_Case__c = :reviewCase.Id],
            'Attachment-only không insert chat history.'
        );
        System.assertEquals(
            1,
            [SELECT COUNT() FROM ContentVersion WHERE FirstPublishLocationId = :reviewCase.Id]
        );
    }

    @isTest
    static void testSaveChatHistoryAndAttachment_SkipsExistingFile() {
        String externalId = 'existing-file-' + String.valueOf(System.currentTimeMillis());
        Case reviewCase = insertReviewInteractionCase(externalId);
        Test.setMock(HttpCalloutMock.class, new FileDownloadHttpMock());

        String messageId = 'file-dup-' + String.valueOf(System.currentTimeMillis());
        String payload = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'sessionID' => externalId,
                'senderName' => 'Agent',
                'message' => 'file',
                'messageType' => 'attachment',
                'fileName' => 'same.png',
                'fileUrl' => 'https://example.com/same.png',
                'isAgent' => true,
                'createdAt' => '2026-06-17T17:00:00.000Z',
                'messageID' => messageId
            }
        });

        Test.startTest();
        System.assertEquals(true, FEC_ChatHubCaseController.saveChatHistoryAndAttachment(payload, false));
        System.assertEquals(true, FEC_ChatHubCaseController.saveChatHistoryAndAttachment(payload, false));
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM ContentVersion WHERE FirstPublishLocationId = :reviewCase.Id]
        );
    }

    // ---------------------------------------------------------
    // TEST: updateOldCaseInteractionId
    // ---------------------------------------------------------

    @isTest
    static void testUpdateOldCaseInteractionId_Success() {
        Case testCase = [SELECT Id, FEC_External_Interaction_ID__c FROM Case WHERE FEC_External_Interaction_ID__c = 'session-12345' LIMIT 1];

        Test.startTest();
        Boolean isUpdated = FEC_ChatHubCaseController.updateOldCaseInteractionId('session-12345', 'agent007');
        Test.stopTest();

        System.assertEquals(true, isUpdated, 'Update should return true when case is found');

        Case updatedCase = [SELECT FEC_External_Interaction_ID__c FROM Case WHERE Id = :testCase.Id];
        System.assert(updatedCase.FEC_External_Interaction_ID__c.contains('-Reassign-agent007-'), 'External Interaction ID should contain reassign info');
    }

    @isTest
    static void testUpdateOldCaseInteractionId_NotFound() {
        Test.startTest();
        Boolean isUpdated = FEC_ChatHubCaseController.updateOldCaseInteractionId('invalid-session-999', 'agent007');
        Test.stopTest();

        System.assertEquals(false, isUpdated, 'Update should return false when no case matches');
    }

    @isTest
    static void testUpdateOldCaseInteractionId_BlankSessionId() {
        Test.startTest();
        Boolean isUpdated = FEC_ChatHubCaseController.updateOldCaseInteractionId('', 'agent007');
        Test.stopTest();

        System.assertEquals(false, isUpdated, 'Update should return false for blank session ID');
    }

    // ---------------------------------------------------------
    // TEST: createInteractionCaseChat
    // ---------------------------------------------------------

    @isTest
    static void testCreateInteractionCaseChat_NullDtoThrows() {
        try {
            FEC_ChatHubCaseController.createInteractionCaseChat('null');
            System.assert(false, 'Expected exception for null DTO.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @isTest
    static void testCreateInteractionCaseChat_ExistingAndNew() {
        String externalId = 'interaction-' + String.valueOf(System.currentTimeMillis());
        Case existing = insertReviewInteractionCase(externalId);

        FEC_ChatHubCaseController.FEC_InteractionCaseDTO dto =
            new FEC_ChatHubCaseController.FEC_InteractionCaseDTO();
        dto.externalInteractionId = externalId;
        dto.channel = FEC_ConstantCommon.CHANNEL_CHAT;
        dto.phoneNumber = '0909123456';
        dto.customerName = 'Test Customer';

        Test.startTest();
        FEC_ChatHubCaseController.FEC_InteractionCaseResponse existingRes =
            FEC_ChatHubCaseController.createInteractionCaseChat(JSON.serialize(dto));

        dto.externalInteractionId = externalId + '-new';
        FEC_ChatHubCaseController.FEC_InteractionCaseResponse newRes =
            FEC_ChatHubCaseController.createInteractionCaseChat(JSON.serialize(dto));
        Test.stopTest();

        System.assertEquals(existing.Id, existingRes.caseId);
        System.assertNotEquals(null, newRes.caseId);
    }
}
