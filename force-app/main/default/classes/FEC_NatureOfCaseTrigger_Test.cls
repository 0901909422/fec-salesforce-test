/**
 * Unit tests for FEC_NatureOfCaseTrigger (channel + remove-phone inheritance).
 */
@IsTest
private class FEC_NatureOfCaseTrigger_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'NOC Trigger PT',
            FEC_Code__c = 'NPT' + suffix,
            FEC_Active__c = true
        );
        insert pt;

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'NOC Trigger BP',
            FEC_Code__c = 'NBP' + suffix,
            FEC_Active__c = true
        );
        insert bp;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'NOC Trigger CAT',
            FEC_Code__c = 'NCA' + suffix,
            FEC_Active__c = true
        );
        insert cat;

        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Channel__c = 'Chat;Phone',
            FEC_Remove_Phone__c = true,
            FEC_Do_Not_Bother__c = true,
            FEC_Active__c = true
        );
    }

    private static FEC_Product_Type__c productType() {
        return [SELECT Id FROM FEC_Product_Type__c LIMIT 1];
    }

    private static FEC_Business_Process__c businessProcess() {
        return [SELECT Id FROM FEC_Business_Process__c LIMIT 1];
    }

    private static FEC_Category__c category() {
        return [SELECT Id FROM FEC_Category__c LIMIT 1];
    }

    private static FEC_Nature_of_Case__c parentNoc() {
        return [
            SELECT Id, FEC_Channel__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Category__c = NULL
              AND FEC_Sub_Category__c = NULL
              AND FEC_Sub_Code__c = NULL
            LIMIT 1
        ];
    }

    @IsTest
    static void testAfterInsert_InheritsChannelFromParent() {
        FEC_Product_Type__c pt = productType();
        FEC_Business_Process__c bp = businessProcess();
        FEC_Category__c cat = category();

        Test.startTest();
        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Active__c = true
        );
        insert child;
        Test.stopTest();

        FEC_Nature_of_Case__c inserted = [
            SELECT FEC_Channel__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :child.Id
        ];
        System.assertEquals('Chat;Phone', inserted.FEC_Channel__c);
    }

    @IsTest
    static void testAfterInsert_InheritsRemovePhoneFlags() {
        FEC_Product_Type__c pt = productType();
        FEC_Business_Process__c bp = businessProcess();
        FEC_Category__c cat = category();

        Test.startTest();
        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Remove_Phone__c = false,
            FEC_Do_Not_Bother__c = false,
            FEC_Transfer_Call_to_Collection__c = false,
            FEC_Active__c = true
        );
        insert child;
        Test.stopTest();

        FEC_Nature_of_Case__c inserted = [
            SELECT FEC_Remove_Phone__c, FEC_Do_Not_Bother__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :child.Id
        ];
        System.assertEquals(true, inserted.FEC_Remove_Phone__c);
        System.assertEquals(true, inserted.FEC_Do_Not_Bother__c);
    }

    @IsTest
    static void testAfterUpdate_PropagatesChannelToChildren() {
        FEC_Product_Type__c pt = productType();
        FEC_Business_Process__c bp = businessProcess();
        FEC_Category__c cat = category();

        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Active__c = true
        );
        insert child;
        child.FEC_Channel__c = null;
        update child;

        FEC_Nature_of_Case__c parent = parentNoc();

        Test.startTest();
        parent.FEC_Channel__c = 'Email;Branch';
        update parent;
        Test.stopTest();

        FEC_Nature_of_Case__c updatedChild = [
            SELECT FEC_Channel__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :child.Id
        ];
        System.assertEquals('Email;Branch', updatedChild.FEC_Channel__c);
    }

    @IsTest
    static void testAfterUpdate_PropagatesRemovePhoneToChildren() {
        FEC_Product_Type__c pt = productType();
        FEC_Business_Process__c bp = businessProcess();
        FEC_Category__c cat = category();

        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Remove_Phone__c = false,
            FEC_Do_Not_Bother__c = false,
            FEC_Transfer_Call_to_Collection__c = false,
            FEC_Active__c = true
        );
        insert child;

        FEC_Nature_of_Case__c parent = parentNoc();
        parent.FEC_Remove_Phone__c = false;
        parent.FEC_Do_Not_Bother__c = false;
        update parent;

        Test.startTest();
        parent.FEC_Remove_Phone__c = true;
        parent.FEC_Do_Not_Bother__c = true;
        update parent;
        Test.stopTest();

        FEC_Nature_of_Case__c updatedChild = [
            SELECT FEC_Remove_Phone__c, FEC_Do_Not_Bother__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :child.Id
        ];
        System.assertEquals(true, updatedChild.FEC_Remove_Phone__c);
        System.assertEquals(true, updatedChild.FEC_Do_Not_Bother__c);
    }

    @IsTest
    static void testAfterInsert_NoInheritanceWhenInactiveChild() {
        FEC_Product_Type__c pt = productType();
        FEC_Business_Process__c bp = businessProcess();
        FEC_Category__c cat = category();

        Test.startTest();
        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Active__c = false
        );
        insert child;
        Test.stopTest();

        FEC_Nature_of_Case__c inserted = [
            SELECT FEC_Channel__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :child.Id
        ];
        System.assertEquals(null, inserted.FEC_Channel__c);
    }
}
