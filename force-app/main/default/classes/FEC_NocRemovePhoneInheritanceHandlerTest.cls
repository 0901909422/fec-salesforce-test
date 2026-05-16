@IsTest
private class FEC_NocRemovePhoneInheritanceHandlerTest {

    private static FEC_Sub_Category__c createSubCategory(String name) {
        FEC_Sub_Category__c sc = new FEC_Sub_Category__c(Name = name);
        insert sc;
        return sc;
    }

    private static FEC_Sub_Code__c createSubCode(String name) {
        FEC_Sub_Code__c code = new FEC_Sub_Code__c(Name = name);
        insert code;
        return code;
    }

    @IsTest
    static void testUpdateParentPropagatesToActiveChildrenWithSubCode() {
        FEC_Sub_Category__c subCat = createSubCategory('SC Propagate');
        FEC_Sub_Code__c subCode = createSubCode('SCODE Propagate');

        FEC_Nature_of_Case__c childShouldUpdate = new FEC_Nature_of_Case__c(
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = false,
            FEC_Do_Not_Bother__c = false,
            FEC_Transfer_Call_to_Collection__c = false
        );
        FEC_Nature_of_Case__c childShouldKeepTrue = new FEC_Nature_of_Case__c(
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = true,
            FEC_Do_Not_Bother__c = true,
            FEC_Transfer_Call_to_Collection__c = true
        );
        FEC_Nature_of_Case__c inactiveChild = new FEC_Nature_of_Case__c(
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = false,
            FEC_Remove_Phone__c = false,
            FEC_Do_Not_Bother__c = false,
            FEC_Transfer_Call_to_Collection__c = false
        );
        insert new List<FEC_Nature_of_Case__c>{ childShouldUpdate, childShouldKeepTrue, inactiveChild };

        FEC_Nature_of_Case__c parent = new FEC_Nature_of_Case__c(
            FEC_Sub_Category__c = subCat.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = true,
            FEC_Do_Not_Bother__c = true,
            FEC_Transfer_Call_to_Collection__c = true
        );
        insert parent;

        Map<Id, FEC_Nature_of_Case__c> refreshed = new Map<Id, FEC_Nature_of_Case__c>([
            SELECT Id, FEC_Remove_Phone__c, FEC_Do_Not_Bother__c, FEC_Transfer_Call_to_Collection__c, FEC_Active__c
            FROM FEC_Nature_of_Case__c
            WHERE Id IN :new List<Id>{ childShouldUpdate.Id, childShouldKeepTrue.Id, inactiveChild.Id }
        ]);

        System.assertEquals(true, refreshed.get(childShouldUpdate.Id).FEC_Remove_Phone__c);
        System.assertEquals(true, refreshed.get(childShouldUpdate.Id).FEC_Do_Not_Bother__c);
        System.assertEquals(true, refreshed.get(childShouldUpdate.Id).FEC_Transfer_Call_to_Collection__c);
        System.assertEquals(true, refreshed.get(childShouldKeepTrue.Id).FEC_Remove_Phone__c);
        System.assertEquals(false, refreshed.get(inactiveChild.Id).FEC_Remove_Phone__c);
    }

    @IsTest
    static void testUpdateParentFalseDoesNotOverrideChildTrue() {
        FEC_Sub_Category__c subCat = createSubCategory('SC No Override');
        FEC_Sub_Code__c subCode = createSubCode('SCODE No Override');

        FEC_Nature_of_Case__c childTrue = new FEC_Nature_of_Case__c(
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = true,
            FEC_Do_Not_Bother__c = true,
            FEC_Transfer_Call_to_Collection__c = true
        );
        insert childTrue;

        FEC_Nature_of_Case__c parent = new FEC_Nature_of_Case__c(
            FEC_Sub_Category__c = subCat.Id,
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
        System.assertEquals(true, refreshedChild.FEC_Remove_Phone__c);
        System.assertEquals(true, refreshedChild.FEC_Do_Not_Bother__c);
        System.assertEquals(true, refreshedChild.FEC_Transfer_Call_to_Collection__c);
    }

    @IsTest
    static void testInsertChildInheritsFromExistingParentSameSubCategory() {
        FEC_Sub_Category__c subCat = createSubCategory('SC Insert Inherit');
        FEC_Sub_Code__c subCode = createSubCode('SCODE Insert Inherit');

        insert new FEC_Nature_of_Case__c(
            FEC_Sub_Category__c = subCat.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = true,
            FEC_Do_Not_Bother__c = true,
            FEC_Transfer_Call_to_Collection__c = true
        );

        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
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
        System.assertEquals(true, refreshed.FEC_Remove_Phone__c);
        System.assertEquals(true, refreshed.FEC_Do_Not_Bother__c);
        System.assertEquals(true, refreshed.FEC_Transfer_Call_to_Collection__c);
    }
}
