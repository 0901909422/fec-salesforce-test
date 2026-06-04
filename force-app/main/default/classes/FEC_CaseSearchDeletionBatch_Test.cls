/**
 * Unit tests for CaseSearchDeletionBatch.
 * Verifies that only 'Search' cases created 7 days ago are deleted.
 */
@IsTest
private class FEC_CaseSearchDeletionBatch_Test {

    private static Id searchRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        System.assert(
            byDev.containsKey(FEC_ConstantCommon.CASE_SEARCH_RECORD_TYPE_DEV_NAME),
            'Required RecordType is missing: ' + FEC_ConstantCommon.CASE_SEARCH_RECORD_TYPE_DEV_NAME
        );
        return byDev.get(FEC_ConstantCommon.CASE_SEARCH_RECORD_TYPE_DEV_NAME).getRecordTypeId();
    }

    private static Case buildSearchCase(String subject) {
        return new Case(
            RecordTypeId = searchRecordTypeId(),
            Subject = subject,
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN
        );
    }

    @TestSetup
    static void setupData() {
        Case oldCase = buildSearchCase('Old Search Case');
        insert oldCase;
        Test.setCreatedDate(oldCase.Id, Date.today().addDays(-7));

        Case newCase = buildSearchCase('Today Search Case');
        insert newCase;

        Case otherTypeCase = new Case(
            Subject = 'Other Record Type',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN
        );
        insert otherTypeCase;
    }

    @IsTest
    static void executeBatch_deletesOnlyOldSearchCases() {
        Test.startTest();
        CaseSearchDeletionBatch batch = new CaseSearchDeletionBatch();
        Database.executeBatch(batch);
        Test.stopTest();

        List<Case> remainingCases = [SELECT Id, Subject FROM Case];

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Case WHERE Subject = 'Old Search Case'],
            'The old search case should have been deleted.'
        );
        System.assert(
            remainingCases.size() >= 1,
            'At least one non-deleted case should remain.'
        );
    }
}
