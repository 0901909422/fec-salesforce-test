@IsTest
private class FEC_NatureOfCaseTriggerHandler_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'PT' + suffix,
            FEC_Active__c = true
        );
        insert pt;

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'Inquiry',
            FEC_Code__c = 'BP' + suffix,
            FEC_Active__c = true
        );
        insert bp;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Payment',
            FEC_Code__c = 'CAT' + suffix,
            FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Late Payment',
            FEC_Code__c = 'SCAT' + suffix,
            FEC_Active__c = true
        );
        insert subCat;

        // Parent NOC: Product Type + Business Process (no Category), with Channel
        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Channel__c = 'Chat;Phone',
            FEC_Active__c = true
        );
    }

    @IsTest
    static void testInheritChannelFromParent_OnInsert() {
        FEC_Product_Type__c pt = [SELECT Id FROM FEC_Product_Type__c LIMIT 1];
        FEC_Business_Process__c bp = [SELECT Id FROM FEC_Business_Process__c LIMIT 1];
        FEC_Category__c cat = [SELECT Id FROM FEC_Category__c LIMIT 1];

        Test.startTest();
        FEC_Nature_of_Case__c childNoc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Active__c = true
        );
        insert childNoc;
        Test.stopTest();

        FEC_Nature_of_Case__c insertedChild = [
            SELECT FEC_Channel__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :childNoc.Id
        ];
        System.assertEquals(
            'Chat;Phone',
            insertedChild.FEC_Channel__c,
            'Child must inherit Channel from immediate parent on insert.'
        );
    }

    @IsTest
    static void testPropagateChannelToChildren_OnUpdate() {
        FEC_Product_Type__c pt = [SELECT Id FROM FEC_Product_Type__c LIMIT 1];
        FEC_Business_Process__c bp = [SELECT Id FROM FEC_Business_Process__c LIMIT 1];
        FEC_Category__c cat = [SELECT Id FROM FEC_Category__c LIMIT 1];

        FEC_Nature_of_Case__c childNoc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Active__c = true
        );
        insert childNoc;

        childNoc.FEC_Channel__c = null;
        update childNoc;

        FEC_Nature_of_Case__c parentNoc = [
            SELECT Id, FEC_Channel__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Category__c = NULL
              AND FEC_Sub_Category__c = NULL
              AND FEC_Sub_Code__c = NULL
            LIMIT 1
        ];

        Test.startTest();
        parentNoc.FEC_Channel__c = 'Email;Branch';
        update parentNoc;
        Test.stopTest();

        FEC_Nature_of_Case__c updatedChild = [
            SELECT FEC_Channel__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :childNoc.Id
        ];
        System.assertEquals(
            'Email;Branch',
            updatedChild.FEC_Channel__c,
            'Child must receive propagated Channel after parent update.'
        );
    }
}
