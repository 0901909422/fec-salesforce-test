@IsTest
private class FEC_ChatHubCaseController_Test {

    private class FileDownloadHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'image/png');
            res.setBodyAsBlob(Blob.valueOf('Mock File Content'));
            res.setStatusCode(200);
            return res;
        }
    }

    private static String uniqueSessionId(String label) {
        String suffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Integer maxLabel = 20 - suffix.length();
        if (maxLabel <= 0) {
            return suffix.length() > 20 ? suffix.substring(0, 20) : suffix;
        }
        if (label.length() > maxLabel) {
            label = label.substring(0, maxLabel);
        }
        return label + suffix;
    }

    private static Map<String, Object> parseResponse(Object response) {
        System.assertNotEquals(null, response, 'Response không được null.');
        return (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(response));
    }

    private static Case insertInteractionSeed(String sessionId) {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        Id rtId = rtMap.containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            ? rtMap.get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME).getRecordTypeId()
            : null;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Case c = new Case(
                Subject = 'FEC_ChatHubCaseController_Test',
                FEC_External_Interaction_ID__c = sessionId,
                FEC_ID_Search__c = 'CHC-' + String.valueOf(System.currentTimeMillis())
            );
            if (rtId != null) {
                c.RecordTypeId = rtId;
                c.FEC_Channel__c = FEC_ConstantCommon.CHANNEL_CHAT;
                c.Status = FEC_ConstantCommon.CASE_STATUS_OPEN;
            }
            insert c;
            return c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    /**
     * Kịch bản 1: Tạo Case từ session mới (createCaseOnNewSession)
     */
    @IsTest
    static void testCreateCaseOnNewSession_Success() {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (!rtMap.containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)) {
            return;
        }

        String sessionId = uniqueSessionId('SESS');
        String jsonData = '{' +
            '"chatSession": {"sessionID": "' + sessionId + '", "chatChannel": "Web"},' +
            '"customerInfo": {"phoneNumber": "0901234567", "customerName": "Test User", "kYCStatus": "Success"}' +
        '}';

        Object response;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Test.startTest();
            response = FEC_ChatHubCaseController.createCaseOnNewSession(jsonData);
            Test.stopTest();
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Map<String, Object> res = parseResponse(response);
        System.assertNotEquals(null, res.get('caseId'), 'CaseId phải được tạo.');

        Case inserted = [
            SELECT FEC_External_Interaction_ID__c, FEC_Phone_Number__c
            FROM Case
            WHERE Id = :(String) res.get('caseId')
        ];
        System.assertEquals(sessionId, inserted.FEC_External_Interaction_ID__c);
        System.assertEquals('0901234567', inserted.FEC_Phone_Number__c);
    }

    @IsTest
    static void testCreateCaseOnNewSession_BlankData() {
        Test.startTest();
        Object response = FEC_ChatHubCaseController.createCaseOnNewSession('');
        Test.stopTest();
        System.assertEquals(null, response, 'JSON rỗng phải trả về null.');
    }

    /**
     * Kịch bản 2: Lưu lịch sử chat và tệp đính kèm (saveChatHistoryAndAttachment)
     */
    @IsTest
    static void testSaveChatHistoryAndAttachment_Success() {
        if (!Schema.getGlobalDescribe().containsKey('FEC_ChatHistory__c')) {
            return;
        }

        String sessionId = uniqueSessionId('HIST');
        Case c = insertInteractionSeed(sessionId);

        String jsonHistory = '[' +
            '{"sessionID": "' + sessionId + '", "senderName": "Agent", "message": "Hi", "messageType": "text", "chatChannel": "Web", "createdAt": "2026-03-20T10:00:00Z", "isAgent": true},' +
            '{"sessionID": "' + sessionId + '", "senderName": "Cust", "message": "img.png", "messageType": "image", "chatChannel": "Web", "createdAt": "2026-03-20T10:05:00Z", "fileName": "img.png", "fileUrl": "https://test.com/img.png", "isAgent": false}' +
        ']';

        Test.setMock(HttpCalloutMock.class, new FileDownloadHttpMock());

        Test.startTest();
        Boolean isSuccess = FEC_ChatHubCaseController.saveChatHistoryAndAttachment(jsonHistory, false);
        Test.stopTest();

        System.assertEquals(true, isSuccess);
        Integer historyCount = Database.countQuery(
            'SELECT COUNT() FROM FEC_ChatHistory__c WHERE FEC_Case__c = \'' +
            String.escapeSingleQuotes(String.valueOf(c.Id)) +
            '\''
        );
        System.assert(historyCount > 0, 'Phải có ít nhất một bản ghi chat history.');
    }

    /**
     * Kịch bản 3: Cập nhật Interaction ID cho Case cũ (updateOldCaseInteractionId)
     */
    @IsTest
    static void testUpdateOldCaseInteractionId() {
        String oldId = uniqueSessionId('OLD');
        Case c = insertInteractionSeed(oldId);

        Test.startTest();
        Boolean updated = FEC_ChatHubCaseController.updateOldCaseInteractionId(oldId, 'AgentName');
        Test.stopTest();

        System.assertEquals(true, updated);
        Case updatedCase = [SELECT FEC_External_Interaction_ID__c FROM Case WHERE Id = :c.Id];
        System.assert(updatedCase.FEC_External_Interaction_ID__c.contains('Reassign'));
    }

    @IsTest
    static void testUpdateOldCaseInteractionId_NotFound() {
        Test.startTest();
        Boolean updated = FEC_ChatHubCaseController.updateOldCaseInteractionId(
            uniqueSessionId('MISS'),
            'AgentName'
        );
        Test.stopTest();
        System.assertEquals(false, updated);
    }

    /**
     * Kịch bản 4: Guard clauses / exceptions
     */
    @IsTest
    static void testErrorHandling() {
        Test.startTest();
        System.assertEquals(null, FEC_ChatHubCaseController.createCaseOnNewSession(''));

        Boolean thrown = false;
        try {
            FEC_ChatHubCaseController.saveChatHistoryAndAttachment('', false);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, thrown, 'JSON history rỗng phải ném AuraHandledException.');
    }
}
