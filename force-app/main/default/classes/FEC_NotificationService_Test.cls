@IsTest
private class FEC_NotificationService_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);
        String queueDevName = ('Test_Int_Queue_' + suffix).left(40);

        insert new FEC_System_Config__c(
            FEC_Sender_Email__c = 'noreply@fecredit.com.test'
        );

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(thisUser) {
            insert new Group(
                Name = 'Test Internal Queue ' + suffix,
                Type = 'Queue',
                DeveloperName = queueDevName
            );
        }

        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Product Type A',
            FEC_Code__c = 'PT' + suffix,
            FEC_Active__c = true
        );
        insert pt;

        FEC_Notification_Channel__c emailChannel = new FEC_Notification_Channel__c(
            Name = FEC_ConstantCommon.NOTIFICATION_CHANNEL_EMAIL,
            FEC_Noti_Channel_Status__c = true
        );
        FEC_Notification_Channel__c appChannel = new FEC_Notification_Channel__c(
            Name = FEC_ConstantCommon.NOTIFICATION_CHANNEL_SF_APP,
            FEC_Noti_Channel_Status__c = true
        );
        insert new List<FEC_Notification_Channel__c>{ emailChannel, appChannel };

        // 4. Tạo Letterhead và Template
        FEC_Enhanced_Letterhead__c lh = new FEC_Enhanced_Letterhead__c(
            Name = 'Mock LH',
            FEC_Header__c = '<img src="https://test.rtaImage.com/123" />', // Để kích hoạt hàm inlineImages
            FEC_Footer__c = 'Footer'
        );
        insert lh;

        FEC_Template__c template = new FEC_Template__c(
            Name = 'Mock Template',
            FEC_Subject_Line__c = 'Alert Case {{{Case.CaseNumber}}}',
            FEC_Body__c = 'Hello {{{User.Name}}}, Case {{{Case.Id}}}',
            FEC_Enhanced_Letterhead__c = lh.Id,
            FEC_Active__c = true
        );
        insert template;

        // 5. Tạo Notification Config (Loại 3 - Email)
        RecordType rt = [SELECT Id FROM RecordType WHERE SobjectType = 'FEC_Notification__c' LIMIT 1];
        
        FEC_Notification__c emailNotif = new FEC_Notification__c(
            Name = 'Email Internal Alert',
            RecordTypeId = rt.Id,
            FEC_Target_Group__c = FEC_ConstantCommon.NOTIFICATION_TARGET_GROUP_INTERNAL,
            FEC_Notification_Status__c = true,
            FEC_Receivers__c = 'internaluser@fecredit.com.test', // Email người nhận
            FEC_Assigned_to_Queue__c = queueDevName,
            FEC_Product_Type__c = pt.Id,
            FEC_Schedule_Start_Time__c = Time.newInstance(0, 0, 0, 0),
            FEC_Schedule_End_Time__c = Time.newInstance(23, 59, 59, 0)
        );
        
        // 6. Tạo Notification Config (Loại 4 - SF App)
        FEC_Notification__c appNotif = new FEC_Notification__c(
            Name = 'App Internal Alert',
            RecordTypeId = rt.Id,
            FEC_Target_Group__c = FEC_ConstantCommon.NOTIFICATION_TARGET_GROUP_INTERNAL,
            FEC_Notification_Status__c = true,
            FEC_Receivers__c = 'admin@fecredit.com.test',
            FEC_Assigned_to_Queue__c = queueDevName,
            FEC_Product_Type__c = pt.Id,
            FEC_Schedule_Start_Time__c = Time.newInstance(0, 0, 0, 0),
            FEC_Schedule_End_Time__c = Time.newInstance(23, 59, 59, 0)
        );
        insert new List<FEC_Notification__c>{emailNotif, appNotif};

        // 7. Map Template với Notification (Template Channel)
        FEC_Notification_Template_Channel__c tcEmail = new FEC_Notification_Template_Channel__c(
            FEC_Notification__c = emailNotif.Id,
            FEC_Notification_Channel__c = emailChannel.Id,
            FEC_Notification_Template__c = template.Id
        );
        
        FEC_Notification_Template_Channel__c tcApp = new FEC_Notification_Template_Channel__c(
            FEC_Notification__c = appNotif.Id,
            FEC_Notification_Channel__c = appChannel.Id,
            FEC_Notification_Template__c = template.Id
        );
        insert new List<FEC_Notification_Template_Channel__c>{tcEmail, tcApp};

        // 8. Tạo User để nhận SF App Notification
        User receiverUser = new User(
            Alias = 'adminfe',
            Email = 'admin@fecredit.com.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'admin_' + DateTime.now().getTime() + '@fecredit.com.test',
            IsActive = true
        );
        insert receiverUser;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                FEC_Product_Type__c = pt.Id,
                Status = 'New',
                OwnerId = UserInfo.getUserId()
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static String getQueueDeveloperName() {
        Group q = [
            SELECT DeveloperName
            FROM Group
            WHERE Type = 'Queue' AND DeveloperName LIKE 'Test_Int_Queue_%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return q.DeveloperName;
    }

    @IsTest
    static void testSendEmailNotifications() {
        Case c = [SELECT Id, OwnerId FROM Case LIMIT 1];
        Group q = [SELECT Id FROM Group WHERE DeveloperName = :getQueueDeveloperName() LIMIT 1];

        // Tạo OldMap chứa dữ liệu cũ (Owner là User)
        Map<Id, Case> oldMap = new Map<Id, Case>();
        oldMap.put(c.Id, c.clone(true, true, true, true));

        // Cập nhật OwnerId sang Queue
        c.OwnerId = q.Id;
        List<Case> newCases = new List<Case>{c};

        Test.startTest();
        // Gọi Service
        FEC_NotificationService.sendEmailNotifications(newCases, oldMap);
        Test.stopTest();

        // Kiểm tra xem lịch sử Notification History có được tạo không
        List<FEC_Notification_History__c> histories = [
            SELECT Id, FEC_Send_Status__c, FEC_Notification_Channel__c 
            FROM FEC_Notification_History__c 
            WHERE FEC_Case__c = :c.Id 
              AND FEC_Notification_Channel__c = :FEC_ConstantCommon.NOTIFICATION_CHANNEL_EMAIL
        ];
        // Lưu ý: Kết quả có thể báo Success/Failure tùy thuộc vào cấu hình OrgWideEmail (trong Test nó có thể fail nếu org chưa có orgwide email active)
        System.assert(histories.size() > 0, 'Phải sinh ra lịch sử gửi Email tự động.');
    }

    @IsTest
    static void testSendSFAppNotifications() {
        Case c = [SELECT Id, OwnerId FROM Case LIMIT 1];
        Group q = [SELECT Id FROM Group WHERE DeveloperName = :getQueueDeveloperName() LIMIT 1];

        // Tạo OldMap chứa dữ liệu cũ
        Map<Id, Case> oldMap = new Map<Id, Case>();
        oldMap.put(c.Id, c.clone(true, true, true, true));

        // Đổi Owner sang Queue
        c.OwnerId = q.Id;
        List<Case> newCases = new List<Case>{c};

        Test.startTest();
        // Gọi Service
        FEC_NotificationService.sendSFAppNotifications(newCases, oldMap);
        Test.stopTest();

        // Kiểm tra lịch sử SF App Notification
        List<FEC_Notification_History__c> histories = [
            SELECT Id, FEC_Send_Status__c, FEC_Failure_Reason__c 
            FROM FEC_Notification_History__c 
            WHERE FEC_Case__c = :c.Id 
              AND FEC_Notification_Channel__c = :FEC_ConstantCommon.NOTIFICATION_CHANNEL_SF_APP
        ];
        System.assert(histories.size() > 0, 'Phải sinh ra lịch sử gửi App Notification tự động.');
    }

    @IsTest
    static void testInlineImages_RegexHandling() {
        // Tạo chuỗi HTML có chứa rtaImage
        String rawHtml = '<p>Test Image <img src="https://fecredit--dev.sandbox.my.salesforce.com/servlet/rtaImage?eid=123&amp;feoid=456" /></p>';
        
        Test.startTest();
        // Trong môi trường Test, hàm này sẽ trả về Blob giả 'Mock Image' -> Encode Base64
        String processedHtml = FEC_NotificationService.inlineImages(rawHtml);
        Test.stopTest();
        
        System.assert(processedHtml.contains('data:image/png;base64,'), 'Phải convert được rtaImage sang chuỗi Base64 inline.');
    }
}