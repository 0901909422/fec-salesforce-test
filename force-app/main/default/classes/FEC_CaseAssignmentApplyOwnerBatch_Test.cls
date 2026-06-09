@IsTest
private class FEC_CaseAssignmentApplyOwnerBatch_Test {

    private static User getRunAsUser() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return admins.isEmpty() ? new User(Id = UserInfo.getUserId()) : admins[0];
    }

    private static FEC_Case_Assignment__c createAssignmentRule(String nameValue) {
        FEC_Case_Assignment__c rule = new FEC_Case_Assignment__c(
            Name = nameValue,
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Scheduled_Time__c = 1,
            FEC_Select_Queues__c = 'Queue CS Support',
            FEC_Role__c = 'CS Agent A',
            FEC_Scale__c = 1,
            FEC_Status__c = 'Draft'
        );
        insert rule;
        return rule;
    }

    private static Case createCaseRow(String subjectValue) {
        Case c = new Case(
            Subject = subjectValue,
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    @IsTest
    static void testBatchApplyOwner_successAndFinishLog() {
        System.runAs(getRunAsUser()) {
            FEC_Case_Assignment__c rule = createAssignmentRule('Apply Owner Rule - Success');
            User assignedUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            Case queueCase = createCaseRow('Apply Owner Batch Case Success');

            Integer runNumber = 101;
            FEC_CaseAssignmentApplyOwnerBatch batchJob = new FEC_CaseAssignmentApplyOwnerBatch(
                rule.Id,
                rule.Name,
                runNumber,
                new List<Id>{ queueCase.Id, null },
                new List<Id>{ assignedUser.Id, assignedUser.Id },
                new List<Boolean>{ true, true },
                new List<Id>{ null, null },
                new List<Id>{ assignedUser.Id },
                new List<Integer>{ 1 }
            );

            Test.startTest();
            Database.executeBatch(batchJob, 50);
            Test.stopTest();

            Case reloadedCase = [SELECT Id, OwnerId FROM Case WHERE Id = :queueCase.Id LIMIT 1];
            System.assertEquals(assignedUser.Id, reloadedCase.OwnerId, 'Case owner should be updated.');

            List<FEC_Case_Assignment_Logs__c> logs = [
                SELECT Id, Name, FEC_Number_of_Case__c
                FROM FEC_Case_Assignment_Logs__c
                WHERE FEC_Case_Assignment_Name__c = :rule.Id
                AND Name LIKE :('%' + String.valueOf(runNumber))
            ];
            System.assertEquals(1, logs.size(), 'Finish should insert one run log for successful batch.');
            System.assertEquals(2, logs[0].FEC_Number_of_Case__c);
        }
    }

    @IsTest
    static void testBatchGuards_nullAndEmptyInputs() {
        System.runAs(getRunAsUser()) {
            FEC_CaseAssignmentApplyOwnerBatch batchJob = new FEC_CaseAssignmentApplyOwnerBatch(
                null,
                null,
                1,
                null,
                null,
                null,
                null,
                null,
                null
            );

            Test.startTest();
            Database.executeBatch(batchJob, 20);
            Test.stopTest();

            System.assertEquals(
                0,
                [SELECT COUNT() FROM FEC_Case_Assignment_Logs__c WHERE Name LIKE '%% - 1'],
                'Guard clauses should avoid creating any logs.'
            );
        }
    }

    @IsTest
    static void testBatchExecuteCatch_preventsFinishLogWhenErrorOccurs() {
        System.runAs(getRunAsUser()) {
            FEC_Case_Assignment__c rule = createAssignmentRule('Apply Owner Rule - Error');
            Case queueCase = createCaseRow('Apply Owner Batch Case Error');

            // Intentionally wrong Id type for Case.OwnerId update to force DML exception in execute().
            Id invalidOwnerId = rule.Id;
            Integer runNumber = 303;

            FEC_CaseAssignmentApplyOwnerBatch batchJob = new FEC_CaseAssignmentApplyOwnerBatch(
                rule.Id,
                rule.Name,
                runNumber,
                new List<Id>{ queueCase.Id },
                new List<Id>{ invalidOwnerId },
                new List<Boolean>{ true },
                new List<Id>{ null },
                new List<Id>{ UserInfo.getUserId() },
                new List<Integer>{ 1 }
            );

            Test.startTest();
            Database.executeBatch(batchJob, 1);
            Test.stopTest();

            System.assertEquals(
                0,
                [
                    SELECT COUNT()
                    FROM FEC_Case_Assignment_Logs__c
                    WHERE FEC_Case_Assignment_Name__c = :rule.Id
                    AND Name LIKE :('%' + String.valueOf(runNumber))
                ],
                'finish() should skip log insert when execute recorded failures.'
            );
        }
    }
}
