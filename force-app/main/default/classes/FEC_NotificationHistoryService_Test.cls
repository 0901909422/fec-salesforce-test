@IsTest
private class FEC_NotificationHistoryService_Test {

    private static Case insertCaseRow() {
        Case c = new Case(
            Subject = 'Notification History Test',
            Status = 'New',
            FEC_ID_Search__c = 'NH-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    @IsTest
    static void testBuildRow_insertRows_andHelpers() {
        Case c = insertCaseRow();
        Datetime sentAt = System.now();

        FEC_Notification_History__c autoRow = FEC_NotificationHistoryService.buildRow(
            c.Id,
            null,
            'Stage 1',
            'Template A',
            'Rule A',
            'Email',
            'Customer',
            FEC_NotificationHistoryService.SEND_TYPE_AUTO,
            FEC_NotificationHistoryService.SEND_STATUS_SUCCESS,
            null,
            FEC_NotificationHistoryService.SEND_USER_SYSTEM,
            'Maker',
            sentAt
        );
        FEC_Notification_History__c manualRow = FEC_NotificationHistoryService.buildRow(
            c.Id,
            null,
            'Stage 2',
            'Template B',
            'Rule B',
            'SMS',
            'Agent',
            FEC_NotificationHistoryService.SEND_TYPE_MANUAL,
            FEC_NotificationHistoryService.SEND_STATUS_FAILURE,
            'SMTP error',
            UserInfo.getUserEmail(),
            'Checker',
            null
        );

        Test.startTest();
        FEC_NotificationHistoryService.insertRow(autoRow);
        FEC_NotificationHistoryService.insertRows(new List<FEC_Notification_History__c>{ manualRow });
        FEC_NotificationHistoryService.insertRows(null);
        FEC_NotificationHistoryService.insertRow(null);
        System.assertEquals('user', FEC_NotificationHistoryService.emailLocalPart('user@fecredit.com'));
        System.assertEquals('invalid', FEC_NotificationHistoryService.emailLocalPart('invalid'));
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM FEC_Notification_History__c WHERE FEC_Case__c = :c.Id]);
    }
}
