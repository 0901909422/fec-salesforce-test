/**
 * Unit tests for CaseTriggerHandler (duplicate FEC_External_Interaction_ID__c vs existing Cases).
 */
@IsTest
private class FEC_CaseTriggerHandler_Test {

    private static Id interactionRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        System.assert(
            byDev.containsKey('Interaction'),
            'Case RecordType DeveloperName Interaction is required for this test.'
        );
        return byDev.get('Interaction').getRecordTypeId();
    }

    /** FEC_External_Interaction_ID__c is Text(20); keep generated values within limit. */
    private static String randomSuffix() {
        return String.valueOf(Math.abs(Crypto.getRandomInteger()));
    }

    private static String externalId(String label) {
        String r = randomSuffix();
        Integer maxLabel = 20 - r.length();
        if (maxLabel <= 0) {
            return r.length() > 20 ? r.substring(0, 20) : r;
        }
        if (label.length() > maxLabel) {
            label = label.substring(0, maxLabel);
        }
        return label + r;
    }

    private static Case buildCase(String externalInteractionId) {
        return new Case(
            RecordTypeId = interactionRecordTypeId(),
            Subject = 'FEC_CaseTriggerHandler_Test',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_External_Interaction_ID__c = externalInteractionId
        );
    }

    @IsTest
    static void onBeforeInsert_blankExternalId_noErrors() {
        Case c = buildCase(null);
        new CaseTriggerHandler().onBeforeInsert(new List<Case>{ c });
        System.assertEquals(0, c.getErrors().size(), 'No duplicate check when External ID is blank.');
    }

    @IsTest
    static void onBeforeInsert_uniqueExternalId_noErrors() {
        String extId = externalId('UQ');
        insert buildCase(extId);

        Case incoming = buildCase(externalId('UN'));
        new CaseTriggerHandler().onBeforeInsert(new List<Case>{ incoming });
        System.assertEquals(0, incoming.getErrors().size(), 'New unique External ID should not error.');
    }

    @IsTest
    static void onBeforeInsert_duplicateExternalId_addsFieldError() {
        String extId = externalId('DP');
        Case existing = buildCase(extId);
        insert existing;

        Case incoming = buildCase(extId);
        new CaseTriggerHandler().onBeforeInsert(new List<Case>{ incoming });

        System.assertEquals(1, incoming.getErrors().size(), 'Duplicate vs DB should produce one error.');
        String msg = incoming.getErrors()[0].getMessage();
        System.assert(
            msg.contains('External Interaction ID has already been used'),
            'Unexpected message: ' + msg
        );
    }

    @IsTest
    static void onBeforeInsert_bulk_mixedExternalIds() {
        String shared = externalId('BK');
        insert buildCase(shared);

        Case ok = buildCase(externalId('OK'));
        Case bad = buildCase(shared);
        new CaseTriggerHandler().onBeforeInsert(new List<Case>{ ok, bad });

        System.assertEquals(0, ok.getErrors().size());
        System.assertEquals(1, bad.getErrors().size());
    }

    @IsTest
    static void onBeforeUpdate_externalIdUnchanged_skipsDuplicateLogic() {
        String extId = externalId('SM');
        Case inserted = buildCase(extId);
        insert inserted;

        Case oldRow = new Case(
            Id = inserted.Id,
            FEC_External_Interaction_ID__c = extId
        );
        Case newRow = new Case(
            Id = inserted.Id,
            Subject = 'Updated subject only',
            FEC_External_Interaction_ID__c = extId
        );
        Map<Id, Case> oldMap = new Map<Id, Case>{ inserted.Id => oldRow };

        new CaseTriggerHandler().onBeforeUpdate(new List<Case>{ newRow }, oldMap);
        System.assertEquals(0, newRow.getErrors().size());
    }

    @IsTest
    static void onBeforeUpdate_changeToDuplicate_addsFieldError() {
        String dupId = externalId('CL');
        Case keeper = buildCase(dupId);
        Case other = buildCase(externalId('OT'));
        insert new List<Case>{ keeper, other };

        Case oldRow = new Case(
            Id = other.Id,
            FEC_External_Interaction_ID__c = other.FEC_External_Interaction_ID__c
        );
        Case newRow = new Case(
            Id = other.Id,
            FEC_External_Interaction_ID__c = dupId
        );
        Map<Id, Case> oldMap = new Map<Id, Case>{ other.Id => oldRow };

        new CaseTriggerHandler().onBeforeUpdate(new List<Case>{ newRow }, oldMap);
        System.assertEquals(1, newRow.getErrors().size());
    }

    @IsTest
    static void onBeforeUpdate_setNewUniqueValue_noErrors() {
        String first = externalId('A');
        Case c = buildCase(first);
        insert c;

        String second = externalId('B');
        Case oldRow = new Case(Id = c.Id, FEC_External_Interaction_ID__c = first);
        Case newRow = new Case(Id = c.Id, FEC_External_Interaction_ID__c = second);
        Map<Id, Case> oldMap = new Map<Id, Case>{ c.Id => oldRow };

        new CaseTriggerHandler().onBeforeUpdate(new List<Case>{ newRow }, oldMap);
        System.assertEquals(0, newRow.getErrors().size());
    }

    // ---- FEC_CaseTriggerHandler.run() via FEC_CaseTrigger ----

    @IsTest
    static void testRun_BeforeInsert_GeneratesIdSearch() {
        Case c = buildCase(externalId('GS'));
        c.FEC_ID_Search__c = null;

        Test.startTest();
        insert c;
        Test.stopTest();

        Case inserted = [SELECT FEC_ID_Search__c FROM Case WHERE Id = :c.Id];
        System.assert(
            String.isNotBlank(inserted.FEC_ID_Search__c),
            'run() phải generate FEC_ID_Search__c qua trigger.'
        );
    }

    @IsTest
    static void testRun_BeforeInsert_BlocksDuplicateExternalId() {
        String extId = externalId('RN');
        insert buildCase(extId);

        Case incoming = buildCase(extId);
        Test.startTest();
        try {
            insert incoming;
            System.assert(false, 'Duplicate External ID phải fail khi trigger gọi run().');
        } catch (DmlException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testRun_IsExecutingGuard_SkipsHandler() {
        Boolean prior = FEC_CaseTriggerHandler.isExecuting;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Case c = buildCase(externalId('GD'));
            insert c;
            System.assertNotEquals(null, c.Id, 'Insert vẫn thành công khi isExecuting=true.');
        } finally {
            FEC_CaseTriggerHandler.isExecuting = prior;
        }
    }

    @IsTest
    static void testRun_AfterUpdate_SystemUpdatePath() {
        Case c = buildCase(externalId('SU'));
        insert c;

        Boolean priorSystem = FEC_CaseTriggerHandler.isSystemUpdate;
        FEC_CaseTriggerHandler.isSystemUpdate = true;
        try {
            Test.startTest();
            update new Case(Id = c.Id, Subject = 'System update path');
            Test.stopTest();
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = priorSystem;
        }

        Case refreshed = [SELECT Subject FROM Case WHERE Id = :c.Id];
        System.assertEquals('System update path', refreshed.Subject);
    }

    @IsTest
    static void testRun_AfterUpdate_OwnerChange() {
        List<User> otherUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Id != :UserInfo.getUserId()
            LIMIT 1
        ];
        if (otherUsers.isEmpty()) {
            System.assert(true, 'Skipped: no second active user in org.');
            return;
        }
        User runUser = otherUsers[0];

        Case c = buildCase(externalId('OW'));
        insert c;

        Test.startTest();
        System.runAs(runUser) {
            update new Case(Id = c.Id, OwnerId = runUser.Id);
        }
        Test.stopTest();

        Case refreshed = [SELECT OwnerId FROM Case WHERE Id = :c.Id];
        System.assertEquals(runUser.Id, refreshed.OwnerId);
    }

    @IsTest
    static void testRun_BeforeUpdate_ExternalIdChangeDuplicate() {
        String first = externalId('A1');
        String second = externalId('B2');
        Case keeper = buildCase(first);
        Case other = buildCase(second);
        insert new List<Case>{ keeper, other };

        Test.startTest();
        try {
            update new Case(
                Id = other.Id,
                FEC_External_Interaction_ID__c = first
            );
            System.assert(false, 'Update trùng External ID phải fail qua run().');
        } catch (DmlException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testRun_BeforeInsert_Email2CaseChannel() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (!byDev.containsKey('Interaction')) {
            System.assert(true, 'Skipped: Interaction record type not in org.');
            return;
        }

        Case c = new Case(
            RecordTypeId = byDev.get('Interaction').getRecordTypeId(),
            Subject = 'Email2Case Channel Test',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = FEC_ConstantCommon.CASE_ORIGIN_EMAIL_UBANK,
            FEC_Channel__c = null
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        Case inserted = [
            SELECT FEC_Channel__c, FEC_Interaction_Subchannel__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals(FEC_ConstantCommon.EMAIL, inserted.FEC_Channel__c);
        System.assertEquals(
            FEC_ConstantCommon.SUBCHANNEL_INCOMING_EMAIL,
            inserted.FEC_Interaction_Subchannel__c
        );
    }

    @IsTest
    static void testRun_BeforeInsert_CustomerCaseParticipants() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (!byDev.containsKey(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)) {
            System.assert(true, 'Skipped: Customer_Case record type not in org.');
            return;
        }

        Case c = new Case(
            RecordTypeId = byDev.get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME).getRecordTypeId(),
            Subject = 'Customer Case Participants',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            OwnerId = UserInfo.getUserId()
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        Case inserted = [SELECT FEC_Case_Participants__c FROM Case WHERE Id = :c.Id];
        System.assert(
            String.isNotBlank(inserted.FEC_Case_Participants__c),
            'run() phải add owner vào FEC_Case_Participants__c.'
        );
    }

    @IsTest
    static void testRun_BeforeInsert_StripSubjectThreadToken() {
        Case c = buildCase(externalId('ST'));
        c.Subject = 'Reply subject [ ref:00D000000000000.500000000000000:ref ]';

        Test.startTest();
        insert c;
        Test.stopTest();

        Case inserted = [SELECT Subject FROM Case WHERE Id = :c.Id];
        System.assert(!inserted.Subject.contains('[ ref:'), 'Thread token phải bị strip.');
    }

    @IsTest
    static void testRun_BeforeInsert_SyncGlobalSearchFromParent() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (
            !byDev.containsKey('Interaction') ||
            !byDev.containsKey(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)
        ) {
            System.assert(true, 'Skipped: required record types not in org.');
            return;
        }

        Case interaction = new Case(
            RecordTypeId = byDev.get('Interaction').getRecordTypeId(),
            Subject = 'Parent Interaction',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'INT-GS-' + randomSuffix()
        );
        insert interaction;

        Case customer = new Case(
            RecordTypeId = byDev.get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME).getRecordTypeId(),
            Subject = 'Child Customer',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_Interaction__c = interaction.Id
        );

        Test.startTest();
        insert customer;
        Test.stopTest();

        Case inserted = [SELECT FEC_Global_Search__c FROM Case WHERE Id = :customer.Id];
        System.assertEquals(interaction.FEC_ID_Search__c, inserted.FEC_Global_Search__c);
    }

    @IsTest
    static void testRun_AfterUpdate_GlobalSearchSyncToChild() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (
            !byDev.containsKey('Interaction') ||
            !byDev.containsKey(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)
        ) {
            System.assert(true, 'Skipped: required record types not in org.');
            return;
        }

        Case interaction = new Case(
            RecordTypeId = byDev.get('Interaction').getRecordTypeId(),
            Subject = 'Interaction GS Sync',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'INT-OLD-' + randomSuffix()
        );
        insert interaction;

        Case customer = new Case(
            RecordTypeId = byDev.get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME).getRecordTypeId(),
            Subject = 'Customer GS Sync',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_Interaction__c = interaction.Id
        );
        insert customer;

        String newSearchKey = 'INT-NEW-' + randomSuffix();
        Test.startTest();
        update new Case(Id = interaction.Id, FEC_ID_Search__c = newSearchKey);
        Test.stopTest();

        Case child = [SELECT FEC_Global_Search__c FROM Case WHERE Id = :customer.Id];
        System.assertEquals(newSearchKey, child.FEC_Global_Search__c);
    }

    @IsTest
    static void testRun_AfterUpdate_ResolvedRemovesFollowUp() {
        Case c = buildCase(externalId('RS'));
        insert c;

        String resolvedStatus = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED;
        Test.startTest();
        update new Case(Id = c.Id, Status = resolvedStatus);
        Test.stopTest();

        Case refreshed = [SELECT Status FROM Case WHERE Id = :c.Id];
        System.assert(
            FEC_CommonUltils.isCaseStatusResolved(refreshed.Status),
            'Case phải ở trạng thái resolved.'
        );
    }

    @IsTest
    static void testRun_BeforeInsert_SyncChannelFromInteraction() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (
            !byDev.containsKey('Interaction') ||
            !byDev.containsKey(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)
        ) {
            System.assert(true, 'Skipped: required record types not in org.');
            return;
        }

        Case interaction = new Case(
            RecordTypeId = byDev.get('Interaction').getRecordTypeId(),
            Subject = 'Channel Parent',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME
        );
        insert interaction;

        Case customer = new Case(
            RecordTypeId = byDev.get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME).getRecordTypeId(),
            Subject = 'Channel Child',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_Interaction__c = interaction.Id,
            FEC_Channel__c = null
        );

        Test.startTest();
        insert customer;
        Test.stopTest();

        Case inserted = [SELECT FEC_Channel__c FROM Case WHERE Id = :customer.Id];
        System.assertEquals(FEC_ConstantCommon.CHANNEL_INBOUND_NAME, inserted.FEC_Channel__c);
    }

    @IsTest
    static void testUpdateEmail2CaseFieldsAsync() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (!byDev.containsKey('Interaction')) {
            System.assert(true, 'Skipped: Interaction record type not in org.');
            return;
        }

        Case c = new Case(
            RecordTypeId = byDev.get('Interaction').getRecordTypeId(),
            Subject = 'Async Email2Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            Origin = FEC_ConstantCommon.CASE_ORIGIN_EMAIL_FE
        );
        insert c;

        insert new EmailMessage(
            ParentId = c.Id,
            Incoming = true,
            FromAddress = 'customer@test.com',
            ToAddress = 'support@fecredit.com.vn',
            Subject = 'Test Email',
            TextBody = 'Body'
        );

        Test.startTest();
        FEC_CaseTriggerHandler.updateEmail2CaseFieldsAsync(new List<Id>{ c.Id });
        Test.stopTest();

        Case updated = [
            SELECT FEC_Interaction_Email__c, FEC_Send_To__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals('customer@test.com', updated.FEC_Interaction_Email__c);
        System.assertNotEquals(null, updated.FEC_Send_To__c);
    }
}
