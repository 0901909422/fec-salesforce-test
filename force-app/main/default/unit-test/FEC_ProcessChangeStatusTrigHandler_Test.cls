@IsTest
private class FEC_ProcessChangeStatusTrigHandler_Test {

    private static String suffix() {
        return String.valueOf(System.currentTimeMillis()).right(6);
    }

    private static FEC_Case_Channel__c newChannel(String codeSuffix) {
        return new FEC_Case_Channel__c(
            Name = 'PCS ' + codeSuffix,
            FEC_Code__c = 'PCS' + codeSuffix,
            FEC_Channel_Status__c = true,
            FEC_Status__c = true
        );
    }

    @IsTest
    static void testHandleBeforeInsert_SetsNewOnRecords() {
        FEC_Case_Channel__c ch1 = newChannel('A' + suffix());
        FEC_Case_Channel__c ch2 = newChannel('B' + suffix());

        Test.startTest();
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeInsert(
            new List<SObject>{ ch1, ch2 }
        );
        insert new List<FEC_Case_Channel__c>{ ch1, ch2 };
        Test.stopTest();

        for (FEC_Case_Channel__c row : [
            SELECT Process_Change_Status__c
            FROM FEC_Case_Channel__c
            WHERE Id IN :new Set<Id>{ ch1.Id, ch2.Id }
        ]) {
            System.assertEquals(FEC_Constants.PROCESS_STATUS_NEW, row.Process_Change_Status__c);
        }
    }

    @IsTest
    static void testHandleBeforeInsert_NullOrDisabled() {
        FEC_Case_Channel__c ch = newChannel('N' + suffix());
        ch.put(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS, 'Keep');

        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeInsert(null);
        System.assertEquals('Keep', ch.get(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS));

        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeInsert(new List<SObject>{ ch });
        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
        System.assertEquals('Keep', ch.get(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS));
    }

    @IsTest
    static void testHandleBeforeUpdate_KeepsNewWhenOldIsNew() {
        FEC_Case_Channel__c ch = newChannel('U1' + suffix());
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeInsert(new List<SObject>{ ch });
        insert ch;

        FEC_Case_Channel__c oldRow = [
            SELECT Id, Name, Process_Change_Status__c
            FROM FEC_Case_Channel__c
            WHERE Id = :ch.Id
        ];
        FEC_Case_Channel__c newRow = [
            SELECT Id, Name, Process_Change_Status__c
            FROM FEC_Case_Channel__c
            WHERE Id = :ch.Id
        ];
        newRow.Name = 'Renamed';

        Test.startTest();
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeUpdate(
            new List<SObject>{ newRow },
            new Map<Id, SObject>{ oldRow.Id => oldRow }
        );
        update newRow;
        Test.stopTest();

        System.assertEquals(FEC_Constants.PROCESS_STATUS_NEW, newRow.Process_Change_Status__c);
    }

    @IsTest
    static void testHandleBeforeUpdate_SetsUpdateWhenOldNotNew() {
        FEC_Case_Channel__c ch = newChannel('U2' + suffix());
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeInsert(new List<SObject>{ ch });
        insert ch;

        FEC_Case_Channel__c oldRow = [
            SELECT Id, Name, Process_Change_Status__c
            FROM FEC_Case_Channel__c
            WHERE Id = :ch.Id
        ];
        oldRow.Process_Change_Status__c = FEC_Constants.PROCESS_STATUS_SYNCED;
        update oldRow;

        oldRow = [
            SELECT Id, Name, Process_Change_Status__c
            FROM FEC_Case_Channel__c
            WHERE Id = :ch.Id
        ];
        FEC_Case_Channel__c newRow = [
            SELECT Id, Name, Process_Change_Status__c
            FROM FEC_Case_Channel__c
            WHERE Id = :ch.Id
        ];
        newRow.Name = 'Updated after sync';

        Test.startTest();
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeUpdate(
            new List<SObject>{ newRow },
            new Map<Id, SObject>{ oldRow.Id => oldRow }
        );
        update newRow;
        Test.stopTest();

        System.assertEquals(FEC_Constants.PROCESS_STATUS_UPDATE, newRow.Process_Change_Status__c);
    }

