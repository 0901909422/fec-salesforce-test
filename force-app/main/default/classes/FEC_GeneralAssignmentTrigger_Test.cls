@IsTest
private class FEC_GeneralAssignmentTrigger_Test {
    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.now().getTime());

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Prod ' + suffix,
            FEC_Code__c = 'PT' + suffix,
            FEC_Active__c = true
        );
        insert prod;

        FEC_Category__c catA = new FEC_Category__c(
            Name = 'CatA ' + suffix,
            FEC_Code__c = 'CA' + suffix,
            FEC_Active__c = true
        );
        FEC_Category__c catB = new FEC_Category__c(
            Name = 'CatB ' + suffix,
            FEC_Code__c = 'CB' + suffix,
            FEC_Active__c = true
        );
        insert new List<FEC_Category__c>{ catA, catB };

        // Parent (Product only)
        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Active__c = true
        );
        // Child for parent above (Product + Category A)
        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = catA.Id,
            FEC_Active__c = true
        );
        // Another parent (Product + Category B)
        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = catB.Id,
            FEC_Active__c = true
        );
    }

    private static FEC_Nature_of_Case__c getRootParentNoc() {
        return [
            SELECT Id
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Category__c = null
              AND FEC_Sub_Category__c = null
              AND FEC_Sub_Code__c = null
            LIMIT 1
        ];
    }

    private static FEC_Nature_of_Case__c getAnotherParentNoc() {
        return [
            SELECT Id
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Category__c != null
              AND FEC_Sub_Category__c = null
              AND FEC_Sub_Code__c = null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    @IsTest
    static void testAfterInsert_triggerCreatesInheritedConfigs() {
        FEC_Nature_of_Case__c parentNoc = getRootParentNoc();

        Test.startTest();
        insert new FEC_General_Assignment_Config__c(
            FEC_Nature_of_Cases__c = parentNoc.Id,
            FEC_Customer_Type__c = 'Existing',
            FEC_Channel__c = 'Call',
            FEC_General_Assignment_Name__c = 'GA-T-INS',
            FEC_Active__c = true
        );
        Test.stopTest();

        Integer childCount = [
            SELECT COUNT()
            FROM FEC_General_Assignment_Config__c
            WHERE FEC_Nature_of_Cases__r.FEC_Category__c != null
              AND FEC_General_Assignment_Name__c = 'GA-T-INS'
        ];
        System.assert(childCount > 0, 'After insert trigger should create inherited child config(s).');
    }

    @IsTest
    static void testAfterUpdate_triggerWhenNatureChanged() {
        FEC_Nature_of_Case__c parentA = getRootParentNoc();
        FEC_Nature_of_Case__c parentB = getAnotherParentNoc();

        FEC_General_Assignment_Config__c cfg = new FEC_General_Assignment_Config__c(
            FEC_Nature_of_Cases__c = parentA.Id,
            FEC_General_Assignment_Name__c = 'GA-T-UPD',
            FEC_Active__c = true
        );
        insert cfg;

        Test.startTest();
        cfg.FEC_Nature_of_Cases__c = parentB.Id;
        update cfg;
        Test.stopTest();

        Integer sameNameCount = [
            SELECT COUNT()
            FROM FEC_General_Assignment_Config__c
            WHERE FEC_General_Assignment_Name__c = 'GA-T-UPD'
        ];
        System.assert(sameNameCount >= 1, 'After update should execute without errors when nature changes.');
    }

    @IsTest
    static void testAfterUpdate_triggerWhenNatureUnchanged() {
        FEC_Nature_of_Case__c parentA = getRootParentNoc();
        FEC_General_Assignment_Config__c cfg = new FEC_General_Assignment_Config__c(
            FEC_Nature_of_Cases__c = parentA.Id,
            FEC_General_Assignment_Name__c = 'GA-T-NOCHG',
            FEC_Active__c = true
        );
        insert cfg;

        Test.startTest();
        cfg.FEC_Active__c = false;
        update cfg;
        Test.stopTest();

        FEC_General_Assignment_Config__c refreshed = [
            SELECT Id, FEC_Active__c
            FROM FEC_General_Assignment_Config__c
            WHERE Id = :cfg.Id
            LIMIT 1
        ];
        System.assertEquals(false, refreshed.FEC_Active__c, 'Update without nature change should still complete.');
    }
}
