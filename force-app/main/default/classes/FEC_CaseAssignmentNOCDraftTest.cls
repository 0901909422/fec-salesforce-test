@isTest(seeAllData=true)
private class FEC_CaseAssignmentNOCDraftTest {
    @isTest
    static void insertNoc_blockedWhenParentAssignmentNotDraft() {
        List<FEC_Case_Assignment_NOC__c> seeds = [
            SELECT
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_Sub_Category__c,
                FEC_Sub_Code__c
            FROM FEC_Case_Assignment_NOC__c
            WHERE
                FEC_Product_Type__c != NULL
                AND FEC_Category__c != NULL
                AND FEC_Sub_Category__c != NULL
            LIMIT 1
        ];
        if (seeds.isEmpty()) {
            return;
        }

        FEC_Case_Assignment_NOC__c seed = seeds[0];
        FEC_Case_Assignment__c parentRow = new FEC_Case_Assignment__c(
            Name = 'CA-DraftRestriction-' + String.valueOf(Crypto.getRandomLong()),
            FEC_Status__c = 'Active',
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = [SELECT Id FROM BusinessHours LIMIT 1].Id,
            FEC_Select_Queues__c = 'Queue Z',
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = 'FEC Draft Restriction Role|1',
            FEC_Scale__c = 1
        );
        insert parentRow;

        FEC_Case_Assignment_NOC__c noc = new FEC_Case_Assignment_NOC__c(
            FEC_Case_Assignment_Name__c = parentRow.Id,
            FEC_Product_Type__c = seed.FEC_Product_Type__c,
            FEC_Category__c = seed.FEC_Category__c,
            FEC_Sub_Category__c = seed.FEC_Sub_Category__c,
            FEC_Sub_Code__c = seed.FEC_Sub_Code__c
        );

        Database.SaveResult saveResult = Database.insert(noc, false);
        System.assertEquals(false, saveResult.isSuccess(), 'Expect NOC insert to fail.');
        Boolean messageOk =
            saveResult.getErrors()[0].getMessage().contains('Draft') ||
            saveResult.getErrors()[0].getMessage().contains('draft');
        System.assert(messageOk, 'Expect Draft restriction message.');
    }
}