    @IsTest
    static void testHandleBeforeUpdate_NullOldMapSetsUpdate() {
        FEC_Case_Channel__c ch = newChannel('U3' + suffix());
        insert ch;

        FEC_Case_Channel__c newRow = [
            SELECT Id, Name, Process_Change_Status__c
            FROM FEC_Case_Channel__c
            WHERE Id = :ch.Id
        ];
        newRow.Name = 'No old map';

        Test.startTest();
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeUpdate(
            new List<SObject>{ newRow },
            null
        );
        update newRow;
        Test.stopTest();

        System.assertEquals(FEC_Constants.PROCESS_STATUS_UPDATE, newRow.Process_Change_Status__c);
    }

    @IsTest
    static void testHandleBeforeUpdate_NullListOrDisabled() {
        FEC_Case_Channel__c ch = newChannel('U4' + suffix());
        ch.put(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS, 'Hold');

        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeUpdate(null, new Map<Id, SObject>());
        System.assertEquals('Hold', ch.get(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS));

        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeUpdate(
            new List<SObject>{ ch },
            new Map<Id, SObject>{ ch.Id => ch }
        );
        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
        System.assertEquals('Hold', ch.get(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS));
    }

    @IsTest
    static void testTriggerDisabledOnInsert() {
        FEC_Case_Channel__c ch = newChannel('D' + suffix());
        ch.Process_Change_Status__c = 'Custom';

        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;

        Test.startTest();
        insert ch;
        Test.stopTest();

        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;

        System.assertEquals(
            'Custom',
            [SELECT Process_Change_Status__c FROM FEC_Case_Channel__c WHERE Id = :ch.Id]
            .Process_Change_Status__c
        );
    }

    @IsTest
    static void testHandleBeforeUpdate_WhenOldStatusNull() {
        FEC_Case_Channel__c ch = newChannel('N' + suffix());
        insert ch;

        FEC_Case_Channel__c oldRow = [
            SELECT Id, Process_Change_Status__c
            FROM FEC_Case_Channel__c
            WHERE Id = :ch.Id
        ];
        FEC_Case_Channel__c newRow = [
            SELECT Id, Name, Process_Change_Status__c
            FROM FEC_Case_Channel__c
            WHERE Id = :ch.Id
        ];
        newRow.Name = 'Changed without prior status';

        Test.startTest();
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeUpdate(
            new List<SObject>{ newRow },
            new Map<Id, SObject>{ oldRow.Id => oldRow }
        );
        update newRow;
        Test.stopTest();

        System.assertEquals(
            FEC_Constants.PROCESS_STATUS_UPDATE,
            [SELECT Process_Change_Status__c FROM FEC_Case_Channel__c WHERE Id = :ch.Id]
            .Process_Change_Status__c
        );
    }

    @IsTest
    static void testHandleBeforeInsert_BulkRecords() {
        List<SObject> rows = new List<SObject>();
        String sfx = suffix();
        for (Integer i = 0; i < 50; i++) {
            rows.add(newChannel(String.valueOf(i) + sfx));
        }

        Test.startTest();
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeInsert(rows);
        insert rows;
        Test.stopTest();

        Set<Id> ids = new Set<Id>();
        for (SObject row : rows) {
            ids.add(row.Id);
        }
        for (FEC_Case_Channel__c row : [
            SELECT Process_Change_Status__c
            FROM FEC_Case_Channel__c
            WHERE Id IN :ids
        ]) {
            System.assertEquals(FEC_Constants.PROCESS_STATUS_NEW, row.Process_Change_Status__c);
        }
    }
}
