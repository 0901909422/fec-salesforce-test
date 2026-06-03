@IsTest
private class FEC_CloseInterationSchedulerBatch_Test {

    private static Id recordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        return byDev.containsKey(developerName) ? byDev.get(developerName).getRecordTypeId() : null;
    }

    @TestSetup
    static void setupData() {
        Id interactionRtId = recordTypeId(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);
        System.assertNotEquals(null, interactionRtId, 'Interaction RecordType is required.');

        Id customerRtId = recordTypeId(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME);
        String suffix = String.valueOf(System.currentTimeMillis());
        User runUser = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];

        System.runAs(runUser) {
            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                Case interactionCase = new Case(
                    Subject = 'FEC_CloseInterationSchedulerBatch_Test Interaction',
                    RecordTypeId = interactionRtId,
                    Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                    FEC_Channel__c = FEC_ConstantCommon.CHANNEL_CHAT,
                    OwnerId = runUser.Id,
                    FEC_ID_Search__c = 'CLINT-' + suffix
                );
                insert interactionCase;

                Case serviceCase = new Case(
                    Subject = 'FEC_CloseInterationSchedulerBatch_Test Service',
                    Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                    FEC_Interaction__c = interactionCase.Id,
                    FEC_Is_Submited__c = false,
                    OwnerId = runUser.Id,
                    FEC_ID_Search__c = 'CLSRV-' + suffix
                );
                if (customerRtId != null) {
                    serviceCase.RecordTypeId = customerRtId;
                }
                insert serviceCase;
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }
        }
    }

    @IsTest
    static void testBatchExecution() {
        User runUser = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];

        Case interactionCase;
        System.runAs(runUser) {
            interactionCase = [
                SELECT Id, FEC_Interaction_Status__c
                FROM Case
                WHERE RecordType.DeveloperName = :FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
                AND Subject = 'FEC_CloseInterationSchedulerBatch_Test Interaction'
                LIMIT 1
            ];
            System.assertEquals(
                1,
                [
                    SELECT COUNT()
                    FROM Case
                    WHERE FEC_Interaction__c = :interactionCase.Id AND FEC_Is_Submited__c = false
                ],
                'Phải có Service Case chưa submit liên kết Interaction.'
            );
        }

        FEC_CloseInterationSchedulerBatch batch = new FEC_CloseInterationSchedulerBatch();
        List<Case> scope = [
            SELECT Id, RecordTypeId, Status, OwnerId, FEC_Channel__c,
                   FEC_Interaction_Subchannel__c, FEC_Send_To__c, IsClosed
            FROM Case
            WHERE Id = :interactionCase.Id
        ];

        System.runAs(runUser) {
            Test.startTest();
            batch.execute(null, scope);
            Test.stopTest();
        }

        interactionCase = [
            SELECT Status, FEC_Outcome_Code__c
            FROM Case
            WHERE Id = :interactionCase.Id
        ];
        System.assertEquals(
            FEC_ConstantCommon.CASE_STATUS_AUTO_CLOSED,
            interactionCase.Status,
            'Interaction Case phải được đóng tự động.'
        );
        System.assertEquals(
            FEC_ConstantCommon.OUTCOME_CODE_COMPLETED,
            interactionCase.FEC_Outcome_Code__c
        );

        List<Case> serviceCases = [
            SELECT Status
            FROM Case
            WHERE FEC_Interaction__c = :interactionCase.Id
        ];
        System.assertEquals(1, serviceCases.size());
        System.assertEquals(
            FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED,
            serviceCases[0].Status,
            'Service Case phải được Cancel tự động.'
        );

        System.assert(
            [SELECT COUNT() FROM FEC_Routing_Action_History__c WHERE FEC_Routing_Action__c = 'Cancel'] > 0,
            'Phải tạo Routing Action History.'
        );
    }

    @IsTest
    static void testScheduler() {
        Test.startTest();
        String jobId = System.schedule(
            'Test Scheduler Close Interaction',
            '0 0 0 * * ?',
            new FEC_CloseInterationSchedulerBatch()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = 'Test Scheduler Close Interaction']
        );
    }
}
