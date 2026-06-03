@IsTest
private class FEC_SalesLogicSelector_Test {

    @IsTest
    static void testSelectAllOrdered_emptyAndSorted() {
        Test.startTest();
        List<FEC_Sales_Logic__c> beforeInsert = FEC_SalesLogicSelector.selectAllOrdered();
        Test.stopTest();

        System.assertNotEquals(null, beforeInsert);

        if (!Schema.sObjectType.FEC_Sales_Logic__c.isCreateable()) {
            System.assert(true, 'Skipped insert: FEC_Sales_Logic__c not createable.');
            return;
        }

        insert new List<FEC_Sales_Logic__c>{
            new FEC_Sales_Logic__c(
                FEC_Sequence__c = 20,
                FEC_CC_Code__c = 'AR',
                FEC_DSA_Code__c = 'CC',
                FEC_TSA_Code__c = 'CC',
                FEC_Sales_Channel__c = 'POS',
                FEC_Sales_Sub_Channel__c = 'POS_CC'
            ),
            new FEC_Sales_Logic__c(
                FEC_Sequence__c = 10,
                FEC_CC_Code__c = 'CC',
                FEC_DSA_Code__c = 'CC',
                FEC_TSA_Code__c = 'CC',
                FEC_Sales_Channel__c = 'POS',
                FEC_Sales_Sub_Channel__c = 'POS_CC'
            )
        };

        List<FEC_Sales_Logic__c> rows = FEC_SalesLogicSelector.selectAllOrdered();
        System.assert(rows.size() >= 2, 'Should return inserted sales logic rows.');

        Id laterRowId = [
            SELECT Id
            FROM FEC_Sales_Logic__c
            WHERE FEC_Sequence__c = 20 AND FEC_CC_Code__c = 'AR'
            LIMIT 1
        ].Id;
        Id earlierRowId = [
            SELECT Id
            FROM FEC_Sales_Logic__c
            WHERE FEC_Sequence__c = 10 AND FEC_CC_Code__c = 'CC'
            LIMIT 1
        ].Id;

        Integer laterIdx = null;
        Integer earlierIdx = null;
        for (Integer i = 0; i < rows.size(); i++) {
            if (rows[i].Id == laterRowId) {
                laterIdx = i;
            }
            if (rows[i].Id == earlierRowId) {
                earlierIdx = i;
            }
        }
        System.assertNotEquals(null, earlierIdx);
        System.assertNotEquals(null, laterIdx);
        System.assert(earlierIdx < laterIdx, 'Lower FEC_Sequence__c should appear first.');
    }
}
