@IsTest
private class FEC_NocRemovePhoneInheritanceHandlerTest {

    private static FEC_Product_Type__c createProductType(String name) {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = name,
            FEC_Code__c = name.replace(' ', '_'),
            FEC_Active__c = true
        );
        insert pt;
        return pt;
    }

    private static FEC_Category__c createCategory(String name) {
        FEC_Category__c cat = new FEC_Category__c(
            Name = name,
            FEC_Code__c = name.replace(' ', '_'),
            FEC_Active__c = true
        );
        insert cat;
        return cat;
    }

    private static FEC_Sub_Category__c createSubCategory(String name) {
        FEC_Sub_Category__c sc = new FEC_Sub_Category__c(
            Name = name,
            FEC_Code__c = name.replace(' ', '_'),
            FEC_Active__c = true
        );
        insert sc;
        return sc;
    }

    private static FEC_Sub_Code__c createSubCode(String name) {
        FEC_Sub_Code__c code = new FEC_Sub_Code__c(
            Name = name,
            FEC_Code__c = name.replace(' ', '_'),
            FEC_Active__c = true
        );
        insert code;
        return code;
    }

    @IsTest
    static void testParentWithMoreNullsPropagatesToChildSameProductType() {
        FEC_Product_Type__c pt = createProductType('PT Inherit 1');
        FEC_Category__c cat = createCategory('Cat Inherit 1');
        FEC_Sub_Category__c subCat = createSubCategory('SC Inherit 1');
        FEC_Sub_Code__c subCode = createSubCode('SCODE Inherit 1');

        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = false,
            FEC_Do_Not_Bother__c = false,
            FEC_Transfer_Call_to_Collection__c = false
        );
        insert child;

        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = true,
            FEC_Do_Not_Bother__c = true,
            FEC_Transfer_Call_to_Collection__c = true
        );

        FEC_Nature_of_Case__c refreshed = [
            SELECT FEC_Do_Not_Bother__c, FEC_Remove_Phone__c, FEC_Transfer_Call_to_Collection__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :child.Id
        ];
        System.assertEquals(true, refreshed.FEC_Do_Not_Bother__c);
        System.assertEquals(true, refreshed.FEC_Remove_Phone__c);
        System.assertEquals(true, refreshed.FEC_Transfer_Call_to_Collection__c);
    }

    @IsTest
    static void testUpdateParentFalseDoesNotOverrideChildTrue() {
        FEC_Product_Type__c pt = createProductType('PT Inherit 2');
        FEC_Sub_Category__c subCat = createSubCategory('SC Inherit 2');
        FEC_Sub_Code__c subCode = createSubCode('SCODE Inherit 2');

        FEC_Nature_of_Case__c childTrue = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true,
            FEC_Remove_Phone__c = true,
            FEC_Do_Not_Bother__c = true,
            FEC_Transfer_Call_to_Collection__c = true
        );
        insert childTrue;

        FEC_Nature_of_Case__c parent = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
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
            SELECT FEC_Remove_Phone__c, FEC_Do_Not_Bother__c, FEC_Transfer_Call_to_Collection__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :childTrue.Id
        ];
        System.assertEquals(true, refreshedChild.FEC_Remove_Phone__c);
        System.assertEquals(true, refreshedChild.FEC_Do_Not_Bother__c);
        System.assertEquals(true, refreshedChild.FEC_Transfer_Call_to_Collection__c);
    }

    @IsTest
    static void testInsertChildInheritsFromSparseParentSameProductType() {
        FEC_Product_Type__c pt = createProductType('PT Inherit 3');
        FEC_Category__c cat = createCategory('Cat Inherit 3');
        FEC_Sub_Category__c subCat = createSubCategory('SC Inherit 3');
        FEC_Sub_Code__c subCode = createSubCode('SCODE Inherit 3');

        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Active__c = true,
            FEC_Do_Not_Bother__c = true,
            FEC_Remove_Phone__c = true,
            FEC_Transfer_Call_to_Collection__c = true
        );

        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true,
            FEC_Do_Not_Bother__c = false,
            FEC_Remove_Phone__c = false,
            FEC_Transfer_Call_to_Collection__c = false
        );
        insert child;

        FEC_Nature_of_Case__c refreshed = [
            SELECT FEC_Do_Not_Bother__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :child.Id
        ];
        System.assertEquals(true, refreshed.FEC_Do_Not_Bother__c);
    }
}
