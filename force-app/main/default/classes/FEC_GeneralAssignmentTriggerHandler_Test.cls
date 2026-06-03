@IsTest
private class FEC_GeneralAssignmentTriggerHandler_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Loan',
            FEC_Code__c = 'LOAN' + suffix,
            FEC_Active__c = true
        );
        insert prod;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Cash',
            FEC_Code__c = 'CASH' + suffix,
            FEC_Active__c = true
        );
        insert cat;

        // Parent NOC: chỉ Product Type (Name auto-number, không gán được)
        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Active__c = true
        );

        // Child NOC: Product Type + Category (kế thừa từ parent theo handler)
        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Active__c = true
        );
    }

    private static FEC_Nature_of_Case__c getParentNoc() {
        return [
            SELECT Id
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Category__c = null
              AND FEC_Sub_Category__c = null
              AND FEC_Sub_Code__c = null
            LIMIT 1
        ];
    }

    private static FEC_Nature_of_Case__c getChildNoc() {
        return [
            SELECT Id
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Category__c != null
            LIMIT 1
        ];
    }

    @IsTest
    static void testInheritanceInsertion() {
        FEC_Nature_of_Case__c parentNoc = getParentNoc();
        FEC_Nature_of_Case__c childNoc = getChildNoc();

        FEC_General_Assignment_Config__c parentConfig = new FEC_General_Assignment_Config__c(
            FEC_Nature_of_Cases__c = parentNoc.Id,
            FEC_Customer_Type__c = 'Existing',
            FEC_Channel__c = 'Call',
            FEC_General_Assignment_Name__c = 'GA01',
            FEC_Active__c = true
        );

        Test.startTest();
        insert parentConfig;
        Test.stopTest();

        List<FEC_General_Assignment_Config__c> childConfigs = [
            SELECT Id, FEC_Nature_of_Cases__c
            FROM FEC_General_Assignment_Config__c
            WHERE FEC_Nature_of_Cases__c = :childNoc.Id
        ];

        System.assertEquals(1, childConfigs.size(), 'Child config phải được tạo kế thừa từ parent.');
    }

    @IsTest
    static void testNoDuplicateInheritance() {
        FEC_Nature_of_Case__c parentNoc = getParentNoc();
        FEC_Nature_of_Case__c childNoc = getChildNoc();

        FEC_General_Assignment_Config__c parentConfig = new FEC_General_Assignment_Config__c(
            FEC_Nature_of_Cases__c = parentNoc.Id,
            FEC_General_Assignment_Name__c = 'GA01',
            FEC_Active__c = true
        );
        insert parentConfig;

        Test.startTest();
        insert new FEC_General_Assignment_Config__c(
            FEC_Nature_of_Cases__c = parentNoc.Id,
            FEC_General_Assignment_Name__c = 'GA01',
            FEC_Active__c = true
        );
        Test.stopTest();

        List<FEC_General_Assignment_Config__c> childConfigs = [
            SELECT Id FROM FEC_General_Assignment_Config__c WHERE FEC_Nature_of_Cases__c = :childNoc.Id
        ];
        System.assertEquals(1, childConfigs.size(), 'Không được tạo trùng lặp.');
    }
}
