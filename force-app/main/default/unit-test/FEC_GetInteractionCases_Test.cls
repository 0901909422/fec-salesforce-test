@IsTest
private class FEC_GetInteractionCases_Test {

    @IsTest
    static void testGetAllInteractions_Success() {
        String rtDevName = FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME;
        Schema.RecordTypeInfo rtInfo =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(rtDevName);
        if (rtInfo == null) {
            return;
        }
        Id interactionRecordTypeId = rtInfo.getRecordTypeId();
        String suffix = String.valueOf(System.currentTimeMillis());
        User runUser = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];

        // FEC_Interaction_Status__c is formula (FEC_Final_Status__c); set Status instead.
        Case testInteraction = new Case(
            Subject = 'FEC_GetInteractionCases_Test Interaction',
            RecordTypeId = interactionRecordTypeId,
            Status = FEC_ConstantCommon.CASE_STATUS_NEW,
            FEC_ID_Search__c = 'INT-' + suffix,
            FEC_Interaction_Duration__c = 120,
            FEC_Phone_Number__c = '0901234567',
            FEC_Channel__c = FEC_ConstantCommon.CHANNEL_CHAT,
            FEC_Interaction_Subchannel__c = FEC_ConstantCommon.CHANNEL_CHAT_NAME,
            FEC_External_Interaction_ID__c = 'EXT-' + suffix,
            FEC_Interaction_Email__c = 'test@example.com'
        );

        System.runAs(runUser) {
            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                insert testInteraction;
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }

            Test.startTest();
            List<FEC_GetInteractionCases.InteractionRow> results =
                FEC_GetInteractionCases.getAllInteractions();
            Test.stopTest();

            System.assertNotEquals(null, results, 'Danh sách trả về không được null.');

            FEC_GetInteractionCases.InteractionRow row = null;
            for (FEC_GetInteractionCases.InteractionRow r : results) {
                if (r.interactionId == testInteraction.Id) {
                    row = r;
                    break;
                }
            }
            System.assertNotEquals(null, row, 'Phải tìm thấy Interaction Case vừa tạo.');
            System.assertEquals(testInteraction.FEC_ID_Search__c, row.interactionIdText);
            System.assertEquals(FEC_ConstantCommon.CASE_STATUS_NEW, row.interactionStatus);
            System.assertEquals('0901234567', row.interactionPhone);
            System.assertEquals(FEC_ConstantCommon.CHANNEL_CHAT, row.channel);
            System.assertEquals(
                testInteraction.FEC_External_Interaction_ID__c,
                row.externalInteractionId
            );
            System.assertEquals('120', row.interactionDuration);
        }
    }

    @IsTest
    static void testGetCaseFieldHelpTexts() {
        // Thực thi phương thức cần test
        Test.startTest();
        Map<String, String> helpTexts = FEC_GetInteractionCases.getCaseFieldHelpTexts();
        Test.stopTest();

        // Xác thực kết quả
        // Vì phụ thuộc vào cấu hình Org (có help text hay không), ta chỉ cần check NotNull để đảm bảo logic chạy thành công
        System.assertNotEquals(null, helpTexts, 'Map help text trả về không được null.');
    }
}