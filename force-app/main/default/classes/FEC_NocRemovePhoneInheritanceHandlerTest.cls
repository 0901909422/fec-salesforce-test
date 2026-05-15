@IsTest
private class FEC_NocRemovePhoneInheritanceHandlerTest {
    private static FEC_Business_Process__c createBusinessProcess(String name) {
        FEC_Business_Process__c bp = new FEC_Business_Process__c(Name = name);
        insert bp;
        return bp;
    }

    @IsTest
    static void testInsertParentPropagatesToActiveChildrenWithoutTrueValue() {
        FEC_Business_Process__c bp = createBusinessProcess('BP Remove 1');

        FEC_Nature_of_Case__c childShouldUpdate = new FEC_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = false,
            FEC_Do_Not_Bother__c = false,
            FEC_Transfer_Call_to_Collection__c = false
        );
        FEC_Nature_of_Case__c childShouldKeepTrue = new FEC_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = true,
            FEC_Do_Not_Bother__c = true,
            FEC_Transfer_Call_to_Collection__c = true
        );
        FEC_Nature_of_Case__c inactiveChild = new FEC_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = false,
            FEC_Remove_Phone__c = false,
            FEC_Do_Not_Bother__c = false,
            FEC_Transfer_Call_to_Collection__c = false
        );
        insert new List<FEC_Nature_of_Case__c>{ childShouldUpdate, childShouldKeepTrue, inactiveChild };

        insert new FEC_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = true,
            FEC_Do_Not_Bother__c = true,
            FEC_Transfer_Call_to_Collection__c = true
        );

        Map<Id, FEC_Nature_of_Case__c> refreshed = new Map<Id, FEC_Nature_of_Case__c>([
            SELECT Id, FEC_Remove_Phone__c, FEC_Do_Not_Bother__c, FEC_Transfer_Call_to_Collection__c, FEC_Active__c
            FROM FEC_Nature_of_Case__c
            WHERE Id IN :new List<Id>{ childShouldUpdate.Id, childShouldKeepTrue.Id, inactiveChild.Id }
        ]);

        System.assertEquals(true, refreshed.get(childShouldUpdate.Id).FEC_Remove_Phone__c,
            'Active child with false value should inherit parent true value.');
        System.assertEquals(true, refreshed.get(childShouldKeepTrue.Id).FEC_Remove_Phone__c,
            'Child already true must be kept (no override).');
        System.assertEquals(true, refreshed.get(childShouldUpdate.Id).FEC_Do_Not_Bother__c,
            'Active child should inherit Do Not Bother from parent.');
        System.assertEquals(true, refreshed.get(childShouldUpdate.Id).FEC_Transfer_Call_to_Collection__c,
            'Active child should inherit Transfer Call to Collection from parent.');
        System.assertEquals(true, refreshed.get(childShouldKeepTrue.Id).FEC_Do_Not_Bother__c,
            'Child already true must be kept (no override).');
        System.assertEquals(true, refreshed.get(childShouldKeepTrue.Id).FEC_Transfer_Call_to_Collection__c,
            'Child already true must be kept (no override).');
        System.assertEquals(false, refreshed.get(inactiveChild.Id).FEC_Remove_Phone__c,
            'Inactive child must not be updated.');
        System.assertEquals(false, refreshed.get(inactiveChild.Id).FEC_Do_Not_Bother__c,
            'Inactive child must not be updated.');
        System.assertEquals(false, refreshed.get(inactiveChild.Id).FEC_Transfer_Call_to_Collection__c,
            'Inactive child must not be updated.');
    }

    @IsTest
    static void testUpdateParentFalseDoesNotOverrideChildTrue() {
        FEC_Business_Process__c bp = createBusinessProcess('BP Remove 2');

        FEC_Nature_of_Case__c childTrue = new FEC_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = true,
            FEC_Do_Not_Bother__c = true,
            FEC_Transfer_Call_to_Collection__c = true
        );
        insert childTrue;

        FEC_Nature_of_Case__c parent = new FEC_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = true,
            FEC_Do_Not_Bother__c = true,
            FEC_Transfer_Call_to_Collection__c = true
        );
        insert parent;

        parent.FEC_Remove_Phone__c = false;
        parent.FEC_Do_Not_Bother__c = false;
        parent.FEC_Transfer_Call_to_Collection__c = false;
        update parent;

        FEC_Nature_of_Case__c refreshedChild = [
            SELECT Id, FEC_Remove_Phone__c, FEC_Do_Not_Bother__c, FEC_Transfer_Call_to_Collection__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :childTrue.Id
            LIMIT 1
        ];
        System.assertEquals(true, refreshedChild.FEC_Remove_Phone__c,
            'Child true value must stay true when parent changes to false.');
        System.assertEquals(true, refreshedChild.FEC_Do_Not_Bother__c,
            'Child true value must stay true when parent changes to false.');
        System.assertEquals(true, refreshedChild.FEC_Transfer_Call_to_Collection__c,
            'Child true value must stay true when parent changes to false.');
    }

    @IsTest
    static void testInsertChildInheritsFromExistingConfiguredParent() {
        FEC_Business_Process__c bp = createBusinessProcess('BP Remove 3');
        FEC_Category__c cat = new FEC_Category__c(Name = 'Cat Remove 3');
        insert cat;

        // Parent at level 1 (BP only) is already configured true.
        insert new FEC_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = true,
            FEC_Do_Not_Bother__c = true,
            FEC_Transfer_Call_to_Collection__c = true
        );

        // New child at level 2 starts false and should inherit true on insert.
        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = null,
            FEC_Sub_Code__c = null,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = false,
            FEC_Do_Not_Bother__c = false,
            FEC_Transfer_Call_to_Collection__c = false
        );
        insert child;

        FEC_Nature_of_Case__c refreshed = [
            SELECT Id, FEC_Remove_Phone__c, FEC_Do_Not_Bother__c, FEC_Transfer_Call_to_Collection__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :child.Id
            LIMIT 1
        ];
        System.assertEquals(true, refreshed.FEC_Remove_Phone__c,
            'Child inserted after parent is configured must inherit remove phone value.');
        System.assertEquals(true, refreshed.FEC_Do_Not_Bother__c,
            'Child inserted after parent is configured must inherit do not bother value.');
        System.assertEquals(true, refreshed.FEC_Transfer_Call_to_Collection__c,
            'Child inserted after parent is configured must inherit transfer call to collection value.');
    }
}
