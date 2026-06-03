@IsTest
private class FEC_LookupController_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'LKPT' + suffix,
            FEC_Active__c = true
        );
        insert prod;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Payment',
            FEC_Code__c = 'LKCAT' + suffix,
            FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Late Payment',
            FEC_Code__c = 'LKSUB' + suffix,
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'LP_01',
            FEC_Code__c = 'LKSC' + suffix,
            FEC_Active__c = true
        );
        insert subCode;

        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id
        );
    }

    @IsTest
    static void testSearchCaseStatus() {
        if (Type.forName('FEC_LookupController') == null) {
            System.assert(true, 'Skipped: FEC_LookupController not on org.');
            return;
        }

        String searchTerm = 'a';
        for (Schema.PicklistEntry entry : Case.Status.getDescribe().getPicklistValues()) {
            if (entry.isActive() && String.isNotBlank(entry.getLabel())) {
                searchTerm = entry.getLabel().length() > 2
                    ? entry.getLabel().substring(0, 2)
                    : entry.getLabel();
                break;
            }
        }

        Test.startTest();
        List<FEC_LookupController.LookupSearchResult> results =
            FEC_LookupController.searchLookupRecords(
                searchTerm,
                new List<String>(),
                'Case.Status',
                'Status',
                null,
                5,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assert(results.size() > 0, 'Should find at least one Case status.');
    }

    @IsTest
    static void testSearchProductType() {
        if (Type.forName('FEC_LookupController') == null) {
            System.assert(true, 'Skipped: FEC_LookupController not on org.');
            return;
        }

        Test.startTest();
        List<FEC_LookupController.LookupSearchResult> results =
            FEC_LookupController.searchLookupRecords(
                'Credit',
                new List<String>(),
                'FEC_Product_Type__c',
                'Name',
                null,
                5,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assert(
            results != null && results.size() > 0,
            'Should find seeded Product Type.'
        );
    }

    @IsTest
    static void testGetRecentlyCreatedRecord() {
        if (Type.forName('FEC_LookupController') == null) {
            System.assert(true, 'Skipped: FEC_LookupController not on org.');
            return;
        }

        FEC_Product_Type__c prod = [SELECT Id, Name FROM FEC_Product_Type__c LIMIT 1];

        Test.startTest();
        FEC_LookupController.LookupSearchResult res =
            FEC_LookupController.getRecentlyCreatedRecord(
                'FEC_Product_Type__c',
                prod.Id,
                'Name',
                null
            );
        Test.stopTest();

        System.assertEquals(prod.Name, res.title);
    }
}
