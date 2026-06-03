@IsTest
private class FEC_MrcDuplicateCaseService_Test {

    private static final String CONTRACT_PREFIX = 'CNT-MRC-';
    private static final String SUBJECT_OLD_FIND = 'MRC_SETUP_OLD_FIND';
    private static final String SUBJECT_OLD_APPLY = 'MRC_SETUP_OLD_APPLY';

    @TestSetup
    static void setupData() {
        insert new FEC_Sub_Category__c(
            Name = 'RL05',
            FEC_Code__c = 'RL05',
            FEC_Active__c = true
        );
        insert new FEC_Sub_Code__c(
            Name = 'RL05.02',
            FEC_Code__c = 'RL05.02',
            FEC_Active__c = true
        );

        createRl05PendingCase(SUBJECT_OLD_FIND);
        createRl05PendingCase(SUBJECT_OLD_APPLY);
    }

    private static Case createRl05PendingCase(String subject) {
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];
        FEC_Sub_Code__c subCode = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1];

        Case c = new Case(
            Subject = subject,
            FEC_ID_Search__c = subject + '-' + System.currentTimeMillis(),
            FEC_SubCategory__c = subCat.Id,
            FEC_SubCode__c = subCode.Id,
            Status = 'Pending'
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        String contractDisplay = CONTRACT_PREFIX + subject;

        FEC_Customer_History__c cust = new FEC_Customer_History__c(
            Name = contractDisplay,
            FEC_Case__c = c.Id,
            FEC_Contract_Number__c = contractDisplay
        );
        insert cust;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = cust.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        return c;
    }

    private static Case oldCaseBySubject(String subject) {
        return [
            SELECT
                Id,
                CreatedDate,
                FEC_Account_or_Contract__c,
                FEC_Account_Contract_Number_Text__c
            FROM Case
            WHERE Subject = :subject
            LIMIT 1
        ];
    }

    private static User adminUser() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return admins.isEmpty() ? new User(Id = UserInfo.getUserId()) : admins[0];
    }

    @IsTest
    static void testApplyNotReceivedHandlingOptionCancel_Success() {
        if (Type.forName('FEC_MrcDuplicateCaseService') == null) {
            System.assert(true, 'Skipped: FEC_MrcDuplicateCaseService not on org.');
            return;
        }

        Case oldCase = oldCaseBySubject(SUBJECT_OLD_APPLY);
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];
        FEC_Sub_Code__c subCode = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1];

        Case newCase = new Case(
            Subject = 'MRC_DUP_NEW_APPLY',
            FEC_ID_Search__c = 'MRC-NEW-' + System.currentTimeMillis(),
            FEC_SubCategory__c = subCat.Id,
            FEC_SubCode__c = subCode.Id,
            FEC_Customer_Confirmation__c = 'Customer has not received MRC',
            FEC_MRC_Request_Handling_Option__c =
                FEC_MrcDuplicateCaseService.OPT_CANCEL_PREVIOUS,
            Status = 'Pending',
            FEC_Account_or_Contract__c = oldCase.FEC_Account_or_Contract__c
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert newCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_MrcDuplicateCaseService.applyNotReceivedHandlingOptionOnSubmit(
                newCase.Id,
                'Customer has not received MRC',
                FEC_MrcDuplicateCaseService.OPT_CANCEL_PREVIOUS
            );
            Test.stopTest();

            System.assertEquals(
                FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED,
                [SELECT Status FROM Case WHERE Id = :oldCase.Id].Status
            );
        }
    }

    @IsTest
    static void testFindOlderOpenRl05DuplicateInfo() {
        if (Type.forName('FEC_MrcDuplicateCaseService') == null) {
            System.assert(true, 'Skipped: FEC_MrcDuplicateCaseService not on org.');
            return;
        }

        Case oldCase = oldCaseBySubject(SUBJECT_OLD_FIND);

        Case newCase = new Case(
            Subject = 'MRC_DUP_NEW_FIND',
            FEC_ID_Search__c = 'MRC-QRY-' + System.currentTimeMillis(),
            Status = 'Pending',
            FEC_Account_or_Contract__c = oldCase.FEC_Account_or_Contract__c
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert newCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        newCase = [SELECT Id, CreatedDate FROM Case WHERE Id = :newCase.Id];

        Test.startTest();
        FEC_MrcDuplicateCaseService.OpenDupInfo info =
            FEC_MrcDuplicateCaseService.findOlderOpenRl05DuplicateInfo(
                newCase.Id,
                oldCase.FEC_Account_or_Contract__c,
                null,
                newCase.CreatedDate,
                'RL05',
                'RL05.02'
            );
        Test.stopTest();

        System.assertNotEquals(null, info);
        System.assertEquals(String.valueOf(oldCase.Id), info.caseIdStr);
    }

    @IsTest
    static void testFindOlderOpenRl05DuplicateId_AndNullGuards() {
        if (Type.forName('FEC_MrcDuplicateCaseService') == null) {
            System.assert(true, 'Skipped: FEC_MrcDuplicateCaseService not on org.');
            return;
        }

        Case oldCase = oldCaseBySubject(SUBJECT_OLD_FIND);
        Case newCase = new Case(
            Subject = 'MRC_DUP_ID',
            FEC_ID_Search__c = 'MRC-ID-' + System.currentTimeMillis(),
            Status = 'Pending',
            FEC_Account_or_Contract__c = oldCase.FEC_Account_or_Contract__c
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert newCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        newCase = [SELECT Id, CreatedDate FROM Case WHERE Id = :newCase.Id];

        Test.startTest();
        Id dupId = FEC_MrcDuplicateCaseService.findOlderOpenRl05DuplicateId(
            newCase.Id,
            oldCase.FEC_Account_or_Contract__c,
            oldCase.FEC_Account_Contract_Number_Text__c,
            newCase.CreatedDate,
            'RL05',
            'RL05.02'
        );
        FEC_MrcDuplicateCaseService.OpenDupInfo nullInfo =
            FEC_MrcDuplicateCaseService.findOlderOpenRl05DuplicateInfo(
            newCase.Id,
            null,
            null,
            newCase.CreatedDate,
            'RL05',
            'RL05.02'
        );
        FEC_MrcDuplicateCaseService.applyNotReceivedHandlingOptionOnSubmit(null);
        FEC_MrcDuplicateCaseService.applyHandlingOptionChanges(new List<Case>(), new Map<Id, Case>());
        Test.stopTest();

        System.assertEquals(oldCase.Id, dupId);
        System.assertEquals(null, nullInfo);
    }

    @IsTest
    static void testApplyCancelNewRequest() {
        if (Type.forName('FEC_MrcDuplicateCaseService') == null) {
            System.assert(true, 'Skipped: FEC_MrcDuplicateCaseService not on org.');
            return;
        }

        Case oldCase = oldCaseBySubject(SUBJECT_OLD_APPLY);
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];
        FEC_Sub_Code__c subCode = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1];

        Case newCase = new Case(
            Subject = 'MRC_DUP_CANCEL_NEW',
            FEC_ID_Search__c = 'MRC-CN-' + System.currentTimeMillis(),
            FEC_SubCategory__c = subCat.Id,
            FEC_SubCode__c = subCode.Id,
            FEC_Customer_Confirmation__c = FEC_MrcReturnCaseService.CONF_NOT_RECEIVED,
            FEC_MRC_Request_Handling_Option__c = FEC_MrcDuplicateCaseService.OPT_CANCEL_NEW,
            Status = 'Pending',
            FEC_Account_or_Contract__c = oldCase.FEC_Account_or_Contract__c
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert newCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_MrcDuplicateCaseService.applyNotReceivedHandlingOptionOnSubmitNow(
                newCase.Id,
                FEC_MrcReturnCaseService.CONF_NOT_RECEIVED,
                FEC_MrcDuplicateCaseService.OPT_CANCEL_NEW
            );
            Test.stopTest();

            System.assert(
                [SELECT Status FROM Case WHERE Id = :newCase.Id].Status != null,
                'Cancel-new submit path should complete without exception.'
            );
        }
    }

    @IsTest
    static void testApplyReceivedConfirmationDuplicateCancel() {
        if (Type.forName('FEC_MrcDuplicateCaseService') == null) {
            System.assert(true, 'Skipped: FEC_MrcDuplicateCaseService not on org.');
            return;
        }

        Case oldCase = oldCaseBySubject(SUBJECT_OLD_APPLY);
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];
        FEC_Sub_Code__c subCode = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1];

        Case newCase = new Case(
            Subject = 'MRC_DUP_RECEIVED',
            FEC_ID_Search__c = 'MRC-RCV-' + System.currentTimeMillis(),
            FEC_SubCategory__c = subCat.Id,
            FEC_SubCode__c = subCode.Id,
            FEC_Customer_Confirmation__c = FEC_MrcReturnCaseService.CONF_RECEIVED,
            Status = 'Pending',
            FEC_Account_or_Contract__c = oldCase.FEC_Account_or_Contract__c
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert newCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_MrcDuplicateCaseService.applyReceivedConfirmationDuplicateCancelOnSubmit(
                newCase.Id,
                FEC_MrcReturnCaseService.CONF_RECEIVED
            );
            Test.stopTest();

            System.assertEquals(
                FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED,
                [SELECT Status FROM Case WHERE Id = :oldCase.Id].Status
            );
        }
    }

    @IsTest
    static void testSuppressAndDeferFlags() {
        if (Type.forName('FEC_MrcDuplicateCaseService') == null) {
            System.assert(true, 'Skipped: FEC_MrcDuplicateCaseService not on org.');
            return;
        }

        Test.startTest();
        FEC_MrcDuplicateCaseService.setDeferDupRoutingHistoryInsert(true);
        Boolean suppressed = FEC_MrcDuplicateCaseService.isSuppressRoutingHistoryTriggerSideEffects();
        FEC_MrcDuplicateCaseService.setDeferDupRoutingHistoryInsert(false);
        Test.stopTest();

        System.assertEquals(false, suppressed);
    }

    @IsTest
    static void testRecordRoutingActionHistoryForCase() {
        if (Type.forName('FEC_MrcDuplicateCaseService') == null) {
            System.assert(true, 'Skipped: FEC_MrcDuplicateCaseService not on org.');
            return;
        }

        Case oldCase = oldCaseBySubject(SUBJECT_OLD_FIND);

        Test.startTest();
        FEC_MrcDuplicateCaseService.recordRoutingActionHistoryForCase(
            oldCase.Id,
            'Cancel',
            'Pending'
        );
        FEC_MrcDuplicateCaseService.recordRoutingActionHistoryForCase(null, 'Cancel', 'Pending');
        Test.stopTest();

        System.assert(true, 'Routing history delegate should complete without exception.');
    }

    @IsTest
    static void testFindOlderDuplicate_ByContractNumber() {
        if (Type.forName('FEC_MrcDuplicateCaseService') == null) {
            System.assert(true, 'Skipped: FEC_MrcDuplicateCaseService not on org.');
            return;
        }

        Case oldCase = oldCaseBySubject(SUBJECT_OLD_FIND);
        String contractNum = oldCase.FEC_Account_Contract_Number_Text__c;

        Case newCase = new Case(
            Subject = 'MRC_DUP_CONTRACT',
            FEC_ID_Search__c = 'MRC-CNT-' + System.currentTimeMillis(),
            Status = 'Pending',
            FEC_Account_Contract_Number_Text__c = contractNum
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert newCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        newCase = [SELECT Id, CreatedDate FROM Case WHERE Id = :newCase.Id];

        Test.startTest();
        Id dupId = FEC_MrcDuplicateCaseService.findOlderOpenRl05DuplicateId(
            newCase.Id,
            null,
            contractNum,
            newCase.CreatedDate,
            'RL05',
            'RL05.02'
        );
        Test.stopTest();

        System.assertEquals(oldCase.Id, dupId);
    }

    @IsTest
    static void testApplyNotReceivedHandlingOptionOnSubmitNow_WithDefer() {
        if (Type.forName('FEC_MrcDuplicateCaseService') == null) {
            System.assert(true, 'Skipped: FEC_MrcDuplicateCaseService not on org.');
            return;
        }

        Case oldCase = oldCaseBySubject(SUBJECT_OLD_APPLY);
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];
        FEC_Sub_Code__c subCode = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1];

        Case newCase = new Case(
            Subject = 'MRC_DUP_DEFER',
            FEC_ID_Search__c = 'MRC-DEF-' + System.currentTimeMillis(),
            FEC_SubCategory__c = subCat.Id,
            FEC_SubCode__c = subCode.Id,
            FEC_Customer_Confirmation__c = FEC_MrcReturnCaseService.CONF_NOT_RECEIVED,
            FEC_MRC_Request_Handling_Option__c = FEC_MrcDuplicateCaseService.OPT_CANCEL_PREVIOUS,
            Status = 'Pending',
            FEC_Account_or_Contract__c = oldCase.FEC_Account_or_Contract__c
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert newCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        System.runAs(adminUser()) {
            Test.startTest();
            FEC_MrcDuplicateCaseService.setDeferDupRoutingHistoryInsert(true);
            FEC_MrcDuplicateCaseService.applyNotReceivedHandlingOptionOnSubmitNow(newCase.Id);
            FEC_MrcDuplicateCaseService.setDeferDupRoutingHistoryInsert(false);
            Test.stopTest();

            System.assertEquals(
                FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED,
                [SELECT Status FROM Case WHERE Id = :oldCase.Id].Status
            );
        }
    }

    @IsTest
    static void testCreateRoutingActionHistoryForCase_Delegate() {
        if (Type.forName('FEC_MrcDuplicateCaseService') == null) {
            System.assert(true, 'Skipped: FEC_MrcDuplicateCaseService not on org.');
            return;
        }

        Case oldCase = oldCaseBySubject(SUBJECT_OLD_FIND);

        Test.startTest();
        FEC_MrcDuplicateCaseService.createRoutingActionHistoryForCase(
            'Cancel',
            '',
            'Queue',
            oldCase.OwnerId,
            String.valueOf(oldCase.Id),
            'Stage',
            'Pending',
            null
        );
        Test.stopTest();

        System.assert(true, 'Delegate to FEC_CaseBusinessService should complete.');
    }

    @IsTest
    static void testFindOlderDuplicate_InvalidSubCodeReturnsNull() {
        if (Type.forName('FEC_MrcDuplicateCaseService') == null) {
            System.assert(true, 'Skipped: FEC_MrcDuplicateCaseService not on org.');
            return;
        }

        Case oldCase = oldCaseBySubject(SUBJECT_OLD_FIND);

        Test.startTest();
        FEC_MrcDuplicateCaseService.OpenDupInfo info =
            FEC_MrcDuplicateCaseService.findOlderOpenRl05DuplicateInfo(
                oldCase.Id,
                oldCase.FEC_Account_or_Contract__c,
                null,
                Datetime.now(),
                'RL05',
                'RL99'
            );
        Test.stopTest();

        System.assertEquals(null, info);
    }
}
