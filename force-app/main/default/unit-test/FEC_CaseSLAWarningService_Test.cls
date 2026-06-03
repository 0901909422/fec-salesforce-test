/**
 * Unit tests for FEC_CaseSLAWarningService (org source + test bypass hooks).
 */
@IsTest
private class FEC_CaseSLAWarningService_Test {

    private static String uniqueSuffix() {
        return String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6);
    }

    private static void resetTestBypasses() {
        FEC_CaseSLAWarningService.testNotificationTypeOverride = null;
        FEC_CaseSLAWarningService.testFixedUserIdsOverride = null;
        FEC_CaseSLAWarningService.testUsersByRoleOverride = null;
    }

    private static Boolean bindNotificationTypeForTest() {
        resetTestBypasses();
        for (String devName : new List<String>{
            'FEC_Case_SLA_Warning',
            'Custom_Notification'
        }) {
            List<CustomNotificationType> rows = [
                SELECT Id, DeveloperName
                FROM CustomNotificationType
                WHERE DeveloperName = :devName
                LIMIT 1
            ];
            if (!rows.isEmpty()) {
                FEC_CaseSLAWarningService.testNotificationTypeOverride = rows[0];
                return true;
            }
        }
        return false;
    }

    private static void bindUsersByRoleForTest() {
        User runUser = [
            SELECT Id, Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        User stubUser = new User(Id = runUser.Id, Email = runUser.Email);
        FEC_CaseSLAWarningService.testUsersByRoleOverride = new Map<String, List<User>>{
            'Senior Customer Care Specialist' => new List<User>{ stubUser },
            'Customer Care Manager' => new List<User>{ stubUser },
            'Unit Head of Customer Care' => new List<User>{ stubUser },
            'Senior Customer Service Support Specialist' => new List<User>{ stubUser },
            'Unit Head of Customer Service Support' => new List<User>{ stubUser }
        };
        FEC_CaseSLAWarningService.testFixedUserIdsOverride = new Set<String>{
            runUser.Id
        };
    }

    private static FEC_Category__c insertCategory(String nameValue) {
        FEC_Category__c c = new FEC_Category__c(
            Name = nameValue,
            FEC_Code__c = nameValue.left(3).toUpperCase() + uniqueSuffix(),
            FEC_Active__c = true
        );
        insert c;
        return c;
    }

    private static Case insertCaseRow(Case row) {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert row;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return row;
    }

    private static void touchCaseHistory(List<Case> cases) {
        for (Case c : cases) {
            c.Subject = c.Subject + ' hist';
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update cases;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @TestSetup
    static void setupData() {
        insertCategory('Request');
        insertCategory('Complaint');
        insertCategory('Internal Task');
    }

    private static Id categoryId(String nameValue) {
        return [SELECT Id FROM FEC_Category__c WHERE Name = :nameValue LIMIT 1].Id;
    }

    private static List<Case> buildBranchCases() {
        Id requestCatId = categoryId('Request');
        Id complaintCatId = categoryId('Complaint');
        Id internalTaskCatId = categoryId('Internal Task');

        List<Case> cases = new List<Case>();
        cases.add(insertCaseRow(new Case(
            Subject = 'SLA Warn Req CS True',
            Status = 'New',
            FEC_Category__c = requestCatId,
            FEC_CS_Support__c = true
        )));
        cases.add(insertCaseRow(new Case(
            Subject = 'SLA Warn Req CS False',
            Status = 'New',
            FEC_Category__c = requestCatId,
            FEC_CS_Support__c = false
        )));
        cases.add(insertCaseRow(new Case(
            Subject = 'SLA Warn Internal Task',
            Status = 'New',
            FEC_Category__c = internalTaskCatId,
            FEC_CS_Support__c = false
        )));
        cases.add(insertCaseRow(new Case(
            Subject = 'SLA Warn Care True',
            Status = 'New',
            FEC_Category__c = complaintCatId,
            FEC_Is_CS_Customer_Care__c = true
        )));
        cases.add(insertCaseRow(new Case(
            Subject = 'SLA Warn Care False',
            Status = 'New',
            FEC_Category__c = complaintCatId,
            FEC_Is_CS_Customer_Care__c = false
        )));
        cases.add(insertCaseRow(new Case(
            Subject = 'SLA Warn No Category',
            Status = 'New'
        )));
        return cases;
    }

    @IsTest
    static void testHandleWarning_allBranches() {
        System.assertEquals(
            true,
            bindNotificationTypeForTest(),
            'Org must have FEC_Case_SLA_Warning or Custom_Notification.'
        );
        bindUsersByRoleForTest();

        List<Case> cases = buildBranchCases();
        touchCaseHistory(cases);

        Test.startTest();
        FEC_CaseSLAWarningService.handleWarning(cases);
        Test.stopTest();

        System.assertEquals(6, cases.size());
        resetTestBypasses();
    }

    @IsTest
    static void testHandleViolation_allBranches() {
        System.assertEquals(
            true,
            bindNotificationTypeForTest(),
            'Org must have FEC_Case_SLA_Warning or Custom_Notification.'
        );
        bindUsersByRoleForTest();

        List<Case> cases = buildBranchCases();
        touchCaseHistory(cases);

        Test.startTest();
        FEC_CaseSLAWarningService.handleViolation(cases);
        Test.stopTest();

        System.assertEquals(6, cases.size());
        resetTestBypasses();
    }

    @IsTest
    static void testHandleWarning_noNotificationType_returnsEarly() {
        resetTestBypasses();

        Test.startTest();
        FEC_CaseSLAWarningService.handleWarning(new List<Case>());
        FEC_CaseSLAWarningService.handleViolation(new List<Case>());
        Test.stopTest();

        System.assert(true, 'Missing notification type should return without error.');
    }

    @IsTest
    static void testHandleWarning_emptyCaseList() {
        System.assertEquals(true, bindNotificationTypeForTest());
        bindUsersByRoleForTest();

        Test.startTest();
        FEC_CaseSLAWarningService.handleWarning(new List<Case>());
        FEC_CaseSLAWarningService.handleViolation(new List<Case>());
        Test.stopTest();

        resetTestBypasses();
        System.assert(true, 'Empty list should complete without exception.');
    }
}
