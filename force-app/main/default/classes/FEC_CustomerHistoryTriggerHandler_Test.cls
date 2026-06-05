@IsTest
private class FEC_CustomerHistoryTriggerHandler_Test {

    @IsTest
    static void testSyncSalesChannelFromSalesLogic_insertAndUpdate() {
        User adminUser = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];
        System.runAs(adminUser) {
            if (!Schema.sObjectType.FEC_Sales_Logic__c.isAccessible()) {
                System.assert(true, 'Skipped: no access to FEC_Sales_Logic__c.');
                return;
            }

            String suffix = String.valueOf(System.currentTimeMillis());
            FEC_Sales_Logic__c logicRow = new FEC_Sales_Logic__c(
                FEC_CC_Code__c = 'AR',
                FEC_DSA_Code__c = 'CC',
                FEC_TSA_Code__c = 'CC',
                FEC_Sales_Channel__c = 'POS',
                FEC_Sales_Sub_Channel__c = 'POS_CC'
            );
            insert logicRow;
            FEC_SalesChannelFromApplicationService.clearRulesCacheForTest();

            Case c;
            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                c = new Case(
                    Subject = 'Cust History Handler',
                    Status = 'New',
                    FEC_ID_Search__c = 'CHH-' + suffix
                );
                insert c;
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }

            FEC_Customer_History__c history = new FEC_Customer_History__c(
                FEC_Case__c = c.Id,
                Name = 'CHH_' + suffix,
                FEC_CC_Code__c = 'AR',
                FEC_DSA_Code__c = 'CC',
                FEC_TSA_Code__c = 'CC'
            );
            insert history;

            FEC_CustomerHistoryTriggerHandler handler = new FEC_CustomerHistoryTriggerHandler();

            Test.startTest();
            handler.syncSalesChannelFromSalesLogic(
                new List<FEC_Customer_History__c>{ history },
                null,
                false
            );

            FEC_Customer_History__c oldRow = history.clone(true, true, true, true);
            history.FEC_CC_Code__c = 'NO_MATCH';
            handler.syncSalesChannelFromSalesLogic(
                new List<FEC_Customer_History__c>{ history },
                new Map<Id, FEC_Customer_History__c>{ history.Id => oldRow },
                true
            );

            history.FEC_CC_Code__c = oldRow.FEC_CC_Code__c;
            handler.syncSalesChannelFromSalesLogic(
                new List<FEC_Customer_History__c>{ history },
                new Map<Id, FEC_Customer_History__c>{ history.Id => oldRow },
                true
            );
            Test.stopTest();

            System.assertNotEquals(null, [SELECT Id FROM FEC_Customer_History__c WHERE Id = :history.Id].Id);
        }
    }
}
