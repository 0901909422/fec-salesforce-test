@IsTest
private class FEC_NotificationHistoryController_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        FEC_Template__c template = new FEC_Template__c(
            Name = 'Template 1',
            FEC_Body__c = 'Hello Customer'
        );
        insert template;

        FEC_Notification_Channel__c notifChannel = new FEC_Notification_Channel__c(
            Name = 'Email',
            FEC_Noti_Channel_Status__c = true
        );
        insert notifChannel;

        RecordType notifRt = [
            SELECT Id
            FROM RecordType
            WHERE SobjectType = 'FEC_Notification__c'
            LIMIT 1
        ];

        SObject notification = Schema.getGlobalDescribe()
            .get('FEC_Notification__c')
            .newSObject();
        notification.put('Name', 'Notif 1');
        notification.put('RecordTypeId', notifRt.Id);
        notification.put('FEC_Notification_Status__c', true);
        if (Schema.SObjectType.FEC_Notification__c.fields.getMap()
            .containsKey('FEC_Notification_Template__c')) {
            notification.put('FEC_Notification_Template__c', template.Id);
        }
        insert notification;

        insert new FEC_Notification_Template_Channel__c(
            FEC_Notification__c = (Id) notification.get('Id'),
            FEC_Notification_Channel__c = notifChannel.Id,
            FEC_Notification_Template__c = template.Id
        );

        Case testCase1;
        Case testCase2;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            testCase1 = new Case(
                Status = 'New',
                FEC_ID_Search__c = 'CASE-001'
            );
            testCase2 = new Case(
                Status = 'New',
                FEC_ID_Search__c = 'CASE-002'
            );
            insert new List<Case>{ testCase1, testCase2 };

            FEC_Customer_History__c custHistory = new FEC_Customer_History__c(
                FEC_Case__c = testCase1.Id,
                FEC_National_ID_Passport_ID__c = '123456789',
                Name = 'CH-' + suffix
            );
            insert custHistory;

            testCase1.FEC_Account_or_Contract__c = custHistory.Id;
            update testCase1;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new List<FEC_Notification_History__c>{
            new FEC_Notification_History__c(
                FEC_Case__c = testCase1.Id,
                FEC_Notification_Channel__c = FEC_ConstantCommon.NOTIFICATION_HISTORY_CHANNEL_EMAIL,
                FEC_Send_Type__c = 'Manual',
                FEC_Notification__c = (Id) notification.get('Id'),
                FEC_Send_Status__c = 'Success',
                FEC_Send_Date_Time__c = System.now()
            ),
            new FEC_Notification_History__c(
                FEC_Case__c = testCase2.Id,
                FEC_Notification_Channel__c = FEC_ConstantCommon.NOTIFICATION_HISTORY_CHANNEL_ZNS,
                FEC_Send_Type__c = 'Auto',
                FEC_Send_Status__c = 'Failed',
                FEC_Failure_Reason__c = 'Invalid Phone',
                FEC_Send_Date_Time__c = System.now()
            )
        };
    }

    @IsTest
    static void testGetNotificationHistoryForCase_WithNationalId() {
        Case testCase1 = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'CASE-001' LIMIT 1];

        Test.startTest();
        List<FEC_NotificationHistoryController.NotificationHistoryRow> results =
            FEC_NotificationHistoryController.getNotificationHistoryForCase(
                testCase1.Id,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_CHANNEL_EMAIL
            );
        Test.stopTest();

        System.assertNotEquals(0, results.size(), 'Phải lấy được lịch sử thông báo Email.');

        FEC_NotificationHistoryController.NotificationHistoryRow row = results[0];
        System.assertEquals('Manual', row.sentType);
        System.assertEquals('Success', row.sentStatus);
        System.assertEquals('Notif 1', row.notificationType);
        if (Schema.SObjectType.FEC_Notification__c.fields.getMap()
            .containsKey('FEC_Notification_Template__c')) {
            System.assertEquals('Hello Customer', row.notificationContent);
        } else {
            System.assert(
                String.isBlank(row.notificationContent),
                'Template body comes from FEC_Notification__c.FEC_Notification_Template__c lookup when present.'
            );
        }
        System.assertEquals('CASE-001', row.caseId);
    }

    @IsTest
    static void testGetNotificationHistoryForCase_WithoutNationalId() {
        Case testCase2 = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'CASE-002' LIMIT 1];

        Test.startTest();
        List<FEC_NotificationHistoryController.NotificationHistoryRow> results =
            FEC_NotificationHistoryController.getNotificationHistoryForCase(
                testCase2.Id,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_CHANNEL_ZNS
            );
        Test.stopTest();

        System.assertNotEquals(0, results.size(), 'Phải lấy được lịch sử thông báo ZNS.');

        FEC_NotificationHistoryController.NotificationHistoryRow row = results[0];
        System.assertEquals('Failed', row.sentStatus);
        System.assertEquals('Invalid Phone', row.failureReason);
        System.assertEquals('CASE-002', row.caseId);
    }

    @IsTest
    static void testGetNotificationHistoryForCase_NegativeScenarios() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_NotificationHistoryController.NotificationHistoryRow> nullIdResult =
            FEC_NotificationHistoryController.getNotificationHistoryForCase(
                null,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_CHANNEL_EMAIL
            );
        System.assertEquals(0, nullIdResult.size(), 'Truyền ID null phải trả về mảng rỗng.');

        List<FEC_NotificationHistoryController.NotificationHistoryRow> emptyChannelResult =
            FEC_NotificationHistoryController.getNotificationHistoryForCase(c.Id, '');
        System.assertEquals(0, emptyChannelResult.size(), 'Truyền Channel rỗng phải trả về mảng rỗng.');

        List<FEC_NotificationHistoryController.NotificationHistoryRow> invalidChannelResult =
            FEC_NotificationHistoryController.getNotificationHistoryForCase(c.Id, 'SMS');
        System.assertEquals(0, invalidChannelResult.size(), 'Truyền Channel không hợp lệ phải trả về mảng rỗng.');
        Test.stopTest();
    }

    @IsTest
    static void testGetEmailNotificationHistoryForCase() {
        Case testCase1 = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'CASE-001' LIMIT 1];

        Test.startTest();
        List<FEC_NotificationHistoryController.NotificationHistoryRow> results =
            FEC_NotificationHistoryController.getEmailNotificationHistoryForCase(testCase1.Id);
        Test.stopTest();

        System.assertNotEquals(0, results.size(), 'Hàm tương thích phải gọi đúng và lấy được lịch sử Email.');
    }

    @IsTest
    static void testGetChannelValues() {
        Case testCase1 = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'CASE-001' LIMIT 1];

        Test.startTest();
        List<FEC_NotificationHistoryController.NotificationHistoryRow> results =
            FEC_NotificationHistoryController.getNotificationHistoryForCase(
                testCase1.Id,
                FEC_ConstantCommon.NOTIFICATION_HISTORY_CHANNEL_MOBILE_APP
            );
        Test.stopTest();

        System.assertEquals(
            0,
            results.size(),
            'MOBILE_APP chưa có dữ liệu test; nhánh logic vẫn được cover.'
        );
    }
}
