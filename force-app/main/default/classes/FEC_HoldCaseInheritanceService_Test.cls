@IsTest
private class FEC_HoldCaseInheritanceService_Test {

    @IsTest
    static void testProcessInheritance() {
        String suffix = String.valueOf(System.currentTimeMillis());

        FEC_Product_Type__c productType = new FEC_Product_Type__c(
            Name = 'Inherit Product',
            FEC_Code__c = 'INP' + suffix,
            FEC_Active__c = true
        );
        insert productType;

        FEC_Category__c category = new FEC_Category__c(
            Name = 'Inherit Category',
            FEC_Code__c = 'INC' + suffix,
            FEC_Active__c = true
        );
        insert category;

        FEC_Sub_Category__c subCategory = new FEC_Sub_Category__c(
            Name = 'Inherit SubCat',
            FEC_Code__c = 'INS' + suffix,
            FEC_Active__c = true
        );
        insert subCategory;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'Inherit SubCode',
            FEC_Code__c = 'INSC' + suffix,
            FEC_Active__c = true
        );
        insert subCode;

        // Parent NOC: Product + Category + Sub Category (Name is auto-number)
        FEC_Nature_of_Case__c parentNoc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = productType.Id,
            FEC_Category__c = category.Id,
            FEC_Sub_Category__c = subCategory.Id,
            FEC_Active__c = true
        );
        insert parentNoc;

        // Child NOC: same hierarchy + Sub Code — direct child per getDirectChildren CASE 3
        FEC_Nature_of_Case__c childNoc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = productType.Id,
            FEC_Category__c = category.Id,
            FEC_Sub_Category__c = subCategory.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true
        );
        insert childNoc;

        FEC_Hold_Case_Config__c sourceConfig = new FEC_Hold_Case_Config__c(
            FEC_Nature_of_Cases__c = parentNoc.Id,
            Hold_Case_Type__c = 'Manual',
            FEC_Active__c = true
        );
        insert sourceConfig;

        Test.startTest();
        FEC_HoldCaseInheritanceService.process(sourceConfig.Id);
        Test.stopTest();

        List<FEC_Hold_Case_Config__c> inheritedConfigs = [
            SELECT Id, FEC_Nature_of_Cases__c
            FROM FEC_Hold_Case_Config__c
            WHERE FEC_Nature_of_Cases__c = :childNoc.Id
        ];

        System.assertEquals(1, inheritedConfigs.size(), 'Config must be inherited to the child NOC.');
        System.assertEquals(childNoc.Id, inheritedConfigs[0].FEC_Nature_of_Cases__c);
    }

    @IsTest
    static void testProcess_NullId() {
        Test.startTest();
        FEC_HoldCaseInheritanceService.process(null);
        Test.stopTest();
        System.assert(true);
    }
}
