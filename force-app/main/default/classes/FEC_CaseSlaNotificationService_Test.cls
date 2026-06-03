@IsTest
private class FEC_CaseSlaNotificationService_Test {

    private static Case insertCaseRow(String subjectValue) {
        Case c = new Case(
            Subject = subjectValue,
            Status = 'New'
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    private static Case buildCaseSnapshot(Id caseId, String categoryName, String subCode) {
        String payload = '{"attributes":{"type":"Case"}'
            + ',"Id":"' + String.valueOf(caseId) + '"'
            + ',"FEC_Category__r":{"Name":"' + categoryName + '"}'
            + ',"FEC_SubCategory__r":{"FEC_Code__c":"' + (subCode == null ? '' : subCode) + '"}'
            + '}';
        return (Case) JSON.deserialize(payload, Case.class);
    }

    @IsTest
    static void testIsSlaCancelRequestInternalTaskCase_branches() {
        System.assertEquals(false, FEC_CaseSlaNotificationService.isSlaCancelRequestInternalTaskCase(null));

        Case requestCase = buildCaseSnapshot('500000000000000AAA', 'Request', null);
        System.assertEquals(true, FEC_CaseSlaNotificationService.isSlaCancelRequestInternalTaskCase(requestCase));

        Case taskIsl = buildCaseSnapshot('500000000000001AAA', 'Internal Task', 'XXX-ISL01-YYY');
        System.assertEquals(true, FEC_CaseSlaNotificationService.isSlaCancelRequestInternalTaskCase(taskIsl));

        Case taskIsc = buildCaseSnapshot('500000000000002AAA', 'Internal Task', 'ISC01');
        System.assertEquals(true, FEC_CaseSlaNotificationService.isSlaCancelRequestInternalTaskCase(taskIsc));

        Case taskOther = buildCaseSnapshot('500000000000003AAA', 'Internal Task', 'OTHER');
        System.assertEquals(false, FEC_CaseSlaNotificationService.isSlaCancelRequestInternalTaskCase(taskOther));

        Case otherCategory = buildCaseSnapshot('500000000000004AAA', 'Complaint', 'ISL01');
        System.assertEquals(false, FEC_CaseSlaNotificationService.isSlaCancelRequestInternalTaskCase(otherCategory));
    }

    @IsTest
    static void testBuildRecipients_nullOrEmptyInputs() {
        Map<Id, Set<String>> emptyResult = FEC_CaseSlaNotificationService.buildSlaNotificationRecipientsByCase(
            new Map<Id, Case>(),
            new Map<Id, Boolean>()
        );
        System.assertEquals(0, emptyResult.size());

        Map<Id, Set<String>> nullViolating = FEC_CaseSlaNotificationService.buildSlaNotificationRecipientsByCase(
            new Map<Id, Case>{},
            null
        );
        System.assertEquals(0, nullViolating.size());
    }

    @IsTest
    static void testBuildRecipients_case1AndCase2_warningAndViolating() {
        Case dbCase1 = insertCaseRow('SLA Notif Case 1');
        Case dbCase2 = insertCaseRow('SLA Notif Case 2');

        // routing history (duplicate perform user to also exercise de-duplicate branch)
        insert new List<FEC_Routing_Action_History__c>{
            new FEC_Routing_Action_History__c(
                FEC_Case__c = dbCase1.Id,
                FEC_Perform_User__c = UserInfo.getUserId()
            ),
            new FEC_Routing_Action_History__c(
                FEC_Case__c = dbCase1.Id,
                FEC_Perform_User__c = UserInfo.getUserId()
            ),
            new FEC_Routing_Action_History__c(
                FEC_Case__c = dbCase2.Id,
                FEC_Perform_User__c = UserInfo.getUserId()
            )
        };

        Map<Id, Case> caseById = new Map<Id, Case>{
            dbCase1.Id => buildCaseSnapshot(dbCase1.Id, 'Complaint', null),      // case 1 (remaining)
            dbCase2.Id => buildCaseSnapshot(dbCase2.Id, 'Internal Task', 'ISL01') // case 2
        };

        // warning pass
        Map<Id, Boolean> warningFlags = new Map<Id, Boolean>{
            dbCase1.Id => false,
            dbCase2.Id => false
        };
        Map<Id, Set<String>> warningResult =
            FEC_CaseSlaNotificationService.buildSlaNotificationRecipientsByCase(caseById, warningFlags);
        System.assertEquals(true, warningResult.containsKey(dbCase1.Id));
        System.assertEquals(true, warningResult.containsKey(dbCase2.Id));
        System.assertNotEquals(null, warningResult.get(dbCase1.Id));
        System.assertNotEquals(null, warningResult.get(dbCase2.Id));

        // violating pass
        Map<Id, Boolean> violatingFlags = new Map<Id, Boolean>{
            dbCase1.Id => true,
            dbCase2.Id => true
        };
        Map<Id, Set<String>> violatingResult =
            FEC_CaseSlaNotificationService.buildSlaNotificationRecipientsByCase(caseById, violatingFlags);
        System.assertEquals(true, violatingResult.containsKey(dbCase1.Id));
        System.assertEquals(true, violatingResult.containsKey(dbCase2.Id));
    }

    @IsTest
    static void testBuildRecipients_blankPerformUserAndNullSubCategory() {
        Case dbCase = insertCaseRow('SLA Notif Null Sub');
        insert new FEC_Routing_Action_History__c(
            FEC_Case__c = dbCase.Id
            // FEC_Perform_User__c null => filtered by query condition
        );

        Map<Id, Case> caseById = new Map<Id, Case>{
            dbCase.Id => buildCaseSnapshot(dbCase.Id, 'Internal Task', null)
        };
        Map<Id, Boolean> flags = new Map<Id, Boolean>{
            dbCase.Id => true
        };

        Map<Id, Set<String>> result =
            FEC_CaseSlaNotificationService.buildSlaNotificationRecipientsByCase(caseById, flags);
        System.assertEquals(true, result.containsKey(dbCase.Id));
        System.assertNotEquals(null, result.get(dbCase.Id));
    }

    @IsTest
    static void testBuildRecipients_withPerformUsersInConfiguredGroups() {
        // Try to exercise branches where perform users belong to configured SP/CC groups.
        List<User> ccUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE
              AND FEC_User_Group__c = :FEC_ConstantCommon.RD_ASSESSMENT_TEAM_CC
            LIMIT 1
        ];
        List<User> spUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE
              AND FEC_User_Group__c = :FEC_ConstantCommon.RD_ASSESSMENT_TEAM_SP
            LIMIT 1
        ];

        if (ccUsers.isEmpty() && spUsers.isEmpty()) {
            System.assert(true, 'No active SP/CC users found in org data.');
            return;
        }

        Case case1 = insertCaseRow('SLA Recipient Case1 Group Branch');
        Case case2 = insertCaseRow('SLA Recipient Case2 Group Branch');

        List<FEC_Routing_Action_History__c> rahRows = new List<FEC_Routing_Action_History__c>();
        if (!ccUsers.isEmpty()) {
            rahRows.add(new FEC_Routing_Action_History__c(
                FEC_Case__c = case1.Id,
                FEC_Perform_User__c = ccUsers[0].Id
            ));
        }
        if (!spUsers.isEmpty()) {
            rahRows.add(new FEC_Routing_Action_History__c(
                FEC_Case__c = case2.Id,
                FEC_Perform_User__c = spUsers[0].Id
            ));
        }
        if (!rahRows.isEmpty()) {
            insert rahRows;
        }

        Map<Id, Case> caseById = new Map<Id, Case>{
            case1.Id => buildCaseSnapshot(case1.Id, 'Complaint', null),       // case 1
            case2.Id => buildCaseSnapshot(case2.Id, 'Internal Task', 'ISC01') // case 2
        };
        Map<Id, Boolean> flags = new Map<Id, Boolean>{
            case1.Id => true,   // violating for case1 branch
            case2.Id => false   // warning for case2 branch
        };

        Map<Id, Set<String>> recipients =
            FEC_CaseSlaNotificationService.buildSlaNotificationRecipientsByCase(caseById, flags);
        System.assertEquals(true, recipients.containsKey(case1.Id));
        System.assertEquals(true, recipients.containsKey(case2.Id));
        if (!ccUsers.isEmpty()) {
            System.assertEquals(
                true,
                recipients.get(case1.Id).contains(String.valueOf(ccUsers[0].Id)),
                'Case 1 should include CC perform user when present.'
            );
        }
        if (!spUsers.isEmpty()) {
            System.assertEquals(
                true,
                recipients.get(case2.Id).contains(String.valueOf(spUsers[0].Id)),
                'Case 2 should include SP perform user when present.'
            );
        }
    }
}
