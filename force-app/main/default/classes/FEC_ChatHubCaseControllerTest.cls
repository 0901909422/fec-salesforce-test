/**
 * Test class for FEC_ChatHubCaseController
 * Covers: createCaseOnNewSession, saveChatHistoryAndAttachment, updateOldCaseInteractionId
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
        String jsonPayload = '{' +
            '"chatSession": {"chatChannel": "Web"},' +
            '"customerInfo": {"phoneNumber": "0987654321"}' +
        '}';

        Test.startTest();
        try {
            FEC_ChatHubCaseController.createCaseOnNewSession(jsonPayload);
            System.assert(false, 'Expected AuraHandledException for missing sessionID');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
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
            '{"sessionID": "session-12345", "senderName": "Agent 1", "message": "Hi there", "messageType": "text", "chatChannel": "Web", "isAgent": true, "createdAt": "2025-12-03T10:00:00Z"},' +
            '{"sessionID": "session-12345", "senderName": "Customer", "fileName": "bug.png", "fileUrl": "https://example.com/bug.png", "messageType": "image", "chatChannel": "Web", "isAgent": false, "createdAt": "2025-12-03T10:05:00Z"}' +
        ']';

        Test.startTest();
        Boolean isSuccess = FEC_ChatHubCaseController.saveChatHistoryAndAttachment(jsonHistoryList, false);
        Test.stopTest();

        System.assertEquals(true, isSuccess, 'Save operation should return true on success');

        List<FEC_ChatHistory__c> chatLogs = [SELECT Id, FEC_MessageType__c FROM FEC_ChatHistory__c WHERE FEC_SessionID__c = 'session-12345'];
        System.assert(chatLogs.size() > 1, 'New chat histories should be inserted');

        List<ContentVersion> cvs = [SELECT Id, Title FROM ContentVersion WHERE FirstPublishLocationId IN (SELECT Id FROM Case WHERE FEC_External_Interaction_ID__c = 'session-12345')];
        System.assert(!cvs.isEmpty(), 'ContentVersion should have been created for the image attachment');
    }

    @isTest
    static void testSaveChatHistoryAndAttachment_AttachmentOnly() {
        Test.setMock(HttpCalloutMock.class, new FileDownloadHttpMock());

        String jsonHistoryList = '[' +
            '{"sessionID": "session-12345", "senderName": "Customer", "fileName": "doc.pdf", "fileUrl": "https://example.com/doc.pdf", "messageType": "attachment", "chatChannel": "Web", "isAgent": false, "createdAt": "2025-12-03T11:00:00Z"},' +
            '{"sessionID": "session-12345", "senderName": "Agent", "message": "Got it", "messageType": "text", "chatChannel": "Web", "isAgent": true, "createdAt": "2025-12-03T11:01:00Z"}' +
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
    static void testSaveChatHistoryAndAttachment_NullAttachmentOnly() {
        Test.setMock(HttpCalloutMock.class, new FileDownloadHttpMock());

        String jsonHistoryList = '[' +
            '{"sessionID": "session-12345", "senderName": "Agent", "message": "Hello", "messageType": "text", "chatChannel": "Web", "isAgent": true, "createdAt": "2025-12-03T12:00:00Z"}' +
        ']';

        Test.startTest();
        Boolean isSuccess = FEC_ChatHubCaseController.saveChatHistoryAndAttachment(jsonHistoryList, null);
        Test.stopTest();

        System.assertEquals(true, isSuccess, 'Should handle null isAttachmentOnly gracefully');
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
}
