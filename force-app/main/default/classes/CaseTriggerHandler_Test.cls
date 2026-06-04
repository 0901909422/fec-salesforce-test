@IsTest
private class CaseTriggerHandler_Test {

    private static Case insertCase(String externalId, String subject) {
        Case c = new Case(
            Subject = subject,
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_External_Interaction_ID__c = externalId,
            FEC_ID_Search__c = subject + '-' + String.valueOf(System.currentTimeMillis())
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
    static void testOnBeforeInsert_noDuplicateExternalId() {
        CaseTriggerHandler handler = new CaseTriggerHandler();
        Case first = insertCase('EXT-DUP-001', 'Case Trigger Handler First');

        Case duplicate = new Case(
            Subject = 'Case Trigger Handler Duplicate',
            FEC_External_Interaction_ID__c = 'EXT-DUP-001'
        );

        Test.startTest();
        handler.onBeforeInsert(new List<Case>{ duplicate });
        Test.stopTest();

        System.assertEquals(true, duplicate.getErrors().size() > 0);
    }

    @IsTest
    static void testOnBeforeInsert_blankExternalIdSkipped() {
        CaseTriggerHandler handler = new CaseTriggerHandler();
        Case row = new Case(Subject = 'No External Id');

        Test.startTest();
        handler.onBeforeInsert(new List<Case>{ row });
        Test.stopTest();

        System.assertEquals(0, row.getErrors().size());
    }

    @IsTest
    static void testOnBeforeUpdate_detectsChangedExternalId() {
        Case existing = insertCase('EXT-OLD-001', 'Case Trigger Handler Update Base');
        existing.FEC_External_Interaction_ID__c = 'EXT-NEW-001';

        CaseTriggerHandler handler = new CaseTriggerHandler();
        Test.startTest();
        handler.onBeforeUpdate(
            new List<Case>{ existing },
            new Map<Id, Case>{
                existing.Id => new Case(
                    Id = existing.Id,
                    FEC_External_Interaction_ID__c = 'EXT-OLD-001'
                )
            }
        );
        Test.stopTest();

        System.assertEquals(0, existing.getErrors().size());
    }

    @IsTest
    static void testOnBeforeUpdate_duplicateExternalId() {
        Case first = insertCase('EXT-UPD-DUP-001', 'Case Trigger Handler Dup First');
        Case second = insertCase('EXT-UPD-DUP-002', 'Case Trigger Handler Dup Second');
        second.FEC_External_Interaction_ID__c = first.FEC_External_Interaction_ID__c;

        CaseTriggerHandler handler = new CaseTriggerHandler();
        Test.startTest();
        handler.onBeforeUpdate(
            new List<Case>{ second },
            new Map<Id, Case>{
                second.Id => new Case(
                    Id = second.Id,
                    FEC_External_Interaction_ID__c = 'EXT-UPD-DUP-002'
                )
            }
        );
        Test.stopTest();

        System.assertEquals(true, second.getErrors().size() > 0);
    }

    @IsTest
    static void testOnBeforeUpdate_unchangedExternalIdSkipped() {
        Case existing = insertCase('EXT-SAME-001', 'Case Trigger Handler Same');
        Case oldRow = new Case(
            Id = existing.Id,
            FEC_External_Interaction_ID__c = existing.FEC_External_Interaction_ID__c
        );

        CaseTriggerHandler handler = new CaseTriggerHandler();
        Test.startTest();
        handler.onBeforeUpdate(new List<Case>{ existing }, new Map<Id, Case>{ existing.Id => oldRow });
        Test.stopTest();

        System.assertEquals(0, existing.getErrors().size());
    }
}
