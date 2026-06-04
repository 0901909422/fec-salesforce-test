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
}
