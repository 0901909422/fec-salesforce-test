@IsTest(SeeAllData=true)
private class FEC_CreateCaseListViewController_Test {
    private static Case buildCaseRow(String subjectValue) {
        return new Case(
            Subject = subjectValue,
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING
        );
    }

    @IsTest
    static void testGetProcessActions_returnsOptions() {
        Test.startTest();
        List<Map<String, String>> res = FEC_CreateCaseListViewController.getProcessActions(
            null, null, null, null
        );
        Test.stopTest();

        System.assertNotEquals(null, res, 'Result list should not be null.');
        if (!res.isEmpty()) {
            System.assert(res[0].containsKey('label'), 'Each option should contain label.');
            System.assert(res[0].containsKey('value'), 'Each option should contain value.');
        }
    }

    @IsTest
    static void testGetQueues_returnsList() {
        Test.startTest();
        List<Map<String, String>> res = FEC_CreateCaseListViewController.getQueues(null);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Queue options should not be null.');
    }

    @IsTest
    static void testCreateCase_successAndGenericError() {
        Id createdId;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            createdId = FEC_CreateCaseListViewController.createCase(buildCaseRow('Create case success'));
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        System.assertNotEquals(null, createdId, 'createCase should return inserted Case Id.');

        Boolean threw = false;
        try {
            FEC_CreateCaseListViewController.createCase(null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assertEquals(true, threw, 'createCase should throw AuraHandledException for invalid input.');

        String longSubject = '';
        for (Integer i = 0; i < 300; i++) {
            longSubject += 'A';
        }
        Boolean dmlThrew = false;
        try {
            FEC_CreateCaseListViewController.createCase(new Case(
                Subject = longSubject,
                Status = FEC_ConstantCommon.CASE_STATUS_PENDING
            ));
        } catch (AuraHandledException ex) {
            dmlThrew = true;
        }
        System.assertEquals(true, dmlThrew, 'createCase should throw AuraHandledException for DML failure.');
    }

    @IsTest
    static void testCreateCaseListView_success_blankAndNotFound() {
        String accountNo = 'ACC-' + String.valueOf(System.now().getTime());
        Case ownerCase = buildCaseRow('History owner case');
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert ownerCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Case__c = ownerCase.Id,
            FEC_Account_Number__c = accountNo
        );
        insert hist;

        Id caseId;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            caseId = FEC_CreateCaseListViewController.createCaseListView(new Case(
                Subject = 'CreateCaseListView success',
                Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
                FEC_Account_Number__c = accountNo
            ));
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        System.assertNotEquals(null, caseId, 'createCaseListView should insert case when account exists.');

        Case created = [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        System.assertEquals(hist.Id, created.FEC_Account_or_Contract__c, 'Case should link to matched customer history.');

        Boolean blankThrew = false;
        try {
            FEC_CreateCaseListViewController.createCaseListView(new Case(
                Subject = 'blank account',
                Status = FEC_ConstantCommon.CASE_STATUS_PENDING
            ));
        } catch (AuraHandledException ex) {
            blankThrew = true;
        }
        System.assertEquals(true, blankThrew, 'Should throw when account number is blank.');

        Boolean notFoundThrew = false;
        try {
            FEC_CreateCaseListViewController.createCaseListView(new Case(
                Subject = 'account not found',
                Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
                FEC_Account_Number__c = 'NO-ACC-' + String.valueOf(System.now().getTime())
            ));
        } catch (AuraHandledException ex) {
            notFoundThrew = true;
        }
        System.assertEquals(true, notFoundThrew, 'Should throw AuraHandledException for invalid account resolution path.');
    }

    @IsTest
    static void testGetQueues_whenUserHasQueueMembership() {
        Group q = new Group(
            Name = 'UT Queue ' + String.valueOf(System.now().getTime()),
            Type = 'Queue'
        );
        insert q;
        insert new QueueSobject(
            QueueId = q.Id,
            SobjectType = 'Case'
        );
        insert new GroupMember(
            GroupId = q.Id,
            UserOrGroupId = UserInfo.getUserId()
        );

        Test.startTest();
        List<Map<String, String>> res = FEC_CreateCaseListViewController.getQueues(null);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Queue options should not be null.');
        System.assert(res.size() > 0, 'User queue membership branch should return queue(s).');
    }

    @IsTest
    static void testGetProcessActions_withCreatedRows() {
        FEC_Process_Action__c pa = new FEC_Process_Action__c(
            Name = 'UT PA ' + String.valueOf(System.now().getTime()),
            FEC_Process_Action_ID__c = 'PA-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6),
            FEC_Process_Action_Vietnamese_Name__c = 'UT Vietnamese Name'
        );
        insert pa;

        List<Map<String, String>> res = FEC_CreateCaseListViewController.getProcessActions(null, null, null, null);
        System.assertNotEquals(null, res, 'Process action list should not be null.');
        System.assert(res.size() > 0, 'Should include at least one process action.');
    }
}
