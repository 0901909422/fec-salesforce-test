@IsTest
private class FEC_ChatHubCaseController_Test {

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

    @IsTest
    static void testSaveChatHistoryAndAttachment_blankJson() {
        try {
            FEC_ChatHubCaseController.saveChatHistoryAndAttachment('', false);
            System.assert(false, 'Expected exception for blank JSON.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @IsTest
    static void testSaveChatHistoryAndAttachment_emptyList() {
        try {
            FEC_ChatHubCaseController.saveChatHistoryAndAttachment('[]', false);
            System.assert(false, 'Expected exception for empty list.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @IsTest
    static void testSaveChatHistoryAndAttachment_textOnReviewCase() {
        String externalId = 'chathub-test-' + String.valueOf(System.currentTimeMillis());
        Case reviewCase = insertReviewInteractionCase(externalId);
        String messageId = 'msg-' + String.valueOf(System.currentTimeMillis());
        String payload = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'sessionID' => externalId,
                'senderName' => 'Agent',
                'message' => 'hello',
                'messageType' => 'text',
                'isAgent' => true,
                'createdAt' => '2026-06-17T14:00:00.000Z',
                'messageID' => messageId
            }
        });

        Test.startTest();
        Boolean ok = FEC_ChatHubCaseController.saveChatHistoryAndAttachment(payload, false);
        Test.stopTest();

        System.assertEquals(true, ok);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_ChatHistory__c WHERE FEC_Case__c = :reviewCase.Id]
        );
    }

    @IsTest
    static void testSaveChatHistoryAndAttachment_attachmentOnReviewCase() {
        String externalId = 'chathub-file-' + String.valueOf(System.currentTimeMillis());
        Case reviewCase = insertReviewInteractionCase(externalId);
        Test.setMock(HttpCalloutMock.class, new MockFileDownload());

        String messageId = 'file-' + String.valueOf(System.currentTimeMillis());
        String payload = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'sessionID' => externalId,
                'senderName' => 'Agent',
                'message' => 'file',
                'messageType' => 'attachment',
                'fileName' => 'chat.png',
                'fileUrl' => 'https://example.com/chat.png',
                'isAgent' => true,
                'createdAt' => '2026-06-17T14:00:00.000Z',
                'messageID' => messageId
            }
        });

        Test.startTest();
        Boolean ok = FEC_ChatHubCaseController.saveChatHistoryAndAttachment(payload, false);
        Test.stopTest();

        System.assertEquals(true, ok);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM ContentVersion WHERE FirstPublishLocationId = :reviewCase.Id]
        );
    }

    @IsTest
    static void testCreateCaseOnNewSession_blankReturnsNull() {
        System.assertEquals(null, FEC_ChatHubCaseController.createCaseOnNewSession(''));
    }

    @IsTest
    static void testUpdateOldCaseInteractionId_successAndNotFound() {
        String externalId = 'reassign-' + String.valueOf(System.currentTimeMillis());
        insertReviewInteractionCase(externalId);

        Test.startTest();
        Boolean updated = FEC_ChatHubCaseController.updateOldCaseInteractionId(externalId, 'agent01');
        Boolean missing = FEC_ChatHubCaseController.updateOldCaseInteractionId('missing-id', 'agent01');
        Test.stopTest();

        System.assertEquals(true, updated);
        System.assertEquals(false, missing);
    }

    @IsTest
    static void testSaveChatHistoryAndAttachment_chatIdLookupAndAttachmentOnly() {
        String externalId = 'chatid-' + String.valueOf(System.currentTimeMillis());
        Case reviewCase = insertReviewInteractionCase(externalId);
        Test.setMock(HttpCalloutMock.class, new MockFileDownload());

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

    @IsTest
    static void testSaveChatHistoryAndAttachment_skipsDuplicateMessage() {
        String externalId = 'dup-' + String.valueOf(System.currentTimeMillis());
        insertReviewInteractionCase(externalId);
        String messageId = 'dup-msg-' + String.valueOf(System.currentTimeMillis());
        String payload = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'sessionID' => externalId,
                'senderName' => 'Agent',
                'message' => 'dup',
                'messageType' => 'text',
                'isAgent' => true,
                'createdAt' => '2026-06-17T16:00:00.000Z',
                'messageID' => messageId
            }
        });

        Test.startTest();
        System.assertEquals(true, FEC_ChatHubCaseController.saveChatHistoryAndAttachment(payload, false));
        System.assertEquals(true, FEC_ChatHubCaseController.saveChatHistoryAndAttachment(payload, false));
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_ChatHistory__c WHERE FEC_MessageID__c = :messageId]
        );
    }

    @IsTest
    static void testCreateInteractionCaseChat_nullDtoThrows() {
        try {
            FEC_ChatHubCaseController.createInteractionCaseChat('null');
            System.assert(false, 'Expected exception for null DTO.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @IsTest
    static void testCreateInteractionCaseChat_existingAndNew() {
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

    @IsTest
    static void testSaveChatHistoryAndAttachment_skipsExistingFile() {
        String externalId = 'existing-file-' + String.valueOf(System.currentTimeMillis());
        Case reviewCase = insertReviewInteractionCase(externalId);
        Test.setMock(HttpCalloutMock.class, new MockFileDownload());

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

    private class MockFileDownload implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBodyAsBlob(Blob.valueOf('png-bytes'));
            return res;
        }
    }
}