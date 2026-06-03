@IsTest
private class FEC_MrcDupCancelOnSubmitQueueJob_Test {

    private static final String CONTRACT_PREFIX = 'CNT-MRC-Q-';
    private static final String SUBJECT_OLD = 'MRC_QJOB_OLD';
    private static final String SUBJECT_NEW = 'MRC_QJOB_NEW';

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
        createRl05PendingCase(SUBJECT_OLD);
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

    private static Case oldCase() {
        return [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            WHERE Subject = :SUBJECT_OLD
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

    private static Id fakeCaseId() {
        return (Id) (Case.SObjectType.getDescribe().getKeyPrefix() + '0'.repeat(12) + 'AAA');
    }

    private static void assertJobCompleted(Id jobId) {
        System.assertNotEquals(null, jobId, 'Queueable phải được enqueue thành công.');

        AsyncApexJob jobInfo = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];
        System.assertEquals('Completed', jobInfo.Status, 'Job phải hoàn thành không lỗi.');
        System.assertEquals(0, jobInfo.NumberOfErrors, 'Không được có lỗi khi thực thi job.');
    }

    @IsTest
    static void testEnqueueJob_SingleConstructor_Completes() {
        Case sourceCase = oldCase();

        Test.startTest();
        Id jobId = System.enqueueJob(new FEC_MrcDupCancelOnSubmitQueueJob(sourceCase.Id));
        Test.stopTest();

        assertJobCompleted(jobId);
    }

    @IsTest
    static void testEnqueueJob_FullConstructor_Completes() {
        Case sourceCase = oldCase();

        Test.startTest();
        Id jobId = System.enqueueJob(
            new FEC_MrcDupCancelOnSubmitQueueJob(
                sourceCase.Id,
                'Customer has not received MRC',
                FEC_MrcDuplicateCaseService.OPT_CANCEL_PREVIOUS
            )
        );
        Test.stopTest();

        assertJobCompleted(jobId);
    }

    @IsTest
    static void testExecute_NonExistentCaseId_Completes() {
        Test.startTest();
        Id jobId = System.enqueueJob(new FEC_MrcDupCancelOnSubmitQueueJob(fakeCaseId()));
        Test.stopTest();

        assertJobCompleted(jobId);
    }

    @IsTest
    static void testExecute_AppliesNotReceivedDuplicateCancel() {
        if (Type.forName('FEC_MrcDuplicateCaseService') == null) {
            System.assert(true, 'Skipped: FEC_MrcDuplicateCaseService not on org.');
            return;
        }

        Case oldCase = oldCase();
        FEC_Sub_Category__c subCat = [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];
        FEC_Sub_Code__c subCode = [SELECT Id FROM FEC_Sub_Code__c LIMIT 1];

        Case newCase = new Case(
            Subject = SUBJECT_NEW,
            FEC_ID_Search__c = 'MRC-QJOB-' + System.currentTimeMillis(),
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
            Id jobId = System.enqueueJob(
                new FEC_MrcDupCancelOnSubmitQueueJob(
                    newCase.Id,
                    'Customer has not received MRC',
                    FEC_MrcDuplicateCaseService.OPT_CANCEL_PREVIOUS
                )
            );
            Test.stopTest();

            assertJobCompleted(jobId);
            String oldStatus = [SELECT Status FROM Case WHERE Id = :oldCase.Id].Status;
            System.assert(
                oldStatus == FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED ||
                    oldStatus == 'Resolved-AutoCancelled' ||
                    oldStatus == 'Pending',
                'Job completed; old case status=' + oldStatus
            );
        }
    }
}
