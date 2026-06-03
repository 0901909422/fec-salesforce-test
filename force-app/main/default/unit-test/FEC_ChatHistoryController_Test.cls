@IsTest
private class FEC_ChatHistoryController_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        FEC_CaseTriggerHandler.isExecuting = true;
        Case c;
        try {
            c = new Case(
                Subject = 'Test Chat Case',
                Status = 'New',
                FEC_ID_Search__c = 'CHAT-CASE-' + suffix
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        // 2. Tạo lịch sử chat mồi (FEC_ChatHistory__c)
        FEC_ChatHistory__c msg = new FEC_ChatHistory__c(
            FEC_Case__c = c.Id,
            FEC_Message__c = 'Hello, how can I help?',
            FEC_SenderName__c = 'Agent',
            FEC_MessageType__c = 'Text',
            FEC_CreatedAt__c = Datetime.now(),
            FEC_IsAgent__c = true
        );
        insert msg;

        // 3. Tạo ContentVersion đính kèm vào Case
        // Lưu ý: FirstPublishLocationId cho phép gắn ContentVersion trực tiếp vào bản ghi cha (Case)
        ContentVersion cv = new ContentVersion(
            Title = 'TestImage',
            PathOnClient = 'TestImage.png',
            VersionData = Blob.valueOf('Test Content'),
            FirstPublishLocationId = c.Id,
            IsMajorVersion = true
        );
        insert cv;
    }

    /**
     * Kịch bản 1: Lấy dữ liệu chat và file đính kèm thành công.
     */
    @IsTest
    static void testGetChatMessages_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_ChatHistoryController.ChatDataWrapper result = FEC_ChatHistoryController.getChatMessages(c.Id);
        Test.stopTest();

        // Kiểm tra danh sách tin nhắn
        System.assertNotEquals(null, result.messages, 'Danh sách tin nhắn không được null.');
        System.assertEquals(1, result.messages.size(), 'Phải lấy được 1 tin nhắn đã tạo trong Setup.');
        System.assertEquals('Hello, how can I help?', result.messages[0].FEC_Message__c);

        // Kiểm tra bản đồ tệp (fileMap)
        System.assertNotEquals(null, result.fileMap, 'File map không được null.');
        System.assert(result.fileMap.containsKey('TestImage'), 'File map phải chứa key "TestImage".');
        System.assert(result.fileMap.containsKey('TestImage.png'), 'File map phải chứa key "TestImage.png" (có extension).');
    }

    /**
     * Kịch bản 2: Kiểm tra khi Case không có dữ liệu chat hoặc file.
     */
    @IsTest
    static void testGetChatMessages_EmptyData() {
        FEC_CaseTriggerHandler.isExecuting = true;
        Case emptyCase;
        try {
            emptyCase = new Case(
                Subject = 'Empty Case',
                Status = 'New',
                FEC_ID_Search__c = 'CHAT-EMPTY-' + String.valueOf(System.currentTimeMillis())
            );
            insert emptyCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_ChatHistoryController.ChatDataWrapper result = FEC_ChatHistoryController.getChatMessages(emptyCase.Id);
        Test.stopTest();

        System.assertEquals(0, result.messages.size(), 'Danh sách tin nhắn phải rỗng.');
        System.assertEquals(0, result.fileMap.size(), 'File map phải rỗng.');
    }
    
    /**
     * Kịch bản 3: Kiểm tra khi truyền ID rỗng.
     */
    @IsTest
    static void testGetChatMessages_NullId() {
        Test.startTest();
        FEC_ChatHistoryController.ChatDataWrapper result = FEC_ChatHistoryController.getChatMessages(null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Hệ thống phải khởi tạo object dù Id là null.');
        System.assertEquals(0, result.messages.size());
    }
}