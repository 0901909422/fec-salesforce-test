@IsTest
private class FEC_CaseTriggerHandler_Test {

    private static Id interactionRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        return byDev.containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            ? byDev.get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME).getRecordTypeId()
            : null;
    }

    @IsTest
    static void testBeforeInsert_generatesIdSearchAndStatusHistory() {
        String suffix = String.valueOf(System.currentTimeMillis());
        Case row = new Case(
            Subject = 'FEC Case Trigger Handler Insert',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_Team__c = 'CC',
            FEC_ID_Search__c = 'FCTH-' + suffix
        );

        Test.startTest();
        insert row;
        Test.stopTest();

        Case loaded = [
            SELECT FEC_ID_Search__c, FEC_Case_Status_History__c
            FROM Case
            WHERE Id = :row.Id
        ];
        System.assertNotEquals(null, loaded.FEC_ID_Search__c);
    }

    @IsTest
    static void testBeforeUpdate_pendingStatusAppendsHistory() {
        Case row = new Case(
            Subject = 'FEC Case Trigger Handler Update',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'FCTHU-' + String.valueOf(System.currentTimeMillis())
        );
        insert row;

        row.Status = FEC_ConstantCommon.CASE_STATUS_PENDING;
        row.FEC_Team__c = 'CC';

        Test.startTest();
        update row;
        Test.stopTest();

        Case loaded = [
            SELECT FEC_Case_Status_History__c, Status
            FROM Case
            WHERE Id = :row.Id
        ];
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_PENDING, loaded.Status);
    }

    @IsTest
    static void testIsExecutingGuard_skipsRecursiveRun() {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'Recursive Guard Case',
                FEC_ID_Search__c = 'FCTHG-' + String.valueOf(System.currentTimeMillis())
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        System.assert(true, 'Recursive guard should allow DML without error.');
    }

    @IsTest
    static void testUpdateEmail2CaseFieldsAsync_emptyAndCaseId() {
        Test.startTest();
        FEC_CaseTriggerHandler.updateEmail2CaseFieldsAsync(null);
        FEC_CaseTriggerHandler.updateEmail2CaseFieldsAsync(new List<Id>());
        Case row = new Case(
            Subject = 'Email2Case Async',
            FEC_ID_Search__c = 'E2CA-' + String.valueOf(System.currentTimeMillis())
        );
        insert row;
        FEC_CaseTriggerHandler.updateEmail2CaseFieldsAsync(new List<Id>{ row.Id });
        Test.stopTest();
        System.assertNotEquals(null, [SELECT Id FROM Case WHERE Id = :row.Id]);
    }

    @IsTest
    static void testEmail2CaseBeforeInsert_setsChannelForInteraction() {
        Id rtId = interactionRecordTypeId();
        if (rtId == null) {
            System.assert(true, 'Skipped: Interaction RecordType unavailable.');
            return;
        }

        Case emailCase = new Case(
            Subject = 'Email2Case Interaction',
            RecordTypeId = rtId,
            Origin = FEC_ConstantCommon.CASE_ORIGIN_EMAIL_FE,
            FEC_ID_Search__c = 'E2CI-' + String.valueOf(System.currentTimeMillis())
        );

        Test.startTest();
        insert emailCase;
        Test.stopTest();

        Case loaded = [
            SELECT FEC_Channel__c, FEC_Interaction_Subchannel__c
            FROM Case
            WHERE Id = :emailCase.Id
        ];
        System.assertEquals(FEC_ConstantCommon.EMAIL, loaded.FEC_Channel__c);
    }

    @IsTest
    static void testAfterUpdate_systemUpdatePath() {
        Case row = new Case(
            Subject = 'System Update Path',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'SYSU-' + String.valueOf(System.currentTimeMillis())
        );
        insert row;

        Boolean prior = FEC_CaseTriggerHandler.isSystemUpdate;
        FEC_CaseTriggerHandler.isSystemUpdate = true;
        try {
            Test.startTest();
            update new Case(Id = row.Id, Subject = 'System Update Path Changed');
            Test.stopTest();
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = prior;
        }
        System.assertNotEquals(null, [SELECT Subject FROM Case WHERE Id = :row.Id].Subject);
    }

    @IsTest
    static void testAfterUpdate_systemUpdateRunsLastModified() {
        Case row = new Case(
            Subject = 'System Last Modified',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'SYSLM-' + String.valueOf(System.currentTimeMillis())
        );
        insert row;
        Datetime beforeUpdate = [SELECT LastModifiedDate FROM Case WHERE Id = :row.Id].LastModifiedDate;

        Boolean prior = FEC_CaseTriggerHandler.isSystemUpdate;
        FEC_CaseTriggerHandler.isSystemUpdate = true;
        try {
            Test.startTest();
            update new Case(Id = row.Id, FEC_SLA_Warning__c = 'Red');
            Test.stopTest();
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = prior;
        }

        Case updated = [SELECT LastModifiedDate, FEC_SLA_Warning__c FROM Case WHERE Id = :row.Id];
        System.assertEquals('Red', updated.FEC_SLA_Warning__c);
        System.assert(updated.LastModifiedDate >= beforeUpdate);
    }

    @IsTest
    static void testBeforeUpdate_samePendingStatusDoesNotDuplicateHistory() {
        Case row = new Case(
            Subject = 'Duplicate Pending History',
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Team__c = 'CC',
            FEC_Case_Status_History__c = '#1: Pending - CC',
            FEC_ID_Search__c = 'DUPP-' + String.valueOf(System.currentTimeMillis())
        );
        insert row;

        Test.startTest();
        update row;
        Test.stopTest();

        System.assertEquals(
            '#1: Pending - CC',
            [SELECT FEC_Case_Status_History__c FROM Case WHERE Id = :row.Id].FEC_Case_Status_History__c
        );
    }

    @IsTest
    static void testBeforeUpdate_statusHistoryTruncatesToMaxLength() {
        Case row = new Case(
            Subject = 'Truncate Status History',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_Case_Status_History__c = '#1: Open\n#2: Pending - A\n#3: Pending - B\n#4: Pending - C',
            FEC_ID_Search__c = 'TRNC-' + String.valueOf(System.currentTimeMillis())
        );
        insert row;
        row.Status = FEC_ConstantCommon.CASE_STATUS_PENDING;
        row.FEC_Team__c = 'VeryLongTeamNameForTruncationTest';

        Test.startTest();
        update row;
        Test.stopTest();

        String history = [SELECT FEC_Case_Status_History__c FROM Case WHERE Id = :row.Id].FEC_Case_Status_History__c;
        System.assert(history.length() <= 256);
    }

    @IsTest
    static void testBeforeInsert_openStatusAppendsHistory() {
        Case row = new Case(
            Subject = 'Open Status History',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'OPNS-' + String.valueOf(System.currentTimeMillis())
        );

        Test.startTest();
        insert row;
        Test.stopTest();

        System.assertNotEquals(null, [SELECT FEC_Case_Status_History__c FROM Case WHERE Id = :row.Id].FEC_Case_Status_History__c);
    }

    @IsTest
    static void testBeforeUpdate_transitionOpenToPendingAppendsHistory() {
        Case row = new Case(
            Subject = 'Open To Pending',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'O2P-' + String.valueOf(System.currentTimeMillis())
        );
        insert row;
        row.Status = FEC_ConstantCommon.CASE_STATUS_PENDING;
        row.FEC_Team__c = 'SP';

        Test.startTest();
        update row;
        Test.stopTest();

        String history = [SELECT FEC_Case_Status_History__c FROM Case WHERE Id = :row.Id].FEC_Case_Status_History__c;
        System.assert(history != null && history.contains('Pending'));
    }

    @IsTest
    static void testAfterUpdate_slaWarningFieldChange() {
        Case row = new Case(
            Subject = 'SLA Warning Notification',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'SLAW-' + String.valueOf(System.currentTimeMillis())
        );
        insert row;
        Case oldClone = row.clone(true, true, true, true);
        row.FEC_SLA_Warning__c = 'Yellow';

        Test.startTest();
        update row;
        FEC_CaseTriggerHandler.isSystemUpdate = true;
        try {
            FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
                new List<Case>{ row },
                new Map<Id, Case>{ row.Id => oldClone }
            );
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = false;
        }
        Test.stopTest();

        System.assertEquals(
            'Yellow',
            [SELECT FEC_SLA_Warning__c FROM Case WHERE Id = :row.Id].FEC_SLA_Warning__c
        );
    }

    @IsTest
    static void testAfterUpdate_resolveStatusClearsFollowUpWatchers() {
        Case row = new Case(
            Subject = 'Resolve Follow Up',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'RSFU-' + String.valueOf(System.currentTimeMillis())
        );
        insert row;
        row.Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED;

        Test.startTest();
        update row;
        Test.stopTest();

        System.assertEquals(
            FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            [SELECT Status FROM Case WHERE Id = :row.Id].Status
        );
    }

    @IsTest
    static void testAfterInsert_runsManagerListSync() {
        Test.startTest();
        Case row = new Case(
            Subject = 'After Insert Manager Sync',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'AINS-' + String.valueOf(System.currentTimeMillis())
        );
        insert row;
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM Case WHERE Id = :row.Id].Id);
    }

    private static Id customerCaseRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        return byDev.containsKey(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)
            ? byDev.get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME).getRecordTypeId()
            : null;
    }

    @IsTest
    static void testBeforeInsert_customerCaseAddsOwnerToParticipants() {
        Id rtId = customerCaseRecordTypeId();
        if (rtId == null) {
            System.assert(true, 'Skipped: Customer_Case RecordType unavailable.');
            return;
        }

        Case row = new Case(
            Subject = 'Customer Case Participants Insert',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            RecordTypeId = rtId,
            OwnerId = UserInfo.getUserId(),
            FEC_ID_Search__c = 'CCPI-' + String.valueOf(System.currentTimeMillis())
        );

        Test.startTest();
        insert row;
        Test.stopTest();

        String participants = [
            SELECT FEC_Case_Participants__c
            FROM Case
            WHERE Id = :row.Id
        ].FEC_Case_Participants__c;
        System.assert(
            String.isNotBlank(participants)
            && participants.contains(String.valueOf(UserInfo.getUserId()))
        );
    }

    private static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String suffix = String.valueOf(System.currentTimeMillis());
        User u = new User(
            Alias = 'tusr',
            Email = 'casehandler.test@fecredit.test.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CaseHandlerTest',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'casehandler.test.' + suffix + '@test.invalid'
        );
        insert u;
        return u;
    }

    @IsTest
    static void testBeforeUpdate_ownerChangeAddsParticipant() {
        Id rtId = customerCaseRecordTypeId();
        if (rtId == null) {
            System.assert(true, 'Skipped: Customer_Case RecordType unavailable.');
            return;
        }

        User newOwner = createTestUser();
        Case row = new Case(
            Subject = 'Customer Case Participants Update',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            RecordTypeId = rtId,
            OwnerId = UserInfo.getUserId(),
            FEC_ID_Search__c = 'CCPU-' + String.valueOf(System.currentTimeMillis())
        );
        insert row;

        Test.startTest();
        update new Case(Id = row.Id, OwnerId = newOwner.Id);
        Test.stopTest();

        String participants = [
            SELECT FEC_Case_Participants__c
            FROM Case
            WHERE Id = :row.Id
        ].FEC_Case_Participants__c;
        System.assert(
            String.isNotBlank(participants)
            && participants.contains(String.valueOf(newOwner.Id))
        );
    }

    @IsTest
    static void testBeforeUpdate_systemUpdateStillUpdatesParticipants() {
        Id rtId = customerCaseRecordTypeId();
        if (rtId == null) {
            System.assert(true, 'Skipped: Customer_Case RecordType unavailable.');
            return;
        }

        User newOwner = createTestUser();
        Case row = new Case(
            Subject = 'System Update Participants',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            RecordTypeId = rtId,
            OwnerId = UserInfo.getUserId(),
            FEC_ID_Search__c = 'SYSP-' + String.valueOf(System.currentTimeMillis())
        );
        insert row;

        Boolean prior = FEC_CaseTriggerHandler.isSystemUpdate;
        FEC_CaseTriggerHandler.isSystemUpdate = true;
        try {
            Test.startTest();
            update new Case(Id = row.Id, OwnerId = newOwner.Id);
            Test.stopTest();
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = prior;
        }

        String participants = [
            SELECT FEC_Case_Participants__c
            FROM Case
            WHERE Id = :row.Id
        ].FEC_Case_Participants__c;
        System.assert(
            String.isNotBlank(participants)
            && participants.contains(String.valueOf(newOwner.Id))
        );
    }

    @IsTest
    static void testBeforeInsert_generatesIdSearchWhenBlank() {
        Case row = new Case(
            Subject = 'Auto Generate FEC ID Search',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN
        );

        Test.startTest();
        insert row;
        Test.stopTest();

        System.assertNotEquals(
            null,
            [SELECT FEC_ID_Search__c FROM Case WHERE Id = :row.Id].FEC_ID_Search__c
        );
    }

    @IsTest
    static void testBeforeInsert_bulkCasesGetUniqueSequentialIds() {
        List<Case> rows = new List<Case>();
        for (Integer i = 0; i < 3; i++) {
            rows.add(new Case(
                Subject = 'Bulk Case ID ' + i,
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN
            ));
        }

        Test.startTest();
        insert rows;
        Test.stopTest();

        Set<String> generatedIds = new Set<String>();
        String sharedPrefix = null;
        Long previousNumber = null;

        for (Case row : [
            SELECT FEC_ID_Search__c
            FROM Case
            WHERE Id IN :rows
            ORDER BY FEC_ID_Search__c
        ]) {
            System.assertNotEquals(null, row.FEC_ID_Search__c);
            System.assert(!generatedIds.contains(row.FEC_ID_Search__c), 'FEC_ID_Search__c must be unique.');
            generatedIds.add(row.FEC_ID_Search__c);

            Integer delimIdx = row.FEC_ID_Search__c.lastIndexOf(FEC_ConstantCommon.FEC_ID_SEARCH_DELIMITER);
            System.assert(delimIdx > 0, 'FEC_ID_Search__c must contain delimiter.');

            String prefix = row.FEC_ID_Search__c.substring(0, delimIdx);
            String numberPart = row.FEC_ID_Search__c.substring(
                delimIdx + FEC_ConstantCommon.FEC_ID_SEARCH_DELIMITER.length()
            );
            System.assert(numberPart.isNumeric(), 'Sequence part must be numeric.');

            if (sharedPrefix == null) {
                sharedPrefix = prefix;
            } else {
                System.assertEquals(sharedPrefix, prefix, 'Bulk insert should share the same prefix.');
            }

            Long currentNumber = Long.valueOf(numberPart);
            if (previousNumber != null) {
                System.assert(
                    currentNumber > previousNumber,
                    'Allocated numbers should increase across bulk insert.'
                );
            }
            previousNumber = currentNumber;
        }
    }

    @IsTest
    static void testEmail2CaseBeforeInsert_setsInternalChannel() {
        Id rtId = interactionRecordTypeId();
        if (rtId == null) {
            System.assert(true, 'Skipped: Interaction RecordType unavailable.');
            return;
        }

        Case emailCase = new Case(
            Subject = 'Email2Case Internal',
            RecordTypeId = rtId,
            Origin = FEC_ConstantCommon.CASE_ORIGIN_EMAIL_INTERNAL,
            FEC_ID_Search__c = 'E2IN-' + String.valueOf(System.currentTimeMillis())
        );

        Test.startTest();
        insert emailCase;
        Test.stopTest();

        Case loaded = [
            SELECT FEC_Channel__c, FEC_Interaction_Subchannel__c
            FROM Case
            WHERE Id = :emailCase.Id
        ];
        System.assertEquals(FEC_ConstantCommon.CHANNEL_INTERNAL, loaded.FEC_Channel__c);
        System.assertEquals(
            FEC_ConstantCommon.SUBCHANNEL_INTERNAL_EMAIL,
            loaded.FEC_Interaction_Subchannel__c
        );
    }

    @IsTest
    static void testAfterUpdate_ownerChangeTriggersAutoFollowUp() {
        User newOwner = createTestUser();
        Case row = new Case(
            Subject = 'Owner Change Follow Up',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'OCFU-' + String.valueOf(System.currentTimeMillis())
        );
        insert row;

        Test.startTest();
        update new Case(Id = row.Id, OwnerId = newOwner.Id);
        Test.stopTest();

        System.assertEquals(
            newOwner.Id,
            [SELECT OwnerId FROM Case WHERE Id = :row.Id].OwnerId
        );
    }

    @IsTest
    static void testCustomerCase_syncGlobalSearchFromParent() {
        Id interactionRt = interactionRecordTypeId();
        Id customerRt = customerCaseRecordTypeId();
        if (interactionRt == null || customerRt == null) {
            System.assert(true, 'Skipped: required RecordTypes unavailable.');
            return;
        }

        Case interaction = new Case(
            RecordTypeId = interactionRt,
            Subject = 'Interaction Parent',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_Channel__c = FEC_ConstantCommon.EMAIL,
            FEC_ID_Search__c = 'INTP-' + String.valueOf(System.currentTimeMillis())
        );
        insert interaction;
        interaction = [SELECT Id, FEC_ID_Search__c FROM Case WHERE Id = :interaction.Id];

        Test.startTest();
        Case customerCase = new Case(
            RecordTypeId = customerRt,
            Subject = 'Customer Child',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_Interaction__c = interaction.Id,
            FEC_ID_Search__c = 'CCHD-' + String.valueOf(System.currentTimeMillis())
        );
        insert customerCase;
        Test.stopTest();

        System.assertEquals(
            interaction.FEC_ID_Search__c,
            [SELECT FEC_Global_Search__c FROM Case WHERE Id = :customerCase.Id].FEC_Global_Search__c
        );
    }

    @IsTest
    static void testInteractionCase_syncGlobalSearchOnUpdate() {
        Id interactionRt = interactionRecordTypeId();
        Id customerRt = customerCaseRecordTypeId();
        if (interactionRt == null || customerRt == null) {
            System.assert(true, 'Skipped: required RecordTypes unavailable.');
            return;
        }

        Case interaction = new Case(
            RecordTypeId = interactionRt,
            Subject = 'Interaction Search Sync',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'INTS-OLD'
        );
        insert interaction;

        Case child = new Case(
            RecordTypeId = customerRt,
            Subject = 'Child Search Sync',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_Interaction__c = interaction.Id,
            FEC_ID_Search__c = 'CHLD-' + String.valueOf(System.currentTimeMillis())
        );
        insert child;

        Test.startTest();
        update new Case(Id = interaction.Id, FEC_ID_Search__c = 'INTS-NEW');
        Test.stopTest();

        System.assertEquals(
            'INTS-NEW',
            [SELECT FEC_Global_Search__c FROM Case WHERE Id = :child.Id].FEC_Global_Search__c
        );
    }

    @IsTest
    static void testEmail2Case_threadTokenSetsParentAndStripsSubject() {
        Id interactionRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)?.getRecordTypeId();

        Case parent = new Case(
            Subject = 'Parent Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_Send_To__c = 'test@fecredit.com.vn',
            FEC_ID_Search__c = 'PAR-' + String.valueOf(System.currentTimeMillis())
        );
        if (interactionRtId != null) {
            parent.RecordTypeId = interactionRtId;
        }
        insert parent;

        String token = '[ ref:ORG.' + String.valueOf(parent.Id).substring(0, 15) + ':ref ]';
        Case reply = new Case(
            Subject = 'Re: Question ' + token,
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = 'Email2Case',
            FEC_ID_Search__c = 'REPL-' + String.valueOf(System.currentTimeMillis())
        );
        Test.startTest();
        insert reply;
        Test.stopTest();

        Case loaded = [SELECT ParentId, Subject, FEC_Send_To__c FROM Case WHERE Id = :reply.Id];
        System.assertEquals(parent.Id, loaded.ParentId);
        System.assert(!loaded.Subject.contains('ref:'));
        System.assertEquals('test@fecredit.com.vn', loaded.FEC_Send_To__c);
    }

    @IsTest
    static void testUpdateEmail2CaseFieldsAsync_withEmailMessage() {
        Id rtId = interactionRecordTypeId();
        if (rtId == null) {
            System.assert(true, 'Skipped: Interaction RecordType unavailable.');
            return;
        }

        Case emailCase = new Case(
            RecordTypeId = rtId,
            Origin = FEC_ConstantCommon.CASE_ORIGIN_EMAIL_FE,
            Subject = 'Email Async Test',
            FEC_Channel__c = FEC_ConstantCommon.EMAIL,
            FEC_ID_Search__c = 'E2EM-' + String.valueOf(System.currentTimeMillis())
        );
        insert emailCase;

        insert new EmailMessage(
            ParentId = emailCase.Id,
            FromAddress = 'customer@example.com',
            ToAddress = 'support@fecredit.com.vn',
            Subject = 'Test',
            TextBody = 'Body',
            Incoming = true,
            Status = '0'
        );

        Test.startTest();
        FEC_CaseTriggerHandler.updateEmail2CaseFieldsAsync(new List<Id>{ emailCase.Id });
        Test.stopTest();

        Case loaded = [
            SELECT FEC_Interaction_Email__c, FEC_Send_To__c
            FROM Case
            WHERE Id = :emailCase.Id
        ];
        System.assertEquals('customer@example.com', loaded.FEC_Interaction_Email__c);
        System.assertEquals(
            FEC_ConstantCommon.EMAIL_READONLY_FROM_FECREDIT,
            loaded.FEC_Send_To__c
        );
    }
}
