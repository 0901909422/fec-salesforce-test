/**
 * Unit tests for FEC_ApplicationListTriggerHandler
 * (sync sales channel to FEC_Customer_History__c).
 */
@IsTest
private class FEC_ApplicationListTriggerHandler_Test {

    private static User adminUser() {
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE
            LIMIT 1
        ];
    }

    private static FEC_Customer_History__c insertCustomerHistory() {
        Case c = new Case(Subject = 'FEC_ApplicationListTriggerHandler_Test');
        insert c;
        FEC_Customer_History__c ch = new FEC_Customer_History__c(FEC_Case__c = c.Id);
        insert ch;
        return ch;
    }

    private static FEC_Application_List__c buildApplicationList(Id customerHistoryId, String ccCode) {
        return new FEC_Application_List__c(
            FEC_Customer_History__c = customerHistoryId,
            FEC_CC_Code__c = ccCode,
            FEC_DSA_Code__c = '',
            FEC_TSA_Code__c = ''
        );
    }

    @IsTest
    static void syncSalesChannel_insert_syncsCustomerHistory() {
        System.runAs(adminUser()) {
            FEC_Customer_History__c ch = insertCustomerHistory();
            FEC_Application_List__c al = buildApplicationList(ch.Id, 'CC');

            Test.startTest();
            insert al;
            Test.stopTest();

            FEC_Customer_History__c loaded = [
                SELECT FEC_Sales_Channel__c, FEC_Sales_Sub_Channel__c
                FROM FEC_Customer_History__c
                WHERE Id = :ch.Id
            ];
            System.assertEquals('POS', loaded.FEC_Sales_Channel__c);
            System.assertEquals('POS_CC', loaded.FEC_Sales_Sub_Channel__c);
        }
    }

    @IsTest
    static void syncSalesChannel_update_codeChange_resyncs() {
        System.runAs(adminUser()) {
            FEC_Customer_History__c ch = insertCustomerHistory();
            FEC_Application_List__c al = buildApplicationList(ch.Id, 'KI');
            insert al;

            Test.startTest();
            al.FEC_CC_Code__c = 'CC';
            update al;
            Test.stopTest();

            FEC_Customer_History__c loaded = [
                SELECT FEC_Sales_Channel__c, FEC_Sales_Sub_Channel__c
                FROM FEC_Customer_History__c
                WHERE Id = :ch.Id
            ];
            System.assertEquals('POS', loaded.FEC_Sales_Channel__c);
            System.assertEquals('POS_CC', loaded.FEC_Sales_Sub_Channel__c);
        }
    }

    @IsTest
    static void syncSalesChannel_nullCustomerHistory_skips() {
        FEC_Application_List__c al = new FEC_Application_List__c(
            FEC_CC_Code__c = 'CC',
            FEC_DSA_Code__c = '',
            FEC_TSA_Code__c = ''
        );

        new FEC_ApplicationListTriggerHandler().syncSalesChannelFromApplicationList(
            new List<FEC_Application_List__c>{ al },
            null,
            false
        );

        System.assertEquals(null, al.FEC_Customer_History__c);
        System.assertEquals(0, [SELECT COUNT() FROM FEC_Customer_History__c]);
    }

    @IsTest
    static void syncSalesChannel_update_noTrackedFieldChange_skips() {
        System.runAs(adminUser()) {
            FEC_Customer_History__c ch = insertCustomerHistory();
            FEC_Application_List__c al = buildApplicationList(ch.Id, 'KI');
            insert al;

            FEC_Customer_History__c before = [
                SELECT FEC_Sales_Channel__c, FEC_Sales_Sub_Channel__c
                FROM FEC_Customer_History__c
                WHERE Id = :ch.Id
            ];
            System.assertEquals('THIRD PARTY', before.FEC_Sales_Channel__c);

            FEC_Application_List__c oldRow = new FEC_Application_List__c(
                Id = al.Id,
                FEC_Customer_History__c = al.FEC_Customer_History__c,
                FEC_CC_Code__c = al.FEC_CC_Code__c,
                FEC_DSA_Code__c = al.FEC_DSA_Code__c,
                FEC_TSA_Code__c = al.FEC_TSA_Code__c
            );
            FEC_Application_List__c updated = new FEC_Application_List__c(
                Id = al.Id,
                FEC_Customer_History__c = al.FEC_Customer_History__c,
                FEC_CC_Code__c = al.FEC_CC_Code__c,
                FEC_DSA_Code__c = al.FEC_DSA_Code__c,
                FEC_TSA_Code__c = al.FEC_TSA_Code__c,
                FEC_CC_Name__c = 'Name only change'
            );

            new FEC_ApplicationListTriggerHandler().syncSalesChannelFromApplicationList(
                new List<FEC_Application_List__c>{ updated },
                new Map<Id, FEC_Application_List__c>{ al.Id => oldRow },
                true
            );

            FEC_Customer_History__c after = [
                SELECT FEC_Sales_Channel__c, FEC_Sales_Sub_Channel__c
                FROM FEC_Customer_History__c
                WHERE Id = :ch.Id
            ];
            System.assertEquals(before.FEC_Sales_Channel__c, after.FEC_Sales_Channel__c);
            System.assertEquals(before.FEC_Sales_Sub_Channel__c, after.FEC_Sales_Sub_Channel__c);
        }
    }
}
