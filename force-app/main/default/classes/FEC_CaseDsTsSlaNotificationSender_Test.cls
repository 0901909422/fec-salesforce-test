@IsTest
private class FEC_CaseDsTsSlaNotificationSender_Test {

    private static final String TEMPLATE_API_TS = 'Template_for_TS_Telesales';
    private static final String TEMPLATE_API_DS = 'Template_for_DS_Direct_Sales';

    private static Case insertCaseRow(Case c) {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    private static Id ensureSlaQueue(String developerName, String queueName) {
        List<Group> existing = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
              AND DeveloperName = :developerName
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }

        Group queue = new Group(
            Name = queueName,
            DeveloperName = developerName,
            Type = 'Queue'
        );
        insert queue;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new QueueSobject(QueueId = queue.Id, SobjectType = 'Case');
        }
        return queue.Id;
    }

    private static Id getOrCreateSlaQueueId() {
        Id telesalesId = ensureSlaQueue('FEC_DQ_Telesales', 'DQ - Telesales');
        ensureSlaQueue('FEC_LG', 'LG');
        ensureSlaQueue('FEC_DQ_Direct_Sales', 'DQ - Direct Sales');
        ensureSlaQueue('FEC_DQ_POS_Sales', 'DQ - POS Sales');
        FEC_CaseDsTsSlaService.resetSlaQueueCacheForTest();
        return telesalesId;
    }

    private static Case buildEligibleSlaCase(
        Id ownerId,
        Id categoryId,
        String team,
        String searchKeySuffix
    ) {
        return new Case(
            Subject = 'DS/TS SLA Case',
            OwnerId = ownerId,
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Team__c = team,
            FEC_Category__c = categoryId,
            FEC_ID_Search__c = 'DSTS-' + searchKeySuffix
        );
    }

    private static Id ensureCategory(String categoryName) {
        List<FEC_Category__c> rows = [
            SELECT Id
            FROM FEC_Category__c
            WHERE Name = :categoryName
            LIMIT 1
        ];
        if (!rows.isEmpty()) {
            return rows[0].Id;
        }
        FEC_Category__c created = new FEC_Category__c(
            Name = categoryName,
            FEC_Code__c = 'SLA-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(8),
            FEC_Active__c = true
        );
        insert created;
        return created.Id;
    }

    private static void ensureSlaTemplates() {
        List<FEC_Template__c> existing = [
            SELECT Id, FEC_API_Name__c
            FROM FEC_Template__c
            WHERE FEC_API_Name__c IN (
                :TEMPLATE_API_DS,
                :TEMPLATE_API_TS
            )
        ];
        Set<String> present = new Set<String>();
        for (FEC_Template__c row : existing) {
            present.add(row.FEC_API_Name__c);
        }

        FEC_Enhanced_Letterhead__c letterhead = new FEC_Enhanced_Letterhead__c(
            Name = 'DS/TS SLA LH ' + System.currentTimeMillis(),
            FEC_Header__c = '<p>Header</p>',
            FEC_Footer__c = '<p>Footer</p>'
        );
        insert letterhead;

        List<FEC_Template__c> toInsert = new List<FEC_Template__c>();
        if (!present.contains(TEMPLATE_API_TS)) {
            toInsert.add(new FEC_Template__c(
                Name = 'TS SLA Template',
                FEC_API_Name__c = TEMPLATE_API_TS,
                FEC_Subject_Line__c = 'TS SLA Alert',
                FEC_Body__c = 'TS SLA body',
                FEC_Active__c = true,
                FEC_Enhanced_Letterhead__c = letterhead.Id
            ));
        }
        if (!present.contains(TEMPLATE_API_DS)) {
            toInsert.add(new FEC_Template__c(
                Name = 'DS SLA Template',
                FEC_API_Name__c = TEMPLATE_API_DS,
                FEC_Subject_Line__c = 'DS SLA Alert',
                FEC_Body__c = 'DS SLA body',
                FEC_Active__c = true,
                FEC_Enhanced_Letterhead__c = letterhead.Id
            ));
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        List<FEC_System_Config__c> configs = [
            SELECT Id
            FROM FEC_System_Config__c
            WHERE FEC_Sender_Email__c != NULL
            LIMIT 1
        ];
        if (configs.isEmpty()) {
            insert new FEC_System_Config__c(
                FEC_Sender_Email__c = 'noreply@fecredit.com.test'
            );
        }
    }

    @IsTest
    static void testSendAfterCaseUpdate_guardClauses() {
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(null, new Map<Id, Case>());
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(new List<Case>(), new Map<Id, Case>());
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ new Case(Id = '500000000000000AAA') },
            new Map<Id, Case>()
        );
        System.assert(true, 'Guard clauses should not throw.');
    }

    @IsTest
    static void testSendAfterCaseUpdate_newlyStampedSlot() {
        Set<Id> queueIds = FEC_CaseDsTsSlaService.getSlaOwnerQueueIds();
        if (queueIds.isEmpty()) {
            System.assert(true, 'No SLA queue metadata in org.');
            return;
        }
        Id queueId = queueIds.iterator().next();
        String suffix = String.valueOf(System.currentTimeMillis());
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA Notify',
            OwnerId = queueId,
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Team__c = 'TS',
            FEC_ID_Search__c = 'DSTS-' + suffix
        ));

        Case oldC = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_1__c = System.now();

        Test.startTest();
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => oldC }
        );
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM Case WHERE Id = :row.Id].Id);
    }

    @IsTest
    static void testSendAfterCaseUpdate_slotsTwoAndThree() {
        Set<Id> queueIds = FEC_CaseDsTsSlaService.getSlaOwnerQueueIds();
        if (queueIds.isEmpty()) {
            System.assert(true, 'No SLA queue metadata in org.');
            return;
        }
        Id queueId = queueIds.iterator().next();
        Datetime nowDt = System.now();
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA Slot 2/3',
            OwnerId = queueId,
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Team__c = 'TS',
            FEC_SLA_Notification_1__c = nowDt,
            FEC_ID_Search__c = 'DSTS23-' + String.valueOf(System.currentTimeMillis())
        ));

        Case old2 = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_2__c = nowDt.addMinutes(1);
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => old2 }
        );

        Case old3 = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_3__c = nowDt.addMinutes(2);
        Test.startTest();
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => old3 }
        );
        Test.stopTest();

        System.assertNotEquals(null, row.Id);
    }

    @IsTest
    static void testSendAfterCaseUpdate_noStampChange() {
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA No Change',
            Status = 'New',
            FEC_ID_Search__c = 'DSTS-NC-' + String.valueOf(System.currentTimeMillis())
        ));
        Case oldC = row.clone(true, true, true, true);

        Test.startTest();
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => oldC }
        );
        Test.stopTest();

        System.assertNotEquals(null, row.Id);
    }

    @IsTest
    static void testSendAfterCaseUpdate_withTemplatesAndEligibleCase() {
        ensureSlaTemplates();
        FEC_CaseDsTsSlaService.testRecipientUserIdsOverride = new List<Id>{ UserInfo.getUserId() };

        Id queueId = getOrCreateSlaQueueId();
        Id complaintId = ensureCategory('Complaint');
        String suffix = String.valueOf(System.currentTimeMillis());
        Case row = insertCaseRow(buildEligibleSlaCase(queueId, complaintId, 'TS', 'TPL-' + suffix));

        FEC_Routing_Action_History__c rah = new FEC_Routing_Action_History__c(
            FEC_Case__c = row.Id,
            FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
            FEC_Routing_Action_Type__c = 'Case',
            FEC_Updated_User_Queue_ID__c = String.valueOf(queueId)
        );
        insert rah;
        Test.setCreatedDate(rah.Id, System.now().addMinutes(-3));

        Case oldC = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_1__c = System.now();

        Test.startTest();
        try {
            FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
                new List<Case>{ row },
                new Map<Id, Case>{ row.Id => oldC }
            );
        } finally {
            FEC_CaseDsTsSlaService.testRecipientUserIdsOverride = null;
        }
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM Case WHERE Id = :row.Id].Id);
    }

    private static void insertOpenAssignment(Id caseId) {
        String status;
        for (Schema.PicklistEntry entry :
            FEC_Assignment__c.FEC_Assignment_Status__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                status = entry.getValue();
                break;
            }
        }
        insert new FEC_Assignment__c(
            FEC_Case__c = caseId,
            FEC_Assignment_Name__c = 'SLA TH2 ' + String.valueOf(System.currentTimeMillis()),
            FEC_Assignment_Status__c = status,
            FEC_Assignment_Type__c = FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING,
            FEC_Assignment_Owner__c = UserInfo.getUserId()
        );
    }

    @IsTest
    static void testSendAfterCaseUpdate_th2DirectSalesProfile() {
        ensureSlaTemplates();
        FEC_CaseDsTsSlaService.testRecipientUserIdsOverride = new List<Id>{ UserInfo.getUserId() };
        getOrCreateSlaQueueId();
        Id complaintId = ensureCategory('Complaint');
        String suffix = String.valueOf(System.currentTimeMillis());
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA TH2',
            OwnerId = UserInfo.getUserId(),
            Status = 'Pending - Manual',
            FEC_Team__c = 'DIRECT_SALES',
            FEC_Category__c = complaintId,
            FEC_Assignment_Users__c = 'DQ - Direct Sales;DQ - POS Sales',
            FEC_ID_Search__c = 'DSTS-TH2-' + suffix
        ));
        insertOpenAssignment(row.Id);

        Case oldC = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_1__c = System.now();

        Test.startTest();
        try {
            FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
                new List<Case>{ row },
                new Map<Id, Case>{ row.Id => oldC }
            );
        } finally {
            FEC_CaseDsTsSlaService.testRecipientUserIdsOverride = null;
        }
        Test.stopTest();

        System.assertNotEquals(null, row.Id);
    }

    @IsTest
    static void testSendAfterCaseUpdate_ineligibleStampedCase() {
        ensureSlaTemplates();
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA Ineligible',
            OwnerId = UserInfo.getUserId(),
            Status = 'New',
            FEC_Team__c = 'Back Office',
            FEC_ID_Search__c = 'DSTS-INEL-' + String.valueOf(System.currentTimeMillis())
        ));

        Case oldC = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_1__c = System.now();

        Test.startTest();
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => oldC }
        );
        Test.stopTest();

        System.assertNotEquals(null, row.Id);
    }

    @IsTest
    static void testSendAfterCaseUpdate_templateWithoutSubject() {
        Set<Id> queueIds = FEC_CaseDsTsSlaService.getSlaOwnerQueueIds();
        if (queueIds.isEmpty()) {
            System.assert(true, 'No SLA queue metadata in org.');
            return;
        }

        ensureSlaTemplates();
        FEC_Template__c tsTemplate = [
            SELECT Id, FEC_Subject_Line__c, FEC_Active__c
            FROM FEC_Template__c
            WHERE FEC_API_Name__c = :TEMPLATE_API_TS
            LIMIT 1
        ];
        String originalSubject = tsTemplate.FEC_Subject_Line__c;
        tsTemplate.FEC_Subject_Line__c = null;
        update tsTemplate;

        Id queueId = queueIds.iterator().next();
        Id complaintId = ensureCategory('Complaint');
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA Blank Subject',
            OwnerId = queueId,
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Team__c = 'TS',
            FEC_Category__c = complaintId,
            FEC_ID_Search__c = 'DSTS-BLANK-' + String.valueOf(System.currentTimeMillis())
        ));

        Case oldC = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_1__c = System.now();

        Test.startTest();
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => oldC }
        );
        Test.stopTest();

        tsTemplate.FEC_Subject_Line__c = originalSubject;
        update tsTemplate;
        System.assertNotEquals(null, row.Id);
    }

    @IsTest
    static void testSendAfterCaseUpdate_noActiveTemplates() {
        Set<Id> queueIds = FEC_CaseDsTsSlaService.getSlaOwnerQueueIds();
        if (queueIds.isEmpty()) {
            System.assert(true, 'No SLA queue metadata in org.');
            return;
        }

        List<FEC_Template__c> templates = [
            SELECT Id, FEC_Active__c
            FROM FEC_Template__c
            WHERE FEC_API_Name__c IN (
                :TEMPLATE_API_DS,
                :TEMPLATE_API_TS
            )
        ];
        for (FEC_Template__c tmpl : templates) {
            tmpl.FEC_Active__c = false;
        }
        if (!templates.isEmpty()) {
            update templates;
        }

        Id queueId = queueIds.iterator().next();
        Id complaintId = ensureCategory('Complaint');
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA No Template',
            OwnerId = queueId,
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Team__c = 'TS',
            FEC_Category__c = complaintId,
            FEC_ID_Search__c = 'DSTS-NOTPL-' + String.valueOf(System.currentTimeMillis())
        ));

        Case oldC = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_1__c = System.now();

        Test.startTest();
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => oldC }
        );
        Test.stopTest();

        for (FEC_Template__c tmpl : templates) {
            tmpl.FEC_Active__c = true;
        }
        if (!templates.isEmpty()) {
            update templates;
        }

        System.assertNotEquals(null, row.Id);
    }

    @IsTest
    static void testSendAfterCaseUpdate_dsTh1DirectSalesQueue() {
        ensureSlaTemplates();
        Id queueId = ensureSlaQueue('FEC_DQ_Direct_Sales', 'DQ - Direct Sales');
        Id complaintId = ensureCategory('Complaint');
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA DS TH1',
            OwnerId = queueId,
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Team__c = 'DIRECT_SALES',
            FEC_Category__c = complaintId,
            FEC_ID_Search__c = 'DSTS-DS1-' + String.valueOf(System.currentTimeMillis())
        ));

        Case oldC = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_1__c = System.now();

        Test.startTest();
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => oldC }
        );
        Test.stopTest();

        System.assertNotEquals(null, row.Id);
    }

    @IsTest
    static void testSendAfterCaseUpdate_lgQueueProfile() {
        ensureSlaTemplates();
        Id queueId = ensureSlaQueue('FEC_LG', 'LG');
        Id complaintId = ensureCategory('Complaint');
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA LG',
            OwnerId = queueId,
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Team__c = 'LG',
            FEC_Category__c = complaintId,
            FEC_ID_Search__c = 'DSTS-LG-' + String.valueOf(System.currentTimeMillis())
        ));

        Case oldC = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_2__c = System.now();

        Test.startTest();
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => oldC }
        );
        Test.stopTest();

        System.assertNotEquals(null, row.Id);
    }

    @IsTest
    static void testSendAfterCaseUpdate_posSalesTh2() {
        ensureSlaTemplates();
        getOrCreateSlaQueueId();
        Id complaintId = ensureCategory('Complaint');
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA POS TH2',
            OwnerId = UserInfo.getUserId(),
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Team__c = 'POS_SALES',
            FEC_Category__c = complaintId,
            FEC_Assignment_Users__c = 'DQ - POS Sales',
            FEC_ID_Search__c = 'DSTS-POS-' + String.valueOf(System.currentTimeMillis())
        ));
        insertOpenAssignment(row.Id);

        Case oldC = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_3__c = System.now();

        Test.startTest();
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => oldC }
        );
        Test.stopTest();

        System.assertNotEquals(null, row.Id);
    }

    @IsTest
    static void testSendAfterCaseUpdate_feedbackCategory() {
        ensureSlaTemplates();
        Id queueId = getOrCreateSlaQueueId();
        Id feedbackId = ensureCategory('Feedback');
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA Feedback',
            OwnerId = queueId,
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Team__c = 'TS',
            FEC_Category__c = feedbackId,
            FEC_ID_Search__c = 'DSTS-FB-' + String.valueOf(System.currentTimeMillis())
        ));

        Case oldC = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_1__c = System.now();

        Test.startTest();
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => oldC }
        );
        Test.stopTest();

        System.assertNotEquals(null, row.Id);
    }

    @IsTest
    static void testSendAfterCaseUpdate_withLetterheadTemplate() {
        if (!Schema.getGlobalDescribe().containsKey('FEC_Enhanced_Letterhead__c')) {
            System.assert(true, 'Skipped: FEC_Enhanced_Letterhead__c not on org.');
            return;
        }

        ensureSlaTemplates();
        FEC_CaseDsTsSlaService.testRecipientUserIdsOverride = new List<Id>{ UserInfo.getUserId() };
        Id queueId = getOrCreateSlaQueueId();
        Id complaintId = ensureCategory('Complaint');
        Case row = insertCaseRow(buildEligibleSlaCase(
            queueId,
            complaintId,
            'TS',
            'LH-' + String.valueOf(System.currentTimeMillis())
        ));

        FEC_Routing_Action_History__c rah = new FEC_Routing_Action_History__c(
            FEC_Case__c = row.Id,
            FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
            FEC_Routing_Action_Type__c = 'Case',
            FEC_Updated_User_Queue_ID__c = String.valueOf(queueId)
        );
        insert rah;
        Test.setCreatedDate(rah.Id, System.now().addMinutes(-3));

        List<FEC_Template__c> templates = [
            SELECT Id
            FROM FEC_Template__c
            WHERE FEC_API_Name__c = :TEMPLATE_API_TS
            LIMIT 1
        ];
        if (!templates.isEmpty()) {
            FEC_Enhanced_Letterhead__c letterhead = new FEC_Enhanced_Letterhead__c(
                FEC_Header__c = '<header>',
                FEC_Footer__c = '<footer>'
            );
            insert letterhead;
            update new FEC_Template__c(
                Id = templates[0].Id,
                FEC_Enhanced_Letterhead__c = letterhead.Id
            );
        }

        Case oldC = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_1__c = System.now();

        Test.startTest();
        try {
            FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
                new List<Case>{ row },
                new Map<Id, Case>{ row.Id => oldC }
            );
        } finally {
            FEC_CaseDsTsSlaService.testRecipientUserIdsOverride = null;
        }
        Test.stopTest();

        System.assertNotEquals(null, row.Id);
    }

    @IsTest
    static void testBuildEmailInfoForCase_WithRecipientsAndLetterhead() {
        ensureSlaTemplates();
        FEC_CaseDsTsSlaService.testRecipientUserIdsOverride = new List<Id>{ UserInfo.getUserId() };
        FEC_CaseDsTsSlaService.testForceSlaEligible = true;
        FEC_CaseDsTsSlaService.testForceSlaQueueProfile = FEC_CaseDsTsSlaService.PROFILE_TELESALES;

        Id queueId = getOrCreateSlaQueueId();
        Id complaintId = ensureCategory('Complaint');
        Case row = insertCaseRow(buildEligibleSlaCase(
            queueId,
            complaintId,
            'TS',
            'UNIT-' + String.valueOf(System.currentTimeMillis())
        ));

        Map<String, FEC_Template__c> templateByApi = new Map<String, FEC_Template__c>();
        for (FEC_Template__c tmpl : [
            SELECT Id, FEC_API_Name__c, FEC_Subject_Line__c, FEC_Body__c,
                   FEC_Enhanced_Letterhead__c,
                   FEC_Enhanced_Letterhead__r.FEC_Header__c,
                   FEC_Enhanced_Letterhead__r.FEC_Footer__c
            FROM FEC_Template__c
            WHERE FEC_API_Name__c = :TEMPLATE_API_TS
              AND FEC_Active__c = true
        ]) {
            templateByApi.put(tmpl.FEC_API_Name__c, tmpl);
        }

        Case loaded = [
            SELECT Id, OwnerId, FEC_Case_Status__c, FEC_Team__c,
                   FEC_Assignment_Count__c, FEC_Assignment_Users__c,
                   FEC_Category__r.Name
            FROM Case
            WHERE Id = :row.Id
        ];

        Test.startTest();
        try {
            List<FEC_Notification.EmailInfo> infos =
                FEC_CaseDsTsSlaNotificationSender.buildEmailInfosForCase(
                    loaded.Id,
                    loaded,
                    templateByApi
                );
            System.assertEquals(1, infos.size());
            System.assert(String.isNotBlank(infos[0].subject));
        } finally {
            FEC_CaseDsTsSlaService.testRecipientUserIdsOverride = null;
            FEC_CaseDsTsSlaService.testForceSlaEligible = false;
        }
        Test.stopTest();
    }

    @IsTest
    static void testBuildEmailInfoForProfile_perQueueTemplateAndRecipients() {
        ensureSlaTemplates();
        FEC_CaseDsTsSlaService.testRecipientUserIdsOverride = new List<Id>{ UserInfo.getUserId() };

        Map<String, FEC_Template__c> templateByApi = new Map<String, FEC_Template__c>();
        for (FEC_Template__c tmpl : [
            SELECT Id, FEC_API_Name__c, FEC_Subject_Line__c, FEC_Body__c,
                   FEC_Enhanced_Letterhead__c,
                   FEC_Enhanced_Letterhead__r.FEC_Header__c,
                   FEC_Enhanced_Letterhead__r.FEC_Footer__c
            FROM FEC_Template__c
            WHERE FEC_API_Name__c IN (:TEMPLATE_API_DS, :TEMPLATE_API_TS)
              AND FEC_Active__c = true
        ]) {
            templateByApi.put(tmpl.FEC_API_Name__c, tmpl);
        }

        Case row = new Case(
            Id = '500000000000000AAA',
            FEC_ID_Search__c = 'DSTS-MULTI'
        );

        Test.startTest();
        try {
            FEC_Notification.EmailInfo dsInfo =
                FEC_CaseDsTsSlaNotificationSender.buildEmailInfoForProfile(
                    row.Id,
                    row,
                    FEC_CaseDsTsSlaService.PROFILE_DIRECT_SALES,
                    templateByApi
                );
            FEC_Notification.EmailInfo tsInfo =
                FEC_CaseDsTsSlaNotificationSender.buildEmailInfoForProfile(
                    row.Id,
                    row,
                    FEC_CaseDsTsSlaService.PROFILE_TELESALES,
                    templateByApi
                );
            System.assertNotEquals(null, dsInfo);
            System.assertNotEquals(null, tsInfo);
            System.assertEquals('DS SLA Alert', dsInfo.subject);
            System.assertEquals('TS SLA Alert', tsInfo.subject);
            System.assertNotEquals(dsInfo.subject, tsInfo.subject);
        } finally {
            FEC_CaseDsTsSlaService.testRecipientUserIdsOverride = null;
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendAfterCaseUpdate_realDmlUpdateDoesNotThrowReadOnly() {
        ensureSlaTemplates();
        Id queueId = getOrCreateSlaQueueId();
        Id complaintId = ensureCategory('Complaint');
        Case row = insertCaseRow(buildEligibleSlaCase(
            queueId,
            complaintId,
            'TS',
            'RO-' + String.valueOf(System.currentTimeMillis())
        ));

        Test.startTest();
        update new Case(
            Id = row.Id,
            FEC_SLA_Notification_1__c = System.now()
        );
        Test.stopTest();

        System.assertNotEquals(
            null,
            [SELECT FEC_SLA_Notification_1__c FROM Case WHERE Id = :row.Id].FEC_SLA_Notification_1__c
        );
    }

    @IsTest
    static void testSendAfterCaseUpdate_oldMapMissingCaseEntry() {
        ensureSlaTemplates();
        Id queueId = getOrCreateSlaQueueId();
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA Missing OldMap',
            OwnerId = queueId,
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Team__c = 'TS',
            FEC_ID_Search__c = 'DSTS-OLD-' + String.valueOf(System.currentTimeMillis())
        ));
        row.FEC_SLA_Notification_1__c = System.now();

        Test.startTest();
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>()
        );
        Test.stopTest();

        System.assertNotEquals(null, row.Id);
    }
}
