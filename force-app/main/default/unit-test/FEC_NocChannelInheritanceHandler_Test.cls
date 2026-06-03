/**
 * Unit tests for FEC_NocChannelInheritanceHandler (channel propagation by NOC hierarchy level).
 */
@IsTest
private class FEC_NocChannelInheritanceHandler_Test {

    private static final String CHANNEL_INITIAL = 'Chat;Phone';
    private static final String CHANNEL_UPDATED = 'Email;Branch';

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'NOC Channel PT',
            FEC_Code__c = 'NCH' + suffix,
            FEC_Active__c = true
        );
        insert pt;

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'NOC Channel BP',
            FEC_Code__c = 'NCB' + suffix,
            FEC_Active__c = true
        );
        insert bp;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'NOC Channel CAT',
            FEC_Code__c = 'NCC' + suffix,
            FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'NOC Channel SCAT',
            FEC_Code__c = 'NCS' + suffix,
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'NOC Channel SC',
            FEC_Code__c = 'NCX' + suffix,
            FEC_Active__c = true
        );
        insert subCode;
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

    private static FEC_Sub_Category__c subCategory() {
        return [SELECT Id FROM FEC_Sub_Category__c LIMIT 1];
    }

    private static FEC_Sub_Code__c subCode() {
        return [SELECT Id FROM FEC_Sub_Code__c LIMIT 1];
    }

    @IsTest
    static void testHandleAfterInsertUpdate_Level1_PropagatesToSameBusinessProcess() {
        FEC_Product_Type__c pt = productType();
        FEC_Business_Process__c bp = businessProcess();
        FEC_Category__c cat = category();

        FEC_Nature_of_Case__c parent = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Channel__c = CHANNEL_INITIAL,
            FEC_Active__c = true
        );
        insert parent;

        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Active__c = true
        );
        insert child;
        update new FEC_Nature_of_Case__c(Id = child.Id, FEC_Channel__c = null);

        parent.FEC_Channel__c = CHANNEL_UPDATED;

        Test.startTest();
        FEC_NocChannelInheritanceHandler.handleAfterInsertUpdate(
            new List<FEC_Nature_of_Case__c>{ parent },
            new Map<Id, FEC_Nature_of_Case__c>{
                parent.Id => new FEC_Nature_of_Case__c(
                    Id = parent.Id,
                    FEC_Channel__c = CHANNEL_INITIAL
                )
            }
        );
        Test.stopTest();

        System.assertEquals(
            CHANNEL_UPDATED,
            [SELECT FEC_Channel__c FROM FEC_Nature_of_Case__c WHERE Id = :child.Id].FEC_Channel__c
        );
    }

    @IsTest
    static void testHandleAfterInsertUpdate_Level2_PropagatesToSameCategory() {
        FEC_Product_Type__c pt = productType();
        FEC_Business_Process__c bp = businessProcess();
        FEC_Category__c cat = category();
        FEC_Sub_Category__c sc = subCategory();

        FEC_Nature_of_Case__c parent = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Channel__c = CHANNEL_INITIAL,
            FEC_Active__c = true
        );
        insert parent;

        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = sc.Id,
            FEC_Active__c = true
        );
        insert child;
        update new FEC_Nature_of_Case__c(Id = child.Id, FEC_Channel__c = null);

        parent.FEC_Channel__c = CHANNEL_UPDATED;

        Test.startTest();
        FEC_NocChannelInheritanceHandler.handleAfterInsertUpdate(
            new List<FEC_Nature_of_Case__c>{ parent },
            new Map<Id, FEC_Nature_of_Case__c>{
                parent.Id => new FEC_Nature_of_Case__c(
                    Id = parent.Id,
                    FEC_Channel__c = CHANNEL_INITIAL
                )
            }
        );
        Test.stopTest();

        System.assertEquals(
            CHANNEL_UPDATED,
            [SELECT FEC_Channel__c FROM FEC_Nature_of_Case__c WHERE Id = :child.Id].FEC_Channel__c
        );
    }

    @IsTest
    static void testHandleAfterInsertUpdate_Level3_PropagatesToSameSubCategory() {
        FEC_Product_Type__c pt = productType();
        FEC_Business_Process__c bp = businessProcess();
        FEC_Category__c cat = category();
        FEC_Sub_Category__c sc = subCategory();
        FEC_Sub_Code__c code = subCode();

        FEC_Nature_of_Case__c parent = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = sc.Id,
            FEC_Channel__c = CHANNEL_INITIAL,
            FEC_Active__c = true
        );
        insert parent;

        FEC_Nature_of_Case__c childSameSubCategory = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = sc.Id,
            FEC_Active__c = true
        );
        insert childSameSubCategory;
        update new FEC_Nature_of_Case__c(Id = childSameSubCategory.Id, FEC_Channel__c = null);

        FEC_Nature_of_Case__c childWithSubCode = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = sc.Id,
            FEC_Sub_Code__c = code.Id,
            FEC_Active__c = true
        );
        insert childWithSubCode;
        update new FEC_Nature_of_Case__c(Id = childWithSubCode.Id, FEC_Channel__c = null);

        parent.FEC_Channel__c = CHANNEL_UPDATED;

        Test.startTest();
        FEC_NocChannelInheritanceHandler.handleAfterInsertUpdate(
            new List<FEC_Nature_of_Case__c>{ parent },
            new Map<Id, FEC_Nature_of_Case__c>{
                parent.Id => new FEC_Nature_of_Case__c(
                    Id = parent.Id,
                    FEC_Channel__c = CHANNEL_INITIAL
                )
            }
        );
        Test.stopTest();

        System.assertEquals(
            CHANNEL_UPDATED,
            [SELECT FEC_Channel__c FROM FEC_Nature_of_Case__c WHERE Id = :childSameSubCategory.Id]
                .FEC_Channel__c
        );
        System.assertEquals(
            CHANNEL_UPDATED,
            [SELECT FEC_Channel__c FROM FEC_Nature_of_Case__c WHERE Id = :childWithSubCode.Id].FEC_Channel__c
        );
    }

    @IsTest
    static void testHandleAfterInsertUpdate_Level4_NoPropagation() {
        FEC_Product_Type__c pt = productType();
        FEC_Business_Process__c bp = businessProcess();
        FEC_Category__c cat = category();
        FEC_Sub_Category__c sc = subCategory();
        FEC_Sub_Code__c code = subCode();

        FEC_Nature_of_Case__c parent = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = sc.Id,
            FEC_Sub_Code__c = code.Id,
            FEC_Channel__c = CHANNEL_INITIAL,
            FEC_Active__c = true
        );
        insert parent;

        FEC_Nature_of_Case__c other = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = sc.Id,
            FEC_Active__c = true
        );
        insert other;

        parent.FEC_Channel__c = CHANNEL_UPDATED;

        Test.startTest();
        FEC_NocChannelInheritanceHandler.handleAfterInsertUpdate(
            new List<FEC_Nature_of_Case__c>{ parent },
            new Map<Id, FEC_Nature_of_Case__c>{
                parent.Id => new FEC_Nature_of_Case__c(
                    Id = parent.Id,
                    FEC_Channel__c = CHANNEL_INITIAL
                )
            }
        );
        Test.stopTest();

        System.assertEquals(
            null,
            [SELECT FEC_Channel__c FROM FEC_Nature_of_Case__c WHERE Id = :other.Id].FEC_Channel__c
        );
    }

    @IsTest
    static void testHandleAfterInsertUpdate_SkipsBlankChannel() {
        FEC_Product_Type__c pt = productType();
        FEC_Business_Process__c bp = businessProcess();

        FEC_Nature_of_Case__c parent = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert parent;

        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert child;

        Test.startTest();
        FEC_NocChannelInheritanceHandler.handleAfterInsertUpdate(
            new List<FEC_Nature_of_Case__c>{ parent },
            null
        );
        Test.stopTest();

        System.assertEquals(null, [SELECT FEC_Channel__c FROM FEC_Nature_of_Case__c WHERE Id = :child.Id].FEC_Channel__c);
    }

    @IsTest
    static void testHandleAfterInsertUpdate_SkipsUnchangedChannel() {
        FEC_Product_Type__c pt = productType();
        FEC_Business_Process__c bp = businessProcess();

        FEC_Nature_of_Case__c parent = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Channel__c = CHANNEL_INITIAL,
            FEC_Active__c = true
        );
        insert parent;

        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert child;

        Test.startTest();
        FEC_NocChannelInheritanceHandler.handleAfterInsertUpdate(
            new List<FEC_Nature_of_Case__c>{ parent },
            new Map<Id, FEC_Nature_of_Case__c>{
                parent.Id => new FEC_Nature_of_Case__c(
                    Id = parent.Id,
                    FEC_Channel__c = CHANNEL_INITIAL
                )
            }
        );
        Test.stopTest();

        System.assertEquals(null, [SELECT FEC_Channel__c FROM FEC_Nature_of_Case__c WHERE Id = :child.Id].FEC_Channel__c);
    }

    @IsTest
    static void testHandleAfterInsertUpdate_InsertWithChannelPropagates() {
        FEC_Product_Type__c pt = productType();
        FEC_Business_Process__c bp = businessProcess();

        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert child;

        FEC_Nature_of_Case__c parent = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Channel__c = CHANNEL_INITIAL,
            FEC_Active__c = true
        );
        insert parent;

        Test.startTest();
        FEC_NocChannelInheritanceHandler.handleAfterInsertUpdate(
            new List<FEC_Nature_of_Case__c>{ parent },
            null
        );
        Test.stopTest();

        System.assertEquals(
            CHANNEL_INITIAL,
            [SELECT FEC_Channel__c FROM FEC_Nature_of_Case__c WHERE Id = :child.Id].FEC_Channel__c
        );
    }
}
