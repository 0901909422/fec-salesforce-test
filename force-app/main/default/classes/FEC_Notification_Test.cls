@IsTest
private class FEC_Notification_Test {

    private static final String CASE_SUBJECT = 'Notification Test Case';

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        insert new FEC_System_Config__c(
            FEC_Sender_Email__c = 'noreply@fecredit.com.test'
        );

        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'PT Test',
            FEC_Code__c = 'PT' + suffix,
            FEC_Active__c = true
        );
        insert pt;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Cat Test',
            FEC_Code__c = 'CAT' + suffix,
            FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'SubCat Test',
            FEC_Code__c = 'SCAT' + suffix,
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'SubCode Test',
            FEC_Code__c = 'SCODE' + suffix,
            FEC_Active__c = true
        );
        insert subCode;

        FEC_Case_Status__c caseStatus = new FEC_Case_Status__c(Name = 'New');
        insert caseStatus;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Stage Notify',
            FEC_Code__c = 'STG' + suffix,
            FEC_Active__c = true
        );
        insert stage;

        FEC_Channel__c channel = new FEC_Channel__c(
            Name = 'Email',
            FEC_Code__c = 'CH' + suffix,
            FEC_Channel_ID__c = 'CH-EMAIL-' + suffix,
            FEC_Channel_Vietnamese_name__c = 'Email',
            FEC_Channel_Status__c = true
        );
        insert channel;

        FEC_Notification_Channel__c notifChannel = new FEC_Notification_Channel__c(
            Name = 'Email',
            FEC_Noti_Channel_Status__c = true
        );
        insert notifChannel;

        FEC_Enhanced_Letterhead__c letterhead = new FEC_Enhanced_Letterhead__c(
            Name = 'Test Letterhead',
            FEC_Header__c = 'Header Content',
            FEC_Footer__c = 'Footer Content'
        );
        insert letterhead;

        FEC_Template__c template = new FEC_Template__c(
            Name = 'Test Template',
            FEC_Subject_Line__c = 'Alert {{{Case.Subject}}}',
            FEC_Body__c = 'Body {{{Case.Subject}}} hist {{{FEC_Customer_History__c.FEC_Email__c}} addi {{{FEC_Additional_Info__c.FEC_Verify_Information__c}}',
            FEC_Enhanced_Letterhead__c = letterhead.Id
        );
        insert template;

        User testUser = new User(
            Alias = 'usrntf',
            Email = 'usrntf@fecredit.com.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'NotifyUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'usrntf_' + suffix + '@fecredit.com.test',
            IsActive = true
        );
        insert testUser;

        String queueDevName = ('Test_Queue_' + suffix).left(40);

        User runAsUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(runAsUser) {
            insert new Group(
                Name = 'Test Queue ' + suffix,
                Type = 'Queue',
                DeveloperName = queueDevName
            );
        }

        FEC_CaseTriggerHandler.isExecuting = true;
        Case existingCase;
        Case nonExistingCase;
        try {
            existingCase = new Case(
                Subject = CASE_SUBJECT,
                FEC_Product_Type__c = pt.Id,
                FEC_Category__c = cat.Id,
                FEC_SubCategory__c = subCat.Id,
                FEC_SubCode__c = subCode.Id,
                FEC_Current_Case_Stage__c = stage.Id,
                FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER,
                Status = 'New'
            );
            insert existingCase;

            nonExistingCase = new Case(
                Subject = 'Non Existing Customer Case',
                FEC_Product_Type__c = pt.Id,
                FEC_Customer_Type__c = FEC_ConstantCommon.CASE_NON_EXISTING_CUSTOMER,
                FEC_Case_Email__c = 'nonexisting@test.com',
                Status = 'New'
            );
            insert nonExistingCase;

            FEC_Customer_History__c custHistory = new FEC_Customer_History__c(
                FEC_Case__c = existingCase.Id,
                FEC_Email__c = 'customer@test.com',
                Name = 'CUST-' + suffix
            );
            insert custHistory;

            existingCase.FEC_Account_or_Contract__c = custHistory.Id;
            update existingCase;

            if (Schema.getGlobalDescribe().containsKey('FEC_Additional_Info__c')) {
                SObject addInfo = Schema.getGlobalDescribe()
                    .get('FEC_Additional_Info__c')
                    .newSObject();
                addInfo.put('FEC_Case__c', existingCase.Id);
                if (addInfo.getSObjectType()
                    .getDescribe()
                    .fields.getMap()
                    .containsKey('FEC_Verify_Information__c')) {
                    String verifyValue = firstActivePicklistValue(
                        'FEC_Additional_Info__c',
                        'FEC_Verify_Information__c'
                    );
                    if (String.isNotBlank(verifyValue)) {
                        addInfo.put('FEC_Verify_Information__c', verifyValue);
                    }
                }
                insert addInfo;
            }
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        RecordType rt = [
            SELECT Id
            FROM RecordType
            WHERE SobjectType = 'FEC_Notification__c'
            LIMIT 1
        ];

        FEC_Notification__c notif = new FEC_Notification__c(
            Name = 'Test Notification',
            RecordTypeId = rt.Id,
            FEC_Product_Type__c = pt.Id,
            FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER,
            FEC_Target_Group__c = 'Customer',
            FEC_Current_Status__c = 'New',
            FEC_Changed_Status__c = 'New',
            FEC_Channel__c = channel.Id + ', Zalo',
            FEC_Assigned_to_Queue__c = queueDevName,
            FEC_SubCategory__c = subCat.Name,
            FEC_SubCode__c = subCode.Name,
            FEC_Case_Stage__c = stage.Name,
            FEC_Notification_Status__c = true
        );
        insert notif;

        insert new FEC_Notification__c(
            Name = 'All Customer Notification',
            RecordTypeId = rt.Id,
            FEC_Product_Type__c = pt.Id,
            FEC_Customer_Type__c = FEC_ConstantCommon.CASE_ALL_REQUEST,
            FEC_Target_Group__c = 'Customer',
            FEC_Notification_Status__c = true
        );

        insert new FEC_Notification_Template_Channel__c(
            FEC_Notification__c = notif.Id,
            FEC_Notification_Channel__c = notifChannel.Id,
            FEC_Notification_Template__c = template.Id
        );
    }

    private static Case getExistingCase() {
        return [
            SELECT Id, Subject, FEC_Product_Type__c, FEC_Category__c,
                FEC_SubCategory__c, FEC_SubCode__c, FEC_Current_Case_Stage__c
            FROM Case
            WHERE Subject = :CASE_SUBJECT
            LIMIT 1
        ];
    }

    private static Case getNonExistingCustomerCase() {
        return [
            SELECT Id, FEC_Product_Type__c
            FROM Case
            WHERE Subject = 'Non Existing Customer Case'
            LIMIT 1
        ];
    }

    private static FEC_Notification__c getMainNotification() {
        return [
            SELECT Id, Name
            FROM FEC_Notification__c
            WHERE Name = 'Test Notification'
            LIMIT 1
        ];
    }

    private static FEC_Template__c getTemplate() {
        return [SELECT Id, Name FROM FEC_Template__c LIMIT 1];
    }

    private static User getSetupUser() {
        return [
            SELECT Id, Email
            FROM User
            WHERE Email = 'usrntf@fecredit.com.test'
            LIMIT 1
        ];
    }

    private static String firstActivePicklistValue(String objectApi, String fieldApi) {
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
            .get(objectApi)
            .getDescribe()
            .fields.getMap();
        if (!fieldMap.containsKey(fieldApi)) {
            return null;
        }
        for (Schema.PicklistEntry entry : fieldMap.get(fieldApi).getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    @IsTest
    static void testGetRecordTypeName() {
        RecordType rt = [SELECT Id FROM RecordType WHERE SobjectType = 'FEC_Notification__c' LIMIT 1];

        Test.startTest();
        RecordType result = FEC_Notification.getRecordTypeName(String.valueOf(rt.Id));
        RecordType missing = FEC_Notification.getRecordTypeName(
            Schema.SObjectType.FEC_Notification__c.getKeyPrefix() + '000000000001'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(rt.Id, result.Id);
        System.assertEquals(null, missing);
    }

    @IsTest
    static void testGetRecordTypeName_InvalidId() {
        Test.startTest();
        RecordType bad = FEC_Notification.getRecordTypeName('not-a-valid-id');
        Test.stopTest();
        System.assertEquals(null, bad);
    }

    @IsTest
    static void testGetNotificationById() {
        FEC_Notification__c notif = getMainNotification();

        Test.startTest();
        Map<String, Object> result = FEC_Notification.getNotificationById(notif.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('record'));
        System.assert(result.containsKey('channels'));
        System.assert(result.containsKey('currentStatusPills'));
        System.assert(result.containsKey('changedStatusPills'));
        System.assert(result.containsKey('subCategoryPills'));
        System.assert(result.containsKey('subCodePills'));
        System.assert(result.containsKey('caseStagePills'));
        System.assert(result.containsKey('queue'));
    }

    @IsTest
    static void testGetAvailableNotifications_ExistingCustomer() {
        Case c = getExistingCase();

        Test.startTest();
        // Several notification criteria fields are long text on this org and cannot be used in SOQL WHERE.
        List<Map<String, Object>> options = FEC_Notification.getAvailableNotifications(
            c.Id,
            String.valueOf(c.FEC_Product_Type__c),
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        System.assert(options.size() >= 2, 'Should match Existing and All notifications.');
    }

    @IsTest
    static void testGetAvailableNotifications_NonExistingCustomer() {
        Case c = getNonExistingCustomerCase();

        Test.startTest();
        List<Map<String, Object>> options = FEC_Notification.getAvailableNotifications(
            c.Id,
            String.valueOf(c.FEC_Product_Type__c),
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        System.assert(options.size() >= 1, 'All-type notification should match any customer type.');
    }

    @IsTest
    static void testSearchInternalUsers() {
        Test.startTest();
        List<User> users = FEC_Notification.searchInternalUsers('usrntf');
        List<User> empty = FEC_Notification.searchInternalUsers('zzz_no_match_xyz');
        Test.stopTest();

        System.assert(users.size() > 0);
        System.assertEquals(0, empty.size());
    }

    @IsTest
    static void testPreviewTemplate_And_MergeFields() {
        Case c = getExistingCase();
        FEC_Template__c template = getTemplate();

        Test.startTest();
        FEC_Template__c previewed = FEC_Notification.previewTemplate(c.Id, template.Id);
        FEC_Template__c noCasePreview = FEC_Notification.previewTemplate(null, template.Id);
        Test.stopTest();

        System.assertNotEquals(null, previewed);
        System.assert(previewed.FEC_Subject_Line__c.contains(c.Subject));
        System.assert(!previewed.FEC_Subject_Line__c.contains('{{{'));
        System.assertEquals(template.Id, noCasePreview.Id);
    }

    @IsTest
    static void testEmailInfoConstructorsAndEmptyBulk() {
        Case c = getExistingCase();

        FEC_Notification.EmailInfo sixParam = new FEC_Notification.EmailInfo(
            c.Id,
            'a@test.com',
            'Subj',
            'Hdr',
            'Bdy',
            'Ftr',
            getTemplate().Id
        );
        FEC_Notification.EmailInfo fiveParam = new FEC_Notification.EmailInfo(
            c.Id,
            'a@test.com',
            'Subj',
            'Hdr',
            'Bdy',
            'Ftr'
        );

        Test.startTest();
        FEC_Notification.executeSendEmailsBulk(new List<FEC_Notification.EmailInfo>(), 'noreply@fecredit.com.test');
        FEC_Notification.executeSendEmailsBulk(null, 'noreply@fecredit.com.test');
        Test.stopTest();

        System.assertEquals(c.Id, sixParam.caseId);
        System.assertEquals(null, fiveParam.templateId);
    }

    @IsTest
    static void testExecuteSendEmailsBulk() {
        Case c = getExistingCase();
        FEC_Template__c template = getTemplate();

        FEC_Notification.EmailInfo emailInfo = new FEC_Notification.EmailInfo(
            c.Id,
            'customer@test.com',
            'Subject {{{Case.Subject}}}',
            '<p>Header</p>',
            'Body {{{Case.Subject}}} {{Case.Subject}}',
            '<p>Footer</p>',
            template.Id
        );

        Test.startTest();
        FEC_Notification.executeSendEmailsBulk(
            new List<FEC_Notification.EmailInfo>{ emailInfo },
            'noreply@fecredit.com.test'
        );
        FEC_Notification.executeSendEmail(
            c.Id,
            'noreply@fecredit.com.test',
            'customer@test.com',
            'Direct {{{Case.Subject}}}',
            'H',
            'Direct body',
            'F',
            template.Id
        );
        Test.stopTest();

        System.assertEquals(
            2,
            [SELECT COUNT() FROM EmailMessage WHERE ParentId = :c.Id]
        );
    }

    @IsTest
    static void testExecuteSendEmailsBulk_WithRoutingHistory() {
        if (!Schema.getGlobalDescribe().containsKey('FEC_Notification_History__c')) {
            System.assert(true, 'Skipped: FEC_Notification_History__c not on org.');
            return;
        }

        Case c = getExistingCase();
        FEC_Notification__c notif = getMainNotification();

        FEC_Notification.EmailInfo emailInfo = new FEC_Notification.EmailInfo(
            c.Id,
            'customer@test.com',
            'Hist {{{Case.Subject}}}',
            '',
            'Body',
            ''
        );

        FEC_Notification.RoutingEmailHistoryInput histInput =
            new FEC_Notification.RoutingEmailHistoryInput();
        histInput.caseId = c.Id;
        histInput.notificationRuleId = notif.Id;
        histInput.stageName = 'Stage Notify';
        histInput.templateDisplayName = 'Test Template';
        histInput.channelName = 'Email';
        histInput.targetGroup = 'Customer';
        histInput.notificationRuleName = notif.Name;

        Test.startTest();
        FEC_Notification.executeSendEmailsBulk(
            new List<FEC_Notification.EmailInfo>{ emailInfo },
            'noreply@fecredit.com.test',
            new List<FEC_Notification.RoutingEmailHistoryInput>{ histInput }
        );
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM FEC_Notification_History__c WHERE FEC_Case__c = :c.Id] > 0
        );
    }

    @IsTest
    static void testSendManualNotification_EmailSuccess() {
        Case c = getExistingCase();
        FEC_Notification__c notif = getMainNotification();
        FEC_Template__c template = getTemplate();

        Test.startTest();
        FEC_Notification.sendManualNotification(
            c.Id,
            template.Id,
            'customer@test.com',
            notif.Id,
            FEC_ConstantCommon.NOTIFICATION_CHANNEL_EMAIL
        );
        Test.stopTest();

        if (Schema.getGlobalDescribe().containsKey('FEC_Notification_History__c')) {
            System.assert(
                [SELECT COUNT() FROM FEC_Notification_History__c WHERE FEC_Case__c = :c.Id] > 0
            );
        }
        System.assert([SELECT COUNT() FROM EmailMessage WHERE ParentId = :c.Id] > 0);
    }

    @IsTest
    static void testSendManualNotification_NoEmailAddress() {
        Case c = getExistingCase();
        FEC_Template__c template = getTemplate();

        update new Case(
            Id = c.Id,
            FEC_Account_or_Contract__c = null
        );

        Test.startTest();
        try {
            FEC_Notification.sendManualNotification(
                c.Id,
                template.Id,
                null,
                null,
                FEC_ConstantCommon.NOTIFICATION_CHANNEL_EMAIL
            );
            System.assert(false, 'Expected exception when no email address.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendManualNotification_MissingTemplate() {
        Case c = getExistingCase();

        Test.startTest();
        try {
            FEC_Notification.sendManualNotification(
                c.Id,
                null,
                'fake@email.com',
                null,
                FEC_ConstantCommon.NOTIFICATION_CHANNEL_EMAIL
            );
            System.assert(false, 'Expected AuraHandledException for missing template.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendManualNotification_ResolvesEmailFromCase() {
        Case c = getExistingCase();
        FEC_Template__c template = getTemplate();

        Test.startTest();
        FEC_Notification.sendManualNotification(
            c.Id,
            template.Id,
            null,
            null,
            FEC_ConstantCommon.NOTIFICATION_CHANNEL_EMAIL
        );
        Test.stopTest();

        System.assert([SELECT COUNT() FROM EmailMessage WHERE ParentId = :c.Id] > 0);
    }

    @IsTest
    static void testGetNotificationById_LookupPillsById() {
        FEC_Notification__c notif = getMainNotification();
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];
        FEC_Sub_Code__c subCode = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1];
        FEC_Case_Stage__c stage = [SELECT Id FROM FEC_Case_Stage__c LIMIT 1];

        notif.FEC_SubCategory__c = subCat.Id;
        notif.FEC_SubCode__c = subCode.Id;
        notif.FEC_Case_Stage__c = stage.Id;
        update notif;

        Test.startTest();
        Map<String, Object> result = FEC_Notification.getNotificationById(notif.Id);
        Test.stopTest();

        List<Object> subCatPills = (List<Object>) result.get('subCategoryPills');
        List<Object> subCodePills = (List<Object>) result.get('subCodePills');
        System.assert(subCatPills.size() > 0);
        System.assert(subCodePills.size() > 0);
    }

    @IsTest
    static void testExecuteSendEmailsBulk_WithTemplateAttachment() {
        Case c = getExistingCase();
        FEC_Template__c template = getTemplate();

        ContentVersion cv = new ContentVersion(
            Title = 'NotifyAttach',
            PathOnClient = 'notify.txt',
            VersionData = Blob.valueOf('attachment body')
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        insert new ContentDocumentLink(
            LinkedEntityId = template.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );

        FEC_Notification.EmailInfo emailInfo = new FEC_Notification.EmailInfo(
            c.Id,
            'customer@test.com',
            'Attach {{{Case.Subject}}}',
            '',
            'Body',
            '',
            template.Id
        );

        Test.startTest();
        FEC_Notification.executeSendEmailsBulk(
            new List<FEC_Notification.EmailInfo>{ emailInfo },
            'noreply@fecredit.com.test'
        );
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM EmailMessage WHERE ParentId = :c.Id] > 0
        );
    }

    @IsTest
    static void testSendManualNotification_SalesforceAppChannel() {
        List<CustomNotificationType> types = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Custom_Notification'
            LIMIT 1
        ];
        if (types.isEmpty()) {
            System.assert(true, 'Skipped: Custom_Notification type not in org.');
            return;
        }

        Case c = getExistingCase();
        FEC_Template__c template = getTemplate();
        User setupUser = getSetupUser();

        Test.startTest();
        FEC_Notification.sendManualNotification(
            c.Id,
            template.Id,
            setupUser.Email,
            getMainNotification().Id,
            FEC_ConstantCommon.NOTIFICATION_CHANNEL_SF_APP
        );
        Test.stopTest();

        if (Schema.getGlobalDescribe().containsKey('FEC_Notification_History__c')) {
            System.assert(
                [
                    SELECT COUNT()
                    FROM FEC_Notification_History__c
                    WHERE FEC_Case__c = :c.Id
                ] > 0
            );
        }
    }

    @IsTest
    static void testSendManualNotification_SfAppTargetUserNotFound() {
        Case c = getExistingCase();
        FEC_Template__c template = getTemplate();

        Test.startTest();
        try {
            FEC_Notification.sendManualNotification(
                c.Id,
                template.Id,
                'no.such.user@fecredit.com.test',
                null,
                FEC_ConstantCommon.NOTIFICATION_CHANNEL_SF_APP
            );
            System.assert(false, 'Expected exception when target user not found.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void testBulkMergeFields_UserAndFlexibleBraces() {
        Case c = getExistingCase();

        FEC_Notification.EmailInfo emailInfo = new FEC_Notification.EmailInfo(
            c.Id,
            'customer@test.com',
            'Subj {{Case.Subject}}',
            '',
            'User {{{User.Email}}} Case {{{Case.Subject}}}',
            ''
        );

        Test.startTest();
        FEC_Notification.executeSendEmailsBulk(
            new List<FEC_Notification.EmailInfo>{ emailInfo },
            UserInfo.getUserEmail()
        );
        Test.stopTest();

        EmailMessage em = [
            SELECT Subject, HtmlBody
            FROM EmailMessage
            WHERE ParentId = :c.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(em.Subject.contains(c.Subject));
        System.assert(!em.HtmlBody.contains('{{{'));
    }
}
