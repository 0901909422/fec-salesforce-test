@isTest
private class FEC_CaseAssignmentFieldHistorySyncTest {
    @isTest
    static void syncTimeSlotsHistoryMirror_keepsTrackedFieldInSync() {
        BusinessHours hours = [SELECT Id FROM BusinessHours LIMIT 1];

        FEC_Case_Assignment__c assignment = new FEC_Case_Assignment__c(
            Name = 'CA-TimeSlots-History-' + String.valueOf(Crypto.getRandomLong()),
            FEC_Status__c = 'Draft',
            FEC_Assignment_Method__c = 'Time-Based',
            FEC_Business_Hours__c = hours.Id,
            FEC_Select_Queues__c = 'Queue Z',
            FEC_Role__c = 'FEC Time Slots History Role|1',
            FEC_Scale__c = 1,
            FEC_Time_Slots__c = '08:00;09:00'
        );
        insert assignment;

        assignment = [
            SELECT Id, FEC_Time_Slots__c, FEC_Time_Slots_Tracked__c
            FROM FEC_Case_Assignment__c
            WHERE Id = :assignment.Id
        ];
        System.assertEquals('08:00;09:00', assignment.FEC_Time_Slots_Tracked__c);

        assignment.FEC_Time_Slots__c = '08:00;09:30';
        update assignment;

        assignment = [
            SELECT FEC_Time_Slots__c, FEC_Time_Slots_Tracked__c
            FROM FEC_Case_Assignment__c
            WHERE Id = :assignment.Id
        ];
        System.assertEquals('08:00;09:30', assignment.FEC_Time_Slots__c);
        System.assertEquals('08:00;09:30', assignment.FEC_Time_Slots_Tracked__c);
    }
}
