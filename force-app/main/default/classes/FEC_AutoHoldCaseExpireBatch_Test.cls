/**
 * Unit tests for FEC_AutoHoldCaseExpireBatch (expire active auto holds past FEC_End_Time__c).
 */
@IsTest
private class FEC_AutoHoldCaseExpireBatch_Test {

    private static Case insertCaseRow(String subject, String status) {
        Case c = new Case(Subject = subject, Status = status);
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    private static FEC_Case_Hold_History__c buildHoldHistory(
        Id caseId,
        String releaseStatus,
        DateTime endTime
    ) {
        return new FEC_Case_Hold_History__c(
            FEC_Case__c = caseId,
            FEC_Start_Time__c = endTime.addHours(-1),
            FEC_End_Time__c = endTime,
            FEC_Status__c = FEC_AutoHoldCaseHistoryService.STATUS_ACTIVE,
            FEC_Type__c = FEC_AutoHoldCaseHistoryService.TYPE_AUTO,
            FEC_Release_Case_Status__c = releaseStatus
        );
    }

    @TestSetup
    static void setupData() {
        DateTime expiredAt = DateTime.now().addMinutes(-5);

        Case holdCase = insertCaseRow('Auto Hold Expire - Hold', 'Pending');
        Case restoreCase = insertCaseRow('Auto Hold Expire - Restore', 'Pending');

        insert new List<FEC_Case_Hold_History__c>{
            buildHoldHistory(holdCase.Id, 'Open', expiredAt),
            buildHoldHistory(restoreCase.Id, '  New  ', expiredAt),
            buildHoldHistory(
                insertCaseRow('Auto Hold Expire - Invalid Release', 'Pending').Id,
                null,
                expiredAt
            ),
            buildHoldHistory(
                insertCaseRow('Auto Hold Expire - Future', 'Pending').Id,
                'Open',
                DateTime.now().addDays(1)
            )
        };
    }

    @IsTest
    static void executeBatch_expiresEligibleHolds() {
        Case holdCase = [
            SELECT Id, Status
            FROM Case
            WHERE Subject = 'Auto Hold Expire - Hold'
            LIMIT 1
        ];
        Case restoreCase = [
            SELECT Id, Status
            FROM Case
            WHERE Subject = 'Auto Hold Expire - Restore'
            LIMIT 1
        ];
        Id futureHistoryId = [
            SELECT Id
            FROM FEC_Case_Hold_History__c
            WHERE FEC_Case__r.Subject = 'Auto Hold Expire - Future'
            LIMIT 1
        ]
        .Id;
        Id invalidReleaseHistoryId = [
            SELECT Id
            FROM FEC_Case_Hold_History__c
            WHERE FEC_Case__r.Subject = 'Auto Hold Expire - Invalid Release'
            LIMIT 1
        ]
        .Id;

        Test.startTest();
        Database.executeBatch(new FEC_AutoHoldCaseExpireBatch(), 50);
        Test.stopTest();

        holdCase = [SELECT Status FROM Case WHERE Id = :holdCase.Id];
        restoreCase = [SELECT Status FROM Case WHERE Id = :restoreCase.Id];
        System.assertEquals('Open', holdCase.Status, 'Expired hold should restore Case.Status from snapshot.');
        System.assertEquals('New', restoreCase.Status, 'Release status should be trimmed before Case update.');

        Map<String, FEC_Case_Hold_History__c> historiesBySubject = new Map<String, FEC_Case_Hold_History__c>();
        for (FEC_Case_Hold_History__c h : [
            SELECT Id, FEC_Status__c, FEC_Case__r.Subject
            FROM FEC_Case_Hold_History__c
            WHERE FEC_Case__r.Subject LIKE 'Auto Hold Expire%'
        ]) {
            historiesBySubject.put(h.FEC_Case__r.Subject, h);
        }

        System.assertEquals(
            FEC_AutoHoldCaseHistoryService.STATUS_COMPLETED,
            historiesBySubject.get('Auto Hold Expire - Hold').FEC_Status__c
        );
        System.assertEquals(
            FEC_AutoHoldCaseHistoryService.STATUS_COMPLETED,
            historiesBySubject.get('Auto Hold Expire - Restore').FEC_Status__c
        );
        System.assertEquals(
            FEC_AutoHoldCaseHistoryService.STATUS_COMPLETED,
            historiesBySubject.get('Auto Hold Expire - Invalid Release').FEC_Status__c,
            'Blank release status should still complete the history row.'
        );
        System.assertEquals(
            FEC_AutoHoldCaseHistoryService.STATUS_ACTIVE,
            historiesBySubject.get('Auto Hold Expire - Future').FEC_Status__c,
            'Future end time must not be picked up by start().'
        );
        System.assertEquals(futureHistoryId, historiesBySubject.get('Auto Hold Expire - Future').Id);
    }

    @IsTest
    static void execute_directScope_coversStartAndFinish() {
        Case c = insertCaseRow('Auto Hold Expire - Direct Execute', 'Pending');
        FEC_Case_Hold_History__c row = buildHoldHistory(
            c.Id,
            'Open',
            DateTime.now().addMinutes(-1)
        );
        insert row;

        FEC_AutoHoldCaseExpireBatch batch = new FEC_AutoHoldCaseExpireBatch();
        Database.QueryLocator locator = batch.start(null);
        System.assertNotEquals(null, locator, 'start() must return a query locator.');

        List<FEC_Case_Hold_History__c> scope = [
            SELECT Id, FEC_Case__c, FEC_Release_Case_Status__c
            FROM FEC_Case_Hold_History__c
            WHERE Id = :row.Id
        ];
        Test.startTest();
        batch.execute(null, scope);
        batch.finish(null);
        Test.stopTest();

        System.assertEquals(
            FEC_AutoHoldCaseHistoryService.STATUS_COMPLETED,
            [SELECT FEC_Status__c FROM FEC_Case_Hold_History__c WHERE Id = :row.Id].FEC_Status__c
        );
        System.assertEquals(
            'Open',
            [SELECT Status FROM Case WHERE Id = :c.Id].Status
        );
    }

    @IsTest
    static void execute_emptyScope_noUpdates() {
        FEC_AutoHoldCaseExpireBatch batch = new FEC_AutoHoldCaseExpireBatch();
        Test.startTest();
        batch.execute(null, new List<FEC_Case_Hold_History__c>());
        batch.finish(null);
        Test.stopTest();
        System.assert(true, 'Empty scope should complete without error.');
    }
}
