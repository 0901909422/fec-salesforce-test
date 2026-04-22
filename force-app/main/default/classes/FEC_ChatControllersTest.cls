/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
public class FEC_ChatControllersTest {

    // 1. HTTP Callout Mock để giả lập việc tải file từ FEC_Utils.downloadFileAsBlob
    private class FileDownloadHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'image/png');
            res.setBodyAsBlob(Blob.valueOf('Mock File Content'));
            res.setStatusCode(200);
            return res;
        }
    }

    // 2. Setup Data chung cho các test method
    @testSetup
    static void setupTestData() {
        // Tạo Case mẫu. Lưu ý: Thêm các required fields của org bạn vào đây nếu có
        Case testCase = new Case(
            Subject = 'Test Chat Case',
            Status = 'New',
            FEC_External_Interaction_ID__c = 'session-12345'
        );
        insert testCase;

        // Tạo mẫu một record Chat History
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

        // Tạo mẫu ContentVersion để test Map file
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
    // TEST: FEC_ChatHistoryController
    // ---------------------------------------------------------
    @isTest
    static void testGetChatMessages() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_ChatHistoryController.ChatDataWrapper result = FEC_ChatHistoryController.getChatMessages(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result wrapper should not be null');
        System.assert(!result.messages.isEmpty(), 'Messages list should not be empty');
        System.assertNotEquals(null, result.fileMap, 'File map should be initialized');
        System.assert(result.fileMap.containsKey('test_image') || result.fileMap.containsKey('test_image.png'), 'File map should contain the test image title');
    }

    // ---------------------------------------------------------
    // TEST: FEC_ChatHubCaseController
    // ---------------------------------------------------------
    
    @isTest
    static void testCreateCaseOnNewSession_Success() {
        // Kiểm tra Record Type tồn tại trước khi test
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        Boolean hasRecordType = rtMap.containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);

        // Giả lập chuỗi JSON payload gửi từ Pega/Genesys/ChatHub
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

            // Kiểm tra xem Case đã thực sự được tạo với đúng Session ID chưa
            Case insertedCase = [SELECT Id, FEC_External_Interaction_ID__c, FEC_Phone_Number__c FROM Case WHERE Id = :response.caseId];
            System.assertEquals('session-99999', insertedCase.FEC_External_Interaction_ID__c, 'External Interaction ID should match sessionID');
            System.assertEquals('0987654321', insertedCase.FEC_Phone_Number__c, 'Phone number should map correctly');
        } else {
            // Record Type chưa tồn tại trong org → verify exception handling
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
    static void testSaveChatHistoryAndAttachment_Success() {
        // Thiết lập Mock để bypass callout download file trong FEC_Utils.downloadFileAsBlob
        Test.setMock(HttpCalloutMock.class, new FileDownloadHttpMock());

        // Giả lập chuỗi JSON chứa list chat history (bao gồm cả text và image)
        String jsonHistoryList = '[' +
            '{"sessionID": "session-12345", "senderName": "Agent 1", "message": "Hi there", "messageType": "text", "chatChannel": "Web", "isAgent": true, "createdAt": "2025-12-03T10:00:00Z"},' +
            '{"sessionID": "session-12345", "senderName": "Customer", "fileName": "bug.png", "fileUrl": "https://example.com/bug.png", "messageType": "image", "chatChannel": "Web", "isAgent": false, "createdAt": "2025-12-03T10:05:00Z"}' +
        ']';

        Test.startTest();
        Boolean isSuccess = FEC_ChatHubCaseController.saveChatHistoryAndAttachment(jsonHistoryList, false);
        Test.stopTest();

        System.assertEquals(true, isSuccess, 'Save operation should return true on success');

        // Kiểm tra Database xem records đã được insert chưa
        List<FEC_ChatHistory__c> chatLogs = [SELECT Id, FEC_MessageType__c FROM FEC_ChatHistory__c WHERE FEC_SessionID__c = 'session-12345'];
        System.assert(chatLogs.size() > 1, 'New chat histories should be inserted');
        
        List<ContentVersion> cvs = [SELECT Id, Title FROM ContentVersion WHERE FirstPublishLocationId IN (SELECT Id FROM Case WHERE FEC_External_Interaction_ID__c = 'session-12345')];
        System.assert(!cvs.isEmpty(), 'A ContentVersion should have been created for the image attachment');
    }

    @isTest
    static void testSaveChatHistoryAndAttachment_ErrorHandling() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            FEC_ChatHubCaseController.saveChatHistoryAndAttachment('', false);
            System.assert(false, 'Expected an AuraHandledException to be thrown due to blank input');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'AuraHandledException should have been thrown for blank input');
    }

    @isTest
    static void testUpdateOldCaseInteractionId() {
        // Lấy case đã tạo trong testSetup
        Case testCase = [SELECT Id, FEC_External_Interaction_ID__c FROM Case WHERE FEC_External_Interaction_ID__c = 'session-12345' LIMIT 1];
        
        Test.startTest();
        Boolean isUpdated = FEC_ChatHubCaseController.updateOldCaseInteractionId('session-12345', 'agent007');
        Test.stopTest();

        System.assertEquals(true, isUpdated, 'Update should return true when case is found');

        // Verify kết quả ID mới
        Case updatedCase = [SELECT Id, FEC_External_Interaction_ID__c FROM Case WHERE Id = :testCase.Id];
        System.assert(updatedCase.FEC_External_Interaction_ID__c.contains('-Reassign-agent007-'), 'External Interaction ID should be appended with reassign logic');
    }
    
    @isTest
    static void testUpdateOldCaseInteractionId_NotFound() {
        Test.startTest();
        Boolean isUpdated = FEC_ChatHubCaseController.updateOldCaseInteractionId('invalid-session-999', 'agent007');
        Test.stopTest();

        System.assertEquals(false, isUpdated, 'Update should return false when no case matches the session ID');
    }
}