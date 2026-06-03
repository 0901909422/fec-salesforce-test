@IsTest
private class FEC_Chathub_Test {

    private static Id interactionRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        System.assert(
            byDev.containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME),
            'Case RecordType Interaction is required for this test.'
        );
        return byDev.get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME).getRecordTypeId();
    }

    /** FEC_External_Interaction_ID__c is unique; keep within 255 chars. */
    private static String uniqueExternalId(String label) {
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

    /**
     * Kịch bản 1: Kiểm tra tạo Interaction Case (createInteractionCase)
     */
    @IsTest
    static void testCreateInteractionCase_Success() {
        FEC_Chathub.CustomerInfo ci = new FEC_Chathub.CustomerInfo();
        ci.customerID = 'CIF123';
        ci.customerName = 'Bui Viet Hoang';
        ci.phoneNumber = '0901234567';
        ci.nationalID = '123456789';

        FEC_Chathub.ChatSession cs = new FEC_Chathub.ChatSession();
        cs.chatID = uniqueExternalId('CH');
        cs.chatChannel = 'Web';
        cs.agentID = 'AGENT_007';

        FEC_Chathub.CreateCaseRequestEvent dto = new FEC_Chathub.CreateCaseRequestEvent();
        dto.customerInfo = ci;
        dto.chatSession = cs;

        FEC_Chathub.FEC_ChathubCaseResponse res;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Test.startTest();
            res = FEC_Chathub.createInteractionCase(dto);
            Test.stopTest();
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        System.assertNotEquals(null, res.caseId, 'CaseId phải được tạo.');
        System.assertEquals('AGENT_007', res.agentID);

        User u = [SELECT FEC_Agent_ID__c FROM User WHERE Id = :UserInfo.getUserId()];
        System.assertEquals('AGENT_007', u.FEC_Agent_ID__c);

        Case created = [
            SELECT Status, FEC_External_Interaction_ID__c, RecordType.DeveloperName
            FROM Case
            WHERE Id = :res.caseId
        ];
        System.assertEquals(cs.chatID, created.FEC_External_Interaction_ID__c);
        System.assertEquals(
            FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME,
            created.RecordType.DeveloperName
        );
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_PENDING, created.Status);
    }

    /**
     * Kịch bản 2: endChatEvent — sessionID rỗng thì bỏ qua (trả về null)
     */
    @IsTest
    static void testEndChatEvent_blankSession_returnsNull() {
        FEC_Chathub.EndChatEvent endDto = new FEC_Chathub.EndChatEvent();
        endDto.chatID = uniqueExternalId('END');
        endDto.sessionID = '';

        Test.startTest();
        FEC_Chathub.FEC_ChathubCaseResponse res = FEC_Chathub.endChatEvent(endDto);
        Test.stopTest();

        System.assertEquals(null, res, 'sessionID rỗng thì endChatEvent phải trả về null.');
    }

    /**
     * Kịch bản 3: Kiểm tra các trường hợp ngoại lệ (Exceptions) và dữ liệu null
     */
    @IsTest
    static void testExceptionAndNullHandling() {
        try {
            FEC_Chathub.createInteractionCase(null);
            System.assert(false, 'Phải ném lỗi khi DTO null');
        } catch (IllegalArgumentException e) {
            System.assert(true);
        }

        FEC_Chathub.CreateCaseRequestEvent dto = new FEC_Chathub.CreateCaseRequestEvent();
        dto.customerInfo = new FEC_Chathub.CustomerInfo();
        dto.chatSession = null;
        try {
            FEC_Chathub.createInteractionCase(dto);
            System.assert(false, 'Phải ném lỗi khi chatSession null');
        } catch (IllegalArgumentException e) {
            System.assert(true);
        }

        try {
            FEC_Chathub.endChatEvent(null);
            System.assert(false, 'Phải ném lỗi khi EndChatEvent null');
        } catch (IllegalArgumentException e) {
            System.assert(true);
        }

        FEC_Chathub.EndChatEvent endDto = new FEC_Chathub.EndChatEvent();
        endDto.sessionID = 'NOT_EXIST';
        endDto.chatID = 'NOT_EXIST';

        Test.startTest();
        FEC_Chathub.FEC_ChathubCaseResponse res = FEC_Chathub.endChatEvent(endDto);
        Test.stopTest();

        System.assertEquals(null, res, 'Không tìm thấy Case nên kết quả phải là null.');
    }
}
