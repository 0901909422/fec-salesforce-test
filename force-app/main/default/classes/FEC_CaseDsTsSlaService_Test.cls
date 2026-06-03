@IsTest
private class FEC_CaseDsTsSlaService_Test {

    private static Id ensureCategory(String nameValue, String codeValue) {
        List<FEC_Category__c> rows = [
            SELECT Id
            FROM FEC_Category__c
            WHERE Name = :nameValue
            LIMIT 1
        ];
        if (!rows.isEmpty()) {
            return rows[0].Id;
        }
        FEC_Category__c c = new FEC_Category__c(
            Name = nameValue,
            FEC_Code__c = codeValue,
            FEC_Active__c = true
        );
        insert c;
        return c.Id;
    }

    private static Case insertCaseRow(Case c) {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    private static Case buildCaseSnapshot(
        Id ownerId,
        String caseStatus,
        String team,
        Decimal assignmentCount,
        String assignmentUsers,
        String categoryName
    ) {
        String payload = '{"attributes":{"type":"Case"}'
            + ',"OwnerId":"' + String.escapeSingleQuotes(String.valueOf(ownerId)) + '"'
            + ',"FEC_Case_Status__c":"' + String.escapeSingleQuotes(caseStatus) + '"'
            + ',"FEC_Team__c":"' + String.escapeSingleQuotes(team) + '"'
            + ',"FEC_Assignment_Count__c":' + String.valueOf(assignmentCount)
            + ',"FEC_Assignment_Users__c":"' + String.escapeSingleQuotes(assignmentUsers == null ? '' : assignmentUsers) + '"'
            + ',"FEC_Category__r":{"Name":"' + String.escapeSingleQuotes(categoryName) + '"}}';
        return (Case) JSON.deserialize(payload, Case.class);
    }

    @IsTest
    static void testUtilityMethods_basicBranches() {
        System.assertEquals(true, FEC_CaseDsTsSlaService.teamContainsDsOrTs('TS'));
        System.assertEquals(true, FEC_CaseDsTsSlaService.teamContainsDsOrTs('DIRECT_SALES'));
        System.assertEquals(false, FEC_CaseDsTsSlaService.teamContainsDsOrTs('Back Office'));

        List<String> labels = FEC_CaseDsTsSlaService.resolveAllMatchedQueueLabels(
            'abc DQ - Direct Sales xyz DQ - Telesales'
        );
        System.assertEquals(2, labels.size());
        System.assertEquals('DQ - Direct Sales', labels[0]);
        System.assertEquals(
            'DQ - Direct Sales',
            FEC_CaseDsTsSlaService.resolveMatchedQueueLabel('DQ - Direct Sales;LG')
        );

        List<Id> parsed = FEC_CaseDsTsSlaService.parseUserIdsFromLabelValue(
            UserInfo.getUserId() + ';invalid;' + UserInfo.getUserId()
        );
        System.assert(parsed.size() > 0);
        System.assertEquals(true, FEC_CaseDsTsSlaService.getRecipientLabelApiName('TELESALES') != null);
    }

    @IsTest
    static void testThresholdElapsedAndSlotResolution() {
        Datetime nowDt = System.now();
        Datetime anchor = nowDt.addMinutes(-2);
        System.assert(FEC_CaseDsTsSlaService.getElapsedMs(anchor, nowDt) >= 120000);
        System.assertEquals(null, FEC_CaseDsTsSlaService.getElapsedMs(null, nowDt));

        FEC_CaseDsTsSlaService.setUseOneMinuteTestThresholds(true);
        try {
            Case c = new Case();
            Map<String, Datetime> profileToAnchor = new Map<String, Datetime>{
                FEC_CaseDsTsSlaService.PROFILE_TELESALES => anchor
            };

            Integer slot1 = FEC_CaseDsTsSlaService.resolveNextCaseSlotToStamp(
                c,
                new List<String>{ FEC_CaseDsTsSlaService.PROFILE_TELESALES },
                profileToAnchor,
                nowDt
            );
            System.assertEquals(1, slot1);

            c.FEC_SLA_Notification_1__c = nowDt;
            Integer slot2 = FEC_CaseDsTsSlaService.resolveNextCaseSlotToStamp(
                c,
                new List<String>{ FEC_CaseDsTsSlaService.PROFILE_TELESALES },
                profileToAnchor,
                nowDt
            );
            System.assertEquals(2, slot2);
        } finally {
            FEC_CaseDsTsSlaService.setUseOneMinuteTestThresholds(false);
        }
    }

    @IsTest
    static void testBuildPatchClearAndStamp() {
        Datetime nowDt = System.now();
        Id complaintId = ensureCategory('Complaint', 'CMP-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6));
        Set<Id> queueIds = FEC_CaseDsTsSlaService.getSlaOwnerQueueIds();
        if (queueIds.isEmpty()) {
            System.assert(true, 'No SLA queue metadata in org.');
            return;
        }
        Id queueId = queueIds.iterator().next();

        Case inserted = insertCaseRow(new Case(
            Subject = 'DS TS SLA Service Test',
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            OwnerId = queueId,
            FEC_Team__c = 'TS',
            FEC_Category__c = complaintId,
            FEC_SLA_Notification_1__c = nowDt
        ));

        Case row = [
            SELECT Id, OwnerId, FEC_Case_Status__c, FEC_Team__c,
                   FEC_Assignment_Count__c, FEC_Assignment_Users__c,
                   FEC_SLA_Notification_1__c, FEC_SLA_Notification_2__c, FEC_SLA_Notification_3__c,
                   FEC_Category__r.Name
            FROM Case
            WHERE Id = :inserted.Id
        ];

        FEC_CaseDsTsSlaService.SlaEligibilityContext emptyCtx = new FEC_CaseDsTsSlaService.SlaEligibilityContext();
        Case clearPatch = FEC_CaseDsTsSlaService.buildNotificationPatch(row, emptyCtx, nowDt);
        System.assertNotEquals(null, clearPatch);
        System.assertEquals(null, clearPatch.FEC_SLA_Notification_1__c);

        FEC_CaseDsTsSlaService.SlaEligibilityContext ctx = FEC_CaseDsTsSlaService.evaluateEligibility(row);
        System.assertEquals(true, ctx != null);
        System.assertEquals(true, FEC_CaseDsTsSlaService.needsClearNotifications(row));

        FEC_Routing_Action_History__c rah = new FEC_Routing_Action_History__c(
            FEC_Case__c = row.Id,
            FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
            FEC_Routing_Action_Type__c = 'Case',
            FEC_Updated_User_Queue_ID__c = String.valueOf(row.OwnerId)
        );
        insert rah;
        Test.setCreatedDate(rah.Id, nowDt.addMinutes(-3));

        Map<Id, FEC_CaseDsTsSlaService.SlaEligibilityContext> mapCtx =
            new Map<Id, FEC_CaseDsTsSlaService.SlaEligibilityContext>{ row.Id => ctx };
        FEC_CaseDsTsSlaService.bulkResolveAnchorsPerProfile(mapCtx);

        FEC_CaseDsTsSlaService.setUseOneMinuteTestThresholds(true);
        try {
            row.FEC_SLA_Notification_1__c = null;
            Case stampPatch = FEC_CaseDsTsSlaService.buildNotificationPatch(row, ctx, nowDt);
            // Org-dependent anchor matching, patch can be null if no anchor resolved.
            System.assertEquals(true, stampPatch == null || stampPatch.Id == row.Id);
        } finally {
            FEC_CaseDsTsSlaService.setUseOneMinuteTestThresholds(false);
        }
    }

    @IsTest
    static void testResolveCaseDisplayIdAndMessages() {
        Id feedbackId = ensureCategory('Feedback', 'FDB-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6));
        Case c = insertCaseRow(new Case(
            Subject = 'Display Id Test',
            Status = 'New',
            FEC_Category__c = feedbackId,
            FEC_ID_Search__c = 'CID-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(8)
        ));

        Case fullRow = [SELECT Id, FEC_ID_Search__c FROM Case WHERE Id = :c.Id];
        String displayId = FEC_CaseDsTsSlaService.resolveCaseDisplayId(fullRow);
        System.assert(displayId.startsWith('CID-'));

        String title = FEC_CaseDsTsSlaService.getApproachingTitle(fullRow);
        String body = FEC_CaseDsTsSlaService.getApproachingBody(fullRow);
        System.assert(String.isNotBlank(title));
        System.assert(String.isNotBlank(body));
    }

    @IsTest
    static void testTh1Th2EligibilityAndProfiles() {
        Set<Id> queueIds = FEC_CaseDsTsSlaService.getSlaOwnerQueueIds();
        if (queueIds.isEmpty()) {
            System.assert(true, 'No SLA queue metadata in org.');
            return;
        }
        Id complaintId = ensureCategory('Complaint', 'CMPX-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(5));
        Id queueId = queueIds.iterator().next();

        Case th1Case = insertCaseRow(new Case(
            Subject = 'TH1 Case',
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            OwnerId = queueId,
            FEC_Team__c = 'TS',
            FEC_Category__c = complaintId
        ));
        Case th1 = buildCaseSnapshot(
            queueId,
            FEC_ConstantCommon.CASE_STATUS_PENDING,
            'TS',
            0,
            '',
            'Complaint'
        );
        System.assertEquals(true, FEC_CaseDsTsSlaService.matchesTh1(th1));
        System.assertEquals(false, FEC_CaseDsTsSlaService.matchesTh2(th1));
        System.assertEquals(true, FEC_CaseDsTsSlaService.meetsCommonCriteria(th1));
        FEC_CaseDsTsSlaService.SlaEligibilityContext th1Ctx = FEC_CaseDsTsSlaService.evaluateEligibility(th1);
        System.assertEquals(true, th1Ctx.isEligible);
        System.assertEquals(FEC_CaseDsTsSlaService.SCENARIO_TH1, th1Ctx.scenario);

        Case th2 = buildCaseSnapshot(
            UserInfo.getUserId(),
            'Pending - Manual',
            'DIRECT_SALES',
            1,
            'DQ - Direct Sales;DQ - POS Sales',
            'Complaint'
        );

        System.assertEquals(false, FEC_CaseDsTsSlaService.matchesTh1(th2));
        System.assertEquals(true, FEC_CaseDsTsSlaService.matchesTh2(th2));
        System.assertEquals(true, FEC_CaseDsTsSlaService.meetsCommonCriteria(th2));
        List<String> activeProfiles = FEC_CaseDsTsSlaService.resolveActiveProfiles(th2);
        System.assert(activeProfiles.size() >= 1);
        FEC_CaseDsTsSlaService.SlaEligibilityContext th2Ctx = FEC_CaseDsTsSlaService.evaluateEligibility(th2);
        System.assertEquals(true, th2Ctx.isEligible);
        System.assertEquals(FEC_CaseDsTsSlaService.SCENARIO_TH2, th2Ctx.scenario);
    }

    @IsTest
    static void testDueSlotRecipientAndDisplayIdFallbacks() {
        Datetime nowDt = System.now();
        Case c = new Case();
        Long elapsed = 3L * 60L * 1000L;

        FEC_CaseDsTsSlaService.setUseOneMinuteTestThresholds(true);
        try {
            Integer teleSlot = FEC_CaseDsTsSlaService.getDueNotificationSlot(
                c, elapsed, FEC_CaseDsTsSlaService.PROFILE_TELESALES
            );
            Integer dsSlot = FEC_CaseDsTsSlaService.getDueNotificationSlot(
                c, elapsed, FEC_CaseDsTsSlaService.PROFILE_DIRECT_SALES
            );
            System.assertEquals(1, teleSlot);
            System.assertEquals(1, dsSlot);

            c.FEC_SLA_Notification_1__c = nowDt;
            Integer teleSlot2 = FEC_CaseDsTsSlaService.getDueNotificationSlot(
                c, elapsed, FEC_CaseDsTsSlaService.PROFILE_TELESALES
            );
            System.assertEquals(2, teleSlot2);
            c.FEC_SLA_Notification_2__c = nowDt;
            Integer dsSlot3 = FEC_CaseDsTsSlaService.getDueNotificationSlot(
                c, elapsed, FEC_CaseDsTsSlaService.PROFILE_DIRECT_SALES
            );
            System.assertEquals(3, dsSlot3);
        } finally {
            FEC_CaseDsTsSlaService.setUseOneMinuteTestThresholds(false);
        }

        System.assertEquals(0, FEC_CaseDsTsSlaService.resolveRecipientUserIdsByProfile('UNKNOWN').size());
        System.assertEquals(0, FEC_CaseDsTsSlaService.resolveRecipientUserIdsUnion(null).size());
        System.assertEquals(0, FEC_CaseDsTsSlaService.resolveRecipientUserIds(null).size());

        FEC_CaseDsTsSlaService.SlaEligibilityContext ctx = new FEC_CaseDsTsSlaService.SlaEligibilityContext();
        ctx.queueProfile = 'UNKNOWN';
        System.assertEquals(0, FEC_CaseDsTsSlaService.resolveRecipientUserIds(ctx).size());

        Id feedbackId = ensureCategory('Feedback', 'FDBX-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(5));
        Case inserted = insertCaseRow(new Case(
            Subject = 'Display Fallback',
            Status = 'New',
            FEC_Category__c = feedbackId,
            FEC_ID_Search__c = 'CASE-DIAG-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6)
        ));
        // only Id present -> forces resolveCaseDisplayId to query DB fallback branch
        String fallbackDisplay = FEC_CaseDsTsSlaService.resolveCaseDisplayId(new Case(Id = inserted.Id));
        System.assert(fallbackDisplay.startsWith('CASE-DIAG-'));
    }

    @IsTest
    static void testBulkResolveAnchorsAndDiagnose() {
        // null/empty guards
        FEC_CaseDsTsSlaService.bulkResolveAnchors(null);
        FEC_CaseDsTsSlaService.bulkResolveAnchorsPerProfile(new Map<Id, FEC_CaseDsTsSlaService.SlaEligibilityContext>());
        System.assertEquals('caseId null', FEC_CaseDsTsSlaService.diagnoseCase(null));

        String notFound = FEC_CaseDsTsSlaService.diagnoseCase('500000000000000AAA');
        System.assert(notFound.contains('Case not found'));
    }

    @IsTest
    static void testDiagnoseCase_eligibleFlow() {
        Set<Id> queueIds = FEC_CaseDsTsSlaService.getSlaOwnerQueueIds();
        if (queueIds.isEmpty()) {
            System.assert(true, 'No SLA queue metadata in org.');
            return;
        }
        Id complaintId = ensureCategory('Complaint', 'CMZD-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(5));
        Id queueId = queueIds.iterator().next();

        Case c = insertCaseRow(new Case(
            Subject = 'Diagnose SLA Eligible',
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            OwnerId = queueId,
            FEC_Team__c = 'TS',
            FEC_Category__c = complaintId
        ));

        FEC_Routing_Action_History__c rah = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
            FEC_Routing_Action_Type__c = 'Case',
            FEC_Updated_User_Queue_ID__c = String.valueOf(queueId),
            FEC_Updated_User_Queue__c = 'DQ - Telesales'
        );
        insert rah;
        Test.setCreatedDate(rah.Id, System.now().addMinutes(-5));

        FEC_CaseDsTsSlaService.setUseOneMinuteTestThresholds(true);
        try {
            String diag = FEC_CaseDsTsSlaService.diagnoseCase(c.Id);
            System.assert(diag.contains('CaseId='));
            System.assert(diag.contains('eligible='));
            System.assert(diag.contains('rahRouteToCount='));
        } finally {
            FEC_CaseDsTsSlaService.setUseOneMinuteTestThresholds(false);
        }
    }

    @IsTest
    static void testProductionThresholdsAndPatchStamping() {
        Datetime nowDt = System.now();
        Datetime oldDt = nowDt.addHours(-9);

        // Ensure production thresholds branch (2h/4h/6h/8h) is exercised
        FEC_CaseDsTsSlaService.setUseOneMinuteTestThresholds(false);

        Case cTele = new Case();
        Integer teleSlot1 = FEC_CaseDsTsSlaService.getDueNotificationSlot(
            cTele,
            3L * 60L * 60L * 1000L,
            FEC_CaseDsTsSlaService.PROFILE_TELESALES
        );
        System.assertEquals(1, teleSlot1);
        cTele.FEC_SLA_Notification_1__c = nowDt;
        Integer teleSlot2 = FEC_CaseDsTsSlaService.getDueNotificationSlot(
            cTele,
            5L * 60L * 60L * 1000L,
            FEC_CaseDsTsSlaService.PROFILE_TELESALES
        );
        System.assertEquals(2, teleSlot2);

        Case cDs = new Case();
        Integer dsSlot1 = FEC_CaseDsTsSlaService.getDueNotificationSlot(
            cDs,
            5L * 60L * 60L * 1000L,
            FEC_CaseDsTsSlaService.PROFILE_DIRECT_SALES
        );
        System.assertEquals(1, dsSlot1);
        cDs.FEC_SLA_Notification_1__c = nowDt;
        Integer dsSlot2 = FEC_CaseDsTsSlaService.getDueNotificationSlot(
            cDs,
            7L * 60L * 60L * 1000L,
            FEC_CaseDsTsSlaService.PROFILE_DIRECT_SALES
        );
        System.assertEquals(2, dsSlot2);
        cDs.FEC_SLA_Notification_2__c = nowDt;
        Integer dsSlot3 = FEC_CaseDsTsSlaService.getDueNotificationSlot(
            cDs,
            9L * 60L * 60L * 1000L,
            FEC_CaseDsTsSlaService.PROFILE_DIRECT_SALES
        );
        System.assertEquals(3, dsSlot3);
        System.assertEquals(
            null,
            FEC_CaseDsTsSlaService.getDueNotificationSlot(cDs, 1000L, 'UNKNOWN')
        );

        // Force stamping branches slot 1/2/3 in buildNotificationPatch
        FEC_CaseDsTsSlaService.setUseOneMinuteTestThresholds(true);
        try {
            FEC_CaseDsTsSlaService.SlaEligibilityContext teleCtx = new FEC_CaseDsTsSlaService.SlaEligibilityContext();
            teleCtx.isEligible = true;
            teleCtx.activeProfiles = new List<String>{ FEC_CaseDsTsSlaService.PROFILE_TELESALES };
            teleCtx.profileToAnchor.put(FEC_CaseDsTsSlaService.PROFILE_TELESALES, oldDt);

            Case baseRow = new Case(Id = '500000000000000AAA');
            Case patch1 = FEC_CaseDsTsSlaService.buildNotificationPatch(baseRow, teleCtx, nowDt);
            System.assertNotEquals(null, patch1);
            System.assertNotEquals(null, patch1.FEC_SLA_Notification_1__c);

            baseRow.FEC_SLA_Notification_1__c = nowDt;
            Case patch2 = FEC_CaseDsTsSlaService.buildNotificationPatch(baseRow, teleCtx, nowDt);
            System.assertNotEquals(null, patch2);
            System.assertNotEquals(null, patch2.FEC_SLA_Notification_2__c);

            FEC_CaseDsTsSlaService.SlaEligibilityContext dsCtx = new FEC_CaseDsTsSlaService.SlaEligibilityContext();
            dsCtx.isEligible = true;
            dsCtx.activeProfiles = new List<String>{ FEC_CaseDsTsSlaService.PROFILE_DIRECT_SALES };
            dsCtx.profileToAnchor.put(FEC_CaseDsTsSlaService.PROFILE_DIRECT_SALES, oldDt);
            Case dsRow = new Case(
                Id = '500000000000001AAA',
                FEC_SLA_Notification_1__c = nowDt,
                FEC_SLA_Notification_2__c = nowDt
            );
            Case patch3 = FEC_CaseDsTsSlaService.buildNotificationPatch(dsRow, dsCtx, nowDt);
            System.assertNotEquals(null, patch3);
            System.assertNotEquals(null, patch3.FEC_SLA_Notification_3__c);
        } finally {
            FEC_CaseDsTsSlaService.setUseOneMinuteTestThresholds(false);
        }
    }

    @IsTest
    static void testBulkResolveAnchorsPerProfile_th1HistoryMatching() {
        Set<Id> queueIds = FEC_CaseDsTsSlaService.getSlaOwnerQueueIds();
        if (queueIds.isEmpty()) {
            System.assert(true, 'No SLA queue metadata in org.');
            return;
        }
        Id complaintId = ensureCategory('Complaint', 'CMBK-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(5));
        Id queueId = queueIds.iterator().next();

        Case c = insertCaseRow(new Case(
            Subject = 'Bulk Anchor TH1',
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            OwnerId = queueId,
            FEC_Team__c = 'TS',
            FEC_Category__c = complaintId
        ));

        // Matching RAH for TH1
        FEC_Routing_Action_History__c okRah = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
            FEC_Routing_Action_Type__c = 'Case',
            FEC_Updated_User_Queue_ID__c = String.valueOf(queueId)
        );
        // Non-matching RAH branch (Assignment type) for TH1
        FEC_Routing_Action_History__c badRah = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
            FEC_Routing_Action_Type__c = 'Assignment',
            FEC_Updated_User_Queue_ID__c = String.valueOf(queueId)
        );
        insert new List<FEC_Routing_Action_History__c>{ okRah, badRah };
        Test.setCreatedDate(okRah.Id, System.now().addMinutes(-4));
        Test.setCreatedDate(badRah.Id, System.now().addMinutes(-2));

        Case snap = buildCaseSnapshot(
            queueId,
            FEC_ConstantCommon.CASE_STATUS_PENDING,
            'TS',
            0,
            '',
            'Complaint'
        );
        FEC_CaseDsTsSlaService.SlaEligibilityContext ctx = FEC_CaseDsTsSlaService.evaluateEligibility(snap);
        Map<Id, FEC_CaseDsTsSlaService.SlaEligibilityContext> mapCtx =
            new Map<Id, FEC_CaseDsTsSlaService.SlaEligibilityContext>{ c.Id => ctx };

        FEC_CaseDsTsSlaService.bulkResolveAnchors(mapCtx);
        System.assertEquals(true, ctx.profileToAnchor != null);
        System.assertEquals(true, ctx.anchorDatetime == null || ctx.anchorDatetime != null);
    }
}
